#ifndef ARCH_H__
#define ARCH_H__

#include <stdint.h>

#define NR_REGS 32

struct Context {
  // TODO: fix the order of these members to match trap.S
  uintptr_t gpr[NR_REGS], mcause, mstatus, mepc, mtval;
  void *pdir;
};

#define GPR1 gpr[17] // a7

#define GPR2 gpr[0]
#define GPR3 gpr[0]
#define GPR4 gpr[0]
#define GPRx gpr[0]

#define MVENDORID                                                              \
  ({                                                                           \
    uintptr_t mvendorid;                                                       \
    asm volatile("csrr %0, mvendorid\n" : "=r"(mvendorid));                    \
    (mvendorid);                                                               \
  })

#define MARCHID                                                                \
  ({                                                                           \
    uintptr_t marchid;                                                         \
    asm volatile("csrr %0, marchid\n" : "=r"(marchid));                        \
    (marchid);                                                                 \
  })

#endif
