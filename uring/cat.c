#include <linux/io_uring.h>
#include <liburing.h>
#include <stdlib.h>
#include <sys/types.h>
#include <stdio.h>
#include <string.h>

#define BUFFER_SIZE 80

int main(int argc, char *argv[])
{
	struct io_uring ring;
	struct io_uring_sqe *sqe;
	struct io_uring_cqe *cqe;
	char buf[BUFFER_SIZE];
	int fd; /* open.txt */
	int ret;
	int got = 0;

	fd = open("hello.txt", O_NONBLOCK | O_RDONLY);
	io_uring_queue_init(10, &ring, 0);

	/* wait for the sqe to complete. */
	/* __kernel_timespec */

	for (;;) {
		if (NULL == (sqe = io_uring_get_sqe(&ring)))
			perror("io_uring_get_sqe() failed.");

		io_uring_prep_read(sqe, fd, buf, BUFFER_SIZE, got);
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

		got += cqe->res;
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
