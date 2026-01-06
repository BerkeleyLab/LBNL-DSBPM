#include <stdio.h>
#include <xil_io.h>
#include <lwip/def.h>
#include <stdbool.h>
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
    netDefault.ipv4.address = IP4_FORMAT(192, 168, 1, 128);
    netDefault.ipv4.netmask = IP4_FORMAT(255, 255, 255, 0);
    netDefault.ipv4.gateway = IP4_FORMAT(192, 168, 1, 1);
    netDefault.useDHCP = 0;
    systemParametersDefault.netConfig = netDefault;
    systemParametersDefault.userMGTrefClkOffsetPPM = 0;
    systemParametersDefault.startupDebugFlags = 0;
    systemParametersDefault.rfDivisor = 328;
    systemParametersDefault.pllMultiplier = 81;
    systemParametersDefault.isSinglePass = 0;
    systemParametersDefault.singlePassEvent = 0;
    systemParametersDefault.adcHeartbeatMarker = 152 * 81 * 1000 * 10;
    systemParametersDefault.evrPerFaMarker = 152 * 82;
    systemParametersDefault.evrPerSaMarker = 152 * 82 * 1000;
    systemParametersDefault.rfdcMMCMDivClkDivider = ADC_CLK_MMCM_DIVCLK_DIVIDER;
    systemParametersDefault.rfdcMMCMMultiplier = ADC_CLK_MMCM_MULTIPLIER;
    systemParametersDefault.rfdcMMCMClk0Divider = ADC_CLK_MMCM_CLK0_DIVIDER;
    systemParametersDefault.rfdcMMCMClk1Divider = ADC_CLK_MMCM_CLK1_DIVIDER;
    // position calc order:
    //   A = 3, B = 1, C = 2, D = 0
    systemParametersDefault.adcOrder = 123;
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
    bool        visited;
    char     *(*format)(const void *val);
    int       (*parse)(const char *str, void *val);
} conv[] = {
    {
        .name = "Ethernet Address",
        .offset = offsetof(struct systemParameters, netConfig.ethernetMAC),
        .visited = false,
        .format = formatMAC,
        .parse= parseMAC,
    },
    {
        .name = "Use DHCP",
        .offset = offsetof(struct systemParameters, netConfig.useDHCP),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "IP Address",
        .offset = offsetof(struct systemParameters, netConfig.ipv4.address),
        .visited = false,
        .format = formatIP,
        .parse = parseIP,
    },
    {
        .name = "IP Netmask",
        .offset = offsetof(struct systemParameters, netConfig.ipv4.netmask),
        .visited = false,
        .format = formatIP,
        .parse = parseIP,
    },
    {
        .name = "IP Gateway",
        .offset = offsetof(struct systemParameters, netConfig.ipv4.gateway),
        .visited = false,
        .format = formatIP,
        .parse = parseIP,
    },
    {
        .name = "User MGT ref offset",
        .offset = offsetof(struct systemParameters, userMGTrefClkOffsetPPM),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "Startup debug flags",
        .offset = offsetof(struct systemParameters, startupDebugFlags),
        .visited = false,
        .format = formatHex,
        .parse = parseHex,
    },
    {
        .name = "PLL RF divisor",
        .offset = offsetof(struct systemParameters, rfDivisor),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "PLL multiplier",
        .offset = offsetof(struct systemParameters, pllMultiplier),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "Single pass?",
        .offset = offsetof(struct systemParameters, isSinglePass),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "Single pass event",
        .offset = offsetof(struct systemParameters, singlePassEvent),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "ADC clocks per heartbeat",
        .offset = offsetof(struct systemParameters, adcHeartbeatMarker),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "EVR clocks per fast acquisition",
        .offset = offsetof(struct systemParameters, evrPerFaMarker),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "EVR clocks per slow acquisition",
        .offset = offsetof(struct systemParameters, evrPerSaMarker),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "ADC for button ABCD",
        .offset = offsetof(struct systemParameters, adcOrder),
        .visited = false,
        .format = formatInt4,
        .parse = parseInt,
    },
    {
        .name = "RFDC MMCM DivClk Divider",
        .offset = offsetof(struct systemParameters, rfdcMMCMDivClkDivider),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "RFDC MMCM Clk Multiplier",
        .offset = offsetof(struct systemParameters, rfdcMMCMMultiplier),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "RFDC MMCM Clk0 Divider",
        .offset = offsetof(struct systemParameters, rfdcMMCMClk0Divider),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "RFDC MMCM Clk1 Divider",
        .offset = offsetof(struct systemParameters, rfdcMMCMClk1Divider),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "X calibration (mm p.u.)",
        .offset = offsetof(struct systemParameters, xCalibration),
        .visited = false,
        .format = formatFloat,
        .parse = parseFloat,
    },
    {
        .name = "Y calibration (mm p.u.)",
        .offset = offsetof(struct systemParameters, yCalibration),
        .visited = false,
        .format = formatFloat,
        .parse = parseFloat,
    },
    {
        .name = "Q calibration (p.u.)",
        .offset = offsetof(struct systemParameters, qCalibration),
        .visited = false,
        .format = formatFloat,
        .parse = parseFloat,
    },
    {
        .name = "Button rotation (0 or 45)",
        .offset = offsetof(struct systemParameters, buttonRotation),
        .visited = false,
        .format = formatInt,
        .parse = parseInt,
    },
    {
        .name = "AFE attenuator trims (dB)",
        .offset = offsetof(struct systemParameters, afeTrim[0]),
        .visited = false,
        .format = formatAtrim,
        .parse = parseAtrim,
    },
};

