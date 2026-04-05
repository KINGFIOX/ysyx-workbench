#ifndef NPC_H__
#define NPC_H__

#include <klib-macros.h>

#include ISA_H // the macro `ISA_H` is defined in CFLAGS
               // it will be expanded as "x86/x86.h", "mips/mips32.h", ...

#define ebreak(code) asm volatile("mv a0, %0; ebreak" : :"r"(code))

// QEMU virt compatible addresses
#define CLINT_BASE  0x02000000
#define PLIC_BASE   0x0c000000

#define VGA_BASE (0x21000000)
#define VGA_SIZE (0x200000)

#define KBD_ADDR        (0x10011000)
#define RTC_ADDR        (CLINT_BASE + 0xBFF8)
#define VGACTL_ADDR     (VGA_BASE + VGA_SIZE - 0x100)
#define AUDIO_ADDR      0
#define DISK_ADDR       0
#define FB_ADDR         VGA_BASE
#define AUDIO_SBUF_ADDR 0

extern char _sram_base;
#define SRAM_END ((uintptr_t)&_sram_base + SRAM_SIZE)

extern char _flash_base;
#define FLASH_END ((uintptr_t)&_flash_base + FLASH_SIZE)

extern char _sdram_base;
#define SDRAM_END ((uintptr_t)&_sdram_base + SDRAM_SIZE)

#define PMEM_END SDRAM_END

#define SIM_PADDR_SPACE \
  RANGE(&_flash_base, FLASH_END), \
  RANGE(&_sdram_base, PMEM_END)

typedef uintptr_t PTE;

#define PGSIZE    4096

#endif
