/*
 * Waveform recorders
 */

#include <stdio.h>
#include <string.h>
#include <xil_cache.h>
#include <xparameters.h>
#include "dsbpmProtocol.h"
#include "waveformRecorder.h"
#include "gpio.h"
#include "util.h"
#include "rfadc.h"
#include "memcpy2.h"

/*
 * Read/write CSR bits
 */
#define WR_CSR_TRIGGER_MASK             0xFF000000
#define WR_CSR_EVENT_TRIGGER_7_ENABLE   0x80000000
#define WR_CSR_EVENT_TRIGGER_6_ENABLE   0x40000000
#define WR_CSR_EVENT_TRIGGER_5_ENABLE   0x20000000
#define WR_CSR_EVENT_TRIGGER_4_ENABLE   0x10000000
#define WR_CSR_SOFT_TRIGGER_ENABLE      0x01000000
#define WR_CSR_TEST_ACQUISITION_MODE    0x200
#define WR_CSR_DIAGNOSTIC_MODE          0x100
#define WR_CSR_ARM                      0x1

/*
 * Read-only CSR bits
 */
#define WR_CSR_ACQ_STATE_MASK            0xE
#define WR_CSR_AXI_FIFO_OVERRUN          0x10
#define WR_CSR_AXI_BRESP_MASK            0x60
#define WR_CSR_IS_FULL                   0x80

/*
 * Register offsets
 */
#define WR_REG_OFFSET_CSR                  0
#define WR_REG_OFFSET_PRETRIGGER_COUNT     1
#define WR_REG_OFFSET_ACQUISITION_COUNT    2
#define WR_REG_OFFSET_ADDRESS_LSB_POINTER  3
#define WR_REG_OFFSET_ADDRESS_MSB_POINTER  4
#define WR_REG_OFFSET_TIMESTAMP_SECONDS    5
#define WR_REG_OFFSET_TIMESTAMP_TICKS      6


/*
 * Handy macros
 */
#define WR_READ(rp,r)     GPIO_READ((rp)->regBase+(r))
#define WR_WRITE(rp,r,v)  GPIO_WRITE((rp)->regBase+(r),(v))
#define isArmed(rp)       (WR_READ(rp, WR_REG_OFFSET_CSR) & WR_CSR_ARM)

/*
 * Communication with IOC
 */
#define TIMEOUT_US      1000000 // 1s
#define RETRY_LIMIT     10

/*
 * Information for a single recorder
 */
struct recorder {
    enum { CS_IDLE, CS_HEADER, CS_ACTIVE } commState;
    char           *acqBuf;
    unsigned int    acqByteCapacity;
    unsigned int    acqSampleCapacity;
    unsigned int    regBase;
    unsigned int    csrModeBits;
    unsigned int    bytesPerSample;
    unsigned int    triggerMask;
    unsigned int    pretrigCount;
    unsigned int    acqCount;
    unsigned int    maxPretrigger;
    unsigned int    dsbpmNumber;
    unsigned int    recorderNumber;
    unsigned int    waveformNumber;
    unsigned int    startByteOffset;
    unsigned int    bytesLeft;
    unsigned int    bytesInPreviousPacket;
    uint32_t        sysUsAtPreviousPacket;
    unsigned int    retryCount;
    int             txBlock;
};
static struct recorder recorder[DSBPM_PROTOCOL_DSP_COUNT][DSBPM_PROTOCOL_RECORDER_COUNT];

static void
showWfrReg(const char *msg, int r)
{
    if (msg)
        printf("%6s: ", msg);
    printf("%4.4X:%4.4X %11d\n", (r >> 16) & 0xFFFF, r & 0xFFFF, r);
}

static void
showRec(struct recorder *rp)
{
    printf("Recorder %d:%d:\n", rp->dsbpmNumber, rp->recorderNumber);
    showWfrReg("CSR", WR_READ(rp, WR_REG_OFFSET_CSR));
    showWfrReg("Pre", WR_READ(rp, WR_REG_OFFSET_PRETRIGGER_COUNT));
    showWfrReg("Acq", WR_READ(rp, WR_REG_OFFSET_ACQUISITION_COUNT));
    showWfrReg("LSB Addr",WR_READ(rp, WR_REG_OFFSET_ADDRESS_LSB_POINTER));
    showWfrReg("MSD Addr",WR_READ(rp, WR_REG_OFFSET_ADDRESS_MSB_POINTER));
    showWfrReg("Sec", WR_READ(rp, WR_REG_OFFSET_TIMESTAMP_SECONDS));
    showWfrReg("Tick",WR_READ(rp, WR_REG_OFFSET_TIMESTAMP_TICKS));
}

