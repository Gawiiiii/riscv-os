#include "include/trap.h"
#include "include/printf.h"
#include "include/riscv.h"
#include "include/syscall.h"
#include "include/proc.h"
#include "include/spinlock.h"

extern void kernelvec(void);

// IRQ handlers table
static interrupt_handler_t irq_table[IRQ_MAX];
uint64 ticks;
static volatile int timer_interrupt_count;
struct spinlock ticks_lock;

static void handle_exception(struct trapframe* tf);
static void scheduler_tick(uint64 now);

void register_interrupt(int irq, interrupt_handler_t h) {
    if (irq < 0 || irq >= IRQ_MAX) {
        printf("[trap] ignore invalid irq %d\n", irq);
        return;
    }
    irq_table[irq] = h;
}

void enable_interrupt(int irq) {
    if (irq < 0 || irq >= IRQ_MAX) return;
    uint64 mask = 1UL << irq;
    w_sie(r_sie() | mask);
}

void disable_interrupt(int irq) {
    if (irq < 0 || irq >= IRQ_MAX) return;
    uint64 mask = 1UL << irq;
    w_sie(r_sie() & ~mask);
}

uint64 get_time(void) {
    return r_time();
}

// Directly program mtimecmp (hart0) to approximate the SBI timer service.
void sbi_set_timer(uint64 time) {
    uint64 hart = r_tp();
    volatile uint64* mtimecmp = (uint64*)(0x02004000UL + 8 * hart);
    *mtimecmp = time;
}

uint64 timer_ticks(void) {
    uint64 t;
    acquire(&ticks_lock);
    t = ticks;
    release(&ticks_lock);
    return t;
}

void timer_interrupt(void) {
    acquire(&ticks_lock);
    ticks++;
    uint64 now = ticks;
    release(&ticks_lock);
    timer_interrupt_count++;
    scheduler_tick(now);
    wakeup((void*)&ticks);
    // Clear SSIP raised by machine timer bridge
    w_sip(r_sip() & ~SIE_SSIE);
}

void trap_init(void) {
    w_stvec((uint64)kernelvec);
    initlock(&ticks_lock, "ticks");
    register_interrupt(IRQ_S_SOFTWARE, timer_interrupt);
    enable_interrupt(IRQ_S_SOFTWARE);
}

void kerneltrap(struct trapframe* tf) {
    uint64 scause = tf->scause;
    uint64 sstatus = r_sstatus();
    struct proc* p = myproc();
    if (p) {
        p->trapframe = tf;
    }
    if ((sstatus & SSTATUS_SPP) == 0) {
        panic("kerneltrap: not from supervisor");
    }

    if (scause & (1ULL << 63)) {
        int irq = (int)(scause & 0xff);
        if (irq >= 0 && irq < IRQ_MAX && irq_table[irq]) {
            irq_table[irq]();
        } else {
            printf("[trap] unhandled interrupt %d (scause=0x%lx)\n", irq, scause);
        }
    } else {
        handle_exception(tf);
    }
}

static void handle_syscall(struct trapframe* tf) {
    syscall_dispatch(tf);
}

static void handle_instruction_page_fault(struct trapframe* tf) {
    printf("[trap] instruction page fault @0x%lx\n", tf->stval);
    panic("instruction page fault");
}

static void handle_load_page_fault(struct trapframe* tf) {
    printf("[trap] load page fault @0x%lx\n", tf->stval);
    panic("load page fault");
}

static void handle_store_page_fault(struct trapframe* tf) {
    printf("[trap] store page fault @0x%lx\n", tf->stval);
    panic("store page fault");
}

static void handle_exception(struct trapframe* tf) {
    uint64 cause = tf->scause;
    switch (cause) {
        case 8:
            handle_syscall(tf);
            break;
        case 12:
            handle_instruction_page_fault(tf);
            break;
        case 13:
            handle_load_page_fault(tf);
            break;
        case 15:
            handle_store_page_fault(tf);
            break;
        default:
            printf("[trap] unknown exception cause=%lu sepc=0x%lx stval=0x%lx\n",
                   cause, tf->sepc, tf->stval);
            panic("Unknown exception");
    }
}

static void scheduler_tick(uint64 now) {
    proc_on_tick();
    struct proc* p = myproc();
    if (p && p->state == PROC_RUNNING && p->need_resched) {
        if (!holding(&p->lock)) {
            yield();
        }
    }
    if ((now % 1000) == 0) {
        printf("[sched] %lu ticks elapsed\n", now);
    }
}

int get_timer_interrupt_count(void) {
    return timer_interrupt_count;
}
