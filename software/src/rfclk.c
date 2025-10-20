/*
 * RF clock generation components
 */
#include <stdio.h>
#include <stdint.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>
#include <xil_assert.h>
#include "ffs.h"
#include "iic.h"
#include "rfclk.h"
#include "util.h"
#include "gpio.h"

/*
 * Configure LMK04208/LMK04828B jitter cleaner.
 */
static void
initLmk04xx(const uint32_t *values, int n)
{
    int i;

    /*
     * Write registers with values from TICS Pro.
     */
    for (i = 0 ; i < n ; i++) {
        uint32_t v = values[i];
        lmk04828Bwrite(v);
    }
}

void
lmk04xxConfig(const uint32_t *values, int n)
{
    initLmk04xx(values, n);
}

/*
 * Initialze LMX2594 frequency synthesizer
 */
static const char * const vTuneNames[4] =
                             { "Vtune Low", "Invalid", "Locked", "Vtune High" };
static int lmx2594v0InitValues[LMX2594_MUX_SEL_SIZE];

static void
init2594(int muxSelect, const uint32_t *values, int n)
{
    Xil_AssertVoid(muxSelect < LMX2594_MUX_SEL_SIZE);

    int i;

    /*
     * Apply and remove RESET
     */
    lmx2594write(muxSelect, 0x002412);
    lmx2594write(muxSelect, 0x002410);

    /*
     * Write registers with values from TICS Pro.
     */
    for (i = 0 ; i < n ; i++) {
        uint32_t v = values[i];
        if ((v & 0xFF0000) == 0) {
            v &= ~0x4; // Force MUXOUT_LD_SEL to readback
            v |=  0x8; // Enable initial calibration

            // Don't initilize VCO calibration and force readback
            // for the default value
            lmx2594v0InitValues[muxSelect] = v & ~(0x8 | 0x4);
        }
        lmx2594write(muxSelect, v);
    }
}

/*
 * Start LMX2594 and verify operation
 * I do not understand why this second FCAL_EN assertion is required, but
 * the device doesn't seem to lock unless this is done.
 */
static void
start2594(int muxSelect)
{
    Xil_AssertVoid(muxSelect < LMX2594_MUX_SEL_SIZE);

    int vTuneCode;
    uint32_t v0 = lmx2594read(muxSelect, 0);

    /*
     * Initiate VCO calibration
     */
    lmx2594write(muxSelect, v0 | 0x8);

    /*
     * Provide some time for things to settle down
     */
    microsecondSpin(10000);

    /*
     * See if clock locked
     */
    vTuneCode = (lmx2594read(muxSelect, 110) >> 9) & 0x3;
    if (vTuneCode != 2) {
        warn("LMX2594 (SPI MUX CHAN %d) -- VCO status: %s",
                                             muxSelect, vTuneNames[vTuneCode]);
    }

    /*
     * Configure STATUS pin to lock detect
     */
    lmx2594write(muxSelect, v0 | 0x4);
}

void
lmx2594Config(int muxSelect, const uint32_t *values, int n)
{
    Xil_AssertVoid(muxSelect < LMX2594_MUX_SEL_SIZE);

    init2594(muxSelect, values, n);
    start2594(muxSelect);
}

void
lmx2594ADCConfig(const uint32_t *values, int n)
{
    int muxSelect =  SPI_MUX_2594_A_ADC;

    init2594(muxSelect, values, n);
    start2594(muxSelect);
}

void
lmx2594DACConfig(const uint32_t *values, int n)
{
    int muxSelect =  SPI_MUX_2594_B_DAC;

    init2594(muxSelect, values, n);
    start2594(muxSelect);
}

void
lmx2594ConfigAllSame(const uint32_t *values, int n)
{
    int i;
    for (i = 0 ; i < LMX2594_MUX_SEL_SIZE; i++) {
        lmx2594Config(lmx2594MuxSel[i], values, n);
    }
}

