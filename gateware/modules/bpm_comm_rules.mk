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
    FPGA_APPLICATION_VARIANT = $(FPGA_APPLICATION)_$(VARIANT)
else
    FPGA_APPLICATION_VARIANT = $(FPGA_APPLICATION)
endif

TARGET_PLATFORM_DIR = $(PLATFORM_DIR)/$(FPGA_VENDOR)/$(FPGA_PLATFORM)/$(FPGA_APPLICATION_VARIANT)
bpm_comm_IP_CORES = cellCommFIFO cellCommMux cellCommSendFIFO

cellCommFIFO_DIR = $(TARGET_PLATFORM_DIR)/cellCommFIFO
cellCommFIFO_TOP = $(cellCommFIFO_DIR)/synth/cellCommFIFO.vhd
cellCommFIFO_VFLAGS_COMMAND_FILE = cellCommFIFO_iverilog_cfile.txt
cellCommMux_DIR = $(TARGET_PLATFORM_DIR)/cellCommMux
cellCommMux_TOP = $(cellCommMux_DIR)/synth/cellCommMux.v
cellCommMux_VFLAGS_COMMAND_FILE = cellCommMux_iverilog_cfile.txt
cellCommSendFIFO_DIR = $(TARGET_PLATFORM_DIR)/cellCommSendFIFO
cellCommSendFIFO_TOP = $(cellCommSendFIFO_DIR)/synth/cellCommSendFIFO.vhd
cellCommSendFIFO_VFLAGS_COMMAND_FILE = cellCommSendFIFO_iverilog_cfile.txt

bpm_comm_IP_CORES_TOP_LVL_SRCS = $(cellCommFIFO_TOP) $(cellCommMux_TOP) $(cellCommSendFIFO_TOP)

# For top-level makefile
IP_CORES += $(bpm_comm_IP_CORES)
IP_CORES_TOP_LVL_SRCS += $(bpm_comm_IP_CORES_TOP_LVL_SRCS)
IP_CORES_DIRS += \
				 $(cellCommFIFO_DIR) \
				 $(cellCommMux_DIR) \
				 $(cellCommSendFIFO_DIR)
VFLAGS_COMMAND_FILE += \
					   $(cellCommFIFO_VFLAGS_COMMAND_FILE) \
					   $(cellCommMux_VFLAGS_COMMAND_FILE) \
					   $(cellCommSendFIFO_VFLAGS_COMMAND_FILE)
bpm_comm_SRCS += \
			   $(TARGET_PLATFORM_DIR)/cellCommFIFO/synth/cellCommFIFO.vhd \
			   $(TARGET_PLATFORM_DIR)/cellCommMux/synth/cellCommMux.v \
			   $(TARGET_PLATFORM_DIR)/cellCommSendFIFO/synth/cellCommSendFIFO.vhd

# clean generate IP cores files, but the source ones (.xci or .bd)
clean::
	$(foreach ipcore, $(bpm_comm_IP_CORES), test -f $($(ipcore)_DIR)/$(ipcore).xci && find $($(ipcore)_DIR) -mindepth 1 -not \( -name \*$(ipcore).xci -o -name \*$(ipcore).bd -o -name \*$(ipcore).coe \) -delete $(CMD_SEP))
