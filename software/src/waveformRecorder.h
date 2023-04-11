/*
 * Waveform recorders
 */

#ifndef _WAVEFORMRECORDER_H_
#define _WAVEFORMRECORDER_H_

#include <lwip/pbuf.h>
#include "dsbpmProtocol.h"

void wfrInit(void);

int waveformRecorderCommand(unsigned int bpm, int waveformCommand, int recorderIndex,
        epicsUInt32 val, uint32_t reply[], int capacity);

struct pbuf *wfrAckPacket(struct dsbpmWaveformAck *ackp);
struct pbuf *wfrCheckForWork(void);
int wfrStatus(int dsbpm);

#endif
