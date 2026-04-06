# NEMU platform Makefile (spike + nvboard)
# Compatible with NEMU MMIO protocol

CFLAGS += -DPLATFORM_NEMU

AM_SRCS += platform/sim/ioe/ioe.c

AM_SRCS += platform/npc/ioe/timer.c \
           platform/npc/ioe/input.c \
           platform/npc/ioe/gpu.c \
           platform/npc/ioe/audio.c \
           platform/npc/ioe/disk.c \
		   platform/npc/ioe/trm.c

CFLAGS    += -fdata-sections -ffunction-sections
CFLAGS    += -I$(AM_HOME)/am/src/platform/npc/include

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

NEMUFLAGS += --batch --log=$(shell dirname $(IMAGE).elf)/nemu-log.txt
ifdef NVBOARD
NEMUFLAGS += --nvboard
endif

run: insert-arg
	$(NEMU_HOME)/build/nemu $(NEMUFLAGS) --image $(IMAGE).bin

gdb: insert-arg
	$(NEMU_HOME)/build/nemu $(NEMUFLAGS) --image $(IMAGE).bin
