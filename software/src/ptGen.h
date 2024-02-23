/*
 * Manipulate DAC tables
 */

#ifndef _PT_GEN_H_
#define _PT_GEN_H_

#define PT_GEN_TABLE_EEPROM_NAME "ptGen.csv"

int ptGenSetTable(unsigned char *buf, int size);
int ptGenGetTable(unsigned char *buf);
void ptGenCommit(unsigned int bpm);
void ptGenCommitAll(void);
void ptGenInit(unsigned int bpm);
int ptGenFetchEEPROM(void);
int ptGenStashEEPROM(void);

#endif
