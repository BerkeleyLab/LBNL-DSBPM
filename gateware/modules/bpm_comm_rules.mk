bpm_comm_DIR = $(MODULES_DIR)/bpm_comm
__bpm_comm_SRCS = \
			   cellComm.v \
			   cellCommAuroraCore.v  \
			   cellCommBPM.v \
			   cellCommBPMCore.v \
			   cellCommDataSwitch.v
bpm_comm_SRCS = $(addprefix $(bpm_comm_DIR)/, $(__bpm_comm_SRCS))

# Mapping ipcore generation for bpm_comm

ifneq ($(VARIANT),)
    bpm_comm_FPGA_APPLICATION_VARIANT = $(FPGA_APPLICATION)_$(VARIANT)
else
    bpm_comm_FPGA_APPLICATION_VARIANT = $(FPGA_APPLICATION)
endif

bpm_comm_TARGET_PLATFORM_DIR = $(PLATFORM_DIR)/$(FPGA_VENDOR)/$(FPGA_PLATFORM)/$(bpm_comm_FPGA_APPLICATION_VARIANT)/
bpm_comm_IP_CORES = \
	cellCommFIFO \
	cellCommMux \
	cellCommSendFIFO

bpm_comm_TCLS = $(foreach ip_core, $(bpm_comm_IP_CORES), $(addprefix $(TARGET_PLATFORM_DIR)/$(ip_core)/,$(addsuffix .tcl, $(ip_core))))

# For top-level makefile
IP_CORES_TCLS += $(bpm_comm_TCLS)

vpath %.tcl $(bpm_comm_DIR)
vpath %.v $(bpm_comm_DIR)

VFLAGS_DEP += $(addprefix -y, $(bpm_comm_DIR))
VFLAGS_DEP += $(addprefix -I, $(bpm_comm_DIR))

# clean generate IP cores files, but the source ones (.tcl)
clean::
	$(foreach ipcore, $(bpm_comm_IP_CORES), test -f $(bpm_comm_TARGET_PLATFORM_DIR)/$(ipcore)/$(ipcore).tcl && find $(bpm_comm_TARGET_PLATFORM_DIR)/$(ipcore) -mindepth 1 -not \( -name \*$(ipcore).tcl -o -name \*.coe \) -delete $(CMD_SEP))
