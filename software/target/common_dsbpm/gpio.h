/*
 * Indices into the big general purpose I/O block.
 * Used to generate Verilog parameter statements too, so be careful with
 * the syntax:
 *     Spaces only (no tabs).
 *     Index defines must be valid Verilog parameter lval expressions.
 */

#ifndef _GPIO_H_
#define _GPIO_H_

#define GPIO_IDX_COUNT 1024

#define GPIO_IDX_FIRMWARE_BUILD_DATE      0 // Firmware build POSIX seconds (R)
#define GPIO_IDX_MICROSECONDS_SINCE_BOOT  1 // Microseconds since boot (R)
#define GPIO_IDX_SECONDS_SINCE_BOOT       2 // Seconds since boot (R)
#define GPIO_IDX_USER_GPIO_CSR            3 // Diagnostic LEDS/switches
#define GPIO_IDX_GTY_CSR                  4 // GTY control/status
#define GPIO_IDX_EVR_SYNC_CSR             5 // Event receiver synchronization
#define GPIO_IDX_SYSREF_ADC_CSR           6 // SYSREF ADC generation control/status
#define GPIO_IDX_FREQ_MONITOR_CSR         7 // Frequency measurement CSR
#define GPIO_IDX_EVR_GTY_DRP              8 // EVR GTY dynamic reconfig (R/W)
#define GPIO_IDX_SOFT_TRIGGER             9 // Acquisition software trigger (W)
#define GPIO_IDX_DISPLAY_CSR             10 // Display CSR (R/W)
#define GPIO_IDX_DISPLAY_DATA            11 // Display I/O (R/W)
#define GPIO_IDX_ADC_SYNC_CSR            12 // ADC synchronization
#define GPIO_IDX_INTERLOCK_CSR           13 // Interlock (R/W)
#define GPIO_IDX_EVENT_LOG_CSR           15 // Event logger control/seconds
#define GPIO_IDX_EVENT_LOG_TICKS         16 // Event logger ticks
#define GPIO_IDX_ADC_RANGE_CSR           17 // Monitor ADC ranges
#define GPIO_IDX_CLK104_SPI_MUX_CSR      18 // Select CLK104 SPI MUX
#define GPIO_IDX_EVR_FA_RELOAD           19 // Fast acquisition divider reload
#define GPIO_IDX_EVR_SA_RELOAD           20 // Slow acquisition divider reload
#define GPIO_IDX_GITHASH                 21 // Git 32-bit hash
#define GPIO_IDX_SYSREF_DAC_CSR          22 // SYSREF DAC generation control/status

/*
 * Per DSBPM registers
 */
