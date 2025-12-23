#ifndef _PRINTF_H_
#define _PRINTF_H_

#include <stdarg.h>
#include "common.h"

int  printf(const char* fmt, ...);
int  vsnprintf(char* buf, size_t size, const char* fmt, va_list ap);
void puts(const char* s);
void puthex(uint64 val, int width);
void panic(const char* msg) __attribute__((noreturn));

#endif // _PRINTF_H_
