HARDWARE ?= zcu208
PROJECT_PART ?= xczu48dr-fsvg1517-2-e
PROJECT_BOARD ?= xilinx.com:zcu208:part0:2.0
COMMUNICATION = gty
XILINX_TOOL := VIVADO
FPGA_VENDOR := xilinx
FPGA_PLATFORM ?= zu48
FPGA_APPLICATION ?= dsbpm

CMD_SEP = ;
__THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
THIS_DIR := $(__THIS_DIR:/=)

include ../../../dir_list.mk

# Top level design name
TARGET ?= dsbpm_zcu208

PLATFORM_TARGET = $(PLATFORM_DIR)/$(FPGA_VENDOR)/$(FPGA_PLATFORM)/$(FPGA_APPLICATION)

# Top level bitstream name
all: $(TARGET)_top.bit

# Search for .v files here
vpath %.v $(DSP_DIR)
vpath %.v $(CORDIC_DIR)
vpath %.v $(MODULES_DIR)
vpath %.v $(GW_TOP_COMMON_DIR)

TOP_LVL_DIR = ../../top/$(TARGET)

# top-level files go here
vpath %.v $(TOP_LVL_DIR)
vpath %.xdc $(TOP_LVL_DIR)

#.tcl.in and .tcl files can be here too
vpath %.tcl.in $(THIS_DIR)
vpath %.txt.in $(THIS_DIR)
vpath %.tcl $(THIS_DIR)

VIVADO_SYNTH_EXTRA_TCL = prop.tcl ipcores_repos.tcl prio_xci_files.tcl

include $(BUILD_DIR)/top_rules.mk
include $(CORDIC_DIR)/rules.mk

# ignore xilinx primitives
UNISIM_CRAP += -e 'GTYE4_CHANNEL|MMCME4_ADV'

# Top level files for depedency tracking
SYSTEM_TOP_PINS_XDC = $(TARGET)_top_pins.xdc
SYSTEM_TOP_TIM_XDC = $(TARGET)_top_tim.xdc $(TARGET)_top_aurora_tim.xdc

# ip_cores generation scripts/names
include $(CELL_COMM_DIR)/top_rules.mk
include $(MODULES_DIR)/bpm_comm_rules.mk

# custom ip_cores that requires packaging
include $(MODULES_DIR)/evr_axi_rules.mk
include $(MODULES_DIR)/axi_lite_generic_reg_rules.mk

IP_CORES += \
	evrGTY \
	rmsBandSelect \
	positionCalcDivider \
	positionCalcMultiplier \
	adcCordic \
	adcToSysFIFO \
	ila_td256_s4096_cap
evrGTY_DIR = $(PLATFORM_TARGET)/evrGTY
rmsBandSelect_DIR = $(PLATFORM_TARGET)/rmsBandSelect
positionCalcDivider_DIR = $(PLATFORM_TARGET)/positionCalcDivider
positionCalcMultiplier_DIR = $(PLATFORM_TARGET)/positionCalcMultiplier
adcCordic_DIR = $(PLATFORM_TARGET)/adcCordic
adcToSysFIFO_DIR = $(PLATFORM_TARGET)/adcToSysFIFO
ila_td256_s4096_cap_DIR = $(PLATFORM_TARGET)/ila_td256_s4096_cap

IP_CORES_DIRS += \
	$(evrGTY_DIR) \
	$(rmsBandSelect_DIR) \
	$(positionCalcDivider_DIR) \
	$(positionCalcMultiplier_DIR) \
	$(adcCordic_DIR) \
	$(adcToSysFIFO_DIR) \
	$(ila_td256_s4096_cap_DIR)

IP_CORES_XCIS += \
	evrGTY.xci \
	rmsBandSelect.xci \
	positionCalcDivider.xci \
	positionCalcMultiplier.xci \
	adcCordic.xci \
	adcToSysFIFO.xci \
	ila_td256_s4096_cap.xci

