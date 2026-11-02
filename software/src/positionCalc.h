/*
 * Deal with position calculation firmware
 */

#ifndef _POSITIONCALC_H_
#define _POSITIONCALC_H_

enum offsetChannel {
    OFFSET_CHANNEL_X = 0,
    OFFSET_CHANNEL_Y,
    OFFSET_CHANNEL_Q,
    OFFSET_CHANNEL_COUNT,
};

void positionCalcInit(unsigned int bpm);
void positionCalcSetOffset(unsigned int bpm, enum offsetChannel channel, int offset);
int positionCalcGetOffset(unsigned int bpm, enum offsetChannel channel);

#endif
