/* NPC 平台启动代码
 * 1. 初始化 sp
 * 2. 复制 .data 段从 mrom (LMA) 到 sram (VMA)
 * 3. 清零 .bss 段
 * 4. 调用 _trm_init
 */

.section entry, "ax"
.globl _start
.type _start, @function

_start:
  /* 初始化 s0 和 sp */
  mv    s0, zero
  la    sp, _stack_pointer
  
  /* fsbl */
  call fsbl

/* .size 设置符号大小的伪指令
 * _start 要设置大小的符号
 * . - _start 计算出的符号的大小
 */
.size _start, . - _start