IP_CORES_SRCS_DIRS = $(IP_CORES_DIRS)
IP_CORES_SRCS_DIRS += $(addsuffix /synth, $(IP_CORES_DIRS))
IP_CORES_SRCS_DIRS += $(addsuffix /hdl, $(IP_CORES_DIRS))

BD_SYSTEM_NAME ?= system

ifeq ($(BD_SYSTEM_NAME),system)
	system_DIR = $(PLATFORM_TARGET)/system
	SYSTEM_TOP_PINS_XDC += $(TARGET)_top_ddr_pins.xdc
	SYSTEM_TOP_TIM_XDC += $(TARGET)_top_ddr_tim.xdc
else
$(error BD_SYSTEM_NAME = $(BD_SYSTEM_NAME) unsupported)
endif

BD = system
system_TOP = $(system_DIR)/synth/system.v
BD_TOP_LVL_SRCS += $(system_TOP)
BD_DIRS = $(system_DIR)

BD_SRCS_DIRS = $(BD_DIRS)
BD_SRCS_DIRS += $(addsuffix /synth, $(BD_DIRS))
BD_SRCS_DIRS += $(addsuffix /hdl, $(BD_DIRS))

BD_bds = $(addsuffix .bd, $(BD))

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
VFLAGS_DEP += -y$(GW_TOP_COMMON_DIR)
VFLAGS_DEP += -y$(TOP_LVL_DIR)
VFLAGS_DEP += $(addprefix -y, $(IP_CORES_SRCS_DIRS))
VFLAGS_DEP += $(addprefix -y, $(BD_SRCS_DIRS))

# Local directories for include searching
VFLAGS_DEP += -I.
VFLAGS_DEP += -I$(MODULES_DIR)
VFLAGS_DEP += -I$(GW_TOP_COMMON_DIR)
VFLAGS_DEP += -I$(TOP_LVL_DIR)
VFLAGS_DEP += $(addprefix -I, $(IP_CORES_SRCS_DIRS))
VFLAGS_DEP += $(addprefix -I, $(BD_SRCS_DIRS))

# additional vflags, our files that have more than 1 top-level module
EXTRA_VFLAGS_DEP += extra_iverilog_cfile.txt
VFLAGS_DEP += $(addprefix -c, $(VFLAGS_COMMAND_FILE) $(EXTRA_VFLAGS_DEP))

VFLAGS_DEP += -DSIMULATE

# Search prerequisites for generated .v/.vh/.vhd/.xdc here
vpath %.v $(IP_CORES_SRCS_DIRS) $(BD_SRCS_DIRS)
vpath %.vh $(IP_CORES_SRCS_DIRS) $(BD_SRCS_DIRS)
vpath %.vhd $(IP_CORES_SRCS_DIRS) $(BD_SRCS_DIRS)
vpath %.xdc $(IP_CORES_SRCS_DIRS) $(BD_SRCS_DIRS)
vpath %.tcl $(GW_SCRIPTS_DIR)
vpath %.sh $(GW_SCRIPTS_DIR)

# List top level depedencies here. Eveything named .bit will be used as
# a top-level target in top_rules.mk. .v and .sv files will be used as
# prerequisites as well as a system_top.xdc file
$(TARGET)_top.bit: system_top.xdc $(VIVADO_SYNTH_EXTRA_TCL) $(TOP_LVL_DIR)/$(TARGET)_top.v $(BD_bds) $(IP_CORES_XCIS)
$(TOP_LVL_DIR)/$(TARGET)_top.v: $(TOP_LVL_DIR)/gitHash.vh $(TOP_LVL_DIR)/firmwareBuildDate.v $(TOP_LVL_DIR)/gpioIDX.v $(EXTRA_VFLAGS_DEP) $(IP_CORES_CUSTOM) $(BD_TOP_LVL_SRCS) cordicg_b22.v

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

