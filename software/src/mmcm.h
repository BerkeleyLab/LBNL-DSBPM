/*
 * MMCM reconfiguration
 */

#ifndef _MMCM_H_
#define _MMCM_H_

void mmcmInit(void);
void mmcmShow(void);
void mmcmSetRFDCDivClkDivider(int divider);
void mmcmSetRFDCClkMultiplier(int multiplier);
void mmcmSetRFDCClk0Divider(int divider);
void mmcmSetRFDCClk1Divider(int divider);

#endif /* _MMCM_H_ */
