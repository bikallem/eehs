#include <liburing.h>
#include <linux/io_uring.h>
#include <netinet/in.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#define handle_sys_error(call, errno)                                             \
    do {                                                                          \
        fprintf(stderr, "%s failed. error: %i %s", call, errno, strerror(errno)); \
        exit(EXIT_FAILURE);                                                       \
    } while (0)

#define SOCK_BACKLOG 1024
static int ring_size = 10;
static int nr_conns;
static long page_size;

static int buf_size = 32;
static int nr_bufs = 256;
static int br_mask;

/*
 * Buffer ring belonging to a connection.
 */
struct conn_buf_ring {
    struct io_uring_buf_ring* br;
    void* buf;
    int bgid;
};

struct conn {
    struct conn_buf_ring in_br;

    int tid;
    int in_fd;
    int pending_cancels;
    int flags;

    struct timeval start_time, end_time;
    struct sockaddr_in addr;
};

#define MAX_CONNS 1024
static struct conn conns[MAX_CONNS];

/*
 * User defined data passed between sqe and cqe.
 */

#define OP_SHIFT (12)
#define TID_MASK ((1U << 12) - 1)

struct userdata {
    union {
        struct {
            uint16_t op_tid; /* 3 bits op, 13 bits tid */
            uint16_t fd;
        };
        uint64_t val;
    };
};

static struct conn* cqe_to_conn(struct io_uring_cqe* cqe)
{
    struct userdata ud = { .val = cqe->user_data };

    return &conns[ud.op_tid & TID_MASK];
}

static inline int cqe_to_op(struct io_uring_cqe* cqe)
{
    struct userdata ud = { .val = cqe->user_data };

    return ud.op_tid >> OP_SHIFT;
}

static inline void encode_userdata(struct io_uring_sqe* sqe, int tid, int op, int fd)
{
    struct userdata ud = {
        .op_tid = (op << OP_SHIFT) | tid,
        .fd = fd
    };

    io_uring_sqe_set_data64(sqe, ud.val);
}

enum {
    __ACCEPT = 1,
    __RECV = 2,
    __SEND = 3,
    __CLOSE = 4,
};

static int listening_socket(int port)
{
    int fd;
    int ret;
    int enable; /* enable socket options */
    struct sockaddr_in local_addr;

    memset(&local_addr, '\0', sizeof(local_addr));
    local_addr.sin_family = AF_INET;
    local_addr.sin_port = htons(port);
    local_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd == -1)
        handle_sys_error("socket()", errno);

    enable = 1;
    ret = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));
    if (ret < 0)
        handle_sys_error("setsockopt()", errno);

    ret = bind(fd, (const struct sockaddr*)&local_addr, sizeof(local_addr));
    if (ret < 0)
        handle_sys_error("bind()", errno);

    ret = listen(fd, SOCK_BACKLOG);
    if (ret < 0)
        handle_sys_error("listen()", errno);

    return fd;
}

static struct io_uring_sqe* get_sqe(struct io_uring* ring)
{
    struct io_uring_sqe* sqe;

    do {
        sqe = io_uring_get_sqe(ring);
        if (sqe)
            break;
        else
            /* Free up submission queue space. */
            io_uring_submit(ring);
    } while (1);

    return sqe;
}

/*
 * Setup a ring provided buffer ring for each connection. If we get -ENOBUFS
 * on receive, for multishot receive we'll wait for half the provided buffers
 * to be returned by pendings sends, then re-arm the multishot receive. If
 * this happens too frequently (see enobufs= stat), then the ring size is
 * likely too small, Use -nXX to make it bigger. See handle_enobufs().
 *
 * The alternative here would be to use the older style provided buffers,
 * where you simply setup a buffer group and use SQEs with
 * io_uring_pre_provide_buffers() to add to the pool. But that approach is
 * slower and has been deprecated by using the faster rign provided buffers.
 */
