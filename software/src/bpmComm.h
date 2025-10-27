/*
 * BPM/cell controller communication
 */

#ifndef _BPMCOMM_H_
#define _BPMCOMM_H_

#define BPMCOMM_CSR_FOFB_INDEX_MASK    0x1FF0000
#define BPMCOMM_CSR_FOFB_INDEX_SHIFT   16
#define BPMCOMM_CSR_FOFB_INDEX_VALID   0x2000000
#define BPMCOMM_CSR_FOFB_INDEX_ENABLE  0x4000000

void bpmCommSetFOFB(unsigned int bpm, int fofbIndex);
int bpmCommGetFOFB(unsigned int bpm);

#endif