static void
wrWrite(struct recorder *rp, int regOffset, uint32_t val)
{
    if (debugFlags & DEBUGFLAG_WAVEFORM_HEAD) {
        printf("WFR %d:%d R%d <- ", rp->dsbpmNumber,
                                    rp->recorderNumber,
                                    regOffset);
        showWfrReg(NULL, val);
    }
    WR_WRITE(rp, regOffset, val);
}

/*
 * Set up waveform recorder data structures
 */
void
wfrInit(void)
{
    int dsbpm, i, r;
    int bytesPerSample, pretrigCount, acqCount, maxPretrig, acqSampleCapacity;
    struct recorder *rp;
    static UINTPTR iBufBase;

    /*
     * Map DDR buffers. _ext_ddr_start is located in the linker script
     * lscript_ddr.ld
     */
    if (iBufBase == 0) {
        extern const UINTPTR _ext_ddr_start;
        iBufBase = (UINTPTR)&_ext_ddr_start;
    }
    for (dsbpm = 0 ; dsbpm < DSBPM_PROTOCOL_DSP_COUNT ; dsbpm++) {
        for (i = 0 ; i < DSBPM_PROTOCOL_RECORDER_COUNT ; i++) {
            switch(i) {
            case 0:
                r = GPIO_IDX_ADC_RECORDER_BASE + dsbpm*GPIO_IDX_RECORDER_PER_DSBPM;
                bytesPerSample = 8; /* 4 16-bit ADCs */
                acqSampleCapacity = CFG_RECORDER_ADC_SAMPLE_CAPACITY;
#if 0
                maxPretrig = ADC_WFR_HW_PRETRIG_COUNT;
                pretrigCount = ADC_WFR_HW_PRETRIG_COUNT;
#endif
                maxPretrig = 0;
                pretrigCount = 0;
                acqCount = 1024 * 1024;
                break;

            case 1:
                r = GPIO_IDX_TBT_RECORDER_BASE + dsbpm*GPIO_IDX_RECORDER_PER_DSBPM;
                bytesPerSample = 16; /* 4 32-bit values (X, Y, Sum, Q) */
                acqSampleCapacity = CFG_RECORDER_TBT_SAMPLE_CAPACITY;
                maxPretrig = CFG_RECORDER_TBT_SAMPLE_CAPACITY;
                pretrigCount = 40;
                acqCount = 10000;
                break;

            case 2:
                r = GPIO_IDX_FA_RECORDER_BASE + dsbpm*GPIO_IDX_RECORDER_PER_DSBPM;
                bytesPerSample = 16; /* 4 32-bit values (X, Y, Sum, Q) */
                acqSampleCapacity = CFG_RECORDER_FA_SAMPLE_CAPACITY;
                maxPretrig = CFG_RECORDER_FA_SAMPLE_CAPACITY;
                pretrigCount = 40;
                acqCount = 1000;
                break;

            case 3: case 4:
                r = i == 3 ? GPIO_IDX_PL_RECORDER_BASE + dsbpm*GPIO_IDX_RECORDER_PER_DSBPM :
                    GPIO_IDX_PH_RECORDER_BASE + dsbpm*GPIO_IDX_RECORDER_PER_DSBPM;
                bytesPerSample = 16; /* 4 32-bit pilot tone magnitudes values */
                acqSampleCapacity = CFG_RECORDER_PT_SAMPLE_CAPACITY;
                maxPretrig = CFG_RECORDER_PT_SAMPLE_CAPACITY;
                pretrigCount = 40;
                acqCount = 1000;
                break;

            default: fatal("Waveform recorder defines mangled!");
            }
            rp = &recorder[dsbpm][i];
            rp->regBase = r;
            rp->pretrigCount = pretrigCount;
            rp->acqCount = acqCount;
            rp->maxPretrigger = maxPretrig;
            rp->bytesPerSample = bytesPerSample;
            rp->commState = CS_IDLE;
            rp->dsbpmNumber = dsbpm;
            rp->recorderNumber = i;
            rp->waveformNumber = 1;
            rp->acqBuf = (char *)iBufBase;
            wrWrite(rp, WR_REG_OFFSET_ADDRESS_LSB_POINTER, iBufBase);
            wrWrite(rp, WR_REG_OFFSET_ADDRESS_MSB_POINTER, iBufBase >> 32);
            rp->csrModeBits = 0;
            wrWrite(rp, WR_REG_OFFSET_CSR, rp->csrModeBits);
            rp->acqSampleCapacity = acqSampleCapacity;
            rp->acqByteCapacity = bytesPerSample * acqSampleCapacity;
            iBufBase += rp->acqByteCapacity;
        }
    }
}

