#include "include/vmem.h"
#include "include/types.h"
#include "include/memlayout.h"
#include "include/printf.h"
#include "include/common.h"

// Basic user memory access helpers modeled after xv6-style copyin/copyout.
// They rely on the supplied pagetable to translate user virtual addresses to
// physical addresses. If the pagetable is NULL, fall back to treating the
// virtual address as already accessible (kernel direct map).

static int within_user(uint64 va, uint64 len) {
    if (va >= KERNBASE) return 0;
    if (len == 0) return 1;
    uint64 end = va + len - 1;
    return end < KERNBASE && end >= va;
}

int user_access_ok(pagetable_t pagetable, uint64 va, uint64 len) {
    if (!within_user(va, len)) return 0;
    if (len == 0) return 1;
    uint64 cur = va;
    uint64 remaining = len;
    while (remaining > 0) {
        uint64 pa = pagetable ? vmem_translate(pagetable, cur) : cur;
        if (pa == 0) return 0;
        uint64 page_left = PGSIZE - (cur & (PGSIZE - 1));
        uint64 n = remaining < page_left ? remaining : page_left;
        cur += n;
        remaining -= n;
    }
    return 1;
}

int copyin(pagetable_t pagetable, char* dst, uint64 srcva, uint64 len) {
    uint64 va = srcva;
    uint64 remaining = len;
    while (remaining > 0) {
        if (!within_user(va, 1)) return -1;
        uint64 pa = pagetable ? vmem_translate(pagetable, va) : va;
        if (pa == 0) return -1;
        uint64 page_left = PGSIZE - (va & (PGSIZE - 1));
        uint64 n = remaining < page_left ? remaining : page_left;
        memcpy(dst, (void*)(pa), n);
        dst += n;
        va += n;
        remaining -= n;
    }
    return 0;
}

int copyout(pagetable_t pagetable, uint64 dstva, const char* src, uint64 len) {
    uint64 va = dstva;
    uint64 remaining = len;
    while (remaining > 0) {
        if (!within_user(va, 1)) return -1;
        uint64 pa = pagetable ? vmem_translate(pagetable, va) : va;
        if (pa == 0) return -1;
        uint64 page_left = PGSIZE - (va & (PGSIZE - 1));
        uint64 n = remaining < page_left ? remaining : page_left;
        memcpy((void*)pa, src, n);
        src += n;
        va += n;
        remaining -= n;
    }
    return 0;
}

int copyinstr(pagetable_t pagetable, char* dst, uint64 srcva, uint64 max) {
    uint64 va = srcva;
    int copied = 0;
    while (copied < max) {
        if (!within_user(va, 1)) return -1;
        uint64 pa = pagetable ? vmem_translate(pagetable, va) : va;
        if (pa == 0) return -1;
        char* p = (char*)pa;
        uint64 page_left = PGSIZE - (va & (PGSIZE - 1));
        for (uint64 i = 0; i < page_left && copied < max; i++) {
            char c = p[i];
            dst[copied++] = c;
            if (c == 0) {
                return 0;
            }
        }
        va = PGROUNDUP(va + 1);
    }
    return -1;
}
