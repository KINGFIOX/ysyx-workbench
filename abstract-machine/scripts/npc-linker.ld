ENTRY(_start)

MEMORY {
  flash (rx)  : ORIGIN = _flash_base, LENGTH = _flash_size
  psram (rwx) : ORIGIN = _psram_base, LENGTH = _psram_size
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
  } > psram
  _data_lma = LOADADDR(.data);

  .bss : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > psram
  _stack_top = ALIGN(0x1000);
  . = _stack_top + 0x8000;
  _stack_pointer = .;
  end = .;
  _end = .;
  _heap_start = ALIGN(0x1000);
}
