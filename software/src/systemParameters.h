/*
 * Global settings
 */

#ifndef _SYSTEM_PARAMETERS_H_
#define _SYSTEM_PARAMETERS_H_

#include <stdint.h>

#define SYSTEM_PARAMETERS_NAME "sysParms.csv"

struct sysNetParms {
    uint32_t  address;
    uint32_t  netmask;
    uint32_t  gateway;
};

struct sysNetConfig {
    unsigned char      ethernetMAC[8]; /* Pad to 4-byte boundary */
    struct sysNetParms ipv4;
};
extern struct sysNetConfig netDefault;
extern struct sysNetConfig currentNetConfig;

extern struct systemParameters {
    struct sysNetConfig netConfig;
    int                 userMGTrefClkOffsetPPM;
    int                 startupDebugFlags;
    int                 rfDivisor;
    int                 pllMultiplier;
    int                 isSinglePass;
    int                 singlePassEvent;
    int                 adcHeartbeatMarker;
    int                 evrPerFaMarker;
    int                 evrPerSaMarker;
    int                 adcOrder;
    float               xCalibration;
    float               yCalibration;
    float               qCalibration;
    int                 rfdcMMCMDivClkDivider;
    int                 rfdcMMCMMultiplier;
    int                 rfdcMMCMClk0Divider;
    int                 buttonRotation;
    int                 afeTrim[4]; /* Per-channel trims in units of 0.25 dB */
    uint32_t            checksum;
} systemParameters;


void systemParametersSetDefaults(void);
int systemParametersFetchEEPROM(void);
int systemParametersStashEEPROM(void);
void systemParametersCommit(void);

char *formatIP(const void *val);
int   parseIP(const char *str, void *val);
char *formatMAC(const void *val);
int   parseMAC(const char *str, void *val);

void showNetworkConfiguration(const struct sysNetParms *ipv4);
void systemParametersShowUserMGTrefClkOffsetPPM(void);

#endif
