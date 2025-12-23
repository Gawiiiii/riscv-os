#include "include/pmem.h"
#include "include/pmm.h"
#include "include/memlayout.h"
#include "include/printf.h"
#include "include/riscv.h"

extern char end[];
extern char _stack_top[];

static pmem_range_t usable;
static int pmem_inited = 0;

pmem_range_t pmem_usable_range(void) {
    if (usable.start == 0 && usable.end == 0) {
        usable.start = (uint64)_stack_top;
        usable.end = RAM_END;
    }
    return usable;
}

uint64 pmem_usable_start(void) {
    return pmem_usable_range().start;
}

uint64 pmem_usable_end(void) {
    return pmem_usable_range().end;
}

void pmem_dump_layout(void) {
    printf("[pmem] kernel end=0x%lx, stack top=0x%lx, usable=[0x%lx, 0x%lx)\n",
           (uint64)end, (uint64)_stack_top, pmem_usable_start(), pmem_usable_end());
}

void pmem_init(void) {
    if (pmem_inited) return;
    pmm_init();
    pmem_inited = 1;
}

void* pmem_alloc(int zero) {
    void* p = alloc_page();
    if (p && zero) {
        memset(p, 0, PGSIZE);
    }
    return p;
}

void pmem_free(uint64 pa, int check) {
    (void)check;
    free_page((void*)pa);
}
