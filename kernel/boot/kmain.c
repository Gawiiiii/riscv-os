// kernel/boot/kmain.c - Supervisor模式下的主函数
// 现在运行在Supervisor模式，具有适当的权限隔离
#include "include/types.h"
#include "include/riscv.h"
#include "include/pmm.h"
#include "include/pmem.h"
#include "include/printf.h"
#include "include/vmem.h"
#include "include/trap.h"
#include "include/test.h"
#include "include/test_ext.h"

// 引入UART驱动
extern void uart_init(void);
extern void uart_putc(char c);
extern void uart_puts(const char *s);

// 外部符号：链接脚本定义的内存布局符号，不是普通变量
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
    // sstatus寄存器 bit8 (SPP) = 1 表示上次特权级为Supervisor模式
    // sstatus寄存器 bit5 (SPIE) = 1 表示进入Supervisor模式时中断使能
    // sstatus寄存器 bit1 (SIE) = 1 表示Supervisor模式中断使能
    asm volatile("csrr %0, sstatus" : "=r"(val));
    return val;
}

// 获取当前CPU ID - 使用数字寄存器号
static inline uint64 read_csr_tp(void) {
    uint64 val;
    asm volatile("mv %0, tp" : "=r"(val));  // tp = CSR 0x4
    return val;
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

    printf("\n==========================================\n");
    printf("    RISC-V Kernel v2.1 (VM enabled)\n");
    printf("    Three-Stage Boot: entry->start->kmain\n");
    printf("    Running in Supervisor Mode\n");
    printf("==========================================\n");

    unsigned long cpu_id = read_csr_tp();
    unsigned long sstatus = read_csr_sstatus();
    printf("CPU ID: %lu\n", cpu_id);
    printf("Supervisor Status Register: 0x%lx\n", sstatus);

    // Park secondary harts to avoid re-running global init (SMP not supported yet).
    if (cpu_id != 0) {
        printf("[kmain] secondary hart %lu parked (no SMP init yet)\n", cpu_id);
        while (1) {
            asm volatile("wfi");
        }
    }

    // 验证BSS段是否正确清零
    if (test_bss_var != 0 || test_static_var != 0) {
        panic("BSS segment not properly cleared");
    }
    if (test_data_var != 42) {
        panic("Data segment corrupted");
    }
    printf("BSS and data checks passed\n");

    pmem_dump_layout();

    // 初始化S模式trap框架并开启中断
    trap_init();
    intr_on();

    // 初始化物理内存管理器并运行自测
    pmm_init();
    pmm_selftest();

    // 独立测试组件
    test_physical_memory();
    test_pagetable();
    vmem_selftest();
    run_pmem_stress_test();

    // 建立并启用内核页表
    pagetable_t kpgtbl = vmem_setup_kernel();
    vmem_enable(kpgtbl);
    printf("[kmain] paging enabled, satp=0x%lx\n", r_satp());

    test_virtual_memory();
    run_vm_mapping_test();
    test_timer_interrupt();
    test_exception_handling();
    test_interrupt_overhead();
    printf("System initialization complete!\n");
    printf("Kernel ready for further extensions.\n");

    // Enter kernel thread/process scheduler test (does not return).
    test_process_subsystem();
    while (1) {
        asm volatile("wfi");
    }
}
