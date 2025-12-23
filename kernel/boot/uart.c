// cat > kernel/boot/uart.c << 'EOF'
// kernel/boot/uart.c - 串口驱动

#include <stdint.h>

// 寄存器地址定义
// 说明：DLL和THR都是+0地址偏移，但是通过LCR寄存器的DLAB位区分；+1的同理
#define UART_BASE       0x10000000UL        // qemu将该地址映射为虚拟UART，即串口基地址，寄存器地址映射
#define UART_THR        (UART_BASE + 0)     // 发送保持寄存器 (Transmit Holding Register)
#define UART_LSR        (UART_BASE + 5)     // 线路状态寄存器 (Line Status Register)
#define UART_IER        (UART_BASE + 1)     // 中断使能寄存器 (Interrupt Enable Register)
#define UART_LCR        (UART_BASE + 3)     // 线路控制寄存器 (Line Control Register)
#define UART_DLL        (UART_BASE + 0)     // 波特率分频器低字节 (Divisor Latch Low)
#define UART_DLH        (UART_BASE + 1)     // 波特率分频器高字节 (Divisor Latch High)
#define UART_FCR        (UART_BASE + 2)     // FIFO控制寄存器 (FIFO Control Register)
#define UART_MCR        (UART_BASE + 4)     // 调制解调器控制寄存器 (Modem Control Register)

#define LSR_THRE        0x20    // 发送保持寄存器空 (Transmit Holding Register Empty) 第5位
#define LCR_DLAB        0x80    // 设置DLAB位 (Divisor Latch Access Bit) 第7位

// 读寄存器的辅助函数
static inline unsigned char uart_read_reg(uintptr_t reg) { // 使用uintptr_t(在stdint.h中定义)确保正确存储内存地址不会截断
    return *(volatile unsigned char*)reg;
}

// 写寄存器的辅助函数
static inline void uart_write_reg(uintptr_t reg, unsigned char val) {
    *(volatile unsigned char*)reg = val;
}

// 发送单个字符
void uart_putc(char c) {
    while (!(uart_read_reg(UART_LSR) & LSR_THRE)) {
        // 等待发送寄存器空
        // 如果LSR的THRE位(第5位)为1，表示发送保持寄存器空，可以写入新数据；否则寄存器满，等待
    }
    uart_write_reg(UART_THR, c);
}

// 发送字符串
void uart_puts(const char *s) {
    if (s == 0) return;
    
    while (*s) {
        if (*s == '\n') { // Unix的换行符\n需要转换为\r\n 即光标回到行首+光标移到下一行
            uart_putc('\r');
        }
        uart_putc(*s);
        s++;
    }
}

void uart_init(void) {
    uart_write_reg(UART_IER, 0x00);     // 禁用中断
    uart_write_reg(UART_LCR, LCR_DLAB); // 设置DLAB位，允许访问DLL和DLH寄存器
    uart_write_reg(UART_DLL, 0x03);     // 设置波特率分频器低位
    uart_write_reg(UART_DLH, 0x00);     // 设置波特率分频器高位
    uart_write_reg(UART_LCR, 0x03);     // 清除DLAB位，设置数据格式为8位数据，无校验，1位停止位 (8N1)
    uart_write_reg(UART_FCR, 0x07);     // 启用FIFO，清除接收和发送FIFO (FCR寄存器的第0位启用FIFO，第1位清除接收FIFO，第2位清除发送FIFO)
    uart_write_reg(UART_MCR, 0x03);     // 设置调制解调器控制寄存器 (设置RTS和DTR信号，第0位DTR，第1位RTS)
    
    uart_putc('U');
}