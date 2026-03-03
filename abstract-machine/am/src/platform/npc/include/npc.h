#ifndef SIM_H__
#define SIM_H__

#include <klib-macros.h>

#include ISA_H // the macro `ISA_H` is defined in CFLAGS
               // it will be expanded as "x86/x86.h", "mips/mips32.h", ...

#define ebreak(code) asm volatile("mv a0, %0; ebreak" : :"r"(code))

#define DEVICE_BASE 0xa0000000

#define MMIO_BASE 0xa0000000

#define VGA_BASE (0x21000000)
#define VGA_SIZE (0x200000)

#define KBD_ADDR        (0x10011000)
#define RTC_ADDR        (DEVICE_BASE + 0x0000048)
#define VGACTL_ADDR     (DEVICE_BASE + 0x0000100)
#define AUDIO_ADDR      (DEVICE_BASE + 0x0000200)
#define DISK_ADDR       (DEVICE_BASE + 0x0000300)
#define FB_ADDR         VGA_BASE
#define AUDIO_SBUF_ADDR (MMIO_BASE   + 0x1200000)

extern char _mrom_base;
#define MROM_END ((uintptr_t)&_mrom_base + MROM_SIZE)

extern char _sram_base;
#define SRAM_END ((uintptr_t)&_sram_base + SRAM_SIZE)

extern char _flash_base;
#define FLASH_END ((uintptr_t)&_flash_base + FLASH_SIZE)

extern char _psram_base;
#define PSRAM_END  ((uintptr_t)&_psram_base + PSRAM_SIZE)

extern char _sdram_base;
#define SDRAM_END ((uintptr_t)&_sdram_base + SDRAM_SIZE)

#define PMEM_END SDRAM_END // NOTE: change to sdram

#define SIM_PADDR_SPACE \
  RANGE(&_flash_base, FLASH_END), \
  RANGE(&_psram_base, PMEM_END)

typedef uintptr_t PTE;

#define PGSIZE    4096

#endif
