实验六：进程管理与调度记录

- 上下文切换：`include/proc.h` 定义 `struct context` 仅保存 ra/sp+s0-s11；`kernel/swtch.S` 对应保存/恢复；`proc_entry_wrapper` 首次调度时先 `release(&p->lock)`，避免进程长期持锁。
- 调度器与时钟：`kernel/proc.c` 引入 `time_slice/priority/runtime_ticks/need_resched`，`age_runnable`+`pick_runnable` 在 `scheduler()` 中实现带优先级的轮转并辅以老化避免饥饿；`proc_on_tick` 在时钟中断里递减时间片；`kernel/trap.c::scheduler_tick` 基于 `ticks_lock` 的时钟自增、抢占触发、`wakeup(&ticks)` 用于唤醒睡眠进程。
- 同步原语：`sleep()/wakeup()`（proc.c）使用进程锁保护状态切换，`wait_process` 由忙等改为在父进程 `sleep`，`exit_process` 退出时唤醒父进程；`sys_sleep`（sysproc.c）基于 `ticks_lock` 和时钟 channel 实现阻塞睡眠。
- 调度器测试：`kernel/test_proc.c` 新增 `cpu_intensive_task`（无显式 yield，依赖时钟抢占）、`sleeper_task`（睡眠 3 tick）、`set_proc_priority` 示例展示实时/优先级调度；原有 A/B/brk 测试仍保留。
- 思考题落地
  - 轮转公平性/避免饥饿：固定 `TIME_SLICE_TICKS` 量化 CPU 片段，`priority` 老化定期提升长期就绪的进程（proc.c）。
  - 实时调度：`set_proc_priority` 允许提升关键任务优先级，`scheduler` 优先选择优先级更高且等待更久的进程。
  - 性能优化：上下文切换仅保存被调用者寄存器；`runtime_ticks/last_scheduled` 为后续优化和调度延迟分析提供数据点。
  - 资源管理：`reap_zombies` 清理无父进程的 ZOMBIE，`wait_process` 释放子进程资源；`kill_process` 唤醒沉睡进程防止资源悬挂。
  - 多核/负载均衡：当前默认单核，`Makefile`/QEMU `CPUS` 可尝试多核运行，调度器保持 per-process 时间片与优先级机制，后续可扩展 per-cpu current 指针做负载分配。
