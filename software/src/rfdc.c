/*
 * RF Analog to Digital Data Conversion
 */
#include <stddef.h>
#include <stdio.h>
#include <stdint.h>
typedef uint8_t __u8;
typedef uint16_t __u16;
typedef uint32_t __u32;
typedef uint64_t __u64;
typedef int32_t __s32;
typedef int64_t __s64;
#include <xrfdc.h>
#include <assert.h>
#include <stdbool.h>
#include "gpio.h"
#include "config.h"
#include "rfdc.h"
#include "util.h"

static_assert(CFG_ADC_TILES_COUNT == CFG_DAC_TILES_COUNT,
    "CFG_ADC_TILES_COUNT != CFG_DAC_TILES_COUNT");

#define XRFDC_ADC_OVR_VOLTAGE_MASK  0x04000000U
#define XRFDC_ADC_OVR_RANGE_MASK    0x08000000U

#define REG_W_MASTER_RESET   0x0004
#define REG_R_POWER_ON_STATE 0x0004

static int rfDCCopyTileState(rfDCType type, uint32_t *tileState, size_t capacity);
static int rfDCChangeTileState(rfDCType type, int tile, uint32_t requestState);
static int rfDCChangeTilePwrRaw(rfDCType type, uint32_t *requestStatus);
static int rfDCChangeTilePwr(rfDCType type, int tile, int on);

static struct rfDCCfg {
    XRFdc rfDC;
    double adcRefClk;
    double adcSampRate;
    double adcNCOFreq;
    double dacRefClk;
    double dacSampRate;
    double dacNCOFreq;
    int adcTileRefClk;
    int dacTileRefClk;
    int initDone;
    char logMessageBuffer[200];
} rfDCCfg = {
    .adcRefClk = ADC_REF_CLK_FREQ,
    .adcSampRate = ADC_SAMPLING_CLK_FREQ,
    .adcNCOFreq = ADC_NCO_FREQ,
    .dacRefClk = DAC_REF_CLK_FREQ,
    .dacSampRate = DAC_SAMPLING_CLK_FREQ,
    .dacNCOFreq = DAC_NCO_FREQ,
    // Check BD design for this
    .adcTileRefClk = 1,
    .dacTileRefClk = 2,
};

void
rfADCSetCfg(double refClk, double sampRate, double NCOFreq)
{
    rfDCCfg.adcRefClk = refClk;
    rfDCCfg.adcSampRate = sampRate;
    rfDCCfg.adcNCOFreq = NCOFreq;
}

void
rfDACSetCfg(double refClk, double sampRate, double NCOFreq)
{
    rfDCCfg.dacRefClk = refClk;
    rfDCCfg.dacSampRate = sampRate;
    rfDCCfg.dacNCOFreq = NCOFreq;
}

/*
 * Stash message in buffer in case it's part of
 * an error message, then print that buffer.
 */
static void
myLogHandler(enum metal_log_level level, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    vsnprintf(rfDCCfg.logMessageBuffer, sizeof rfDCCfg.logMessageBuffer, format, args);
    va_end(args);
    printf("%s", rfDCCfg.logMessageBuffer);
}

void
rfADCshow(void)
{
    int tile;
    int adc;
    uint32_t v;
    XRFdc_IPStatus IPStatus;
    XRFdc_PLL_Settings PLLSettings;

    if (XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus) != 0) {
        printf("Can't get IP status.\n");
        return;
    }

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (!IPStatus.ADCTileStatus[tile].IsEnabled) {
            continue;
        }

        printf("ADC Tile %d (%d) enabled\n", tile, 224 + tile);
        printf("   ADC Tile state: %#X\n", IPStatus.ADCTileStatus[tile].TileState);
        printf("        ADC  Mask: %#X\n", IPStatus.ADCTileStatus[tile].BlockStatusMask);
        XRFdc_GetClockSource(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, &v);
        printf("     Clock source: %s\n",
                        v == XRFDC_INTERNAL_PLL_CLK ? "Internal PLL" :
                        v == XRFDC_EXTERNAL_CLK ? "External clock" : "Unknown");

        if (v == XRFDC_INTERNAL_PLL_CLK) {
            XRFdc_GetPLLLockStatus(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, &v);
            printf("      ADC PLL locked state %d\n", (int)v);
        }

        XRFdc_GetPLLConfig(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, &PLLSettings);
        printf("       PLL %s\n", PLLSettings.Enabled ? "enabled" : "disabled");
        printf("     Ref Clk Freq: %g MHz\n", PLLSettings.RefClkFreq);
        printf("    Sampling Rate: %g GHz\n", PLLSettings.SampleRate);

        for (adc = 0 ; adc < CFG_ADC_PER_TILE ; adc++) {
            int adcIdx = (tile * CFG_ADC_PER_TILE) + adc;
            int i;
            XRFdc_Mixer_Settings mixer;
            XRFdc_Cal_Freeze_Settings cfs;

            if (adcIdx >= CFG_ADC_PHYSICAL_COUNT) {
                break;
            }

            XRFdc_GetLinkCoupling(&rfDCCfg.rfDC, tile, adc, &v);
            printf("   ADC %d: %cC link", adcIdx,  v ? 'A' : 'D');
            XRFdc_GetIntrStatus(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, adc, &v);

            if (v) {
                if (v & XRFDC_ADC_OVR_RANGE_MASK) {
                    printf(", Overrange");
                }
                if (v & XRFDC_ADC_OVR_VOLTAGE_MASK) {
                    printf(", Overvoltage");
                }
            }

            i = XRFdc_GetCalFreeze(&rfDCCfg.rfDC, tile, adc, &cfs);

            if (i == XST_SUCCESS) {
                if (cfs.FreezeCalibration) {
                    printf(", Freeze");
                }
                if (cfs.CalFrozen) {
                    printf(", Frozen");
                }
                if (cfs.DisableFreezePin) {
                    printf(", freeze pin disabled");
                }
            }
            else {
                printf(", XRFdc_GetCalFreeze=%d", i);
            }

            printf("\n");
            XRFdc_GetDither(&rfDCCfg.rfDC, tile, adc, &v);
            printf("      Dither: %s\n", v ? "enabled" : "disabled");

            i = XRFdc_GetMixerSettings(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile,adc,&mixer);
            if (i == XST_SUCCESS) {
                printf("      Mixer Settings\n");
                printf("               Freq: %g MHz\n", mixer.Freq);
                printf("        PhaseOffset: %g degrees\n", mixer.PhaseOffset);
                printf("        EventSource: %d\n", mixer.EventSource);
                printf("      CoarseMixFreq: %d\n", mixer.CoarseMixFreq);
                printf("          MixerMode: %d\n", mixer.MixerMode);
                printf("     FineMixerScale: %d\n", mixer.FineMixerScale);
                printf("          MixerType: %d\n", mixer.MixerType);
            }
            else {
                printf("      XRFdc_GetMixerSettings()=%d\n", i);
            }
        }
    }
}