int
lmx2594Readback(int muxSelect, uint32_t *values, int capacity)
{
    Xil_AssertNonvoid(muxSelect < LMX2594_MUX_SEL_SIZE);

    /*
     * Configure STATUS pin to readback
     */
    int v0 = lmx2594v0InitValues[muxSelect];
    lmx2594write(muxSelect, v0 & ~0x4);

    int i;
    int n = lmx2594Sizes[muxSelect];
    for (i = 0 ; (i < n) && (i < capacity) ; i++) {
        int r = n - i - 1;
        int v = lmx2594read(muxSelect, r);
        *values++ = (r << 16) | (v & 0xFFFF);
    }

    /*
     * Configure STATUS pin to lock detect
     */
    lmx2594write(muxSelect, v0 | 0x4);
    return n;
}

int
lmx2594ReadbackFirst(uint32_t *values, int capacity)
{
    return lmx2594Readback(lmx2594MuxSel[0], values, capacity);
}

void
rfClkInit(void)
{
    lmk04xxConfig(lmk04828BValues, lmk04828BSizes);

    int i;
    for (i = 0 ; i < LMX2594_MUX_SEL_SIZE ; i++) {
        lmx2594Config(lmx2594MuxSel[i], lmx2594Values[i],
                lmx2594Sizes[i]);
    }

    if (debugFlags & DEBUGFLAG_RF_CLK_SHOW) rfClkShow();
}

void
rfClkShow(void)
{
    int i, m, r, v;
    static uint16_t chDiv[32] = {
     2, 4, 6, 8, 12, 16, 24, 32, 48, 64, 72, 96, 128, 192, 256, 384, 512, 768};

    for (i = 0 ; i < LMX2594_MUX_SEL_SIZE ; i++) {
        m = lmx2594MuxSel[i];

        /*
         * Configure STATUS pin to readback
         */
        int v0 = lmx2594v0InitValues[m];
        lmx2594write(m, v0 & ~0x4);

        r = lmx2594read(m, 110);
        printf("LMX2594 %c:\n", i + 'A');
        printf("       rb_VCO_SEL: %d\n", (r >> 5) & 0x7);
        v = (r >> 9) & 0x3;
        printf("      rb_LD_VTUNE: %s\n", vTuneNames[v]);
        r = lmx2594read(m, 111);
        printf("   rb_VCO_CAPCTRL: %d\n", r & 0xFF);
        r = lmx2594read(m, 112);
        printf("   rb_VCO_DACISET: %d\n", r & 0x1FF);
        r = lmx2594read(m, 9);
        printf("           OSC_2X: %d\n", (r >> 12) & 0x1);
        r = lmx2594read(m, 10);
        printf("             MULT: %d\n", (r >> 7) & 0x1F);
        r = lmx2594read(m, 11);
        printf("            PLL_R: %d\n", (r >> 4) & 0xFF);
        r = lmx2594read(m, 12);
        printf("        PLL_R_PRE: %d\n", r & 0xFFF);
        r = lmx2594read(m, 34);
        v = lmx2594read(m, 36);
        printf("            PLL_N: %d\n", ((r & 0x7) << 16) | v);
        r = lmx2594read(m, 42);
        v = lmx2594read(m, 43);
        if (r || v) {
            printf("          PLL_NUM: %d\n", (r << 16) | v);
            r = lmx2594read(m, 38);
            v = lmx2594read(m, 39);
            printf("          PLL_DEN: %d\n", (r << 16) | v);
        }
        r = (lmx2594read(m, 75) >> 6) & 0x1F;
        v = chDiv[r];
        if (v) {
            printf("            CHDIV: %d\n", v);
        }
        else {
            printf("            CHDIV: %#x\n", r);
        }
        r = lmx2594read(m, 31);
        printf("       CHDIV_DIV2: %#x\n", (r >> 14) & 0x1);
        r = lmx2594read(m, 44);
        printf("          OUTA_PD: %x\n", (r >> 6) & 0x1);
        printf("          OUTB_PD: %x\n", (r >> 7) & 0x1);

        /*
         * Configure STATUS pin to lock detect
         */
        lmx2594write(m, v0 | 0x4);
    }
}

