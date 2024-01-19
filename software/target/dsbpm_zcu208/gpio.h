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
#define GPIO_IDX_SYSREF_CSR               6 // SYSREF generation control/status
#define GPIO_IDX_FREQ_MONITOR_CSR         7 // Frequency measurement CSR
#define GPIO_IDX_EVR_GTY_DRP              8 // EVR GTY dynamic reconfig (R/W)
#define GPIO_IDX_SOFT_TRIGGER             9 // Acquisition software trigger (W)
#define GPIO_IDX_DISPLAY_CSR             10 // Display CSR (R/W)
#define GPIO_IDX_DISPLAY_DATA            11 // Display I/O (R/W)
#define GPIO_IDX_AFE_SPI_CSR             12 // AFE SPI devices (R/W)
#define GPIO_IDX_INTERLOCK_CSR           13 // Interlock (R/W)
#define GPIO_IDX_EVENT_LOG_CSR           15 // Event logger control/seconds
#define GPIO_IDX_EVENT_LOG_TICKS         16 // Event logger ticks
#define GPIO_IDX_ADC_RANGE_CSR           17 // Monitor ADC ranges
#define GPIO_IDX_CLK104_SPI_MUX_CSR      18 // Select CLK104 SPI MUX
#define GPIO_IDX_EVR_FA_RELOAD           19 // Fast acquisition divider reload
#define GPIO_IDX_EVR_SA_RELOAD           20 // Slow acquisition divider reload
#define GPIO_IDX_ADC_FA_RELOAD           21 // Fast acquisition divider reload
#define GPIO_IDX_ADC_SA_RELOAD           22 // Slow acquisition divider reload
#define GPIO_IDX_ADC_HEARTBEAT_RELOAD    23 // ADC heartbeat counter
#define GPIO_IDX_GITHASH                 24 // Git 32-bit hash

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
#define GPIO_IDX_SA_TIMESTAMP_TICKS      55 // Slow acquisition time stamp
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

#define GPIO_IDX_PER_DSBPM               (GPIO_IDX_ADC_PROCESSING-GPIO_IDX_LOTABLE_ADDRESS+1)

#define CFG_AXI_SAMPLES_PER_CLOCK         1 // 1 sample per clock
#define CFG_LO_RF_ROW_CAPACITY           1024
#define CFG_LO_PT_ROW_CAPACITY           8192

// Waveform recorders
// Capacities must be powers of two
#define CFG_NUM_RECORDERS                5 // ADC, TbT, FA, PL, PH
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
#define GPIO_IDX_RECORDER_PER_DSBPM      (GPIO_IDX_PH_RECORDER_END-GPIO_IDX_ADC_RECORDER_BASE+1)

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

#endif
