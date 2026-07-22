/*
 * BPM/cell controller communication
 */

#ifndef _BPMCOMM_H_
#define _BPMCOMM_H_

#include "reg_macros.h"

#define BPMCOMM_CSR_FOFB_INDEX_SIZE                 9
#define BPMCOMM_CSR_FOFB_INDEX_SHIFT                16
#define BPMCOMM_CSR_FOFB_INDEX_MASK                 REG_GEN_MASK(BPMCOMM_CSR_FOFB_INDEX_SHIFT, \
                                                            BPMCOMM_CSR_FOFB_INDEX_SIZE)
#define BPMCOMM_CSR_FOFB_INDEX_R(reg)               REG_GEN_READ(reg, BPMCOMM_CSR_FOFB_INDEX_SHIFT, \
                                                            BPMCOMM_CSR_FOFB_INDEX_SIZE)
#define BPMCOMM_CSR_FOFB_INDEX_W(value)             REG_GEN_WRITE(value, BPMCOMM_CSR_FOFB_INDEX_SHIFT, \
                                                            BPMCOMM_CSR_FOFB_INDEX_SIZE)

#define BPMCOMM_CSR_FOFB_INDEX_VALID_SIZE           1
#define BPMCOMM_CSR_FOFB_INDEX_VALID_SHIFT          25
#define BPMCOMM_CSR_FOFB_INDEX_VALID_MASK           REG_GEN_MASK(BPMCOMM_CSR_FOFB_INDEX_VALID_SHIFT, \
                                                      BPMCOMM_CSR_FOFB_INDEX_VALID_SIZE)
#define BPMCOMM_CSR_FOFB_INDEX_VALID                BPMCOMM_CSR_FOFB_INDEX_VALID_MASK

#define BPMCOMM_CSR_FOFB_INDEX_ENABLE_SIZE          1
#define BPMCOMM_CSR_FOFB_INDEX_ENABLE_SHIFT         26
#define BPMCOMM_CSR_FOFB_INDEX_ENABLE_MASK          REG_GEN_MASK(BPMCOMM_CSR_FOFB_INDEX_ENABLE_SHIFT, \
                                                     BPMCOMM_CSR_FOFB_INDEX_ENABLE_SIZE)
#define BPMCOMM_CSR_FOFB_INDEX_ENABLE               BPMCOMM_CSR_FOFB_INDEX_ENABLE_MASK

void bpmCommSetFOFB(unsigned int bpm, int fofbIndex);
int bpmCommGetFOFB(unsigned int bpm);

#endif
