#include "include/vmem.h"
#include "include/pmm.h"
#include "include/pmem.h"
#include "include/memlayout.h"
#include "include/printf.h"

extern char _text_start[], _text_end[];
extern char _data_start[], _data_end[];
extern char _bss_start[], _bss_end[];
extern char _stack_bottom[], _stack_top[];
extern char end[];

static pagetable_t kernel_pagetable = NULL;

static void freewalk(pagetable_t pagetable, int level);
static void dumpwalk(pagetable_t pagetable, int level, int indent, int* remaining);
static void map_range(pagetable_t pagetable, uint64 va_start, uint64 va_end, uint64 pa_start, int perm);

pagetable_t create_pagetable(void) {
    void* page = alloc_page();
    if (!page) return NULL;
    memset(page, 0, PGSIZE);
    return (pagetable_t)page;
}

pte_t* walk_create(pagetable_t pagetable, uint64 va) {
    if (va >= MAXVA) return NULL;
    for (int level = 2; level > 0; level--) {
        pte_t* pte = &pagetable[PX(level, va)];
        if (*pte & PTE_V) {
            pagetable = (pagetable_t)PTE2PA(*pte);
        } else {
            pagetable_t newtable = create_pagetable();
            if (!newtable) return NULL;
            *pte = PA2PTE(newtable) | PTE_V;
            pagetable = newtable;
        }
    }
    return &pagetable[PX(0, va)];
}

pte_t* walk_lookup(pagetable_t pagetable, uint64 va) {
    if (va >= MAXVA) return NULL;
    for (int level = 2; level > 0; level--) {
        pte_t* pte = &pagetable[PX(level, va)];
        if ((*pte & PTE_V) == 0) return NULL;
        pagetable = (pagetable_t)PTE2PA(*pte);
    }
    return &pagetable[PX(0, va)];
}

int map_page(pagetable_t pagetable, uint64 va, uint64 pa, int perm) {
    if (va % PGSIZE || pa % PGSIZE) return -1;
    pte_t* pte = walk_create(pagetable, va);
    if (!pte) return -1;
    if (*pte & PTE_V) {
        return -2; // already mapped
    }
    *pte = PA2PTE(pa) | perm | PTE_V;
    return 0;
}

static void map_range(pagetable_t pagetable, uint64 va_start, uint64 va_end, uint64 pa_start, int perm) {
    uint64 va = PGROUNDDOWN(va_start);
    uint64 pa = PGROUNDDOWN(pa_start);
    for (; va < va_end; va += PGSIZE, pa += PGSIZE) {
        int r = map_page(pagetable, va, pa, perm);
        if (r != 0) {
            printf("[vmem] map_range fail va=0x%lx pa=0x%lx perm=0x%x err=%d\n", va, pa, perm, r);
            panic("map_range failed");
        }
    }
}

void destroy_pagetable(pagetable_t pagetable) {
    freewalk(pagetable, 2);
}

static void freewalk(pagetable_t pagetable, int level) {
    for (int i = 0; i < 512; i++) {
        pte_t pte = pagetable[i];
        if ((pte & PTE_V) == 0) continue;
        if ((pte & (PTE_R | PTE_W | PTE_X)) != 0) {
            continue; // leaf mapping, actual physical page lifetime handled elsewhere
        }
        pagetable_t child = (pagetable_t)PTE2PA(pte);
        freewalk(child, level - 1);
    }
    free_page(pagetable);
}

static void dumpwalk(pagetable_t pagetable, int level, int indent, int* remaining) {
    for (int i = 0; i < 512; i++) {
        pte_t pte = pagetable[i];
        if ((pte & PTE_V) == 0) continue;
        if (*remaining <= 0) return;
        (*remaining)--;
        for (int j = 0; j < indent; j++) printf(" ");
        uint64 pa = PTE2PA(pte);
        printf("L%d[%d]: PTE=0x%lx -> PA=0x%lx flags=0x%lx\n",
               level, i, pte, pa, PTE_FLAGS(pte));
        if ((pte & (PTE_R | PTE_W | PTE_X)) == 0 && level > 0) {
            dumpwalk((pagetable_t)pa, level - 1, indent + 2, remaining);
        }
    }
}

void dump_pagetable(pagetable_t pagetable) {
    printf("[vmem] dump pagetable @0x%lx\n", (uint64)pagetable);
    int remaining = 200; // keep output bounded to avoid flooding console
    dumpwalk(pagetable, 2, 0, &remaining);
    if (remaining == 0) {
        printf("[vmem] dump truncated after 200 entries\n");
    }
}

