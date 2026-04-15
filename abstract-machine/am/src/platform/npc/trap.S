#define concat_temp(x, y) x ## y
#define concat(x, y) concat_temp(x, y)
#define MAP(c, f) c(f)

#if __riscv_xlen == 32
#define LOAD  lw
#define STORE sw
#define XLEN  4
#else
#define LOAD  ld
#define STORE sd
#define XLEN  8
#endif

#define REGS_LO16(f) \
      f( 1)       f( 3) f( 4) f( 5) f( 6) f( 7) f( 8) f( 9) \
f(10) f(11) f(12) f(13) f(14) f(15)

#define REGS_HI16(f) \
                                    f(16) f(17) f(18) f(19) \
f(20) f(21) f(22) f(23) f(24) f(25) f(26) f(27) f(28) f(29) \
f(30) f(31)

#define NR_REGS 32

#define REGS(f) REGS_LO16(f) REGS_HI16(f)

#define PUSH(n) STORE concat(x, n), (n * XLEN)(sp);
#define POP(n)  LOAD  concat(x, n), (n * XLEN)(sp);

// Context: gpr[32] + mcause + mstatus + mepc + mtval + pdir = 37 words
#define CONTEXT_SIZE  ((NR_REGS + 4 + 1) * XLEN)
#define OFFSET_SP     ( 2 * XLEN)
#define OFFSET_CAUSE  ((NR_REGS + 0) * XLEN)
#define OFFSET_STATUS ((NR_REGS + 1) * XLEN)
#define OFFSET_EPC    ((NR_REGS + 2) * XLEN)
#define OFFSET_TVAL   ((NR_REGS + 3) * XLEN)
#define OFFSET_PDIR   ((NR_REGS + 4) * XLEN)

// Convention: sscratch = kernel_sp when in U-mode, 0 when in S-mode.
// This lets us distinguish user vs kernel traps.

.align 3
.globl __am_asm_trap
__am_asm_trap:
  csrrw sp, sscratch, sp        // swap sp <-> sscratch
  bnez  sp, _save_ctx           // sp != 0: from U-mode (sscratch had kernel_sp)
  csrr  sp, sscratch            // sp == 0: from S-mode, restore kernel sp
_save_ctx:
  addi sp, sp, -CONTEXT_SIZE

  MAP(REGS, PUSH)               // save x1,x3-x31 (excludes x0 and x2)

  csrr t0, sscratch
  STORE t0, OFFSET_SP(sp)       // save original sp (user or kernel) as gpr[2]

  csrr t0, scause
  csrr t1, sstatus
  csrr t2, sepc
  csrr t3, stval

  STORE t0, OFFSET_CAUSE(sp)
  STORE t1, OFFSET_STATUS(sp)
  STORE t2, OFFSET_EPC(sp)
  STORE t3, OFFSET_TVAL(sp)

  csrw sscratch, zero            // mark we are in S-mode now

  // Save current address space (reads satp before we switch to kernel PT)
  mv a0, sp
  call __am_get_cur_as

  // Switch to kernel page table for full MMIO access
  lla  t0, kernel_satp
  LOAD t0, 0(t0)
  beqz t0, 1f                   // skip if kernel_satp not yet set (early boot)
  csrw satp, t0
  sfence.vma zero, zero
1:

  mv a0, sp
  call __am_irq_handle
  mv sp, a0                     // may return a different Context (context switch)

  // Switch to target process's address space
  mv a0, sp
  call __am_switch

.globl __am_asm_restore
__am_asm_restore:
  LOAD t1, OFFSET_STATUS(sp)
  LOAD t2, OFFSET_EPC(sp)
  csrw sstatus, t1
  csrw sepc, t2

  // Check SPP (bit 8) to determine return privilege
  andi t0, t1, (1 << 8)
  bnez t0, _restore_kernel

_restore_user:
  // Set sscratch = kernel_sp for next user trap
  addi t0, sp, CONTEXT_SIZE
  csrw sscratch, t0

  MAP(REGS, POP)                // restore x1,x3-x31
  LOAD sp, OFFSET_SP(sp)       // restore user sp (must be last)
  sret

_restore_kernel:
  MAP(REGS, POP)                // restore x1,x3-x31
  addi sp, sp, CONTEXT_SIZE    // pop context frame (sp was kernel sp)
  sret
