/*
 * Manipulate local oscillator tables
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "ffs.h"
#include "gpio.h"
#include "localOscillator.h"
#include "systemParameters.h"
#include "util.h"
#include "loTables.h"

#define BANKSELECT_SHIFT  30
#define BANKINDEX_RF      0
#define BANKINDEX_PT_LO   1
#define BANKINDEX_PT_HI   2
#define BANKINDEX_NONE    3

/*
 * Bit assignments for RF and PT banks
 */
#define VALUE_WIDTH         18
#define VALUE_MASK          ((1<<VALUE_WIDTH)-1)

/*
 * Bit assignments for 'bank none'
 */
#define NOBANK_RUN_BIT         0x1
#define NOBANK_SINGLE_PASS_BIT 0x2
#define NOBANK_DSP_USE_RMS_BIT 0x4
/* Synchronous demodulation synchronization status */
#define NOBANK_SD_STATUS_SHIFT 27
#define NOBANK_SD_STATUS_MASK  (0x3 << NOBANK_SD_STATUS_SHIFT)

/*
 * Synchronous demodulation control/status
 */
#define SDACCUMULATOR_TBT_SUM_SHIFT_SHIFT   0
#define SDACCUMULATOR_TBT_SUM_SHIFT_MASK    0xF
#define SDACCUMULATOR_MT_SUM_SHIFT_SHIFT    4
#define SDACCUMULATOR_MT_SUM_SHIFT_MASK     0xF0
#define SDACCUMULATOR_FA_CIC_SHIFT_SHIFT    8
#define SDACCUMULATOR_FA_CIC_SHIFT_MASK     0xF00
#define SDACCUMULATOR_SD_OVERFLOWS_SHIFT    12
#define SDACCUMULATOR_SD_OVERFLOWS_MASK     0xF000
#define SDACCUMULATOR_FA_DECIMATION_SHIFT   19
#define SDACCUMULATOR_FA_DECIMATION_MASK    0x1FF80000
#define SDACCUMULATOR_CIC_STAGE_COUNT_SHIFT 29
#define SDACCUMULATOR_CIC_STAGE_COUNT_MASK  0xE0000000

/*
 * Coefficient scaling
 */
#define SCALE_FACTOR    ((double)0x1FFFF)

#define REG(base,chan)  ((base) + (GPIO_IDX_PER_DSBPM * (chan)))

#define RF_TABLE_BUF_SIZE       (2+(2*CFG_LO_RF_ROW_CAPACITY))
#define PT_TABLE_BUF_SIZE       (2+(4*CFG_LO_PT_ROW_CAPACITY))
#define MAX_TABLE_BUF_SIZE      (PT_TABLE_BUF_SIZE)

static int32_t rfTable[RF_TABLE_BUF_SIZE];
static int32_t ptTable[PT_TABLE_BUF_SIZE];

/*
 * Form checksum
 */
static int32_t
checkSum(const int32_t *ip, int rowCount, int colCount)
{
    int r, c;
    int32_t sum = 0xF00D8421;

    sum += *ip++;
    ip++;
    for (r = 0 ; r < rowCount ; r++) {
        for (c = 0 ; c < colCount ; c++) {
            sum += *ip++ + r + c;
        }
    }
    return sum;
}

/*
 * Write to local osciallator RAM
 */
static void
writeTable(unsigned int bpm, int bankIndex, int row, int isSin, int value)
{
    uint32_t address = (row << 1) | (isSin != 0);
    uint32_t csr = (bankIndex << BANKSELECT_SHIFT) | (value & VALUE_MASK);

    if (bpm >= CFG_DSBPM_COUNT) return;

    GPIO_WRITE(REG(GPIO_IDX_LOTABLE_ADDRESS, bpm), address);
    GPIO_WRITE(REG(GPIO_IDX_LOTABLE_CSR, bpm), csr);
}

/*
 * Write selected bits in 'bank none'
 */
