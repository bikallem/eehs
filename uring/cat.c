#include <linux/io_uring.h>
#include <liburing.h>
#include <stdlib.h>
#include <sys/types.h>
#include <stdio.h>

#define BUFFER_SIZE 50

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

	if (NULL == (sqe = io_uring_get_sqe(&ring)))
		perror("io_uring_get_sqe() failed.");

	io_uring_prep_read(sqe, fd, buf, BUFFER_SIZE, -1);

	/* wait for the sqe to complete. */
	/* __kernel_timespec */

	for (;;) {
		ret = io_uring_submit_and_wait(&ring, 1);
		if (ret <= 0) {
			perror("io_uring_submit_and_wait() failed");
			break;
		}

		/* printf("\nret: %d", ret); */

		if (io_uring_wait_cqe(&ring, &cqe) != 0) {
			perror("io_uring_wait_cqe() failed");
			break;
		}

		if (cqe->res == 0) {
			printf("\nCOMPLETE");
			break;
		}

		/* prepare next read request. */
		if (NULL == (sqe = io_uring_get_sqe(&ring)))
			perror("io_uring_get_sqe() failed.");

		if (cqe->res == BUFFER_SIZE) {
			printf("\n%.*s", BUFFER_SIZE, buf);
			fflush(stdout);

			got += cqe->res;
			io_uring_prep_read(sqe, fd, buf, BUFFER_SIZE, got);
			io_uring_cqe_seen(&ring, cqe);
		} else {
			break;
		}
	}

	close(fd);
	io_uring_queue_exit(&ring);

	exit(EXIT_SUCCESS);
}
