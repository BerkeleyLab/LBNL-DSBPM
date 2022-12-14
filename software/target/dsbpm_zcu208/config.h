/*
 * Configuration values specific to a particular site or  application.
 * Same restrictions as noted in gpio.h.
 */
#define VERILOG_FIRMWARE_STYLE_HSD
#define CFG_ACQUISITION_BUFFER_CAPACITY     (1<<15)
#define CFG_LONG_SEGMENT_CAPACITY           (1<<9)
#define CFG_SHORT_SEGMENT_CAPACITY          (1<<6)
#define CFG_EARLY_SEGMENTS_COUNT            5
#define CFG_SEGMENT_PRETRIGGER_COUNT        32
#define CFG_DSPS_PER_BONDED_GROUP           4

/*
 * For softwre compatibility:
 */
#define CFG_ADCS_PER_BONDED_GROUP CFG_DSPS_PER_BONDED_GROUP

/*
 * ADC AXI MMCM (adcClk source) configuration
 * Values are scaled by a factor of 1000.
 */
#define ADC_CLK_MMCM_MULTIPLIER   50625
#define ADC_CLK_MMCM_DIVIDER      10000
#define ADC_CLK_MMCM_CLK1_DIVIDER 4000

/* For compatibility */
#define ADC_CLK_MMCM_CLK0_DIVIDER ADC_CLK_MMCM_DIVIDER

/*
 * Number of ADC AXI clocks per SYSREF clock
 */
#define ADC_CLK_PER_SYSREF  81

/*
 * Number of FPGA_REFCLK_OUT_C clocks per SYSREF clock
 */
#define REFCLK_OUT_PER_SYSREF   272

/*
 * Number of ADC streams required by application
 */
#define CFG_ADC_CHANNEL_COUNT    16 // I/Q

/*
 * Number of DSP channels per DSBPM
 */
#define CFG_DSP_CHANNEL_COUNT    24 // ADC0, ADC1, ADC2, ADC3 (I, Q), A, B, C, D, X, Y, Q, S (TbT, FA)

/*
 * For softwre compatibility:
 */
#define CFG_ACQ_CHANNEL_COUNT CFG_DSP_CHANNEL_COUNT

/*
 * Number of physical ADC channels required by application
 */
#define CFG_ADC_PHYSICAL_COUNT    8

/*
 * Number of DSP chains
 */
#define CFG_DSBPM_COUNT         ((CFG_ADC_PHYSICAL_COUNT + 3)/4)

/*
 * ADC sampling clock frequency
 */
/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. 81*40 = 3240
 */
//#define CFG_ADC_SAMPLING_CLK_FREQ   4935.468
#define CFG_ADC_SAMPLING_CLK_FREQ   3240.000

/*
 * ADC reference clock
 */
/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. 81*40 = 3240
 */
//#define CFG_ADC_REF_CLK_FREQ   4935.468
#define CFG_ADC_REF_CLK_FREQ   3240.000

/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. We want to shift the carrier to the 20th bin.
 *  Since the RF is at bin 328 or -328, bin 20 would be at -308
 */
#define CFG_ADC_NCO_FREQ -308.000
