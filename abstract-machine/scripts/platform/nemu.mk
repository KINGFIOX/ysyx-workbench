# NEMU 平台 Makefile

CFLAGS += -DPLATFORM_NEMU

# NEMU 源文件
AM_SRCS += platform/sim/trm.c \
           platform/sim/ioe/ioe.c

# NEMU 使用 sim/ 下的完整实现
AM_SRCS += platform/sim/ioe/timer.c \
           platform/sim/ioe/input.c \
           platform/sim/ioe/gpu.c \
           platform/sim/ioe/audio.c \
           platform/sim/ioe/disk.c

CFLAGS    += -fdata-sections -ffunction-sections
CFLAGS    += -I$(AM_HOME)/am/src/platform/sim/include
LDSCRIPTS += $(AM_HOME)/scripts/nemu-linker.ld
LDFLAGS   += --defsym=_pmem_start=0x80000000 --defsym=_entry_offset=0x0
LDFLAGS   += --gc-sections -e _start

MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = the_insert-arg_rule_in_Makefile_will_insert_mainargs_here
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=$(MAINARGS_PLACEHOLDER)

insert-arg: image
	@python3 $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) $(MAINARGS_PLACEHOLDER) "$(mainargs)"

image: image-dep
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) -S --set-section-flags .bss=alloc,contents -O binary $(IMAGE).elf $(IMAGE).bin

.PHONY: insert-arg

# run NEMU in batch mode by default for automated tests
NEMUFLAGS += -b -l $(shell dirname $(IMAGE).elf)/nemu-log.txt

run: insert-arg
	$(MAKE) -C $(NEMU_HOME) ISA=$(ISA) run ARGS="$(NEMUFLAGS)" IMG=$(IMAGE).bin

gdb: insert-arg
	$(MAKE) -C $(NEMU_HOME) ISA=$(ISA) gdb ARGS="$(NEMUFLAGS)" IMG=$(IMAGE).bin
