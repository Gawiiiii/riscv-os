#ifndef _PMM_H_
#define _PMM_H_

#include "common.h"
#include "memlayout.h"
#include "riscv.h"

void   pmm_init(void);
void*  alloc_page(void);
void   free_page(void* pa);
void*  alloc_pages(int n);      // optional helper, may return NULL if insufficient pages
size_t pmm_total_pages(void);
size_t pmm_free_pages(void);
void   pmm_selftest(void);

#endif // _PMM_H_