/*
 * Convert recorder index to pointer
 */
static struct recorder *
recorderPointer(int dsbpmIndex, int recorderIndex)
{
    if ((dsbpmIndex < 0) || (dsbpmIndex >= DSBPM_PROTOCOL_DSP_COUNT) ||
            (recorderIndex < 0) || (recorderIndex >= DSBPM_PROTOCOL_RECORDER_COUNT))
        return NULL;
    return &recorder[dsbpmIndex][recorderIndex];
}

/*
 * Create a data packet
 */
static struct pbuf *
dataPacket(struct recorder *rp)
{
    int offset, dataLength, packetLength;
    struct dsbpmWaveformData *dp;
    struct pbuf *p = NULL;

    offset = (rp->startByteOffset +
              (rp->txBlock * DSBPM_PROTOCOL_WAVEFORM_PAYLOAD_CAPACITY)) %
                                                            rp->acqByteCapacity;
    dataLength = rp->bytesLeft;
    if (dataLength > 0) {
        if (dataLength > DSBPM_PROTOCOL_WAVEFORM_PAYLOAD_CAPACITY)
            dataLength = DSBPM_PROTOCOL_WAVEFORM_PAYLOAD_CAPACITY;
        packetLength = sizeof(*dp) -
                        (DSBPM_PROTOCOL_WAVEFORM_PAYLOAD_CAPACITY - dataLength);

        /*
         * Create the packet
         */
        p = pbuf_alloc(PBUF_TRANSPORT, packetLength, PBUF_RAM);
        if (p) {
            dp = (struct dsbpmWaveformData *)p->payload;
            dp->magic = DSBPM_PROTOCOL_MAGIC_WAVEFORM_DATA;
            dp->dsbpmNumber = rp->dsbpmNumber;
            dp->recorderNumber = rp->recorderNumber;
            dp->waveformNumber = rp->waveformNumber;
            dp->blockNumber = rp->txBlock;
            if ((offset + dataLength) <= rp->acqByteCapacity) {
                memcpy2(dp->payload, rp->acqBuf + offset, dataLength);
            }
            else {
                /* Handle ring buffer wraparound */
                unsigned int l1, l2;
                l1 = rp->acqByteCapacity - offset;
                memcpy2(dp->payload, rp->acqBuf + offset, l1);
                offset = 0;
                l2 = dataLength - l1;
                memcpy2(dp->payload + l1, rp->acqBuf + offset, l2);
            }
            rp->sysUsAtPreviousPacket = MICROSECONDS_SINCE_BOOT();
            if (debugFlags & DEBUGFLAG_WAVEFORM_XFER)
                printf("WFR %d:%d block %d size %d\n",
                                            rp->dsbpmNumber,
                                            rp->recorderNumber,
                                            (int)dp->blockNumber, dataLength);
        }
    }
    if (p) {
        rp->commState = CS_ACTIVE;
        rp->bytesInPreviousPacket = dataLength;
    }
    else {
        rp->commState = CS_IDLE;
        rp->bytesInPreviousPacket = 0;
    }
    return p;
}

/*
 * Called from publisher packet handler.
 * Hand back a pointer to the data packet to be transmitted.
 */
struct pbuf *
wfrAckPacket(struct dsbpmWaveformAck *ackp)
{
    struct recorder *rp = recorderPointer(ackp->dsbpmNumber, ackp->recorderNumber);

    /*
     * Sanity check
     */
    if ((rp == NULL)
     || ((rp->commState != CS_ACTIVE) && (rp->commState != CS_HEADER))
     || (ackp->magic != DSBPM_PROTOCOL_MAGIC_WAVEFORM_ACK)
     || (ackp->waveformNumber != rp->waveformNumber)
     || (ackp->blockNumber != rp->txBlock))
        return NULL;
    if (debugFlags & DEBUGFLAG_WAVEFORM_XFER)
        printf("WFR %d:%d ACK %d\n",
                                (int)ackp->dsbpmNumber,
                                (int)ackp->recorderNumber,
                                (int)ackp->blockNumber);

    /*
     * Determine contents
     */
    rp->retryCount = 0;
    if (rp->commState != CS_HEADER) {
        rp->txBlock++;
        if (rp->bytesInPreviousPacket < rp->bytesLeft) {
            rp->bytesLeft -= rp->bytesInPreviousPacket;
        }
        else {
            rp->bytesLeft = 0;
        }
    }
    return dataPacket(rp);
}