#define GPIO_IDX_LOTABLE_ADDRESS         32 // Local oscillator table write address
#define GPIO_IDX_LOTABLE_CSR             33 // Local oscillator tables
#define GPIO_IDX_SUM_SHIFT_CSR           34 // Accumulator scaling values
#define GPIO_IDX_AUTOTRIM_CSR            35 // Auto gain compensation control/status
#define GPIO_IDX_AUTOTRIM_THRESHOLD      36 // Auto gain compensation tone threshold
#define GPIO_IDX_ADC_GAIN_FACTOR_0       37 // Gain factor for ADC 0
#define GPIO_IDX_ADC_GAIN_FACTOR_1       38 // Gain factor for ADC 1
#define GPIO_IDX_ADC_GAIN_FACTOR_2       39 // Gain factor for ADC 2
#define GPIO_IDX_ADC_GAIN_FACTOR_3       40 // Gain factor for ADC 3
#define GPIO_IDX_PRELIM_STATUS           41 // Preliminary processing status
#define GPIO_IDX_PRELIM_RF_MAG_0         42 // ADC 0 RF (SA) magnitude
#define GPIO_IDX_PRELIM_RF_MAG_1         43 // ADC 1 RF (SA) magnitude
#define GPIO_IDX_PRELIM_RF_MAG_2         44 // ADC 2 RF (SA) magnitude
#define GPIO_IDX_PRELIM_RF_MAG_3         45 // ADC 3 RF (SA) magnitude
#define GPIO_IDX_PRELIM_PT_LO_MAG_0      46 // ADC 0 low freq pilot tone magnitude
#define GPIO_IDX_PRELIM_PT_LO_MAG_1      47 // ADC 1 low freq pilot tone magnitude
#define GPIO_IDX_PRELIM_PT_LO_MAG_2      48 // ADC 2 low freq pilot tone magnitude
#define GPIO_IDX_PRELIM_PT_LO_MAG_3      49 // ADC 3 low freq pilot tone magnitude
#define GPIO_IDX_PRELIM_PT_HI_MAG_0      50 // ADC 0 high freq pilot tone magnitude
#define GPIO_IDX_PRELIM_PT_HI_MAG_1      51 // ADC 1 high freq pilot tone magnitude
#define GPIO_IDX_PRELIM_PT_HI_MAG_2      52 // ADC 2 high freq pilot tone magnitude
#define GPIO_IDX_PRELIM_PT_HI_MAG_3      53 // ADC 3 high freq pilot tone magnitude
#define GPIO_IDX_SA_TIMESTAMP_SEC        54 // Slow acquisition time stamp
#define GPIO_IDX_SA_TIMESTAMP_FRACTION   55 // Slow acquisition time stamp
#define GPIO_IDX_POSITION_CALC_CSR       56 // Position calculation control/status
#define GPIO_IDX_POSITION_CALC_XCAL      57 // X calibration factor
#define GPIO_IDX_POSITION_CALC_YCAL      58 // Y calibration factor
#define GPIO_IDX_POSITION_CALC_QCAL      59 // Q calibration factor
#define GPIO_IDX_POSITION_CALC_SA_X      60 // Slow acquisition X position
#define GPIO_IDX_POSITION_CALC_SA_Y      61 // Slow acquisition Y position
#define GPIO_IDX_POSITION_CALC_SA_Q      62 // Slow acquisition skew
#define GPIO_IDX_POSITION_CALC_SA_S      63 // Slow acquisition sum
#define GPIO_IDX_LOSS_OF_BEAM_THRSH      64 // Loss-of-beam threshold
#define GPIO_IDX_LOSS_OF_BEAM_TRIGGER    65 // Loss-of-beam trigger
#define GPIO_IDX_RMS_X_WIDE              66 // RMS X wide bandwidth
#define GPIO_IDX_RMS_Y_WIDE              67 // RMS Y wide bandwidth
#define GPIO_IDX_RMS_X_NARROW            68 // RMS X narrow bandwidth
#define GPIO_IDX_RMS_Y_NARROW            69 // RMS Y narrow bandwidth
#define GPIO_IDX_WFR_SOFT_TRIGGER        70 // WFR soft trigger
#define GPIO_IDX_ADC_PROCESSING          71 // ADC processing
#define GPIO_IDX_DACTABLE_ADDRESS        72 // DAC table address
#define GPIO_IDX_DACTABLE_CSR            73 // DAC table CSR
#define GPIO_IDX_AFE_SPI_CSR             74 // AFE SPI devices (R/W)
#define GPIO_IDX_RF_GAIN_FACTOR_0        75 // ADC 0 RF gain
#define GPIO_IDX_RF_GAIN_FACTOR_1        76 // ADC 1 RF gain
#define GPIO_IDX_RF_GAIN_FACTOR_2        77 // ADC 2 RF gain
#define GPIO_IDX_RF_GAIN_FACTOR_3        78 // ADC 3 RF gain
#define GPIO_IDX_PL_GAIN_FACTOR_0        79 // ADC 0 low freq pilot tone gain
#define GPIO_IDX_PL_GAIN_FACTOR_1        80 // ADC 1 low freq pilot tone gain
#define GPIO_IDX_PL_GAIN_FACTOR_2        81 // ADC 2 low freq pilot tone gain
#define GPIO_IDX_PL_GAIN_FACTOR_3        82 // ADC 3 low freq pilot tone gain
#define GPIO_IDX_PH_GAIN_FACTOR_0        83 // ADC 0 high freq pilot tone gain
#define GPIO_IDX_PH_GAIN_FACTOR_1        84 // ADC 1 high freq pilot tone gain
#define GPIO_IDX_PH_GAIN_FACTOR_2        85 // ADC 2 high freq pilot tone gain
#define GPIO_IDX_PH_GAIN_FACTOR_3        86 // ADC 3 high freq pilot tone gain
#define GPIO_IDX_CLOCK_STATUS            87 // BPM Sync/Clock status
#define GPIO_IDX_CELL_COMM_TEST          88 // Cell Comm test

