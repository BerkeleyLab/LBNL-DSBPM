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

struct ina239RegMap {
    uint8_t addr;
};

static const struct ina239RegMap ina239RegMap[] = {
    {0x02},         // AMI_INA239_INDEX_SHUNT_CAL
    {0x04},         // AMI_INA239_INDEX_V_SHUNT
    {0x05},         // AMI_INA239_INDEX_V_BUS
    {0x06},         // AMI_INA239_INDEX_DIETEMP
    {0x07},         // AMI_INA239_INDEX_CURRENT
    {0x3E},         // AMI_INA239_INDEX_MFR
    {0x3F},         // AMI_INA239_INDEX_DEVID
};

#define NUM_INA239_INDECES ARRAY_SIZE(ina239RegMap)

#define MUXPORT_UNKNOWN 127
#define MUXPORT_NONE    126

#define DEVINFO_CPOL_NORMAL   0
#define DEVINFO_CPOL_INV      1

#define DEVINFO_CPHA_NORMAL   0
#define DEVINFO_CPHA_DLY      1

struct deviceInfo {
    uint8_t muxPort;
    // latch enable means a pulse at the end
    // of an SPI transaction. Otherwise normal
    // CSB behavior
    uint8_t latchEn;
    uint8_t lsbFirst;
    uint8_t wordSize24;
    uint8_t cpol;
    uint8_t cpha;
};

