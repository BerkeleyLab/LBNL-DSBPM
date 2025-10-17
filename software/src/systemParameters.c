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
struct systemParameters systemParametersCandidate;

/*
 * Allow space for extra terminating '\0'
 */
#define MAX_SYSTEM_PARAMETERS_BUF_SIZE (1+MB(1))

struct sysNetConfig netDefault;
struct sysNetConfig currentNetConfig;
struct systemParameters systemParametersDefault;

/*
 * Buffer for file I/O
 */
static unsigned char systemParametersBuf[MAX_SYSTEM_PARAMETERS_BUF_SIZE];
static int systemParametersGetTable(unsigned char *buf, int capacity,
        const struct systemParameters* sysParams);
static int systemParametersSetTable(struct systemParameters* sysParams,
        const unsigned char *buf, int size);

static int
checksum(struct systemParameters *sysParams)
{
    int i, sum = 0xCAFEF00D;
    const int *ip = (int *)sysParams;

    for (i = 0 ; i < ((sizeof *sysParams -
                    sizeof sysParams->checksum) / sizeof(*ip)) ; i++)
        sum += *ip++ + i;
    if (sum == 0) sum = 0xABCD0341;
    return sum;
}

static
void systemParametersUpdateChecksum(struct systemParameters *sysParams)
{
    sysParams->checksum = checksum(sysParams);
}

void
systemParametersSetDefaults(void)
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
    systemParametersDefault.netConfig = netDefault;
    systemParametersDefault.userMGTrefClkOffsetPPM = 0;
    systemParametersDefault.startupDebugFlags = 0;
    systemParametersDefault.rfDivisor = 328;
    systemParametersDefault.pllMultiplier = 81;
    systemParametersDefault.isSinglePass = 0;
    systemParameters.singlePassEvent = 0;
    systemParametersDefault.adcHeartbeatMarker = 152 * 81 * 1000 * 10;
    systemParametersDefault.evrPerFaMarker = 152 * 82;
    systemParametersDefault.evrPerSaMarker = 152 * 82 * 1000;
    // position calc order:
    //   A = 3, B = 1, C = 2, D = 0
    systemParametersDefault.adcOrder = 3120;
    // ADC logical order:
    //   ADC_0 = 4, ADC_1 = 5, ADC_2 = 6, ADC_3 = 7
    //   ADC_4 = 0, ADC_5 = 1, ADC_6 = 2, ADC_7 = 3
    systemParametersDefault.xCalibration = 16.0;
    systemParametersDefault.yCalibration = 16.0;
    systemParametersDefault.qCalibration = 16.0;
    systemParametersDefault.buttonRotation = 45;
    memset(systemParametersDefault.afeTrim, 0, sizeof systemParametersDefault.afeTrim);
}

/*
 * Read and process values on system startup.
 * Perform sanity check on parameters read from EEPROM.
 * If they aren't good then assign default values.
 */
void
systemParametersCommit(void)
{
    if (checksum(&systemParametersCandidate) != systemParametersCandidate.checksum) {
        printf("\n====== ASSIGNING DEFAULT PARAMETERS ===\n\n");
        systemParametersCandidate = systemParametersDefault;
    }

    systemParameters = systemParametersCandidate;
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
    size_t      offset;
    char     *(*format)(const void *val);
    int       (*parse)(const char *str, void *val);
} conv[] = {
  {"Ethernet Address", offsetof(struct systemParameters, netConfig.ethernetMAC), formatMAC,  parseMAC},
  {"IP Address",       offsetof(struct systemParameters, netConfig.ipv4.address),     formatIP,   parseIP},
  {"IP Netmask",       offsetof(struct systemParameters, netConfig.ipv4.netmask),     formatIP,   parseIP},
  {"IP Gateway",       offsetof(struct systemParameters, netConfig.ipv4.gateway),     formatIP,   parseIP},
  {"User MGT ref offset", offsetof(struct systemParameters, userMGTrefClkOffsetPPM),   formatInt,   parseInt},
  {"Startup debug flags", offsetof(struct systemParameters, startupDebugFlags),   formatHex,   parseHex},
  {"PLL RF divisor",   offsetof(struct systemParameters, rfDivisor),       formatInt,  parseInt},
  {"PLL multiplier",   offsetof(struct systemParameters, pllMultiplier),   formatInt,  parseInt},
  {"Single pass?",     offsetof(struct systemParameters, isSinglePass),    formatInt,  parseInt},
  {"Single pass event",offsetof(struct systemParameters, singlePassEvent), formatInt,  parseInt},
  {"ADC clocks per heartbeat",
                       offsetof(struct systemParameters, adcHeartbeatMarker),  formatInt,  parseInt},
  {"EVR clocks per fast acquisition",
                       offsetof(struct systemParameters, evrPerFaMarker),  formatInt,  parseInt},
  {"EVR clocks per slow acquisition",
                       offsetof(struct systemParameters, evrPerSaMarker),  formatInt,  parseInt},
  {"ADC for button ABCD",
                       offsetof(struct systemParameters, adcOrder),       formatInt4,  parseInt},
  {"X calibration (mm p.u.)",
                       offsetof(struct systemParameters, xCalibration),  formatFloat,parseFloat},
  {"Y calibration (mm p.u.)",
                       offsetof(struct systemParameters, yCalibration),  formatFloat,parseFloat},
  {"Q calibration (p.u.)",
                       offsetof(struct systemParameters, qCalibration),  formatFloat,parseFloat},
  {"Button rotation (0 or 45)",
                       offsetof(struct systemParameters, buttonRotation),  formatInt,  parseInt},
  {"AFE attenuator trims (dB)",
                       offsetof(struct systemParameters, afeTrim[0]),   formatAtrim,parseAtrim},
};

/*
 * Serialize/deserialize complete table
 */
int
systemParametersGetTable(unsigned char *buf, int capacity,
        const struct systemParameters* sysParams)
{
    char *cp = (char *)buf;
    int i;

    for (i = 0 ; i < (sizeof conv / sizeof conv[0]) ; i++)
        cp += sprintf(cp, "%s,%s\n", conv[i].name, (*conv[i].format)(
                    (char *) sysParams + conv[i].offset));
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
            sizeof(systemParametersBuf), &systemParameters);
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
parseTable(struct systemParameters *sysParams,
        const unsigned char *buf, int size, char **err)
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

        l = (*conv[i].parse)(cp, (char *)sysParams + conv[i].offset);
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

int
systemParametersSetTable(struct systemParameters *sysParams,
        const unsigned char *buf, int size)
{
    char *err = "";
    int i = parseTable(sysParams, buf, size, &err);

    if (i <= 0) {
        printf("Bad file contents at line %d: %s\n", -i, err);
        return -1;
    }
    if (sysParams->buttonRotation == 90)
        sysParams->buttonRotation = 0;
    if ((sysParams->buttonRotation != 0)
     && (sysParams->buttonRotation != 45)) {
        printf("Bad button rotation (must be 0 or 45)\n");
        return -1;
    }
    systemParametersUpdateChecksum(sysParams);
    return sizeof (*sysParams);
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
        return -1;
    }

    fr = f_read(&fil, systemParametersBuf, sizeof(systemParametersBuf), &nRead);
    if (fr != FR_OK) {
        f_close(&fil);
        return -1;
    }
    if (nRead == 0) {
        f_close(&fil);
        return 0;
    }

    nWrite = systemParametersSetTable(&systemParametersCandidate,
            (unsigned char *)systemParametersBuf, nRead);
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
