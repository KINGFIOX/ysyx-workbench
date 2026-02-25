ENTRY(_start)

MEMORY {
  irom (rx)  : ORIGIN = _flash_base, LENGTH = _flash_size
  dram (rwx) : ORIGIN = _sdram_base, LENGTH = _sdram_size
}

SECTIONS {
  .text : {
    *(entry)
    *(.text*)
  } > irom

  .rodata : {
    *(.rodata*)
    *(.srodata*)
  } > irom
  _rodata_end = .;

  .data : AT(_rodata_end) {
    _data_start = .;
    *(.data*)
    *(.sdata*)
    _data_end = .;
  } > dram
  _data_lma = LOADADDR(.data);

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
