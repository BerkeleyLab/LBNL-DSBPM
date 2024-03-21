#include <stdint.h>
#include <stdio.h>
#include "acqSync.h"
#include "gpio.h"
#include "systemParameters.h"
#include "util.h"

/*
 * Acquisition markers
 */
static void
initMarkers(void)
{
    GPIO_WRITE(GPIO_IDX_EVR_FA_RELOAD, systemParameters.evrPerFaMarker - 2);
    GPIO_WRITE(GPIO_IDX_EVR_SA_RELOAD, systemParameters.evrPerSaMarker - 2);

    microsecondSpin(1200*1000); /* Allow for heartbeat to occur */

    if (debugFlags & DEBUGFLAG_ACQ_SYNC) {
        printf("acqSync: csr FA: 0x%08X\n", GPIO_READ(GPIO_IDX_EVR_FA_RELOAD));
        printf("acqSync: csr SA: 0x%08u\n", GPIO_READ(GPIO_IDX_EVR_SA_RELOAD));
    }
}

void
acqSyncInit(void)
{
    initMarkers();
}
