include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/npc.mk
CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS := -fno-pic -march=rv64i_zicsr -mabi=lp64 -mcmodel=medany -mstrict-align  # overwrite: NPC 不支持 M 扩展

# NPC 使用两级 bootloader: start.S -> fsbl -> ssbl -> _trm_init
# 其他使用共享的 riscv/sim/ 目录，vme.c 使用 dummy stub
# libgcc 已移至 klib，通过 klib/Makefile 条件编译
AM_SRCS += platform/npc/start.S \
           platform/npc/fsbl.c \
           platform/npc/ssbl.c \
           riscv/sim/cte.c \
           riscv/sim/trap.S \
           platform/dummy/vme.c
