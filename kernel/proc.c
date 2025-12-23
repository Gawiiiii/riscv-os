#include "include/proc.h"
#include "include/pmm.h"
#include "include/printf.h"
#include "include/test.h"
#include "include/trap.h"

static struct proc proc_table[NPROC];
static struct proc* current_proc = NULL;
static int nextpid = 1;
static struct spinlock pid_lock;
static struct context scheduler_ctx;
static uint64 last_aging_tick;
extern char end[];

extern void swtch(struct context*, struct context*);

static void reset_sched_state(struct proc* p);
static void age_runnable(uint64 now);
static struct proc* pick_runnable(uint64 now);

static int alloc_pid(void) {
    int pid;
    acquire(&pid_lock);
    pid = nextpid++;
    release(&pid_lock);
    return pid;
}

void proc_init(void) {
    initlock(&pid_lock, "pid");
    last_aging_tick = 0;
    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        initlock(&p->lock, "proc");
        p->state = PROC_UNUSED;
        p->priority = PRIORITY_DEFAULT;
        p->time_slice = TIME_SLICE_TICKS;
        p->runtime_ticks = 0;
        p->last_scheduled = 0;
        p->need_resched = 0;
    }
}

static void free_kstack(struct proc* p) {
    if (p->kstack) {
        void* base = (void*)PGROUNDDOWN(p->kstack);
        free_page(base);
        p->kstack = 0;
    }
}

void free_process(struct proc* p) {
    if (!p) return;
    if (p->trapframe) {
        free_page(p->trapframe);
        p->trapframe = NULL;
    }
    free_kstack(p);
    p->pagetable = NULL;
    p->entry = NULL;
    p->parent = NULL;
    p->state = PROC_UNUSED;
    p->pid = 0;
    p->xstate = 0;
    p->killed = 0;
    p->chan = NULL;
    p->priority = PRIORITY_DEFAULT;
    p->time_slice = TIME_SLICE_TICKS;
    p->runtime_ticks = 0;
    p->last_scheduled = 0;
    p->need_resched = 0;
    memset(p->name, 0, sizeof(p->name));
}

static void reset_sched_state(struct proc* p) {
    p->priority = PRIORITY_DEFAULT;
    p->time_slice = TIME_SLICE_TICKS;
    p->runtime_ticks = 0;
    p->last_scheduled = timer_ticks();
    p->need_resched = 0;
}

struct proc* alloc_process(void) {
    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        acquire(&p->lock);
        if (p->state != PROC_UNUSED) {
            release(&p->lock);
            continue;
        }
        p->pid = alloc_pid();
        p->state = PROC_USED;

        void* tf = alloc_page();
        void* kstack = alloc_page();
        if (!tf || !kstack) {
            if (tf) free_page(tf);
            if (kstack) free_page(kstack);
            p->state = PROC_UNUSED;
            release(&p->lock);
            return NULL;
        }

        memset(tf, 0, PGSIZE);
        memset(&p->ctx, 0, sizeof(p->ctx));

        p->trapframe = (struct trapframe*)tf;
        p->kstack = (uint64)kstack;
        p->ctx.sp = p->kstack + PGSIZE;
        p->killed = 0;
        p->xstate = 0;
        p->pagetable = NULL;
        p->chan = NULL;
        p->brk = (uint64)end;
        reset_sched_state(p);
        release(&p->lock);
        return p;
    }
    return NULL;
}

static void proc_entry_wrapper(void) {
    struct proc* p = myproc();
    if (!p || !p->entry) {
        panic("proc entry wrapper");
    }
    release(&p->lock);
    intr_on();
    p->entry();
    exit_process(0);
}

int create_process(void (*entry)(void), const char* name) {
    struct proc* p = alloc_process();
    if (!p) return -1;
    acquire(&p->lock);
    p->parent = myproc();
    p->entry = entry;
    if (name) {
        memset(p->name, 0, sizeof(p->name));
        size_t len = strlen(name);
        if (len >= sizeof(p->name)) len = sizeof(p->name) - 1;
        memcpy(p->name, name, len);
    } else {
        memcpy(p->name, "kproc", 5);
    }
    p->priority = p->parent ? p->parent->priority : PRIORITY_DEFAULT;
    p->time_slice = TIME_SLICE_TICKS;
    p->runtime_ticks = 0;
    p->last_scheduled = timer_ticks();
    p->need_resched = 0;
    p->ctx.ra = (uint64)proc_entry_wrapper;
    p->ctx.sp = p->kstack + PGSIZE;
    p->state = PROC_RUNNABLE;
    release(&p->lock);

    return p->pid;
}

int cpuid(void) {
    return (int)r_tp();
}

struct proc* myproc(void) {
    return current_proc;
}

void sched(void) {
    struct proc* p = myproc();
    if (!p) {
        panic("sched: no current proc");
    }
    if (!holding(&p->lock)) {
        panic("sched: lock not held");
    }
    if (intr_get()) {
        panic("sched: interruptible");
    }
    swtch(&p->ctx, &scheduler_ctx);
}

void yield(void) {
    struct proc* p = myproc();
    if (!p) return;
    acquire(&p->lock);
    p->state = PROC_RUNNABLE;
    sched();
    p->time_slice = TIME_SLICE_TICKS;
    p->need_resched = 0;
    release(&p->lock);
}

