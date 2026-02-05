/*
 * .text/.rodata 放在 mrom 中 (代码和只读数据)
 * .data/.bss 的 VMA 在 sram 中 (运行时地址)
 * .data 的 LMA 在 mrom 中 (加载地址，紧跟 .rodata 后面)
 * 启动代码负责把 .data 从 mrom 复制到 sram
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

  /* 只读数据段也放在 mrom，包括 .srodata (small rodata) */
  .rodata : {
    *(.rodata*)
    *(.srodata*) /* riscv small data section */
  } > mrom
  _rodata_end = .;

  /*
    .data 在物理内存中, 最终其实会有两份:
      1. mrom(只读)
      2. sram(可读可写, 但是一开始是空的)
    既然 .data 会有两份: 那么也就意味着有两份地址:
      1. mrom: _data_lma
      2. sram: _data_start, _data_end
    AT, LOADADDR 配套使用: at(define), loadaddr(use)
  */
  .data : AT(_rodata_end) {
    _data_start = .;
    *(.data*)
    *(.sdata*)    /* RISC-V small data section */
    _data_end = .;
  } > sram
  _data_lma = LOADADDR(.data);

  /* BSS 段放在 sram，无需加载（启动代码清零） */
  .bss : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > sram

  /* 
   * 栈放在 sram 末尾，向下增长
   * _stack_pointer 指向 sram 末尾
   * 栈空间 = sram 末尾 - .bss 结束位置
   */
  _stack_pointer = _sram_base + _sram_size;
  _heap_start = .; /* FIXME: 实际上没有空间了 */
}
