#include <stdio.h>
#include <string.h>
#include "gpio.h"
#include "util.h"

/*
 * Read fan tachometers
 * Works for even or odd number of fans
 */
int
fanCtlFanSpeeds(unsigned int fanIdx)
{
    if (fanIdx >= CFG_FAN_COUNT) {
        return -1;
    }

    GPIO_WRITE(GPIO_IDX_RPB_FAN_TACHOMETERS, fanIdx);
    return GPIO_READ(GPIO_IDX_RPB_FAN_TACHOMETERS) & 0xFFFF;
}

void
fanCtlInfoDisplay(void)
{
    int rawSpeed = 0;
    unsigned int fanIdx = 0;

    printf("Fan Speeds:\n");

    for (fanIdx = 0 ; fanIdx < CFG_FAN_COUNT; fanIdx++) {
        unsigned int v = 0;

        rawSpeed = fanCtlFanSpeeds(fanIdx);
        if (rawSpeed > 0) {
            v = (unsigned int)(rawSpeed * 3.75);
        }

        printf("   Fan %u: %u RPM\n", fanIdx, v);
    }
}
