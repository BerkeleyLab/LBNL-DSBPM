/*
 * BPM/cell controller communication
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <xparameters.h>
#include "dsbpmProtocol.h"
#include "bpmComm.h"
#include "gpio.h"
#include "util.h"

#define REG(base,chan)  ((base) + (GPIO_IDX_CELL_COMM_BPM_PER_DSBPM * (chan)))

void
bpmCommSetFOFB(unsigned int bpm, int fofbIndex)
{
    if (bpm >= CFG_DSBPM_COUNT) return;

    uint32_t reg = GPIO_READ(REG(GPIO_IDX_CELL_COMM_BPM_CSR, bpm));

    reg |= BPMCOMM_CSR_FOFB_INDEX_ENABLE;
    if ((fofbIndex >= 0) && (fofbIndex < DSBPM_PROTOCOL_FOFB_CAPACITY))  {
        reg &= ~BPMCOMM_CSR_FOFB_INDEX_MASK;
        reg |= BPMCOMM_CSR_FOFB_INDEX_VALID |
            BPMCOMM_CSR_FOFB_INDEX_W(fofbIndex);
    }

    GPIO_WRITE(REG(GPIO_IDX_CELL_COMM_BPM_CSR, bpm), reg);
}

int
bpmCommGetFOFB(unsigned int bpm)
{
    if (bpm >= CFG_DSBPM_COUNT) return -1;

    uint32_t reg = GPIO_READ(REG(GPIO_IDX_CELL_COMM_BPM_CSR, bpm));

    return BPMCOMM_CSR_FOFB_INDEX_R(reg);
}

int
bpmCommFOFBFetch(uint32_t *args)
{
    int i = 0;
    int shift = 0, count = 0;
    uint32_t v = 0;

    for (i = 0; i < CFG_DSBPM_COUNT; ++i) {
        if (shift > 16) {
            *args++ = v;
            v = 0;
            count++;
            shift = 0;
        }

        v |= bpmCommGetFOFB(i) << shift;
        shift += 16;
    }

    *args = v;

    return count + 1;
}