void
rfDACshow(void)
{
    int tile, dac, duc;
    uint32_t v;
    XRFdc_IPStatus IPStatus;
    XRFdc_PLL_Settings PLLSettings;

    if (XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus) != 0) {
        printf("Can't get IP status.\n");
        return;
    }

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (!IPStatus.DACTileStatus[tile].IsEnabled) {
            continue;
        }

        printf("DAC Tile %d (%d) enabled\n", tile, 228 + tile);
        printf("   DAC Tile state: %#X\n", IPStatus.DACTileStatus[tile].TileState);
        printf("         DAC Mask: %#X\n", IPStatus.DACTileStatus[tile].BlockStatusMask);
        XRFdc_GetClockSource(&rfDCCfg.rfDC, XRFDC_DAC_TILE, tile, &v);
        printf("     Clock source: %s\n",
                        v == XRFDC_INTERNAL_PLL_CLK ? "Internal PLL" :
                        v == XRFDC_EXTERNAL_CLK ? "External clock" : "Unknown");

        if (v == XRFDC_INTERNAL_PLL_CLK) {
            XRFdc_GetPLLLockStatus(&rfDCCfg.rfDC, XRFDC_DAC_TILE, tile, &v);
            printf("      DAC PLL locked state %d\n", (int)v);
        }

        XRFdc_GetPLLConfig(&rfDCCfg.rfDC, XRFDC_DAC_TILE, tile, &PLLSettings);
        printf("       PLL %s\n", PLLSettings.Enabled ? "enabled" : "disabled");
        printf("     Ref Clk Freq: %g MHz\n", PLLSettings.RefClkFreq);
        printf("    Sampling Rate: %g GHz\n", PLLSettings.SampleRate);

        for (dac = 0 ; dac < CFG_DAC_PER_TILE ; dac++) {
            for (duc = 0; duc < CFG_DAC_DUC_PER_DAC; duc++) {
                int i;
                XRFdc_Mixer_Settings mixer;
                printf("   DAC/DUC %d/%d\n", tile*CFG_DAC_PER_TILE + dac, duc);
                i = XRFdc_GetMixerSettings(&rfDCCfg.rfDC, XRFDC_DAC_TILE, tile, dac*CFG_DAC_DUC_OFFSET + duc,
                        &mixer);
                if (i == XST_SUCCESS) {
                    printf("      Mixer Settings\n");
                    printf("               Freq: %g MHz\n", mixer.Freq);
                    printf("        PhaseOffset: %g degrees\n", mixer.PhaseOffset);
                    printf("        EventSource: %d\n", mixer.EventSource);
                    printf("      CoarseMixFreq: %d\n", mixer.CoarseMixFreq);
                    printf("          MixerMode: %d\n", mixer.MixerMode);
                    printf("     FineMixerScale: %d\n", mixer.FineMixerScale);
                    printf("          MixerType: %d\n", mixer.MixerType);
                }
                else {
                    printf("      XRFdc_GetMixerSettings()=%d\n", i);
                }
            }
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
    if (XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus) != 0) {
        printf("Can't get IP status -- assuming AC coupling.\n");
        return 1;
    }
    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (!IPStatus.ADCTileStatus[tile].IsEnabled) continue;
        for (adc = 0 ; adc < CFG_ADC_PER_TILE ; adc++) {
            XRFdc_GetLinkCoupling(&rfDCCfg.rfDC, tile, adc, &v);
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

static int
rfADCCfgStaticSingle(int tile)
{
    int status = XRFdc_DynamicPLLConfig(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile,
                                   XRFDC_EXTERNAL_CLK,
                                   rfDCCfg.adcRefClk,
                                   rfDCCfg.adcSampRate);

    if (status != XST_SUCCESS) {
        warn("ADC Tile %d XRFdc_DynamicPLLConfig() = %d", tile, status);
    }

    int status2 = 0;
    int status2Latch = 0;
    for (int adc = 0 ; adc < CFG_ADC_PER_TILE ; adc++) {
        status2 = XRFdc_SetDither(&rfDCCfg.rfDC, tile, adc, 1);
        if (status2 != XST_SUCCESS) {
            status2Latch |= status2;
            warn("ADC Tile:Block %d:%d XRFdc_SetDither() = %d", tile, adc, status2);
        }
    }

    return (status | status2Latch);
}

static int
rfADCCfgStatic(void)
{

    if (!rfDCCfg.initDone) {
        return -1;
    }

    int status = 0;
    for (int tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        status |= rfADCCfgStaticSingle(tile);
    }

    return status;
}

static void
rfADCCfg(void)
{
    int i, tile, adc, status;

    XRFdc_IPStatus IPStatus;
    XRFdc_MultiConverter_Sync_Config adcConfig, dacConfig;

    if (!rfDCCfg.initDone) {
        return;
    }

    if (XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus) != 0) {
        printf("Can't get IP status.\n");
        return;
    }

    XRFdc_MultiConverter_Init(&dacConfig, NULL, NULL, rfDCCfg.dacTileRefClk);
    XRFdc_MultiConverter_Init(&adcConfig, NULL, NULL, rfDCCfg.adcTileRefClk);

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (IPStatus.ADCTileStatus[tile].IsEnabled &&
            (IPStatus.ADCTileStatus[tile].TileState == XRFDC_STATE_FULL)) {
            adcConfig.Tiles |= 1 << tile;
        }
        if (IPStatus.DACTileStatus[tile].IsEnabled &&
            (IPStatus.DACTileStatus[tile].TileState == XRFDC_STATE_FULL)) {
            dacConfig.Tiles |= 1 << tile;
        }
    }

    /*
     * Disable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDCCfg.rfDC, &dacConfig, &adcConfig, 0);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(0) failed: %d", status);
        return;
    }

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        // Override GUI mixer settings
#ifdef ADC_NCO_FREQ
        for (adc = 0 ; adc < CFG_ADC_PER_TILE ; adc++) {
            XRFdc_Mixer_Settings mixer;
            i = XRFdc_GetMixerSettings(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, adc, &mixer);
            if (i != XST_SUCCESS) warn("ADC Tile:Block %d:%d XRFdc_GetMixerSettings() = %d",
                    tile, adc, i);

            mixer.Freq = rfDCCfg.adcNCOFreq;
            mixer.EventSource = XRFDC_EVNT_SRC_SYSREF;
            i = XRFdc_SetMixerSettings(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, adc, &mixer);
            if (i != XST_SUCCESS) warn("ADC Tile:Block %d:%d XRFdc_SetMixerSettings() = %d",
                    tile, adc, i);

            // Reset NCO phase
            i = XRFdc_ResetNCOPhase(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, adc);
            if (i != XST_SUCCESS) warn("ADC Tile:Block %d:%d XRFdc_ResetNCOPhase() = %d",
                    tile, adc, i);
        }
#endif
    }

    /*
     * Enable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDCCfg.rfDC, &dacConfig, &adcConfig, 1);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(1) failed: %d", status);
        return;
    }

    /*
     * Make sure we have enough SYSREF cycles
     */
    microsecondSpin(100);

    /*
     * Disable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDCCfg.rfDC, &dacConfig, &adcConfig, 0);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(0) failed: %d", status);
        return;
    }
}

static int
rfDACCfgStaticSingle(int tile)
{
    int status = XRFdc_DynamicPLLConfig(&rfDCCfg.rfDC, XRFDC_DAC_TILE, tile,
                                        XRFDC_EXTERNAL_CLK,
                                        rfDCCfg.dacRefClk,
                                        rfDCCfg.dacSampRate);

    if (status != XST_SUCCESS) {
        warn("DAC Tile %d rfDACCfgStaticSingle() = %d", tile, status);
    }

    return status;
}

static int
rfDACCfgStatic(void)
{
    if (!rfDCCfg.initDone) {
        return -1;
    }

    int status = 0;
    for (int tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        status |= rfDACCfgStaticSingle(tile);
    }

    return status;
}

static void
rfDACCfg(void)
{
    int i, tile, dac, duc, status;

    XRFdc_IPStatus IPStatus;
    XRFdc_MultiConverter_Sync_Config adcConfig, dacConfig;

    if (!rfDCCfg.initDone) {
        return;
    }

    if (XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus) != 0) {
        printf("Can't get IP status.\n");
        return;
    }

    XRFdc_MultiConverter_Init(&dacConfig, NULL, NULL, rfDCCfg.dacTileRefClk);
    XRFdc_MultiConverter_Init(&adcConfig, NULL, NULL, rfDCCfg.adcTileRefClk);

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (IPStatus.ADCTileStatus[tile].IsEnabled &&
            (IPStatus.ADCTileStatus[tile].TileState == XRFDC_STATE_FULL)) {
            adcConfig.Tiles |= 1 << tile;
        }
        if (IPStatus.DACTileStatus[tile].IsEnabled &&
            (IPStatus.DACTileStatus[tile].TileState == XRFDC_STATE_FULL)) {
            dacConfig.Tiles |= 1 << tile;
        }
    }

    /*
     * Disable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDCCfg.rfDC, &dacConfig, &adcConfig, 0);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(0) failed: %d", status);
        return;
    }

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        // Override GUI mixer settings
#ifdef DAC_NCO_FREQ
        // Because we are using I/Q -> real mixer we only have
        // 1 datapath enable per DAC
        for (dac = 0 ; dac < CFG_DAC_PER_TILE ; dac++) {
            for (duc = 0; duc < CFG_DAC_DUC_PER_DAC; duc++) {
                XRFdc_Mixer_Settings mixer;
                i = XRFdc_GetMixerSettings(&rfDCCfg.rfDC, XRFDC_DAC_TILE, tile,
                        dac*CFG_DAC_DUC_OFFSET + duc, &mixer);
                if (i != XST_SUCCESS) warn("DAC Tile:Block %d:%d XRFdc_GetMixerSettings() = %d",
                        tile, dac*CFG_DAC_DUC_OFFSET + duc, i);

                mixer.Freq = rfDCCfg.dacNCOFreq;
                mixer.FineMixerScale = XRFDC_MIXER_SCALE_1P0;
                mixer.EventSource = XRFDC_EVNT_SRC_SYSREF;
                i = XRFdc_SetMixerSettings(&rfDCCfg.rfDC, XRFDC_DAC_TILE, tile, dac*CFG_DAC_DUC_OFFSET + duc, &mixer);
                if (i != XST_SUCCESS) warn("DAC Tile:Block %d:%d XRFdc_SetMixerSettings() = %d",
                        tile, dac*CFG_DAC_DUC_OFFSET + duc, i);

                // Reset NCO phase
                i = XRFdc_ResetNCOPhase(&rfDCCfg.rfDC, XRFDC_DAC_TILE, tile, dac*CFG_DAC_DUC_OFFSET + duc);
                if (i != XST_SUCCESS) warn("DAC Tile:Block %d:%d XRFdc_ResetNCOPhase() = %d",
                        tile, dac*CFG_DAC_DUC_OFFSET + duc, i);
            }
        }
#endif
    }

    /*
     * Enable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDCCfg.rfDC, &dacConfig, &adcConfig, 1);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(1) failed: %d", status);
        return;
    }

    /*
     * Make sure we have enough SYSREF cycles
     */
    microsecondSpin(100);

    /*
     * Disable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDCCfg.rfDC, &dacConfig, &adcConfig, 0);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(0) failed: %d", status);
        return;
    }
}

void
rfDCinit(void)
{
    int i;
    XRFdc_Config *configp;
    static struct metal_init_params init_param = METAL_INIT_DEFAULTS;

    if (metal_init(&init_param)) {
        warn("metal_init failed");
    }
    metal_set_log_handler(myLogHandler);
    metal_set_log_level(METAL_LOG_INFO);

    configp = XRFdc_LookupConfig(XPAR_XRFDC_0_DEVICE_ID);
    if (!configp) {
        warn("XRFdc_LookupConfig");
    }

    i = XRFdc_CfgInitialize(&rfDCCfg.rfDC, configp);
    if (i != XST_SUCCESS) {
        warn("XRFdc_CfgInitialize=%d", i);
    }

    rfDCCfg.initDone = 1;

    rfADCCfgStatic();
    rfADCCfg();
    rfDACCfgStatic();
    rfDACCfg();

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
    rfDCCfg.logMessageBuffer[0] = '\0';
    i = XRFdc_Reset(&rfDCCfg.rfDC, XRFDC_ADC_TILE, XRFDC_SELECT_ALL_TILES);
    if (i != XST_SUCCESS) warn("Critical -- ADC - %s\nXRFdc_Reset=%d",
                                                           rfDCCfg.logMessageBuffer, i);
    rfADCCfgStatic();
    rfADCCfg();
}

void
rfDACrestart(void)
{
    int i;
    rfDCCfg.logMessageBuffer[0] = '\0';
    i = XRFdc_Reset(&rfDCCfg.rfDC, XRFDC_DAC_TILE, XRFDC_SELECT_ALL_TILES);
    if (i != XST_SUCCESS) warn("Critical -- DAC - %s\nXRFdc_Reset=%d",
                                                           rfDCCfg.logMessageBuffer, i);
    rfDACCfgStatic();
    rfDACCfg();
}

void
rfDCsyncType(rfDCType type)
{
    int i;
    int tile, status;
    XRFdc_IPStatus IPStatus;
    XRFdc_MultiConverter_Sync_Config adcConfig, dacConfig;

    if (!rfDCCfg.initDone) {
        return;
    }

    status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
    if (status != 0) {
        printf("Can't get IP status.\n");
        return;
    }

    // For MTS to work we need ADC 0 or DAC 0 tile to be fully enabled.
    // According to PG269, "RF-DAC Tile Configuration": When enabled the
    // tile is included in a multi-tile synchronization group. RF-DAC Tile
    // 0 must be enabled and present in the group along with converter 0
    // of the tile being configured to enable this option. See Multi-Tile
    // Synchronization for details.
    uint32_t oldTileStatus[CFG_TILES_COUNT];
    status = rfDCCopyTileState(type, oldTileStatus, ARRAY_SIZE(oldTileStatus));
    if (status != XST_SUCCESS) {
        printf("Can't copy tile state.\n");
        return;
    }

    status = rfDCChangeTilePwr(type, 0, 1);
    if (status != XST_SUCCESS) {
        return;
    }

    XRFdc_MultiConverter_Init(&dacConfig, NULL, NULL, rfDCCfg.dacTileRefClk);
    XRFdc_MultiConverter_Init(&adcConfig, NULL, NULL, rfDCCfg.adcTileRefClk);
    /* Unknown latency */
    adcConfig.Target_Latency = -1;
    dacConfig.Target_Latency = -1;

    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (type & RFDC_ADC) {
            if (IPStatus.ADCTileStatus[tile].IsEnabled &&
                (IPStatus.ADCTileStatus[tile].TileState == XRFDC_STATE_FULL)) {
                adcConfig.Tiles |= 1 << tile;
            }
        }
        if (type & RFDC_DAC) {
            if (IPStatus.DACTileStatus[tile].IsEnabled &&
                (IPStatus.DACTileStatus[tile].TileState == XRFDC_STATE_FULL)) {
                dacConfig.Tiles |= 1 << tile;
            }
        }
    }

    /*
     * Enable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDCCfg.rfDC, &dacConfig, &adcConfig, 1);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(1) failed: %d", status);
        return;
    }

    /*
     * Make sure we have enough SYSREF cycles
     */
    microsecondSpin(1000);

    /*
     * Synchronize between tiles in each group. Try a few times before
     * giving up
     */
    if (type & RFDC_ADC) {
        for (i = 0; i < 8; ++i) {
            status = XRFdc_MultiConverter_Sync(&rfDCCfg.rfDC, XRFDC_ADC_TILE, &adcConfig);
            if (status == XRFDC_MTS_OK) {
                printf("ADC synchronization complete.\n");
                break;
            }

            warn("XRFdc_MultiConverter_Sync (tiles) ADC failed: %d, try %d",
                    status, i);
            microsecondSpin(10000);
        }
    }

    if (type & RFDC_DAC) {
        for (i = 0; i < 8; ++i) {
            status = XRFdc_MultiConverter_Sync(&rfDCCfg.rfDC, XRFDC_DAC_TILE, &dacConfig);
            if (status == XRFDC_MTS_OK) {
                printf("DAC synchronization complete.\n");
                break;
            }

            warn("XRFdc_MultiConverter_Sync (tiles) DAC failed: %d, try %d",
                    status, i);
            microsecondSpin(10000);
        }
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
    int latency = -1;
    for (tile = 0 ; tile < CFG_TILES_COUNT ; tile++) {
        if (adcConfig.Latency[tile] > latency) {
            latency = adcConfig.Latency[tile];
        }
    }
    adcConfig.Target_Latency = latency + 8;
    status = XRFdc_MultiConverter_Sync(&rfDCCfg.rfDC, XRFDC_ADC_TILE, &adcConfig);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MultiConverter_Sync (groups) failed: %d", status);
        return;
    }
