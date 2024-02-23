/*
 * Manipulate DAC tables
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "ffs.h"
#include "gpio.h"
#include "ptGen.h"
#include "systemParameters.h"
#include "util.h"

#define BANKSELECT_SHIFT  31
#define BANKINDEX_PT_GEN  0
#define BANKINDEX_NONE    1

/*
 * Bit assignments for PT Gen banks
 */
#define VALUE_WIDTH         16
#define VALUE_MASK          ((1<<VALUE_WIDTH)-1)

/*
 * Bit assignments for 'bank none'
 */
#define NOBANK_RUN_BIT         0x1

#define REG(base,chan)  ((base) + (GPIO_IDX_PER_DSBPM * (chan)))

#define PT_GEN_TABLE_BUF_SIZE       (2+(2*CFG_PT_GEN_ROW_CAPACITY))
#define MAX_TABLE_BUF_SIZE          (PT_GEN_TABLE_BUF_SIZE)

static int32_t ptGenTable[PT_GEN_TABLE_BUF_SIZE];

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

    GPIO_WRITE(REG(GPIO_IDX_DACTABLE_ADDRESS, bpm), address);
    GPIO_WRITE(REG(GPIO_IDX_DACTABLE_CSR, bpm), csr);
}

/*
 * Write selected bits in 'bank none'
 */
static void
writeCSR(unsigned int bpm, uint32_t value, uint32_t mask)
{
    uint32_t v;

    v = GPIO_READ(REG(GPIO_IDX_DACTABLE_CSR, bpm));
    v = (v & ~mask) | (value & mask);
    GPIO_WRITE(REG(GPIO_IDX_DACTABLE_CSR, bpm),
            (BANKINDEX_NONE << BANKSELECT_SHIFT) | v);
}

/*
 * Called when complete file has been uploaded to the TFTP server
 */
int
ptGenSetTable(unsigned char *buf, int size)
{
    int r, c, colCount = 2;
    int capacity = CFG_PT_GEN_ROW_CAPACITY;
    int32_t *table = ptGenTable;
    int32_t *ip = &table[2];
    int byteCount;
    unsigned char *cp = buf;

    for (r = 0 ; r < capacity ; r++) {
        for (c = 0 ; c < colCount ; c++) {
            char expectedEnd = (c == (colCount - 1)) ? '\n' : ',';
            char *endp;
            int x;

            x = strtol((char *)cp, &endp, 0);
            if ((*endp != expectedEnd)
             && ((expectedEnd == '\n') && (*endp != '\r'))) {
                sprintf((char *)buf, "Unexpected characters on line %d: %c (expected %c)",
                        r + 1, *endp, expectedEnd);
                printf("Unexpected characters on line %d: %c (expected %c)\n",
                        r + 1, *endp, expectedEnd);
                return -1;
            }
            *ip++ = x;
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

/*
 * Called when local oscillator table is to be downloaded from the TFTP server
 */
int
ptGenGetTable(unsigned char *buf)
{
    int r, c, rowCount, colCount = 2;
    int32_t *table = ptGenTable;
    unsigned char *cp = buf;

    rowCount = table[0];
    table += 2;
    for (r = 0 ; r < rowCount ; r++) {
        for (c = 0 ; c < colCount ; c++) {
            int i;
            char sep = (c == (colCount - 1)) ? '\n' : ',';
            int v = *table++;
            i = sprintf((char *)cp, "%d%c", v, sep);
            cp += i;
        }
    }
    return cp - buf;
}

/*
 * Start oscillators
 */
static void
ptGenRun(unsigned int bpm)
{
    uint32_t v = NOBANK_RUN_BIT;
    writeCSR(bpm, v, NOBANK_RUN_BIT);

    if (debugFlags & DEBUGFLAG_LOCAL_OSC_SHOW)
        printf("PT generation %u running!\n", bpm);
}

static int
isPtGenRun(unsigned int bpm)
{
    uint32_t v = GPIO_READ(REG(GPIO_IDX_DACTABLE_CSR, bpm));
    return (v & NOBANK_RUN_BIT) == NOBANK_RUN_BIT;
}

/*
 * Commit table to FPGA
 */
static void
ptGenWrite(unsigned int bpm, int32_t *dst, const int32_t *src, int capacity)
{
    int r, c, rowCount;
    size_t hdrSizeWords = 2; // Row count and checksum
    int colCount = 2;

    rowCount = src[0];
    if ((rowCount >= 29)
     && (rowCount < capacity)
     && (src[1] == checkSum(src, rowCount, colCount))) {
        if (dst) {
            memcpy(dst, src, hdrSizeWords*sizeof(*src));
            dst+=hdrSizeWords;
        }
        src+=hdrSizeWords;

        for (r = 0 ; r < rowCount ; r++) {
            for (c = 0 ; c < colCount ; c++) {
                writeTable(bpm, BANKINDEX_PT_GEN, r, c & 0x1, *src);

                if(dst) *dst++ = *src;
                src++;
            }
        }
    }
    else {
        printf("CORRUPT PT GENERATION TABLE\n");
    }

    ptGenRun(bpm);
}

/*
 * Initialize PT tables
 */

void
ptGenCommit(unsigned int bpm)
{
    int32_t *src = ptGenTable;
    int capacity = CFG_PT_GEN_ROW_CAPACITY;

    if (bpm >= CFG_DSBPM_COUNT) return;

    ptGenWrite(bpm, NULL, src, capacity);
}

void
ptGenCommitAll(void)
{
    int i;
    for (i = 0; i < CFG_DSBPM_COUNT; i++) {
        ptGenCommit(i);
    }
}

void ptGenInit(unsigned int bpm)
{
    /*
     * The obnly supported initialization is via a .csv file called
     * the filesystem readback
     */
    if (!isPtGenRun(bpm)) {
        printf("PT Generation failed to initialize by filesystem readback. "
                "Check previous errrors\n");
    }
}


/*
 * EEPROM I/O
 */
static int32_t tableBuf[MAX_TABLE_BUF_SIZE];

int
ptGenFetchEEPROM()
{
    const char *name = "/"PT_GEN_TABLE_EEPROM_NAME;
    int nRead;
    FRESULT fr;
    FIL fil;
    UINT nWritten;

    fr = f_open(&fil, name, FA_WRITE | FA_CREATE_ALWAYS);
    if (fr != FR_OK) {
        return -1;
    }

    nRead = ptGenGetTable((unsigned char *)tableBuf);
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

/*
 * Copy file to Local Oscillator EEPROM
 */
int
ptGenStashEEPROM()
{
    const char *name = "/"PT_GEN_TABLE_EEPROM_NAME;
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
        printf("PT generation table file read failed\n");
        f_close(&fil);
        return -1;
    }
    if (nRead == 0) {
        f_close(&fil);
        return 0;
    }

    nWrite = ptGenSetTable((unsigned char *)tableBuf, nRead);
    f_close(&fil);

    return nWrite;
}