pagetable_t vmem_setup_kernel(void) {
    if (kernel_pagetable) {
        return kernel_pagetable;
    }
    kernel_pagetable = create_pagetable();
    if (!kernel_pagetable) panic("vmem_setup_kernel: alloc root");
    vmem_map_kernel_segments(kernel_pagetable);
    return kernel_pagetable;
}

pagetable_t vmem_kernel_pagetable(void) {
    return kernel_pagetable;
}

void vmem_map_kernel_segments(pagetable_t kpgtbl) {
    uint64 text_start = (uint64)_text_start;
    uint64 data_start_addr = (uint64)_data_start;
    uint64 bss_end    = (uint64)_bss_end;
    uint64 stack_bottom = (uint64)_stack_bottom;
    uint64 stack_top    = (uint64)_stack_top;

    uint64 text_only_end = PGROUNDDOWN(data_start_addr);
    if (text_only_end > text_start) {
        map_range(kpgtbl, text_start, text_only_end, text_start, PTE_R | PTE_X);
    }

    // The page containing the start of .data may also contain tail of .text/.rodata.
    uint64 overlap_page = PGROUNDDOWN(data_start_addr);
    map_range(kpgtbl, overlap_page, overlap_page + PGSIZE, overlap_page, PTE_R | PTE_W | PTE_X);

    uint64 data_rest_start = overlap_page + PGSIZE;
    uint64 data_end   = PGROUNDUP(bss_end);
    if (data_end > data_rest_start) {
        map_range(kpgtbl, data_rest_start, data_end, data_rest_start, PTE_R | PTE_W);
    }
    map_range(kpgtbl, stack_bottom, stack_top, stack_bottom, PTE_R | PTE_W);

    // Map remaining physical memory for allocator use
    uint64 free_start = PGROUNDUP(pmem_usable_start());
    map_range(kpgtbl, free_start, RAM_END, free_start, PTE_R | PTE_W);

    // Map UART device
    map_range(kpgtbl, 0x10000000UL, 0x10000000UL + PGSIZE, 0x10000000UL, PTE_R | PTE_W);
}

void vmem_enable(pagetable_t kpgtbl) {
    uint64 satp = MAKE_SATP(kpgtbl);
    w_satp(satp);
    sfence_vma();
}

uint64 vmem_translate(pagetable_t pagetable, uint64 va) {
    pte_t* pte = walk_lookup(pagetable, va);
    if (!pte || (*pte & PTE_V) == 0) return 0;
    uint64 pa = PTE2PA(*pte);
    return pa | (va & (PGSIZE - 1));
}

void vmem_selftest(void) {
    printf("[vmem] selftest start\n");
    pagetable_t pt = create_pagetable();
    if (!pt) panic("vmem selftest: pagetable alloc");
    void* page = alloc_page();
    if (!page) panic("vmem selftest: page alloc");
    uint64 va = 0x40000000UL;
    int r = map_page(pt, va, (uint64)page, PTE_R | PTE_W);
    if (r != 0) panic("vmem selftest: map_page");
    uint64 pa = vmem_translate(pt, va);
    if (pa != (uint64)page) panic("vmem selftest: translate mismatch");
    destroy_pagetable(pt);
    free_page(page);
    printf("[vmem] selftest passed\n");
}

// -------- Compatibility wrappers for user-style tests --------
int vm_mappages(pagetable_t pt, uint64 va, uint64 pa, uint64 sz, int perm) {
    uint64 a = PGROUNDDOWN(va);
    uint64 last = PGROUNDUP(va + sz);
    for (; a < last; a += PGSIZE, pa += PGSIZE) {
        pte_t* pte = walk_create(pt, a);
        if (!pte) return -1;
        if (*pte & PTE_V) {
            // allow remap to same pa with new perms
            *pte = PA2PTE(pa) | perm | PTE_V;
        } else {
            *pte = PA2PTE(pa) | perm | PTE_V;
        }
    }
    return 0;
}

int vm_unmappages(pagetable_t pt, uint64 va, uint64 sz, int do_free) {
    uint64 a = PGROUNDDOWN(va);
    uint64 last = PGROUNDUP(va + sz);
    for (; a < last; a += PGSIZE) {
        pte_t* pte = walk_lookup(pt, a);
        if (!pte || (*pte & PTE_V) == 0) return -1;
        if (do_free) {
            uint64 pa = PTE2PA(*pte);
            free_page((void*)pa);
        }
        *pte = 0;
    }
    sfence_vma();
    return 0;
}

void vm_print(pagetable_t pt) {
    dump_pagetable(pt);
}

void kvm_init(void) {
    vmem_setup_kernel();
}

void kvm_inithart(void) {
    pagetable_t kpgtbl = vmem_setup_kernel();
    vmem_enable(kpgtbl);
}
