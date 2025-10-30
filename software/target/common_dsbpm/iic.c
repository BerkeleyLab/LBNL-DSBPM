/*
 * Communicate with IIC devices
 * For now just use routines from Xilinx library.
 * At some point we might take over the I/O ourselves and not be stuck
 * here waiting for I/O to complete.
 */
#include <stdio.h>
#include <stdint.h>
#include <xiicps.h>
#include "iic.h"
#include "util.h"
#include "gpio.h"

#define IIC_MAX_TRIES   4

#define C0_M_IIC_ADDRESS  0x75   /* Address of controller 0 multiplexer */
#define C1_M0_IIC_ADDRESS 0x74   /* Address of controller 1 multiplexer 0 */

static int deviceIds[] = {
    XPAR_PSU_I2C_0_DEVICE_ID,
    XPAR_PSU_I2C_1_DEVICE_ID
};
#define CONTROLLER_COUNT (sizeof deviceIds/sizeof deviceIds[0])

#define MUXPORT_UNKNOWN 127
#define MUXPORT_NONE    126

struct deviceInfo {
    int16_t controllerIndex;
    uint8_t muxPort;
    uint8_t deviceAddress;
};
static struct deviceInfo deviceTable[] = {
    { 0, MUXPORT_NONE, 0x20 }, // TCA6416A Port Expander
    { 0,            0, 0x40 }, // INA226 VCCINT
    { 0,            0, 0x41 }, // INA226 VCCINT_IO_BRAM
    { 0,            0, 0x42 }, // INA226 VCC1V8
    { 0,            0, 0x43 }, // INA226 VCC1V2
    { 0,            0, 0x45 }, // INA226 VADJ_FMC
    { 0,            0, 0x46 }, // INA226 MGTAVCC
    { 0,            0, 0x47 }, // INA226 MGT1V2
    { 0,            0, 0x48 }, // INA226 MGT1V8C
    { 0,            0, 0x49 }, // INA226 VCCINT_AMS
    { 0,            0, 0x4A }, // INA226 DAC_AVTT
    { 0,            0, 0x4B }, // INA226 DAC_AVCCAUX
    { 0,            0, 0x4C }, // INA226 ADC_AVCC
    { 0,            0, 0x4D }, // INA226 ADC_AVCCAUX
    { 0,            0, 0x4E }, // INA226 DAC_AVCC
    { 0,            2, 0x43 }, // IR38164 A, U112
    { 0,            2, 0x4C }, // IR38164 B, U123
    { 0,            2, 0x4B }, // IR38164 C, U127
    { 0,            2, 0x40 }, // IR35215, U104
    { 0,            2, 0x40 }, // PLACEHOLDER, don't mess with the IIC order
    { 0,            2, 0x44 }, // IRPS5401 A, U53
    { 0,            2, 0x45 }, // IRPS5401 B, U55
    { 0,            3, 0x54 }, // SYSMON
    { 1,            0, 0x54 }, // EEPROM
    { 1,            1, 0x36 }, // SI5341
    { 1,            2, 0x5D }, // USER_SI570
    { 1,            3, 0x5D }, // USER_MGT_SI570
    { 1,            4, 0x5B }, // 8A34001
    { 1,            5, 0x2F }, // I2C2SPI
    { 1,            6, 0x50 }, // RFMC
    { 1,            8, 0x50 }, // FMC
    { 1,           10, 0x32 }, // SYSMON   /* Not used -- R184, R187 DNP */
    { 1,           11, 0x51 }, // SODIMM
    { 1,           12, 0x50 }, // SFP 3 INFO
    { 1,           12, 0x51 }, // SFP 3 STATUS
    { 1,           13, 0x50 }, // SFP 2 INFO
    { 1,           13, 0x51 }, // SFP 2 STATUS
    { 1,           14, 0x50 }, // SFP 1 INFO
    { 1,           14, 0x51 }, // SFP 1 STATUS
    { 1,           15, 0x50 }, // SFP 0 INFO
    { 1,           15, 0x51 }, // SFP 0 STATUS
};
#define DEVICE_COUNT (sizeof deviceTable/sizeof deviceTable[0])

struct controller {
    XIicPs Iic;
    uint8_t controllerIndex;
    uint8_t muxPort[2];
};

static struct controller controllers[CONTROLLER_COUNT];

struct rfClkInfo {
    unsigned int muxSelect;
    enum rfClkType type;
};

#define SPI_MUX_2594_A_ADC    0
#define SPI_MUX_2594_B_DAC    1
#define SPI_MUX_04828B        2

#define SPI_MUX_2594_A_ADC_NEW 3

