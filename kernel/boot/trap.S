#include "include/trap.h"

.section .text
.globl kernelvec
.globl timervec

# Supervisor trap entry: save context, call C handler, restore and sret
kernelvec:
    addi sp, sp, -TRAPFRAME_SIZE

    sd ra, TF_RA(sp)
    sd t0, TF_T0(sp)
    sd t1, TF_T1(sp)
    sd t2, TF_T2(sp)
    sd t3, TF_T3(sp)
    sd t4, TF_T4(sp)
    sd t5, TF_T5(sp)
    sd t6, TF_T6(sp)

    sd s0, TF_S0(sp)
    sd s1, TF_S1(sp)
    sd s2, TF_S2(sp)
    sd s3, TF_S3(sp)
    sd s4, TF_S4(sp)
    sd s5, TF_S5(sp)
    sd s6, TF_S6(sp)
    sd s7, TF_S7(sp)
    sd s8, TF_S8(sp)
    sd s9, TF_S9(sp)
    sd s10, TF_S10(sp)
    sd s11, TF_S11(sp)

    sd a0, TF_A0(sp)
    sd a1, TF_A1(sp)
    sd a2, TF_A2(sp)
    sd a3, TF_A3(sp)
    sd a4, TF_A4(sp)
    sd a5, TF_A5(sp)
    sd a6, TF_A6(sp)
    sd a7, TF_A7(sp)

    sd gp, TF_GP(sp)
    sd tp, TF_TP(sp)

    addi t0, sp, TRAPFRAME_SIZE   # original sp before trap
    sd t0, TF_SP(sp)

    csrr t0, sepc
    sd t0, TF_SEPC(sp)
    csrr t0, sstatus
    sd t0, TF_SSTATUS(sp)
    csrr t0, stval
    sd t0, TF_STVAL(sp)
    csrr t0, scause
    sd t0, TF_SCAUSE(sp)

    mv a0, sp
    call kerneltrap

    ld t0, TF_SSTATUS(sp)
    csrw sstatus, t0
    ld t0, TF_SEPC(sp)
    csrw sepc, t0

    ld ra, TF_RA(sp)
    ld t0, TF_T0(sp)
    ld t1, TF_T1(sp)
    ld t2, TF_T2(sp)
    ld t3, TF_T3(sp)
    ld t4, TF_T4(sp)
    ld t5, TF_T5(sp)
    ld t6, TF_T6(sp)

    ld s0, TF_S0(sp)
    ld s1, TF_S1(sp)
    ld s2, TF_S2(sp)
    ld s3, TF_S3(sp)
    ld s4, TF_S4(sp)
    ld s5, TF_S5(sp)
    ld s6, TF_S6(sp)
    ld s7, TF_S7(sp)
    ld s8, TF_S8(sp)
    ld s9, TF_S9(sp)
    ld s10, TF_S10(sp)
    ld s11, TF_S11(sp)

    ld a0, TF_A0(sp)
    ld a1, TF_A1(sp)
    ld a2, TF_A2(sp)
    ld a3, TF_A3(sp)
    ld a4, TF_A4(sp)
    ld a5, TF_A5(sp)
    ld a6, TF_A6(sp)
    ld a7, TF_A7(sp)

    ld gp, TF_GP(sp)
    ld tp, TF_TP(sp)

    ld sp, TF_SP(sp)
    sret

# Machine-mode timer vector: re-arm timer and raise SSIP for S-mode
# Scratch layout (per hart):
#   [0] saved t1
#   [1] saved t2
#   [2] saved t3
#   [3] mtimecmp address
#   [4] interval (cycles)
timervec:
    csrrw t0, mscratch, t0    # t0 = scratch pointer, mscratch = old t0
    sd t1, 0(t0)
    sd t2, 8(t0)
    sd t3, 16(t0)

    ld t1, 24(t0)             # mtimecmp address
    ld t2, 32(t0)             # interval
    csrr t3, time             # current time
    add t3, t3, t2
    sd t3, 0(t1)              # program next timer

    li t2, 2                  # SSIP
    csrs sip, t2              # trigger supervisor software interrupt

    ld t1, 0(t0)
    ld t2, 8(t0)
    ld t3, 16(t0)
    csrrw t0, mscratch, t0    # restore original t0 into t0, mscratch=pointer
    mret
