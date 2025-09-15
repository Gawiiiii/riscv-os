// kernel/boot/start.c - 完整的特权级切换和硬件初始化
// 参考xv6实现，为后续操作系统功能做准备

#include <stdint.h>
// #include "include/riscv.h"

// RISC-V寄存器访问宏定义
#define read_csr(reg) ({ unsigned long __tmp; \
    asm volatile("csrr %0, " #reg : "=r"(__tmp)); __tmp; })

#define write_csr(reg, val) ({ \
    asm volatile("csrw " #reg ", %0" :: "rK"(val)); })

#define set_csr(reg, bit) ({ unsigned long __tmp; \
    asm volatile("csrrs %0, " #reg ", %1" : "=r"(__tmp) : "rK"(bit)); __tmp; })

#define clear_csr(reg, bit) ({ unsigned long __tmp; \
    asm volatile("csrrc %0, " #reg ", %1" : "=r"(__tmp) : "rK"(bit)); __tmp; })

// 机器状态寄存器(mstatus)位定义
#define MSTATUS_MPP_MASK    (3L << 11)  // Previous Privilege Mode
#define MSTATUS_MPP_M       (3L << 11)  // Machine模式
#define MSTATUS_MPP_S       (1L << 11)  // Supervisor模式  
#define MSTATUS_MIE         (1L << 3)   // Machine中断使能

// 中断使能寄存器位定义
#define MIE_SEIE            (1L << 9)   // Supervisor外部中断
#define MIE_STIE            (1L << 5)   // Supervisor定时器中断
#define MIE_SSIE            (1L << 1)   // Supervisor软件中断

#define SIE_SEIE            (1L << 9)   // Supervisor外部中断使能
#define SIE_STIE            (1L << 5)   // Supervisor定时器中断使能
#define SIE_SSIE            (1L << 1)   // Supervisor软件中断使能

// 前向声明
extern void kmain(void);
void timerinit(void);

/*
 * start() - 在Machine模式下运行，负责：
 * 1. 配置特权级切换到Supervisor模式
 * 2. 设置中断委托和权限管理
 * 3. 初始化基础硬件
 * 4. 通过mret跳转到Supervisor模式的kmain函数
 */
void start(void) {
    // 调试标记：进入start函数
    *(volatile char*)0x10000000 = 's';
    
    // ========== 1. 配置特权级切换 ==========
    // 设置mstatus寄存器，准备从Machine模式切换到Supervisor模式
    unsigned long x = read_csr(mstatus);
    x &= ~MSTATUS_MPP_MASK;          // 清除之前的特权级设置
    x |= MSTATUS_MPP_S;              // 设置Previous Privilege为Supervisor模式
    write_csr(mstatus, x);
    
    // 设置mret的返回地址为kmain函数
    // mret指令会跳转到mepc寄存器指定的地址
    write_csr(mepc, (uint64_t)kmain);
    
    // ========== 2. 配置内存管理 ==========
    // 禁用分页机制 - 启动阶段使用物理地址
    // satp = 0 表示禁用地址翻译，使用恒等映射
    write_csr(satp, 0);
    
    // ========== 3. 配置中断和异常委托 ==========
    // 将大部分异常委托给Supervisor模式处理
    // 这样Supervisor模式可以处理页面错误、非法指令等异常
    write_csr(medeleg, 0xffff);
    
    // 将中断委托给Supervisor模式处理
    // 这样Supervisor模式可以处理时钟中断、外部中断等
    write_csr(mideleg, 0xffff);
    
    // 在Supervisor模式中使能中断
    // 注意：这个设置会在特权级切换后生效
    write_csr(sie, read_csr(sie) | SIE_SEIE | SIE_STIE | SIE_SSIE);
    
    // ========== 4. 配置物理内存保护(PMP) ==========
    // PMP允许Machine模式限制低特权级模式的内存访问
    // 这里配置允许Supervisor模式访问所有物理内存
    
    // 设置PMP地址寄存器0 - 覆盖整个地址空间
    write_csr(pmpaddr0, 0x3fffffffffffffull);
    
    // 设置PMP配置寄存器0
    // 0xf = NAPOT | R | W | X (自然对齐的2的幂 + 读写执行权限)
    write_csr(pmpcfg0, 0xf);
    
    // ========== 5. 初始化定时器中断 ==========
    // 为操作系统调度准备定时器中断
    timerinit();
    
    // ========== 6. 保存CPU ID ==========
    // 将硬件线程ID保存到tp寄存器，供后续使用
    // 在多核系统中，每个核心需要知道自己的ID
    int id;
    asm volatile("csrr %0, mhartid" : "=r"(id)); // 避免函数调用 直接使用内联汇编
    asm volatile("mv tp, %0" : : "r" (id));  // tp = CSR 0x4
    // int id = r_mhartid();
    // w_tp(id);
    
    // 调试标记：准备特权级切换
    *(volatile char*)0x10000000 = 'S';
    
    // ========== 7. 执行特权级切换 ==========
    // mret指令会：
    // 1. 将特权级切换到mstatus.MPP指定的模式(Supervisor)
    // 2. 跳转到mepc寄存器指定的地址(kmain)
    // 3. 恢复中断使能状态
    asm volatile("mret");
    
    // 注意：代码永远不会执行到这里
    // 如果执行到这里，说明mret失败了
    *(volatile char*)0x10000000 = 'F';  // Failure标记
    while(1) {}
}

/*
 * timerinit() - 初始化定时器中断
 * 配置机器模式定时器，为操作系统调度提供时钟源
 */
void timerinit(void) {
    // 调试标记：初始化定时器
    *(volatile char*)0x10000000 = 't';
    
    // ========== 使能机器模式定时器中断 ==========
    write_csr(mie, read_csr(mie) | MIE_STIE);
    
    // ========== 配置定时器扩展 ==========
    // 使能sstc扩展(Supervisor-mode timer compare)
    // 允许Supervisor模式直接操作stimecmp寄存器
    write_csr(menvcfg, read_csr(menvcfg) | (1L << 63));
    
    // ========== 允许Supervisor访问时间寄存器 ==========
    // mcounteren控制低特权级对性能计数器的访问
    // 位1(TM) = 1 允许访问时间相关寄存器
    write_csr(mcounteren, read_csr(mcounteren) | 2);
    
    // ========== 设置第一次定时器中断 ==========
    // 获取当前时间并设置下次中断时间
    // 1000000个时钟周期后触发中断（约1ms，取决于时钟频率）
    unsigned long current_time = read_csr(time);
    write_csr(stimecmp, current_time + 1000000);
    
    // 调试标记：定时器初始化完成
    *(volatile char*)0x10000000 = 'T';
}