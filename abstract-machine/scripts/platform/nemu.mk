# NEMU 平台 Makefile

include $(AM_HOME)/scripts/platform/sim.mk

CFLAGS += -DPLATFORM_NEMU

# NEMU 使用 sim/ 下的完整实现
AM_SRCS += platform/sim/ioe/timer.c \
           platform/sim/ioe/input.c \
           platform/sim/ioe/gpu.c \
           platform/sim/ioe/audio.c \
           platform/sim/ioe/disk.c

# run NEMU in batch mode by default for automated tests
NEMUFLAGS += -b -l $(shell dirname $(IMAGE).elf)/nemu-log.txt

run: insert-arg
	$(MAKE) -C $(NEMU_HOME) ISA=$(ISA) run ARGS="$(NEMUFLAGS)" IMG=$(IMAGE).bin

gdb: insert-arg
	$(MAKE) -C $(NEMU_HOME) ISA=$(ISA) gdb ARGS="$(NEMUFLAGS)" IMG=$(IMAGE).bin
