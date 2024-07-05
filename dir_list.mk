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

GW_TOP_DIR         = $(GATEWARE_DIR)/top
GW_TOP_COMMON_DIR  = $(GW_TOP_DIR)/common_dsbpm_zcu208
GW_SYN_DIR         = $(GATEWARE_DIR)/syn

# Sofware

SW_LIBS_DIR        = $(SOFTWARE_DIR)/libs
SW_TGT_DIR         = $(SOFTWARE_DIR)/target
SW_SCRIPTS_DIR     = $(SOFTWARE_DIR)/scripts
SW_SRC_DIR     	   = $(SOFTWARE_DIR)/src
SW_APP_DIR         = $(SOFTWARE_DIR)/app

# DSBPM Sofware

SW_DSBPM_VCXO_160_DIR = $(SW_APP_DIR)/dsbpm_vcxo_160
SW_DSBPM_VCXO_160_SCRIPTS_DIR = $(SW_DSBPM_VCXO_160_DIR)/scripts

SW_DSBPM_VCXO_117_DIR = $(SW_APP_DIR)/dsbpm_vcxo_117
SW_DSBPM_VCXO_117_SCRIPTS_DIR = $(SW_DSBPM_VCXO_117_DIR)/scripts

include $(BEDROCK_DIR)/dir_list.mk
