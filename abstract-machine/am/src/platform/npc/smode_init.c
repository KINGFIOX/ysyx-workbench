#include <stdint.h>

extern void _trm_init(void);

static inline void csrw_mstatus(uint64_t val) {
  asm volatile("csrw mstatus, %0" : : "r"(val));
}

static inline uint64_t csrr_mstatus(void) {
  uint64_t val;
  asm volatile("csrr %0, mstatus" : "=r"(val));
  return val;
}

void smode_init(void) {
  // 1. Grant S-mode full access to all physical memory via PMP
  //    TOR mode (top-of-range), covering 0 to 0x3FFFFFFFFFFFFF (max PA)
  asm volatile("csrw pmpaddr0, %0" : : "r"(0x3fffffffffffffull));
  //    pmpcfg0: A=TOR(01), R=1, W=1, X=1 -> 0x0F
  asm volatile("csrw pmpcfg0, %0" : : "r"(0xful));

  // 2. Delegate all exceptions and interrupts to S-mode
  asm volatile("csrw medeleg, %0" : : "r"(0xfffful));
  asm volatile("csrw mideleg, %0" : : "r"(0xfffful));

  // 3. Enable S-mode external and timer interrupts in sie
  //    SIE_SEIE (bit 9) | SIE_STIE (bit 5)
  asm volatile("csrs sie, %0" : : "r"((1ul << 9) | (1ul << 5)));

  // 4. Disable paging and clear sscratch
  asm volatile("csrw satp, %0" : : "r"(0ul));
  asm volatile("csrw sscratch, %0" : : "r"(0ul));

  // 5. Set MPP = S-mode (01) in mstatus for mret
  uint64_t mstatus = csrr_mstatus();
  mstatus &= ~(3ul << 11); // clear MPP
  mstatus |= (1ul << 11);  // MPP = 01 (S-mode)
  csrw_mstatus(mstatus);

  // 6. Set mepc to _trm_init so mret jumps there in S-mode
  asm volatile("csrw mepc, %0" : : "r"(_trm_init));

  // 7. Switch to S-mode
  asm volatile("mret");
}
