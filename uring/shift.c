#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static bool str_to_uint16_t(const char* str, uint16_t* v)
{
    char* end;
    errno = 0;
    intmax_t val = strtoimax(str, &end, 10);
    if (errno == ERANGE || end == str || *end != '\0' || val < 0 || val >= UINT16_MAX)
        return false;
    *v = (uint16_t)val;
    return true;
}

int main(int argc, char* argv[])
{
    (void)argc;
    (void)argv;
    uint16_t op;
    uint16_t tid;
    uint16_t op_shifted;
    uint16_t op_shifted_minus1;
    uint16_t op_tid;
    char bits[16 + 1];
    size_t sz;

    sz = sizeof(bits);

    if (argc < 3) {
        fprintf(stderr, "\nUsage: shift OP TID");
        return 1;
    }

    if (!str_to_uint16_t(argv[1], &op)) {
        fprintf(stderr, "\nInvalid op argument");
        return 1;
    }

    if (!str_to_uint16_t(argv[2], &tid)) {
        fprintf(stderr, "\nInvalid tid argument");
        return 1;
    }

    snprintf(bits, sz, "%016b", op);
    printf("\nop %d\t\t: %s", op, bits);
    printf("\nop %d\t\t: %016b", op-1, op-1);

    snprintf(bits, sz, "%016b", tid);
    printf("\ntid %d\t: %s", tid, bits);

    op_shifted = (op << 12);
    snprintf(bits, sz, "%016b", op_shifted);
    printf("\n(%dU << 12)\t: %s %d", op, bits, op_shifted);
    op_shifted_minus1 = (1U << 12) - 1;
    printf("\n(%dU << 12)-1\t: %016b %d", 1, op_shifted_minus1, op_shifted_minus1);

    op_tid = (op_shifted | tid);
    snprintf(bits, sz, "%016b", op_tid);
    printf("\nop_tid %d\t: %s", op_tid, bits);

    return 0;
}
