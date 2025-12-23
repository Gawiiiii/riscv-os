// User-mode syscall stubs (mirrors xv6-style usys.pl output)

#include "syscall_numbers.h"

#define SYSCALL(name, num) \
    .global name;          \
name:                      \
    li a7, num;            \
    ecall;                 \
    ret

SYSCALL(fork,   SYS_fork)
SYSCALL(exit,   SYS_exit)
SYSCALL(wait,   SYS_wait)
SYSCALL(kill,   SYS_kill)
SYSCALL(getpid, SYS_getpid)
SYSCALL(open,   SYS_open)
SYSCALL(close,  SYS_close)
SYSCALL(read,   SYS_read)
SYSCALL(write,  SYS_write)
SYSCALL(sbrk,   SYS_sbrk)
SYSCALL(yield,  SYS_yield)
