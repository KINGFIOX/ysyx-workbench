# mainargs 传递机制

## 问题一：mainargs 是怎么生成并传递给 AM 的 main 函数的？

这是一个**二进制补丁**技术，整个流程分为三步：

### 1. 编译时：创建占位符

在 `scripts/platform/sim.mk` 中定义了：

```makefile
MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = the_insert-arg_rule_in_Makefile_will_insert_mainargs_here
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=$(MAINARGS_PLACEHOLDER)
```

然后在 `am/src/platform/sim/trm.c` 中：

```c
static const char mainargs[MAINARGS_MAX_LEN] = TOSTRING(MAINARGS_PLACEHOLDER);
```

这里 `mainargs` 被初始化为一个 64 字节的字符数组，内容是那个很长的占位符字符串。

### 2. 链接后：二进制补丁替换

在生成 `.bin` 文件后，`insert-arg` 目标会执行：

```makefile
insert-arg: image
	@python3 $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) $(MAINARGS_PLACEHOLDER) "$(mainargs)"
```

`tools/insert-arg.py` 脚本的核心逻辑：

```python
fp = open(bin, 'r+b')
data = fp.read()
idx = data.find(str.encode(placeholder))  # 在二进制中搜索占位符
fp.seek(idx)
mainargs_pad = str.encode(mainargs) + ((max_len - len(mainargs)) * str.encode("\0"))  # 补 \0
fp.write(mainargs_pad)  # 原地替换
```

它直接在二进制文件中**搜索占位符字符串**，然后用你传入的 `mainargs='xxx'` **原地替换**。

### 3. 运行时：传递给 main

```c
void _trm_init() {
  int ret = main(mainargs);
  halt(ret);
}
```

`_trm_init()` 是 AM 的入口函数，它调用 `main(mainargs)`，把这个字符串作为参数传给应用程序。

### 为什么这样设计？

因为**裸机程序没有操作系统**，不存在 shell 来传递 `argc/argv`。这个设计通过：
1. 编译时预留空间（占位符）
2. 链接后直接修改二进制
3. 运行时读取被修改的数据

实现了一种"伪命令行参数"的效果。

---

## 问题二：为什么不会保留之前的 mainargs 状态？

### 现象

```bash
# 第一次运行
make run mainargs='riscv32-npc'
# 输出：mainargs = 'riscv32-npc'.

# 第二次运行（不指定 mainargs）
make run
# 输出：mainargs = ''.
```

既然 `insert-arg.py` 已经把 `riscv32-npc` 写入了二进制文件，为什么第二次运行时 mainargs 变成了空？

### 原因

关键在于 Makefile 的依赖链：

```makefile
# nemu.mk / npc.mk
run: insert-arg
	$(MAKE) -C $(NEMU_HOME) ISA=$(ISA) run ...

# sim.mk
insert-arg: image
	@python3 $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin ... "$(mainargs)"

image: image-dep
	@$(OBJCOPY) -S --set-section-flags .bss=alloc,contents -O binary $(IMAGE).elf $(IMAGE).bin
```

每次 `make run` 时的完整流程：

1. **`run` 依赖 `insert-arg`**
2. **`insert-arg` 依赖 `image`**
3. **`image` 每次都从 `.elf` 重新生成 `.bin`**

所以：

| 运行                              | OBJCOPY                                       | insert-arg                  |
| --------------------------------- | --------------------------------------------- | --------------------------- |
| `make run mainargs='riscv32-npc'` | 从 `.elf` 生成新 `.bin`（包含占位符）         | 用 `riscv32-npc` 替换占位符 |
| `make run`                        | 从 `.elf` **又重新生成** `.bin`（包含占位符） | 用**空字符串**替换占位符    |

### 关键点

- `.bin` 文件是一个**临时产物**，每次都从 `.elf` 重新生成
- 之前写入的 `riscv32-npc` 已经被新的 `OBJCOPY` 覆盖掉了
- `.elf` 里面永远是那个占位符字符串
- 每次 `OBJCOPY` 后，`.bin` 又恢复成占位符状态，然后再用当前的 `$(mainargs)` 替换
