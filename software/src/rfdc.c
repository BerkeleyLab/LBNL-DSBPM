/*
 * RF Analog to Digital Data Conversion
 */
#include <stdio.h>
#include <stdint.h>
typedef uint8_t __u8;
typedef uint16_t __u16;
typedef uint32_t __u32;
typedef uint64_t __u64;
typedef int32_t __s32;
typedef int64_t __s64;
#include <xrfdc.h>
#include <xrfdc_mts.h>
#include "gpio.h"
#include "config.h"
#include "rfdc.h"
#include "util.h"

#define XRFDC_ADC_OVR_VOLTAGE_MASK  0x04000000U
#define XRFDC_ADC_OVR_RANGE_MASK    0x08000000U

#define REG_W_MASTER_RESET   0x0004
#define REG_R_POWER_ON_STATE 0x0004

static XRFdc rfDC;
static int initDone;
static char logMessageBuffer[200];

/*
 * Stash message in buffer in case it's part of
 * an error message, then print that buffer.
 */
static void
myLogHandler(enum metal_log_level level, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    vsnprintf(logMessageBuffer, sizeof logMessageBuffer, format, args);
    va_end(args);
    printf("%s", logMessageBuffer);
}

void
rfADCshow(void)
{
    int tile;
    int adc;
    uint32_t v;
    XRFdc_IPStatus IPStatus;

    if (XRFdc_GetIPStatus(&rfDC, &IPStatus) != 0) {
        printf("Can't get IP status.\n");
        return;
    }
    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (!IPStatus.ADCTileStatus[tile].IsEnabled) continue;
        printf("ADC Tile %d (%d) enabled\n", tile, 224 + tile);
        printf("   ADC Tile state: %#X\n", IPStatus.ADCTileStatus[tile].TileState);
        printf("        ADC  Mask: %#X\n", IPStatus.ADCTileStatus[tile].BlockStatusMask);
        XRFdc_GetClockSource(&rfDC, XRFDC_ADC_TILE, tile, &v);
        printf(" ADC Clock source: %s\n",
                        v == XRFDC_INTERNAL_PLL_CLK ? "Internal PLL" :
                        v == XRFDC_EXTERNAL_CLK ? "External clock" : "Unknown");
        if (v == XRFDC_INTERNAL_PLL_CLK) {
            XRFdc_GetPLLLockStatus(&rfDC, XRFDC_ADC_TILE, tile, &v);
            printf("       ADC PLL locked state %d\n", (int)v);
        }
        for (adc = 0 ; adc < CFG_ADC_PER_TILE ; adc++) {
            int adcIdx = (tile * CFG_ADC_PER_TILE) + adc;
            int i;
            XRFdc_Mixer_Settings mixer;
            XRFdc_Cal_Freeze_Settings cfs;
            if (adcIdx >= CFG_ADC_PHYSICAL_COUNT) break;
            XRFdc_GetLinkCoupling(&rfDC, tile, adc, &v);
            printf("        ADC %d: %cC link", adcIdx,  v ? 'A' : 'D');
            XRFdc_GetIntrStatus(&rfDC, XRFDC_ADC_TILE, tile, adc, &v);
            if (v) {
                if (v & XRFDC_ADC_OVR_RANGE_MASK) printf(", Overrange");
                if (v & XRFDC_ADC_OVR_VOLTAGE_MASK) printf(", Overvoltage");
            }
            i = XRFdc_GetCalFreeze(&rfDC, tile, adc, &cfs);
            if (i == XST_SUCCESS) {
                if (cfs.FreezeCalibration) printf(", Freeze");
                if (cfs.CalFrozen) printf(", Frozen");
                if (cfs.DisableFreezePin) printf(", freeze pin disabled");
            }
            else {
                printf(", XRFdc_GetCalFreeze=%d", i);
            }
            printf("\n");
            i = XRFdc_GetMixerSettings(&rfDC, XRFDC_ADC_TILE, tile,adc,&mixer);
            if (i == XST_SUCCESS) {
                printf("ADC Mixer.Freq %g\n", mixer.Freq);
                printf("ADC Mixer.PhaseOffset %g\n", mixer.PhaseOffset);
                printf("ADC Mixer.EventSource %d\n", mixer.EventSource);
                printf("ADC Mixer.CoarseMixFreq %d\n", mixer.CoarseMixFreq);
                printf("ADC Mixer.MixerMode %d\n", mixer.MixerMode);
                printf("ADC Mixer.FineMixerScale %d\n", mixer.FineMixerScale);
                printf("ADC Mixer.MixerType %d\n", mixer.MixerType);
            }
            else {
                printf("ADC XRFdc_GetMixerSettings()=%d\n", i);
            }
        }
    }
}

