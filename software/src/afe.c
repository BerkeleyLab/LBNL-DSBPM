/*
 * Communicate with analog front end components
 */

#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include <limits.h>
#include "afe.h"
#include "gpio.h"
#include "rfdc.h"
#include "systemParameters.h"
#include "util.h"

#define SPI_DEVSEL_SHIFT    24
#define SPI_DEVSEL_MASK     0x07000000

#define SPI_W_24_BIT_OP     0x80000000
#define SPI_W_LSB_FIRST     0x40000000

#define SPI_R_BUSY          0x80000000

#define REG(base,chan)  ((base) + (GPIO_IDX_PER_DSBPM * (chan)))

#define ADC_RANGE_CSR_CMD_LATCH 0x1
#define ADC_RANGE_CSR_CMD_SHIFT 0x2

static unsigned int afeAttenuation[CFG_DSBPM_COUNT][CFG_ADC_PER_BPM_COUNT];

void
afeInit(void)
{
}

int
afeGetSerialNumber(void)
{
    return 0;
}

/*
 * Set attenuators
 */
void
afeAttenSet(unsigned int bpm, unsigned int channel,
        unsigned int mdB)
{
    static const int address = 0x7;
    int pass = 0;

    if (bpm >= CFG_DSBPM_COUNT) return;
    if (channel >= CFG_ADC_PER_BPM_COUNT) return;
    // All channels are wired together
    channel = 0;

    /*
     * Write trimmed value
     */
    int attSteps = (mdB * 4)/1000;
    if (attSteps > 127) attSteps = 127;
    else if (attSteps < 0) attSteps = 0;

    int v = attSteps;
    // SPI data: 8-bit address | 8-bit data
    v |= address << 8;
    // SPI module options
    v |= SPI_W_LSB_FIRST | ((channel << SPI_DEVSEL_SHIFT) & SPI_DEVSEL_MASK);
    while  (GPIO_READ(REG(GPIO_IDX_AFE_SPI_CSR, bpm)) & SPI_R_BUSY) {
        if (++pass >= 100) {
            warn("ATTENUATOR UPDATE FAILED TO COMPLETE");
            break;
        }
    }
    GPIO_WRITE(REG(GPIO_IDX_AFE_SPI_CSR, bpm), v);

#if 0
    /*
     * Write trimmed value
     */
    do {
        int pass = 0;
        int v = (mdB * 4)/1000 + systemParameters.afeTrim[i];
        if (v > 127) v = 127;
        else if (v < 0) v = 0;
        // SPI data: 8-bit address | 8-bit data
        v |= address << 8;
        // SPI module options
        v |= SPI_W_LSB_FIRST | ((channel << SPI_DEVSEL_SHIFT) & SPI_DEVSEL_MASK);
        while  (GPIO_READ(REG(GPIO_IDX_AFE_SPI_CSR, bpm)) & SPI_R_BUSY) {
            if (++pass >= 100) {
                warn("ATTENUATOR UPDATE FAILED TO COMPLETE");
                break;
            }
        }
        GPIO_WRITE(REG(GPIO_IDX_AFE_SPI_CSR, bpm), v);
    } while (++i < sizeof systemParameters.afeTrim /
                                            sizeof systemParameters.afeTrim[0]);
#endif

    /*
     * Update attenuator compenstation coefficients in FPGA.
     * Step is 0.25
     */
    afeAttenuation[bpm][channel] = attSteps*1000/4;
}

/*
 * Read back attenuator setting
 */
unsigned int
afeAttenGet(unsigned int bpm, unsigned int channel)
{
    if (bpm >= CFG_DSBPM_COUNT) return 0;
    if (channel >= CFG_ADC_PER_BPM_COUNT) return 0;
    // All channels are wired together
    channel = 0;

    return afeAttenuation[bpm][channel];
}

void
afeADCrestart(void)
{
    int i;

    // Unfreeze all ADCs
    for (i = 0 ; i < CFG_ADC_PHYSICAL_COUNT ; i++) {
        rfADCfreezeCalibration(i, 0);
    }
    // Perform ADC restart (foreground calibration)
    rfADCrestart();
    // Perform ADC synchronization
    rfDCsync();
}

/*
 * Fetch ADC extents for each channel
 */
int
afeFetchADCextents(uint32_t *buf)
{
    int channel, i;
    GPIO_WRITE(GPIO_IDX_ADC_RANGE_CSR, ADC_RANGE_CSR_CMD_LATCH);
    for (channel = 0 ; channel < CFG_ADC_PHYSICAL_COUNT ; channel++) {
        int min = INT_MAX, max = INT_MIN;
        for (i = 0 ; i < CFG_AXI_SAMPLES_PER_CLOCK ; i++) {
            int v;
            v = (int16_t)(GPIO_READ(GPIO_IDX_ADC_RANGE_CSR) & 0xFFFF);
            GPIO_WRITE(GPIO_IDX_ADC_RANGE_CSR, ADC_RANGE_CSR_CMD_SHIFT);
            if (v < min) min = v;
            v = (int16_t)(GPIO_READ(GPIO_IDX_ADC_RANGE_CSR) & 0xFFFF);
            GPIO_WRITE(GPIO_IDX_ADC_RANGE_CSR, ADC_RANGE_CSR_CMD_SHIFT);
            if (v > max) max = v;
        }
        *buf++ = (max << 16) | (min & 0xFFFF);
    }
    return CFG_ADC_PHYSICAL_COUNT;
}
