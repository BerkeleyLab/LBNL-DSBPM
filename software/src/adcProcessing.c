#include <stdint.h>
#include <stdio.h>
#include "adcProcessing.h"
#include "gpio.h"

#define REG(base,chan)  ((base) + (GPIO_IDX_PER_DSBPM * (chan)))

/*
 * Acquisition markers
 */
void
adcProcessingRMSThrs(int bpm, uint32_t thrs)
{
    int ch;

    if (bpm < 0) {
        for (ch = 0 ; ch < CFG_DSBPM_COUNT ; ch++) {
            GPIO_WRITE(REG(GPIO_IDX_ADC_PROCESSING, ch), thrs);
        }
    }
    else if (bpm < CFG_DSBPM_COUNT) {
        GPIO_WRITE(REG(GPIO_IDX_ADC_PROCESSING, bpm), thrs);
    }
}
