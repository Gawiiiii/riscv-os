# RISC-V 操作系统实践（Sv39 & PMM 版本）

## 概述
- 三阶段启动：`entry.S` → `start.c`（Machine 模式）→ `kmain.c`（Supervisor 模式）
- 物理页分配器：`pmm_init / alloc_page / free_page / alloc_pages`，自测验证页面分配/回收
- Sv39 页表：`create_pagetable / walk_create / walk_lookup / map_page / destroy_pagetable / dump_pagetable`
- 内核页表映射：代码段 R+X，数据/BSS/栈 R+W，剩余物理内存 R+W，UART 等设备恒等映射
- 分页激活：写入 `satp` + `sfence.vma`
- 进程调度：基于 `TIME_SLICE_TICKS` 的抢占式轮转，支持优先级与老化（`set_proc_priority/age_runnable`），`runtime_ticks/last_scheduled` 记录运行时间；`wait_process/sleep/wakeup` 避免忙等，`proc_on_tick` 由时钟中断驱动抢占
- 系统调用骨架：`include/syscall.h` + `kernel/syscall.c/sysproc.c` 提供分发表、参数提取器与基础 syscalls（getpid/uptime/yield/exit/wait/sleep），其余占位返回 -1，`trap.c` 在 scause=8 时进入分发器
- 用户态访问辅助：`kernel/uaccess.c` 提供 `copyin/copyout/copyinstr`，基于页表翻译+用户地址检查，默认仅接受 <KERNBASE 的地址；无用户页表时回退为直接访问（便于内核态自测）
- 自测用例：`test_physical_memory / test_pagetable / test_virtual_memory / test_timer_interrupt / test_process_subsystem`，运行时打印关键日志
- 中断/异常：Machine 定时器在 M 模式重装并通过 SSIP 交给 S 模式；S 模式 `stvec=kernelvec`，`trap_init` 负责注册/开关中断与处理异常

## 环境依赖
- RISC-V 64 位交叉工具链（如 `riscv64-unknown-elf-gcc` 或 `riscv64-linux-gnu-gcc`）
- QEMU ≥ 7（支持 `qemu-system-riscv64`，virt 机器）
- 推荐在 Linux/x86_64 下使用；macOS 可用交叉工具链 + QEMU

## 构建与运行
```bash
make           # 默认构建，包含所有自测
make clean     # 清理构建产物
make qemu      # 以 -machine virt -nographic 运行内核
make qemu-gdb  # 启动 QEMU 并监听 GDB（端口自动计算，virt/-nographic）
make qemu CPUS=2 # 多核（定时器桥接目前假设单核）
```
运行 `make qemu` 时的关键信息示例：
```
==========================================
    RISC-V Kernel v2.1 (VM enabled)
    Three-Stage Boot: entry->start->kmain
    Running in Supervisor Mode
==========================================
[pmem] kernel end=0x8..., stack top=0x8..., usable=[...)
[pmm] init: ... pages managed (...)
[pmm] selftest passed
[test] physical memory ok ...
[test] pagetable ok
[vmem] selftest passed
[kmain] paging enabled, satp=0x...
[test] virtual memory ok
[test] timer interrupt ok ...
```
内核末尾进入 `wfi` 循环，可用 `Ctrl+A, X` 退出 QEMU。

## 目录结构
```
my-os/
├── include/          # 公共头文件（pmm.h, vmem.h, pmem.h, printf.h, test.h 等）
├── kernel/
│   ├── boot/         # 启动与平台初始化（entry.S, start.c, kmain.c, uart.c, trap.S, kernel.ld）
│   ├── mm/           # 物理/虚拟内存管理
│   ├── trap.c        # 中断/异常分发、时钟桥接
│   ├── test.c        # 物理内存 & 页表测试
│   ├── test_vm.c     # 虚拟内存测试
│   ├── test_trap.c   # 中断测试
│   └── printf.c      # 内核打印与基础 libc 辅助
├── build/            # 编译输出（make 生成）
└── scripts/          # 预留脚本目录
```

## 中断与异常要点
- 委托策略：`medeleg=0xffff`，`mideleg` 委托 SSIP/STIP/SEIP，保留 MTIP 在 M 模式；M 定时器在 `timervec` 中重装下一次时间并置 SSIP，最终在 S 模式由 `timer_interrupt` 处理。
- 向量表：`stvec=kernelvec`，在汇编保存 31 个通用寄存器 + CSR（sepc/sstatus/stval/scause），再调用 `kerneltrap`。
- API：`trap_init/register_interrupt/enable_interrupt/disable_interrupt`，默认注册 SSIP→`timer_interrupt`；`get_time/sbi_set_timer/timer_ticks/get_timer_interrupt_count` 暴露时间与计数。
- 处理逻辑：中断进入 `kerneltrap` 判断 scause 高位；异常分发到 `handle_exception`（syscall/页故障等分支预留）。
- 自测：`test_timer_interrupt` 等待 5 次时钟中断并打印耗时，异常/性能测试当前为安全占位，避免故意触发致命异常。

