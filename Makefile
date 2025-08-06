include dir_list.mk

CROSS_COMPILE    ?=
PLATFORM         ?= zcu208
APP              ?= dsbpm
SAMPLES_PER_TURN ?= 81
VCXO_TYPE        ?= 160
VARIANT          ?=

BD_SYSTEM_NAME   ?= system

TARGET       = $(APP)_$(PLATFORM)
GW_TGT_DIR   = $(GW_SYN_DIR)/$(TARGET)
BIT          = $(GW_TGT_DIR)/$(TARGET)_top.bit
SW_TGT_DIR   = $(SW_APP_DIR)/$(APP)

.PHONY: all bit sw

all: bit sw

bit:
	make -C $(GW_TGT_DIR) BD_SYSTEM_NAME=$(BD_SYSTEM_NAME) TARGET=$(TARGET) $(TARGET)_top.bit

sw:
	make -C $(SW_TGT_DIR) VARIANT=$(VARIANT) SAMPLES_PER_TURN=$(SAMPLES_PER_TURN) VCXO_TYPE=$(VCXO_TYPE) TARGET=$(TARGET) BIT=$(BIT) all

clean:
	make -C $(GW_TGT_DIR) TARGET=$(TARGET) clean
	make -C $(SW_TGT_DIR) TARGET=$(TARGET) clean
	rm -f *.log *.jou