static void
writeCSR(unsigned int bpm, uint32_t value, uint32_t mask)
{
    uint32_t v;

    v = GPIO_READ(REG(GPIO_IDX_LOTABLE_CSR, bpm));
    v = (v & ~mask) | (value & mask);
    GPIO_WRITE(REG(GPIO_IDX_LOTABLE_CSR, bpm),
            (BANKINDEX_NONE << BANKSELECT_SHIFT) | v);
}

/*
 * float->int scaling
 */
static int
scale(double x)
{
    int i, neg = 0;

    if (x < 0) {
        x = -x;
        neg = 1;
    }
    i = (x * SCALE_FACTOR) + 0.5;
    if (neg) i = -i;
    return i;
}

static void
setSumShift(unsigned int bpm, int sumShift, uint32_t mask, int shift)
{
    uint32_t csr;

    if (bpm >= CFG_DSBPM_COUNT) return;

    csr = GPIO_READ(REG(GPIO_IDX_SUM_SHIFT_CSR, bpm));
    if (sumShift < 0) sumShift = 0;
    else if (sumShift > 15) sumShift = 15;
    csr &= ~mask;
    csr |= sumShift << shift;
    GPIO_WRITE(REG(GPIO_IDX_SUM_SHIFT_CSR, bpm), csr);
}

void
sdAccumulateSetTbtSumShift(unsigned int bpm, int shift)
{
    setSumShift(bpm, shift, SDACCUMULATOR_TBT_SUM_SHIFT_MASK,
                            SDACCUMULATOR_TBT_SUM_SHIFT_SHIFT);
}

void
sdAccumulateSetMtSumShift(unsigned int bpm, int shift)
{
    setSumShift(bpm, shift, SDACCUMULATOR_MT_SUM_SHIFT_MASK,
                            SDACCUMULATOR_MT_SUM_SHIFT_SHIFT);
}

void
sdAccumulateSetFaSumShift(unsigned int bpm, int shift)
{
    setSumShift(bpm, shift, SDACCUMULATOR_FA_CIC_SHIFT_MASK,
                            SDACCUMULATOR_FA_CIC_SHIFT_SHIFT);
}

/*
 * Determine shift to correct for CIC scaling
 */
static int
cicShift(int decimationFactor, int nStages)
{
    double x = 1.0;
    int shift = 0;

    while (nStages--) x *= decimationFactor;
    while (x > 1) {
        shift++;
        x /= 2;
    }
    return shift;
}

/*
 * Scale FA CIC result by appropriate amount if actual FA decimation factor
 * exceeds the configured value.
 */
