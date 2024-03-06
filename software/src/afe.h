/*
 * Communicate with analog front end SPI components
 */

#ifndef _AFE_SPI_H_
#define _AFE_SPI_H_


void afeInit(void);
int afeGetSerialNumber(void);
void afeAttenSet(unsigned int bpm, unsigned int channel, unsigned int mdB);
unsigned int afeAttenGet(unsigned int bpm, unsigned int channel);
void afeADCrestart(void);
int afeFetchADCextents(uint32_t *buf);

#endif /* _AFE_SPI_H_ */
