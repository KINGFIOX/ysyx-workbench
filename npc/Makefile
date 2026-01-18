BUILD_DIR = ./build
NPC_HOME := $(abspath .)

MILL := mill

PRJ = playground

VERILATOR ?= verilator
VERILATOR_TOP ?= NPCSoC
VERILATOR_SV  := $(BUILD_DIR)/$(VERILATOR_TOP).sv
VERILATOR_FILELIST := $(BUILD_DIR)/filelist.f
VERILATOR_MDIR := $(BUILD_DIR)/obj-verilator
VERILATOR_MK  := $(VERILATOR_MDIR)/V$(VERILATOR_TOP).mk
VERILATOR_LIB := $(VERILATOR_MDIR)/V$(VERILATOR_TOP)__ALL.a

# =============================== 构建 NPC 可执行文件 ===============================
# 完整构建: Chisel -> Verilog -> Verilator -> C++ 链接
build-npc: verilate
	$(MAKE) -f scripts/native.mk NPC_HOME=$(NPC_HOME)

# =============================== Chisel -> Verilog ===============================
test:
	$(MILL) -i $(PRJ).test

verilog: $(VERILATOR_SV)

# 搜集所有 Chisel 源文件作为依赖，实现增量编译
CHISEL_SRCS := $(shell find $(PRJ)/src -name "*.scala" 2>/dev/null)
CHISEL_RESOURCES := $(shell find $(PRJ)/resources -name "*.sv" 2>/dev/null)

# 当任何 .scala 文件或 .sv 资源文件修改时，重新生成 Verilog
$(VERILATOR_SV): $(CHISEL_SRCS) $(CHISEL_RESOURCES)
	$(call git_commit, "generate verilog")
	mkdir -p $(BUILD_DIR)
	$(MILL) -i $(PRJ).runMain npc.NPCSoC --target-dir $(BUILD_DIR)

# =============================== Verilog -> Verilator C++ ===============================

verilate: $(VERILATOR_LIB)

# 收集所有生成的 SV 文件作为依赖
GENERATED_SVS := $(wildcard $(BUILD_DIR)/*.sv)

# Verilator Makefile 依赖于所有生成的 SV 文件
$(VERILATOR_MK): $(VERILATOR_SV) $(VERILATOR_FILELIST) $(GENERATED_SVS)
	@echo "=== Verilating $(VERILATOR_TOP) ==="
	cd $(BUILD_DIR) && $(VERILATOR) --cc \
		-f filelist.f \
		-y verification \
		--Mdir obj-verilator \
		--top-module $(VERILATOR_TOP) \
		--trace \
		-O2 -Wall -Wno-fatal \
		-CFLAGS "-std=c++17 -O2"

# Verilator 生成的库依赖于 Verilator Makefile
$(VERILATOR_LIB): $(VERILATOR_MK)
	@echo "=== Building Verilator library ==="
	$(MAKE) -C $(VERILATOR_MDIR) -f V$(VERILATOR_TOP).mk


# =============================== commands ===============================

help:
	$(MILL) -i $(PRJ).runMain Elaborate --help

reformat:
	$(MILL) -i __.reformat

checkformat:
	$(MILL) -i __.checkFormat

bsp:
	$(MILL) -i mill.bsp.BSP/install

idea:
	$(MILL) -i mill.idea.GenIdea/idea

clean:
	-rm -rf $(BUILD_DIR)

.PHONY: test verilog verilate help reformat checkformat clean build-npc menuconfig run gdb

menuconfig:
	$(MAKE) -f scripts/native.mk NPC_HOME=$(NPC_HOME) menuconfig

run:
	$(MAKE) -f scripts/native.mk NPC_HOME=$(NPC_HOME) run IMG=$(IMG)

gdb:
	$(MAKE) -f scripts/native.mk NPC_HOME=$(NPC_HOME) gdb IMG=$(IMG)

sim:
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	@gtkwave $(BUILD_DIR)/npc_core.vcd

-include ../Makefile