static void
optimizeCicShift(unsigned int bpm, int mtTableLength)
{
    uint32_t csr = GPIO_READ(REG(GPIO_IDX_SUM_SHIFT_CSR, bpm));
    int nCICstages = (csr & SDACCUMULATOR_CIC_STAGE_COUNT_MASK) >>
                                            SDACCUMULATOR_CIC_STAGE_COUNT_SHIFT;
    int faDecimationConfig = (csr & SDACCUMULATOR_FA_DECIMATION_MASK) >>
                                            SDACCUMULATOR_FA_DECIMATION_SHIFT;
    unsigned int num = systemParameters.evrPerFaMarker *
                       systemParameters.pllMultiplier * 4;
    unsigned int den = mtTableLength * systemParameters.rfDivisor;
    int faDecimationActual = num / den;
    int remainder = num % den;
    int cicShiftConfig, cicShiftActual;

    if (remainder) warn("FA CIC DECIMATION FACTOR ISN'T AN INTEGER\n");
    if (faDecimationActual != faDecimationConfig) {
        int shift;
        printf("FA CIC filter stage count: %d\n", nCICstages);
        cicShiftConfig = cicShift(faDecimationConfig, nCICstages);
        cicShiftActual = cicShift(faDecimationActual, nCICstages);
        shift = cicShiftConfig - cicShiftActual;
        if (shift > 15) shift = 15;
        if (shift < 0) {
            shift = 0;
            warn("FA CIC SCALING OVERFLOW\n");
            warn("Increase pilot tone table length or attenuate filter inputs.\n\n");
        }
        if (remainder) printf(" (remainder %d (!!!))", remainder);
        printf("FA CIC filter FPGA build decimation factor %d (shift %d).\n",
                                            faDecimationConfig, cicShiftConfig);
        printf("FA CIC filter actual decimation factor %d", faDecimationActual);
        printf(" (shift %d).\n", cicShiftActual);
        printf("Set CIC shift to %d.\n", shift);
        sdAccumulateSetFaSumShift(bpm, shift);
    }

    if (debugFlags & DEBUGFLAG_LOCAL_OSC_SHOW) {
        printf("optimizeCicShift: nCICstages = %d\n", nCICstages);
        printf("optimizeCicShift: faDecimationConfig = %d\n", faDecimationConfig);
        printf("optimizeCicShift: num = %u\n", num);
        printf("optimizeCicShift: den = %u\n", den);
        printf("optimizeCicShift: faDecimationActual = %d\n", faDecimationActual);
        printf("optimizeCicShift: remainder = %d\n", remainder);
    }
}

/*
 * Called when complete file has been uploaded to the TFTP server
 */
static int
localOscSetTable(unsigned char *buf, int size, int isPt)
{
    int r, c, colCount = isPt ? 4 : 2;
    int capacity = isPt ? CFG_LO_PT_ROW_CAPACITY : CFG_LO_RF_ROW_CAPACITY;
    int32_t *table = isPt ? ptTable : rfTable;
    int32_t *ip = &table[2];
    int byteCount;
    unsigned char *cp = buf;

    for (r = 0 ; r < capacity ; r++) {
        for (c = 0 ; c < colCount ; c++) {
            char expectedEnd = (c == (colCount - 1)) ? '\n' : ',';
            char *endp;
            double x;

            x = strtod((char *)cp, &endp);
            if ((*endp != expectedEnd)
             && ((expectedEnd == '\n') && (*endp != '\r'))) {
                sprintf((char *)buf, "Unexpected characters on line %d", r + 1);
                printf("Unexpected characters on line %d\n", r + 1);
                return -1;
            }
            /* The odd-looking comparison is to deal with NANs */
            if (!(x >= -1.0) && (x <= 1.0)) {
                sprintf((char *)buf, "Value out of range at line %d", r + 1);
                printf("Value out of range at line %d\n", r + 1);
                return -1;
            }
            *ip++ = scale(x);
            cp = (unsigned char *)endp + 1;
            if ((cp - buf) >= size) {
                if ((r < 28) || (c != (colCount - 1))) {
                    sprintf((char *)buf, "Too short at line %d", r + 1);
                    printf("Too short at line %d, c = %d, colCount = %d, size = %d\n", r + 1, c, colCount, size);
                    return -1;
                }
                table[0] = r + 1;
                table[1] = checkSum(&table[0], r + 1, colCount);
                byteCount = (ip - table) * sizeof(*ip);
                memcpy(buf, table, byteCount);
                return byteCount;
            }
        }
    }
    sprintf((char *)buf, "Too long at line %d", r + 1);
    printf("Too long at line %d\n", r + 1);
    return -1;
}

int
localOscSetRfTable(unsigned char *buf, int size)
{
    return localOscSetTable(buf, size, 0);
}

int
localOscSetPtTable(unsigned char *buf, int size)
{
    return localOscSetTable(buf, size, 1);
}

/*
 * Called when local oscillator table is to be downloaded from the TFTP server
 */
