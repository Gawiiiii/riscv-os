#include "include/pmm.h"
#include "include/printf.h"
#include "include/riscv.h"
#include "include/vmem.h"
#include "include/test.h"

void test_virtual_memory(void) {
    printf("[test] virtual memory start\n");
    pagetable_t kpgtbl = vmem_kernel_pagetable();
    if (!kpgtbl) panic("kernel pagetable not ready");

    void* page = alloc_page();
    if (!page) panic("alloc page for vm test");

    uint64 va = 0x40000000UL; // below kernel base, ensure mapping works
    if (map_page(kpgtbl, va, (uint64)page, PTE_R | PTE_W) != 0) {
        panic("map_page in vm test");
    }
    sfence_vma();

    uint64* vptr = (uint64*)va;
    uint64 pattern = 0x1234abcd5678ef90UL;
    *vptr = pattern;

    uint64* pptr = (uint64*)page;
    if (*pptr != pattern) {
        panic("virtual to physical mismatch");
    }

    // clear mapping
    pte_t* pte = walk_lookup(kpgtbl, va);
    if (pte) {
        *pte = 0;
        sfence_vma();
    }
    free_page(page);
    printf("[test] virtual memory ok\n");
}
