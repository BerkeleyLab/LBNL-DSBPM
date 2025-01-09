__COMMON_DSBPM_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
COMMON_DSBPM_DIR := $(__COMMON_DSBPM_DIR:/=)

__HDR_COMMON_DSBPM_FILES = \
	iic.h
HDR_COMMON_DSBPM_FILES = $(addprefix $(COMMON_DSBPM_DIR)/, $(__HDR_COMMON_DSBPM_FILES))

__SRC_COMMON_DSBPM_FILES = \
	iic.c
SRC_COMMON_DSBPM_FILES = $(addprefix $(COMMON_DSBPM_DIR)/, $(__SRC_COMMON_DSBPM_FILES))

__HDR_GEN_COMMON_DSBPM_FILES = \
	idt8A34001.h
HDR_GEN_COMMON_DSBPM_FILES = $(addprefix $(COMMON_DSBPM_DIR)/, $(__HDR_GEN_COMMON_DSBPM_FILES))

# For top-level makefile
HDR_FILES += $(HDR_COMMON_DSBPM_FILES) $(HDR_GEN_COMMON_DSBPM_FILES)
SRC_FILES += $(SRC_COMMON_DSBPM_FILES)
INCLUDE_DIRS += $(COMMON_DSBPM_DIR)

%lmk04828B.h: %lmk04828B.tcs
	sh $(SW_SCRIPTS_DIR)/createRFCLKheader.sh $< > $@

%lmx2594ADC.h: %lmx2594ADC.tcs
	sh $(SW_SCRIPTS_DIR)/createRFCLKheader.sh $< > $@

%lmx2594DAC.h: %lmx2594DAC.tcs
	sh $(SW_SCRIPTS_DIR)/createRFCLKheader.sh $< > $@

%idt8A34001.h: %idt8A34001.txt
	python3 $(SW_SCRIPTS_DIR)/idtParsing.py -f $< > $@

clean::
	$(RM) -rf $(HDR_GEN_COMMON_DSBPM_FILES)
