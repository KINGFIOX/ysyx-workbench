include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/npc.mk
CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS := -fno-pic -march=rv32i_zicsr -mabi=ilp32 -mstrict-align  # overwrite: NPC 不支持 M 扩展

# 使用共享的 riscv/sim/ 目录，但 vme.c 使用 dummy stub
AM_SRCS += riscv/sim/start.S \
           riscv/sim/cte.c \
           riscv/sim/trap.S \
           platform/dummy/vme.c \
           riscv/npc/libgcc/div.S \
           riscv/npc/libgcc/muldi3.S \
           riscv/npc/libgcc/multi3.c \
           riscv/npc/libgcc/ashldi3.c \
           riscv/npc/libgcc/unused.c