void
rfDACshow(void)
{
    int tile;
    uint32_t v;
    XRFdc_IPStatus IPStatus;

    if (XRFdc_GetIPStatus(&rfDC, &IPStatus) != 0) {
        printf("Can't get IP status.\n");
        return;
    }
    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (!IPStatus.DACTileStatus[tile].IsEnabled) continue;
        printf("DAC Tile %d (%d) enabled\n", tile, 224 + tile);
        printf("   DAC Tile state: %#X\n", IPStatus.DACTileStatus[tile].TileState);
        printf("         DAC Mask: %#X\n", IPStatus.DACTileStatus[tile].BlockStatusMask);
        XRFdc_GetClockSource(&rfDC, XRFDC_DAC_TILE, tile, &v);
        printf(" DAC Clock source: %s\n",
                        v == XRFDC_INTERNAL_PLL_CLK ? "Internal PLL" :
                        v == XRFDC_EXTERNAL_CLK ? "External clock" : "Unknown");
        if (v == XRFDC_INTERNAL_PLL_CLK) {
            XRFdc_GetPLLLockStatus(&rfDC, XRFDC_DAC_TILE, tile, &v);
            printf("       DAC PLL locked state %d\n", (int)v);
        }
    }
}

int
rfADClinkCouplingIsAC(void)
{
    int tile;
    int adc;
    uint32_t v;
    int firstTime = 1;
    XRFdc_IPStatus IPStatus;
    static int isAC = 1;

    if (!firstTime) return isAC;
    if (XRFdc_GetIPStatus(&rfDC, &IPStatus) != 0) {
        printf("Can't get IP status -- assuming AC coupling.\n");
        return 1;
    }
    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (!IPStatus.ADCTileStatus[tile].IsEnabled) continue;
        for (adc = 0 ; adc < CFG_ADC_PER_TILE ; adc++) {
            XRFdc_GetLinkCoupling(&rfDC, tile, adc, &v);
            if (firstTime) {
                firstTime = 0;
                isAC = v;
            }
            else if (isAC != v) {
                printf("ADC coupling differs -- reverting to AC coupling\n");
                return 1;
            }
        }
    }
    return isAC;
}

static void rfADCCfgDefaults(void)
{
    int i, tile, adc;

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        i = XRFdc_DynamicPLLConfig(&rfDC, XRFDC_ADC_TILE, tile,
                                          XRFDC_EXTERNAL_CLK,
                                          CFG_ADC_REF_CLK_FREQ,
                                          CFG_ADC_SAMPLING_CLK_FREQ);
        if (i != XST_SUCCESS) fatal("XRFdc_DynamicPLLConfig(XRFDC_ADC_TILE)=%d", i);

        // Override GUI mixer settings
#ifdef CFG_ADC_NCO_FREQ
        for (adc = 0 ; adc < CFG_ADC_PER_TILE ; adc++) {
            XRFdc_Mixer_Settings mixer;
            i = XRFdc_GetMixerSettings(&rfDC, XRFDC_ADC_TILE, tile, adc, &mixer);
            if (i != XST_SUCCESS) warn("XRFdc_GetMixerSettings(XRFDC_ADC_TILE)=%d", i);

            mixer.Freq = CFG_ADC_NCO_FREQ;
            mixer.EventSource = XRFDC_EVNT_SRC_TILE;
            i = XRFdc_SetMixerSettings(&rfDC, XRFDC_ADC_TILE, tile, adc, &mixer);
            if (i != XST_SUCCESS) warn("XRFdc_SetMixerSettings(XRFDC_ADC_TILE)=%d", i);

            // Reset NCO phase
            i = XRFdc_ResetNCOPhase(&rfDC, XRFDC_ADC_TILE, tile, adc);
            if (i != XST_SUCCESS) warn("XRFdc_ResetNCOPhase(XRFDC_ADC_TILE)=%d", i);
        }

        // Update Mixer settings. Applies to all blocks in a tile
        i = XRFdc_UpdateEvent(&rfDC, XRFDC_ADC_TILE, tile, 0, XRFDC_EVENT_MIXER);
        if (i != XST_SUCCESS) warn("XRFdc_UpdateEvent(XRFDC_ADC_TILE)=%d", i);
#endif
    }
}

