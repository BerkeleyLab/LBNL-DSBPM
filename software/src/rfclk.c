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

// Default LMK values
static const uint32_t lmk04828BDefaults[] = {
#include "lmk04828B.h"
};

#define LMK04828B_SIZE (sizeof lmk04828BDefaults/sizeof lmk04828BDefaults[0])

// Default ADC values
static const uint32_t lmx2594ADCDefaults[] = {
#include "lmx2594ADC.h"
};

// Default DAC values
const uint32_t lmx2594DACDefaults[] = {
#include "lmx2594DAC.h"
};

#define LMX2594ADC_SIZE (sizeof lmx2594ADCDefaults/sizeof lmx2594ADCDefaults[0])
#define LMX2594DAC_SIZE (sizeof lmx2594DACDefaults/sizeof lmx2594DACDefaults[0])

/*
 * Copy file to Local Oscillator EEPROM
 */
#define RFCLK_TABLE_CAPACITY                512
#define RFCLK_TABLE_BUF_SIZE                (2+RFCLK_TABLE_CAPACITY)

static int32_t rfClkConfigBuf[RFCLK_TABLE_BUF_SIZE];

struct rfClkConfig {
    uint32_t        table[RFCLK_TABLE_BUF_SIZE];
    const uint32_t  *defaultValues;
    int             defaultSize;
    int             muxSel;
    void            (*writeToChip)(const uint32_t *, int);
    const char      *name;
};

