#ifndef _SPINLOCK_H_
#define _SPINLOCK_H_

#include "common.h"

// Very small spinlock for uniprocessor-friendly critical sections.
// We still keep the interface close to xv6 for future expansion.
struct spinlock {
    uint32 locked;      // 0 -> unlocked, 1 -> locked
    const char* name;   // optional name for debug
};

void initlock(struct spinlock* lk, const char* name);
void acquire(struct spinlock* lk);
void release(struct spinlock* lk);
int  holding(struct spinlock* lk);

// Interrupt nesting helpers (match xv6 semantics)
void push_off(void);
void pop_off(void);

#endif // _SPINLOCK_H_