static const struct deviceInfo deviceTable[] = {
    { 0,    1,    1,    0,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_NORMAL}, // AMI_SPI_INDEX_AFE_ATT_ALL
    { 1,    0,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_AFE_0
    { 2,    0,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_AFE_1
    { 3,    0,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_AFE_2
    { 4,    0,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_AFE_3
    { 5,    0,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY},    // AMI_SPI_INDEX_PTM_0
};

#define NUM_DEVICES ARRAY_SIZE(deviceTable)

struct controller {
    struct genericSPI spi;
    uint8_t controllerIndex;
    uint8_t muxPort;
    uint8_t muxPortNone;
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

#define NUM_PS_SENSORS                  5
#define INA239_AMPS_PER_VOLT            9 /* 1/Rshunt */

struct psInfo {
    int         deviceIndex;
    uint32_t    vshunt;
    uint32_t    vbus;
    uint32_t    current;
    uint32_t    temp;
    const char *name;
};

static struct psInfo psInfos[CFG_DSBPM_COUNT][NUM_PS_SENSORS] = {
    {
        {
            .deviceIndex = AMI_SPI_INDEX_AFE_0,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "AFE_0"
        },
        {
            .deviceIndex = AMI_SPI_INDEX_AFE_1,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "AFE_1"
        },
        {
            .deviceIndex = AMI_SPI_INDEX_AFE_2,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "AFE_2"
        },
        {
            .deviceIndex = AMI_SPI_INDEX_AFE_3,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "AFE_3"
        },
        {
            .deviceIndex = AMI_SPI_INDEX_PTM_0,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "PTM_0"
        },
    },
    {
        {
            .deviceIndex = AMI_SPI_INDEX_AFE_0,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "AFE_0"
        },
        {
            .deviceIndex = AMI_SPI_INDEX_AFE_1,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "AFE_1"
        },
        {
            .deviceIndex = AMI_SPI_INDEX_AFE_2,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "AFE_2"
        },
        {
            .deviceIndex = AMI_SPI_INDEX_AFE_3,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "AFE_3"
        },
        {
            .deviceIndex = AMI_SPI_INDEX_PTM_0,
            .vshunt = 0,
            .vbus = 0,
            .current = 0,
            .temp = 0,
            .name = "PTM_0"
        },
    }
};

static int fetchVIRaw(unsigned int controllerIndex, unsigned int channel,
        uint32_t *vbuf, uint32_t *vsbuf, uint32_t *ibuf);
static int fetchTempRaw(unsigned int controllerIndex, unsigned int channel,
        uint32_t *tbuf);

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
    int i = 0;
    struct controller *cp = NULL;
    gspiErr spiStatus = GSPI_SUCCESS;
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
        spiStatus = genericSPIWrite(&cp->spi, data);

        if (spiStatus != GSPI_SUCCESS) {
            warn("Configure MCP23S08 %d", cp->controllerIndex);
        }

        /*
         * Configure outputs according to the "deselect" bit from
         * each device:
         */
        uint8_t deselect = 0;
        for (i = 0; i < NUM_DEVICES; i++) {
            deselect |= (deviceTable[i].latchEn? 0x0 : 0x1) << i;
        }
        cp->muxPortNone = deselect;
        cp->muxPort = cp->muxPortNone;

        data = MCP23S08_REG_ADDR << 16;
        data |= 0x09 << 8;
        data |= cp->muxPort;
        spiStatus = genericSPIWrite(&cp->spi, data);

        if (spiStatus != GSPI_SUCCESS) {
            warn("Configure MCP23S08 %d", cp->controllerIndex);
        }
    }

    /*
     * Read one set of sensors so we can display them as soon as
     * we exit this
     */
    int controllerIndex = 0, sensor = 0;
    int status = 0;
    for (controllerIndex = 0 ; controllerIndex < NUM_CONTROLLERS; controllerIndex++) {
        for (sensor = 0 ; sensor < NUM_PS_SENSORS; sensor++) {
            status = fetchVIRaw(controllerIndex, sensor,
                    &psInfos[controllerIndex][sensor].vbus,
                    &psInfos[controllerIndex][sensor].vshunt,
                    &psInfos[controllerIndex][sensor].current);
            status |= fetchTempRaw(controllerIndex, sensor,
                    &psInfos[controllerIndex][sensor].temp);

            if (status < 0) {
                warn("Read AFE sensors from Controller %d", controllerIndex);
            }
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
    gspiErr spiStatus = GSPI_SUCCESS;

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

    spiStatus = genericSPIWrite(&cp->spi, data);
    if(spiStatus != GSPI_SUCCESS) {
        return -1;
    }

    return 0;
}

static int
amiSetMux(struct controller *cp, unsigned int muxPort,
        unsigned int activeHigh)
{
    int status = 0;

    if (muxPort == MUXPORT_NONE) {
        muxPort = cp->muxPortNone;
    }
    else {
        unsigned int muxPortBitmap = muxPort & 0x7;
        muxPortBitmap = (1 << muxPortBitmap) & 0xFF;
        //muxPort = ~(1 << muxPort) & 0xFF;
        muxPort = activeHigh? (cp->muxPortNone | muxPortBitmap) :
            (cp->muxPortNone & ~muxPortBitmap);
    }

    status = amiSetMcp23s08(cp, muxPort);
    if (status < 0) {
        cp->muxPort = MUXPORT_UNKNOWN;
        return -1;
    }

    cp->muxPort = muxPort;

    return 0;
}

static int
amiSPIWrite(unsigned int controllerIndex, unsigned int deviceIndex,
        uint32_t data)
{
    gspiErr spiStatus = GSPI_SUCCESS;
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

    if (!dp->latchEn) {
        if (amiSetMux(cp, dp->muxPort, dp->latchEn) < 0) {
            return -1;
        }
    }

    /*
     * Only the mux is on channel 0. Everything is on channel 1
     */
    genericSPISetOptions(&cp->spi, dp->wordSize24, dp->lsbFirst, dp->cpol,
            dp->cpha, 1);
    spiStatus = genericSPIWrite(&cp->spi, data);

    if (dp->latchEn) {
        amiSetMux(cp, dp->muxPort, dp->latchEn);
    }

    if (amiSetMux(cp, MUXPORT_NONE, dp->latchEn) < 0) {
        return -1;
    }

    if (spiStatus != GSPI_SUCCESS) {
        return -1;
    }

    return 0;
}

static int
amiSPIRead(unsigned int controllerIndex, unsigned int deviceIndex,
        uint32_t data, uint32_t *buf)
{
    gspiErr spiStatus = GSPI_SUCCESS;
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

    if (!dp->latchEn) {
        if (amiSetMux(cp, dp->muxPort, dp->latchEn) < 0) {
            return -1;
        }
    }

    /*
     * Only the mux is on channel 0. Everything is on channel 1
     */
    genericSPISetOptions(&cp->spi, dp->wordSize24, dp->lsbFirst, dp->cpol,
            dp->cpha, 1);
    spiStatus = genericSPIRead(&cp->spi, data, buf);

    if (dp->latchEn) {
        amiSetMux(cp, dp->muxPort, dp->latchEn);
    }

    if (amiSetMux(cp, MUXPORT_NONE, dp->latchEn) < 0) {
        return -1;
    }

    if (spiStatus != GSPI_SUCCESS) {
        return -1;
    }

    return 0;
}

/*
 * Set attenuators
 */
static int
amiAttenSet(unsigned int controllerIndex, unsigned int channel,
        int address, unsigned int mdB)
{
    gspiErr spiStatus = GSPI_SUCCESS;
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

    spiStatus = amiSPIWrite(controllerIndex, deviceIndex, v);
    if (spiStatus != GSPI_SUCCESS) {
        return -1;
    }

    return 0;
}

int
amiAfeAttenSet(unsigned int bpm, unsigned int channel,
        unsigned int mdB)
{
    const int address = 0x7;
    gspiErr spiStatus = GSPI_SUCCESS;

    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    if (channel >= CFG_ADC_PER_BPM_COUNT) {
        return -1;
    }

    // All channels are wired together
    channel = 0;
    spiStatus = amiAttenSet(bpm, channel, address, mdB);

    if (spiStatus != GSPI_SUCCESS) {
        return -1;
    }

    amiAfeAttenuation[bpm][channel] = mdB;

    return 0;
}

int
amiPtmAttenSet(unsigned int bpm, unsigned int mdB)
{
    const int address = 0x3;
    gspiErr spiStatus = GSPI_SUCCESS;

    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    // Only a single PTM module
    unsigned int channel = 0;
    spiStatus = amiAttenSet(bpm, channel, address, mdB);

    if (spiStatus != GSPI_SUCCESS) {
        return -1;
    }

    amiPtmAttenuation[bpm] = mdB;

    return 0;
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
amiGetIna239Reading(unsigned int controllerIndex, unsigned int deviceIndex,
        unsigned int type, uint32_t *buf)
{
    int status = 0;

    if (type >= NUM_INA239_INDECES) {
        return -1;
    }

    status = amiGetIna239(controllerIndex, deviceIndex,
            ina239RegMap[type].addr, buf);

    if (status < 0) {
        return status;
    }

    return 0;
}

int
amiIna239MfrIdGet(unsigned int bpm, unsigned int channel)
{
    int status = 0;
    uint32_t buf = 0;

    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    if (channel >= NUM_PS_SENSORS) {
        return -1;
    }

    status = amiGetIna239Reading(bpm, psInfos[bpm][channel].deviceIndex,
        AMI_INA239_INDEX_MFR, &buf);

    if (status < 0) {
        return status;
    }

    return buf;
}

int
amiIna239DevIdGet(unsigned int bpm, unsigned int channel)
{
    int status = 0;
    uint32_t buf = 0;

    if (bpm >= CFG_DSBPM_COUNT) {
        return -1;
    }

    if (channel >= NUM_PS_SENSORS) {
        return -1;
    }

    status = amiGetIna239Reading(bpm, psInfos[bpm][channel].deviceIndex,
        AMI_INA239_INDEX_DEVID, &buf);

    if (status < 0) {
        return status;
    }

    return buf;
}

static int
fetchVIRaw(unsigned int controllerIndex, unsigned int channel,
        uint32_t *vbuf, uint32_t *vsbuf, uint32_t *ibuf)
{
    int status = 0;

    status |= amiGetIna239Reading(controllerIndex, psInfos[controllerIndex][channel].deviceIndex,
            AMI_INA239_INDEX_V_BUS, vbuf);
    status |= amiGetIna239Reading(controllerIndex, psInfos[controllerIndex][channel].deviceIndex,
            AMI_INA239_INDEX_V_SHUNT, vsbuf);
    status |= amiGetIna239Reading(controllerIndex, psInfos[controllerIndex][channel].deviceIndex,
            AMI_INA239_INDEX_CURRENT, ibuf);

    if (status < 0) {
        return status;
    }

    return 0;
}

static int
convertVI(uint32_t vbuf, uint32_t vsbuf, uint32_t ibuf,
        float *vp, float *vsp, float *ip)
{
    // 3.125mV / LSB
    *vp = vbuf / 320.0;

    // 5uV / LSB
    *vsp = vsbuf / 200000.0;

    // From the INA239 datasheet:
    // SHUNT_CAL = 819.2 x 10^6 x CURRENT_LSB x RSHUNT
    // Current_LSB = Maximum Expected Current / 2^15
    //
    // With:
    // SHUNT_CAL = 0x1000
    // RSHUNT = 115mOHM
    // CURRENT_LSB * RSHUNT = 5uV per count
    int curr = ibuf;
    if (curr & 0x8000) {
        curr -= 0x10000;
    }

    // 5uV per count
    curr *= 5;
    curr *= INA239_AMPS_PER_VOLT;
    *ip = curr / 1.0e6;

    return 0;
}

static int
fetchTempRaw(unsigned int controllerIndex, unsigned int channel,
        uint32_t *tbuf)
{
    int status = 0;

    status |= amiGetIna239Reading(controllerIndex, psInfos[controllerIndex][channel].deviceIndex,
            AMI_INA239_INDEX_DIETEMP, tbuf);

    if (status < 0) {
        return status;
    }

    return 0;
}

static int
convertTemp(uint32_t tbuf, float *tp)
{
    // 4 LSB are reserved
    tbuf >>= 4;

    int temp = tbuf;
    if (temp & 0x8000) {
        temp -= 0x10000;
    }

    // 125 mC / LSB
    *tp = temp / 8.0;

    return 0;
}

/*
 * SPI can take ms to conclude, so probe a new sensro every xxx ms.
 */
void
amiCrank()
{
    int status = 0;
    int sensorRead = 0;
    static uint32_t whenEntered;
    static int bpm;
    static int sensor;

    if ((MICROSECONDS_SINCE_BOOT() - whenEntered) > 100000) {
        if (sensor >= NUM_PS_SENSORS) {
            sensor = 0;
            bpm++;
        }

        if (bpm >= CFG_DSBPM_COUNT) {
            bpm = 0;
        }

        status = fetchVIRaw(bpm, sensor,
                &psInfos[bpm][sensor].vbus, &psInfos[bpm][sensor].vshunt,
                &psInfos[bpm][sensor].current);
        status |= fetchTempRaw(bpm, sensor, &psInfos[bpm][sensor].temp);

        sensor++;
        sensorRead = 1;
    }

    if (sensorRead) {
        whenEntered = MICROSECONDS_SINCE_BOOT();
    }
}

/*
 * This doesn't do any SPI readings, only gets the cached
 * values, convert and display them.
 */
void
amiPSinfoDisplay(unsigned int bpm)
{
    unsigned int sensor = 0;
    int status = 0;

    if (bpm >= CFG_DSBPM_COUNT) {
        return;
    }

    printf("BPM%u:\n", bpm);

    for (sensor = 0 ; sensor < NUM_PS_SENSORS; sensor++) {
        float v = 0.0, vs = 0.0, i = 0.0, t = 0.0;

        status = convertVI(psInfos[bpm][sensor].vbus,
                psInfos[bpm][sensor].vshunt,
                psInfos[bpm][sensor].current,
                &v, &vs, &i);
        status |= convertTemp(psInfos[bpm][sensor].temp, &t);
        if (status < 0) {
            printf("%8s: NaN (bus) V  NaN (shunt)  NaN A  Nan oC\n",
                    psInfos[bpm][sensor].name);
        }
        else {
            printf("%8s: %7.3f (bus) V  %7.3f (shunt) V  %8.3f A  %7.3f C\n",
                    psInfos[bpm][sensor].name, v, vs, i, t);
        }
    }
}
