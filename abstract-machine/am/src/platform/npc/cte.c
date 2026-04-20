#include <am.h>
#include <riscv/riscv.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdint.h>

#define NR_REGS 32

typedef Context *(*handler_t)(Event, Context *);

static handler_t user_handler = NULL;

static void handle_unaligned_load(Context *c) {
  uint32_t instr = *(uint32_t *)c->mepc;
  uint32_t rd = (instr >> 7) & 0x1F;
  uint32_t funct3 = (instr >> 12) & 0x7;

  uintptr_t addr = c->mtval;
  uintptr_t value = 0;

  switch (funct3) {
    case 0: // LB
      value = (int8_t)*(uint8_t *)addr;
      break;
    case 1: // LH
      value = (int16_t)(*(uint8_t *)addr | (*(uint8_t *)(addr + 1) << 8));
      break;
    case 2: // LW
      value = *(uint8_t *)addr |
              (*(uint8_t *)(addr + 1) << 8) |
              (*(uint8_t *)(addr + 2) << 16) |
              (*(uint8_t *)(addr + 3) << 24);
      break;
    case 4: // LBU
      value = *(uint8_t *)addr;
      break;
    case 5: // LHU
      value = *(uint8_t *)addr | (*(uint8_t *)(addr + 1) << 8);
      break;
    default:
      printf("unknown load funct3: %d\n", funct3); panic("");
  }

  // x0 不可写
  if (rd != 0) {
    c->gpr[rd] = value;
  }
  c->mepc += 4;
}

static void handle_unaligned_store(Context *c) {
  uint32_t instr = *(uint32_t *)c->mepc;
  uint32_t funct3 = (instr >> 12) & 0x7;
  uint32_t rs2 = (instr >> 20) & 0x1F;

  uintptr_t addr = c->mtval;
  uintptr_t value = c->gpr[rs2];

  switch (funct3) {
    case 0: // SB
      *(uint8_t *)addr = value & 0xFF;
      break;
    case 1: // SH
      *(uint8_t *)addr = value & 0xFF;
      *(uint8_t *)(addr + 1) = (value >> 8) & 0xFF;
      break;
    case 2: // SW
      *(uint8_t *)addr = value & 0xFF;
      *(uint8_t *)(addr + 1) = (value >> 8) & 0xFF;
      *(uint8_t *)(addr + 2) = (value >> 16) & 0xFF;
      *(uint8_t *)(addr + 3) = (value >> 24) & 0xFF;
      break;
    default:
      printf("unknown store funct3: %d\n", funct3); panic("");
  }

  c->mepc += 4;
}

Context *__am_irq_handle(Context *c) {
  if (user_handler) {
    Event ev = {0};
    uintptr_t mcause = c->mcause;

    if ((intptr_t)mcause < 0) {
      uintptr_t interrupt_id = mcause & ((uintptr_t)-1 >> 1);
      switch (interrupt_id) {
        default:
          ev.event = EVENT_ERROR;
          ev.cause = mcause;
          break;
      }
    } else {
      switch (mcause) {
        case 4: // load address misaligned
          handle_unaligned_load(c); break;
        case 6: // store/AMO address misaligned
          handle_unaligned_store(c); break;
        case 11: // ecall from M-mode
          c->mepc += 4;
          if (c->GPR1 == (uintptr_t)-1) {
            ev.event = EVENT_YIELD;
          } else {
            ev.event = EVENT_SYSCALL;
          }
          break;
        default:
          ev.event = EVENT_ERROR;
          ev.cause = mcause;
          break;
      }
    }
    c = user_handler(ev, c);
  }

  return c;
}

extern void __am_asm_trap(void);

bool cte_init(handler_t handler) {
  asm volatile("csrw mtvec, %0" : : "r"(__am_asm_trap));

  user_handler = handler;

  return true;
}

typedef void (*entry_t)(void *);

Context *kcontext(Area kstack, entry_t entry, void *arg) {
  Context *c = (Context *)((uintptr_t)kstack.end - sizeof(Context));
  for (int i = 0; i < NR_REGS; i++) {
    c->gpr[i] = 0;
  }
  c->mepc = (uintptr_t)entry;
  c->gpr[10] = (uintptr_t)arg; // a0
  c->mstatus = 0x1800; // MPP = 3 (M-mode)
  c->mcause = 0x1800;
  c->pdir = NULL;
  return c;
}

__attribute__((weak)) void yield() {
  asm volatile("li a7, -1; ecall");
}

bool ienabled() {
  return false;
}

void iset(bool enable) {
}