static const struct rfClkInfo rfClkInfos[RFCLK_INFO_NUM_DEVICES] = {
    {.muxSelect = SPI_MUX_04828B, .type = RFCLK_LMK04XXX},     // RFCLK_INFO_LMK04XXX_INDEX
    {.muxSelect = SPI_MUX_2594_A_ADC, .type = RFCLK_LMX2594},  // RFCLK_INFO_LMX2594_ADC_INDEX
    {.muxSelect = SPI_MUX_2594_B_DAC, .type = RFCLK_LMX2594},  // RFCLK_INFO_LMX2594_DAC_INDEX
};

/*
 * Initialize IIC controllers
 */
void
initController(struct controller *cp, int deviceId)
{
	int Status;
	XIicPs_Config *Config;

    /*
     * Find and initialize the controller
     */
	Config = XIicPs_LookupConfig(deviceId);
	if (Config == NULL) fatal("XIicPs_LookupConfig");
	Status = XIicPs_CfgInitialize(&cp->Iic, Config, Config->BaseAddress);
	if (Status != XST_SUCCESS) fatal("XIicPs_CfgInitialize");
	Status = XIicPs_SelfTest(&cp->Iic);
	if (Status != XST_SUCCESS) fatal("XIicPs_SelfTest");

	/*
	 * Set the IIC serial clock rate.
     * Use 80kHz because there might be a bug with the driver:
     * https://adaptivesupport.amd.com/s/article/59366?language=en_US
	 */
	XIicPs_SetSClk(&cp->Iic, 80000);

}

void
iicInit(void)
{
    int i;
    uint8_t buf[7];

    for (i = 0 ; i < CONTROLLER_COUNT ; i++) {
        struct controller *cp = &controllers[i];
        cp->controllerIndex = i;
        initController(cp, deviceIds[i]);
        cp->muxPort[0] = i == 0 ? MUXPORT_NONE : MUXPORT_UNKNOWN;
        cp->muxPort[1] = MUXPORT_UNKNOWN;
    }

    /*
     * Configure port expander 0_1 as output and drive low -- this works
     * around a design error on the ZCU111 that resulted in the fan always
     * running at maximum speed.  The workaround has the undesirable side
     * effect of making it impossible to monitor the fan controller FANFAIL_B
     * line, but is beter than having the fan always run at full speed.
     */
    buf[0] = 0x2; /* Select output register 0 */
    buf[1] = 0x00; /* Port 0: All outputs low */
    buf[2] = 0x00; /* Port 1: All outputs low */
    buf[3] = 0x00; /* Port 0: No polarity inversion */
    buf[4] = 0x00; /* Port 1: No polarity inversion */
    buf[5] = ~0x02; /* Port 0: All inputs, except bit 1 */
    buf[6] = ~0x00; /* Port 1: All inputs */
    if (!iicWrite(IIC_INDEX_TCA6416A_PORT, buf, 7)) warn("Configure TCA6416");

    /*
     * Configure SC18IS602 to:
     *
     * - ORDER = 0: MSB first
     * - CPOL = 0: SPICLK LOW when IDLE
     * - CPHA = 0: Data clocked on leading EDGE
     * - SPI clock rate = 10: 115kHz
     */
    buf[0] = 0xF0; /* Function ID F0h */
    buf[1] = 0x02; /* See above */
    if (!iicWrite(IIC_INDEX_I2C2SPI, buf, 2)) warn("Configure SC18IS602");
}

static int
iicSend(struct controller *cp, int address, const uint8_t *buf, int n)
{
    int i = 0;
    int isBusy = 1;
    int status;

    if (debugFlags & DEBUGFLAG_IIC) {
        printf("IIC %d:0x%02X <-", cp->controllerIndex, address);
        for (i = 0 ; i < n ; i++) printf(" %02X", buf[i]);
    }

    for (i = 0; i < IIC_MAX_TRIES; ++i) {
        if (!XIicPs_BusIsBusy(&cp->Iic)) {
            isBusy = 0;
            break;
        }
        microsecondSpin(100);
    }

    if (isBusy) {
        if (debugFlags & DEBUGFLAG_IIC) {
            printf(" == reset ==");
        }
        XIicPs_Reset(&cp->Iic);
        microsecondSpin(10000);
        if (XIicPs_BusIsBusy(&cp->Iic)) {
            printf("===== IIC %d reset failed ====\n", cp->controllerIndex);
            return 0;
        }
    }

    status = XIicPs_MasterSendPolled(&cp->Iic, (uint8_t *)buf, n, address);
    if (debugFlags & DEBUGFLAG_IIC) {
        if (status != XST_SUCCESS) printf(" FAILED");
        printf("\n");
    }
    microsecondSpin(100);
    return status == XST_SUCCESS;
}

