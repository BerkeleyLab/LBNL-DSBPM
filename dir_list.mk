TOP := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

GATEWARE_DIR       = $(TOP)gateware
SOFTWARE_DIR       = $(TOP)software

# Gateware

SUBMODULES_DIR     = $(GATEWARE_DIR)/submodules
MODULES_DIR        = $(GATEWARE_DIR)/modules
PLATFORM_DIR       = $(GATEWARE_DIR)/platform
GW_SCRIPTS_DIR     = $(GATEWARE_DIR)/scripts

BEDROCK_DIR        = $(SUBMODULES_DIR)/bedrock
EVR_DIR            = $(MODULES_DIR)/evr
PLATFORM_ZU48_DIR  = $(PLATFORM_DIR)/xilinx/zu48
PLATFORM_ZU48_DSBPM_DIR  = $(PLATFORM_ZU48_DIR)/dsbpm

GW_SYN_DIR         = $(GATEWARE_DIR)/syn

# Sofware

SW_LIBS_DIR        = $(SOFTWARE_DIR)/libs
SW_TGT_DIR         = $(SOFTWARE_DIR)/target
SW_SCRIPTS_DIR     = $(SOFTWARE_DIR)/scripts
SW_SRC_DIR     	   = $(SOFTWARE_DIR)/src
SW_APP_DIR         = $(SOFTWARE_DIR)/app

# DSBPM Sofware

SW_DSBPM_DIR         = $(SW_APP_DIR)/dsbpm
SW_DSBPM_SCRIPTS_DIR = $(SW_DSBPM_DIR)/scripts

include $(BEDROCK_DIR)/dir_list.mk
