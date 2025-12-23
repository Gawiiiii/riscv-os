#ifndef _VMEM_H_
#define _VMEM_H_

#include "common.h"
#include "riscv.h"

pagetable_t create_pagetable(void);
pte_t*      walk_create(pagetable_t pagetable, uint64 va);
pte_t*      walk_lookup(pagetable_t pagetable, uint64 va);
int         map_page(pagetable_t pagetable, uint64 va, uint64 pa, int perm);
void        destroy_pagetable(pagetable_t pagetable);
void        dump_pagetable(pagetable_t pagetable);

// Kernel paging helpers
pagetable_t vmem_setup_kernel(void);
pagetable_t vmem_kernel_pagetable(void);
void        vmem_map_kernel_segments(pagetable_t kpgtbl);
void        vmem_enable(pagetable_t kpgtbl);
uint64      vmem_translate(pagetable_t pagetable, uint64 va);
void        vmem_selftest(void);

// Compatibility wrappers for user-style tests
int         vm_mappages(pagetable_t pt, uint64 va, uint64 pa, uint64 sz, int perm);
int         vm_unmappages(pagetable_t pt, uint64 va, uint64 sz, int do_free);
void        vm_print(pagetable_t pt);
void        kvm_init(void);
void        kvm_inithart(void);

#endif // _VMEM_H_
