#include <stdio.h>
#include <xil_io.h>
#include <lwip/def.h>
#include "gpio.h"
#include "iic.h"
#include "systemParameters.h"
#include "user_mgt_refclk.h"
#include "util.h"
#include "ffs.h"

struct systemParameters systemParameters;

/*
 * Allow space for extra terminating '\0'
 */
#define MAX_SYSTEM_PARAMETERS_BUF_SIZE (1+MB(1))

struct sysNetConfig netDefault;

/*
 * Buffer for file I/O
 */
static unsigned char systemParametersBuf[MAX_SYSTEM_PARAMETERS_BUF_SIZE];
static int systemParametersGetTable(unsigned char *buf, int capacity);

static int
checksum(void)
{
    int i, sum = 0xCAFEF00D;
    const int *ip = (int *)&systemParameters;

    for (i = 0 ; i < ((sizeof systemParameters -
                    sizeof systemParameters.checksum) / sizeof(*ip)) ; i++)
        sum += *ip++ + i;
    if (sum == 0) sum = 0xABCD0341;
    return sum;
}

void systemParametersUpdateChecksum(void)
{
    systemParameters.checksum = checksum();
}

/*
 * Read and process values on system startup.
 * Perform sanity check on parameters read from EEPROM.
 * If they aren't good then assign default values.
 */
void
systemParametersCommit(void)
{
    netDefault.ethernetMAC[0] = 0xAA;
    netDefault.ethernetMAC[1] = 'L';
    netDefault.ethernetMAC[2] = 'B';
    netDefault.ethernetMAC[3] = 'N';
    netDefault.ethernetMAC[4] = 'L';
    netDefault.ethernetMAC[5] = 0x01;
    netDefault.ipv4.address = htonl((192<<24) | (168<<16) | (  1<< 8) | 128);
    netDefault.ipv4.netmask = htonl((255<<24) | (255<<16) | (255<< 8) | 0);
    netDefault.ipv4.gateway = htonl((192<<24) | (168<<16) | (  1<< 8) | 1);

    if (checksum() != systemParameters.checksum) {
        printf("\n====== ASSIGNING DEFAULT PARAMETERS ===\n\n");
        systemParameters.netConfig = netDefault;
        systemParameters.userMGTrefClkOffsetPPM = 0;
        systemParameters.startupDebugFlags = 0;
        systemParameters.rfDivisor = 328;
        systemParameters.pllMultiplier = 81;
        systemParameters.isSinglePass = 0;
        systemParameters.adcHeartbeatMarker = 152 * 82 * 2000;
        systemParameters.evrPerFaMarker = 152 * 82;
        systemParameters.evrPerSaMarker = 152 * 82 * 1000;
        // position calc order = A = 3, B = 1, C = 2, D = 0
        systemParameters.adcOrder = 3120;
        systemParameters.xCalibration = 16.0;
        systemParameters.yCalibration = 16.0;
        systemParameters.qCalibration = 16.0;
        systemParameters.buttonRotation = 45;
        memset(systemParameters.afeTrim, 0, sizeof systemParameters.afeTrim);
    }
    debugFlags = systemParameters.startupDebugFlags;
    if (userMGTrefClkAdjust(systemParameters.userMGTrefClkOffsetPPM)) {
        systemParametersShowUserMGTrefClkOffsetPPM();
    }
}

/*
 * Serializer/deserializers
 * Note -- Format routines share common static buffer.
 */
static char cbuf[40];
char *
formatMAC(const void *val)
{
    const unsigned char *addr = (const unsigned char *)val;
    sprintf(cbuf, "%02X:%02X:%02X:%02X:%02X:%02X", addr[0], addr[1], addr[2],
                                                   addr[3], addr[4], addr[5]);
    return cbuf;
}

int
parseMAC(const char *str, void *val)
{
    const char *cp = str;
    int i = 0;
    long l;
    char *endp;

    for (;;) {
        l = strtol(cp, &endp, 16);
        if ((l < 0) || (l > 255))
            return -1;
        *((uint8_t*)val + i) = l;
        if (++i == 6)
            return endp - str;
        if (*endp++ != ':')
            return -1;
        cp = endp;
    }
}

char *
formatIP(const void *val)
{
    uint32_t l = ntohl(*(uint32_t *)val);
    sprintf(cbuf, "%d.%d.%d.%d", (int)(l >> 24) & 0xFF, (int)(l >> 16) & 0xFF,
                                 (int)(l >>  8) & 0xFF, (int)(l >>  0) & 0xFF);
    return cbuf;
}

int
parseIP(const char *str, void *val)
{
    const char *cp = str;
    uint32_t addr = 0;
    int i = 0;
    long l;
    char *endp;

    for (;;) {
        l = strtol(cp, &endp, 10);
        if ((l < 0) || (l > 255))
            return -1;
        addr = (addr << 8) | l;
        if (++i == 4) {
            *(uint32_t *)val = htonl(addr);
            return endp - str;
        }
        if (*endp++ != '.')
            return -1;
        cp = endp;
    }
}

