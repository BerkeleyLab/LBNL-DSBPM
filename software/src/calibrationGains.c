/*
 * Calibration gains support
 */

#include <stdio.h>
#include "calibrationGains.h"
#include "gpio.h"
#include "util.h"

#define REG(base,chan)  ((base) + (GPIO_IDX_PER_DSBPM * (chan)))

enum gainType {
    GAIN_TYPE_RF,
    GAIN_TYPE_PL,
    GAIN_TYPE_PH
};

static void cgSetStaticGains(unsigned int bpm, unsigned int channel, int gain, enum gainType type)
{
    uint32_t base;

    if (bpm >= CFG_DSBPM_COUNT) return;

    switch(type) {
    case GAIN_TYPE_RF:
        base = GPIO_IDX_RF_GAIN_FACTOR_0;
        break;

    case GAIN_TYPE_PL:
        base = GPIO_IDX_PL_GAIN_FACTOR_0;
        break;

    case GAIN_TYPE_PH:
        base = GPIO_IDX_PH_GAIN_FACTOR_0;
        break;
    }

    GPIO_WRITE(REG(base + channel, bpm), gain);
}

void cgSetStaticRFGains(unsigned int bpm, unsigned int channel, int gain)
{
    cgSetStaticGains(bpm, channel, gain, GAIN_TYPE_RF);
}

void cgSetStaticPLGains(unsigned int bpm, unsigned int channel, int gain)
{
    cgSetStaticGains(bpm, channel, gain, GAIN_TYPE_PL);
}

void cgSetStaticPHGains(unsigned int bpm, unsigned int channel, int gain)
{
    cgSetStaticGains(bpm, channel, gain, GAIN_TYPE_PH);
}
