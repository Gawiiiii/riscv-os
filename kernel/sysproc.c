#include "include/syscall.h"
#include "include/printf.h"
#include "include/proc.h"
#include "include/trap.h"
#include "include/vmem.h"
#include "include/memlayout.h"

#define MAX_IO_LEN 4096

int64 sys_fork(void) {
    // Full user-mode fork is not yet supported; return error to callers.
    return -1;
}

int64 sys_exit(void) {
    int status = 0;
    argint(0, &status);
    exit_process(status);
    return 0; // not reached
}

int64 sys_wait(void) {
    uint64 uaddr = 0;
    int status = 0;
    if (argaddr(0, &uaddr) < 0) return -1;
    int pid = wait_process(&status);
    if (pid < 0) return -1;
    if (uaddr != 0) {
        struct proc* p = myproc();
        pagetable_t pt = p ? p->pagetable : NULL;
        if (check_user_ptr(uaddr, sizeof(int)) < 0) return -1;
        if (copyout(pt, uaddr, (char*)&status, sizeof(int)) < 0) return -1;
    }
    return pid;
}

int64 sys_kill(void) {
    int pid = 0;
    if (argint(0, &pid) < 0 || pid <= 0) return -1;
    return kill_process(pid);
}

int64 sys_getpid(void) {
    struct proc* p = myproc();
    if (!p) return -1;
    return p->pid;
}

int64 sys_open(void) {
    uint64 path_addr = 0;
    int flags = 0;
    if (argaddr(0, &path_addr) < 0 || argint(1, &flags) < 0) {
        return -1;
    }
    char path[128];
    if (get_user_string(path_addr, path, sizeof(path)) < 0) {
        return -1;
    }
    (void)flags;
    // File subsystem is not ready; report unimplemented while keeping validation coverage.
    return -1;
}

int64 sys_close(void) {
    int fd = 0;
    if (argint(0, &fd) < 0 || fd < 0) return -1;
    // No file table yet; accept close on stdio descriptors.
    if (fd == 0 || fd == 1 || fd == 2) return 0;
    return -1;
}

int64 sys_read(void) {
    int fd = 0;
    uint64 buf = 0;
    int n = 0;
    if (argint(0, &fd) < 0 || argaddr(1, &buf) < 0 || argint(2, &n) < 0) {
        return -1;
    }
    if (n < 0) return -1;
    if (check_user_ptr(buf, (uint64)n) < 0) return -1;
    // Simple stub: no real input source, return 0 bytes read.
    (void)fd;
    (void)buf;
    return 0;
}

int64 sys_write(void) {
    int fd = 0;
    uint64 buf = 0;
    int n = 0;
    if (argint(0, &fd) < 0 || argaddr(1, &buf) < 0 || argint(2, &n) < 0) {
        return -1;
    }
    if (n < 0) return -1;
    if (check_user_ptr(buf, (uint64)n) < 0) return -1;
    if (n > MAX_IO_LEN) n = MAX_IO_LEN;
    if (fd != 1 && fd != 2) return -1; // stdout/stderr only
    struct proc* p = myproc();
    pagetable_t pt = p ? p->pagetable : NULL;

    const int CHUNK = 256;
    char tmp[CHUNK];
    int written = 0;
    while (written < n) {
        int to_copy = n - written;
        if (to_copy > CHUNK) to_copy = CHUNK;
        if (copyin(pt, tmp, buf + written, (uint64)to_copy) < 0) {
            return -1;
        }
        // printf handles UART output
        printf("%.*s", to_copy, tmp);
        written += to_copy;
    }
    return written;
}

int64 sys_sbrk(void) {
    int n = 0;
    if (argint(0, &n) < 0) return -1;
    struct proc* p = myproc();
    if (!p) return -1;
    uint64 old = p->brk;
    if (n >= 0) {
        uint64 inc = (uint64)n;
        if (p->brk + inc < p->brk) return -1;
        p->brk += inc;
        return old;
    } else {
        // Shrink: keep simple and just move the break down without freeing.
        uint64 dec = (uint64)(-n);
        if (dec > (p->brk - (uint64)KERNBASE)) {
            return -1;
        }
        p->brk -= dec;
        return old;
    }
}

int64 sys_uptime(void) {
    return (int64)timer_ticks();
}

int64 sys_yield(void) {
    yield();
    return 0;
}

int64 sys_sleep(void) {
    int n = 0;
    if (argint(0, &n) < 0 || n < 0) {
        return -1;
    }
    acquire(&ticks_lock);
    uint64 start = ticks;
    while (ticks - start < (uint64)n) {
        sleep((void*)&ticks, &ticks_lock);
        if (myproc() && myproc()->killed) {
            release(&ticks_lock);
            return -1;
        }
    }
    release(&ticks_lock);
    return 0;
}