static char *
formatAtrim(const void *val)
{
    int i;
    const int *ip = (const int *)val;
    char *cp = cbuf;
    for (i = 0 ; ; ) {
        cp += sprintf(cp, "%g", (float)*ip++ / 4.0);
        if (++i >=
            sizeof systemParameters.afeTrim/sizeof systemParameters.afeTrim[0])
            break;
        *cp++ = ' ';
    }
    return cbuf;
}

static int
parseAtrim(const char *str, void *val)
{
    const char *cp = str;
    int *ip = (int *)val;
    const char *term = " ";
    int i = 0;
    int n =  sizeof systemParameters.afeTrim/sizeof systemParameters.afeTrim[0];
    double d;
    char *endp;

    for (;;) {
        d = strtod(cp, &endp);
        if ((d < 0) || (d >= 1.8)) return -1;
        if ((endp != cp) && (strchr(term, *endp) != NULL)) {
            *ip++ = (d * 4.0) + 0.5;
            i++;
            if (i == (n - 1)) term = "\r\n";
            else if (i == n) return endp - str;
        }
        if (strchr("\r\n", *endp) != NULL) return -1;
        cp = endp + 1;
    }
}

#if 0  // Unused for now -- '#if'd out to inhibit unused function warning */
static char *formatDouble(void *val)
{
    sprintf(cbuf, "%.15g", *(double *)val);
    return cbuf;
}
#endif

static int
parseDouble(const char *str, void *val)
{
    char *endp;
    double d = strtod(str, &endp);
    if ((endp != str)
     && ((*endp == ',') || (*endp == '\r') || (*endp == '\n'))) {
        *(double *)val = d;
        return endp - str;
    }
    return -1;
}

static char *
formatFloat(const void *val)
{
    sprintf(cbuf, "%.7g", *(const float *)val);
    return cbuf;
}

static int
parseFloat(const char *str, void *val)
{
    int i;
    double d;

    i = parseDouble(str, &d);
    if (i > 0)
        *(float *)val = d;
    return i;
}

static char *
formatInt(const void *val)
{
    sprintf(cbuf, "%d", *(const int *)val);
    return cbuf;
}

static int
parseInt(const char *str, void *val)
{
    int i;
    double d;

    i = parseDouble(str, &d);
    if ((i > 0) && ((int)d == d))
        *(int *)val = d;
    return i;
}

static char *
formatInt4(const void *val)
{
    sprintf(cbuf, "%04d", *(const int *)val);
    return cbuf;
}

static int
parseHex(const char *str, void *val)
{
    char *endp;
    int d = strtol(str, &endp, 16);
    if ((endp != str)
     && ((*endp == ',') || (*endp == '\r') || (*endp == '\n'))) {
        *(unsigned long *)val = d;
        return endp - str;
    }
    return -1;
}

static char *
formatHex(const void *val)
{
    sprintf(cbuf, "0x%x", *(const int *)val);
    return cbuf;
}

/*
 * Conversion table
 */
static struct conv {
    const char *name;
    void       *addr;
    char     *(*format)(const void *val);
    int       (*parse)(const char *str, void *val);
} conv[] = {
  {"Ethernet Address", &systemParameters.netConfig.ethernetMAC,formatMAC,  parseMAC},
  {"IP Address",       &systemParameters.netConfig.ipv4.address,    formatIP,   parseIP},
  {"IP Netmask",       &systemParameters.netConfig.ipv4.netmask,    formatIP,   parseIP},
  {"IP Gateway",       &systemParameters.netConfig.ipv4.gateway,    formatIP,   parseIP},
  {"User MGT ref offset", &systemParameters.userMGTrefClkOffsetPPM,  formatInt,   parseInt},
  {"Startup debug flags", &systemParameters.startupDebugFlags,  formatHex,   parseHex},
  {"PLL RF divisor",   &systemParameters.rfDivisor,      formatInt,  parseInt},
  {"PLL multiplier",   &systemParameters.pllMultiplier,  formatInt,  parseInt},
  {"Single pass?",     &systemParameters.isSinglePass,   formatInt,  parseInt},
  {"ADC clocks per heartbeat",
                       &systemParameters.adcHeartbeatMarker, formatInt,  parseInt},
  {"EVR clocks per fast acquisition",
                       &systemParameters.evrPerFaMarker, formatInt,  parseInt},
  {"EVR clocks per slow acquisition",
                       &systemParameters.evrPerSaMarker, formatInt,  parseInt},
  {"ADC for button ABCD",
                       &systemParameters.adcOrder,      formatInt4,  parseInt},
  {"X calibration (mm p.u.)",
                       &systemParameters.xCalibration, formatFloat,parseFloat},
  {"Y calibration (mm p.u.)",
                       &systemParameters.yCalibration, formatFloat,parseFloat},
  {"Q calibration (p.u.)",
                       &systemParameters.qCalibration, formatFloat,parseFloat},
  {"Button rotation (0 or 45)",
                       &systemParameters.buttonRotation, formatInt,  parseInt},
  {"AFE attenuator trims (dB)",
                       &systemParameters.afeTrim[0],   formatAtrim,parseAtrim},
};

