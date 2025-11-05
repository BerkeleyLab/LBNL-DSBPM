/*
 * Communicate with the Analog Module Interface SPI components
 */

#ifndef _RPB_SPI_H_
#define _RPB_SPI_H_

#include <stdint.h>

#define RPB_SPI_INDEX_INA239            0

#define RPB_INA239_INDEX_SHUNT_CAL      0
#define RPB_INA239_INDEX_V_SHUNT        1
#define RPB_INA239_INDEX_V_BUS          2
#define RPB_INA239_INDEX_DIETEMP        3
#define RPB_INA239_INDEX_CURRENT        4
#define RPB_INA239_INDEX_MFR            5
#define RPB_INA239_INDEX_DEVID          6

#define RPB_INA239_MFR                  0x5449
#define RPB_INA239_DEVID                0x2391

#define RPB_NUM_PS_SENSORS              1

void rpbInit(void);

int rpbIna239MfrIdGet(unsigned int channel);
int rpbIna239DevIdGet(unsigned int channel);

int rpbFetch(uint32_t *args);
void rpbCrank(void);
void rpbPSinfoDisplay(void);

#endif /* _RPB_SPI_H_ */
