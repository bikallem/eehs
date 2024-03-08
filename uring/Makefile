EXE = cat echo shift
CFLAGS = -std=c2x -W -Wall -Wextra -luring -g -O0 \
				 -DDEBUG -fno-omit-frame-pointer -Wno-pointer-arith

RM = rm -f

all: ${EXE}

release: CFLAGS += -O3 -Werror
release: ${EXE}

clean:
	${RM} ${EXE} *.o

