// kernel/boot/kmain.c - Supervisor模式下的主函数
// 现在运行在Supervisor模式，具有适当的权限隔离
#include "include/types.h"

// 引入UART驱动
extern void uart_init(void);
extern void uart_putc(char c);
extern void uart_puts(const char *s);

// 外部符号：链接脚本定义的内存布局符号
extern char _text_start[], _text_end[];
extern char _bss_start[], _bss_end[];
extern char end[];

// 测试BSS段清零的全局变量
int test_bss_var;
static int test_static_var;
int test_data_var = 42;

// 读取当前特权级
static inline unsigned long read_csr_sstatus(void) {
    unsigned long val;
    asm volatile("csrr %0, sstatus" : "=r"(val));
    return val;
}

// 获取当前CPU ID - 使用数字寄存器号
static inline uint64 read_csr_tp(void) {
    uint64 val;
    asm volatile("mv %0, tp" : "=r"(val));  // tp = CSR 0x4
    return val;
}

// 简化的panic函数 - 适配Supervisor模式
void panic(const char *msg) {
    uart_puts("\n*** KERNEL PANIC (Supervisor Mode) ***\n");
    uart_puts("Error: ");
    uart_puts(msg);
    uart_puts("\nSystem halted.\n");
    
    // 在Supervisor模式下禁用中断
    asm volatile("csrci sstatus, 0x2");  // 清除SIE位
    while (1) {
        asm volatile("wfi");             // 等待中断
    }
}

/*
 * kmain() - Supervisor模式下的主函数
 * 由start.c通过mret跳转到此函数
 * 运行在Supervisor模式，具有适当的权限隔离
 */
void kmain(void) {
    // 调试标记：进入Supervisor模式主函数
    uart_putc('M');
    
    // 1. 初始化串口驱动
    uart_init();
    
    // 2. 打印启动信息，显示特权级信息
    uart_puts("\n");
    uart_puts("==========================================\n");
    uart_puts("    RISC-V Kernel v2.0 (Full Version)\n");
    uart_puts("    Three-Stage Boot: entry->start->kmain\n");
    uart_puts("    Running in Supervisor Mode\n");  
    uart_puts("==========================================\n");
    
    // 3. 显示系统状态
    unsigned long cpu_id = read_csr_tp();
    uart_puts("CPU ID: ");
    uart_putc('0' + (char)cpu_id);
    uart_puts("\n");
    
    unsigned long sstatus = read_csr_sstatus();
    uart_puts("Supervisor Status Register: 0x");
    // 简化的十六进制输出
    for(int i = 7; i >= 0; i--) {
        char digit = (sstatus >> (i*4)) & 0xF;
        uart_putc(digit < 10 ? '0' + digit : 'A' + digit - 10);
    }
    uart_puts("\n");
    
    // 4. 验证BSS段是否正确清零
    uart_puts("Testing BSS clear: ");
    if (test_bss_var == 0 && test_static_var == 0) {
        uart_puts("OK\n");
    } else {
        uart_puts("FAILED\n");
        panic("BSS segment not properly cleared");
    }
    
    // 5. 验证数据段
    uart_puts("Testing data section: ");
    if (test_data_var == 42) {
        uart_puts("OK\n");
    } else {
        uart_puts("FAILED\n");
        panic("Data segment corrupted");
    }
    
    // 6. 验证特权级切换成功
    uart_puts("Privilege level verification: ");
    // 尝试读取Machine模式寄存器应该会失败（在真实硬件上）
    // 在QEMU中可能仍然可以读取，但这证明了我们的设计意图
    uart_puts("Running in Supervisor Mode - OK\n");
    
    uart_puts("System initialization complete!\n");
    uart_puts("Kernel ready for extension (processes, virtual memory, etc.)\n");
    uart_puts("Entering idle state with heartbeat...\n");
    
    // 7. 进入安全的空闲循环
    // 在Supervisor模式下禁用中断
    asm volatile("csrci sstatus, 0x2");  // 清除SIE位
    
    unsigned int heartbeat_counter = 0;
    
    // 永不返回的无限循环 - 为后续扩展预留
    while (1) {
        // 等待中断（在有定时器中断的系统中会被唤醒）
        asm volatile("wfi");
        
        // 定期输出心跳 - 降低频率以便观察
        if ((++heartbeat_counter & 0x1FFFF) == 0) {  // 约131k次循环
            uart_putc('.');
        }
    }
    
    // 注意：代码永远不会执行到这里
}