// kernel/boot/start.c - 完整的特权级切换和硬件初始化
// 参考xv6实现，为后续操作系统功能做准备

#include <stdint.h>
#include "include/trap.h"

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
#define MIE_MTIE            (1L << 7)   // 机器定时器中断

#define SIE_SEIE            (1L << 9)   // Supervisor外部中断使能
#define SIE_STIE            (1L << 5)   // Supervisor定时器中断使能
#define SIE_SSIE            (1L << 1)   // Supervisor软件中断使能

#define CLINT_MTIMECMP(hart) (0x02004000UL + 8 * (hart))
#define TICK_INTERVAL        1000000UL
#define MAX_HARTS            2

extern void timervec(void);
static uint64_t timer_scratch[MAX_HARTS][5];

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
    x |= MSTATUS_MPP_S;              // 设置Previous Privilege为Supervisor模式，欺骗cpu，使得mret从M模式进入S模式
    write_csr(mstatus, x);
    
    // 设置mret的返回地址为kmain函数
    // mret指令会跳转到mepc寄存器指定的地址
    write_csr(mepc, (uint64_t)kmain);
    
    // ========== 2. 配置内存管理 ==========
    // 禁用分页机制 - 启动阶段使用物理地址
    // satp = 0 表示禁用地址翻译，使用恒等映射
    // satp 寄存器的结构如下：[63:60] MODE | [59:44] ASID | [43:0] PPN
    // MODE 字段控制地址转换模式，0 = Bare (禁用分页)，1 = Sv32, 8 = Sv39, 9 = Sv48 (SvN 表示启用N位虚拟地址转换)
    write_csr(satp, 0);
    
    // ========== 3. 配置中断和异常委托 ==========
    // 将所有异常委托给Supervisor模式处理
    // 这样Supervisor模式可以处理页面错误、非法指令等异常
    write_csr(medeleg, 0xffff);
    
    // 将软件/外部/监督定时器中断委托给Supervisor模式
    // 机器定时器中断保留在M模式，用于桥接到S模式
    unsigned long ideleg = (1 << 1) | (1 << 5) | (1 << 9);
    write_csr(mideleg, ideleg);
    
    // 在Supervisor模式中使能中断
    // 注意：这个设置会在特权级切换后生效
    write_csr(sie, read_csr(sie) | SIE_SEIE | SIE_STIE | SIE_SSIE);
    
    // ========== 4. 配置物理内存保护(PMP) ==========
    // 共有16个PMP条目，pmpaddr寄存器存储地址，pmpcfg寄存器存储配置，每个PMP都有自己的pmpaddr，所有PMP共享两个pmpcfg (0&2,没有1&3)
    // 访问某地址时，cpu会从pmp0开始往后逐个检查pmp条目，直到某个条目将该地址包含在内，就根据该pmp的约束访问内存
    // 如果都不匹配，Machine模式无限制访问，S/M模式禁止访问
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
    
    int id;
    asm volatile("csrr %0, mhartid" : "=r"(id));

    // ========== 允许Supervisor访问时间寄存器 ==========
    // mcounteren控制低特权级对性能计数器的访问
    write_csr(mcounteren, read_csr(mcounteren) | 2);
    write_csr(menvcfg, read_csr(menvcfg) | (1L << 63));

    // ========== 设置机器模式trap向量处理定时器 ==========
    write_csr(mtvec, (uint64_t)timervec);

    // 配置mscratch供timervec使用:
    // [0..2] 暂存寄存器, [3] mtimecmp地址, [4] interval
    uint64_t* scratch = &timer_scratch[id][0];
    scratch[3] = CLINT_MTIMECMP(id);
    scratch[4] = TICK_INTERVAL;
    write_csr(mscratch, (uint64_t)scratch);

    // ========== 使能机器模式定时器中断 ==========
    write_csr(mie, read_csr(mie) | MIE_MTIE);

    // ========== 设置第一次定时器中断 ==========
    sbi_set_timer(get_time() + TICK_INTERVAL);

    // 调试标记：定时器初始化完成
    *(volatile char*)0x10000000 = 'T';
}
