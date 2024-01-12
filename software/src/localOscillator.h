/*
 * Manipulate local oscillator tables
 */

#ifndef _LOCAL_OSC_H_
#define _LOCAL_OSC_H_

#define RF_TABLE_EEPROM_NAME "rfTable.csv"
#define PT_TABLE_EEPROM_NAME "ptTable.csv"

int localOscGetRfTable(unsigned char *buf, int capacity);
int localOscSetRfTable(unsigned char *buf, int size);
int localOscGetPtTable(unsigned char *buf, int capacity);
int localOscSetPtTable(unsigned char *buf, int size);
void localOscRfCommit(unsigned int bpm);
void localOscPtCommit(unsigned int bpm);
void localOscRfCommitAll(void);
void localOscPtCommitAll(void);
int localOscGetDspAlgorithm(unsigned int bpm);
void localOscSetDspAlgorithm(unsigned int bpm, int useRMS);
int localOscGetSdSyncStatus(unsigned int bpm);

void localOscillatorInit(unsigned int bpm);

void sdAccumulateSetTbtSumShift(unsigned int bpm, int shift);
void sdAccumulateSetMtSumShift(unsigned int bpm, int shift);
void sdAccumulateSetFaSumShift(unsigned int bpm, int shift);

int localOscillatorFetchEEPROM(int isPt);
int localOscillatorFetchRfEEPROM(void);
int localOscillatorFetchPtEEPROM(void);
int localOscillatorStashEEPROM(int isPt);
int localOscillatorStashRfEEPROM(void);
int localOscillatorStashPtEEPROM(void);

#endif
