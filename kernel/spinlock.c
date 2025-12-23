#include "include/spinlock.h"
#include "include/riscv.h"
#include "include/printf.h"

// Per-hart interrupt nesting depth.
struct cpu_local_state {
    int noff;
    int intena;
};

// In this lab OS we run single-core by default, so store a single slot.
static struct cpu_local_state cpu_state = {0, 0};

static inline struct cpu_local_state* local_state(void) {
    return &cpu_state;
}

void initlock(struct spinlock* lk, const char* name) {
    lk->locked = 0;
    lk->name = name;
}

int holding(struct spinlock* lk) {
    return lk->locked != 0;
}

void acquire(struct spinlock* lk) {
    push_off();
    while (__sync_lock_test_and_set(&lk->locked, 1) != 0) {
        // spin
    }
    __sync_synchronize();
}

void release(struct spinlock* lk) {
    __sync_synchronize();
    lk->locked = 0;
    pop_off();
}

void push_off(void) {
    int old = intr_get();
    intr_off();
    struct cpu_local_state* st = local_state();
    if (st->noff == 0) {
        st->intena = old;
    }
    st->noff += 1;
}

void pop_off(void) {
    struct cpu_local_state* st = local_state();
    if (intr_get()) {
        panic("pop_off - interruptible");
    }
    if (st->noff < 1) {
        panic("pop_off");
    }
    st->noff -= 1;
    if (st->noff == 0 && st->intena) {
        intr_on();
    }
}