static void rfDACCfgDefaults(void)
{
    int i, tile, dac;

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        i = XRFdc_DynamicPLLConfig(&rfDC, XRFDC_DAC_TILE, tile,
                                          XRFDC_EXTERNAL_CLK,
                                          CFG_DAC_REF_CLK_FREQ,
                                          CFG_DAC_SAMPLING_CLK_FREQ);
        if (i != XST_SUCCESS) fatal("XRFdc_DynamicPLLConfig(xrfdc_dac_tile)=%d", i);

        // Override GUI mixer settings
#ifdef CFG_DAC_NCO_FREQ
        for (dac = 0 ; dac < CFG_DAC_PER_TILE ; dac++) {
            XRFdc_Mixer_Settings mixer;
            i = XRFdc_GetMixerSettings(&rfDC, XRFDC_DAC_TILE, tile, dac, &mixer);
            if (i != XST_SUCCESS) warn("XRFdc_GetMixerSettings(XRFDC_DAC_TILE)=%d", i);

            mixer.Freq = CFG_DAC_NCO_FREQ;
            mixer.EventSource = XRFDC_EVNT_SRC_TILE;
            i = XRFdc_SetMixerSettings(&rfDC, XRFDC_DAC_TILE, tile, dac, &mixer);
            if (i != XST_SUCCESS) warn("XRFdc_SetMixerSettings(XRFDC_DAC_TILE)=%d", i);

            // Reset NCO phase
            i = XRFdc_ResetNCOPhase(&rfDC, XRFDC_DAC_TILE, tile, dac);
            if (i != XST_SUCCESS) warn("XRFdc_ResetNCOPhase(XRFDC_DAC_TILE)=%d", i);
        }

        // Update Mixer settings. Applies to all blocks in a tile
        i = XRFdc_UpdateEvent(&rfDC, XRFDC_DAC_TILE, tile, 0, XRFDC_EVENT_MIXER);
        if (i != XST_SUCCESS) warn("XRFdc_UpdateEvent(XRFDC_DAC_TILE)=%d", i);
#endif
    }
}

void
rfDCinit(void)
{
    int i;
    XRFdc_Config *configp;
    static struct metal_init_params init_param = METAL_INIT_DEFAULTS;

    if (metal_init(&init_param)) {
        fatal("metal_init failed");
    }
    metal_set_log_handler(myLogHandler);
    metal_set_log_level(METAL_LOG_INFO);

    configp = XRFdc_LookupConfig(XPAR_XRFDC_0_DEVICE_ID);
    if (!configp) fatal("XRFdc_LookupConfig");
    i = XRFdc_CfgInitialize(&rfDC, configp);
    if (i != XST_SUCCESS) fatal("XRFdc_CfgInitialize=%d", i);

    rfADCCfgDefaults();
    rfDACCfgDefaults();
    initDone = 1;

    if (debugFlags & DEBUGFLAG_RF_ADC_SHOW) rfADCshow();
    if (debugFlags & DEBUGFLAG_RF_DAC_SHOW) rfDACshow();
}


/*
 * AFE must be supplying 0.0V to all channels
 */
void
rfADCrestart(void)
{
    int i;
    logMessageBuffer[0] = '\0';
    i = XRFdc_Reset(&rfDC, XRFDC_ADC_TILE, XRFDC_SELECT_ALL_TILES);
    if (i != XST_SUCCESS) warn("Critical -- ADC - %s\nXRFdc_Reset=%d",
                                                           logMessageBuffer, i);
    rfADCCfgDefaults();
}

void
rfDACrestart(void)
{
    int i;
    logMessageBuffer[0] = '\0';
    i = XRFdc_Reset(&rfDC, XRFDC_DAC_TILE, XRFDC_SELECT_ALL_TILES);
    if (i != XST_SUCCESS) warn("Critical -- DAC - %s\nXRFdc_Reset=%d",
                                                           logMessageBuffer, i);
    rfDACCfgDefaults();
}

void
rfDCsync(void)
{
    int tile, latency, status;
    XRFdc_IPStatus IPStatus;
    XRFdc_MultiConverter_Sync_Config adcConfig, dacConfig;

    if (!initDone) return;
    if (XRFdc_GetIPStatus(&rfDC, &IPStatus) != 0) {
        printf("Can't get IP status.\n");
        return;
    }
    XRFdc_MultiConverter_Init(&dacConfig, NULL, NULL);
    XRFdc_MultiConverter_Init(&adcConfig, NULL, NULL);
    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (IPStatus.ADCTileStatus[tile].IsEnabled) {
            adcConfig.Tiles |= 1 << tile;
        }
    }

    /*
     * Enable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDC, &dacConfig, &adcConfig, 1);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(1) failed: %d", status);
        return;
    }

    /*
     * Synchronize between tiles in each group
     */
    status = XRFdc_MultiConverter_Sync(&rfDC, XRFDC_ADC_TILE, &adcConfig);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MultiConverter_Sync (tiles) failed: %d", status);
        return;
    }

