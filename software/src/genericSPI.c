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
        int lsbFirst, int cpol, int cpha, int channel)
{
    spip->lsbFirst = lsbFirst;
    spip->wordSize24 = wordSize24;
    spip->cpol = cpol;
    spip->cpha = cpha;
    spip->channel = channel;
}

static int
genericSPIBusyWait(struct genericSPI *spip)
{
    // Wait up to 1 ms for transaction to complete
    int pass = 0;
    while (genericSPIIsBusy(spip)) {
        if (++pass >= 100) {
            return -1;
        }

        microsecondSpin(10);
    }

    return 0;
}

static int
genericSPITransaction(struct genericSPI *spip, uint32_t value)
{
    int bytes = spip->wordSize24? 3 : 2;
    uint32_t mask = ((1 << (bytes*8)) - 1);
    uint32_t v = value & mask;

    if (spip->inProgress) {
        return -1;
    }

    // SPI module options
    v |= (spip->wordSize24? SPI_W_24_BIT_OP: 0) |
         (spip->lsbFirst? SPI_W_LSB_FIRST: 0) |
         (spip->cpol? SPI_W_CPOL: 0) |
         (spip->cpha? SPI_W_CPHA: 0) |
         ((spip->channel << SPI_DEVSEL_SHIFT) & SPI_DEVSEL_MASK);

    GPIO_WRITE(spip->gpioIdx, v);
    return 0;
}

int
genericSPIWrite(struct genericSPI* spip, uint32_t value)
{
    int status = 0;

    status = genericSPIBusyWait(spip);
    if (status < 0) {
        return status;
    }

    status = genericSPITransaction(spip, value);
    if (status < 0) {
        return status;
    }

    // Number of bytes written
    return spip->wordSize24? 3 : 2;
}

int
genericSPIRead(struct genericSPI* spip, uint32_t value, uint32_t *buf)
{
    int status = 0;

    status = genericSPIBusyWait(spip);
    if (status < 0) {
        return status;
    }

    status = genericSPITransaction(spip, value);
    if (status < 0) {
        return status;
    }

    status = genericSPIBusyWait(spip);
    if (status < 0) {
        return status;
    }

    *buf = GPIO_READ(spip->gpioIdx) & 0x00FFFFFF;

    // Number of bytes read
    return spip->wordSize24? 3 : 2;
}

int
genericSPIReadAsync(struct genericSPI* spip, uint32_t value)
{
    int status = 0;

    status = genericSPIBusyWait(spip);
    if (status < 0) {
        return status;
    }

    status = genericSPITransaction(spip, value);
    if (status < 0) {
        return status;
    }

    spip->inProgress = 1;

    return 0;
}

int
genericSPITryRead(struct genericSPI* spip, uint32_t *buf)
{
    if (genericSPIIsBusy(spip)) {
        return -1;
    }

    spip->inProgress = 0;

    *buf = GPIO_READ(spip->gpioIdx) & 0x00FFFFFF;

    // Number of bytes read
    return spip->wordSize24? 3 : 2;
}
