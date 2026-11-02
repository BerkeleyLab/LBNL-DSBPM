HARDWARE ?= zcu208
PROJECT_PART ?= xczu48dr-fsvg1517-2-e
PROJECT_BOARD ?= xilinx.com:zcu208:part0:2.0
COMMUNICATION = gty
XILINX_TOOL := VIVADO
FPGA_VENDOR := xilinx
FPGA_PLATFORM ?= zu48
FPGA_APPLICATION ?= dsbpm
BD_SYSTEM_NAME ?= system

CMD_SEP = ;
__THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
THIS_DIR := $(__THIS_DIR:/=)

include ../../../dir_list.mk

# Top level design name
TARGET ?= $(FPGA_APPLICATION)_$(HARDWARE)

VENDOR_PLATFORM_DIR = $(PLATFORM_DIR)/$(FPGA_VENDOR)
FPGA_FAMILY_PLATFORM_DIR = $(VENDOR_PLATFORM_DIR)/$(FPGA_PLATFORM)
TARGET_PLATFORM_DIR = $(FPGA_FAMILY_PLATFORM_DIR)/$(FPGA_APPLICATION)

GW_CCTRL_TGT_DIR = $(GW_SYN_DIR)/$(TARGET)
XPR              = $(GW_CCTRL_TGT_DIR)/_xilinx/$(TARGET)_top/$(TARGET)_top.xpr

# Top level bitstream name
all: $(TARGET)_top.bit

# Search for .v files here
vpath %.v $(DSP_DIR)
vpath %.v $(CORDIC_DIR)
vpath %.v $(MODULES_DIR)
vpath %.v $(VENDOR_PLATFORM_DIR)
vpath %.v $(FPGA_FAMILY_PLATFORM_DIR)
vpath %.v $(GW_TOP_COMMON_DIR)

# Search for .sv files here
vpath %.sv $(DSP_DIR)
vpath %.sv $(CORDIC_DIR)
vpath %.sv $(MODULES_DIR)
vpath %.sv $(GW_TOP_COMMON_DIR)

TOP_LVL_DIR = ../../top/$(TARGET)

# top-level files go here
vpath %.v $(TOP_LVL_DIR)
vpath %.sv $(TOP_LVL_DIR)
vpath %.xdc $(TOP_LVL_DIR)

#.tcl.in and .tcl files can be here too
vpath %.tcl.in $(THIS_DIR)
vpath %.txt.in $(THIS_DIR)
vpath %.tcl $(THIS_DIR)

VIVADO_SYNTH_EXTRA_TCL = prop.tcl ipcores_repos.tcl prio_xci_files.tcl

include $(BUILD_DIR)/top_rules.mk
include $(CORDIC_DIR)/rules.mk
include $(CELL_COMM_DIR)/top_rules.mk

# Used by platform rules
dsbpm_BD_CORE    = $(BD_SYSTEM_NAME)
include $(PLATFORM_DIR)/top_rules.mk

# ignore xilinx primitives
UNISIM_CRAP += -e 'GTYE4_CHANNEL|MMCME4_ADV'

# Enable support for system verilog
VERILOG += -g2012

# Top level files for depedency tracking
SYSTEM_TOP_PINS_XDC = $(TARGET)_top_pins.xdc
SYSTEM_TOP_TIM_XDC = $(TARGET)_top_tim.xdc $(TARGET)_top_aurora_tim.xdc

# ip_cores generation scripts/names
include $(MODULES_DIR)/bpm_comm_rules.mk

# custom ip_cores that requires packaging
include $(MODULES_DIR)/evr_axi_rules.mk
include $(MODULES_DIR)/axi_lite_generic_reg_rules.mk

# block diagram selection

ifeq ($(BD_SYSTEM_NAME),system)
	SYSTEM_TOP_PINS_XDC += $(TARGET)_top_ddr_pins.xdc
	SYSTEM_TOP_TIM_XDC += $(TARGET)_top_ddr_tim.xdc
else ifeq ($(BD_SYSTEM_NAME),system_without_ddr)
	SYSTEM_TOP_PINS_XDC += $(TARGET)_top_ddr_pins.xdc
else
$(error BD_SYSTEM_NAME = $(BD_SYSTEM_NAME) unsupported)
endif

# For iverilog to search for dependencies

# Bedrock directories for searching
VFLAGS_DEP += -y$(DSP_DIR)
VFLAGS_DEP += -y$(CORDIC_DIR)
VFLAGS_DEP += -y$(FPGA_FAMILY_DIR)
VFLAGS_DEP += -y$(FPGA_FAMILY_DIR)/xilinx
VFLAGS_DEP += -y$(FPGA_FAMILY_DIR)/iserdes
VFLAGS_DEP += -y$(ISERDES_DIR)
VFLAGS_DEP += -y$(XILINX_DIR)
VFLAGS_DEP += -y$(SERIAL_IO_DIR)
VFLAGS_DEP += -y$(PERIPH_DRIVERS_DIR)
VFLAGS_DEP += -y$(HOMELESS_DIR)

