# NPC 平台 Makefile
# NPC 使用独立的链接脚本，.text 在 mrom，.data 在 sram

CFLAGS += -DPLATFORM_NPC

# NPC 独立的源文件
AM_SRCS += platform/sim/ioe/ioe.c

# NPC 使用 npc/ 下的特定实现:
# 1. 有校准因子的 timer
# 2. stub 版的 gpu/input
# 3. 使用 uart 实现的 trm.c
AM_SRCS += platform/npc/ioe/timer.c \
           platform/npc/ioe/input.c \
           platform/npc/ioe/gpu.c \
           platform/npc/ioe/audio.c \
           platform/npc/ioe/disk.c \
		   platform/npc/ioe/trm.c

CFLAGS    += -fdata-sections -ffunction-sections
CFLAGS    += -I$(AM_HOME)/am/src/platform/npc/include

# 从 NPC 配置文件读取地址配置
NPC_CONFIG := $(NPC_HOME)/.config
MROM_BASE := $(shell grep '^CONFIG_SOC_MROM_BASE=' $(NPC_CONFIG) | cut -d= -f2)
MROM_SIZE := $(shell grep '^CONFIG_SOC_MROM_SIZE=' $(NPC_CONFIG) | cut -d= -f2)
SRAM_BASE := $(shell grep '^CONFIG_SOC_SRAM_BASE=' $(NPC_CONFIG) | cut -d= -f2)
SRAM_SIZE := $(shell grep '^CONFIG_SOC_SRAM_SIZE=' $(NPC_CONFIG) | cut -d= -f2)
FLASH_BASE := $(shell grep '^CONFIG_SOC_XIP_FLASH_BASE=' $(NPC_CONFIG) | cut -d= -f2)
FLASH_SIZE := $(shell grep '^CONFIG_SOC_XIP_FLASH_SIZE=' $(NPC_CONFIG) | cut -d= -f2)
PSRAM_BASE := $(shell grep '^CONFIG_SOC_PSRAM_BASE=' $(NPC_CONFIG) | cut -d= -f2)
PSRAM_SIZE := $(shell grep '^CONFIG_SOC_PSRAM_SIZE=' $(NPC_CONFIG) | cut -d= -f2)

# 将地址配置传递给 C 程序
CFLAGS += -DFLASH_BASE=$(FLASH_BASE) -DFLASH_SIZE=$(FLASH_SIZE)
CFLAGS += -DPSRAM_BASE=$(PSRAM_BASE) -DPSRAM_SIZE=$(PSRAM_SIZE)

# 使用 NPC 专用链接脚本
LDSCRIPTS += $(AM_HOME)/scripts/npc-linker.ld
LDFLAGS   += --defsym=_flash_base=$(FLASH_BASE) --defsym=_flash_size=$(FLASH_SIZE)
LDFLAGS   += --defsym=_psram_base=$(PSRAM_BASE) --defsym=_psram_size=$(PSRAM_SIZE)
LDFLAGS   += --gc-sections -e _start
LDFLAGS   += --orphan-handling=warn

MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = the_insert-arg_rule_in_Makefile_will_insert_mainargs_here
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=$(MAINARGS_PLACEHOLDER)

insert-arg: image
	@python3 $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) $(MAINARGS_PLACEHOLDER) "$(mainargs)"

image: image-dep
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) -S -O binary $(IMAGE).elf $(IMAGE).bin

.PHONY: insert-arg

# TODO: run NPC in batch mode by default for automated tests
NPCFLAGS += -l $(shell dirname $(IMAGE).elf)/npc-log.txt

run: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) run ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin

gdb: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) gdb ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin
