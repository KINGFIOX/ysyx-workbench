include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/nemu.mk
CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS := -fno-pic -march=rv64im_zicsr -mabi=lp64 -mcmodel=medany -mstrict-align

# Reuse shared riscv/sim/ directory (same as NEMU)
AM_SRCS += riscv/sim/start.S \
           riscv/sim/cte.c \
           riscv/sim/trap.S \
           riscv/sim/vme.c
