/*
 * Per-application EPICS support
 */

#include <stdio.h>
#include <string.h>
#include "adcProcessing.h"
#include "afe.h"
#include "platform_config.h"
#include "dsbpmProtocol.h"
#include "lossOfBeam.h"
#include "localOscillator.h"
#include "epicsApplicationCommands.h"
#include "evr.h"
#include "gpio.h"
#include "util.h"
#include "ptGen.h"
#include "autotrim.h"
#include "calibrationGains.h"
#include "rfdc.h"
#include "waveformRecorder.h"

int
epicsApplicationCommand(int commandArgCount, struct dsbpmPacket *cmdp,
                                             struct dsbpmPacket *replyp)
{
    int lo = cmdp->command & DSBPM_PROTOCOL_CMD_MASK_LO;
    int idx = cmdp->command & DSBPM_PROTOCOL_CMD_MASK_IDX;
    int replyArgCount = 0;

    switch (cmdp->command & DSBPM_PROTOCOL_CMD_MASK_HI) {
    case DSBPM_PROTOCOL_CMD_HI_LONGOUT:
        if (commandArgCount != 1) return -1;
        switch (lo) {
        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_RMS_THRSH:
            adcProcessingRMSThrs(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_LOB_THRSH:
            lossOfBeamThreshold(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_TBT_SUM_SHIFT:
            sdAccumulateSetTbtSumShift(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_MT_SUM_SHIFT:
            sdAccumulateSetMtSumShift(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_BUTTON_DSP:
            localOscSetDspAlgorithm(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_AUTOTRIM_CTL:
            autotrimEnable(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_AUTOTRIM_THRS:
            autotrimSetThreshold(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_AUTOTRIM_FILT_SHFT:
            autotrimSetFilterShift(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_TRIM:
            autotrimSetStaticGains(idx / CFG_ADC_PER_BPM_COUNT,
                    idx % CFG_ADC_PER_BPM_COUNT, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_DSA:
            rfADCSetDSADSBPM(idx / CFG_ADC_PER_BPM_COUNT,
                    idx % CFG_ADC_PER_BPM_COUNT, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_AFE_ATT:
            afeAttenSet(idx / CFG_ADC_PER_BPM_COUNT,
                    idx % CFG_ADC_PER_BPM_COUNT, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_DAC_CURRENT:
            rfDACSetVOPDSBPM(idx / CFG_DAC_PER_BPM_COUNT,
                    idx % CFG_DAC_PER_BPM_COUNT, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_DAC_CTL:
            unsigned int bpm = idx / CFG_DAC_PER_BPM_COUNT;
            unsigned int dac = idx % CFG_DAC_PER_BPM_COUNT;

            // Invalid DAC channel
            if (dac != 0)
                return -1;

            ptGenRun(bpm, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_RF_GAINS:
            cgSetStaticRFGains(idx / CFG_ADC_PER_BPM_COUNT,
                    idx % CFG_ADC_PER_BPM_COUNT, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_PL_GAINS:
            cgSetStaticPLGains(idx / CFG_ADC_PER_BPM_COUNT,
                    idx % CFG_ADC_PER_BPM_COUNT, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_PH_GAINS:
            cgSetStaticPHGains(idx / CFG_ADC_PER_BPM_COUNT,
                    idx % CFG_ADC_PER_BPM_COUNT, cmdp->args[0]);
            break;

        default: return -1;
        }
        break;

    case DSBPM_PROTOCOL_CMD_HI_RECORDERS:
        replyArgCount = waveformRecorderCommand(lo, idx,
                cmdp->args[0], replyp->args, DSBPM_PROTOCOL_ARG_CAPACITY);
        break;

    default: return -1;
    }
    return replyArgCount;
}
