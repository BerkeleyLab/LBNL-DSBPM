/*
 * I2C devices
 */
#ifndef _IIC_H_
#define _IIC_H_

#include <stdint.h>

// skip SYSMON readout that can get in the way
// of streaming data for the DSBPM target
// #define SYSMON_SKIP_PSINFO

#define IIC_INDEX_TCA6416A_PORT           0
#define IIC_INDEX_INA226_VCCINT           1
#define IIC_INDEX_INA226_VCCINT_IO_BRAM   2
#define IIC_INDEX_INA226_VCC1V8           3
#define IIC_INDEX_INA226_VCC1V2           4
#define IIC_INDEX_INA226_VADJ_FMC         5
#define IIC_INDEX_INA226_MGTAVCC          6
#define IIC_INDEX_INA226_MGT1V2           7
#define IIC_INDEX_INA226_MGT1V8C          8
#define IIC_INDEX_INA226_VCCINT_AMS       9
#define IIC_INDEX_INA226_DAC_AVTT        10
#define IIC_INDEX_INA226_DAC_AVCCAUX     11
#define IIC_INDEX_INA226_ADC_AVCC        12
#define IIC_INDEX_INA226_ADC_AVCCAUX     13
#define IIC_INDEX_INA226_DAC_AVCC        14
#define IIC_INDEX_IR38164_A              15
#define IIC_INDEX_IR38164_B              16
#define IIC_INDEX_IR38164_C              17
#define IIC_INDEX_IR35215                18
#define IIC_INDEX_PLACEHOLDER            19 // don't mess with the IIC order
#define IIC_INDEX_IRPS5401_A             20
#define IIC_INDEX_IRPS5401_B             21
#define IIC_INDEX_SYSMON                 22
#define IIC_INDEX_EEPROM                 23
#define IIC_INDEX_SI5341                 24
#define IIC_INDEX_USER_SI570             25
#define IIC_INDEX_USER_MGT_SI570         26
#define IIC_INDEX_8A34001                27
#define IIC_INDEX_I2C2SPI                28
#define IIC_INDEX_RFMC                   29
#define IIC_INDEX_FMC                    30
#define IIC_INDEX_SYSMON_UNUSED          31
#define IIC_INDEX_SODIMM                 32
#define IIC_INDEX_SFP_3_INFO             33
#define IIC_INDEX_SFP_3_STATUS           34
#define IIC_INDEX_SFP_2_INFO             35
#define IIC_INDEX_SFP_2_STATUS           36
#define IIC_INDEX_SFP_1_INFO             37
#define IIC_INDEX_SFP_1_STATUS           38
#define IIC_INDEX_SFP_0_INFO             39
#define IIC_INDEX_SFP_0_STATUS           40

#define IIC_INDEX_PMBUS_FIRST            IIC_INDEX_IR38164_A
#define IIC_INDEX_PMBUS_LAST             IIC_INDEX_IRPS5401_B
#define IIC_INDEX_PMBUS_12V_MONIT        IIC_INDEX_IRPS5401_A

// AmpsPerVolt (1/Rshunt)
#define INA226_VCCINT_AMPS_PER_VOLT           2000
#define INA226_VCCINT_IO_BRAM_AMPS_PER_VOLT   2000
#define INA226_VCC1V8_AMPS_PER_VOLT           500
#define INA226_VCC1V2_AMPS_PER_VOLT           200
#define INA226_VADJ_FMC_AMPS_PER_VOLT         200
#define INA226_MGTAVCC_AMPS_PER_VOLT          500
#define INA226_MGT1V2_AMPS_PER_VOLT           200
#define INA226_MGT1V8C_AMPS_PER_VOLT          200
#define INA226_VCCINT_AMS_AMPS_PER_VOLT       2000
#define INA226_DAC_AVTT_AMPS_PER_VOLT         200
#define INA226_DAC_AVCCAUX_AMPS_PER_VOLT      200
#define INA226_ADC_AVCC_AMPS_PER_VOLT         200
#define INA226_ADC_AVCCAUX_AMPS_PER_VOLT      200
#define INA226_DAC_AVCC_AMPS_PER_VOLT         200

#define SPI_MUX_2594_A_ADC    0
#define SPI_MUX_2594_B_DAC    1
#define SPI_MUX_04828B        2

#define LMX2594_MUX_SEL_SIZE  2

extern const unsigned int lmx2594MuxSel[];
extern const uint32_t *lmx2594Values[];
extern uint32_t lmx2594Sizes[];

void iicInit(void);
int iicRead(unsigned int deviceIndex, int subAddress, uint8_t *buf, int n);
int iicWrite(unsigned int deviceIndex, const uint8_t *buf, int n);

int eepromRead(int address, void *buf, int n);
int eepromWrite(int address, const void *buf, int n);

int pmbusRead(unsigned int deviceIndex, unsigned int page, int reg);

uint32_t lmk04828Bread(int reg);
int lmk04828Bwrite(uint32_t value);
int lmx2594read(int muxSelect, int reg);
int lmx2594write(int muxSelect, uint32_t value);

int sfpGetStatus(uint32_t *buf);
int sfpGetTemperature(void);
int sfpGetRxPower(void);

#endif  /* _IIC_H_ */
