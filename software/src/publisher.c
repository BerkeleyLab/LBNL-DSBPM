/*
 * Publish monitor values
 */
#include <stdio.h>
#include <string.h>
#include <lwip/udp.h>
#include "autotrim.h"
#include "afe.h"
#include "ami.h"
#include "platform_config.h"
#include "dsbpmProtocol.h"
#include "cellComm.h"
#include "publisher.h"
#include "evr.h"
#include "gpio.h"
#include "localOscillator.h"
#include "systemParameters.h"
#include "ptGen.h"
#include "util.h"
#include "rfdc.h"
#include "waveformRecorder.h"
#include "bpmComm.h"

#define MAX_ADC_CHANNELS_PER_CHAIN (DSBPM_PROTOCOL_ADC_COUNT/CFG_DSBPM_COUNT)
#define MAX_DAC_CHANNELS_PER_CHAIN (DSBPM_PROTOCOL_DAC_COUNT/CFG_DSBPM_COUNT)

#define REG(base,chan)  ((base) + (GPIO_IDX_PER_DSBPM * (chan)))

static struct udp_pcb *pcb;
static ip_addr_t  subscriberAddr;
static u16_t      subscriberPort;

/*
 * Send values to subscriber
 */
static void
publishSlowAcquisition(unsigned int saSeconds, unsigned int saFraction)
{
    int i;
    int adcChannel, dacChannel, chainNumber;
    struct pbuf *p;
    struct dsbpmSlowAcquisition *pk;
    static epicsUInt32 packetNumber = 1;
    uint32_t r;
    p = pbuf_alloc(PBUF_TRANSPORT, sizeof *pk, PBUF_RAM);
    if (p == NULL) {
        printf("Can't allocate pbuf for slow data\n");
        return;
    }
    pk = (struct dsbpmSlowAcquisition *)p->payload;
    pk->packetNumber = packetNumber++;
    pk->seconds = saSeconds;
    pk->fraction = saFraction;
    pk->magic = DSBPM_PROTOCOL_MAGIC_SLOW_ACQUISITION;
    for (i = 0 ; i < DSBPM_PROTOCOL_DSP_COUNT ; i++) {
        chainNumber = i;
        pk->xPos[i] = GPIO_READ(REG(GPIO_IDX_POSITION_CALC_SA_X, chainNumber));
        pk->yPos[i] = GPIO_READ(REG(GPIO_IDX_POSITION_CALC_SA_Y, chainNumber));
        pk->skew[i] = GPIO_READ(REG(GPIO_IDX_POSITION_CALC_SA_Q, chainNumber));
        pk->buttonSum[i] = GPIO_READ(REG(GPIO_IDX_POSITION_CALC_SA_S, chainNumber));
        pk->xRMSwide[i] = GPIO_READ(REG(GPIO_IDX_RMS_X_WIDE, chainNumber));
        pk->yRMSwide[i] = GPIO_READ(REG(GPIO_IDX_RMS_Y_WIDE, chainNumber));
        pk->xRMSnarrow[i] = GPIO_READ(REG(GPIO_IDX_RMS_X_NARROW, chainNumber));
        pk->yRMSnarrow[i] = GPIO_READ(REG(GPIO_IDX_RMS_Y_NARROW, chainNumber));
        pk->lossOfBeamStatus[i] = GPIO_READ(REG(GPIO_IDX_LOSS_OF_BEAM_TRIGGER, chainNumber));
        pk->prelimProcStatus[i] = GPIO_READ(REG(GPIO_IDX_PRELIM_STATUS, chainNumber));
        pk->recorderStatus[i] = wfrStatus(i);
        pk->autotrimStatus[i] = autotrimStatus(i);
        pk->sdSyncStatus[i] = localOscGetSdSyncStatus(i);
        pk->cellCommStatus[i] = 0;
        pk->clockStatus[i] = GPIO_READ(REG(GPIO_IDX_CLOCK_STATUS, chainNumber));
    }
    pk->clipStatus = rfADCstatus();
    for (i = 0 ; i < DSBPM_PROTOCOL_ADC_COUNT ; i++) {
        adcChannel = i % MAX_ADC_CHANNELS_PER_CHAIN;
        chainNumber = i / MAX_ADC_CHANNELS_PER_CHAIN;
        pk->rfMag[i] = GPIO_READ(REG(GPIO_IDX_PRELIM_RF_MAG_0 +
                adcChannel, chainNumber));
        pk->ptLoMag[i] = GPIO_READ(REG(GPIO_IDX_PRELIM_PT_LO_MAG_0 +
                adcChannel, chainNumber));
        pk->ptHiMag[i] = GPIO_READ(REG(GPIO_IDX_PRELIM_PT_HI_MAG_0 +
                adcChannel, chainNumber));
        pk->gainFactor[i] = GPIO_READ(REG(GPIO_IDX_ADC_GAIN_FACTOR_0 +
                adcChannel, chainNumber));
        pk->calibRFFactor[i] = GPIO_READ(REG(GPIO_IDX_RF_GAIN_FACTOR_0 +
                adcChannel, chainNumber));
        pk->calibPLFactor[i] = GPIO_READ(REG(GPIO_IDX_PL_GAIN_FACTOR_0 +
                adcChannel, chainNumber));
        pk->calibPHFactor[i] = GPIO_READ(REG(GPIO_IDX_PH_GAIN_FACTOR_0 +
                adcChannel, chainNumber));
        pk->rfADCDSA[i] = rfADCGetDSADSBPM(chainNumber, adcChannel);
        pk->afeAtt[i] = amiAfeAttenGet(chainNumber, adcChannel);
    }

    for (i = 0 ; i < DSBPM_PROTOCOL_DAC_COUNT ; i++) {
        dacChannel = i % MAX_DAC_CHANNELS_PER_CHAIN;
        chainNumber = i / MAX_DAC_CHANNELS_PER_CHAIN;
        pk->dacCurrent[i] = rfDACGetVOPDSBPM(chainNumber, dacChannel);
        pk->dacCtl[i] = isPtGenRun(chainNumber);
        pk->ptmAtt[i] = amiPtmAttenGet(chainNumber);
    }


    r = 0;
    pk->adcPeak[0] = r;
    pk->adcPeak[1] = r >> 16;
    r = 0;
    pk->adcPeak[2] = r;
    pk->adcPeak[3] = r >> 16;
    udp_sendto(pcb, p, &subscriberAddr, subscriberPort);
    pbuf_free(p);
}

/*
 * Publish when appropriate
 */
void
publisherCheck(void)
{
    struct pbuf *p;
    unsigned int saSeconds;
    unsigned int saFraction;
    static unsigned int previousSaSeconds, previousSaFraction;

    /*
     * Wait for SA time stamp to stabilize
     */
    saFraction = GPIO_READ(GPIO_IDX_SA_TIMESTAMP_FRACTION);
    for (;;) {
        unsigned int checkFraction;
        saSeconds = GPIO_READ(GPIO_IDX_SA_TIMESTAMP_SEC);
        checkFraction = GPIO_READ(GPIO_IDX_SA_TIMESTAMP_FRACTION);
        if (checkFraction == saFraction) break;
        saFraction = checkFraction;
    }
    if (subscriberPort == 0) {
        previousSaSeconds = saSeconds;
        previousSaFraction = saFraction;
    }
    else {
        if ((saFraction != previousSaFraction) || (saSeconds != previousSaSeconds)) {
            int evrTickDiff = (saFraction - previousSaFraction) / 4.294967296 +
                                ((saSeconds-previousSaSeconds) * 1e9);
            unsigned int sysMicroseconds = MICROSECONDS_SINCE_BOOT();
            static int sysMicrosecondsOld, evrTickDiffOld, sysTickDiffOld;
            int sysTickDiff = (sysMicroseconds - sysMicrosecondsOld) *
                ((float) 99999001/1000000);
            if ((debugFlags & DEBUGFLAG_SA_TIMING_CHECK)
             && ((evrTickDiff < 90000000) || (evrTickDiff > 110000000)
              || (sysTickDiff < 9700000) || (sysTickDiff > 10200000))) {
                printf("old:%d:%09d  new:%d:%09d "
                       "evrTickDiff:%d sysTickDiff:%d "
                       "evrTickDiffOld:%d sysTickDiffOld:%d\n",
                                             previousSaSeconds, previousSaFraction,
                                             saSeconds, saFraction,
                                             evrTickDiff, sysTickDiff,
                                             evrTickDiffOld, sysTickDiffOld);
            }
            sysMicrosecondsOld = sysMicroseconds;
            evrTickDiffOld = evrTickDiff;
            sysTickDiffOld = sysTickDiff;
            previousSaSeconds = saSeconds;
            previousSaFraction = saFraction;
            publishSlowAcquisition(saSeconds, saFraction);
        }

        if ((p = wfrCheckForWork()) != NULL) {
            udp_sendto(pcb, p, &subscriberAddr, subscriberPort);
            pbuf_free(p);
        }
    }
}

/*
 * Handle a subscription request
 */
static void
publisher_callback(void *arg, struct udp_pcb *pcb, struct pbuf *p,
                   const ip_addr_t *fromAddr, u16_t fromPort)
{
    int i = 0;
    const char *cp = p->payload;
    static epicsInt16 fofbIndex[CFG_DSBPM_COUNT];
    static int beenHere;

    /*
     * Initialize static with negative values
     */
    if (!beenHere) {
        for (i = 0; i < CFG_DSBPM_COUNT; ++i) {
            fofbIndex[i] = -1000;
        }
        beenHere = 1;
    }

    /*
     * Must copy payload rather than just using payload area
     * since the latter is not aligned on a 32-bit boundary
     * which results in (silently mangled) misaligned accesses.
     */
    if (debugFlags & DEBUGFLAG_PUBLISHER) {
        long addr = ntohl(fromAddr->addr);
        printf("publisher_callback: %d (%x) from %d.%d.%d.%d:%d\n",
                                                p->len,
                                                p->len >= 1 ? (*cp & 0xFF) : 0,
                                                (int)((addr >> 24) & 0xFF),
                                                (int)((addr >> 16) & 0xFF),
                                                (int)((addr >>  8) & 0xFF),
                                                (int)((addr      ) & 0xFF),
                                                fromPort);
    }
    if (p->len == sizeof fofbIndex) {
        epicsInt16 newIndex[CFG_DSBPM_COUNT];
        memcpy(&newIndex, p->payload, sizeof newIndex);

        for (i = 0; i < CFG_DSBPM_COUNT; ++i) {
            if (newIndex[i] != fofbIndex[i]) {
                fofbIndex[i] = newIndex[i];
                bpmCommSetFOFB(i, fofbIndex[i]);
            }
        }
        subscriberAddr = *fromAddr;
        subscriberPort = fromPort;
    }
    else if (subscriberPort && (p->len == sizeof(struct dsbpmWaveformAck))) {
        struct dsbpmWaveformAck dsbpmAck;
        struct pbuf *txPacket;
        memcpy(&dsbpmAck, p->payload, sizeof dsbpmAck);
        txPacket = wfrAckPacket(&dsbpmAck);
        if (txPacket) {
            udp_sendto(pcb, txPacket, &subscriberAddr, subscriberPort);
            pbuf_free(txPacket);
        }
    }
    pbuf_free(p);
}

/*
 * Set up publisher UDP port
 */
void
publisherInit(void)
{
    int err;

    pcb = udp_new();
    if (pcb == NULL) {
        fatal("Can't create publisher pcb\n");
        return;
    }
    err = udp_bind(pcb, IP_ADDR_ANY, DSBPM_PROTOCOL_PUBLISHER_UDP_PORT);
    if (err != ERR_OK) {
        fatal("Can't bind to publisher port, error:%d", err);
        return;
    }
    udp_recv(pcb, publisher_callback, NULL);
}
