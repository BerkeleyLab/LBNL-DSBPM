#include <stdio.h>
#include <lwipopts.h>
#include <lwip/init.h>
#include <lwip/inet.h>
#include <netif/xadapter.h>
#include "afe.h"
#include "ami.h"
#include "console.h"
#include "display.h"
#include "epics.h"
#include "evr.h"
#include "evrSROC.h"
#include "eyescan.h"
#include "ffs.h"
#include "gpio.h"
#include "iic.h"
#include "idtClk.h"
#include "mgt.h"
#include "mmcm.h"
#include "platform.h"
#include "rfdc.h"
#include "rfclk.h"
#include "softwareBuildDate.h"
#include "st7789v.h"
#include "sysref.h"
#include "sysmon.h"
#include "systemParameters.h"
#include "tftp.h"
#include "util.h"
#include "localOscillator.h"
#include "ptGen.h"
#include "autotrim.h"
#include "acqSync.h"
#include "publisher.h"
#include "positionCalc.h"
#include "waveformRecorder.h"
#include "cellComm.h"

static void
sfpString(const char *name, int offset)
{
    uint8_t rxBuf[17];
    rxBuf[16] = '\0';
    if (iicRead (IIC_INDEX_SFP_0_INFO, offset, rxBuf, 16))
        printf("%16s: %s\n", name, rxBuf);
}
static void sfpChk(void)
{
    uint8_t rxBuf[10];
    int i;
    int f;
    sfpString("Manufacturer ID", 20);
    sfpString("Part Number", 40);
    sfpString("Serial Number", 68);
    if (iicRead (IIC_INDEX_SFP_0_INFO, 84, rxBuf, 6))
        printf("%16s: 20%c%c-%c%c-%c%c\n", "Date Code", rxBuf[0], rxBuf[1], rxBuf[2], rxBuf[3], rxBuf[4], rxBuf[5]);
    if (iicRead (IIC_INDEX_SFP_0_STATUS, 96, rxBuf, 10)) {
        i = rxBuf[0];
        f = (rxBuf[1] * 100) / 256;
        printf("     Temperature: %d.%02d\n", i, f);
        i = (rxBuf[2] << 8) + rxBuf[3];
        i /= 10;
        f = i % 1000;
        i /= 1000;
        printf("             Vcc: %d.%03d\n", i, f);
        i = (rxBuf[8] << 8) + rxBuf[9];
        f = i % 10;
        i /= 10;
        printf("   Rx Power (uW): %d.%d\n", i, f);
    }
}

int
main(void)
{
    int isRecovery;
    int bpm;
    static ip_addr_t ipaddr, netmask, gateway;
    static struct netif netif;

    /* Set up infrastructure */
    init_platform();
    platform_enable_interrupts();
    /* Must be called before filesystemReadbacks() */
    systemParametersSetDefaults();
    isRecovery = resetRecoverySwitchPressed();

    /* Announce our presence */
    st7789vInit();
    printf("\nGit ID (32-bit): 0x%08x\n", GPIO_READ(GPIO_IDX_GITHASH));
    printf("Firmware POSIX seconds: %u\n",
            (unsigned int) GPIO_READ(GPIO_IDX_FIRMWARE_BUILD_DATE));
    printf("Software POSIX seconds: %d\n", SOFTWARE_BUILD_DATE);
    displayInfo();

    /* Set up file system */
    ffsCheck();

    /* Get configuration settings */
    iicInit();
    /* Readback configurations from filesystem, if available */
    filesystemReadbacks();

    if (isRecovery) {
        printf("==== Recovery mode -- Using default network parameters ====\n");
        currentNetConfig = netDefault;
    }
    else {
        currentNetConfig = systemParameters.netConfig;
    }
    drawIPv4Address(&currentNetConfig.ipv4.address, isRecovery);

    /* Set up hardware */
    sysmonInit();
    sfpChk();
    mgtClkIDTInit();
    eyescanInit();
    mgtInit();
    evrInit();
    cellCommInit();
    rfClkPreInit();
    mmcmInit();
    rfClkInit();
    sysrefInit(0);
    sysrefInit(1);
    sysrefShow(0);
    sysrefShow(1);
    rfDCinit();
    afeInit();
    amiInit();
    rfADCrestart();
    rfDACrestart();
    rfDCsync();

    /*
     * Show AFE sensors
     */
    for (bpm = 0; bpm < CFG_DSBPM_COUNT; bpm++) {
        amiPSinfoDisplay(bpm);
    }

    /* Start network */
    lwip_init();
    printf("Network:\n");
    printf("       MAC: %s\n", formatMAC(currentNetConfig.ethernetMAC));
    showNetworkConfiguration(&currentNetConfig.ipv4);
    ipaddr.addr = currentNetConfig.ipv4.address;
    netmask.addr = currentNetConfig.ipv4.netmask;
    gateway.addr = currentNetConfig.ipv4.gateway;
    printf("If things lock up at this point it's likely because\n"
           "the network driver can't negotiate a connection.\n");
    displayShowStatusLine("-- Intializing Network --");
    if (!xemac_add(&netif, &ipaddr, &netmask, &gateway, currentNetConfig.ethernetMAC,
                                                     XPAR_XEMACPS_0_BASEADDR)) {
        fatal("Error adding network interface");
    }
    netif_set_default(&netif);
    netif_set_up(&netif);
    displayShowStatusLine("");

    /* Set up communications and acquisition */
    epicsInit();
    tftpInit();
    publisherInit();
    acqSyncInit();
    evrSROCInit();

    for (bpm = 0; bpm < CFG_DSBPM_COUNT; bpm++) {
        localOscillatorInit(bpm);
        ptGenInit(bpm);
        positionCalcInit(bpm);
        wfrInit(bpm);
    }

    /*
     * Main processing loop
     */
    printf("DFE serial number: %03d\n", serialNumberDFE());
    printf("AFE serial number: %03d\n", afeGetSerialNumber());
    if (displayGetMode() == DISPLAY_MODE_STARTUP) {
        displaySetMode(DISPLAY_MODE_PAGES);
    }
    for (;;) {
        checkForReset();
        mgtCrankRxAligner();
        cellCommCrank();
        amiCrank();
        xemacif_input(&netif);
        publisherCheck();
        consoleCheck();
        ffsCheck();
        displayUpdate();
    }

    /* Never reached */
    cleanup_platform();
    return 0;
}