#define GPIO_IDX_PER_DSBPM               (GPIO_IDX_CELL_COMM_TEST-GPIO_IDX_LOTABLE_ADDRESS+1)

#define CFG_AXI_SAMPLES_PER_CLOCK        1 // 1 sample per clock
// For compatibility
#define CFG_ADC_AXI_SAMPLES_PER_CLOCK    CFG_AXI_SAMPLES_PER_CLOCK
#define CFG_DAC_AXI_SAMPLES_PER_CLOCK    2 // 2 sample per clock (I and Q)
#define CFG_LO_RF_ROW_CAPACITY           1024
#define CFG_LO_PT_ROW_CAPACITY           8192

#define CFG_PT_GEN_ROW_CAPACITY          32768 // 2^15 per DAC sample (I and Q)

// FOFB communication
#define GPIO_IDX_CELL_COMM_CCW_CSR       256
#define GPIO_IDX_CELL_COMM_CW_CSR        257
#define GPIO_IDX_CELL_COMM_CCW_CRC_FAULTS 258
#define GPIO_IDX_CELL_COMM_CW_CRC_FAULTS 259

#define CFG_NUM_CC_BPMS                  2
#define GPIO_IDX_PER_CC_BPM              1

#define GPIO_IDX_CELL_COMM_BPM_CSR       260
#define GPIO_IDX_CELL_COMM_BPM_PER_DSBPM (GPIO_IDX_CELL_COMM_BPM_CSR-GPIO_IDX_CELL_COMM_BPM_CSR+1)

// Waveform recorders
// Capacities must be powers of two
#define CFG_NUM_RECORDERS                7 // ADC, TbT, FA, PL, PH, TbT Pos, FA Pos
#define GPIO_IDX_PER_RECORDER            8

#define GPIO_IDX_ADC_RECORDER_BASE       512  // ADC recorder
#define GPIO_IDX_ADC_RECORDER_END        519
#define GPIO_IDX_TBT_RECORDER_BASE       520  // Turn-by-turn recorder
#define GPIO_IDX_TBT_RECORDER_END        527
#define GPIO_IDX_FA_RECORDER_BASE        528  // Fast acquisition recorder
#define GPIO_IDX_FA_RECORDER_END         535
#define GPIO_IDX_PL_RECORDER_BASE        536  // Low pilot tone recorder
#define GPIO_IDX_PL_RECORDER_END         543
#define GPIO_IDX_PH_RECORDER_BASE        544  // High pilot tone recorder
#define GPIO_IDX_PH_RECORDER_END         551
#define GPIO_IDX_TBT_POS_RECORDER_BASE   552  // Turn-by-turn position recorder
#define GPIO_IDX_TBT_POS_RECORDER_END    559
#define GPIO_IDX_FA_POS_RECORDER_BASE    560  // Fast acquisition position recorder
#define GPIO_IDX_FA_POS_RECORDER_END     567
#define GPIO_IDX_RECORDER_PER_DSBPM      (GPIO_IDX_FA_POS_RECORDER_END-GPIO_IDX_ADC_RECORDER_BASE+1)

#include <xil_io.h>
#include <xparameters.h>
#include "config.h"

#define GPIO_READ(i)    Xil_In32(XPAR_AXI_LITE_GENERIC_REG_0_BASEADDR+(4*(i)))
#define GPIO_WRITE(i,x) Xil_Out32(XPAR_AXI_LITE_GENERIC_REG_0_BASEADDR+(4*(i)),(x))
#define MICROSECONDS_SINCE_BOOT()   GPIO_READ(GPIO_IDX_MICROSECONDS_SINCE_BOOT)

#define USER_GPIO_CSR_RECOVERY_MODE_BUTTON  0x80000000
#define USER_GPIO_CSR_DISPLAY_MODE_BUTTON   0x40000000
#define USER_GPIO_CSR_HEARTBEAT             0x10000

#define EVR_SYNC_CSR_HB_GOOD    0x2
#define EVR_SYNC_CSR_PPS_GOOD   0x4

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

#endif