## 系统调用学习与框架（任务1-5）
- 完整路径梳理：用户态桩（参考 xv6 `user/usys.pl`）→ `ecall` → `uservec`/`usertrap` → `syscall_dispatch`（scause=8）→ `sys_*` 实现 → 填充返回值到 a0，`trapframe.sepc+=4` 复位。
- 分发表：`kernel/syscall.c` 定义 `syscall_desc syscall_table[SYS_MAX]`，编号对齐 xv6，含名称/参数个数，调试开关 `debug_syscalls` 可打印 `pid/nr/ret`。
- 参数提取：`argint/argaddr/argstr` 从当前 trapframe 的 a0-a5 取值，`argstr` 经 `copyinstr` 做用户空间校验。
- 基础实现：`kernel/sysproc.c` 提供 `getpid/uptime/yield/sleep/exit/wait`，`write` 支持向 stdout/stderr 输出（chunk 拷贝+printf）；`sbrk` 维护每进程 brk 指针并返回旧值；`kill` 调用 `kill_process` 标记目标；`fork` 仍返回 -1（尚未复制地址空间）；`read/open/close` 现返回错误占位。
- 参考资料：对照 xv6 `kernel/syscall.c/sysproc.c/sysfile.c`、`trampoline.S`、RISC-V ecall 约定（a7 编号，a0 结果）理解寄存器/特权级切换与 trapframe 设计。

## 遇到的问题和解决方案
- **map_range panic（重复映射导致 err=-2）**：分页初始化时按段直接映射，`.text` 与 `.data` 位于同一页尾部，造成二次映射冲突。方案：将 `.text` 前半按 R+X 映射，含 `.data` 起始的那一页单独用 R+W+X 覆盖，后续数据/ BSS 用 R+W 映射，确保每个页框只建一次 PTE。
- **页表 dump 输出过长卡屏**：调试时递归打印页表导致控制台刷屏。方案：为 `dump_pagetable` 增加输出上限（200 条）并在最终版本移除默认调用，避免阻塞串口输出。
- **RWX 段链接警告**：`kernel.ld` 当前将加载段设为可读写执行，链接器提示警告。保持告警可忽略运行，若要消除需调整段权限或拆分段，但不影响功能。
- **定时器委托与桥接**：MTIP 委托给 S 模式会导致 S 急需访问 stimecmp，部分环境不支持。改为 MTIP 留在 M 模式，在 `timervec` 中重装下一次时间并置 SSIP 给 S 模式处理，保证定时器稳定。
- **stvec/上下文保存选择**：需要保存哪些寄存器？选用 kernelvec 保存全部 GPR 与 sepc/sstatus/stval/scause，避免遗漏导致返回异常。trapframe 结构在汇编与 C 之间共享偏移。
- **时钟计数起始值不为 0**：启动阶段 M 模式桥接会触发少量中断，进入 `test_timer_interrupt` 前计数可能是 1/2。测试逻辑改为记录当前值并等待 +5 次，打印如 “2->7”，属正常现象。
- **调度占位日志噪声**：`[sched] 1000 ticks elapsed` 仅用于验证时钟在跑，如果影响输出可提高阈值或移除。暂保留为可见的健康信号。
- **内核调度入口选择**：`test_process_subsystem` 在内存/中断自测完成后默认进入调度循环；如只想观察前序测试，可临时注释 `kmain` 末尾的调用。
- **syscall trapframe 来源不足**：当前还未切换到用户态，trapframe 主要来自内核栈。分发器优先使用本次陷入的 tf，不存在时回退到 `myproc()->trapframe`，避免空指针；后续接入用户态 trap 保存后可替换。
- **用户态内存拷贝接入**：`copyin/copyout/copyinstr` 现基于页表翻译+用户地址检查；无用户页表时回退直访，便于当前仅内核态的调用场景。后续接入真实用户页表与权限位时需替换。
- **定时器测试卡住**：`test_timer_interrupt` 偶尔等不到时钟中断导致死等，输出停在 “timer interrupt start”。修复：测试入口显式 `intr_on()`，加入软中断唤醒兜底，并将等待 tick 数从 5 降到 2，保证短时间内完成。
- **压力测试刷屏/延迟**：早期 `run_pmem_stress_test` 一次性打印 500+ 行，导致误判卡住。缩减每核分配次数到 32，并在多核场景将次核直接 park，避免重复全局初始化。

## GDB 调试
1. `make qemu-gdb` 启动 QEMU 并等待调试器。
2. 另开终端执行 `riscv64-unknown-elf-gdb kernel/kernel`，目标端口见生成的 `.gdbinit`（默认 25000+UID%5000）。
3. 常用断点：`_entry`、`start`、`kmain`，或在 `test_*` 函数处观察自测流程。
