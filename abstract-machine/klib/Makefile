NAME = klib
SRCS = $(shell find src/ -name "*.c")

# 提取 PLATFORM（在 include 之前需要手动解析 ARCH）
KLIB_PLATFORM = $(word 2,$(subst -, ,$(ARCH)))

# NPC 平台需要 libgcc（软件乘除法）
ifeq ($(KLIB_PLATFORM),npc)
SRCS += $(shell find src/libgcc/ -name "*.S")
endif

include $(AM_HOME)/Makefile
