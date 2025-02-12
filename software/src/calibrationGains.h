/*
 * Calibration gains support
 */

#ifndef _CALIB_GAINS_H_
#define _CALIB_GAINS_H_

void cgSetStaticRFGains(unsigned int bpm, unsigned int channel, int gain);
void cgSetStaticPLGains(unsigned int bpm, unsigned int channel, int gain);
void cgSetStaticPHGains(unsigned int bpm, unsigned int channel, int gain);

#endif