void sleep(void* chan, struct spinlock* lk) {
    struct proc* p = myproc();
    if (!p) {
        panic("sleep: no proc");
    }
    if (lk == NULL) {
        panic("sleep: null lk");
    }

    if (lk != &p->lock) {
        acquire(&p->lock);
        release(lk);
    }
    p->chan = chan;
    p->state = PROC_SLEEPING;
    p->time_slice = TIME_SLICE_TICKS;
    p->need_resched = 0;
    sched();
    p->chan = NULL;

    if (lk != &p->lock) {
        release(&p->lock);
        acquire(lk);
    } else {
        release(&p->lock);
    }
}

void wakeup(void* chan) {
    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        acquire(&p->lock);
        if (p->state == PROC_SLEEPING && p->chan == chan) {
            p->state = PROC_RUNNABLE;
            p->time_slice = TIME_SLICE_TICKS;
            p->need_resched = 0;
        }
        release(&p->lock);
    }
}

void exit_process(int status) {
    struct proc* p = myproc();
    if (!p) {
        panic("exit with no proc");
    }
    acquire(&p->lock);
    p->xstate = status;
    p->state = PROC_ZOMBIE;
    wakeup(p->parent);
    sched();
    panic("zombie exit");
}

int wait_process(int* status) {
    struct proc* cur = myproc();
    for (;;) {
        for (int i = 0; i < NPROC; i++) {
            struct proc* p = &proc_table[i];
            acquire(&p->lock);
            if (p->parent != cur) {
                release(&p->lock);
                continue;
            }
            if (p->state == PROC_ZOMBIE) {
                int pid = p->pid;
                if (status) *status = p->xstate;
                free_process(p);
                release(&p->lock);
                return pid;
            }
            release(&p->lock);
        }
        // No child exited yet; sleep to avoid busy waiting.
        acquire(&cur->lock);
        int havekids = 0;
        for (int i = 0; i < NPROC; i++) {
            if (proc_table[i].parent == cur) {
                havekids = 1;
                break;
            }
        }
        if (!havekids) {
            release(&cur->lock);
            return -1;
        }
        sleep(cur, &cur->lock);
    }
}

static void age_runnable(uint64 now) {
    if (now - last_aging_tick < SCHED_AGING_TICKS) {
        return;
    }
    last_aging_tick = now;
    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        acquire(&p->lock);
        if (p->state == PROC_RUNNABLE && p->priority > PRIORITY_MIN) {
            p->priority--;
        }
        release(&p->lock);
    }
}

static struct proc* pick_runnable(uint64 now) {
    struct proc* best = NULL;
    int best_pri = 0x7fffffff;
    uint64 best_stamp = 0;

    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        acquire(&p->lock);
        if (p->state == PROC_RUNNABLE) {
            int pri = p->priority;
            uint64 stamp = p->last_scheduled;
            if (!best || pri < best_pri || (pri == best_pri && stamp <= best_stamp)) {
                if (best) {
                    release(&best->lock);
                }
                best = p;
                best_pri = pri;
                best_stamp = stamp;
                continue;
            }
        }
        release(&p->lock);
    }
    return best;
}

static void reap_zombies(void) {
    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        acquire(&p->lock);
        if (p->state == PROC_ZOMBIE && p->parent == NULL) {
            free_process(p);
            release(&p->lock);
            continue;
        }
        release(&p->lock);
    }
}

void scheduler(void) {
    for (;;) {
        intr_on();
        uint64 now = timer_ticks();
        age_runnable(now);
        reap_zombies();

        struct proc* p = pick_runnable(now);
        if (p != NULL) {
            p->state = PROC_RUNNING;
            p->time_slice = TIME_SLICE_TICKS;
            p->need_resched = 0;
            p->last_scheduled = now;
            current_proc = p;
            swtch(&scheduler_ctx, &p->ctx);
            current_proc = NULL;
            release(&p->lock);
        } else {
            // idle: halt a bit to avoid busy looping
            asm volatile("wfi");
        }
    }
}

void proc_on_tick(void) {
    struct proc* p = myproc();
    if (!p) return;
    acquire(&p->lock);
    p->runtime_ticks++;
    if (p->time_slice > 0) {
        p->time_slice--;
        if (p->time_slice == 0) {
            p->need_resched = 1;
        }
    }
    release(&p->lock);
}

int set_proc_priority(int pid, int new_priority) {
    if (new_priority < PRIORITY_MIN) {
        new_priority = PRIORITY_MIN;
    }
    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        acquire(&p->lock);
        if (p->pid == pid && p->state != PROC_UNUSED) {
            p->priority = new_priority;
            p->time_slice = TIME_SLICE_TICKS;
            release(&p->lock);
            return 0;
        }
        release(&p->lock);
    }
    return -1;
}

void procdump(void) {
    printf("[proc] dump\n");
    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        acquire(&p->lock);
        if (p->state != PROC_UNUSED) {
            printf(" pid=%d state=%d prio=%d slice=%d run=%lu name=%s\n",
                   p->pid, p->state, p->priority, p->time_slice,
                   p->runtime_ticks, p->name);
        }
        release(&p->lock);
    }
}

int kill_process(int pid) {
    for (int i = 0; i < NPROC; i++) {
        struct proc* p = &proc_table[i];
        acquire(&p->lock);
        if (p->pid == pid && p->state != PROC_UNUSED) {
            p->killed = 1;
            if (p->state == PROC_SLEEPING) {
                p->state = PROC_RUNNABLE;
                p->chan = NULL;
                p->time_slice = TIME_SLICE_TICKS;
                p->need_resched = 0;
            }
            release(&p->lock);
            return 0;
        }
        release(&p->lock);
    }
    return -1;
}
