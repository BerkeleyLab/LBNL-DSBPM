/*
 * RFDC AXI MMCM (adcClk/dacClk source) configuration
 * Values are scaled by a factor of 1000.
 */
#define ADC_CLK_MMCM_DIVCLK_DIVIDE 41000
#define ADC_CLK_MMCM_MULTIPLIER    101250
#define ADC_CLK_MMCM_CLK0_DIVIDER  10000
#define ADC_CLK_MMCM_CLK1_DIVIDER  10000

/*
 * Number of ADC AXI clocks per SYSREF clock
 */
#define ADC_CLK_PER_SYSREF  81

/*
 * Number of DAC AXI clocks per SYSREF clock.
 */
#define DAC_CLK_PER_SYSREF  81

/*
 * Number of FPGA_REFCLK_OUT_C clocks per SYSREF clock
 */
#define REFCLK_OUT_PER_SYSREF   328

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
 * Number of ADCs per tile
 */
#define CFG_ADC_PER_TILE        2

/*
 * Number of tiles
 */
#define CFG_TILES_COUNT         (((CFG_ADC_PHYSICAL_COUNT)+(CFG_ADC_PER_TILE)-1)/(CFG_ADC_PER_TILE))

/*
 * For backwards compatibility
 */
#define CFG_ADC_TILES_COUNT     CFG_TILES_COUNT

/*
 * Number of ADCs per BPM
 */

#define CFG_ADC_PER_BPM_COUNT   ((CFG_ADC_PHYSICAL_COUNT)/(CFG_DSBPM_COUNT))

/*
 * Number of DAC streams required by application
 */
#define CFG_DAC_CHANNEL_COUNT    8

/*
 * Number of physical DAC channels required by application
 */
#define CFG_DAC_PHYSICAL_COUNT    8

/*
 * Number of DACs per tile
 */
#define CFG_DAC_PER_TILE        2

/*
 * Number of dapaths per DAC
 */
#define CFG_DAC_DUC_PER_DAC     1

/*
 * Datapaths offset per DAC
 */
#define CFG_DAC_DUC_OFFSET      2

/*
 * Number of tiles
 */
#define CFG_DAC_TILES_COUNT      (((CFG_DAC_PHYSICAL_COUNT)+(CFG_DAC_PER_TILE)-1)/(CFG_DAC_PER_TILE))

/*
 * Number of DACs per BPM
 */

#define CFG_DAC_PER_BPM_COUNT   ((CFG_DAC_PHYSICAL_COUNT)/(CFG_DSBPM_COUNT))

/*
 * ADC sampling clock frequency
 */
/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. 81*40 = 3240
 */
//#define ADC_SAMPLING_CLK_FREQ   4935.468
#define ADC_SAMPLING_CLK_FREQ   3240.000

/*
 * ADC reference clock
 */
/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. 81*40 = 3240
 */
//#define ADC_REF_CLK_FREQ   4935.468
#define ADC_REF_CLK_FREQ   3240.000

/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. We want to shift the carrier to the 20th bin.
 *  Since the RF is at bin 328 or -328, bin 20 would be at -308
 */
#define ADC_NCO_FREQ -308.000

/*
 * DAC sampling clock frequency
 */
/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. 81*40 = 3240
 */
//#define DAC_SAMPLING_CLK_FREQ   4935.468
#define DAC_SAMPLING_CLK_FREQ   3240.000

/*
 * DAC reference clock
 */
/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. 81*40 = 3240
 */
//#define DAC_REF_CLK_FREQ   4935.468
#define DAC_REF_CLK_FREQ   3240.000

/*
 *  Fake frequency to fool API into calculating the correct
 *  NCO frequency. We want to shift the bin to RF, which is at
 *  bin 328 or -328
 */
#define DAC_NCO_FREQ 328.000

/*
 *  Recorder capacities, in samples. Waveform recorder pads
 *  the write address by the correct sample size (usually 4
 *  32-bit samples).
 */
#define CFG_RECORDER_ADC_SAMPLE_CAPACITY 16*1024*1024
#define CFG_RECORDER_TBT_SAMPLE_CAPACITY 16*1024*1024
#define CFG_RECORDER_FA_SAMPLE_CAPACITY  16*1024*1024
#define CFG_RECORDER_PT_SAMPLE_CAPACITY  16*1024*1024
#define CFG_RECORDER_TBT_POS_SAMPLE_CAPACITY 16*1024*1024
#define CFG_RECORDER_FA_POS_SAMPLE_CAPACITY  16*1024*1024
