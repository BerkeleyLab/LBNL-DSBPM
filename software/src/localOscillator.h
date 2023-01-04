/*
 * Manipulate local oscillator tables
 */

#ifndef _LOCAL_OSC_H_
#define _LOCAL_OSC_H_

#define RF_TABLE_EEPROM_NAME "rfTable.csv"
#define PT_TABLE_EEPROM_NAME "ptTable.csv"

int localOscGetRfTable(unsigned char *buf, int capacity);
int localOscSetRfTable(unsigned char *buf, int size);
void localOscRfReadback(const unsigned char *buf);
int localOscGetPtTable(unsigned char *buf, int capacity);
int localOscSetPtTable(unsigned char *buf, int size);
void localOscPtReadback(const unsigned char *buf);
void localOscRfCommit(void);
void localOscPtCommit(void);
int localOscGetDspAlgorithm(void);
void localOscSetDspAlgorithm(int useRMS);
int localOscGetSdSyncStatus(void);

void localOscillatorInit(void);

void sdAccumulateSetTbtSumShift(int shift);
void sdAccumulateSetMtSumShift(int shift);
void sdAccumulateSetFaSumShift(int shift);

void localOscillatorFetchEEPROM(int isPt);
void localOscillatorFetchRfEEPROM(void);
void localOscillatorFetchPtEEPROM(void);
int localOscillatorStashEEPROM(int isPt);
int localOscillatorStashRfEEPROM(void);
int localOscillatorStashPtEEPROM(void);

#endif
