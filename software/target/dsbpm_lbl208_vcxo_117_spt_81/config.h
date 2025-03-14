/*
 * RFDC AXI MMCM (adcClk/dacClk source) configuration
 * Values are scaled by a factor of 1000.
 */
#define ADC_CLK_MMCM_DIVCLK_DIVIDER 41000
#define ADC_CLK_MMCM_MULTIPLIER     101250
#define ADC_CLK_MMCM_CLK0_DIVIDER   10000

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