/*
 * Create a header packet
 */
static struct pbuf *
headerPacket(struct recorder *rp)
{
    struct pbuf *p;
    struct dsbpmWaveformHeader *hp;
    unsigned int count;

    count = WR_READ(rp, WR_REG_OFFSET_ACQUISITION_COUNT);
    if (count > rp->acqCount)
        count = rp->acqCount;
    if (debugFlags & DEBUGFLAG_WAVEFORM_HEAD)
        showRec(rp);
    if (rp->recorderNumber == 0) {
        /*
         * ADC recorder uses linear buffer with fixed trigger samples.
         */
#if 0
        rp->startByteOffset = (ADC_WFR_HW_PRETRIG_COUNT - rp->pretrigCount) *
                                                            rp->bytesPerSample;
#endif
        rp->startByteOffset = 0;
    }
    else {
        /* Other recorders use a ring buffer */
        char *nextAddress = (char *)((uint64_t) WR_READ(rp, WR_REG_OFFSET_ADDRESS_LSB_POINTER) |
                ((uint64_t) WR_READ(rp, WR_REG_OFFSET_ADDRESS_MSB_POINTER)) << 32);
        rp->startByteOffset = ((nextAddress - rp->acqBuf) +
                               rp->acqByteCapacity -
                               (rp->acqCount * rp->bytesPerSample)) %
                                                            rp->acqByteCapacity;
    }
    p = pbuf_alloc(PBUF_TRANSPORT, sizeof(*hp), PBUF_RAM);
    if (p) {
        hp = (struct dsbpmWaveformHeader *)p->payload;
        hp->magic = DSBPM_PROTOCOL_MAGIC_WAVEFORM_HEADER;
        hp->dsbpmNumber = rp->dsbpmNumber;
        hp->recorderNumber = rp->recorderNumber;
        hp->waveformNumber = rp->waveformNumber;
        hp->seconds = WR_READ(rp, WR_REG_OFFSET_TIMESTAMP_SECONDS);
        hp->ticks = WR_READ(rp, WR_REG_OFFSET_TIMESTAMP_TICKS);
        hp->byteCount = rp->bytesLeft = count * rp->bytesPerSample;
        rp->commState = CS_HEADER;
        rp->txBlock = 0;
        rp->sysUsAtPreviousPacket = MICROSECONDS_SINCE_BOOT();
        if (debugFlags & DEBUGFLAG_WAVEFORM_HEAD)
            printf("acqCount:%d(%X)  start byte offset:%d(%X)  bytesLeft:%d\n",
                                    rp->acqCount, rp->acqCount,
                                    rp->startByteOffset, rp->startByteOffset,
                                    rp->bytesLeft);
    }
    rp->bytesInPreviousPacket = 0;
    return p;
}

/*
 * Called from publisher fast-update routine
 */
int
wfrStatus(int dsbpm)
{
    int i;
    int s = 0;

    if ((dsbpm < 0) || (dsbpm >= DSBPM_PROTOCOL_DSP_COUNT))
        return 0;

    for (i = DSBPM_PROTOCOL_RECORDER_COUNT - 1 ; i >= 0 ; i--) {
        epicsUInt32 csr = WR_READ(&recorder[dsbpm][i], WR_REG_OFFSET_CSR);
        s = (s << 1) | ((csr & WR_CSR_ARM) != 0);
    }
    return s;
}

/*
 * Diagnostic histograms
 */
#define HISTSIZE 120
static unsigned int histogram[HISTSIZE];

#if 0
/*
 * Check that ADC waveform recorder is working as expected
 */
