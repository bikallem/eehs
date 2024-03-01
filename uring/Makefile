EXE = cat echo
CFLAGS = -std=c2x -W -Wall -Wextra -pedantic -luring -g \
				 -DDEBUG -fno-omit-frame-pointer -Wno-pointer-arith
RM = rm -f

all: ${EXE}

release: CFLAGS += -g3 -Werror
release: ${EXE}

clean:
	${RM} ${EXE} *.o