#endif

    /*
     * Disable SYSREF
     */
    status = XRFdc_MTS_Sysref_Config(&rfDCCfg.rfDC, &dacConfig, &adcConfig, 0);
    if (status != XRFDC_MTS_OK) {
        warn("XRFdc_MTS_Sysref_Config(1) failed: %d", status);
        return;
    }

    for (int i = 0; i < ARRAY_SIZE(oldTileStatus); ++i) {
        oldTileStatus[i] = (oldTileStatus[i] == XRFDC_STATE_FULL);
    }

    // Revert old tiles states
    status = rfDCChangeTilePwrRaw(type, oldTileStatus);
    if (status != XST_SUCCESS) {
        return;
    }
}

void
rfDCADCsync(){
    rfADCCfgStatic();
    rfADCCfg();
    rfDCsyncType(RFDC_ADC);
}

void
rfDCDACsync(){
    rfDACCfgStatic();
    rfDACCfg();
    rfDCsyncType(RFDC_DAC);
}

void
rfDCsync(){
    rfDCADCsync();
    rfDCDACsync();
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
    i = XRFdc_SetCalFreeze(&rfDCCfg.rfDC, tile, adc, &cfs);
    if (i == XST_SUCCESS) {
        uint32_t then = MICROSECONDS_SINCE_BOOT();
        for (;;) {
            i = XRFdc_GetCalFreeze(&rfDCCfg.rfDC, tile, adc, &cfs);
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

void
rfADCfreezeCalibrationBPM(unsigned int bpm, int channel, int freeze)
{
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return;

    if (CFG_SWAP_ADC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_ADC_SET_ORDER) {
        channel = CFG_ADC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_ADC_PER_BPM_COUNT + channel;
    rfADCfreezeCalibration(ch, freeze);
}

unsigned int
rfADCGetStatus(int channel)
{
    int tile = channel / CFG_ADC_PER_TILE;
    int adc = channel % CFG_ADC_PER_TILE;
    uint32_t v;
    int b = 0;

    XRFdc_GetIntrStatus(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, adc, &v);
    if (v) {
        b |= (v & XRFDC_ADC_OVR_RANGE_MASK) ? 0x1 : 0;
        b |= (v & XRFDC_ADC_OVR_VOLTAGE_MASK)  ? 0x2 : 0;
        XRFdc_IntrClr(&rfDCCfg.rfDC, XRFDC_ADC_TILE, tile, adc, v);
    }

    return b;
}

unsigned int
rfADCGetStatusBPM(unsigned int bpm, int channel)
{
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return 0;

    if (CFG_SWAP_ADC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_ADC_SET_ORDER) {
        channel = CFG_ADC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_ADC_PER_BPM_COUNT + channel;
    return rfADCGetStatus(ch);
}

unsigned int
rfADCstatus(void)
{
    int bpm;
    int channel;
    int status = 0;
    int statusShift = 0;

    for (bpm = 0; bpm < CFG_DSBPM_COUNT; bpm++) {
        for (channel = 0 ; channel < CFG_ADC_PER_BPM_COUNT; channel++) {
            int b = rfADCGetStatusBPM(bpm, channel);
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

    if (!rfDCCfg.initDone) {
        return -1.0;
    }

    i = XRFdc_GetDSA(&rfDCCfg.rfDC, tile, adc, &dsa);
    if (i != XST_SUCCESS) {
        printf("XRFdc_GetDSA tile %d, adc %d: %d\n", tile, adc, i);
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

    if (!rfDCCfg.initDone) {
        return;
    }

    i = XRFdc_GetDSA(&rfDCCfg.rfDC, tile, adc, &dsa);
    if (i != XST_SUCCESS) {
        printf("XRFdc_GetDSA tile %d, adc %d: %d\n", tile, adc, i);
        return;
    }

    dsa.Attenuation = att;
    i = XRFdc_SetDSA(&rfDCCfg.rfDC, tile, adc, &dsa);
    if (i != XST_SUCCESS) {
        printf("XRFdc_SetDSA tile %d, adc %d: %d\n", tile, adc, i);
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

    if (CFG_SWAP_ADC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_ADC_SET_ORDER) {
        channel = CFG_ADC_PER_BPM_COUNT-1 - channel;
    }

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

    if (CFG_SWAP_ADC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_ADC_SET_ORDER) {
        channel = CFG_ADC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_ADC_PER_BPM_COUNT + channel;
    att = rfADCGetDSA(ch);

    return att * 1000;
}

int
rfDACGetVOP(int channel)
{
    int i;

    int tile = channel / CFG_DAC_PER_TILE;
    int dac = channel % CFG_DAC_PER_TILE;
    int duc = 0;

    if (!rfDCCfg.initDone) {
        return -1;
    }

    unsigned int ucurrent;
    i = XRFdc_GetOutputCurr(&rfDCCfg.rfDC, tile, dac*CFG_DAC_DUC_OFFSET + duc,
            &ucurrent);
    if (i != XST_SUCCESS) {
        printf("XRFdc_GetOutputCurr tile %d, dac %d, duc %d: %d\n", tile, dac,
                duc, i);
        return -1;
    }

    return ucurrent;
}

void
rfDACSetVOP(int channel, unsigned int ucurrent)
{
    int i, duc;
    int tile = channel / CFG_DAC_PER_TILE;
    int dac = channel % CFG_DAC_PER_TILE;

    if (!rfDCCfg.initDone) {
        return;
    }

    for (duc = 0; duc < CFG_DAC_DUC_PER_DAC; duc++) {
        i = XRFdc_SetDACVOP(&rfDCCfg.rfDC, tile, dac*CFG_DAC_DUC_OFFSET + duc,
                ucurrent);
        if (i != XST_SUCCESS) {
            printf("XRFdc_SetDACVOP tile %d, dac %d, duc %d: %d\n", tile, dac,
                    duc, i);
        }
    }
}

int
rfDACGetVOPDSBPM(unsigned int bpm, int channel)
{
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return -1;

    if (CFG_SWAP_DAC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_DAC_SET_ORDER) {
        channel = CFG_DAC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_DAC_PER_BPM_COUNT + channel;
    return rfDACGetVOP(ch);
}

void
rfDACSetVOPDSBPM(unsigned int bpm, int channel, unsigned int ucurrent)
{
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return;

    if (CFG_SWAP_DAC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_DAC_SET_ORDER) {
        channel = CFG_DAC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_DAC_PER_BPM_COUNT + channel;
    rfDACSetVOP(ch, ucurrent);
}

static int
rfDCGetPowerMode(rfDCType type, int channel)
{
    int i = XST_SUCCESS;
    XRFdc_Pwr_Mode_Settings pwr = {0};
    int tile = 0;
    int block = 0;
    uint32_t rfdcType = (type & RFDC_ADC) ? XRFDC_ADC_TILE :
                        (type & RFDC_DAC) ? XRFDC_DAC_TILE : XRFDC_ADC_TILE;

    if (!rfDCCfg.initDone) {
        return -1;
    }

    if (type & RFDC_ADC) {
        tile = channel / CFG_ADC_PER_TILE;
        block = channel % CFG_ADC_PER_TILE;
    }
    else if (type & RFDC_DAC) {
        tile = channel / CFG_DAC_PER_TILE;
        block = (channel % CFG_DAC_PER_TILE)*CFG_DAC_DUC_OFFSET;
    }
    else {
        return -1;
    }

    i = XRFdc_GetPwrMode(&rfDCCfg.rfDC, rfdcType, tile, block, &pwr);
    if (i != XST_SUCCESS) {
        printf("XRFdc_GetPwrMode tile %d, block %d: %d\n", tile, block, i);
        return -1;
    }

    return (pwr.PwrMode != 0);
}

static void
rfDCSetPowerMode(rfDCType type, int channel, int on)
{
    int i = XST_SUCCESS;
    XRFdc_Pwr_Mode_Settings pwr = {0};
    int tile = 0, block = 0;
    uint32_t rfdcType = (type & RFDC_ADC) ? XRFDC_ADC_TILE :
                        (type & RFDC_DAC) ? XRFDC_DAC_TILE : XRFDC_ADC_TILE;

    if (!rfDCCfg.initDone) {
        return;
    }

    if (type & RFDC_ADC) {
        tile = channel / CFG_ADC_PER_TILE;
        block = channel % CFG_ADC_PER_TILE;
    }
    else if (type & RFDC_DAC) {
        tile = channel / CFG_DAC_PER_TILE;
        block = (channel % CFG_DAC_PER_TILE)*CFG_DAC_DUC_OFFSET;
    }
    else {
        return;
    }

    i = XRFdc_GetPwrMode(&rfDCCfg.rfDC, rfdcType, tile, block, &pwr);
    if (i != XST_SUCCESS) {
        printf("XRFdc_GetPwrMode tile %d, block %d: %d\n", tile, block, i);
        return;
    }

    pwr.PwrMode = (on != 0);

    i = XRFdc_SetPwrMode(&rfDCCfg.rfDC, rfdcType, tile, block, &pwr);
    if (i != XST_SUCCESS) {
        printf("XRFdc_SetPwrMode tile %d, block %d: %d\n", tile, block, i);
        return;
    }
}

int
rfDACGetPowerModeBPM(unsigned int bpm, int channel)
{
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return -1;

    if (CFG_SWAP_DAC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_DAC_SET_ORDER) {
        channel = CFG_DAC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_DAC_PER_BPM_COUNT + channel;
    return rfDCGetPowerMode(RFDC_DAC, ch);
}

void
rfDACSetPowerModeBPM(unsigned int bpm, int channel, int on)
{
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return;

    if (CFG_SWAP_DAC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_DAC_SET_ORDER) {
        channel = CFG_DAC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_DAC_PER_BPM_COUNT + channel;
    rfDCSetPowerMode(RFDC_DAC, ch, on);
}

static int
rfDCGetShutdownMode(rfDCType type, int channel)
{
    int tile = 0;

    if (!rfDCCfg.initDone) {
        return -1;
    }

    if (type & RFDC_ADC) {
        tile = channel / CFG_ADC_PER_TILE;
    }
    else if (type & RFDC_DAC) {
        tile = channel / CFG_DAC_PER_TILE;
    }
    else {
        return -1;
    }

    if (tile >= CFG_TILES_COUNT) {
        return -1;
    }

    XRFdc_IPStatus IPStatus;
    int status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
    if (status != XST_SUCCESS) {
        printf("Can't get IP status.\n");
        return status;
    }

    int tileState = (type & RFDC_ADC) ? IPStatus.ADCTileStatus[tile].TileState :
        IPStatus.DACTileStatus[tile].TileState;

    return tileState;
}

// Helper function to determine which tiles should be in which
// state (on, pass-through, off). This is needed because
// the clock is distributed in daisy-chain via the source tile
static void
rfDCTileTargetState(int tileRefClk, uint32_t *requestStatus, uint32_t *targetState)
{
    bool clockNeedBelow = false;
    bool clockNeedAbove = false;
    bool *clockNeededp = &clockNeedBelow;
    int inc = 1;

    for (int i = 0, tile = 0; i < CFG_TILES_COUNT; i++, tile += inc) {
        if (tile == tileRefClk) {
            tile = CFG_TILES_COUNT;
            inc = -1;
            clockNeededp = &clockNeedAbove;
            continue;
        }

        if (requestStatus[tile]) {
            *clockNeededp = true;
            targetState[tile] = XRFDC_STATE_FULL;
        }
        else if (*clockNeededp) {
            targetState[tile] = XRFDC_STATE_CLK_DET;
        }
        else {
            targetState[tile] = XRFDC_STATE_SHUTDOWN;
        }
    }

    if (requestStatus[tileRefClk]) {
        targetState[tileRefClk] = XRFDC_STATE_FULL;
    }
    else if (clockNeedBelow || clockNeedAbove) {
        /*
         * This is the clock SOURCE tile, not merely a pass-through
         * tile. The source must remain operational while other
         * tiles consume its distributed clock.
         *
         * The RFdc driver requires the clock-distribution source
         * to reach IPSM state 7. Since state 7 is not an exposed
         * CustomStartUp endpoint, leave the source FULL.
         */
        targetState[tileRefClk] = XRFDC_STATE_FULL;

    }
    else {
        targetState[tileRefClk] = XRFDC_STATE_SHUTDOWN;
    }
}

static int
rfDCChangeTileState(rfDCType type, int tile, uint32_t requestState)
{
    uint32_t rfdcType = (type & RFDC_ADC) ? XRFDC_ADC_TILE :
                        (type & RFDC_DAC) ? XRFDC_DAC_TILE : XRFDC_ADC_TILE;
    XRFdc_IPStatus IPStatus;
    int status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
    if (status != XST_SUCCESS) {
        printf("Can't get IP status.\n");
        return status;
    }

    XRFdc_TileStatus *tileStatus = (type & RFDC_ADC) ? IPStatus.ADCTileStatus :
        IPStatus.DACTileStatus;
    int currentState = tileStatus[tile].TileState;
    int currentEnabled = tileStatus[tile].IsEnabled;

    if (!currentEnabled) {
        return XST_SUCCESS;
    }

    if (debugFlags & DEBUGFLAG_RF_DAC_SHOW) {
        printf("rfDCChangeTileState: tile %d, type %d, state %u -> %u\n",
               tile, type, currentState, requestState);
    }

    int newState = 0;
    if (requestState == XRFDC_STATE_SHUTDOWN) {
        // Don't try to shutdown a tile that is already shut down
        if (currentState != XRFDC_STATE_SHUTDOWN ) {
            status = XRFdc_Shutdown(&rfDCCfg.rfDC, rfdcType, tile);
            if (status != XST_SUCCESS) {
                printf("Couldn't shutdown %s tile %d\n",
                     (type & RFDC_ADC)? "ADC" : "DAC", tile);
                return status;
            }
        }
    }
    else if (requestState == XRFDC_STATE_CLK_DET) {
        // We have to shutdown a tile to reduce its status
        if (currentState > XRFDC_STATE_CLK_DET) {
            status = XRFdc_Shutdown(&rfDCCfg.rfDC, rfdcType, tile);
            if (status != XST_SUCCESS) {
                printf("Couldn't shutdown %s tile %d\n",
                     (type & RFDC_ADC)? "ADC" : "DAC", tile);
                return status;
            }
        }

        status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
        if (status != XST_SUCCESS) {
            printf("Can't get IP status.\n");
            return status;
        }

        newState = (type & RFDC_ADC) ? IPStatus.ADCTileStatus[tile].TileState :
            IPStatus.DACTileStatus[tile].TileState;

        // Re-apply the PLL configuration if it was off or was turned off just now.
        // Without this, the reference tile will not forward the clock.
        int cfgStatus = -1;
        if (newState == XRFDC_STATE_SHUTDOWN) {
            if (type & RFDC_ADC) {
                cfgStatus = rfADCCfgStaticSingle(tile);
            }
            else if (type & RFDC_DAC) {
                cfgStatus = rfDACCfgStaticSingle(tile);
            }

            if (cfgStatus != XST_SUCCESS) {
                return cfgStatus;
            }
        }

        status = XRFdc_CustomStartUp(&rfDCCfg.rfDC, rfdcType, tile,
                                     newState, requestState);
        if (status != XST_SUCCESS) {
            printf("Couldn't startup %s tile %d\n",
                 (type & RFDC_ADC)? "ADC" : "DAC", tile);
            return status;
        }
    }
    else if (requestState == XRFDC_STATE_FULL) {
        // If this tile was previously XRFDC_STATE_SHUTDOWN, its PLL was
        // erased. Re-apply it before starting it.
        int cfgStatus = -1;
        if (currentState < XRFDC_STATE_PWRUP) {
            if (type & RFDC_ADC) {
                cfgStatus = rfADCCfgStaticSingle(tile);
            }
            else if (type & RFDC_DAC) {
                cfgStatus = rfDACCfgStaticSingle(tile);
            }

            if (cfgStatus != XST_SUCCESS) {
                return cfgStatus;
            }
        }

        status = XRFdc_StartUp(&rfDCCfg.rfDC, rfdcType, tile);
        if (status != XST_SUCCESS) {
            printf("Couldn't startup %s tile %d\n",
                 (type & RFDC_ADC)? "ADC" : "DAC", tile);
            return status;
        }
    }

    // Check if the status change was successful

    status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
    if (status != XST_SUCCESS) {
        printf("Can't get IP status.\n");
        return status;
    }

    newState = (type & RFDC_ADC) ? IPStatus.ADCTileStatus[tile].TileState :
        IPStatus.DACTileStatus[tile].TileState;
    if (newState != requestState) {
        warn("Couldn't change %s tile %d state from %d to %d(%d)",
             (type & RFDC_ADC)? "ADC" : "DAC", tile, currentState,
             requestState, newState);
    }

    return status;
}

static int
rfDCApplyTileStates(rfDCType type, uint32_t *targetState)
{
    int tileRefClk = 0;

    if (type & RFDC_ADC) {
        tileRefClk = rfDCCfg.adcTileRefClk;
    }
    else if (type & RFDC_DAC) {
        tileRefClk = rfDCCfg.dacTileRefClk;
    }
    else {
        return -1;
    }

    XRFdc_IPStatus IPStatus;
    int status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
    if (status != XST_SUCCESS) {
        printf("Can't get IP status.\n");
        return status;
    }

    XRFdc_TileStatus *tileStatus = (type & RFDC_ADC) ? IPStatus.ADCTileStatus :
        IPStatus.DACTileStatus;

    // If this is a power-down operation we need to start
    // from the leaves to the reference clock tile
    int inc = 1;
    for (int i = 0, tile = 0; i < CFG_TILES_COUNT; i++, tile += inc) {
        if (tile == tileRefClk) {
            tile = CFG_TILES_COUNT;
            inc = -1;
            continue;
        }

        if (targetState[tile] < tileStatus[tile].TileState) {
            status = rfDCChangeTileState(type, tile, targetState[tile]);
            if (status != XST_SUCCESS) {
                return status;
            }
        }
    }

    // Do reference tile separately. This is the time to power down
    // the reference tile if requested.
    if (targetState[tileRefClk] < tileStatus[tileRefClk].TileState) {
        status = rfDCChangeTileState(type, tileRefClk, targetState[tileRefClk]);
        if (status != XST_SUCCESS) {
            return status;
        }

        // Update Tile status as tiles might have gone down
        int status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
        if (status != XST_SUCCESS) {
            printf("Can't get IP status.\n");
            return status;
        }
    }

    // For a power-up operation, regardless of the tile, DAC0 needs
    // to be at least in state 6 bacause according to PG269
    // "DAC_Tile0 and ADC_Tile0 control the bandgap trim for the device.
    // If these tiles are enabled they should be powered up to at least
    // stage 4 in order that the bandgap trim settings are propagated
    // to the other enabled tiles."

    // Check if there is at least one power-up operation
    int powerUpOp = 0;
    for (int i = 0; i < CFG_TILES_COUNT; i++) {
        if (targetState[i] > tileStatus[i].TileState) {
            powerUpOp = 1;
        }
    }

    if (powerUpOp &&
        (tileStatus[0].TileState < XRFDC_STATE_CLK_DET)) {
        status = rfDCChangeTileState(type, 0, XRFDC_STATE_CLK_DET);
        if (status != XST_SUCCESS) {
            return status;
        }

        int status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
        if (status != XST_SUCCESS) {
            printf("Can't get IP status.\n");
            return status;
        }
    }

    // If this is a power-up operation we need to start
    // from the reference clock tile to the leaves. This
    // includes the reference tile. That's why the +1 on the
    // for guard condition
    inc = -1;
    for (int i = 0, tile = tileRefClk; i < CFG_TILES_COUNT + 1; i++, tile += inc) {
        if (tile < 0) {
            tile = tileRefClk;
            inc = 1;
            continue;
        }

        if (targetState[tile] > tileStatus[tile].TileState) {
            status = rfDCChangeTileState(type, tile, targetState[tile]);
            if (status != XST_SUCCESS) {
                return status;
            }
        }
    }

    return XST_SUCCESS;
}

static int
rfDCChangeTilePwrRaw(rfDCType type, uint32_t *requestStatus)
{
    int status = 0;
    uint32_t tileRefClk;

    if (type & RFDC_ADC) {
        tileRefClk = rfDCCfg.adcTileRefClk;
    }
    else if (type & RFDC_DAC) {
        tileRefClk = rfDCCfg.dacTileRefClk;
    }
    else {
        return -1;
    }

    // Calculate the new tile states
    uint32_t targetState[CFG_TILES_COUNT];
    rfDCTileTargetState(tileRefClk, requestStatus, targetState);

    if (debugFlags & DEBUGFLAG_RF_DAC_SHOW) {
        XRFdc_IPStatus IPStatus;
        status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
        if (status != XST_SUCCESS) {
            printf("Can't get IP status.\n");
            return status;
        }

        XRFdc_TileStatus *tileStatus = (type & RFDC_ADC) ? IPStatus.ADCTileStatus :
            IPStatus.DACTileStatus;

        printf("rfDCChangeTilePwrRaw: current/target state: ");

        for(int i = 0; i < CFG_TILES_COUNT; ++i) {
            printf("(%u/%u) ", tileStatus[i].TileState, targetState[i]);
        }
        printf("\n");
    }

    status = rfDCApplyTileStates(type, targetState);
    if (status != XST_SUCCESS) {
        return status;
    }

    return status;
}

static int
rfDCCopyTileState(rfDCType type, uint32_t *tileState, size_t capacity)
{
    XRFdc_IPStatus IPStatus;
    int status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
    if (status != XST_SUCCESS) {
        printf("Can't get IP status.\n");
        return status;
    }

    XRFdc_TileStatus *tileStatus = (type & RFDC_ADC) ? IPStatus.ADCTileStatus :
        IPStatus.DACTileStatus;

    // Get current tile status
    for (int i = 0; i < CFG_TILES_COUNT && i < capacity; ++i) {
        tileState[i] = tileStatus[i].TileState;
    }

    return XST_SUCCESS;
}

static int
rfDCChangeTilePwr(rfDCType type, int tile, int on)
{
    if (tile >= CFG_TILES_COUNT) {
        return -1;
    }

    // Get current tile status
    uint32_t requestStatus[CFG_TILES_COUNT];
    int status = rfDCCopyTileState(type, requestStatus, ARRAY_SIZE(requestStatus));
    if (status != XST_SUCCESS) {
        return status;
    }

    for (int i = 0; i < ARRAY_SIZE(requestStatus); ++i) {
        requestStatus[i] = (requestStatus[i] == XRFDC_STATE_FULL);
    }

    // Add new tile state request
    requestStatus[tile] = (on != 0);

    status = rfDCChangeTilePwrRaw(type, requestStatus);

    return status;
}

static void
rfDCSetShutdownMode(rfDCType type, int channel, int on)
{
    int tile = 0;

    if (!rfDCCfg.initDone) {
        return;
    }

    if (type & RFDC_ADC) {
        tile = channel / CFG_ADC_PER_TILE;
    }
    else if (type & RFDC_DAC) {
        tile = channel / CFG_DAC_PER_TILE;
    }
    else {
        return;
    }

    // Save state so we can determine if we need MTS at the end
    uint32_t oldTileStatus[CFG_TILES_COUNT];
    int status = rfDCCopyTileState(type, oldTileStatus, ARRAY_SIZE(oldTileStatus));
    if (status != XST_SUCCESS) {
        printf("Can't copy tile state.\n");
        return;
    }

    status = rfDCChangeTilePwr(type, tile, on);
    if (status != XST_SUCCESS) {
        return;
    }

    if (debugFlags & DEBUGFLAG_RF_DAC_SHOW) {
        XRFdc_IPStatus IPStatus;
        int status = XRFdc_GetIPStatus(&rfDCCfg.rfDC, &IPStatus);
        if (status != XST_SUCCESS) {
            printf("Can't get IP status.\n");
            return;
        }

        XRFdc_TileStatus *tileStatus = (type & RFDC_ADC) ? IPStatus.ADCTileStatus :
            IPStatus.DACTileStatus;

        printf("rfDCSetShutdownMode: new state: ");

        for(int i = 0; i < CFG_TILES_COUNT; ++i) {
            printf("%u ", tileStatus[i].TileState);
        }
        printf("\n");
    }

    // Determine if MTS is necessary

    uint32_t newTileStatus[CFG_TILES_COUNT];
    status = rfDCCopyTileState(type, newTileStatus, ARRAY_SIZE(newTileStatus));
    if (status != XST_SUCCESS) {
        printf("Can't copy tile state.\n");
        return;
    }

    int stateChanged = 0;
    for (int i = 0; i < ARRAY_SIZE(newTileStatus) &&
            i < ARRAY_SIZE(oldTileStatus); ++i) {
        if (oldTileStatus[i] != newTileStatus[i]) {
            stateChanged = 1;
            break;
        }
    }

    if (on != 0 && stateChanged) {
        if (type & RFDC_ADC) {
            rfDCsyncType(RFDC_ADC);
        }
        else if (type & RFDC_DAC) {
            rfDCsyncType(RFDC_DAC);
        }
    }
}

int
rfDACGetShutdownModeBPM(unsigned int bpm, int channel)
{
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return -1;

    if (CFG_SWAP_DAC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_DAC_SET_ORDER) {
        channel = CFG_DAC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_DAC_PER_BPM_COUNT + channel;
    return rfDCGetShutdownMode(RFDC_DAC, ch);
}

void
rfDACSetShutdownModeBPM(unsigned int bpm, int channel, int on)
{
    int ch;
    if (bpm >= CFG_DSBPM_COUNT) return;

    if (CFG_SWAP_DAC_SETS) {
        bpm = (bpm + CFG_DSBPM_COUNT-1) % CFG_DSBPM_COUNT;
    }

    if (CFG_REVERSE_DAC_SET_ORDER) {
        channel = CFG_DAC_PER_BPM_COUNT-1 - channel;
    }

    ch = bpm * CFG_DAC_PER_BPM_COUNT + channel;
    rfDCSetShutdownMode(RFDC_DAC, ch, on);
}