int
lmx2594Status(void)
{
    int i, m;
    int v = 0;

    for (i = 0 ; i < LMX2594_MUX_SEL_SIZE ; i++) {
        m = lmx2594MuxSel[i];
        /*
         * Configure STATUS pin to readback
         */
        int v0 = lmx2594v0InitValues[m];
        lmx2594write(m, v0 & ~0x4);

        v |= ((lmx2594read(m, 110) >> 9) & 0x3) << (i * 4);

        /*
         * Configure STATUS pin to lock detect
         */
        lmx2594write(m, v0 | 0x4);
    }
    return v;
}

/*
 * Copy file to Local Oscillator EEPROM
 */
#define RFCLK_TABLE_CAPACITY                512
#define RFCLK_TABLE_BUF_SIZE                (2+RFCLK_TABLE_CAPACITY)

static int32_t rfClkTableBuf[RFCLK_TABLE_BUF_SIZE];

struct rfClkTable {
    int32_t     table[RFCLK_TABLE_BUF_SIZE];
    void        (*writeToChip)(const uint32_t *, int);
    const char  *name;
};

static struct rfClkTable rfClkTables[RFCLK_TABLE_NUM_DEVICES] = {
    {
        .name = "/"LMK04XX_TABLE_EEPROM_NAME,
        .writeToChip = lmk04xxConfig,
    },
    {
        .name = "/"LMX2594_ADC_TABLE_EEPROM_NAME,
        .writeToChip = lmx2594ADCConfig,
    },
    {
        .name = "/"LMX2594_DAC_TABLE_EEPROM_NAME,
        .writeToChip = lmx2594DACConfig,
    },
};

/*
 * Form checksum
 */
static int32_t
checkSum(const int32_t *ip, int rowCount)
{
    int r;
    int32_t sum = 0xF00D8421;

    sum += *ip++;
    ip++;
    for (r = 0 ; r < rowCount ; r++) {
        sum += *ip++ + r;
    }
    return sum;
}

/*
 * Commit table to FPGA
 */
static void
rfClkGenWrite(unsigned int index, int32_t *dst, const int32_t *src, int capacity)
{
    int rowCount;
    size_t hdrSizeWords = 2; // Row count and checksum

    rowCount = src[0];
    if ((rowCount >= 10)
     && (rowCount < capacity)
     && (src[1] == checkSum(src, rowCount))) {
        if (dst) {
            memcpy(dst, src, hdrSizeWords*sizeof(*src));
            dst+=hdrSizeWords;
        }
        src+=hdrSizeWords;

        void (*funcp)(const uint32_t *, int) = rfClkTables[index].writeToChip;
        if (funcp) {
            (*funcp)((const uint32_t *)src, rowCount);
        }

        if (dst) {
            memcpy(dst, src, rowCount);
        }
    }
    else {
        printf("rfClkGen: CORRUPT RFCLK GENERATION TABLE\n");
    }
}

static void
rfClkGenCommit(unsigned int index)
{
    Xil_AssertVoid(index < RFCLK_TABLE_NUM_DEVICES);

    int32_t *src = rfClkTables[index].table;
    int capacity = RFCLK_TABLE_CAPACITY;

    rfClkGenWrite(index, NULL, src, capacity);
}

void
rfClkLMK04xxCommit()
{
    rfClkGenCommit(RFCLK_TABLE_LMK04XX_INDEX);
}

void
rfClkLMX2594ADCCommit()
{
    rfClkGenCommit(RFCLK_TABLE_LMX2594ADC_INDEX);
}

void
rfClkLMX2594DACCommit()
{
    rfClkGenCommit(RFCLK_TABLE_LMX2594DAC_INDEX);
}

/*
 * Called when complete file has been uploaded to the TFTP server
 */
