#***************************************************************************************
# Copyright (c) 2014-2024 Zihao Yu, Nanjing University
#
# NEMU is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#**************************************************************************************/

COLOR_RED := $(shell echo "\033[1;31m")
COLOR_END := $(shell echo "\033[0m")

ifeq ($(wildcard .config),)
$(warning $(COLOR_RED)Warning: .config does not exist!$(COLOR_END))
$(warning $(COLOR_RED)To build the project, first run 'make menuconfig'.$(COLOR_END))
endif

Q            := @
Kconfig      := $(NEMU_HOME)/Kconfig
rm-distclean += include/generated include/config .config .config.old
silent := -s

# 使用系统安装的 kconfig 和 fixdep 工具
CONF   := kconfig-conf
MCONF  := kconfig-mconf
FIXDEP := fixdep

menuconfig:
	$(Q)mkdir -p include/config include/generated
	$(Q)$(MCONF) $(Kconfig)
	$(Q)$(CONF) $(silent) --silentoldconfig $(Kconfig)

.PHONY: menuconfig

# Help text used by make help
help:
	@echo  '  menuconfig	  - Update current config utilising a menu based program'

distclean: clean
	-@rm -rf $(rm-distclean)

.PHONY: help distclean

define call_fixdep
	@$(FIXDEP) $(1) $(2) unused > $(1).tmp
	@mv $(1).tmp $(1)
endef
