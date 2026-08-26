dsbpm_zu47_platform_DIR = $(PLATFORM_DIR)/xilinx/zu47

dsbpm_zu47_platform_app_DIR = $(dsbpm_zu47_platform_DIR)/$(FPGA_APPLICATION)

include $(dsbpm_zu47_platform_app_DIR)/bottom_rules.mk
