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

# 从 NPC Meson 配置读取地址 (优先 meson introspect，否则 meson_options.txt 默认值)
NPC_SOC_CONFIG_MK := $(AM_HOME)/.npc-soc-config.mk
$(shell NPC_HOME=$(NPC_HOME) python3 $(AM_HOME)/tools/get-npc-soc-config.py > $(NPC_SOC_CONFIG_MK) 2>/dev/null)
-include $(NPC_SOC_CONFIG_MK)

# 将地址配置传递给 C 程序
CFLAGS += -DMROM_BASE=$(MROM_BASE) -DMROM_SIZE=$(MROM_SIZE) # mrom
CFLAGS += -DSRAM_BASE=$(SRAM_BASE) -DSRAM_SIZE=$(SRAM_SIZE) # sram
CFLAGS += -DFLASH_BASE=$(FLASH_BASE) -DFLASH_SIZE=$(FLASH_SIZE) # flash
CFLAGS += -DPSRAM_BASE=$(PSRAM_BASE) -DPSRAM_SIZE=$(PSRAM_SIZE) # psram
CFLAGS += -DSDRAM_BASE=$(SDRAM_BASE) -DSDRAM_SIZE=$(SDRAM_SIZE) # sdram

LDSCRIPTS += $(AM_HOME)/scripts/npc-linker.ld
LDFLAGS   += --defsym=_mrom_base=$(MROM_BASE) --defsym=_mrom_size=$(MROM_SIZE) # mrom
LDFLAGS   += --defsym=_sram_base=$(SRAM_BASE) --defsym=_sram_size=$(SRAM_SIZE) # sram
LDFLAGS   += --defsym=_flash_base=$(FLASH_BASE) --defsym=_flash_size=$(FLASH_SIZE) # flash
LDFLAGS   += --defsym=_psram_base=$(PSRAM_BASE) --defsym=_psram_size=$(PSRAM_SIZE) # psram
LDFLAGS   += --defsym=_sdram_base=$(SDRAM_BASE) --defsym=_sdram_size=$(SDRAM_SIZE) # sdram
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
NPCFLAGS += -b -l $(shell dirname $(IMAGE).elf)/npc-log.txt
ifdef NVBOARD
NPCFLAGS += --nvboard
endif
ifdef WAVE
NPCFLAGS += --wave
endif


run: insert-arg
	$(MAKE) -C $(NPC_HOME) GUEST_ISA=$(ISA) run ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin

gdb: insert-arg
	$(MAKE) -C $(NPC_HOME) GUEST_ISA=$(ISA) gdb ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin
