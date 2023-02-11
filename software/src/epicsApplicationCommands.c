/*
 * Per-application EPICS support
 */

#include <stdio.h>
#include <string.h>
#include "platform_config.h"
#include "dsbpmProtocol.h"
#include "acquisition.h"
#include "lossOfBeam.h"
#include "localOscillator.h"
#include "epicsApplicationCommands.h"
#include "evr.h"
#include "gpio.h"
#include "util.h"
#include "autotrim.h"

/*
 * Set the acquisition trigger events
 */
static void
selectTriggerEventAction(int eventNumber, unsigned int idx, int action)
{
    static unsigned char oldEventNumber[2];

    if (idx >= (sizeof oldEventNumber / sizeof oldEventNumber[0])) {
        return;
    }
    if (oldEventNumber[idx]) {
        evrRemoveEventAction(oldEventNumber[idx], action);
        oldEventNumber[idx] = 0;
    }
    if ((eventNumber > 0) && (eventNumber < 255)) {
        evrAddEventAction(eventNumber, action);
        oldEventNumber[idx] = eventNumber;
    }
}

int
epicsApplicationCommand(int commandArgCount, struct dsbpmPacket *cmdp,
                                             struct dsbpmPacket *replyp)
{
    int lo = cmdp->command & DSBPM_PROTOCOL_CMD_MASK_LO;
    int idx = cmdp->command & DSBPM_PROTOCOL_CMD_MASK_IDX;
    int replyArgCount = 0;

    switch (cmdp->command & DSBPM_PROTOCOL_CMD_MASK_HI) {
    case DSBPM_PROTOCOL_CMD_HI_LONGIN:
        if (commandArgCount != 0) return -1;
        replyArgCount = 1;
        switch (idx) {
        case DSBPM_PROTOCOL_CMD_LONGIN_IDX_ACQ_STATUS:
            replyArgCount = acquisitionStatus(replyp->args, DSBPM_PROTOCOL_ARG_CAPACITY);
            break;

        default: return -1;
        }
        break;

    case DSBPM_PROTOCOL_CMD_HI_LONGOUT:
        if (commandArgCount != 1) return -1;
        switch (lo) {
        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_NO_VALUE:
            switch (idx) {
            case DSBPM_PROTOCOL_CMD_LONGOUT_NV_IDX_SOFT_TRIGGER:
                GPIO_WRITE(GPIO_IDX_SOFT_TRIGGER, 0);
                break;
            default: return -1;
            }
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_PRETRIGGER_SAMPLES:
            acquisitionSetPretriggerCount(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_INPUT_BONDING:
            acquisitionSetBonding(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_TRIGGER_EDGE:
            acquisitionSetTriggerEdge(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_TRIGGER_LEVEL:
            acquisitionSetTriggerLevel(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_TRIGGER_ENABLES:
            acquisitionSetTriggerEnables(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_REARM:
            acquisitionArm(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_SEGMENTED_MODE:
            acquisitionSetSegmentedMode(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_EARLY_SEGMENT_INTERVAL:
            acquisitionSetEarlySegmentInterval(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_LATER_SEGMENT_INTERVAL:
            acquisitionSetLaterSegmentInterval(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_GENERIC:
            switch (idx) {

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_LOB_THRSH:
                lossOfBeamThreshold(-1, cmdp->args[0]);
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_TBT_SUM_SHIFT:
                 sdAccumulateSetTbtSumShift(cmdp->args[0]);
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_MT_SUM_SHIFT:
                sdAccumulateSetMtSumShift(cmdp->args[0]);
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_BUTTON_DSP:
                localOscSetDspAlgorithm(cmdp->args[0]);
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_AUTOTRIM_CTL:
                 autotrimEnable(0, cmdp->args[0]);
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_AUTOTRIM_THRS:
                autotrimSetThreshold(0, cmdp->args[0]);
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_AUTOTRIM_FILT_SHFT:
                autotrimSetFilterShift(0, cmdp->args[0]);
                break;

            default: return -1;
            }
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_TRIM:
            autotrimSetStaticGains(0, idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_DSA:
            rfADCSetDSADSBPM(0, idx, cmdp->args[0]);
            break;

        default: return -1;
        }
        break;

    case DSBPM_PROTOCOL_CMD_HI_RECORDERS:
        replyArgCount = waveformRecorderCommand(0, lo, idx,
            cmdp->args[0], replyp->args, DSBPM_PROTOCOL_ARG_CAPACITY);
        break;

    default: return -1;
    }
    return replyArgCount;
}
