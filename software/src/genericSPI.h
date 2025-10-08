/*
 * Generic SPI bit definitions
 */

#ifndef _GENERIC_SPI_H_
#define _GENERIC_SPI_H_

#include <stdint.h>
#include <xparameters.h>
#include <limits.h>

#define SPI_DEVSEL_SHIFT    24
#define SPI_DEVSEL_MASK     0x07000000

#define SPI_W_24_BIT_OP     0x80000000
#define SPI_W_LSB_FIRST     0x40000000

#define SPI_R_BUSY          0x80000000

struct genericSPI {
    uint32_t gpioIdx;
    uint8_t lsbFirst;
    uint8_t channel;
    uint8_t wordSize24;
    uint8_t inProgress;
};

void genericSPISetOptions(struct genericSPI *spip, int wordSize24,
        int lsbFirst, int channel);
int genericSPIIsBusy(struct genericSPI* spip);
int genericSPIWrite(struct genericSPI* spip, uint32_t value);
int genericSPIRead(struct genericSPI* spip, uint32_t value, uint32_t *buf);

int genericSPIReadAsync(struct genericSPI* spip, uint32_t value);
int genericSPITryRead(struct genericSPI* spip, uint32_t *buf);

#endif /* _AFE_SPI_H_ */