static struct rfClkConfig rfClkConfigs[RFCLK_TABLE_NUM_DEVICES] = {
    {
        .defaultValues = lmk04828BDefaults,
        .defaultSize = LMK04828B_SIZE,
        .muxSel = SPI_MUX_04828B,
        .writeToChip = lmk04xxConfig,
        .name = "/"LMK04XX_TABLE_EEPROM_NAME,
    },
    {
        .defaultValues = lmx2594ADCDefaults,
        .defaultSize = LMX2594ADC_SIZE,
        .muxSel = SPI_MUX_2594_A_ADC,
        .writeToChip = lmx2594ADCConfig,
        .name = "/"LMX2594_ADC_TABLE_EEPROM_NAME,
    },
    {
        .defaultValues = lmx2594DACDefaults,
        .defaultSize = LMX2594DAC_SIZE,
        .muxSel = SPI_MUX_2594_B_DAC,
        .writeToChip = lmx2594DACConfig,
        .name = "/"LMX2594_DAC_TABLE_EEPROM_NAME,
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

static int
muxSelToIndex(unsigned int muxSel)
{
    int i;
    for (i = 0; i < RFCLK_TABLE_NUM_DEVICES; i++) {
        if (muxSel == rfClkConfigs[i].muxSel) {
            return i;
        }
    }

    return -1;
}

static int
tableGetRowCount(const int32_t *src, int capacity)
{
    int rowCount = src[0];

    if ((rowCount < 10)
     || (rowCount >= capacity)
     || (src[1] != checkSum(src, rowCount))) {
        return 0;
    }

    return rowCount;
}

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
    int muxSelect = SPI_MUX_2594_A_ADC;

    init2594(muxSelect, values, n);
    start2594(muxSelect);
}

void
lmx2594DACConfig(const uint32_t *values, int n)
{
    int muxSelect = SPI_MUX_2594_B_DAC;

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

    int index = muxSelToIndex(muxSelect);

    if (index < 0) {
        return -1;
    }

    const uint32_t *table = rfClkConfigs[index].table;
    int tableCapacity = RFCLK_TABLE_BUF_SIZE;

    int n = tableGetRowCount((const int32_t *)table, tableCapacity);
    if (n <= 0) {
        return -1;
    }

    int i;
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

/*
 * This is already initialized by the TFTP server, via the
 * *Fetch, *Stash, *Default functions
 */
void
rfClkInit(void)
{
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
 * Commit table to FPGA
 */
static int
rfClkGenWrite(unsigned int index, uint32_t *dst, const uint32_t *src, int capacity)
{
    int rowCount = tableGetRowCount((const int32_t *)src, capacity);
    size_t hdrSizeWords = 2; // Row count and checksum

    if (rowCount <= 0) {
        return -1;
    }

    if (dst) {
        memcpy(dst, src, hdrSizeWords*sizeof(*src));
        dst+=hdrSizeWords;
    }
    src+=hdrSizeWords;

    void (*funcp)(const uint32_t *, int) = rfClkConfigs[index].writeToChip;
    if (funcp) {
        (*funcp)((const uint32_t *)src, rowCount);
    }

    if (dst) {
        memcpy(dst, src, rowCount);
    }

    return 0;
}

static void
rfClkGenCommit(unsigned int index)
{
    Xil_AssertVoid(index < RFCLK_TABLE_NUM_DEVICES);

    uint32_t *src = rfClkConfigs[index].table;
    int capacity = RFCLK_TABLE_CAPACITY;

    if (rfClkGenWrite(index, NULL, src, capacity) < 0) {
        printf("rfClkGen: CORRUPT RFCLK GENERATION TABLE\n");
    }
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

static int
formatValuesToTable(uint32_t *table, unsigned int tableCapacity,
        const uint32_t *values, unsigned int valuesSize)
{
    if (tableCapacity < 2+valuesSize) {
        return -1;
    }

    int byteCount = valuesSize * sizeof(*values);
    memcpy(&table[2], values, byteCount);

    table[0] = valuesSize;
    table[1] = checkSum((const int32_t *)&table[0], valuesSize);

    return byteCount + 2*sizeof(*table);
}

/*
 * Called when complete file has been uploaded to the TFTP server
 */
static int
rfClkSetTable(unsigned int index, unsigned char *buf, int size)
{
    int r;
    int capacity = RFCLK_TABLE_CAPACITY;
    uint32_t *table = rfClkConfigs[index].table;
    uint32_t *ip = &table[2];
    int byteCount;
    unsigned char *cp = buf;

    for (r = 0 ; r < capacity ; r++) {
       char expectedEnd = '\n';
       char *endp;
       unsigned int x;

       x = strtoul((char *)cp, &endp, 0);
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
           table[1] = checkSum((const int32_t *)&table[0], r + 1);
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
rfClkGetTable(unsigned int index, unsigned char *buf)
{
    int r, rowCount;
    uint32_t *table = rfClkConfigs[index].table;
    unsigned char *cp = buf;

    rowCount = table[0];
    table += 2;
    for (r = 0 ; r < rowCount ; r++) {
        int i;
        char sep = '\n';
        unsigned int x = *table++;
        i = sprintf((char *)cp, "%u%c", x, sep);
        cp += i;
    }
    return cp - buf;
}

int
rfClkFetchEEPROM(unsigned int index)
{
    Xil_AssertNonvoid(index < RFCLK_TABLE_NUM_DEVICES);

    const char *name = rfClkConfigs[index].name;
    int nRead;
    FRESULT fr;
    FIL fil;
    UINT nWritten;

    fr = f_open(&fil, name, FA_WRITE | FA_CREATE_ALWAYS);
    if (fr != FR_OK) {
        return -1;
    }

    nRead = rfClkGetTable(index, (unsigned char *)rfClkConfigBuf);
    if (nRead <= 0) {
        f_close(&fil);
        return -1;
    }

    fr = f_write(&fil, rfClkConfigBuf, nRead, &nWritten);
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

    const char *name = rfClkConfigs[index].name;
    int nWrite;
    FRESULT fr;
    FIL fil;
    UINT nRead;

    fr = f_open(&fil, name, FA_READ);
    if (fr != FR_OK) {
        return -1;
    }

    fr = f_read(&fil, rfClkConfigBuf, sizeof(rfClkConfigBuf), &nRead);
    if (fr != FR_OK) {
        printf("rfClkStashEEPROM: register file (%s) read failed\n", name);
        f_close(&fil);
        return -1;
    }
    if (nRead == 0) {
        f_close(&fil);
        return 0;
    }

    nWrite = rfClkSetTable(index, (unsigned char *)rfClkConfigBuf, nRead);
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

void
rfClkDefaults(unsigned int index)
{
    Xil_AssertVoid(index < RFCLK_TABLE_NUM_DEVICES);

    const uint32_t *values = rfClkConfigs[index].defaultValues;
    int size = rfClkConfigs[index].defaultSize;
    uint32_t *src = rfClkConfigs[index].table;
    int capacity = RFCLK_TABLE_CAPACITY;

    /*
     * Format table and write to chip
     */
    if (formatValuesToTable(src, capacity, values, size) < 0) {
        printf("rfClkDefaults: COULD NOT COPY DEFAULTS VAUES TO TABLE\n");
        return;
    }

    if (rfClkGenWrite(index, NULL, src, capacity) < 0) {
        printf("rfClkDefaults: CORRUPT RFCLK GENERATION TABLE\n");
    }
}

void
rfClkLMK04xxDefaults()
{
    rfClkDefaults(RFCLK_TABLE_LMK04XX_INDEX);
}

void
rfClkLMX2594ADCDefaults()
{
    rfClkDefaults(RFCLK_TABLE_LMX2594ADC_INDEX);
}

void
rfClkLMX2594DACDefaults()
{
    rfClkDefaults(RFCLK_TABLE_LMX2594DAC_INDEX);
}
