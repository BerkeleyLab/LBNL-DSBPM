/*
 * RF Analog to Digital Data Conversion
 */
#ifndef _RFDC_H_
#define _RFDC_H_

typedef enum rfDCType {
    RFDC_ADC = 0x1,
    RFDC_DAC = 0x2,
} rfDCType;

void rfDCinit(void);
void rfDCsync(void);
void rfDCsyncType(int type);
void rfADCrestart(void);
void rfADCshow(void);
int rfADClinkCouplingIsAC(void);

void rfADCfreezeCalibration(int channel, int freeze);
void rfADCfreezeCalibrationBPM(unsigned int bpm, int channel, int freeze);

unsigned int rfADCGetStatus(int channel);
unsigned int rfADCGetStatusBPM(unsigned int bpm, int channel);
unsigned int rfADCstatus(void);

float rfADCGetDSA(int channel);
void rfADCSetDSA(int channel, float att);
void rfADCSetDSADSBPM(unsigned int bpm, int channel, int mDbAtt);
int rfADCGetDSADSBPM(unsigned int bpm, int channel);

int rfDACGetVOP(int channel);
void rfDACSetVOP(int channel, unsigned int ucurrent);
int rfDACGetVOPDSBPM(unsigned int bpm, int channel);
void rfDACSetVOPDSBPM(unsigned int bpm, int channel, unsigned int ucurrent);

void rfDACrestart(void);
void rfDACshow(void);

#endif  /* _RFADC_H_ */