#if 0
/* If latency variation causes problems, say with acquired signals moving
 * relative to event triggers, this code can be enabled, perhaps with the
 * addition of a system configuration value for the target latency.
 * E. Norum 2020-10-10 */
    /*
     * Synchronize between groups as described on page 125 of PG269 (v2.1)
     * "Zynq UltraScale+ RFSoC RF Data Converter", "Advanced Multi-Converter
     * Sync API Use".
     */
    latency = -1;
    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (adcConfig.Latency[tile] > latency) {
            latency = adcConfig.Latency[tile];
        }
    }
    adcConfig.Target_Latency = latency + 8;
    status = XRFdc_MultiConverter_Sync(&rfDC, XRFDC_ADC_TILE, &adcConfig);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MultiConverter_Sync (groups) failed: %d", status);
        return;
    }
#endif
    printf("ADC synchronization complete.\n");

    /*
     * Disable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDC, &dacConfig, &adcConfig, 0);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(0) failed: %d", status);
        return;
    }
}

void
rfADCfreezeCalibration(int channel, int freeze)
{
    int i;
    XRFdc_Cal_Freeze_Settings cfs;
    int tile = channel / CFG_ADC_PER_TILE;
    int adc = channel % CFG_ADC_PER_TILE;

    freeze = (freeze != 0);
    cfs.DisableFreezePin = 1;
    cfs.FreezeCalibration = freeze;
    i = XRFdc_SetCalFreeze(&rfDC, tile, adc, &cfs);
    if (i == XST_SUCCESS) {
        uint32_t then = MICROSECONDS_SINCE_BOOT();
        for (;;) {
            i = XRFdc_GetCalFreeze(&rfDC, tile, adc, &cfs);
            if (i != XST_SUCCESS) {
                warn("XRFdc_GetCalFreeze tile %d, adc %d: %d", tile, adc, i);
                break;
            }
            if (cfs.CalFrozen == freeze) {
                break;
            }
            if ((MICROSECONDS_SINCE_BOOT() - then) > 20) {
                warn("XRFdc_SetCalFreeze tile %d, adc %d, freeze %d timeout",
                                                             tile, adc, freeze);
                break;
            }
        }
    }
    else {
        warn("XRFdc_SetCalFreeze tile %d, adc %d: %d", tile, adc, i);
    }
}

unsigned int
rfADCstatus(void)
{
    int status = 0;
    int tile, adc;
    int statusShift = 0;
    uint32_t v;

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        for (adc = 0 ; adc < CFG_ADC_PER_TILE ; adc++) {
            int b = 0;
            if (((tile * CFG_ADC_PER_TILE) + adc) >= CFG_ADC_PHYSICAL_COUNT) break;
            XRFdc_GetIntrStatus(&rfDC, XRFDC_ADC_TILE, tile, adc, &v);
            if (v) {
                b |= (v & XRFDC_ADC_OVR_RANGE_MASK) ? 0x1 : 0;
                b |= (v & XRFDC_ADC_OVR_VOLTAGE_MASK)  ? 0x2 : 0;
                XRFdc_IntrClr(&rfDC, XRFDC_ADC_TILE, tile, adc, v);
            }
            status |= b << statusShift;
            statusShift += 2;
        }
    }
    return status;
}

float
rfADCGetDSA(int channel)
{
    int i;
    XRFdc_DSA_Settings dsa;
    int tile = channel / CFG_ADC_PER_TILE;
    int adc = channel % CFG_ADC_PER_TILE;

    i = XRFdc_GetDSA(&rfDC, tile, adc, &dsa);
    if (i != XST_SUCCESS) {
        printf("XRFdc_GetDSA tile %d, adc %d: %d", tile, adc, i);
        return -1.0;
    }

    return dsa.Attenuation;
}

void
rfADCSetDSA(int channel, float att)
{
    int i;
    XRFdc_DSA_Settings dsa;
    int tile = channel / CFG_ADC_PER_TILE;
    int adc = channel % CFG_ADC_PER_TILE;

    i = XRFdc_GetDSA(&rfDC, tile, adc, &dsa);
    if (i != XST_SUCCESS) {
        printf("XRFdc_GetDSA tile %d, adc %d: %d", tile, adc, i);
        return;
    }

    dsa.Attenuation = att;
    i = XRFdc_SetDSA(&rfDC, tile, adc, &dsa);
    if (i != XST_SUCCESS) {
        printf("XRFdc_SetDSA tile %d, adc %d: %d", tile, adc, i);
        return;
    }
}

/* att is in mDb, integer */
void
rfADCSetDSADSBPM(unsigned int bpm, int channel, int mDbAtt)
{
    float att;
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return;

    att = ((float) mDbAtt) / 1000;
    ch = bpm * CFG_ADC_PER_BPM_COUNT + channel;
    rfADCSetDSA(ch, att);
}

int
rfADCGetDSADSBPM(unsigned int bpm, int channel)
{
    float att;
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return -1;

    ch = bpm * CFG_ADC_PER_BPM_COUNT + channel;
    att = rfADCGetDSA(ch);

    return att * 1000;
}
