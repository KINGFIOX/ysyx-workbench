include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/nemu.mk
CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS := -fno-pic -march=rv64im_zicsr -mabi=lp64 -mcmodel=medany -mstrict-align

# Use NPC boot flow: start.S -> fsbl -> ssbl -> _trm_init
AM_SRCS += platform/npc/start.S \
           platform/npc/fsbl.c \
           platform/npc/ssbl.c \
           riscv/sim/cte.c \
           riscv/sim/trap.S \
           riscv/sim/vme.c
