/*
 * RF Analog to Digital Data Conversion
 */
#ifndef _RFDC_H_
#define _RFDC_H_

void rfADCinit(void);
void rfDCsync(void);
void rfADCrestart(void);
void rfADCfreezeCalibration(int channel, int freeze);
void rfADCshow(void);
unsigned int rfADCstatus(void);
int rfADClinkCouplingIsAC(void);
float rfADCGetDSA(int channel);
void rfADCSetDSA(int channel, float att);
void rfADCSetDSADSBPM(unsigned int bpm, int channel, int mDbAtt);
int rfADCGetDSADSBPM(unsigned int bpm, int channel);

#endif  /* _RFADC_H_ */