# ip_cores commands. Keep track only of the top-level. If this changed or doesn't
# exist regenerate eveything. Otherwise, consider this up to date
vpath %.xci $(IP_CORES_SRCS_DIRS) $(BD_SRCS_DIRS)
vpath %.bd $(IP_CORES_SRCS_DIRS) $(BD_SRCS_DIRS)

# Use second expansion here so we can get the matched target name in the prerequisite
# and use the defined variable to find the .xci one level below.
# FIXME: Is there an easier way to do this?
.SECONDEXPANSION:
$(IP_CORES_TOP_LVL_SRCS): % : $$(basename $$(notdir %)).xci
	$(VIVADO_CMD) -source $(GW_SCRIPTS_DIR)/ip_core_proc.tcl $(GW_SCRIPTS_DIR)/gen_ip_core.tcl -tclargs $< $(PROJECT_PART) $(PROJECT_BOARD)
	# fix line-continuation between (* *) attribute that iverilog doesn't understand
	# from: https://catonmat.net/sed-one-liners-explained-part-one,
	# 39. Append a line to the next if it ends with a backslash "\".
	TOP_LVL="$*"; if [ "$${TOP_LVL##*.}" = "v" ] || [ "$${TOP_LVL##*.}" = "sv" ]; then sed -i -e :a -e '/\\$$/N; s/\\\n//; ta' $${TOP_LVL}; fi
	# generate iverilog switches
	rm -f $($(basename $(notdir $@))_VFLAGS_COMMAND_FILE)
	(find $($(basename $(notdir $@))_DIR)/hdl $($(basename $(notdir $@))_DIR)/synth -mindepth 1 -not \( -name \*rfs.v \) -name "*.v" -exec echo "-l"'{}' \; || true) >> $($(basename $(notdir $@))_VFLAGS_COMMAND_FILE)
	(find $($(basename $(notdir $@))_DIR) -mindepth 1 -maxdepth 1 -not \( -name \*rfs.v \) -name "*.v" -exec echo "-l"'{}' \; || true) >> $($(basename $(notdir $@))_VFLAGS_COMMAND_FILE)

$(BD_TOP_LVL_SRCS): % : $$(basename $$(notdir %)).bd
	$(VIVADO_CMD) -source $(GW_SCRIPTS_DIR)/bd_proc.tcl $(GW_SCRIPTS_DIR)/gen_bd.tcl -tclargs $< $(PROJECT_PART) $(PROJECT_BOARD) $(IP_CORES_CUSTOM_TARGET_DIRS)

# clean generate IP cores files, but the source ones (.xci or .bd)
clean::
	$(foreach ipcore, $(IP_CORES), test -f $($(ipcore)_DIR)/$(ipcore).xci && find $($(ipcore)_DIR) -mindepth 1 -not \( -name \*$(ipcore).xci -o -name \*$(ipcore).bd -o -name \*$(ipcore).coe \) -delete $(CMD_SEP))
	$(foreach bd, $(BD), test -f $($(bd)_DIR)/$(bd).bd && find $($(bd)_DIR) -mindepth 1 -not \( -name \*$(bd).xci -o -name \*$(bd).bd \) -delete $(CMD_SEP))

# Cleaning rules
include $(CELL_COMM_DIR)/bottom_rules.mk
include $(BUILD_DIR)/bottom_rules.mk

CLEAN += *.bit
CLEAN += system_top.xdc
CLEAN += $(TOP_LVL_DIR)/firmwareBuildDate.v
CLEAN += $(TOP_LVL_DIR)/gpioIDX.v
CLEAN += $(TOP_LVL_DIR)/gitHash.vh
CLEAN += cordicg_b22.v
CLEAN += $(IP_CORES_CUSTOM)
CLEAN += $(VFLAGS_COMMAND_FILE)
CLEAN += *.log *.jou *.str
CLEAN += *.xsa
CLEAN += psu_init*
CLEAN += ipcores_repos.tcl
CLEAN += prio_xci_files.tcl
CLEAN += $(EXTRA_VFLAGS_DEP)
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
