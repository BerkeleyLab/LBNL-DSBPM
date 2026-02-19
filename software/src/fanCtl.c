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

int
fanCtlFetch(uint32_t *args)
{
    int shift = 0, count = 0;
    uint32_t v = 0;
    unsigned int fan = 0;

    for (fan = 0 ; fan < CFG_FAN_COUNT ; fan++) {
        if (shift > 16) {
            *args++ = v;
            v = 0;
            count++;
            shift = 0;
        }
        v |= fanCtlFanSpeeds(fan) << shift;
        shift += 16;
    }

    *args = v;

    return count + 1;
}

void
fanCtlInfoDisplay(void)
{
    int rawSpeed = 0;
    unsigned int fanIdx = 0;

    for (fanIdx = 0 ; fanIdx < CFG_FAN_COUNT; fanIdx++) {
        unsigned int v = 0;

        rawSpeed = fanCtlFanSpeeds(fanIdx);
        if (rawSpeed > 0) {
            v = (unsigned int)(rawSpeed * 3.75);
        }

        printf("   Fan %u: %u RPM\n", fanIdx, v);
    }
}
