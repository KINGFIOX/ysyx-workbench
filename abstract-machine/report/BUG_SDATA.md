# 分析: 从 "Small Data Section 优化" 到 "ysyxSoC 的启动"

## 1. Small Data Section 优化

编译环境：优化等级 `-O2`，工具链 `riscv32-unknown-linux-gnu-gcc (GCC) 15.2.0`

GCC 会生成一个特殊的 `.sdata`（Small Data Section），这是一种访问全局变量的优化技术。

### 1.1 不使用 Small Data Section 的情况

访问全局变量时，通常需要这样操作：

```asm
la   t0, global      # 加载全局变量地址
lw   t1, 0(t0)       # 读取变量值
```

其中 `la` 是伪指令，会被汇编器展开为：

```asm
lui  t0, %hi(global)       # 加载地址高 20 位
addi t0, t0, %lo(global)   # 加载地址低 12 位
```

因此，访问一个全局变量实际需要 **三条指令**：

```asm
lui  t0, %hi(global)
addi t0, t0, %lo(global)
lw   t1, 0(t0)
```

这显然有些低效。能否像访问栈变量一样，只用一条指令就能访问全局变量呢？

### 1.2 使用 Small Data Section 的情况

答案是可以的，这就是 Small Data Section 的作用。

编译器会将较小的全局变量放入 `.sdata` 段，并使用 `gp`（Global Pointer）寄存器指向该区域的中心。由于 `lw` 指令的立即数偏移是 12 位有符号数（范围 -2048 ~ +2047），只要变量在 `gp ± 2KB` 范围内，就可以用 **单条指令** 访问：

```asm
lw   t1, offset(gp)   # 一条指令直接访问
```

GCC 的 `-G<n>` 选项（默认 `-G8`）控制这一行为：大小 ≤ n 字节的变量放入 `.sdata`，否则放入普通 `.data`。

---

## 2. 镜像文件生成解析

### 2.1 生成 ELF

参考资料：