static void
adcRecorderDiagnosticCheck(struct recorder *rp)
{
    unsigned int old, new, diff;
    int i;
    unsigned int count = WR_READ(rp, WR_REG_OFFSET_ACQUISITION_COUNT) / 2;
    unsigned int *a = (unsigned int *)rp->acqBuf;
    int errorCount = 0;

    showRec(rp);
    for (i = 0 ; i < HISTSIZE ; i++) histogram[i] = 0;
    old = a[0];
    for (i = 1 ; i < count ; i++) {
        new = a[i*4];
        diff = new - old;
        if (errorCount < 100) {
            if ((diff == 0)
             || (diff >= HISTSIZE)
             || ((a[i*4+1] - 1) != a[(i-1)*4+1])
             || ((a[i*4+1] + 1) != a[(i*4+2)])
             || ((a[i*4+1] + 2) != a[(i*4+3)])) {
                if (errorCount == 0)
                    printf("  Index     TICKS   ADC 1    ADC 2    ADC 3 \n");
                printf("%7d: %8.8X %8.8X %8.8X %8.8X\n", i, a[i*4+0], a[i*4+1],
                                                            a[i*4+2], a[i*4+3]);
                if (++errorCount >= 100) {
                    printf("Too many errors -- printing inhibited\n");
                }
            }
        }
        if (diff >= HISTSIZE) diff = HISTSIZE - 1;
        histogram[diff]++;
        old = new;
    }
    for (i = 0 ; i < HISTSIZE ; i++) {
        if (histogram[i])
            printf("%5d: %u\n", i, histogram[i]);
    }
}
#endif

/*
 * Check that non-ADC waveform recorder is working as expected
 */
static void
recorderDiagnosticCheck(struct recorder *rp)
{
    unsigned int oldVal, val, wordCount;
    int i;
    unsigned int count = WR_READ(rp, WR_REG_OFFSET_ACQUISITION_COUNT);
    char *nextAddress = (char *)((uint64_t) WR_READ(rp, WR_REG_OFFSET_ADDRESS_LSB_POINTER) |
            ((uint64_t) WR_READ(rp, WR_REG_OFFSET_ADDRESS_MSB_POINTER)) << 32);
    unsigned int bIndex = ((nextAddress - rp->acqBuf) +
                           rp->acqByteCapacity -
                           (count * rp->bytesPerSample)) % rp->acqByteCapacity;

    showRec(rp);
    for (i = 0 ; i < HISTSIZE ; i++) histogram[i] = 0;
    for (i = 0 ; i < count ; i++) {
        int *a = (int *)(rp->acqBuf + bIndex);
        val = a[0];
        if (i && (val != (oldVal + 1))) {
            printf("%7d: %8.8X %8.8X %8.8X %8.8X %8.8X\n", i, a[0], a[1],
                                                           a[2], a[3], oldVal);
        }
        oldVal = val;
        bIndex = (bIndex + rp->bytesPerSample) % rp->acqByteCapacity;
        val = a[1];
        if (val >= HISTSIZE) val = HISTSIZE - 1;
        histogram[val]++;
    }
    printf("Burst sizes:\n");
    for (i = HISTSIZE - 1, oldVal = 0, wordCount = 0 ; i >= 0 ; i--) {
        int c = histogram[i] - oldVal;
        if (c < 0) {
            printf("histogram[%d]=%u c=%d\n", i, histogram[i], c);
            c = 0;
        }
        oldVal += c;
        wordCount += (i + 1) * c;
        if (c) printf("%5d: %u\n", i + 1, c);
    }
    printf("Words transferred: %u\n", wordCount);
}

/*
 * Called from publisher work-check routine
 * Hand back a pointer to the packet to be transmitted.
 */
struct pbuf *
wfrCheckForWork(void)
{
    static int dsbpmIndex;
    static int recorderIndex;
    struct recorder *rp;
    struct pbuf *p = NULL;
    uint32_t now;

    /*
     * Rotate through recorders one at a time
     */
    if (recorderIndex >= (DSBPM_PROTOCOL_RECORDER_COUNT - 1)) {
        recorderIndex = 0;
        if (dsbpmIndex >= (DSBPM_PROTOCOL_DSP_COUNT - 1)) {
            dsbpmIndex = 0;
        }
        else {
            dsbpmIndex++;
        }
    }
    else {
        recorderIndex++;
    }
    rp = recorderPointer(dsbpmIndex, recorderIndex);

    /*
     * Send a header when a recorder has filled
     */
    if (rp->commState == CS_IDLE) {
        epicsUInt32 csr = WR_READ(rp, WR_REG_OFFSET_CSR);
        if (csr & WR_CSR_IS_FULL) {
            /* Clear full status */
            wrWrite(rp, WR_REG_OFFSET_CSR, rp->csrModeBits);
            if (debugFlags & DEBUGFLAG_WAVEFORM_HEAD)
                printf("DSBPM:Recorder %d:%d is full\n", rp->dsbpmNumber, rp->recorderNumber);

            /*
             * The buffer is almost certainly bigger than the cache
             * so it's fine to simply invalidate everything.
             * After discussions with Xilinx and much testing I've
             * confirmed that this is in fact the correct call.
             * A call to 'Invalidate' seems to result in a mangled
             * system.  This is likely because the cache is write-back.
             */
            Xil_DCacheFlush();
            rp->retryCount = 0;
            if (csr & WR_CSR_DIAGNOSTIC_MODE) {
                if (rp->recorderNumber == 0) {
#if 0
                    adcRecorderDiagnosticCheck(rp);
#endif
                }
                else
                    recorderDiagnosticCheck(rp);
            }
            p = headerPacket(rp);
        }
    }
    else {
        now = MICROSECONDS_SINCE_BOOT();
        if ((now - rp->sysUsAtPreviousPacket) > TIMEOUT_US) {
            if (++rp->retryCount < RETRY_LIMIT) {
                /*
                 * Retry the transmission.
                 * It might seem like a good idea to just hang on to the
                 * pbuf pointer and return it again, but that turns out to
                 * be a really bad idea since udp_sendto mangles the pbuf.
                 */
                switch (rp->commState) {
                case CS_HEADER: p = headerPacket(rp); break;
                case CS_ACTIVE: p = dataPacket(rp);   break;
                default:                              break;
                }
            }
            else {
                rp->commState = CS_IDLE;
            }
        }
    }
    return p;
}