static int setup_recv_rings(struct io_uring* ring, struct conn* c)
{
    struct conn_buf_ring* cbr = &c->in_br;
    int ret, i;
    void* ptr;

    cbr->buf = NULL;

    if (posix_memalign(&cbr->buf, page_size, buf_size * nr_bufs)) {
        fprintf(stderr, "\nposix memalign");
        return 1;
    }

    cbr->br = io_uring_setup_buf_ring(ring, nr_bufs, cbr->bgid, 0, &ret);
    if (!cbr->br) {
        fprintf(stderr, "\nBuffer ring register failed %d\n", ret);
        return 1;
    }

    ptr = cbr->buf;
    for (i = 0; i < nr_bufs; i++) {
        printf("\n%d: add bid %d, data %p", c->tid, i, ptr);
        io_uring_buf_ring_add(cbr->br, ptr, buf_size, i, br_mask, i);
        ptr += buf_size;
    }
    io_uring_buf_ring_advance(cbr->br, nr_bufs);
    printf("\n%d: recv buffer ring bgid %d, bufs %d", c->tid, cbr->bgid, nr_bufs);
    return 0;
}

static void submit_receive(struct io_uring* ring, struct conn* c)
{
    struct conn_buf_ring* cbr = &c->in_br;
    struct io_uring_sqe* sqe;

    printf("\n%d: submit receive fd=%d", c->tid, c->in_fd);

    /*
     * For both recv and multishot receive, we use the ring provided
     * buffers. These are handed to the application ahead of time, and
     * are consued when a receive triggers. Note that the address and
     * length of the receive are set to NUL/0, and we assign the
     * sqe->buf_group to tell the kernel which buffer group ID to pick
     * a buffer from. Finally, IOSQE_BUFFER_SELECT is set to tell the
     * kernel that we want a buffer picked for this request, we are not
     * passing one in with the request.
     */
    sqe = get_sqe(ring);
    io_uring_prep_recv_multishot(sqe, c->in_fd, NULL, 0, 0);

    encode_userdata(sqe, c->tid, __RECV, c->in_fd);
    sqe->buf_group = cbr->bgid;
    sqe->flags |= IOSQE_BUFFER_SELECT;
}

/*
 * We are done with this buffer, add it back to our pool so that the
 * kernel is free to use it again.
 */
static void replenish_buffer(struct conn* c, int bid)
{
    struct conn_buf_ring* cbr = &c->in_br;
    void* this_buf;

    this_buf = cbr->buf + bid + buf_size;
    io_uring_buf_ring_add(cbr->br, this_buf, buf_size, bid, br_mask, 0);
    io_uring_buf_ring_advance(cbr->br, 1);
}

static int handle_accept(struct io_uring* ring, struct io_uring_cqe* cqe)
{
    struct conn* c;

    if (nr_conns == MAX_CONNS) {
        fprintf(stderr, "\nmax clients reached %d", nr_conns);
        return 1;
    }

    c = &conns[nr_conns];
    c->tid = nr_conns++;
    c->in_fd = cqe->res; /* client fd */
    gettimeofday(&c->start_time, NULL);

    printf("\nNew client: id=%d, in=%d", c->tid, c->in_fd);

    if (setup_recv_rings(ring, c))
        return 1;

    submit_receive(ring, c);
    return 0;
}

static int handle_recv(struct io_uring* ring, struct io_uring_cqe* cqe)
{
    struct conn* c;
    struct conn_buf_ring* cbr;
    int bid;
    char* data;

    c = cqe_to_conn(cqe);

    /*
     * Not having a buffer attached should only happen if we get a zero
     * sized receive, because the other end closed the connection. It
     * cannot happen otherwise, as all our receives are using provided
     * buffers and hence it's not possible to return a CQE with a non-zero
     * result and not have a buffer attached.
     */
    /* if(!(cqe->flags & IORING_CQE_F_BUFFER)) { */
    /*   if(!cqe->res) { */
    /*     close_cd */
    /*   } */
    /* } */

    bid = cqe->flags >> IORING_CQE_BUFFER_SHIFT;

    printf("\n%d: recv: bid=%d, res=%d", c->tid, bid, cqe->res);

    /*
     * Retrieve received data.
     */
    cbr = &c->in_br;
    data = malloc(cqe->res + 1);
    memcpy(data, cbr->buf + bid * buf_size, cqe->res);
    data[cqe->res] = '\0';

    printf("\ndata: %s", data);

    replenish_buffer(c, bid);
    free(data);

    /*
     * Re-arm the receive multishot again if terminated.
     */
    if (!(cqe->flags & IORING_CQE_F_MORE))
        submit_receive(ring, c);

    return 0;
}

