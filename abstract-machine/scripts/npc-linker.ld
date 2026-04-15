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
  /* All loadable sections must be in ONE output section to avoid
     VMA/LMA alignment mismatch when copying from flash to SDRAM. */
  .text : {
    _app_vma_start = .;
    *(.text*)
    *(.rodata*)
    *(.srodata*)

    /* RT-Thread custom data sections (no-op when RT-Thread is not linked) */
    /* { */
    __fsymtab_start = .;
    KEEP(*(FSymTab))
    __fsymtab_end = .;
    . = ALIGN(8);
    __vsymtab_start = .;
    KEEP(*(VSymTab))
    __vsymtab_end = .;
    . = ALIGN(8);
    __rt_init_start = .;
    KEEP(*(SORT(.rti_fn*)))
    __rt_init_end = .;
    . = ALIGN(8);
    __rt_utest_tc_tab_start = .;
    KEEP(*(UtestTcTab))
    __rt_utest_tc_tab_end = .;
    . = ALIGN(8);
    __am_apps_data_start = .;
    *(__am_apps.data*)
    *(__am_apps.sdata*)
    __am_apps_data_end = .;
    . = ALIGN(8);
    /* } */

    *(.data*)
    *(.sdata*)

    . = ALIGN(4096);
    _ramdisk_start = .;
    KEEP(*(.ramdisk*))
    _ramdisk_end = .;

    _app_vma_end = .;
  } > dram AT> irom
  _app_lma = LOADADDR(.text);

  .bss : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > dram

  _stack_top = ALIGN(0x1000);
  . = _stack_top + 0x80000;
  _stack_pointer = .;
  end = .;
  _end = .;
  _heap_start = ALIGN(0x1000);
}
