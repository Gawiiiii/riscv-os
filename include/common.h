#ifndef __COMMON_H__
#define __COMMON_H__
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

// 通用类型定义
#ifndef NULL
#define NULL ((void*)0)
#endif

typedef uint64_t uint64;
typedef uint32_t uint32;
typedef uint16_t uint16;
typedef uint8_t  uint8;

typedef int64_t  int64;
typedef int32_t  int32;
typedef int16_t  int16;
typedef int8_t   int8;

// Minimal libc-style helpers implemented inside the kernel
void*  memset(void* dst, int c, size_t n);
void*  memcpy(void* dst, const void* src, size_t n);
int    memcmp(const void* a, const void* b, size_t n);
size_t strlen(const char* s);

#endif