/*
 * Called from server packet handler
 */
int
waveformRecorderCommand(unsigned int bpm, int waveformCommand, int recorderIndex,
        epicsUInt32 val, uint32_t reply[], int capacity)
{
    struct recorder *rp;
    int replyArgCount = 0;

    if (bpm < 0 || bpm >= CFG_DSBPM_COUNT) return 0;
    if (recorderIndex < 0 || recorderIndex >= DSBPM_PROTOCOL_RECORDER_COUNT) return 0;

    if (waveformCommand == DSBPM_PROTOCOL_CMD_RECORDERS_LO_SOFT_TRIGGER) {
        if (debugFlags & DEBUGFLAG_WAVEFORM_HEAD)
            printf("Recorder soft trigger\n");
        GPIO_WRITE(bpm*GPIO_IDX_PER_DSBPM+GPIO_IDX_WFR_SOFT_TRIGGER,
                0);
        return 0;
    }

    rp = recorderPointer(bpm, recorderIndex);
    if (rp == NULL)
        return 0;

    epicsUInt32 csr = 0;
    switch (waveformCommand) {
    case DSBPM_PROTOCOL_CMD_RECORDERS_LO_ARM:
        csr = (rp->triggerMask & 0xFF) << 24;
        if (val) {
            if (!isArmed(rp)) {
                wrWrite(rp, WR_REG_OFFSET_ACQUISITION_COUNT, rp->acqCount);
                wrWrite(rp, WR_REG_OFFSET_PRETRIGGER_COUNT, rp->pretrigCount);
                rp->waveformNumber++;
            }
            rp->commState = CS_IDLE;
            csr |= WR_CSR_ARM;
        }
        if (debugFlags & DEBUGFLAG_RECORDER_DIAG)
            rp->csrModeBits |= WR_CSR_DIAGNOSTIC_MODE;
        else
            rp->csrModeBits &= ~WR_CSR_DIAGNOSTIC_MODE;
        csr |= rp->csrModeBits;
        wrWrite(rp, WR_REG_OFFSET_CSR, csr);
        break;

    case DSBPM_PROTOCOL_CMD_RECORDERS_LO_TRIGGER_MASK:
        val &= 0xFF;
        rp->triggerMask = val;
        break;

    case DSBPM_PROTOCOL_CMD_RECORDERS_LO_PRETRIGGER_COUNT:
        if (val >= 0) {
            if (val > rp->maxPretrigger) val = rp->maxPretrigger;
            rp->pretrigCount = val;
        }
        break;

    case DSBPM_PROTOCOL_CMD_RECORDERS_LO_ACQUISITION_COUNT:
        if (val > 0) {
            if (val > rp->acqSampleCapacity) val = rp->acqSampleCapacity;
            rp->acqCount = val;
        }
        break;

    case DSBPM_PROTOCOL_CMD_RECORDERS_LO_ACQUISITION_MODE:
        if (val) rp->csrModeBits |=  WR_CSR_TEST_ACQUISITION_MODE;
        else     rp->csrModeBits &= ~WR_CSR_TEST_ACQUISITION_MODE;
        break;

    default:
        break;
    }

    return replyArgCount;
}
