/*
 * Waveform recorders
 */

#ifndef _WAVEFORMRECORDER_H_
#define _WAVEFORMRECORDER_H_

#include <lwip/pbuf.h>
#include "dsbpmProtocol.h"

void wfrInit(unsigned int bpm);

int waveformRecorderCommand(unsigned int bpm, int waveformCommand, unsigned int recorder,
        epicsUInt32 val, uint32_t reply[], int capacity);

struct pbuf *wfrAckPacket(struct dsbpmWaveformAck *ackp);
struct pbuf *wfrCheckForWork(void);
int wfrStatus(unsigned int bpm);

#endif
