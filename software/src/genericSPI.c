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

gspiErr
genericSPIIsBusy(struct genericSPI* spip)
{
    return (GPIO_READ(spip->gpioIdx) & SPI_R_BUSY)? GSPI_EAGAIN : GSPI_SUCCESS;
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

static gspiErr
genericSPIBusyWait(struct genericSPI *spip)
{
    // Wait up to 1 ms for transaction to complete
    int pass = 0;
    while (genericSPIIsBusy(spip)) {
        if (++pass >= 100) {
            return GSPI_EAGAIN;
        }

        microsecondSpin(10);
    }

    return GSPI_SUCCESS;
}

static gspiErr
genericSPITransaction(struct genericSPI *spip, uint32_t value)
{
    int bytes = spip->wordSize24? 3 : 2;
    uint32_t mask = ((1 << (bytes*8)) - 1);
    uint32_t v = value & mask;

    if (spip->inProgress) {
        return GSPI_EINPROGRESS;
    }

    // SPI module options
    v |= (spip->wordSize24? SPI_W_24_BIT_OP: 0) |
         (spip->lsbFirst? SPI_W_LSB_FIRST: 0) |
         (spip->cpol? SPI_W_CPOL: 0) |
         (spip->cpha? SPI_W_CPHA: 0) |
         ((spip->channel << SPI_DEVSEL_SHIFT) & SPI_DEVSEL_MASK);

    GPIO_WRITE(spip->gpioIdx, v);
    return GSPI_SUCCESS;
}

gspiErr
genericSPIWrite(struct genericSPI* spip, uint32_t value)
{
    gspiErr status = GSPI_SUCCESS;

    status = genericSPIBusyWait(spip);
    if (status != GSPI_SUCCESS) {
        return status;
    }

    status = genericSPITransaction(spip, value);
    if (status != GSPI_SUCCESS) {
        return status;
    }

    return GSPI_SUCCESS;
}

gspiErr
genericSPIRead(struct genericSPI* spip, uint32_t value, uint32_t *buf)
{
    gspiErr status = GSPI_SUCCESS;

    status = genericSPIBusyWait(spip);
    if (status != GSPI_SUCCESS) {
        return status;
    }

    status = genericSPITransaction(spip, value);
    if (status != GSPI_SUCCESS) {
        return status;
    }

    status = genericSPIBusyWait(spip);
    if (status != GSPI_SUCCESS) {
        return status;
    }

    *buf = GPIO_READ(spip->gpioIdx) & 0x00FFFFFF;

    // Number of bytes read
    return GSPI_SUCCESS;
}

/*
 * Try to start a transaction. Can fail with:
 *   GSPI_EAGAIN if SPI is not ready
 *   GSPI_EINPROGRESS if SPI already has a transaction in progress
 */
gspiErr
genericSPITryStartTransaction(struct genericSPI* spip, uint32_t value)
{
    gspiErr status = GSPI_SUCCESS;

    status = genericSPIIsBusy(spip);
    if (status != GSPI_SUCCESS) {
        return status;
    }

    status = genericSPITransaction(spip, value);
    if (status != GSPI_SUCCESS) {
        return status;
    }

    spip->inProgress = 1;
    return GSPI_SUCCESS;
}

/*
 * Try to read SPI result. Can fail with:
 *   GSPI_EAGAIN if SPI is not ready
 */
gspiErr
genericSPITryRead(struct genericSPI *spip, uint32_t *buf)
{
    gspiErr status = GSPI_SUCCESS;

    status = genericSPIIsBusy(spip);
    if (status != GSPI_SUCCESS) {
        return status;
    }

    spip->inProgress = 0;
    *buf = GPIO_READ(spip->gpioIdx) & 0x00FFFFFF;

    return GSPI_SUCCESS;
}
