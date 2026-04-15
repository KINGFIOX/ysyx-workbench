#include <am.h>
#include <riscv/riscv.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdint.h>

#define NR_REGS 32

#define SSTATUS_SIE  (1ul << 1)
#define SSTATUS_SPIE (1ul << 5)
#define SSTATUS_SPP  (1ul << 8)

typedef Context *(*handler_t)(Event, Context *);

static handler_t user_handler = NULL;

Context *__am_irq_handle(Context *c) {
  if (user_handler) {
    Event ev = {0};
    uintptr_t cause = c->mcause;

    if ((intptr_t)cause < 0) {
      uintptr_t interrupt_id = cause & ((uintptr_t)-1 >> 1);
      switch (interrupt_id) {
        case 1: // S-mode software interrupt
          ev.event = EVENT_IRQ_IODEV;
          break;
        case 5: // S-mode timer interrupt
          ev.event = EVENT_IRQ_TIMER;
          break;
        case 9: // S-mode external interrupt
          ev.event = EVENT_IRQ_IODEV;
          break;
        default:
          ev.event = EVENT_ERROR;
          ev.cause = cause;
          break;
      }
    } else {
      switch (cause) {
        case 8: // ecall from U-mode
          c->mepc += 4;
          if (c->GPR1 == (uintptr_t)-1) {
            ev.event = EVENT_YIELD;
          } else {
            ev.event = EVENT_SYSCALL;
          }
          break;
        case 12: // instruction page fault
          ev.event = EVENT_PAGEFAULT;
          ev.cause = cause;
          ev.ref = c->mtval;
          break;
        case 13: // load page fault
          ev.event = EVENT_PAGEFAULT;
          ev.cause = cause;
          ev.ref = c->mtval;
          break;
        case 15: // store/AMO page fault
          ev.event = EVENT_PAGEFAULT;
          ev.cause = cause;
          ev.ref = c->mtval;
          break;
        default:
          ev.event = EVENT_ERROR;
          ev.cause = cause;
          break;
      }
    }
    c = user_handler(ev, c);
  }

  return c;
}

extern void __am_asm_trap(void);

bool cte_init(handler_t handler) {
  asm volatile("csrw stvec, %0" : : "r"(__am_asm_trap));

  user_handler = handler;

  return true;
}

typedef void (*entry_t)(void *);

Context *kcontext(Area kstack, entry_t entry, void *arg) {
  Context *c = (Context *)((uintptr_t)kstack.end - sizeof(Context));
  memset(c, 0, sizeof(Context));
  c->mepc = (uintptr_t)entry;
  c->gpr[10] = (uintptr_t)arg; // a0
  c->mstatus = SSTATUS_SPP | SSTATUS_SPIE; // SPP=S-mode, SPIE=1
  c->pdir = NULL;
  return c;
}

__attribute__((weak)) void yield() {
  asm volatile("li a7, -1; ecall");
}

bool ienabled() {
  uintptr_t sstatus;
  asm volatile("csrr %0, sstatus" : "=r"(sstatus));
  return (sstatus & SSTATUS_SIE) != 0;
}

void iset(bool enable) {
  if (enable) {
    asm volatile("csrs sstatus, %0" : : "r"(SSTATUS_SIE));
  } else {
    asm volatile("csrc sstatus, %0" : : "r"(SSTATUS_SIE));
  }
}
