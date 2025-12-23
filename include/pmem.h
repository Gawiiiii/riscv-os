#ifndef _PMEM_H_
#define _PMEM_H_

#include "common.h"

typedef struct {
    uint64 start;
    uint64 end;
} pmem_range_t;

pmem_range_t pmem_usable_range(void);
uint64       pmem_usable_start(void);
uint64       pmem_usable_end(void);
void         pmem_dump_layout(void);

// Test-friendly wrappers mirroring user-provided interfaces
void         pmem_init(void);                 // idempotent init, wraps pmm_init
void*        pmem_alloc(int zero);            // zero!=0 -> memset page to zero
void         pmem_free(uint64 pa, int check); // check flag ignored, calls free_page

#endif // _PMEM_H_
