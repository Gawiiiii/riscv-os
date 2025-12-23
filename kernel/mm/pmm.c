#include "include/pmm.h"
#include "include/pmem.h"
#include "include/printf.h"

typedef struct run {
    struct run* next;
} run_t;

static run_t* free_list = NULL;
static size_t total_pages = 0;
static size_t free_pages_cnt = 0;
static uint64 managed_start = 0;

static inline int aligned_page(void* pa) {
    return ((uint64)pa % PGSIZE) == 0;
}

void free_page(void* pa) {
    if (pa == NULL) {
        return;
    }
    if (!aligned_page(pa)) {
        printf("[pmm] free_page: unaligned address 0x%lx\n", (uint64)pa);
        return;
    }
    run_t* r = (run_t*)pa;
    r->next = free_list;
    free_list = r;
    free_pages_cnt++;
}

void* alloc_page(void) {
    if (free_list == NULL) {
        return NULL;
    }
    run_t* r = free_list;
    free_list = r->next;
    free_pages_cnt--;
    memset(r, 0, PGSIZE);
    return (void*)r;
}

void* alloc_pages(int n) {
    if (n <= 0) return NULL;
    void* first = NULL;
    void* prev = NULL;
    for (int i = 0; i < n; i++) {
        void* p = alloc_page();
        if (!p) {
            // rollback
            void* cur = first;
            while (cur) {
                void* next = *((void**)cur);
                free_page(cur);
                cur = next;
            }
            return NULL;
        }
        // reuse first word to chain pages while we allocate
        *((void**)p) = NULL;
        if (prev) {
            *((void**)prev) = p;
        } else {
            first = p;
        }
        prev = p;
    }
    // break temporary links
    void* cur = first;
    while (cur) {
        void* next = *((void**)cur);
        *((void**)cur) = 0;
        cur = next;
    }
    return first;
}

void pmm_init(void) {
    pmem_range_t r = pmem_usable_range();
    managed_start = PGROUNDUP(r.start);
    uint64 limit = PGROUNDDOWN(r.end);
    for (uint64 p = managed_start; p + PGSIZE <= limit; p += PGSIZE) {
        total_pages++;
        free_page((void*)p);
    }
    printf("[pmm] init: %lu pages managed (start=0x%lx end=0x%lx)\n",
           total_pages, managed_start, limit);
}

size_t pmm_total_pages(void) {
    return total_pages;
}

size_t pmm_free_pages(void) {
    return free_pages_cnt;
}

void pmm_selftest(void) {
    printf("[pmm] selftest start\n");
    size_t before = pmm_free_pages();
    void* p1 = alloc_page();
    void* p2 = alloc_page();
    void* p3 = alloc_page();
    if (!p1 || !p2 || !p3) {
        printf("[pmm] selftest: allocation failed\n");
        panic("pmm selftest alloc");
    }
    uint64* a = (uint64*)p1;
    uint64* b = (uint64*)p2;
    a[0] = 0xdeadbeefdeadbeef;
    b[0] = 0x1122334455667788;
    if (a[0] != 0xdeadbeefdeadbeef || b[0] != 0x1122334455667788) {
        panic("pmm selftest pattern");
    }
    free_page(p1);
    free_page(p2);
    free_page(p3);
    if (pmm_free_pages() != before) {
        panic("pmm selftest leak");
    }
    printf("[pmm] selftest passed\n");
}
