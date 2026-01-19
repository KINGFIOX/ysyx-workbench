include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/nemu.mk
CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS := -fno-pic -march=rv32im_zicsr -mabi=ilp32 -mstrict-align  # overwrite: 添加 Zicsr 扩展

# 使用共享的 riscv/sim/ 目录
AM_SRCS += riscv/sim/start.S \
           riscv/sim/cte.c \
           riscv/sim/trap.S \
           riscv/sim/vme.c
