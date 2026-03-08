ENTRY(_start)

MEMORY {
  irom (rx)  : ORIGIN = _flash_base, LENGTH = _flash_size
  dram (rwx) : ORIGIN = _sdram_base, LENGTH = _sdram_size
}

SECTIONS {
  /* ===== FSBL: execute in place from flash ===== */
  .text.fsbl : {
    *(entry)
    *start.o(.text*)
    *fsbl.o(.text*)
  } > irom

  .rodata.fsbl : {
    *fsbl.o(.rodata*)
    *fsbl.o(.srodata*)
  } > irom

  /* ===== SSBL: stored in flash, FSBL copies to SDRAM ===== */
  .text.ssbl : {
    _ssbl_vma_start = .;
    *ssbl.o(.text*)
    *ssbl.o(.rodata*)
    *ssbl.o(.srodata*)
    _ssbl_vma_end = .;
    . = ALIGN(64);
  } > dram AT> irom
  _ssbl_lma = LOADADDR(.text.ssbl);

  /* ===== Application: stored in flash, SSBL copies to SDRAM ===== */
  .text : {
    _app_vma_start = .;
    *(.text*)
  } > dram AT> irom
  _app_lma = LOADADDR(.text);

  .rodata : {
    *(.rodata*)
    *(.srodata*)
  } > dram AT> irom

  .data : {
    *(.data*)
    *(.sdata*)
  } > dram AT> irom
  _app_vma_end = .;

  .bss : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > dram

  _stack_top = ALIGN(0x1000);
  . = _stack_top + 0x8000;
  _stack_pointer = .;
  end = .;
  _end = .;
  _heap_start = ALIGN(0x1000);
}
