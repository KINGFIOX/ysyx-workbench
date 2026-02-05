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

  /* 复制 .data 段：从 _data_lma (mrom) 复制到 _data_start (sram) */
  la    a0, _data_start     /* dst: sram 中的 .data VMA */
  la    a1, _data_lma       /* src: mrom 中的 .data LMA */
  la    a2, _data_end       /* end: .data 段结束地址 */
  bgeu  a0, a2, 2f          /* 如果 .data 为空，跳过复制 */
1:
  lw    t0, 0(a1)           /* 从 mrom 加载 4 字节 */
  sw    t0, 0(a0)           /* 存储到 sram */
  addi  a0, a0, 4
  addi  a1, a1, 4
  bltu  a0, a2, 1b          /* 循环直到复制完成 */
2:
  /* 清零 .bss 段 */
  la    a0, _bss_start
  la    a1, _bss_end
  bgeu  a0, a1, 4f          /* 如果 .bss 为空，跳过清零 */
3:
  sw    zero, 0(a0)
  addi  a0, a0, 4
  bltu  a0, a1, 3b
4:

  /* 调用 _trm_init */
  call  _trm_init

.size _start, . - _start
