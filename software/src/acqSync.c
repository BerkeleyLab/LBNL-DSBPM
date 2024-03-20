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
#ifdef GPIO_IDX_ADC_FA_RELOAD
    GPIO_WRITE(GPIO_IDX_ADC_FA_RELOAD, systemParameters.evrPerFaMarker - 2);
#endif
#ifdef GPIO_IDX_ADC_SA_RELOAD
    GPIO_WRITE(GPIO_IDX_ADC_SA_RELOAD, systemParameters.evrPerSaMarker - 2);
#endif
#ifdef GPIO_IDX_ADC_HEARTBEAT_RELOAD
    GPIO_WRITE(GPIO_IDX_ADC_HEARTBEAT_RELOAD,
            systemParameters.adcHeartbeatMarker - 2);
#endif

    microsecondSpin(1200*1000); /* Allow for heartbeat to occur */

    if (debugFlags & DEBUGFLAG_ACQ_SYNC) {
        printf("acqSync: csr FA: 0x%08X\n", GPIO_READ(GPIO_IDX_EVR_FA_RELOAD));
        printf("acqSync: csr SA: 0x%08X\n", GPIO_READ(GPIO_IDX_EVR_SA_RELOAD));
#ifdef GPIO_IDX_ADC_FA_RELOAD
        printf("acqSync: csr ADC FA: 0x%08X\n", GPIO_READ(GPIO_IDX_ADC_FA_RELOAD));
#endif
#ifdef GPIO_IDX_ADC_SA_RELOAD
        printf("acqSync: csr ADC SA: 0x%08X\n", GPIO_READ(GPIO_IDX_ADC_SA_RELOAD));
#endif
    }
}

void
acqSyncInit(void)
{
    initMarkers();
}
