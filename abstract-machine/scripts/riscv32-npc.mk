include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/npc.mk
CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS := -fno-pic -march=rv32i_zicsr -mabi=ilp32 -mstrict-align  # overwrite: NPC 不支持 M 扩展

# NPC 使用专用的 start.S（包含 .data 复制和 .bss 清零）
# 其他使用共享的 riscv/sim/ 目录，vme.c 使用 dummy stub
# libgcc 已移至 klib，通过 klib/Makefile 条件编译
AM_SRCS += platform/npc/start.S \
           riscv/sim/cte.c \
           riscv/sim/trap.S \
           platform/dummy/vme.c
