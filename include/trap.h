#ifndef _TRAP_H_
#define _TRAP_H_

#define IRQ_S_SOFTWARE 1
#define IRQ_S_TIMER    5
#define IRQ_S_EXTERNAL 9
#define IRQ_MAX        16

// Trapframe field offsets (bytes) for assembly/C cooperation
#define TF_RA       0
#define TF_SP       8
#define TF_GP       16
#define TF_TP       24
#define TF_T0       32
#define TF_T1       40
#define TF_T2       48
#define TF_S0       56
#define TF_S1       64
#define TF_A0       72
#define TF_A1       80
#define TF_A2       88
#define TF_A3       96
#define TF_A4       104
#define TF_A5       112
#define TF_A6       120
#define TF_A7       128
#define TF_S2       136
#define TF_S3       144
#define TF_S4       152
#define TF_S5       160
#define TF_S6       168
#define TF_S7       176
#define TF_S8       184
#define TF_S9       192
#define TF_S10      200
#define TF_S11      208
#define TF_T3       216
#define TF_T4       224
#define TF_T5       232
#define TF_T6       240
#define TF_SEPC     248
#define TF_SSTATUS  256
#define TF_STVAL    264
#define TF_SCAUSE   272
#define TF_PAD      280
#define TRAPFRAME_SIZE 288

#ifndef __ASSEMBLER__
#include "types.h"
#include "spinlock.h"

typedef void (*interrupt_handler_t)(void);

struct trapframe {
    uint64 ra;
    uint64 sp;
    uint64 gp;
    uint64 tp;
    uint64 t0;
    uint64 t1;
    uint64 t2;
    uint64 s0;
    uint64 s1;
    uint64 a0;
    uint64 a1;
    uint64 a2;
    uint64 a3;
    uint64 a4;
    uint64 a5;
    uint64 a6;
    uint64 a7;
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
    uint64 t3;
    uint64 t4;
    uint64 t5;
    uint64 t6;
    uint64 sepc;
    uint64 sstatus;
    uint64 stval;
    uint64 scause;
    uint64 pad; // keep 16-byte alignment
};

void trap_init(void);
void register_interrupt(int irq, interrupt_handler_t h);
void enable_interrupt(int irq);
void disable_interrupt(int irq);

uint64 get_time(void);
void sbi_set_timer(uint64 time);
uint64 timer_ticks(void);
int get_timer_interrupt_count(void);
extern uint64 ticks;
extern struct spinlock ticks_lock;

void kerneltrap(struct trapframe* tf);
void timer_interrupt(void);

#endif // __ASSEMBLER__
#endif // _TRAP_H_
