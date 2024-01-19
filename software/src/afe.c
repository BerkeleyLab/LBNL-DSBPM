/*
 * Communicate with analog front end components
 */

#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include <limits.h>
#include "afe.h"
#include "gpio.h"
#include "rfadc.h"
#include "util.h"

#define AFE_CHANNEL_COUNT   8

#define SPI_DEVSEL_SHIFT 24
#define SPI_W_24_BIT_OP  0x80000000
#define SPI_R_BUSY       0x80000000
#define SPI_DEVSEL_MASK  0x07000000

#define SPI_WRITE(v)    GPIO_WRITE(GPIO_IDX_AFE_SPI_CSR, (v))
#define SPI_READ()      GPIO_READ(GPIO_IDX_AFE_SPI_CSR)

#define ADC_RANGE_CSR_CMD_LATCH 0x1
#define ADC_RANGE_CSR_CMD_SHIFT 0x2

void
afeInit(void)
{
}

int
afeGetSerialNumber(void)
{
    return 0;
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
    rfADCsync();
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
