/*
 * Communicate with the Redundant Power Board SPI components
 */

#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include <limits.h>
#include "evr.h"
#include "genericSPI.h"
#include "rpb.h"
#include "gpio.h"
#include "util.h"

struct ina239RegMap {
    uint8_t addr;
};

static const struct ina239RegMap ina239RegMap[] = {
    {0x02},         // RPB_INA239_INDEX_SHUNT_CAL
    {0x04},         // RPB_INA239_INDEX_V_SHUNT
    {0x05},         // RPB_INA239_INDEX_V_BUS
    {0x06},         // RPB_INA239_INDEX_DIETEMP
    {0x07},         // RPB_INA239_INDEX_CURRENT
    {0x3E},         // RPB_INA239_INDEX_MFR
    {0x3F},         // RPB_INA239_INDEX_DEVID
};

#define NUM_INA239_INDECES ARRAY_SIZE(ina239RegMap)

#define DEVINFO_CPOL_NORMAL   0
#define DEVINFO_CPOL_INV      1

#define DEVINFO_CPHA_NORMAL   0
#define DEVINFO_CPHA_DLY      1

struct deviceInfo {
    uint8_t channel;
    uint8_t lsbFirst;
    uint8_t wordSize24;
    uint8_t cpol;
    uint8_t cpha;
};

static const struct deviceInfo deviceTable[] = {
    {  0,    0,    1,   DEVINFO_CPOL_NORMAL, DEVINFO_CPHA_DLY}, // RPB_SPI_INDEX_INA239
};

#define NUM_DEVICES ARRAY_SIZE(deviceTable)

struct controller {
    struct genericSPI spi;
    uint8_t controllerIndex;
};

static struct controller controller = {
    .spi = {
        .gpioIdx = GPIO_IDX_RPB_SPI_CSR,
        .lsbFirst = 0,
        .channel = 0,
        .wordSize24 = 1,
        .cpol = DEVINFO_CPOL_NORMAL,
        .cpha = DEVINFO_CPHA_DLY,
        .inProgress = 0
    },
    .controllerIndex = 0,
};

#define NUM_CONTROLLERS ARRAY_SIZE(controller)

static const float INA239_AMPS_PER_VOLT = 1.0/18e-3; /* 1/Rshunt */

struct psInfo {
    int         deviceIndex;
    uint32_t    vshunt;
    uint32_t    vbus;
    uint32_t    current;
    uint32_t    temp;
    uint32_t    mfrId;
    uint32_t    devId;
    const char *name;
};

static struct psInfo psInfos[RPB_NUM_PS_SENSORS] = {
    {
        .deviceIndex = RPB_SPI_INDEX_INA239,
        .vshunt = 0,
        .vbus = 0,
        .current = 0,
        .temp = 0,
        .mfrId = 0,
        .devId = 0,
        .name = "RPB_0"
    },
};

static int fetchId(unsigned int channel,
        uint32_t *mfrId, uint32_t *devId);
static int fetchVIRaw(unsigned int channel,
        uint32_t *vbuf, uint32_t *vsbuf, uint32_t *ibuf);
static int fetchTempRaw(unsigned int channel,
        uint32_t *tbuf);

int
rpbAfeGetSerialNumber(void)
{
    return 0;
}

static void
initController(void)
{
}

void
rpbInit(void)
{
    initController();

    /*
     * Read one set of sensors so we can display them as soon as
     * we exit this
     */
    int sensor = 0;
    int status = 0;
    for (sensor = 0 ; sensor < RPB_NUM_PS_SENSORS; sensor++) {
        status = fetchId(sensor,
                &psInfos[sensor].mfrId,
                &psInfos[sensor].devId);
        status |= fetchVIRaw(sensor,
                &psInfos[sensor].vbus,
                &psInfos[sensor].vshunt,
                &psInfos[sensor].current);
        status |= fetchTempRaw(sensor,
                &psInfos[sensor].temp);

        if (status < 0) {
            warn("Read RPB sensors");
        }
    }
}

static int
rpbSPIWrite(unsigned int deviceIndex, uint32_t data)
{
    gspiErr spiStatus = GSPI_SUCCESS;
    const struct deviceInfo *dp;
    struct controller *cp;

    if (deviceIndex >= NUM_DEVICES) {
        return -1;
    }

    dp = &deviceTable[deviceIndex];
    cp = &controller;

    genericSPISetOptions(&cp->spi, dp->wordSize24, dp->lsbFirst, dp->cpol,
            dp->cpha, dp->channel);
    spiStatus = genericSPIWrite(&cp->spi, data);

    if (spiStatus != GSPI_SUCCESS) {
        return -1;
    }

    return 0;
}

static int
rpbSPIRead(unsigned int deviceIndex, uint32_t data, uint32_t *buf)
{
    gspiErr spiStatus = GSPI_SUCCESS;
    const struct deviceInfo *dp;
    struct controller *cp;

    if (deviceIndex >= NUM_DEVICES) {
        return -1;
    }

    dp = &deviceTable[deviceIndex];
    cp = &controller;

    genericSPISetOptions(&cp->spi, dp->wordSize24, dp->lsbFirst, dp->cpol,
            dp->cpha, dp->channel);
    spiStatus = genericSPIRead(&cp->spi, data, buf);

    if (spiStatus != GSPI_SUCCESS) {
        return -1;
    }

    return 0;
}

/*
 * Get INA239 values
 */
static int
rpbGetIna239(unsigned int deviceIndex, int address, uint32_t *buf)
{
    // SPI data: 6-bit reg address | 1b0 | 1b1 (read op) | 16-bit data (0)
    int v = 0x0000;
    v |= ((address & 0x3F) << 2 | 0x01) << 16;

    return rpbSPIRead(deviceIndex, v, buf);
}