# Local directories for searching
VFLAGS_DEP += -y.
VFLAGS_DEP += -y$(MODULES_DIR)
VFLAGS_DEP += -y$(TOP_LVL_DIR)
VFLAGS_DEP += -y$(GW_TOP_COMMON_DIR)
VFLAGS_DEP += -y$(VENDOR_PLATFORM_DIR)
VFLAGS_DEP += -y$(FPGA_FAMILY_PLATFORM_DIR)
VFLAGS_DEP += -y$(BWUDP_DIR)

# Local directories for include searching
VFLAGS_DEP += -I.
VFLAGS_DEP += -I$(MODULES_DIR)
VFLAGS_DEP += -I$(TOP_LVL_DIR)
VFLAGS_DEP += -I$(GW_TOP_COMMON_DIR)
VFLAGS_DEP += -I$(BWUDP_DIR)

VFLAGS_DEP += $(SYNTH_OPT)
VFLAGS_DEP += -DSIMULATE -g2012 -Y .sv

# Search prerequisites for generated .v/.vh/.vhd/.xdc here
vpath %.tcl $(GW_SCRIPTS_DIR)
vpath %.sh $(GW_SCRIPTS_DIR)

# List top level depedencies here. Eveything named .bit will be used as
# a top-level target in top_rules.mk. .v and .sv files will be used as
# prerequisites as well as a system_top.xdc file
$(TARGET)_top.bit: system_top.xdc $(VIVADO_SYNTH_EXTRA_TCL) $(IP_CORES_TCLS) $(IP_CORES_XCIS) $(TOP_LVL_DIR)/$(TARGET)_top.v $(BD_CORE_BDS)
$(TOP_LVL_DIR)/$(TARGET)_top.v: $(TOP_LVL_DIR)/gitHash.vh $(TOP_LVL_DIR)/firmwareBuildDate.v $(TOP_LVL_DIR)/gpioIDX.v $(IP_CORES_CUSTOM) cordicg_b22.v

$(EXTRA_VFLAGS_DEP): % : %.in
	sed -e 's|$$BEDROCK_DIR|$(BEDROCK_DIR:/=)|g' \
		$< > $@

# Generate bundled .xdc from other .xdc. Don't change the order of the
# prerequisites as we need constraints in the order specified
system_top.xdc: $(SYSTEM_TOP_PINS_XDC) $(SYSTEM_TOP_TIM_XDC)
	cat $^ > $@

# Generate firmware date and parameters
%firmwareBuildDate.v: set_firmware_build_date.tcl
	$(VIVADO_CMD) -source $< -tclargs $@

%gitHash.vh: gitHashVerilog.sh
	sh $(GW_SCRIPTS_DIR)/gitHashVerilog.sh > $@

%gpioIDX.v: $(SW_TGT_COMMON_DIR)/gpio.h
	sh $(GW_SCRIPTS_DIR)/createVerilogIDX.sh $^ > $@

ipcores_repos.tcl: ipcores_repos.tcl.in
	sed -e 's|$$DIRS|$(IP_CORES_CUSTOM_TARGET_DIRS)|g' \
		$< > $@

prio_xci_files.tcl: prio_xci_files.tcl.in
	sed -e 's|$$XCI_FILES|ila_td256_s4096_cap.xci|g' \
		$< > $@

# Cleaning rules
include $(CELL_COMM_DIR)/bottom_rules.mk
include $(PLATFORM_DIR)/bottom_rules.mk
include $(BUILD_DIR)/bottom_rules.mk

CLEAN += *.bit
CLEAN += system_top.xdc
CLEAN += $(TOP_LVL_DIR)/firmwareBuildDate.v
CLEAN += $(TOP_LVL_DIR)/gpioIDX.v
CLEAN += $(TOP_LVL_DIR)/gitHash.vh
CLEAN += cordicg_b22.v
CLEAN += $(IP_CORES_CUSTOM)
CLEAN += *.log *.jou *.str
CLEAN += *.xsa
CLEAN += psu_init*
CLEAN += ipcores_repos.tcl
CLEAN += prio_xci_files.tcl
CLEAN_DIRS +=  _xilinx .Xil .ip_user_files .hbs $(IP_CORES_CUSTOM_TARGET_DIRS)
CLEAN_DIRS += _gen

# Dependency rules for top level. It will include the dependencies for
# the bitstream %.bit and use the stem to list the depedencies for the
# top level named %.v or %.sv
ifneq (,$(findstring bit,$(MAKECMDGOALS)))
    ifneq (,$(findstring bits,$(MAKECMDGOALS)))
	include $(BITS_:%.bit=$(DEPDIR)/%.bit.d)
    else
	include $(MAKECMDGOALS:%.bit=$(DEPDIR)/%.bit.d)
    endif
endif
