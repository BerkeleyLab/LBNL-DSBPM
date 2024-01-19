/*
 * Deal with loss of beam firmware
 */

#include <stdio.h>
#include <stdint.h>
#include "gpio.h"

#define REG(base,chan)  ((base) + (GPIO_IDX_PER_DSBPM * (chan)))

void lossOfBeamThreshold(unsigned int bpm, uint32_t thrs)
{
    if (bpm >= CFG_DSBPM_COUNT) return;
    GPIO_WRITE(REG(GPIO_IDX_LOSS_OF_BEAM_THRSH, bpm), thrs);
}