static int
rfClkSetTable(unsigned char *buf, int size, unsigned int index)
{
    int r;
    int capacity = RFCLK_TABLE_CAPACITY;
    int32_t *table = rfClkTables[index].table;
    int32_t *ip = &table[2];
    int byteCount;
    unsigned char *cp = buf;

    for (r = 0 ; r < capacity ; r++) {
       char expectedEnd = '\n';
       char *endp;
       int x;

       x = strtol((char *)cp, &endp, 0);
       if ((*endp != expectedEnd)
        && ((expectedEnd == '\n') && (*endp != '\r'))) {
           sprintf((char *)buf, "Unexpected characters on line %d: %c (expected %c)",
                   r + 1, *endp, expectedEnd);
           printf("rfClkSetTable: Unexpected characters on line %d: %c (expected %c)\n",
                   r + 1, *endp, expectedEnd);
           return -1;
       }

       *ip++ = x;
       cp = (unsigned char *)endp + 1;
       if ((cp - buf) >= size) {
           if (r < 10) {
               sprintf((char *)buf, "Too short at line %d", r + 1);
               printf("rfClkSetTable: Too short at line %d, size = %d\n", r + 1, size);
               return -1;
           }
           table[0] = r + 1;
           table[1] = checkSum(&table[0], r + 1);
           byteCount = (ip - table) * sizeof(*ip);
           memcpy(buf, table, byteCount);
           return byteCount;
       }
    }

    sprintf((char *)buf, "Too long at line %d", r + 1);
    printf("rfClkSetTable: Too long at line %d\n", r + 1);
    return -1;
}

/*
 * Called when table is to be downloaded from the TFTP server
 */
static int
rfClkGetTable(unsigned char *buf, unsigned int index)
{
    int r, rowCount;
    int32_t *table = rfClkTables[index].table;
    unsigned char *cp = buf;

    rowCount = table[0];
    table += 2;
    for (r = 0 ; r < rowCount ; r++) {
        int i;
        char sep = '\n';
        int x = *table++;
        i = sprintf((char *)cp, "%u%c", x, sep);
        cp += i;
    }
    return cp - buf;
}

int
rfClkFetchEEPROM(unsigned int index)
{
    Xil_AssertNonvoid(index < RFCLK_TABLE_NUM_DEVICES);

    const char *name = rfClkTables[index].name;
    int nRead;
    FRESULT fr;
    FIL fil;
    UINT nWritten;

    fr = f_open(&fil, name, FA_WRITE | FA_CREATE_ALWAYS);
    if (fr != FR_OK) {
        return -1;
    }

    nRead = rfClkGetTable((unsigned char *)rfClkTableBuf, index);
    if (nRead <= 0) {
        f_close(&fil);
        return -1;
    }

    fr = f_write(&fil, rfClkTableBuf, nRead, &nWritten);
    if (fr != FR_OK) {
        f_close(&fil);
        return -1;
    }

    f_close(&fil);
    return nWritten;
}

int
rfClkFetchLMK04xxEEPROM()
{
    return rfClkFetchEEPROM(RFCLK_TABLE_LMK04XX_INDEX);
}

int
rfClkFetchLMX2594ADCEEPROM()
{
    return rfClkFetchEEPROM(RFCLK_TABLE_LMX2594ADC_INDEX);
}

int
rfClkFetchLMX2594DACEEPROM()
{
    return rfClkFetchEEPROM(RFCLK_TABLE_LMX2594DAC_INDEX);
}

int
rfClkStashEEPROM(unsigned int index)
{
    Xil_AssertNonvoid(index < RFCLK_TABLE_NUM_DEVICES);

    const char *name = rfClkTables[index].name;
    int nWrite;
    FRESULT fr;
    FIL fil;
    UINT nRead;

    fr = f_open(&fil, name, FA_READ);
    if (fr != FR_OK) {
        return -1;
    }

    fr = f_read(&fil, rfClkTableBuf, sizeof(rfClkTableBuf), &nRead);
    if (fr != FR_OK) {
        printf("rfClkStashEEPROM: register file (%s) read failed\n", name);
        f_close(&fil);
        return -1;
    }
    if (nRead == 0) {
        f_close(&fil);
        return 0;
    }

    nWrite = rfClkSetTable((unsigned char *)rfClkTableBuf, nRead, index);
    f_close(&fil);

    return nWrite;
}

int
rfClkStashLMK04xxEEPROM()
{
    return rfClkStashEEPROM(RFCLK_TABLE_LMK04XX_INDEX);
}

int
rfClkStashLMX2594ADCEEPROM()
{
    return rfClkStashEEPROM(RFCLK_TABLE_LMX2594ADC_INDEX);
}

int
rfClkStashLMX2594DACEEPROM()
{
    return rfClkStashEEPROM(RFCLK_TABLE_LMX2594DAC_INDEX);
}
