#ifndef _PROC_H_
#define _PROC_H_

#include "common.h"
#include "riscv.h"
#include "param.h"
#include "spinlock.h"

struct trapframe;

// Saved registers for kernel context switches.
struct context {
    uint64 ra;
    uint64 sp;

    // Callee-saved registers
    uint64 s0;
    uint64 s1;
    uint64 s2;
    uint64 s3;
    uint64 s4;
    uint64 s5;
    uint64 s6;
    uint64 s7;
    uint64 s8;
    uint64 s9;
    uint64 s10;
    uint64 s11;
};

enum procstate {
    PROC_UNUSED = 0,
    PROC_USED,
    PROC_RUNNABLE,
    PROC_RUNNING,
    PROC_SLEEPING,
    PROC_ZOMBIE,
};

struct proc {
    struct spinlock lock;
    enum procstate state;

    void* chan;          // sleep channel (unused for now)
    int killed;
    int xstate;
    int pid;

    // address space
    pagetable_t pagetable;       // user page table (reserved for later)
    struct trapframe* trapframe; // user trap frame (reserved for later)
    uint64 brk;                  // simple sbrk pointer
    uint64 runtime_ticks;        // accumulated runtime in timer ticks
    uint64 last_scheduled;       // last time scheduled (ticks)
    int    priority;             // lower value => higher priority
    int    time_slice;           // remaining ticks in current slice
    int    need_resched;         // set by timer tick for preemption

    // kernel execution context
    uint64 kstack;       // kernel stack base (physical/identity-mapped)
    struct context ctx;  // swtch() context

    struct proc* parent;
    void (*entry)(void); // kernel task entry
    char name[16];
};

void        proc_init(void);
struct proc* alloc_process(void);
void        free_process(struct proc* p);
int         create_process(void (*entry)(void), const char* name);
void        exit_process(int status) __attribute__((noreturn));
int         wait_process(int* status);
void        scheduler(void) __attribute__((noreturn));
void        sched(void);
void        yield(void);
void        sleep(void* chan, struct spinlock* lk);
void        wakeup(void* chan);
void        proc_on_tick(void);
struct proc* myproc(void);
int         cpuid(void);
void        procdump(void);
int         kill_process(int pid);
int         set_proc_priority(int pid, int new_priority);

#endif // _PROC_H_
