#include "include/pmm.h"
#include "include/printf.h"
#include "include/vmem.h"
#include "include/test.h"

static void assert_nonnull(void* ptr, const char* msg) {
    if (!ptr) {
        panic(msg);
    }
}

void test_physical_memory(void) {
    printf("[test] physical memory start\n");
    size_t before = pmm_free_pages();
    void* p1 = alloc_page();
    void* p2 = alloc_page();
    void* p3 = alloc_page();

    assert_nonnull(p1, "alloc p1");
    assert_nonnull(p2, "alloc p2");
    assert_nonnull(p3, "alloc p3");

    if (p1 == p2 || p1 == p3 || p2 == p3) {
        panic("duplicate physical pages");
    }

    uint64* a = (uint64*)p1;
    uint64* b = (uint64*)p2;
    uint64* c = (uint64*)p3;
    a[0] = 0x1111222233334444;
    b[0] = 0x5555666677778888;
    c[0] = 0x9999aaaabbbbcccc;

    if (a[0] != 0x1111222233334444 || b[0] != 0x5555666677778888 || c[0] != 0x9999aaaabbbbcccc) {
        panic("memory pattern mismatch");
    }

    free_page(p1);
    free_page(p2);
    free_page(p3);

    if (pmm_free_pages() != before) {
        panic("physical memory leak");
    }
    printf("[test] physical memory ok (free=%lu)\n", (uint64)pmm_free_pages());
}

void test_pagetable(void) {
    printf("[test] pagetable start\n");
    pagetable_t pt = create_pagetable();
    assert_nonnull(pt, "create pagetable");
    void* page = alloc_page();
    assert_nonnull(page, "alloc mapping page");
    uint64 va = 0x40000000UL;
    int r = map_page(pt, va, (uint64)page, PTE_R | PTE_W);
    if (r != 0) panic("map_page failed");
    pte_t* pte = walk_lookup(pt, va);
    if (!pte || (*pte & PTE_V) == 0) panic("walk_lookup failed");
    if (PTE2PA(*pte) != (uint64)page) panic("pte mismatch");

    // Clear mapping before freeing leaf page
    *pte = 0;
    destroy_pagetable(pt);
    free_page(page);
    printf("[test] pagetable ok\n");
}
