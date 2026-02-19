/*
 * System monitoring 2
 *  AMI SYSMON
 *  RPB SYSMON
 */
#include <stdio.h>
#include <stdint.h>
#include "display.h"
#include "sysmon2.h"
#include "ami.h"
#include "rpb.h"
#include "util.h"

void
sysmon2Init(void)
{
    sysmonDisplay();
}

/*
 * Return system monitor 2
 */
int
sysmon2Fetch(uint32_t *args)
{
    int i;
    int aIndex = 0;
    evrTimestamp now;

    evrCurrentTime(&now);
    args[aIndex++] = now.secPastEpoch;
    args[aIndex++] = now.fraction;

    aIndex += amiFetch(args + aIndex);
    aIndex += rpbFetch(args + aIndex);
    aIndex += fanCtlFetch(args + aIndex);

    return aIndex;
}

void
sysmon2Draw(int redrawAll, int page)
{
}

void
sysmon2Display(void)
{
    int bpm;

    for (bpm = 0; bpm < CFG_DSBPM_COUNT; bpm++) {
        printf("BPM%u:\n", bpm);
        amiPSinfoDisplay(bpm, 0);
    }

    printf("RPB:\n");
    rpbPSinfoDisplay(0);

    printf("Fan Speeds:\n");
    fanCtlInfoDisplay();
}
