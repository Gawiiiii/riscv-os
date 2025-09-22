# RISC-V 操作系统实践
刘家维

## 概述
这是一个基于 RISC-V 架构的简易操作系统内核实现，借鉴了xv6，旨在帮助理解操作系统的基本原理和机制。该项目涵盖了内存管理、进程调度、中断处理等核心功能。

## 快速运行
### 清除编译
```
make clean
```
### 编译所有
```
make all
```
### 运行内核
```
make qemu
```
### 运行效果
```
Starting kernel in QEMU...
Expected output sequence: S P B b C M U ...
Use Ctrl+A X to exit QEMU
qemu-system-riscv64 -machine virt -bios none -kernel kernel/kernel -m 128M -smp 1 -nographic
SPBbCstTSMU
==========================================
    RISC-V Kernel v2.0 (Full Version)
    Three-Stage Boot: entry->start->kmain
    Running in Supervisor Mode
==========================================
CPU ID: 0
Supervisor Status Register: 0x00000000
Testing BSS clear: OK
Testing data section: OK
Privilege level verification: Running in Supervisor Mode - OK
System initialization complete!
Kernel ready for extension (processes, virtual memory, etc.)
Entering idle state with heartbeat...
```
然后开始无限循环打印心跳点
其中的 SPBbCstTSMU 为检查点，启动时可通过此系列检查点判断何处出现问题；输出E则为严重错误（如start函数返回到entry了）

## 目录结构
```
riscv-os/
├── kernel/
│   ├── boot/     # 启动相关代码
│   ├── mm/       # 内存管理 (Memory Management)
│   ├── trap/     # 中断和异常处理
│   ├── proc/     # 进程管理
│   ├── fs/       # 文件系统
│   └── net/      # 网络栈
├── include/      # 头文件
└── scripts/      # 构建脚本
```