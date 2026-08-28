dsbpm_IP_CORES = \
	adcCordic \
	cellCommFIFO \
	evrGTY \
	rmsBandSelect \
	adcToSysFIFO \
	cellCommMux \
	ila_td256_s4096_cap \
	positionCalcDivider \
	cellCommSendFIFO \
	positionCalcMultiplier

dsbpm_IP_CORES_DIRS = $(addprefix $(dsbpm_zu48_platform_app_DIR)/, $(dsbpm_IP_CORES))

# For top-level makefile
IP_CORES_TCLS += $(addsuffix .tcl, $(dsbpm_IP_CORES))
IP_CORES_DIRS += $(dsbpm_IP_CORES_DIRS)

dsbpm_BD_CORE ?= \
	system

dsbpm_BD_CORE_DIR = $(addprefix $(dsbpm_zu48_platform_app_DIR)/, $(dsbpm_BD_CORE))

# For top-level makefile
BD_CORE_BDS += $(addprefix $(dsbpm_BD_CORE_DIR)/, $(addsuffix .bd, $(dsbpm_BD_CORE)))
BD_CORE_DIRS += \
	$(dsbpm_BD_CORE_DIR) \
	$(addsuffix /synth, $(dsbpm_BD_CORE_DIR)) \
	$(addsuffix /hdl, $(dsbpm_BD_CORE_DIR))

vpath %.tcl $(IP_CORES_DIRS) $(BD_CORE_DIRS)
vpath %.bd $(BD_CORE_DIRS)

%.bd: %.tcl axi_lite_generic_reg evr_axi
	$(VIVADO_CMD) -source $(GW_SCRIPTS_DIR)/bd_tcl_proc.tcl $(GW_SCRIPTS_DIR)/gen_bd_tcl.tcl  -tclargs $< $(PROJECT_PART) $(PROJECT_BOARD) $(IP_CORES_CUSTOM_TARGET_DIRS)