static int
localOscGetTable(unsigned char *buf, int isPt)
{
    int r, c, rowCount, colCount = isPt ? 4 : 2;
    int32_t *table = isPt ? ptTable : rfTable;
    unsigned char *cp = buf;

    rowCount = table[0];
    table += 2;
    for (r = 0 ; r < rowCount ; r++) {
        for (c = 0 ; c < colCount ; c++) {
            int i;
            char sep = (c == (colCount - 1)) ? '\n' : ',';
            double v = *table++ / SCALE_FACTOR;
            i = sprintf((char *)cp, "%9.6f%c", v, sep);
            cp += i;
        }
    }
    return cp - buf;
}

int
localOscGetRfTable(unsigned char *buf, int size)
{
    return localOscGetTable(buf, 0);
}

int
localOscGetPtTable(unsigned char *buf, int size)
{
    return localOscGetTable(buf, 1);
}

/*
 * Start oscillators
 */
static void
localOscRun(unsigned int bpm)
{
    uint32_t v = NOBANK_RUN_BIT;
    if (systemParameters.isSinglePass) v |= NOBANK_SINGLE_PASS_BIT;
    writeCSR(bpm, v, NOBANK_SINGLE_PASS_BIT | NOBANK_RUN_BIT);

    if (debugFlags & DEBUGFLAG_LOCAL_OSC_SHOW)
        printf("Local oscillator %u running!\n", bpm);
}

static int
isLocalOscRun(unsigned int bpm)
{
    uint32_t v = GPIO_READ(REG(GPIO_IDX_LOTABLE_CSR, bpm));
    return (v & NOBANK_RUN_BIT) == NOBANK_RUN_BIT;
}

/*
 * Commit table to FPGA
 */
static void
localOscWrite(unsigned int bpm, int32_t *dst, const int32_t *src, int capacity,
        int isPt)
{
    int r, c, rowCount;
    size_t hdrSizeWords = 2; // Row count and checksum
    int colCount = isPt ? 4 : 2;
    static int goodTables = 0;

    rowCount = src[0];
    if ((rowCount >= 29)
     && (rowCount < capacity)
     && (src[1] == checkSum(src, rowCount, colCount))) {
        goodTables++;
        if (dst) {
            memcpy(dst, src, hdrSizeWords*sizeof(*src));
            dst+=hdrSizeWords;
        }
        src+=hdrSizeWords;

        for (r = 0 ; r < rowCount ; r++) {
            for (c = 0 ; c < colCount ; c++) {
                int bankIndex;
                if (isPt) {
                    if (c < 2)
                        bankIndex = BANKINDEX_PT_LO;
                    else
                        bankIndex = BANKINDEX_PT_HI;
                }
                else {
                    bankIndex = BANKINDEX_RF;
                }
                writeTable(bpm, bankIndex, r, c & 0x1, *src);

                if(dst) *dst++ = *src;
                src++;
            }
        }
    }
    else {
        printf("CORRUPT LOCAL OSCILLATOR TABLE\n");
    }

    if (goodTables == 2) localOscRun(bpm);
    if (isPt) optimizeCicShift(bpm, rowCount);
}


/*
 * Initialize local oscillators
 */

static void
localOscCommit(unsigned int bpm, int isPt)
{
    int32_t *src = isPt ? ptTable : rfTable;
    int capacity = isPt ? CFG_LO_PT_ROW_CAPACITY : CFG_LO_RF_ROW_CAPACITY;

    localOscWrite(bpm, NULL, src, capacity, isPt);
}

void
localOscRfCommit(unsigned int bpm)
{
    if (bpm >= CFG_DSBPM_COUNT) return;

    localOscCommit(bpm, 0);
}

void
localOscRfCommitAll(void)
{
    int i;
    for (i = 0; i < CFG_DSBPM_COUNT; i++) {
        localOscCommit(i, 0);
    }
}

void
localOscPtCommit(unsigned int bpm)
{
    if (bpm >= CFG_DSBPM_COUNT) return;

    localOscCommit(bpm, 1);
}

