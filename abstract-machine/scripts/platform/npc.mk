# NPC 平台 Makefile

include $(AM_HOME)/scripts/platform/sim.mk

CFLAGS += -DPLATFORM_NPC

# NPC 使用 npc/ 下的特定实现（有校准因子的 timer，stub 版的 gpu/input）
AM_SRCS += platform/npc/ioe/timer.c \
           platform/npc/ioe/input.c \
           platform/npc/ioe/gpu.c \
           platform/npc/ioe/audio.c \
           platform/npc/ioe/disk.c

# run NPC in batch mode by default for automated tests
NPCFLAGS += -b -l $(shell dirname $(IMAGE).elf)/npc-log.txt

run: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) run ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin
