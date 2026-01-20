# ELF

https://ysyx.oscc.cc/slides/2306/14.html#/elf文件格式

## 常用前缀

| 前缀 | 全称 | 含义 |
|------|------|------|
| `SHF_` | Section Header Flags | Section 的属性标志 |
| `SHT_` | Section Header Type | Section 的类型 |
| `PF_` | Program header Flags | Segment 的权限标志 |
| `PT_` | Program header Type | Segment 的类型 |
| `ET_` | ELF Type | ELF 文件类型 |
| `EM_` | ELF Machine | 目标架构 |

## SHF_ (Section Header Flags)

| 标志 | 值 | 含义 |
|------|---|------|
| `SHF_WRITE` | 0x1 | 可写 |
| `SHF_ALLOC` | 0x2 | 运行时需要分配内存 |
| `SHF_EXECINSTR` | 0x4 | 包含可执行指令 |
| `SHF_MERGE` | 0x10 | 可合并的数据 |
| `SHF_STRINGS` | 0x20 | 包含字符串 |

## PF_ (Program Header Flags)

| 标志 | 值 | 含义 |
|------|---|------|
| `PF_X` | 0x1 | 可执行 |
| `PF_W` | 0x2 | 可写 |
| `PF_R` | 0x4 | 可读 |

## PT_ (Program Header Type)

| 类型 | 值 | 含义 |
|------|---|------|
| `PT_NULL` | 0 | 未使用 |
| `PT_LOAD` | 1 | 可加载段 |
| `PT_DYNAMIC` | 2 | 动态链接信息 |
| `PT_INTERP` | 3 | 解释器路径 |
| `PT_NOTE` | 4 | 辅助信息 |
| `PT_PHDR` | 6 | Program Header 表自身 |

## ET_ (ELF Type)

| 类型 | 值 | 含义 |
|------|---|------|
| `ET_NONE` | 0 | 无类型 |
| `ET_REL` | 1 | 可重定位文件 (.o) |
| `ET_EXEC` | 2 | 可执行文件 |
| `ET_DYN` | 3 | 共享目标文件 (.so) |
| `ET_CORE` | 4 | Core 文件 |

## EM_ (ELF Machine)

| 类型 | 值 | 含义 |
|------|---|------|
| `EM_NONE` | 0 | 无机器类型 |
| `EM_386` | 3 | Intel 80386 |
| `EM_ARM` | 40 | ARM |
| `EM_X86_64` | 62 | AMD x86-64 |
| `EM_RISCV` | 243 | RISC-V |

## 参考

- 头文件: `/usr/include/elf.h`
- ELF 规范: [System V ABI](https://refspecs.linuxfoundation.org/elf/elf.pdf)

## 链接

# 链接

```
┌─────────────────────────────────────────────────────────────┐
│  编译阶段：gcc -c foo.c -o foo.o                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  foo.o (目标文件)                                            │
│  ├── ELF Header                                             │
│  ├── Section Header Table                                   │
│  │   ├── .text  (flags: SHF_ALLOC | SHF_EXECINSTR)         │
│  │   ├── .data  (flags: SHF_ALLOC | SHF_WRITE)             │
│  │   ├── .rodata (flags: SHF_ALLOC)                        │
│  │   └── .bss   (flags: SHF_ALLOC | SHF_WRITE)             │
│  └── (无 Program Header Table)                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
                      链接器 (ld) + linker.ld
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  链接阶段：ld -T linker.ld foo.o -o program                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  program (可执行文件)                                         │
│  ├── ELF Header                                             │
│  ├── Program Header Table  ← 链接器根据 PHDRS 创建            │
│  │   ├── LOAD (text): R+X                                   │
│  │   └── LOAD (data): R+W                                   │
│  ├── Section Header Table                                   │
│  │   ├── .text                                              │
│  │   ├── .rodata                                            │
│  │   ├── .data                                              │
│  │   └── .bss                                               │
│  └── 实际数据...                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```
