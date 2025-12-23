#include "include/printf.h"
#include "include/proc.h"
#include "include/test.h"
#include "include/syscall.h"
#include "include/trap.h"

static void simple_task_a(void) {
    for (int i = 0; i < 3; i++) {
        printf("[proc] task A iter %d\n", i);
        yield();
    }
    printf("[proc] task A exit\n");
    exit_process(0);
}

static void simple_task_b(void) {
    for (int i = 0; i < 2; i++) {
        printf("[proc] task B iter %d\n", i);
        yield();
    }
    printf("[proc] task B exit\n");
    exit_process(0);
}

static void cpu_intensive_task(void) {
    uint64 start = timer_ticks();
    for (volatile int i = 0; i < 200000; i++) {
        if (i % 50000 == 0) {
            printf("[proc] busy iter %d\n", i);
        }
    }
    uint64 end = timer_ticks();
    printf("[proc] busy ran for %lu ticks\n", end - start);
    exit_process(0);
}

static void sleeper_task(void) {
    printf("[proc] sleeper waiting 3 ticks\n");
    acquire(&ticks_lock);
    uint64 target = ticks + 3;
    while (ticks < target) {
        sleep((void*)&ticks, &ticks_lock);
    }
    release(&ticks_lock);
    printf("[proc] sleeper wakeup\n");
    exit_process(0);
}

// Simulate the provided initcode.c brk/sbrk sequence via syscall_dispatch.
// We drive sys_sbrk through a synthetic trapframe while running as a kernel task.
static void syscall_brk_task(void) {
    struct trapframe tf;
    memset(&tf, 0, sizeof(tf));

    printf("[syscall-test] brk/sbrk sequence start\n");

    // Step 1: brk(0) equivalent -> use sbrk(0) to read current break.
    tf.a7 = SYS_sbrk;
    tf.a0 = 0;
    syscall_dispatch(&tf);
    uint64 heap_top = tf.a0;
    printf("[syscall-test] brk(0) -> 0x%lx\n", heap_top);

    // Step 2: brk(heap_top + 10 pages) => sbrk(+10 pages)
    int inc_up = 4096 * 10;
    tf.a0 = inc_up;
    tf.sepc = 0; // reset for readability
    syscall_dispatch(&tf);
    uint64 new_top = tf.a0 + inc_up; // sbrk returns old break
    printf("[syscall-test] brk(+10 pages) old=0x%lx new=0x%lx\n", tf.a0, new_top);

    // Step 3: brk(new_top - 5 pages) => sbrk(-5 pages)
    int inc_down = -4096 * 5;
    tf.a0 = inc_down;
    tf.sepc = 0;
    syscall_dispatch(&tf);
    uint64 final_top = new_top + inc_down;
    printf("[syscall-test] brk(-5 pages) old=0x%lx new=0x%lx\n", tf.a0, final_top);

    // Keep the task alive briefly to mirror the infinite loop in initcode.
    for (int i = 0; i < 3; i++) {
        yield();
    }
    printf("[syscall-test] brk/sbrk sequence done\n");
    exit_process(0);
}

void test_process_subsystem(void) {
    printf("[test] process subsystem start\n");
    proc_init();

    int pid_brk = create_process(syscall_brk_task, "brkTest");
    int pid1 = create_process(simple_task_a, "taskA");
    int pid2 = create_process(simple_task_b, "taskB");
    int pid_busy = create_process(cpu_intensive_task, "busy");
    int pid_sleep = create_process(sleeper_task, "sleepy");
    if (pid_brk < 0 || pid1 < 0 || pid2 < 0 || pid_busy < 0 || pid_sleep < 0) {
        panic("[proc] create_process failed");
    }
    set_proc_priority(pid_busy, 3);   // mimic a higher-priority, latency-sensitive task
    set_proc_priority(pid_sleep, 12); // keep sleeper low priority to show aging/wakeup

    printf("[test] created pids: %d, %d, %d, %d, %d (enter scheduler)\n",
           pid_brk, pid1, pid2, pid_busy, pid_sleep);
    scheduler(); // never returns
}
