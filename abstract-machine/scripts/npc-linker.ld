ENTRY(_start)

MEMORY {
  flash (rx)  : ORIGIN = _flash_base, LENGTH = _flash_size
  sram (rwx) : ORIGIN = _sram_base, LENGTH = _sram_size
}

SECTIONS {
  .text : {
    *(entry)
    *(.text*)
  } > flash

  .rodata : {
    *(.rodata*)
    *(.srodata*)
  } > flash
  _rodata_end = .;

  .data : AT(_rodata_end) {
    _data_start = .;
    *(.data*)
    *(.sdata*)
    _data_end = .;
  } > sram
  _data_lma = LOADADDR(.data);

  .bss : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > sram

  _stack_pointer = _sram_base + _sram_size;
  _heap_start = .; /* FIXME: 实际上没有空间了 */
}
