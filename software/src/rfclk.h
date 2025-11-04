/*
 * RF clock generation components
 */
#ifndef _RFCLK_H_
#define _RFCLK_H_

#define LMK04XX_TABLE_EEPROM_NAME           "lmk04xx.csv"
#define LMX2594_ADC_TABLE_EEPROM_NAME       "lmxADC.csv"
#define LMX2594_DAC_TABLE_EEPROM_NAME       "lmxDAC.csv"

void rfClkPreInit(void);
void rfClkInit(void);
void rfClkShow(void);

void lmk04xxConfig(const uint32_t *values, int n);
void lmx2594ADCConfig(const uint32_t *values, int n);
void lmx2594DACConfig(const uint32_t *values, int n);
void lmx2594ConfigAllSame(const uint32_t *values, int n);
int lmx2594Readback(unsigned int index, uint32_t *values, int capacity);
int lmx2594ReadbackFirst(uint32_t *values, int capacity);
int lmx2594Status(void);

int rfClkFetchLMK04xxEEPROM(void);
int rfClkFetchLMX2594ADCEEPROM(void);
int rfClkFetchLMX2594DACEEPROM(void);
int rfClkStashLMK04xxEEPROM(void);
int rfClkStashLMX2594ADCEEPROM(void);
int rfClkStashLMX2594DACEEPROM(void);
void rfClkLMK04xxCommit(void);
void rfClkLMX2594ADCCommit(void);
void rfClkLMX2594DACCommit(void);
void rfClkLMK04xxDefaults(void);
void rfClkLMX2594ADCDefaults(void);
void rfClkLMX2594DACDefaults(void);

#endif  /* _RFCLK_H_ */
