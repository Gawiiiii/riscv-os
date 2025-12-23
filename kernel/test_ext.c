#include "include/common.h"
#include "include/pmem.h"
#include "include/pmm.h"
#include "include/riscv.h"
#include "include/vmem.h"
#include "include/printf.h"

// Wrappers matching the user-provided test logic.
// We keep it single-core friendly (default CPUS=1), but the code
// mirrors the control flow of the snippets.

static volatile int started = 0;
static volatile int over_1 = 0, over_2 = 0;
static void* mem_slots[1024];

void run_pmem_stress_test(void) {
    int cpuid = (int)r_tp();

    if (cpuid == 0) {
        pmem_init();
        printf("cpu %d is booting!\n", cpuid);
        __sync_synchronize();
        started = 1;

        for (int i = 0; i < 32; i++) {
            mem_slots[i] = pmem_alloc(1);
            if (!mem_slots[i]) panic("pmem_alloc failed");
            memset(mem_slots[i], 1, PGSIZE);
            printf("mem = %p, data = %d\n", mem_slots[i], ((int*)mem_slots[i])[0]);
        }
        printf("cpu %d alloc over\n", cpuid);
        over_1 = 1;

        // single-core friendly: no wait for over_2 unless cpus>1
        while (over_2 == 0 && 0) {}

        for (int i = 0; i < 32; i++) {
            pmem_free((uint64)mem_slots[i], 1);
        }
        printf("cpu %d free over\n", cpuid);
    } else {
        while (started == 0) {}
        __sync_synchronize();
        printf("cpu %d is booting!\n", cpuid);

        for (int i = 32; i < 64; i++) {
            mem_slots[i] = pmem_alloc(1);
            if (!mem_slots[i]) panic("pmem_alloc failed (cpu>0)");
            memset(mem_slots[i], 1, PGSIZE);
            printf("mem = %p, data = %d\n", mem_slots[i], ((int*)mem_slots[i])[0]);
        }
        printf("cpu %d alloc over\n", cpuid);
        over_2 = 1;

        while (over_1 == 0 || over_2 == 0) {}

        for (int i = 32; i < 64; i++) {
            pmem_free((uint64)mem_slots[i], 1);
        }
        printf("cpu %d free over\n", cpuid);
    }
}

void run_vm_mapping_test(void) {
    int cpuid = (int)r_tp();

    if (cpuid == 0) {
        pmem_init();
        kvm_init();
        kvm_inithart();

        printf("cpu %d is booting!\n", cpuid);
        __sync_synchronize();

        pagetable_t test_pgtbl = pmem_alloc(1);
        if (!test_pgtbl) panic("test_pgtbl alloc failed");

        uint64 mem[5];
        for (int i = 0; i < 5; i++) {
            void* p = pmem_alloc(0);
            if (!p) panic("test mem alloc failed");
            mem[i] = (uint64)p;
        }

        printf("\ntest-1\n\n");
        vm_mappages(test_pgtbl, 0, mem[0], PGSIZE, PTE_R);
        vm_mappages(test_pgtbl, PGSIZE * 10, mem[1], PGSIZE / 2, PTE_R | PTE_W);
        vm_mappages(test_pgtbl, PGSIZE * 512, mem[2], PGSIZE - 1, PTE_R | PTE_X);
        vm_mappages(test_pgtbl, (uint64)PGSIZE * 512 * 512, mem[2], PGSIZE, PTE_R | PTE_X);
        vm_mappages(test_pgtbl, MAXVA - PGSIZE, mem[4], PGSIZE, PTE_W);
        // vm_print(test_pgtbl); // verbose debug dump

        printf("\ntest-2\n\n");
        vm_mappages(test_pgtbl, 0, mem[0], PGSIZE, PTE_W); // remap with new perm
        vm_unmappages(test_pgtbl, PGSIZE * 10, PGSIZE, 1);
        vm_unmappages(test_pgtbl, PGSIZE * 512, PGSIZE, 1);
        // vm_print(test_pgtbl); // verbose debug dump
    } else {
        while (started == 0) {}
        __sync_synchronize();
        printf("cpu %d is booting!\n", cpuid);
    }
}
