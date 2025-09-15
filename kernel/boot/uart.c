// cat > kernel/boot/uart.c << 'EOF'
// kernel/boot/uart.c - 串口驱动

#include <stdint.h>

#define UART_BASE       0x10000000UL
#define UART_THR        (UART_BASE + 0)
#define UART_LSR        (UART_BASE + 5)
#define UART_IER        (UART_BASE + 1)
#define UART_LCR        (UART_BASE + 3)
#define UART_DLL        (UART_BASE + 0)
#define UART_DLH        (UART_BASE + 1)
#define UART_FCR        (UART_BASE + 2)
#define UART_MCR        (UART_BASE + 4)

#define LSR_THRE        0x20
#define LCR_DLAB        0x80

static inline unsigned char uart_read_reg(uintptr_t reg) {
    return *(volatile unsigned char*)reg;
}

static inline void uart_write_reg(uintptr_t reg, unsigned char val) {
    *(volatile unsigned char*)reg = val;
}

void uart_putc(char c) {
    while (!(uart_read_reg(UART_LSR) & LSR_THRE)) {
        // 等待发送寄存器空
    }
    uart_write_reg(UART_THR, c);
}

void uart_puts(const char *s) {
    if (s == 0) return;
    
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s);
        s++;
    }
}

void uart_init(void) {
    uart_write_reg(UART_IER, 0x00);
    uart_write_reg(UART_LCR, LCR_DLAB);
    uart_write_reg(UART_DLL, 0x03);
    uart_write_reg(UART_DLH, 0x00);
    uart_write_reg(UART_LCR, 0x03);
    uart_write_reg(UART_FCR, 0x07);
    uart_write_reg(UART_MCR, 0x03);
    
    uart_putc('U');
}