- [GNU LD Manual - Section 3](https://home.cs.colorado.edu/~main/cs1300/doc/gnu/ld_3.html)
- [ELF 文件和链接](https://www.bilibili.com/video/BV1Ly4y1w7hn/)

针对 ysyxSoC 的分离式内存架构（MROM + SRAM），编写了如下链接脚本：

```ld
ENTRY(_start)

MEMORY {
  mrom (rx)  : ORIGIN = _mrom_base, LENGTH = _mrom_size
  sram (rwx) : ORIGIN = _sram_base, LENGTH = _sram_size
}

SECTIONS {
  /* 代码段：放在 mrom */
  .text : {
    *(entry)
    *(.text*)
  } > mrom

  /* 只读数据段：放在 mrom */
  .rodata : {
    *(.rodata*)
    *(.srodata*)
  } > mrom
  _rodata_end = .;

  /* 数据段：VMA 在 sram，LMA 在 mrom */
  .data : AT(_rodata_end) {
    _data_start = .;
    *(.data*)
    *(.sdata*)
    _data_end = .;
  } > sram
  _data_lma = LOADADDR(.data);

  /* BSS 段：放在 sram，无需加载 */
  .bss : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > sram

  /* 栈指针：指向 sram 末尾 */
  _stack_pointer = _sram_base + _sram_size;
}
```

### 2.2 段的放置策略

| 段        | 存放位置                | 说明                 |
| --------- | ----------------------- | -------------------- |
| `.text`   | mrom                    | 代码，只读           |
| `.rodata` | mrom                    | 只读数据             |
| `.data`   | mrom (LMA) + sram (VMA) | 初始化数据，需复制   |
| `.bss`    | sram                    | 未初始化数据，需清零 |

`.data` 段比较特殊，它在物理内存中有**两份**：

- **MROM 中的副本**：存放初始值（只读）
- **SRAM 中的副本**：运行时实际使用（可读写）

启动代码负责将 MROM 中的 `.data` 复制到 SRAM。

### 2.3 符号的定义与含义

链接脚本中定义的符号：

| 符号             | 定义方式                  | 含义                            |
| ---------------- | ------------------------- | ------------------------------- |
| `_rodata_end`    | `_rodata_end = .;`        | `.rodata` 段结束地址（mrom 中） |
| `_data_start`    | 在 `.data` 段内定义       | `.data` 的 VMA 起始（sram 中）  |
| `_data_end`      | 在 `.data` 段内定义       | `.data` 的 VMA 结束（sram 中）  |
| `_data_lma`      | `LOADADDR(.data)`         | `.data` 的 LMA（mrom 中）       |
| `_bss_start`     | 在 `.bss` 段内定义        | `.bss` 的起始地址               |
| `_bss_end`       | 在 `.bss` 段内定义        | `.bss` 的结束地址               |
| `_stack_pointer` | `_sram_base + _sram_size` | 栈顶（sram 末尾）               |

**为什么没有 `_data_lma_end`？**

因为 `.data` 在 mrom 和 sram 中的大小相同，可以通过计算得出：

```
_data_lma_end = _data_lma + (_data_end - _data_start)
```

### 2.4 LMA 与 VMA

链接器为每个段维护两个地址：

| 地址类型 | 全称                   | 含义       | 设置方式   |
| -------- | ---------------------- | ---------- | ---------- |
| VMA      | Virtual Memory Address | 运行时地址 | `> region` |
| LMA      | Load Memory Address    | 加载时地址 | `AT(...)`  |

对于 `.data` 段：

- `> sram` 设置 VMA = 0x0f000000（运行时在 sram）
- `AT(_rodata_end)` 设置 LMA = 紧跟 `.rodata`（加载时在 mrom）

---

## 3. 生成 BIN

### 3.1 objcopy 的工作原理

`objcopy -O binary` 将 ELF 转换为原始二进制文件：

1. 提取所有**可加载且有内容**的段（Type = LOAD，FileSiz > 0）
2. 按 **LMA（PhysAddr）** 排序
3. 生成从最低 LMA 到最高 LMA 的**连续内存镜像**
4. 段之间的空隙用**零填充**

### 3.2 链接脚本如何影响 BIN

链接脚本不直接生成 BIN，但它决定了 ELF 的结构：

```
链接脚本              ELF Program Header           BIN 文件
┌─────────────┐      ┌────────────────────────┐      ┌─────────────┐
│ > region    │ ───→ │ virtual memory address │      │             │
│ AT(...)     │ ───→ │ load memory address    │ ───→ │ 段的位置     │
│ 段内容       │ ───→ │ FileSiz                │ ───→ │ 段的大小     │
│ 段类型       │ ───→ │ Type                   │ ───→ │ 是否输出     │
└─────────────┘      └────────────────────────┘      └─────────────┘
```

**Type 字段决定是否输出到 BIN：**

| Type           | 含义           | 是否输出到 BIN         |
| -------------- | -------------- | ---------------------- |
| `PT_LOAD`      | 需要加载到内存 | 是（如果 FileSiz > 0） |
| `PT_NULL`      | 未使用         | 否                     |
| `PT_NOTE`      | 辅助信息       | 否                     |
| `PT_GNU_STACK` | 栈属性         | 否                     |
| ...            | 其他类型       | 否                     |

只有 `PT_LOAD` 类型且 `FileSiz > 0` 的段会被 objcopy 输出到 BIN 文件。

**Section 类型也有影响：**

| Section Type   | 含义                    | FileSiz |
| -------------- | ----------------------- | ------- |
| `SHT_PROGBITS` | 有实际内容（代码/数据） | > 0     |
| `SHT_NOBITS`   | 无内容（如 .bss）       | = 0     |

`.bss` 段虽然也是 `PT_LOAD`，但因为是 `SHT_NOBITS` 类型，`FileSiz = 0`，所以不会输出到 BIN。

## 4. 启动流程

### 4.1 数据平面与控制平面

计算机的很多领域都可以分为两部分：**数据平面**和**控制平面**，或者说 data 和 meta。

| 领域       | 控制平面                               | 数据平面                |
| ---------- | -------------------------------------- | ----------------------- |
| ELF 文件   | Program Header、Section Header、符号表 | .text、.data 的实际内容 |
| 计算机网络 | 路由协议、路由表交换                   | 用户数据包转发          |
| 处理器设计 | 控制信号、状态机                       | ALU 运算、数据通路      |

ELF 经过 `objcopy -O binary` 后，**只剩下数据平面的内容**——纯粹的二进制指令和数据，所有元信息都被剥离。

### 4.2 裸机启动的约定

理想情况下，BIN 文件的结构应该是：

```
BIN 文件:
┌────────────────────────┐  offset 0x00000000
│ mv s0, zero            │  ← 第一条指令
│ la sp, _stack_pointer  │
│ call _trm_init         │
│ ...                    │
└────────────────────────┘
```

BIN 文件的第一个 word 就是 `start.S` 中的第一条指令 `mv s0, zero`（编码为 `0x00000413`）。

对于裸机程序，没有 Linux 那样的加载器（loader）来解析 ELF 头、设置内存映射。硬件上电后，PC 被初始化为 `0x20000000`（MROM 起始地址），CPU 直接从该地址取指执行。

因此，必须确保：
- **BIN 文件被完整加载到 MROM（0x20000000）**
- **BIN 的第一个字节对应 0x20000000 地址**

这是一个隐式的约定：链接脚本、加载器必须一致。

---

## 5. Small Data Section 导致的问题

### 5.1 问题现象

在测试 `am-kernels/tests/cpu-tests` 时，`wanshu` 这个测试用例失败了：

```
[init_mrom] The image size = 285213308  # 约 285 MB！
[init_mrom] Warning: image size exceeds MROM size, truncated

invalid opcode(PC = 0x20000000):
    06 00 00 00 1c 00 00 00 ...  # 不是 mv s0, zero (0x00000413)
```

第一条指令应该是 `0x00000413`，但实际取到的是 `0x00000006`。

### 5.2 原因分析

`wanshu.c` 中有一个小数组：

```c
int ans[] = {6, 28};  // 8 字节
```

由于 GCC 的 `-G8` 默认设置，这个 8 字节的数组被放入了 `.sdata` 段（Small Data Section）。

而原始链接脚本只处理了 `.data*`，没有处理 `.sdata*`：

```ld
.data : AT(_rodata_end) {
    *(.data*)
    /* 缺少 *(.sdata*) */
} > sram
```

**问题：`.sdata` 没有被任何规则匹配，为什么它的地址是 0x0f000000？**

这涉及到链接器对 **Orphan Section** 的处理机制：

1. **Orphan Section**：链接脚本中没有显式规则匹配的段
2. **默认行为**：链接器会根据段的**属性**自动放置Orphan Section
3. **放置策略**：
   - 查找属性兼容的内存区域（读/写/执行权限）
   - `.sdata` 是可写数据段（WA 标志）
   - `mrom` 是 `(rx)`（只读+可执行），不兼容
   - `sram` 是 `(rwx)`（可读写+可执行），兼容
   - 因此 `.sdata` 被放入 sram 区域

```
MEMORY 定义:
  mrom (rx)   ← 只读，不能放 .sdata（需要写权限）
  sram (rwx)  ← 可写，.sdata 被放在这里
```

4. **地址分配**：Orphan Section被放在兼容区域中，紧跟在已定义段之后
   - `.bss` 结束于某个 sram 地址
   - `.sdata` 紧跟其后（或根据对齐要求调整）

实际上，可以用 `--orphan-handling=warn` 让链接器报告Orphan Section：

```bash
riscv32-unknown-linux-gnu-ld --orphan-handling=warn ...
# warning: orphan section `.sdata.ans' being placed in section `.sdata.ans'
```

导致 `.sdata` 段：
- **VMA = 0x0f000000**（sram，由链接器自动放置）
- **LMA = VMA = 0x0f000000**（默认，未用 AT 指定）

### 5.3 objcopy 的行为

objcopy 按 LMA 从低到高输出：

```
LMA 分布:                              BIN 文件:
0x0f000000 ┌──────────┐               ┌──────────┐ offset 0
           │ .sdata   │  ← LMA        │ 06000000 │ ← ans[0] = 6
           │ {6, 28}  │               │ 1c000000 │ ← ans[1] = 28
           └──────────┘               ├──────────┤
                │                     │          │
                │ 285 MB              │ 零填充    │ ~285 MB
                ↓                     │          │
0x20000000 ┌──────────┐               ├──────────┤
           │ .text    │               │ .text    │
           └──────────┘               └──────────┘
```

BIN 文件的前 8 字节是 `{6, 28}` 的小端表示：`06 00 00 00 1c 00 00 00`。

### 5.4 加载后的结果

NPC 加载器将 BIN 文件加载到 MROM（0x20000000），但由于 BIN 文件有 285 MB，超过 MROM 的 4 KB，被截断。

截断后，MROM 里装的是 BIN 文件的**开头 4 KB**，也就是 `.sdata` 的内容和大量零填充：

```
MROM 内容 (加载后):
0x20000000: 06 00 00 00  ← 应该是 mv s0, zero，实际是 ans[0]
0x20000004: 1c 00 00 00  ← 应该是 la sp，实际是 ans[1]
0x20000008: 00 00 00 00  ← 零填充
...
```

CPU 从 0x20000000 取指，得到 `0x00000006`，这不是合法指令，触发非法指令异常。

### 5.5 解决方案

在链接脚本中将 `.sdata*` 纳入 `.data` 段，共享同一个 LMA：

```ld
.data : AT(_rodata_end) {
    *(.data*)
    *(.sdata*)    /* 添加这一行 */
} > sram
```

修复后，所有数据段的 LMA 都在 MROM 中，BIN 文件大小恢复正常（约 600 字节）。

---

## 6. 总结

| 阶段    | 关键点                                            |
| ------- | ------------------------------------------------- |
| 编译    | GCC 可能生成 `.sdata`/`.srodata`，由 `-G<n>` 控制 |
| 链接    | 用 `AT(...)` 确保所有数据段的 LMA 在 MROM 中      |
| objcopy | 按 LMA 输出连续镜像，LMA 分散会导致巨型 BIN       |
| 加载    | BIN 被加载到固定地址，无元信息，依赖约定          |

**核心教训**：链接脚本必须处理所有可能的段（包括 `.sdata*`、`.srodata*`、`.sbss*`），否则遗漏的段会使用默认 LMA，破坏 BIN 文件的布局。
