/* NPC 专用链接脚本
 * .text 放在 mrom 中
 * .data 放在 sram 中
 * 地址通过 LDFLAGS 的 --defsym 从 $NPC_HOME/.config 获取
 */

ENTRY(_start)

MEMORY {
  mrom (rx)  : ORIGIN = _mrom_base, LENGTH = _mrom_size
  sram (rwx) : ORIGIN = _sram_base, LENGTH = _sram_size
}

SECTIONS {
  /* 代码段放在 mrom */
  .text : {
    *(entry)
    *(.text*)
  } > mrom
  etext = .;
  _etext = .;

  /* 只读数据段也放在 mrom */
  .rodata : {
    *(.rodata*)
  } > mrom

  /* 数据段放在 sram */
  .data : {
    *(.data*)
  } > sram
  edata = .;
  _data = .;

  /* BSS 段放在 sram */
  .bss : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
  } > sram

  /* 栈放在 sram */
  _stack_top = ALIGN(0x1000);
  . = _stack_top + 0x8000;
  _stack_pointer = .;
  end = .;
  _end = .;
  _heap_start = ALIGN(0x1000);
}
