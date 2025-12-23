#ifndef _SYSCALL_H_
#define _SYSCALL_H_

#include "common.h"
#include "types.h"
#include "trap.h"
#include "riscv.h"

#ifndef __user
#define __user
#endif

// System call descriptor
struct syscall_desc {
    int64 (*func)(void);
    const char* name;
    int arg_count;
};

// System call numbers (aligned with xv6 where possible)
enum syscall_num {
    SYS_none = 0,
    SYS_fork = 1,
    SYS_exit = 2,
    SYS_wait = 3,
    SYS_pipe = 4,
    SYS_read = 5,
    SYS_kill = 6,
    SYS_exec = 7,
    SYS_fstat = 8,
    SYS_chdir = 9,
    SYS_dup = 10,
    SYS_getpid = 11,
    SYS_sbrk = 12,
    SYS_sleep = 13,
    SYS_uptime = 14,
    SYS_open = 15,
    SYS_write = 16,
    SYS_mknod = 17,
    SYS_unlink = 18,
    SYS_link = 19,
    SYS_mkdir = 20,
    SYS_close = 21,
    SYS_yield = 22,
    SYS_MAX
};

extern const struct syscall_desc syscall_table[SYS_MAX];

// Dispatcher entry
void syscall_dispatch(struct trapframe* tf);

// Argument helpers (operate on the current trapframe)
int get_syscall_arg(int n, uint64* ip);
int argint(int n, int* ip);
int argaddr(int n, uint64* ip);
int argstr(int n, char* buf, int max);

// User memory helpers
int user_access_ok(pagetable_t pagetable, uint64 va, uint64 len);
int copyin(pagetable_t pagetable, char* dst, uint64 srcva, uint64 len);
int copyout(pagetable_t pagetable, uint64 dstva, const char* src, uint64 len);
int copyinstr(pagetable_t pagetable, char* dst, uint64 srcva, uint64 max);
int check_user_ptr(uint64 uaddr, uint64 size);
int get_user_string(uint64 uaddr, char* buf, int max);
int get_user_buffer(uint64 uaddr, void* buf, int size);

// Basic syscall implementations
int64 sys_fork(void);
int64 sys_exit(void);
int64 sys_wait(void);
int64 sys_kill(void);
int64 sys_getpid(void);
int64 sys_open(void);
int64 sys_close(void);
int64 sys_read(void);
int64 sys_write(void);
int64 sys_sbrk(void);
int64 sys_uptime(void);
int64 sys_yield(void);
int64 sys_sleep(void);

extern int debug_syscalls;
extern const char* syscall_names[SYS_MAX];

#endif // _SYSCALL_H_
