#include <stdint.h>
#include <stdio.h>
#include "evrSROC.h"
#include "gpio.h"
#include "systemParameters.h"
#include "util.h"

/*
 * Set reference clock divisor
 */
static void
initSROC(void)
{
    int refDivisor = systemParameters.rfDivisor / 4;
    int pllMultiplier = systemParameters.pllMultiplier;

    if ((systemParameters.rfDivisor <= 0)
     || ((systemParameters.rfDivisor % 4) != 0))
        warn("RF DIVISOR SYSTEM PARAMETER NOT A MULTIPLE OF 4");
    GPIO_WRITE(GPIO_IDX_EVR_SYNC_CSR, refDivisor << 16);

    // Generate heartbeat from ADC clock
    GPIO_WRITE(GPIO_IDX_ADC_SYNC_CSR, pllMultiplier << 16);

    microsecondSpin(1200*1000); /* Allow for heartbeat to occur */

    if (debugFlags & DEBUGFLAG_EVR_SROC) {
        printf("evrSROC: csr: 0x%08X\n", GPIO_READ(GPIO_IDX_EVR_SYNC_CSR));
        printf("adcSROC: csr: 0x%08X\n", GPIO_READ(GPIO_IDX_ADC_SYNC_CSR));
    }
}

void
evrSROCInit(void)
{
    initSROC();
}