void
localOscPtCommitAll(void)
{
    int i;
    for (i = 0; i < CFG_DSBPM_COUNT; i++) {
        localOscCommit(i, 1);
    }
}

int
localOscGetDspAlgorithm(unsigned int bpm)
{
    if (bpm >= CFG_DSBPM_COUNT) return 0;

    return (GPIO_READ(REG(GPIO_IDX_LOTABLE_CSR, bpm)) &
            NOBANK_DSP_USE_RMS_BIT) != 0;
}

void
localOscSetDspAlgorithm(unsigned int bpm, int useRMS)
{
    if (bpm >= CFG_DSBPM_COUNT) return;

    writeCSR(bpm, useRMS ? NOBANK_DSP_USE_RMS_BIT : 0, NOBANK_DSP_USE_RMS_BIT);
}

int
localOscGetSdSyncStatus(unsigned int bpm)
{
    if (bpm >= CFG_DSBPM_COUNT) return 0;

    return (GPIO_READ(REG(GPIO_IDX_LOTABLE_CSR, bpm)) & NOBANK_SD_STATUS_MASK) >>
                                              NOBANK_SD_STATUS_SHIFT;
}

void localOscillatorInit(unsigned int bpm)
{
    /*
     * If running, it was already initilized by the filesystem
     * readback
     */
    if (!isLocalOscRun(bpm)) {
        localOscSetRfTable(rfTableSR, sizeof(rfTableSR)-1);
        localOscSetPtTable(rfTablePT, sizeof(rfTablePT)-1);
        localOscRfCommit(bpm);
        localOscPtCommit(bpm);
    }
}


/*
 * EEPROM I/O
 */
static int32_t tableBuf[MAX_TABLE_BUF_SIZE];

int
localOscillatorFetchEEPROM(int isPt)
{
    const char *name = isPt ? "/"PT_TABLE_EEPROM_NAME : "/"RF_TABLE_EEPROM_NAME;
    int nRead;
    FRESULT fr;
    FIL fil;
    UINT nWritten;

    fr = f_open(&fil, name, FA_WRITE | FA_CREATE_ALWAYS);
    if (fr != FR_OK) {
        return -1;
    }

    nRead = localOscGetTable((unsigned char *)tableBuf, isPt);
    if (nRead <= 0) {
        f_close(&fil);
        return -1;
    }

    fr = f_write(&fil, tableBuf, nRead, &nWritten);
    if (fr != FR_OK) {
        f_close(&fil);
        return -1;
    }

    f_close(&fil);
    return nWritten;
}

int
localOscillatorFetchRfEEPROM(void)
{
    return localOscillatorFetchEEPROM(0);
}

int
localOscillatorFetchPtEEPROM(void)
{
    return localOscillatorFetchEEPROM(1);
}

/*
 * Copy file to Local Oscillator EEPROM
 */
int
localOscillatorStashEEPROM(int isPt)
{
    const char *name = isPt ? "/"PT_TABLE_EEPROM_NAME : "/"RF_TABLE_EEPROM_NAME;
    int nWrite;
    FRESULT fr;
    FIL fil;
    UINT nRead;

    fr = f_open(&fil, name, FA_READ);
    if (fr != FR_OK) {
        return -1;
    }

    fr = f_read(&fil, tableBuf, sizeof(tableBuf), &nRead);
    if (fr != FR_OK) {
        printf("%s local oscillator file read failed\n", isPt? "PT" : "RF");
        f_close(&fil);
        return -1;
    }
    if (nRead == 0) {
        f_close(&fil);
        return 0;
    }

    nWrite = localOscSetTable((unsigned char *)tableBuf, nRead, isPt);
    f_close(&fil);

    return nWrite;
}

int
localOscillatorStashRfEEPROM(void)
{
    return localOscillatorStashEEPROM(0);
}

int
localOscillatorStashPtEEPROM(void)
{
    return localOscillatorStashEEPROM(1);
}