/*
 * String matcher
 *   Ignore case.
 */
static int
parameterMatch(const char *name, const char *match, size_t size)
{
    if (strncasecmp(name, match, size) == 0) {
        return 1;
    }

    return 0;
}

static int
searchConvName(struct conv *cnv, size_t size,
        const char *match, size_t len)
{
    int i = 0;
    int matched = -1;

    for (i = 0; i < size; ++i) {
        if (parameterMatch(cnv[i].name, match, len) ){
            if (matched >= 0) {
                // Duplicated match
                return -1;
            }

            matched = i;
        }
    }

    // Not found
    if (matched < 0) {
        return size;
    }

    return matched;
}

static int
searchConvFirstNonVisited(struct conv *cnv, size_t size)
{
    int i = 0;

    for (i = 0; i < size; ++i) {
        if (!cnv[i].visited){
            return i;
        }
    }

    // Not found
    return size;
}

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
    int pos = 0;
    int l = 0;
    int line = 1;

    /*
     * Step 1: Parse line, which must be "<parameter_name>", <parameter_value>\n
     * Step 2: Convert <parameter_value> according to the function in "conv"
     */
    while ((cp - base) < size) {
        size_t spn = strcspn (cp, ",");
        if (((cp - base) + spn) >= size) {
            *err = "Unexpected EOF";
            return -line;
        }

        pos = searchConvName(conv, ARRAY_SIZE(conv), cp, spn);
        if (pos < 0) {
            *err = "Duplicated parameter name";
            return -line;
        }

        // Ignore unexpected values
        if (pos >= ARRAY_SIZE(conv)) {
            printf ("Skiping unexpected parameter \"%.*s\"\n",
                    (int) spn, cp);
            spn = strcspn (cp, "\n");
            cp += spn + 1;
            line++;
            continue;
        }

        // Skip ','
        cp += spn + 1;

        l = (*conv[pos].parse)(cp, (char *)sysParams + conv[pos].offset);
        if (l <= 0) {
            *err = "Invalid value";
            return -line;
        }

        cp += l;

        // Mark node as visited
        conv[pos].visited = true;

        // Skip trailing spaces and ',' until a '\n' is found
        while (((cp - base) < size)
            && (((isspace((unsigned char)*cp))) || (*cp == ','))) {
            if (*cp == '\n') {
                line++;
            }
            cp++;
        }
    }

    // Check if every node was visited
    pos = searchConvFirstNonVisited(conv, ARRAY_SIZE(conv));
    if (pos < ARRAY_SIZE(conv)) {
        *err = "Missing parameters";
        return -line;
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
    if ((sysParams->rfdcMMCMDivClkDivider < 1000)
     || (sysParams->rfdcMMCMMultiplier < 1000)
     || (sysParams->rfdcMMCMClk0Divider < 1000)
     || (sysParams->rfdcMMCMClk1Divider < 1000)) {
        printf("Bad RF MMCM parameters (must be >= 1000)\n");
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

    fr = f_read(&fil, systemParametersBuf, sizeof(systemParametersBuf)-1, &nRead);
    if (fr != FR_OK) {
        f_close(&fil);
        return -1;
    }
    if (nRead == 0) {
        f_close(&fil);
        return 0;
    }

    systemParametersBuf[nRead] = '\0';

    nWrite = systemParametersSetTable(&systemParametersCandidate,
            (unsigned char *)systemParametersBuf, nRead);
    f_close(&fil);

    return nWrite;
}

void
setDefaultIPv4Address(struct sysNetConfig *netConfig,
        struct sysNetConfig *sysParamsNetConfig,
        struct sysNetConfig *defaultNetConfig, int isRecovery)
{
    if (isRecovery) {
        netConfig->ipv4 = defaultNetConfig->ipv4;
        netConfig->useDHCP = defaultNetConfig->useDHCP;
        memcpy(netConfig->ethernetMAC, defaultNetConfig->ethernetMAC,
                sizeof (netConfig->ethernetMAC));
    }
    else {
        netConfig->useDHCP = sysParamsNetConfig->useDHCP;
#if LWIP_DHCP==1
        if (netConfig->useDHCP) {
            netConfig->ipv4.address = 0;
            netConfig->ipv4.netmask = 0;
            netConfig->ipv4.gateway = 0;
        }
        else {
            netConfig->ipv4 = sysParamsNetConfig->ipv4;
        }
#else
        netConfig->ipv4 = sysParamsNetConfig->ipv4;
#endif
        memcpy (netConfig->ethernetMAC, sysParamsNetConfig->ethernetMAC,
                sizeof (netConfig->ethernetMAC));
    }
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
