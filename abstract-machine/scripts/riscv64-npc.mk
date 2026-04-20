include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/npc.mk
CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS := -fno-pic -march=rv64im_zicsr_zifencei -mabi=lp64 -mcmodel=medany -mstrict-align

# NPC 使用两级 bootloader: start.S -> fsbl -> ssbl -> _trm_init
# libgcc 已移至 klib，通过 klib/Makefile 条件编译
AM_SRCS += platform/npc/start.S \
           platform/npc/fsbl.c \
           platform/npc/ssbl.c \
           platform/npc/cte.c \
           platform/npc/trap.S