static int
iicRecv(struct controller *cp, int address, uint8_t *buf, int n)
{
    int status;

    status = XIicPs_MasterRecvPolled(&cp->Iic, buf, n, address);
    if (debugFlags & DEBUGFLAG_IIC) {
        printf("IIC %d:0x%02X ->", cp->controllerIndex, address);
        if (status == XST_SUCCESS) {
            int i;
            for (i = 0 ; i < n ; i++) printf(" %02X", buf[i]);
        }
        else {
            printf(" FAILED");
        }
        printf("\n");
    }
    microsecondSpin(100);
    return status == XST_SUCCESS;
}

/*
 * Set multiplexers
 */
static int
setMux(struct controller *cp, int muxPort)
{
    int newMux;
    int otherMux;
    uint8_t b;

    switch (cp->controllerIndex) {
    case 0:
        if ((muxPort != MUXPORT_NONE) && (muxPort != cp->muxPort[0])) {
            b = 0x4 | muxPort;
            if (iicSend(cp, C0_M_IIC_ADDRESS, &b, 1)) {
                cp->muxPort[0] = muxPort;
            }
            else {
                cp->muxPort[0] = MUXPORT_UNKNOWN;
                return 0;
            }
        }
        break;

    case 1:
        newMux = muxPort >> 3;
        otherMux = 1 - newMux;
        b = 1 << (muxPort & 0x7);
        if (cp->muxPort[otherMux] != MUXPORT_NONE) {
            uint8_t z = 0;
            if (iicSend(cp, C1_M0_IIC_ADDRESS + otherMux, &z, 1)) {
                cp->muxPort[otherMux] = MUXPORT_NONE;
            }
            else {
                cp->muxPort[otherMux] = MUXPORT_UNKNOWN;
                return 0;
            }
        }
        if (cp->muxPort[newMux] != muxPort) {
            if (iicSend(cp, C1_M0_IIC_ADDRESS + newMux, &b, 1)) {
                cp->muxPort[newMux] = muxPort;
            }
            else {
                cp->muxPort[newMux] = MUXPORT_UNKNOWN;
                return 0;
            }
        }
        break;
    }
    return 1;
}

/*
 * Read 16 bit value from PMBUS power management IC.
 * Scale by a factor of 256.
 * Why the VOUT register doesn't use the same format is a mystery to me.
 */
int
pmbusRead(unsigned int deviceIndex, unsigned int page, int reg)
{
    uint8_t ioBuf[2];
    int v;

    // set page if valid page. This only exists for
    // specific devices
    if (page <= 3) {
        unsigned char obuf[2];
        obuf[0] = 0;
        obuf[1] = page;
        if (!iicWrite(deviceIndex, obuf, 2)) {
            return -1;
        }
    }

    if (!iicRead(deviceIndex, reg, ioBuf, 2)) {
        return -1;
    }
    v = (ioBuf[1] << 8) | ioBuf[0];
    if (reg != 0x8B) {
        int exp = (v & 0xF800) >> 11;
        v &= 0x7FF;
        if (exp & 0x10) exp -= 0x20;
        v <<= (8 + exp);
    }
    return v;
}

/*
 * Read from specified device
 */
int
iicRead(unsigned int deviceIndex, int subAddress, uint8_t *buf, int n)
{
    struct controller *cp;
    struct deviceInfo *dp;
    int deviceAddress = (deviceIndex >> 8) & 0xFF;
    deviceIndex &= 0xFF;

    if (deviceIndex >= DEVICE_COUNT) return 0;
    dp = &deviceTable[deviceIndex];
    if (deviceAddress == 0) deviceAddress = dp->deviceAddress;
    cp = &controllers[dp->controllerIndex];
    if (!setMux(cp, dp->muxPort)) return 0;
    if (subAddress >= 0) {
        int sent;
        uint8_t s = subAddress;
        XIicPs_SetOptions(&cp->Iic, XIICPS_REP_START_OPTION);
        sent = iicSend(cp, deviceAddress, &s, 1);
        XIicPs_ClearOptions(&cp->Iic, XIICPS_REP_START_OPTION);
        if (!sent) return 0;
    }
    return iicRecv(cp, deviceAddress, buf, n);
}

/*
 * Write to specified device
 */
