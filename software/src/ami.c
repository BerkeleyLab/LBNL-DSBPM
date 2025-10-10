/*
 * Communicate with the Analog Module Interface SPI components
 */

#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include <limits.h>
#include "genericSPI.h"
#include "ami.h"
#include "gpio.h"
#include "rfdc.h"
#include "systemParameters.h"
#include "util.h"

#define REG(base,chan)  ((base) + (GPIO_IDX_PER_DSBPM * (chan)))

#define NUM_MCP23S08                2
#define NUM_MCP23S08_PORTS          8

#define MCP23S08_REG_ADDR           0x40
#define MCP23S08_REG_ADDR_RW        0x1

#define MUXPORT_UNKNOWN 127
#define MUXPORT_NONE    126

#define DEVINFO_CPOL_NORMAL   0
#define DEVINFO_CPOL_INV      1

#define DEVINFO_CPHA_NORMAL   0
#define DEVINFO_CPHA_DLY      1

struct deviceInfo {
    uint8_t muxPort;
    uint8_t lsbFirst;
    uint8_t wordSize24;
    uint8_t cpol;
    uint8_t cpha;
};

static const struct deviceInfo deviceTable[] = {
    { 0,    1,    0,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_NORMAL}, // AMI_SPI_INDEX_AFE_ATT_ALL
    { 1,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_AFE_0
    { 2,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_AFE_1
    { 3,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_AFE_2
    { 4,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_AFE_3
    { 5,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_PTM_0
};

#define NUM_DEVICES ARRAY_SIZE(deviceTable)

struct controller {
    struct genericSPI spi;
    uint8_t controllerIndex;
    uint8_t muxPort;
};

static struct controller controllers[] = {
    {
        .spi = {
            .gpioIdx = REG(GPIO_IDX_AMI_SPI_CSR, 0),
            .lsbFirst = 0,
            .channel = 0,
            .wordSize24 = 1,
            .cpol = DEVINFO_CPOL_NORMAL,
            .cpha = DEVINFO_CPHA_NORMAL,
            .inProgress = 0
        },
        .controllerIndex = 0,
        .muxPort = MUXPORT_NONE
    },
    {
        .spi = {
            .gpioIdx = REG(GPIO_IDX_AMI_SPI_CSR, 1),
            .lsbFirst = 0,
            .channel = 0,
            .wordSize24 = 1,
            .cpol = DEVINFO_CPOL_NORMAL,
            .cpha = DEVINFO_CPHA_NORMAL,
            .inProgress = 0
        },
        .controllerIndex = 1,
        .muxPort = MUXPORT_NONE
    },
};

#define NUM_CONTROLLERS ARRAY_SIZE(controllers)

static unsigned int amiAfeAttenuation[CFG_DSBPM_COUNT][CFG_ADC_PER_BPM_COUNT];
static unsigned int amiPtmAttenuation[CFG_DSBPM_COUNT];

static struct {
    int     deviceIndex;
    int     ampsPerVolt; /* 1/Rshunt */
    const char *name;
} const psInfo[] = {
    { AMI_SPI_INDEX_AFE_0,              0,         "AFE_0"          },
    { AMI_SPI_INDEX_AFE_1,              0,         "AFE_1"          },
    { AMI_SPI_INDEX_AFE_2,              0,         "AFE_2"          },
    { AMI_SPI_INDEX_AFE_3,              0,         "AFE_3"          },
    { AMI_SPI_INDEX_PTM_0,              0,         "PTM_0"          },
};

#define NUM_SENSORS ARRAY_SIZE(psInfo)

int
amiAfeGetSerialNumber(void)
{
    return 0;
}

static void
initController(void)
{
}

void
amiInit(void)
{
    struct controller *cp = NULL;
    int ret = 0;
    uint32_t data = 0;

    initController();

    /*
     * Configure the GPIO expander:
     * 24-bit transaction
     * MSB first
     * CSB 0
     */
    for (cp = controllers; cp < &controllers[NUM_CONTROLLERS]; ++cp) {
        genericSPISetOptions(&cp->spi, 1, 0, DEVINFO_CPOL_NORMAL,
                DEVINFO_CPHA_NORMAL, 0);

        /*
         * Configure IODIR:
         * Outputs: 0-5
         * Input 6-7
         */

        data = MCP23S08_REG_ADDR << 16;
        data |= 0x00 << 8;
        data |= 0xC0;
        ret = genericSPIWrite(&cp->spi, data);

        if (ret != 3) {
            warn("Configure MCP23S08 %d", cp->controllerIndex);
        }

        /*
         * Configure all outputs to 1:
         */

        data = MCP23S08_REG_ADDR << 16;
        data |= 0x09 << 8;
        data |= 0xFF;
        ret = genericSPIWrite(&cp->spi, data);

        if (ret != 3) {
            warn("Configure MCP23S08 %d", cp->controllerIndex);
        }
    }
}

/*
 * Set multiplexers
 */
static int
amiSetMcp23s08(struct controller *cp, unsigned int muxPort)
{
    uint32_t data = 0;

    /*
     * 24-bit transaction
     * MSB first
     * CSB 0
     */
    genericSPISetOptions(&cp->spi, 1, 0, DEVINFO_CPOL_NORMAL,
            DEVINFO_CPHA_NORMAL, 0);

    data = MCP23S08_REG_ADDR << 16;
    data |= 0x09 << 8;
    data |= muxPort & 0xFF;

    return genericSPIWrite(&cp->spi, data);
}

static int
amiSetMux(struct controller *cp, unsigned int muxPort)
{
    int bytesWritten = 0;

    if (muxPort == MUXPORT_NONE) {
        muxPort = 0xFF;
    }
    else {
        muxPort &= 0x7;
        muxPort = ~(1 << muxPort) & 0xFF;
    }

    bytesWritten = amiSetMcp23s08(cp, muxPort);

    if (bytesWritten == 3) {
        cp->muxPort = muxPort;
    }
    else {
        cp->muxPort = MUXPORT_UNKNOWN;
        return -1;
    }

    return bytesWritten;
}

static int
amiSPIWrite(unsigned int controllerIndex, unsigned int deviceIndex,
        uint32_t data)
{
    int bytesWritten = 0;
    const struct deviceInfo *dp;
    struct controller *cp;

    if (controllerIndex >= NUM_CONTROLLERS) {
        return -1;
    }

    if (deviceIndex >= NUM_DEVICES) {
        return -1;
    }

    dp = &deviceTable[deviceIndex];
    cp = &controllers[controllerIndex];

    if (amiSetMux(cp, dp->muxPort) < 0) {
        return -1;
    }

    /*
     * Only the mux is on channel 0. Everything is on channel 1
     */
    genericSPISetOptions(&cp->spi, dp->wordSize24, dp->lsbFirst, dp->cpol,
            dp->cpha, 1);
    bytesWritten = genericSPIWrite(&cp->spi, data);

    if (amiSetMux(cp, MUXPORT_NONE) < 0) {
        return -1;
    }

    return bytesWritten;
}

static int
amiSPIRead(unsigned int controllerIndex, unsigned int deviceIndex,
        uint32_t data, uint32_t *buf)
{
    const struct deviceInfo *dp;
    struct controller *cp;

    if (controllerIndex >= NUM_CONTROLLERS) {
        return -1;
    }

    if (deviceIndex >= NUM_DEVICES) {
        return -1;
    }

    dp = &deviceTable[deviceIndex];
    cp = &controllers[controllerIndex];

    if (amiSetMux(cp, dp->muxPort) < 0) {
        return -1;
    }

    /*
     * Only the mux is on channel 0. Everything is on channel 1
     */
    genericSPISetOptions(&cp->spi, dp->wordSize24, dp->lsbFirst, dp->cpol,
            dp->cpha, 1);
    return genericSPIRead(&cp->spi, data, buf);
}

/*
 * Set attenuators
 */
static int
amiAttenSet(unsigned int controllerIndex, unsigned int channel,
        int address, unsigned int mdB)
{
    unsigned int deviceIndex = AMI_SPI_INDEX_AFE_ATT_ALL;

    /*
     * Write trimmed value
     */
    int attSteps = (mdB * 4)/1000;
    if (attSteps > 127) attSteps = 127;
    else if (attSteps < 0) attSteps = 0;

    // SPI data: 8-bit address | 8-bit data
    int v = attSteps;
    v |= address << 8;

    return amiSPIWrite(controllerIndex, deviceIndex, v);
}

int
amiAfeAttenSet(unsigned int bpm, unsigned int channel,
        unsigned int mdB)
{
    const int address = 0x7;
    int bytesWritten = 0;

    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    if (channel >= CFG_ADC_PER_BPM_COUNT) {
        return -1;
    }

    // All channels are wired together
    channel = 0;
    bytesWritten = amiAttenSet(bpm, channel, address, mdB);

    if (bytesWritten >= 0) {
        amiAfeAttenuation[bpm][channel] = mdB;
    }

    return bytesWritten;
}

int
amiPtmAttenSet(unsigned int bpm, unsigned int mdB)
{
    const int address = 0x3;
    int bytesWritten = 0;

    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    // Only a single PTM module
    unsigned int channel = 0;
    bytesWritten = amiAttenSet(bpm, channel, address, mdB);

    if (bytesWritten >= 0) {
        amiPtmAttenuation[bpm] = mdB;
    }

    return bytesWritten;
}

/*
 * Get attenuators
 */
unsigned int
amiAfeAttenGet(unsigned int bpm, unsigned int channel)
{
    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    if (channel >= CFG_ADC_PER_BPM_COUNT) {
        return -1;
    }

    // All channels are wired together
    channel = 0;
    return amiAfeAttenuation[bpm][channel];
}

unsigned int
amiPtmAttenGet(unsigned int bpm)
{
    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    return amiPtmAttenuation[bpm];
}

/*
 * Get INA239 values
 */
static int
amiGetIna239(unsigned int controllerIndex, unsigned int deviceIndex,
        int address, uint32_t *buf)
{
    // SPI data: 6-bit reg address | 1b0 | 1b1 (read op) | 16-bit data (0)
    int v = 0x0000;
    v |= ((address & 0x3F) << 2 | 0x01) << 16;

    return amiSPIRead(controllerIndex, deviceIndex, v, buf);
}

static int
amiGetIna239MfrId(unsigned int controllerIndex, unsigned int deviceIndex)
{
    uint32_t buf = 0;
    int status = 0;

    status = amiGetIna239(controllerIndex, deviceIndex, 0x3E, &buf);
    if (status < 0) {
        return status;
    }

    return buf;
}

int
amiIna239MfrIdGet(unsigned int bpm, unsigned int channel)
{
    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    if (channel >= NUM_SENSORS) {
        return -1;
    }

    return amiGetIna239MfrId(bpm, psInfo[channel].deviceIndex);
}

static int
amiGetIna239DevId(unsigned int controllerIndex, unsigned int deviceIndex)
{
    uint32_t buf = 0;
    int status = 0;

    status = amiGetIna239(controllerIndex, deviceIndex, 0x3F, &buf);
    if (status < 0) {
        return status;
    }

    return buf;
}

int
amiIna239DevIdGet(unsigned int bpm, unsigned int channel)
{
    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    if (channel >= NUM_SENSORS) {
        return -1;
    }

    return amiGetIna239DevId(bpm, psInfo[channel].deviceIndex);
}

void amiPSinfoDisplay(unsigned int bpm)
{
    unsigned int channel = 0;
    int value = 0;

    if (bpm >= CFG_DSBPM_COUNT) {
        return;
    }

    printf("BPM%u:\n", bpm);

    for (channel = 0 ; channel < NUM_SENSORS; channel++) {
        printf("  PS%u %s:\n", channel, psInfo[channel].name);

        value = amiIna239MfrIdGet(bpm, channel);
        printf("    MFR ID: ");
        if (value < 0) {
            printf("Could not read\n");
        }
        else {
            printf("0x%04X\n", value);
        }

        value = amiIna239DevIdGet(bpm, channel);
        printf("    Device ID: ");
        if (value < 0) {
            printf("Could not read\n");
        }
        else {
            printf("0x%04X\n", value);
        }
    }
}