static int handle_cqe(struct io_uring* ring, struct io_uring_cqe* cqe)
{
    (void)ring;
    int ret = 1;

    if (cqe->res < 0) {
        fprintf(stderr, "\ncqe error");
        return 1;
    }

    switch (cqe_to_op(cqe)) {
    case __ACCEPT:
        ret = handle_accept(ring, cqe);
        break;
    case __RECV:
        ret = handle_recv(ring, cqe);
        break;
    default:
        fprintf(stderr, "bad user data %lx\n", (long)cqe->user_data);
        return 1;
    }

    return ret;
}

static int loop_ioevents(struct io_uring* ring, int fd)
{
    struct __kernel_timespec idle_ts = {
        .tv_sec = 1,
    };

    struct io_uring_sqe* sqe;

    sqe = get_sqe(ring);
    io_uring_prep_multishot_accept(sqe, fd, NULL, NULL, 0);
    encode_userdata(sqe, 0, __ACCEPT, fd);

    while (1) {
        struct io_uring_cqe* cqe;
        unsigned int head;
        int ret, to_wait, i;

        to_wait = 1;
        printf("\nSubmit and wait for %d", to_wait);
        ret = io_uring_submit_and_wait_timeout(ring, &cqe, to_wait, &idle_ts, NULL);
        printf("\nSubmit and wait: %d", ret);

        i = 0;
        io_uring_for_each_cqe(ring, head, cqe)
        {
            if (handle_cqe(ring, cqe))
                return 1;
            i++;
        }

        printf("\nHandled %d events", i);

        /*
         * Advance CQE ring for seen events when we've processed
         * all of them in this loop. This can also be done with
         * io_uring_cqe_seen() in each handler above, which just marks
         * that single CQE as seen. However, it's more efficient to
         * mark a batch as seen when we're done with that batch.
         */
        if (i)
            io_uring_cq_advance(ring, i);
    }

    return 0;
}

int main(int argc, char* argv[])
{
    (void)argv;
    (void)argc;
    struct io_uring ring;
    struct io_uring_params params;
    int fd;
    int ret = 0;

    page_size = sysconf(_SC_PAGESIZE);
    if (page_size < 0) {
        fprintf(stderr, "\nsysconf(_SC_PAGESIZE)");
        return 1;
    }

    br_mask = nr_bufs - 1;

    fd = listening_socket(9000);

    /*
     * Set up a big CQ ring so that we never overflow the SQ ring.
     * Events will not be dropped if this happends, but it does slow
     * the application down in dealing with overflown events.
     *
     * Set SINGLE_ISSUER, which tells the kernel that only one therad
     * is doing IO submissions. This enables certain optimizations in
     * the kernel.
     */
    memset(&params, 0, sizeof(params));
    params.flags |= IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_CLAMP;
    params.flags |= IORING_SETUP_CQSIZE;
    params.cq_entries = 10;
    params.flags |= IORING_SETUP_DEFER_TASKRUN;

    /* int sz = io_uring_mlock_size_params(ring_size, &params); */
    /* printf("\nsz: %d", sz); */

    ret = io_uring_queue_init_params(ring_size, &ring, &params);
    if (ret != 0) {
        fprintf(stderr, "\nio_uring_queue_init_params() failed. %s", strerror(-ret));
        exit(EXIT_FAILURE);
    }

    ret = loop_ioevents(&ring, fd);
    io_uring_queue_exit(&ring);
    /* printf("\ni: %b, %b", 10, 10); */
    exit(ret);
}