int
iicWrite(unsigned int deviceIndex, const uint8_t *buf, int n)
{
    struct controller *cp;
    struct deviceInfo *dp;
    int deviceAddress = (deviceIndex >> 8) & 0xFF;
    deviceIndex &= 0xFF;

    if (deviceIndex >= DEVICE_COUNT) return 0;
    dp = &deviceTable[deviceIndex];
    if (deviceAddress == 0) deviceAddress = dp->deviceAddress;
    cp = &controllers[dp->controllerIndex];
    if (!setMux(cp, dp->muxPort)) return 0;
    return iicSend(cp, deviceAddress, buf, n);
}

/*
 * EEPROM I/O
 * writes must not span page boundaries.
 */
int
eepromRead(int address, void *buf, int n)
{
    struct deviceInfo *dp = &deviceTable[IIC_INDEX_EEPROM];
    struct controller *cp = &controllers[dp->controllerIndex];

    if (debugFlags & DEBUGFLAG_IIC) {
        printf("eepromRead %d@%d\n", n, address);
    }
    if (!setMux(cp, dp->muxPort)) return 0;
    uint8_t xBuf[2];   // 2-byte addressing
    uint16_t subAddress = address & 0xFFFF;
    int nGet = 16384 - subAddress; // we can read the whole 16KB EEPROM
    xBuf[0] = (subAddress >> 8) & 0xFF; // MSB sent first
    xBuf[1] = subAddress & 0xFF;
    if (nGet > n) nGet = n;
    if (!iicSend(cp, dp->deviceAddress, xBuf, 2)
     || !iicRecv(cp, dp->deviceAddress, buf, nGet)) {
        return 0;
    }
    return 1;
}

int
eepromWrite(int address, const void *buf, int n)
{
    struct deviceInfo *dp = &deviceTable[IIC_INDEX_EEPROM];
    struct controller *cp = &controllers[dp->controllerIndex];
    uint16_t subAddress = address & 0xFFFF;
    const uint8_t *src = buf;
    int nLeft = n;

    if (!setMux(cp, dp->muxPort)) return 0;
    while (nLeft) {
        uint8_t xBuf[66];   /* Two greater than page size, beucase 2-byte addressing */
        int i = 2;
        int passCount = 0;
        xBuf[0] = (subAddress >> 8) & 0xFF; // MSB sent first
        xBuf[1] = subAddress & 0xFF;
        while (nLeft) {
            xBuf[i++] = *src++;
            subAddress++;
            nLeft--;
            // write each 64-byte page
            if ((subAddress & 0x3F) == 0) break;
        }
        /* Ensure completion of write operation */
        while (!iicSend(cp, dp->deviceAddress, xBuf, i)) {
            if (++passCount > 20) return 0;
        }
        microsecondSpin(5000);
    }
    return 1;
}

/*
 * Select the correct SPI multiplexer SDO output
 */
static int
spiSDOMuxSelect(unsigned int muxSelect)
{
    uint32_t selected = GPIO_READ(GPIO_IDX_CLK104_SPI_MUX_CSR);
    if (selected != muxSelect) {
        GPIO_WRITE(GPIO_IDX_CLK104_SPI_MUX_CSR, muxSelect);
    }
    return 1;
}

/*
 * Send n bytes to specified SPI target
 * Note that the I2C to SPI adapter chip enable lines are connected to
 * the SPI devices in reverse order to the MUX channel selection (!!!)
 */
static int
spiSend(unsigned int muxSelect, const uint8_t *buf, unsigned int n)
{
    uint8_t iicBuf[20];

    if ((muxSelect >= 4) || (n >= sizeof iicBuf)) return 0;
    iicBuf[0] = 0x8 >> muxSelect;

    // Depending on the CLk104 version, LMX ADC could be on
    // either GPIO3 or GPIO0, so select both to increase
    // compatibility
    if (muxSelect == SPI_MUX_2594_A_ADC) {
        iicBuf[0] = 0x8 >> SPI_MUX_2594_A_ADC_NEW;
    }

    memcpy(&iicBuf[1], buf, n);
    if (!iicWrite(IIC_INDEX_I2C2SPI, iicBuf, n + 1)) return 0;

    microsecondSpin(10000);
    return 1;
}

/*
 * Send and receive
 */
static int
spiTransfer(unsigned int muxSelect, uint8_t *buf, unsigned int n)
{
    /*
     * Don't exceed I2C/SPI adapter buffer limit
     */
    if (n > 200) return 0;

    /*
     * Select the correct SDO MUX port for readout
     */
    spiSDOMuxSelect(muxSelect);

    /*
     * Transmit to and receive from SPI device
     */
    if (!spiSend(muxSelect, buf, n)) return 0;

    /*
     * Read buffered data from I2C/SPI adapter
     */
    return iicRead(IIC_INDEX_I2C2SPI, -1, buf, n);
}

