#include <linux/io_uring.h>
#include <liburing.h>
#include <stdlib.h>
#include <sys/types.h>
#include <stdio.h>

#define BUFFER_SIZE 1024

int main(int argc, char *argv[])
{
	struct io_uring ring;
	struct io_uring_sqe *sqe;
	struct io_uring_cqe *cqe;
	char buf[BUFFER_SIZE];

	int fd; /* open.txt */

	fd = open("hello.txt", O_NONBLOCK | O_RDONLY);
	io_uring_queue_init(10, &ring, 0);

	if (NULL == (sqe = io_uring_get_sqe(&ring)))
		perror("io_uring_get_sqe() failed.");

	io_uring_prep_read(sqe, fd, buf, BUFFER_SIZE, 0);
	io_uring_submit(&ring);

	/* wait for the sqe to complete. */
	io_uring_wait_cqe(&ring, &cqe);

	printf("%.*s", BUFFER_SIZE, buf);

	close(fd);
	io_uring_queue_exit(&ring);

	exit(EXIT_SUCCESS);
}
