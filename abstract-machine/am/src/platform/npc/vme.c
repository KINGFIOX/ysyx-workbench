#include <am.h>
#include <npc.h>
#include <riscv/riscv.h>
#include <klib.h>

#define PA2PTE(pa)       (((uintptr_t)(pa) >> 12) << 10)
#define PTE2PA(pte)      (((pte) >> 10) << 12)
#define VPN(level, va)   (((uintptr_t)(va) >> (12 + 9 * (level))) & 0x1FF)

static AddrSpace kas = {};
static void *(*pgalloc_usr)(int) = NULL;
static void (*pgfree_usr)(void *) = NULL;
static int vme_enable = 0;

static Area segments[] = {
  SIM_PADDR_SPACE
};

#define USER_SPACE RANGE(0x40000000, 0x80000000)

static inline void set_satp(void *pdir) {
  uintptr_t mode = 8ul << 60; // Sv39
  asm volatile("csrw satp, %0" : : "r"(mode | ((uintptr_t)pdir >> 12)));
  asm volatile("sfence.vma zero, zero");
}

static inline uintptr_t get_satp() {
  uintptr_t satp;
  asm volatile("csrr %0, satp" : "=r"(satp));
  return (satp & ((1ul << 44) - 1)) << 12;
}

bool vme_init(void *(*pgalloc_f)(int), void (*pgfree_f)(void *)) {
  pgalloc_usr = pgalloc_f;
  pgfree_usr = pgfree_f;

  kas.ptr = pgalloc_f(PGSIZE);

  for (int i = 0; i < LENGTH(segments); i++) {
    void *va = segments[i].start;
    for (; va < segments[i].end; va += PGSIZE) {
      map(&kas, va, va, 0);
    }
  }

  set_satp(kas.ptr);
  vme_enable = 1;

  return true;
}

void protect(AddrSpace *as) {
  PTE *updir = (PTE *)(pgalloc_usr(PGSIZE));
  as->ptr = updir;
  as->area = USER_SPACE;
  as->pgsize = PGSIZE;
  memcpy(updir, kas.ptr, PGSIZE);
}

void unprotect(AddrSpace *as) {
}

void __am_get_cur_as(Context *c) {
  c->pdir = (vme_enable ? (void *)get_satp() : NULL);
}

void __am_switch(Context *c) {
  if (vme_enable && c->pdir != NULL) {
    set_satp(c->pdir);
  }
}

void map(AddrSpace *as, void *va, void *pa, int prot) {
  uintptr_t vaddr = (uintptr_t)va & ~(uintptr_t)(PGSIZE - 1);
  uintptr_t paddr = (uintptr_t)pa & ~(uintptr_t)(PGSIZE - 1);

  PTE *pt = (PTE *)as->ptr;

  for (int level = 2; level > 0; level--) {
    int idx = VPN(level, vaddr);
    if (!(pt[idx] & PTE_V)) {
      void *page = pgalloc_usr(PGSIZE);
      pt[idx] = PA2PTE(page) | PTE_V;
    }
    pt = (PTE *)PTE2PA(pt[idx]);
  }

  int idx = VPN(0, vaddr);
  int flags = PTE_V | PTE_A | PTE_D;
  if (prot == 0) {
    flags |= PTE_R | PTE_W | PTE_X;
  } else {
    flags |= PTE_U | PTE_R | PTE_X;
    if (prot & MMAP_WRITE) flags |= PTE_W;
  }
  pt[idx] = PA2PTE(paddr) | flags;
}

Context *ucontext(AddrSpace *as, Area kstack, void *entry) {
  Context *c = (Context *)((uintptr_t)kstack.end - sizeof(Context));
  memset(c, 0, sizeof(Context));
  c->mepc = (uintptr_t)entry;
  // SPP=0 (return to U-mode), SPIE=1 (enable interrupts after sret)
  c->mstatus = (1ul << 5);
  c->pdir = as->ptr;
  return c;
}