/*
 * LMK04828B Jitter Cleaner
 */
static uint32_t
lmk04828Bread(unsigned int muxSelect, int reg)
{
    uint8_t buf[3];

    /*
     * Select register
     */
    // Read command + W1 (0) W2 (0) + A12 - A8
    buf[0] = 0x80 | ((reg & 0x1F00) >> 8);
    // A7 - A0
    buf[1] = (reg & 0xFF);
    buf[2] = 0;
    if (!spiTransfer(muxSelect, buf, 3)) return 0;
    return buf[2];
}

static int
lmk04828Bwrite(unsigned int muxSelect, uint32_t value)
{
    uint8_t buf[3];

    buf[0] = value >> 16;
    buf[1] = value >> 8;
    buf[2] = value;
    if (!spiSend(muxSelect, buf, 3)) return 0;
    return 1;
}

/*
 * LMX2594 RF synthesizer
 */
static int
lmx2594read(unsigned int muxSelect, int reg)
{
    uint8_t buf[3];

    buf[0] = 0x80 | (reg & 0x7F);
    buf[1] = 0;
    buf[2] = 0;
    if (!spiTransfer(muxSelect, buf, 3)) return 0;
    return (buf[1] << 8) | buf[2];
}

static int
lmx2594write(unsigned int muxSelect, uint32_t value)
{
    uint8_t buf[3];

    buf[0] = (value >> 16) & 0x7F;
    buf[1] = value >> 8;
    buf[2] = value;
    if (!spiSend(muxSelect, buf, 3)) return 0;
    return 1;
}

enum rfClkType
rfClkGetType(unsigned int index)
{
    if (index >= RFCLK_INFO_NUM_DEVICES) {
        return RFCLK_UNKNOWN;
    }

    const struct rfClkInfo *info = &rfClkInfos[index];
    return info->type;
}

enum opRW {
    OP_READ,
    OP_WRITE
};

static int
rfClkOp(unsigned int index, uint32_t value, enum opRW op)
{
    if (index >= RFCLK_INFO_NUM_DEVICES) {
        return -1;
    }

    const struct rfClkInfo *info = &rfClkInfos[index];
    int ret = 0;

    switch (op) {
    case OP_WRITE:
        switch (info->type) {
        case RFCLK_LMK04XXX:
            ret = lmk04828Bwrite(info->muxSelect, value);
            break;

        case RFCLK_LMX2594:
            ret = lmx2594write(info->muxSelect, value);
            break;

        default:
            ret = -1;
        }
        break;

    case OP_READ:
        switch (info->type) {
        case RFCLK_LMK04XXX:
            ret = lmk04828Bread(info->muxSelect, value);
            break;

        case RFCLK_LMX2594:
            ret = lmx2594read(info->muxSelect, value);
            break;

        default:
            ret = -1;
        }
        break;

    default:
        ret = -1;
        break;
    }

    return ret;
}

int
rfClkRead(unsigned int index, uint32_t value)
{
    return rfClkOp(index, value, OP_READ);
}

int
rfClkWrite(unsigned int index, uint32_t value)
{
    return rfClkOp(index, value, OP_WRITE);
}

int
sfpGetStatus(uint32_t *buf)
{
    uint8_t rxBuf[10];
    uint16_t temp, vcc, txPower, rxPower;

    if (iicRead (IIC_INDEX_SFP_2_STATUS, 96, rxBuf, 10)) {
        temp = (rxBuf[0] << 8) + rxBuf[1];
        vcc = (rxBuf[2] << 8) + rxBuf[3];
        txPower = (rxBuf[6] << 8) | rxBuf[7];
        rxPower = (rxBuf[8] << 8) | rxBuf[9];
        buf[0] = (vcc << 16) | temp;
        buf[1] = (rxPower << 16) | txPower;
    }
    else {
        buf[0] = 0;
        buf[1] = 0;
    }
    return 2;
}

int
sfpGetTemperature(void)
{
    uint8_t rxBuf[2];
    if (iicRead (IIC_INDEX_SFP_2_STATUS, 96, rxBuf, 2)) {
        return ((int16_t)((rxBuf[0] << 8) + rxBuf[1]) * 10) / 256;
    }
    return 2550;
}

int
sfpGetRxPower(void)
{
    uint8_t rxBuf[2];
    if (iicRead (IIC_INDEX_SFP_2_STATUS, 96+8, rxBuf, 2)) {
        return (rxBuf[0] << 8) + rxBuf[1];
    }
    return 0;
}
