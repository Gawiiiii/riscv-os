#include "include/syscall.h"
#include "include/printf.h"
#include "include/proc.h"
#include "include/trap.h"
#include "include/vmem.h"

static struct trapframe* current_tf;
int debug_syscalls = 0;

// Forward declarations for unimplemented handlers
static int64 sys_unimpl(void);

const char* syscall_names[SYS_MAX] = {
    [SYS_none]   = "none",
    [SYS_fork]   = "fork",
    [SYS_exit]   = "exit",
    [SYS_wait]   = "wait",
    [SYS_pipe]   = "pipe",
    [SYS_read]   = "read",
    [SYS_kill]   = "kill",
    [SYS_exec]   = "exec",
    [SYS_fstat]  = "fstat",
    [SYS_chdir]  = "chdir",
    [SYS_dup]    = "dup",
    [SYS_getpid] = "getpid",
    [SYS_sbrk]   = "sbrk",
    [SYS_sleep]  = "sleep",
    [SYS_uptime] = "uptime",
    [SYS_open]   = "open",
    [SYS_write]  = "write",
    [SYS_mknod]  = "mknod",
    [SYS_unlink] = "unlink",
    [SYS_link]   = "link",
    [SYS_mkdir]  = "mkdir",
    [SYS_close]  = "close",
    [SYS_yield]  = "yield",
};

const struct syscall_desc syscall_table[SYS_MAX] = {
    [SYS_fork]   = {sys_fork, "fork", 0},
    [SYS_exit]   = {sys_exit, "exit", 1},
    [SYS_wait]   = {sys_wait, "wait", 1},
    [SYS_pipe]   = {sys_unimpl, "pipe", 1},
    [SYS_read]   = {sys_read, "read", 3},
    [SYS_kill]   = {sys_kill, "kill", 2},
    [SYS_exec]   = {sys_unimpl, "exec", 2},
    [SYS_fstat]  = {sys_unimpl, "fstat", 2},
    [SYS_chdir]  = {sys_unimpl, "chdir", 1},
    [SYS_dup]    = {sys_unimpl, "dup", 1},
    [SYS_getpid] = {sys_getpid, "getpid", 0},
    [SYS_sbrk]   = {sys_sbrk, "sbrk", 1},
    [SYS_sleep]  = {sys_sleep, "sleep", 1},
    [SYS_uptime] = {sys_uptime, "uptime", 0},
    [SYS_open]   = {sys_open, "open", 2},
    [SYS_write]  = {sys_write, "write", 3},
    [SYS_mknod]  = {sys_unimpl, "mknod", 3},
    [SYS_unlink] = {sys_unimpl, "unlink", 1},
    [SYS_link]   = {sys_unimpl, "link", 2},
    [SYS_mkdir]  = {sys_unimpl, "mkdir", 1},
    [SYS_close]  = {sys_close, "close", 1},
    [SYS_yield]  = {sys_yield, "yield", 0},
};

static struct trapframe* active_trapframe(void) {
    if (current_tf) {
        return current_tf;
    }
    struct proc* p = myproc();
    if (p) {
        return p->trapframe;
    }
    return NULL;
}

static pagetable_t active_pagetable(void) {
    struct proc* p = myproc();
    return p ? p->pagetable : NULL;
}

static uint64 arg_raw(int n) {
    if (n < 0 || n > 5) return (uint64)-1;
    struct trapframe* tf = active_trapframe();
    if (!tf) {
        return (uint64)-1;
    }
    switch (n) {
        case 0: return tf->a0;
        case 1: return tf->a1;
        case 2: return tf->a2;
        case 3: return tf->a3;
        case 4: return tf->a4;
        case 5: return tf->a5;
        default:
            return (uint64)-1;
    }
}

int get_syscall_arg(int n, uint64* ip) {
    if (!ip) return -1;
    uint64 val = arg_raw(n);
    if (val == (uint64)-1 && !active_trapframe()) return -1;
    *ip = val;
    return 0;
}

int argint(int n, int* ip) {
    if (!ip) return -1;
    uint64 val = 0;
    if (get_syscall_arg(n, &val) < 0) return -1;
    *ip = (int)val;
    return 0;
}

int argaddr(int n, uint64* ip) {
    if (!ip) return -1;
    return get_syscall_arg(n, ip);
}

int argstr(int n, char* buf, int max) {
    if (!buf || max <= 0) return -1;
    uint64 addr = 0;
    if (argaddr(n, &addr) < 0) return -1;
    return get_user_string(addr, buf, max);
}

int check_user_ptr(uint64 uaddr, uint64 size) {
    pagetable_t pt = active_pagetable();
    return user_access_ok(pt, uaddr, size) ? 0 : -1;
}

int get_user_string(uint64 uaddr, char* buf, int max) {
    if (!buf || max <= 0) return -1;
    if (check_user_ptr(uaddr, 1) < 0) return -1;
    return copyinstr(active_pagetable(), buf, uaddr, (uint64)max);
}

int get_user_buffer(uint64 uaddr, void* buf, int size) {
    if (!buf || size < 0) return -1;
    if (size == 0) return 0;
    if (check_user_ptr(uaddr, (uint64)size) < 0) return -1;
    return copyin(active_pagetable(), buf, uaddr, (uint64)size);
}

void syscall_dispatch(struct trapframe* tf) {
    if (!tf) {
        panic("[syscall] missing trapframe");
    }
    int num = (int)tf->a7;
    tf->a0 = -1;
    current_tf = tf;
    if (num > 0 && num < SYS_MAX) {
        const struct syscall_desc* desc = &syscall_table[num];
        if (desc->func && desc->arg_count >= 0 && desc->arg_count <= 6) {
            int64 ret = desc->func();
            tf->a0 = ret;
            if (debug_syscalls) {
                const char* name = desc->name ? desc->name : "unknown";
                printf("[syscall] pid=%d nr=%d (%s) -> %ld\n",
                       myproc() ? myproc()->pid : -1, num, name, ret);
            }
        } else {
            printf("[syscall] invalid entry nr=%d sepc=0x%lx\n", num, tf->sepc);
        }
    } else {
        printf("[syscall] unknown num=%d sepc=0x%lx\n", num, tf->sepc);
    }
    current_tf = NULL;
    tf->sepc += 4; // advance past ecall
}

static int64 sys_unimpl(void) {
    return -1;
}
