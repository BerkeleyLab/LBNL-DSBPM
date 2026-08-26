dsbpm_zu48_platform_DIR = $(PLATFORM_DIR)/xilinx/zu48

dsbpm_zu48_platform_app_DIR = $(dsbpm_zu48_platform_DIR)/$(FPGA_APPLICATION)

include $(dsbpm_zu48_platform_app_DIR)/top_rules.mk
