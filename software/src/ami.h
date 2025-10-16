/*
 * Communicate with the Analog Module Interface SPI components
 */

#ifndef _AMI_SPI_H_
#define _AMI_SPI_H_

#include <stdint.h>

#define AMI_SPI_INDEX_AFE_ATT_ALL       0
#define AMI_SPI_INDEX_AFE_0             1
#define AMI_SPI_INDEX_AFE_1             2
#define AMI_SPI_INDEX_AFE_2             3
#define AMI_SPI_INDEX_AFE_3             4
#define AMI_SPI_INDEX_PTM_0             5

#define AMI_INA239_INDEX_SHUNT_CAL      0
#define AMI_INA239_INDEX_V_SHUNT        1
#define AMI_INA239_INDEX_V_BUS          2
#define AMI_INA239_INDEX_DIETEMP        3
#define AMI_INA239_INDEX_CURRENT        4
#define AMI_INA239_INDEX_MFR            5
#define AMI_INA239_INDEX_DEVID          6

#define AMI_INA239_MFR                  0x5449
#define AMI_INA239_DEVID                0x2391

void amiInit(void);
int amiAfeGetSerialNumber(void);
int amiAfeAttenSet(unsigned int bpm, unsigned int channel, unsigned int mdB);
unsigned int amiAfeAttenGet(unsigned int bpm, unsigned int channel);
int amiPtmAttenSet(unsigned int bpm, unsigned int mdB);
unsigned int amiPtmAttenGet(unsigned int bpm);

int amiIna239MfrIdGet(unsigned int bpm, unsigned int channel);
int amiIna239DevIdGet(unsigned int bpm, unsigned int channel);

int amiFetch(uint32_t *args);
void amiCrank();
void amiPSinfoDisplay(unsigned int bpm);

#endif /* _AMI_SPI_H_ */
