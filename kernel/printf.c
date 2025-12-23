#include <stdarg.h>
#include "include/common.h"
#include "include/printf.h"

// UART primitives
extern void uart_putc(char c);
extern void uart_puts(const char* s);

void* memset(void* dst, int c, size_t n) {
    unsigned char* p = (unsigned char*)dst;
    while (n--) {
        *p++ = (unsigned char)c;
    }
    return dst;
}

void* memcpy(void* dst, const void* src, size_t n) {
    unsigned char* d = (unsigned char*)dst;
    const unsigned char* s = (const unsigned char*)src;
    while (n--) {
        *d++ = *s++;
    }
    return dst;
}

int memcmp(const void* a, const void* b, size_t n) {
    const unsigned char* pa = (const unsigned char*)a;
    const unsigned char* pb = (const unsigned char*)b;
    for (size_t i = 0; i < n; i++) {
        if (pa[i] != pb[i]) {
            return pa[i] - pb[i];
        }
    }
    return 0;
}

size_t strlen(const char* s) {
    size_t n = 0;
    if (!s) return 0;
    while (s[n]) n++;
    return n;
}

static void console_putc(int c) {
    uart_putc((char)c);
}

void puts(const char* s) {
    if (!s) return;
    uart_puts(s);
    uart_putc('\n');
}

void puthex(uint64 val, int width) {
    static const char* digits = "0123456789abcdef";
    for (int i = width - 1; i >= 0; i--) {
        int shift = i * 4;
        int nibble = (val >> shift) & 0xF;
        console_putc(digits[nibble]);
    }
}

int vsnprintf(char* buf, size_t size, const char* fmt, va_list ap) {
    size_t idx = 0;
    for (const char* p = fmt; *p; p++) {
        if (*p != '%') {
            if (buf && idx + 1 < size) buf[idx] = *p;
            idx++;
            continue;
        }
        p++;
        if (!*p) break;
        switch (*p) {
            case 'd': {
                int v = va_arg(ap, int);
                char tmp[32];
                int n = 0;
                int neg = v < 0;
                unsigned int uv = neg ? (unsigned int)(-v) : (unsigned int)v;
                do {
                    tmp[n++] = "0123456789"[uv % 10];
                    uv /= 10;
                } while (uv && n < (int)sizeof(tmp));
                if (neg && n < (int)sizeof(tmp)) tmp[n++] = '-';
                while (n--) {
                    if (buf && idx + 1 < size) buf[idx] = tmp[n];
                    idx++;
                }
                break;
            }
            case 'u': {
                unsigned int v = va_arg(ap, unsigned int);
                char tmp[32];
                int n = 0;
                do {
                    tmp[n++] = "0123456789"[v % 10];
                    v /= 10;
                } while (v && n < (int)sizeof(tmp));
                while (n--) {
                    if (buf && idx + 1 < size) buf[idx] = tmp[n];
                    idx++;
                }
                break;
            }
            case 'l': { // handle %lx or %ld
                p++;
                char spec = *p;
                uint64 v64 = va_arg(ap, uint64);
                if (spec == 'x' || spec == 'p') {
                    char tmp[32];
                    int n = 0;
                    do {
                        tmp[n++] = "0123456789abcdef"[v64 % 16];
                        v64 /= 16;
                    } while (v64 && n < (int)sizeof(tmp));
                    while (n--) {
                        if (buf && idx + 1 < size) buf[idx] = tmp[n];
                        idx++;
                    }
                } else { // ld or lu
                    char tmp[32];
                    int n = 0;
                    do {
                        tmp[n++] = "0123456789"[v64 % 10];
                        v64 /= 10;
                    } while (v64 && n < (int)sizeof(tmp));
                    while (n--) {
                        if (buf && idx + 1 < size) buf[idx] = tmp[n];
                        idx++;
                    }
                }
                break;
            }
            case 'x':
            case 'p': {
                uint64 v = (*p == 'p') ? (uint64)va_arg(ap, void*) : (uint64)va_arg(ap, unsigned int);
                char tmp[32];
                int n = 0;
                do {
                    tmp[n++] = "0123456789abcdef"[v % 16];
                    v /= 16;
                } while (v && n < (int)sizeof(tmp));
                while (n--) {
                    if (buf && idx + 1 < size) buf[idx] = tmp[n];
                    idx++;
                }
                break;
            }
            case 's': {
                const char* s = va_arg(ap, const char*);
                if (!s) s = "(null)";
                while (*s) {
                    if (buf && idx + 1 < size) buf[idx] = *s;
                    idx++;
                    s++;
                }
                break;
            }
            case 'c': {
                char c = (char)va_arg(ap, int);
                if (buf && idx + 1 < size) buf[idx] = c;
                idx++;
                break;
            }
            case '%':
                if (buf && idx + 1 < size) buf[idx] = '%';
                idx++;
                break;
            default:
                if (buf && idx + 1 < size) buf[idx] = '%';
                idx++;
                if (buf && idx + 1 < size) buf[idx] = *p;
                idx++;
                break;
        }
    }
    if (buf && size) {
        buf[(idx < size) ? idx : size - 1] = '\0';
    }
    return (int)idx;
}

int printf(const char* fmt, ...) {
    char buf[256];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    for (int i = 0; buf[i]; i++) {
        console_putc(buf[i]);
    }
    return n;
}

void panic(const char* msg) {
    uart_puts("\nPANIC: ");
    uart_puts(msg);
    uart_puts("\n");
    while (1) {
        asm volatile("wfi");
    }
}
