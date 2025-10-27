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
bpm_comm_IP_CORES_DIRS = $(addprefix $(bpm_comm_TARGET_PLATFORM_DIR), $(bpm_comm_IP_CORES))

# For top-level makefile
IP_CORES_XCIS += $(addsuffix .xci, $(bpm_comm_IP_CORES))
IP_CORES_DIRS += $(bpm_comm_IP_CORES_DIRS)

vpath %.v $(BPM_COMM_DIR)

VFLAGS_DEP += $(addprefix -y, $(BPM_COMM_DIR))
VFLAGS_DEP += $(addprefix -I, $(BPM_COMM_DIR))

# clean generate IP cores files, but the source ones (.xci or .bd)
clean::
	$(foreach ipcore, $(bpm_comm_IP_CORES), test -f $(bpm_comm_TARGET_PLATFORM_DIR)$(ipcore)/$(ipcore).xci && find $(bpm_comm_TARGET_PLATFORM_DIR)$(ipcore) -mindepth 1 -not \( -name \*$(ipcore).xci -o -name \*$(ipcore).bd -o -name \*$(ipcore).coe \) -delete $(CMD_SEP))
