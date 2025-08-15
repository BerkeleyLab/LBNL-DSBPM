/*
 * Communicate with the generic SPI module
 */

#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include <limits.h>
#include "util.h"
#include "gpio.h"
#include "genericSPI.h"

int
genericSPIIsBusy(struct genericSPI* spip)
{
    return (GPIO_READ(spip->gpioIdx) & SPI_R_BUSY)? 1 : 0;
}

void
genericSPISetOptions(struct genericSPI *spip, int wordSize24,
        int lsbFirst, int channel)
{
    spip->lsbFirst = lsbFirst;
    spip->channel = channel;
    spip->wordSize24 = wordSize24;
}

static int
genericSPITransaction(struct genericSPI *spip, uint32_t value)
{
    int bytes = spip->wordSize24? 3 : 2;
    uint32_t mask = ((1 << (bytes*8)) - 1);
    uint32_t v = value & mask;

    // SPI module options
    v |= (spip->wordSize24? SPI_W_24_BIT_OP: 0) |
         (spip->lsbFirst? SPI_W_LSB_FIRST: 0) |
         ((spip->channel << SPI_DEVSEL_SHIFT) & SPI_DEVSEL_MASK);

    if (spip->inProgress) {
        return -1;
    }

    // Wait up to 1 ms for transaction to complete
    int pass = 0;
    while (genericSPIIsBusy(spip)) {
        if (++pass >= 100) {
            return -1;
        }

        microsecondSpin(10);
    }

    GPIO_WRITE(spip->gpioIdx, v);
    return 0;
}

int
genericSPIWrite(struct genericSPI* spip, uint32_t value)
{
    if (genericSPITransaction(spip, value) < 0) {
        return -1;
    }

    // Number of bytes written
    return spip->wordSize24? 3 : 2;
}

int
genericSPIRead(struct genericSPI* spip, uint32_t value)
{
    if (genericSPITransaction(spip, value) < 0) {
        return -1;
    }

    // Wait up to 1 ms for transaction to complete
    int pass = 0;
    while (genericSPIIsBusy(spip)) {
        if (++pass >= 100) {
            return -1;
        }

        microsecondSpin(10);
    }

    return GPIO_READ(spip->gpioIdx) & 0x00FFFFFF;
}

int
genericSPIReadAsync(struct genericSPI* spip, uint32_t value)
{
    if (genericSPITransaction(spip, value) < 0) {
        return -1;
    }

    spip->inProgress = 1;

    return 0;
}

int
genericSPITryRead(struct genericSPI* spip, uint32_t value)
{
    if (genericSPIIsBusy(spip)) {
        return -1;
    }

    spip->inProgress = 0;

    return GPIO_READ(spip->gpioIdx) & 0x00FFFFFF;
}