static int
rpbGetIna239Reading(unsigned int deviceIndex, unsigned int type, uint32_t *buf)
{
    int status = 0;

    if (type >= NUM_INA239_INDECES) {
        return -1;
    }

    status = rpbGetIna239(deviceIndex, ina239RegMap[type].addr, buf);

    if (status < 0) {
        return status;
    }

    return 0;
}

int
rpbIna239MfrIdGet(unsigned int channel)
{
    int status = 0;
    uint32_t buf = 0;

    if (channel >= RPB_NUM_PS_SENSORS) {
        return -1;
    }

    status = rpbGetIna239Reading(psInfos[channel].deviceIndex,
            RPB_INA239_INDEX_MFR, &buf);

    if (status < 0) {
        return status;
    }

    return buf;
}

int
rpbIna239DevIdGet(unsigned int channel)
{
    int status = 0;
    uint32_t buf = 0;

    if (channel >= RPB_NUM_PS_SENSORS) {
        return -1;
    }

    status = rpbGetIna239Reading(psInfos[channel].deviceIndex,
        RPB_INA239_INDEX_DEVID, &buf);

    if (status < 0) {
        return status;
    }

    return buf;
}

static int
fetchId(unsigned int channel, uint32_t *mfrId, uint32_t *devId)
{
    int status = 0;

    status = rpbGetIna239Reading(psInfos[channel].deviceIndex,
            RPB_INA239_INDEX_MFR, mfrId);
    status |= rpbGetIna239Reading(psInfos[channel].deviceIndex,
            RPB_INA239_INDEX_DEVID, devId);

    if (status < 0) {
        return status;
    }

    return 0;
}

static int
fetchVIRaw(unsigned int channel, uint32_t *vbuf, uint32_t *vsbuf, uint32_t *ibuf)
{
    int status = 0;

    status |= rpbGetIna239Reading(psInfos[channel].deviceIndex,
            RPB_INA239_INDEX_V_BUS, vbuf);
    status |= rpbGetIna239Reading(psInfos[channel].deviceIndex,
            RPB_INA239_INDEX_V_SHUNT, vsbuf);
    status |= rpbGetIna239Reading(psInfos[channel].deviceIndex,
            RPB_INA239_INDEX_CURRENT, ibuf);

    if (status < 0) {
        return status;
    }

    return 0;
}

static int
convertVI(uint32_t vbuf, uint32_t vsbuf, uint32_t ibuf,
        float *vp, float *vsp, float *ip)
{
    int vbus = vbuf;
    if (vbus & 0x8000) {
        vbus -= 0x10000;
    }

    // 3.125mV / LSB
    *vp = vbus / 320.0;

    int vshunt = vsbuf;
    if (vshunt & 0x8000) {
        vshunt -= 0x10000;
    }

    // 5uV / LSB
    *vsp = vshunt / 200000.0;

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
    *ip = (curr * INA239_AMPS_PER_VOLT) / 1.0e6;

    return 0;
}

static int
fetchTempRaw(unsigned int channel, uint32_t *tbuf)
{
    int status = 0;

    status |= rpbGetIna239Reading(psInfos[channel].deviceIndex,
            RPB_INA239_INDEX_DIETEMP, tbuf);

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
rpbCrank()
{
    int status = 0;
    int sensorRead = 0;
    static uint32_t whenEntered;
    static int sensor;

    if ((MICROSECONDS_SINCE_BOOT() - whenEntered) > 100000) {
        if (sensor >= RPB_NUM_PS_SENSORS) {
            sensor = 0;
        }

        status = fetchVIRaw(sensor,
                &psInfos[sensor].vbus, &psInfos[sensor].vshunt,
                &psInfos[sensor].current);
        status |= fetchTempRaw(sensor, &psInfos[sensor].temp);

        sensor++;
        sensorRead = 1;
    }

    if (sensorRead) {
        whenEntered = MICROSECONDS_SINCE_BOOT();
    }
}

int
rpbFetch(uint32_t *args)
{
    int sensor;
    int aIndex = 0;

    for (sensor = 0 ; sensor < RPB_NUM_PS_SENSORS; sensor++) {
        args[aIndex++] = (psInfos[sensor].vshunt << 16) |
                            psInfos[sensor].vbus;
        args[aIndex++] = (psInfos[sensor].current << 16) |
                            psInfos[sensor].temp;
    }

    return aIndex;
}

/*
 * This doesn't do any SPI readings, only gets the cached
 * values, convert and display them.
 */
void
rpbPSinfoDisplay(int verbose)
{
    unsigned int sensor = 0;
    int status = 0;

    for (sensor = 0 ; sensor < RPB_NUM_PS_SENSORS; sensor++) {
        float v = 0.0, vs = 0.0, i = 0.0, t = 0.0;

        status = convertVI(psInfos[sensor].vbus,
                psInfos[sensor].vshunt,
                psInfos[sensor].current,
                &v, &vs, &i);
        status |= convertTemp(psInfos[sensor].temp, &t);
        if (status < 0) {
            printf("%8s(Nil:Nil): NaN (bus) V  NaN (shunt)  NaN A  Nan oC\n",
                    psInfos[sensor].name);
        }
        else if (verbose == 0) {
            printf("%8s: %7.3f (bus) V  %7.3f (shunt) V  %8.3f A  %7.3f C\n",
                    psInfos[sensor].name, v, vs, i, t);
        }
        else {
            printf("%8s(0x%04X:0x%04X): %7.3f (bus) V  %7.3f (shunt) V  %8.3f A  %7.3f C\n",
                    psInfos[sensor].name, psInfos[sensor].mfrId, psInfos[sensor].devId,
                    v, vs, i, t);
        }
    }
}
