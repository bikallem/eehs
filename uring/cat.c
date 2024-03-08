#undef _FORTIFY_SOURCE

#include <liburing.h>
#include <linux/io_uring.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#define BUFFER_SIZE 80

int main(int argc, char* argv[])
{
    struct io_uring ring;
    struct io_uring_sqe* sqe;
    struct io_uring_cqe* cqe;
    char buf[BUFFER_SIZE];
    int fd; /* open.txt */
    int ret;

    if (argc < 2) {
        printf("\nUsage: cat [file]");
        exit(EXIT_FAILURE);
    }

    io_uring_queue_init(10, &ring, 0);

    fd = open(argv[1], O_NONBLOCK | O_RDONLY);

    for (;;) {
        if (NULL == (sqe = io_uring_get_sqe(&ring)))
            perror("io_uring_get_sqe() failed.");

        io_uring_prep_read(sqe, fd, buf, BUFFER_SIZE, -1);
        ret = io_uring_submit_and_wait(&ring, 1);
        if (ret <= 0) {
            perror("io_uring_submit_and_wait() failed");
            break;
        }

        if (io_uring_wait_cqe(&ring, &cqe) != 0) {
            perror("io_uring_wait_cqe() failed");
            break;
        }

        io_uring_cqe_seen(&ring, cqe);
        if (cqe->res == 0) {
            printf("\nCOMPLETE");
            break;
        }

        printf("\n%.*s", BUFFER_SIZE, buf);
        fflush(stdout);
        memset(buf, '\000', BUFFER_SIZE);

        if (cqe->res < BUFFER_SIZE)
            break;
    }

    close(fd);
    io_uring_queue_exit(&ring);

    exit(EXIT_SUCCESS);
}