/*
 * Serialize/deserialize complete table
 */
int
systemParametersGetTable(unsigned char *buf, int capacity)
{
    char *cp = (char *)buf;
    int i;

    for (i = 0 ; i < (sizeof conv / sizeof conv[0]) ; i++)
        cp += sprintf(cp, "%s,%s\n", conv[i].name, (*conv[i].format)(conv[i].addr));
    return cp - (char *)buf;
}

/*
 * EEPROM I/O
 */
int
systemParametersFetchEEPROM(void)
{
    const char *name = SYSTEM_PARAMETERS_NAME;
    int nRead;
    FRESULT fr;
    FIL fil;
    UINT nWritten;

    fr = f_open(&fil, name, FA_WRITE | FA_CREATE_ALWAYS);
    if (fr != FR_OK) {
        return -1;
    }

    nRead = systemParametersGetTable((unsigned char *)systemParametersBuf,
            sizeof(systemParametersBuf));
    if (nRead <= 0) {
        f_close(&fil);
        return -1;
    }

    fr = f_write(&fil, systemParametersBuf, nRead, &nWritten);
    if (fr != FR_OK) {
        f_close(&fil);
        return -1;
    }

    f_close(&fil);
    return nWritten;
}

static int
parseTable(unsigned char *buf, int size, char **err)
{
    const char *base = (const char *)buf;
    const char *cp = base;
    int i, l;
    int line = 1;

    for (i = 0 ; i < (sizeof conv / sizeof conv[0]) ; i++) {
        l = strlen(conv[i].name);
        if (((cp - base) + l + 2) >= size) {
            *err = "Unexpected EOF";
            return -line;
        }
        if (strncmp(cp, conv[i].name, l) != 0) {
            *err = "Unexpected parameter name";
            return -line;
        }
        cp += l;
        if (*cp++ != ',') {
            *err = "Missing comma after parameter name";
            return -line;
        }
        l = (*conv[i].parse)(cp, conv[i].addr);
        if (l <= 0) {
            *err = "Invalid value";
            return -line;
        }
        cp += l;
        while (((cp - base) < size)
            && (((isspace((unsigned char)*cp))) || (*cp == ','))) {
            if (*cp == '\n')
                line++;
            cp++;
        }
    }
    return cp - base;
}

static int
systemParametersSetTable(unsigned char *buf, int size)
{
    char *err = "";
    int i = parseTable(buf, size, &err);

    if (i <= 0) {
        printf("Bad file contents at line %d: %s\n", -i, err);
        return -1;
    }
    if (systemParameters.buttonRotation == 90)
        systemParameters.buttonRotation = 0;
    if ((systemParameters.buttonRotation != 0)
     && (systemParameters.buttonRotation != 45)) {
        printf("Bad button rotation (must be 0 or 45)\n");
        return -1;
    }
    systemParametersUpdateChecksum();
    memcpy(buf, &systemParameters, sizeof systemParameters);
    return sizeof(systemParameters);
}

int
systemParametersStashEEPROM(void)
{
    const char *name = SYSTEM_PARAMETERS_NAME;
    int nWrite;
    FRESULT fr;
    FIL fil;
    UINT nRead;

    fr = f_open(&fil, name, FA_READ);
    if (fr != FR_OK) {
        printf("System parameters file open failed, name = %s\n", name);
        return -1;
    }

    fr = f_read(&fil, systemParametersBuf, sizeof(systemParametersBuf), &nRead);
    if (fr != FR_OK) {
        printf("System parameters file read failed\n");
        f_close(&fil);
        return -1;
    }
    if (nRead == 0) {
        f_close(&fil);
        return 0;
    }

    nWrite = systemParametersSetTable((unsigned char *)systemParametersBuf, nRead);
    f_close(&fil);

    return nWrite;
}

/*
 * Print configuration routines
 */
void
showNetworkConfiguration(const struct sysNetParms *ipv4)
{
    printf("   IP ADDR: %s\n", formatIP(&ipv4->address));
    printf("  NET MASK: %s\n", formatIP(&ipv4->netmask));
    printf("   GATEWAY: %s\n", formatIP(&ipv4->gateway));
}

void
systemParametersShowUserMGTrefClkOffsetPPM(void)
{
    printf("User MGT reference clock offset: %d PPM\n",
                                       systemParameters.userMGTrefClkOffsetPPM);
}
