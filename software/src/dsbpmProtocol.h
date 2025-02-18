#ifndef _DS_BPM_PROTOCOL_
#define _DS_BPM_PROTOCOL_

#if defined(PLATFORM_ZYNQMP) || defined(PLATFORM_VERSAL)
# include <stdint.h>
  typedef uint8_t  epicsUInt8;
  typedef int8_t   epicsInt8;
  typedef uint16_t epicsUInt16;
  typedef int16_t  epicsInt16;
  typedef uint32_t epicsUInt32;
  typedef int32_t  epicsInt32;
#else
# include <epicsTypes.h>
#endif

#define DSBPM_PROTOCOL_UDP_PORT                 50005
#define DSBPM_PROTOCOL_PUBLISHER_UDP_PORT       50006

#define DSBPM_PROTOCOL_WAVEFORM_PAYLOAD_CAPACITY  1440
#define DSBPM_PROTOCOL_RECORDER_COUNT             7

// echo "DSBPM_PROTOCOL_MAGIC" | md5sum | cut -b1-8 | tac -rs .. | echo $(tr -d '\n')
#define DSBPM_PROTOCOL_MAGIC                    0xD06F9891
#define DSBPM_PROTOCOL_MAGIC_SWAPPED            0x91986FD0
#define DSBPM_PROTOCOL_MAGIC_SLOW_ACQUISITION   0xD06F9A92
#define DSBPM_PROTOCOL_MAGIC_SWAPPED_SLOW_ACQUISITION \
                                                0x929A6FD0
#define DSBPM_PROTOCOL_MAGIC_WAVEFORM_HEADER    0xD06F9993
#define DSBPM_PROTOCOL_MAGIC_SWAPPED_WAVEFORM_HEADER \
                                                0x93996FD0
#define DSBPM_PROTOCOL_MAGIC_WAVEFORM_DATA      0xD06F9794
#define DSBPM_PROTOCOL_MAGIC_SWAPPED_WAVEFORM_DATA \
                                                0x94976FD0
#define DSBPM_PROTOCOL_MAGIC_WAVEFORM_ACK       0xD06F9795
#define DSBPM_PROTOCOL_MAGIC_SWAPPED_WAVEFORM_ACK \
                                                0x95976FD0

#define DSBPM_PROTOCOL_ARG_CAPACITY    350
#define DSBPM_PROTOCOL_ADC_COUNT       8
#define DSBPM_PROTOCOL_DAC_COUNT       8
#define DSBPM_PROTOCOL_DSP_COUNT       2

struct dsbpmPacket {
    epicsUInt32    magic;
    epicsUInt32    nonce;
    epicsUInt32    command;
    epicsUInt32    args[DSBPM_PROTOCOL_ARG_CAPACITY];
};

/*
 * Slow acquisition (typically 10 Hz) monitoring
 */
struct dsbpmSlowAcquisition {
    epicsUInt32 magic;
    epicsUInt32 packetNumber;
    epicsUInt32 seconds;
    epicsUInt32 ticks;
    epicsUInt8  clipStatus;
    epicsUInt8  cellCommStatus[DSBPM_PROTOCOL_DSP_COUNT];
    epicsUInt8  autotrimStatus[DSBPM_PROTOCOL_DSP_COUNT];
    epicsUInt8  sdSyncStatus[DSBPM_PROTOCOL_DSP_COUNT];
    epicsUInt8  pad1;
    epicsUInt16 adcPeak[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 rfMag[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 ptLoMag[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 ptHiMag[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 gainFactor[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 calibRFFactor[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 calibPLFactor[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 calibPHFactor[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 rfADCDSA[DSBPM_PROTOCOL_ADC_COUNT];
    epicsInt32  xPos[DSBPM_PROTOCOL_DSP_COUNT];
    epicsInt32  yPos[DSBPM_PROTOCOL_DSP_COUNT];
    epicsInt32  skew[DSBPM_PROTOCOL_DSP_COUNT];
    epicsInt32  buttonSum[DSBPM_PROTOCOL_DSP_COUNT];
    epicsInt32  xRMSwide[DSBPM_PROTOCOL_DSP_COUNT];
    epicsInt32  yRMSwide[DSBPM_PROTOCOL_DSP_COUNT];
    epicsInt32  xRMSnarrow[DSBPM_PROTOCOL_DSP_COUNT];
    epicsInt32  yRMSnarrow[DSBPM_PROTOCOL_DSP_COUNT];
    epicsUInt32 lossOfBeamStatus[DSBPM_PROTOCOL_DSP_COUNT];
    epicsUInt32 prelimProcStatus[DSBPM_PROTOCOL_DSP_COUNT];
    epicsUInt32 recorderStatus[DSBPM_PROTOCOL_DSP_COUNT];
    epicsUInt32 afeAtt[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 dacCurrent[DSBPM_PROTOCOL_DAC_COUNT];
    epicsUInt32 dacCtl[DSBPM_PROTOCOL_DAC_COUNT];
};

/*
 * Waveform transfer
 * When a waveform recorder completes acquisition it sends the header
 * unsolicited.  It then sends each block when requested.
 * The header is retransmitted if a block request does not arrive in a
 * reasonable interval.
 */
struct dsbpmWaveformHeader {
    epicsUInt32 magic;
    epicsUInt32 dsbpmNumber;
    epicsUInt32 waveformNumber;
    epicsUInt16 recorderNumber;
    epicsUInt32 seconds;
    epicsUInt32 ticks;
    epicsUInt32 byteCount;
    epicsUInt32 bytesPerSample;
    epicsUInt32 bytesPerAtom;
};
struct dsbpmWaveformData {
    epicsUInt32 magic;
    epicsUInt32 dsbpmNumber;
    epicsUInt32 waveformNumber;
    epicsUInt32 recorderNumber;
    epicsUInt32 blockNumber;
    unsigned char payload[DSBPM_PROTOCOL_WAVEFORM_PAYLOAD_CAPACITY];
};
struct dsbpmWaveformAck {
    epicsUInt32 magic;
    epicsUInt32 dsbpmNumber;
    epicsUInt32 waveformNumber;
    epicsUInt32 recorderNumber;
    epicsUInt32 blockNumber;
};

#define DSBPM_PROTOCOL_SIZE_TO_ARG_COUNT(s) (DSBPM_PROTOCOL_ARG_CAPACITY - \
                    ((sizeof(struct dsbpmPacket)-(s))/sizeof(epicsUInt32)))
#define DSBPM_PROTOCOL_ARG_COUNT_TO_SIZE(a) (sizeof(struct dsbpmPacket) - \
                        ((DSBPM_PROTOCOL_ARG_CAPACITY - (a)) * sizeof(epicsUInt32)))
#define DSBPM_PROTOCOL_ARG_COUNT_TO_U32_COUNT(a) \
                    ((sizeof(struct dsbpmPacket) / sizeof(epicsUInt32)) - \
                                            (DSBPM_PROTOCOL_ARG_CAPACITY - (a)))
#define DSBPM_PROTOCOL_U32_COUNT_TO_ARG_COUNT(u) (DSBPM_PROTOCOL_ARG_CAPACITY - \
                    (((sizeof(struct dsbpmPacket)/sizeof(epicsUInt32)))-(u)))

#define DSBPM_PROTOCOL_CMD_MASK_HI             0xF000
#define DSBPM_PROTOCOL_CMD_MASK_LO             0x0F80
#define DSBPM_PROTOCOL_CMD_MASK_IDX            0x007F

#define DSBPM_PROTOCOL_CMD_HI_LONGIN           0x0000
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_FIRMWARE_BUILD_DATE 0x00
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_SOFTWARE_BUILD_DATE 0x01
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_LMX2594_STATUS      0x02
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_DFE_SERIAL_NUMBER   0x04
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_AFE_SERIAL_NUMBER   0x05
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_GIT_HASH_ID         0x06

#define DSBPM_PROTOCOL_CMD_HI_LONGOUT          0x1000
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_NO_VALUE        0x0000
#  define DSBPM_PROTOCOL_CMD_LONGOUT_NV_IDX_CLEAR_POWERUP_STATUS  0x00
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_TRIM                   0x0080
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_LOB_THRSH              0x0100
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_DSA                    0x0180
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_TBT_SUM_SHIFT          0x0200
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_RMS_THRSH              0x0280
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_MT_SUM_SHIFT           0x0300
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_BUTTON_DSP             0x0380
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_AUTOTRIM_CTL           0x0400
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_AUTOTRIM_THRS          0x0480
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_AUTOTRIM_FILT_SHFT     0x0500
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_AFE_ATT                0x0580
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_DAC_CURRENT            0x0600
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_DAC_CTL                0x0680
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_RF_GAINS               0x0700
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_PL_GAINS               0x0780
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_PH_GAINS               0x0800
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_EVENT_ACTION       0x0900
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_TRIGGER_DELAY      0x0A00
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_GENERIC                0x0F00
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_IDX_REBOOT           0x00

#define DSBPM_PROTOCOL_CMD_HI_SYSMON           0x2000
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_INT32       0x0000
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_UINT16_LO   0x0100
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_UINT16_HI   0x0200
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_INT16_LO    0x0300
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_INT16_HI    0x0400

#define DSBPM_PROTOCOL_CMD_HI_PLL_CONFIG       0x4000
# define DSBPM_PROTOCOL_CMD_PLL_CONFIG_LO_SET     0x0000
# define DSBPM_PROTOCOL_CMD_PLL_CONFIG_LO_GET     0x0100

#define DSBPM_PROTOCOL_CMD_HI_RECORDERS        0x5000
# define DSBPM_PROTOCOL_CMD_RECORDERS_LO_ARM                 0x0000
# define DSBPM_PROTOCOL_CMD_RECORDERS_LO_TRIGGER_MASK        0x0100
# define DSBPM_PROTOCOL_CMD_RECORDERS_LO_PRETRIGGER_COUNT    0x0200
# define DSBPM_PROTOCOL_CMD_RECORDERS_LO_ACQUISITION_COUNT   0x0300
# define DSBPM_PROTOCOL_CMD_RECORDERS_LO_ACQUISITION_MODE    0x0400
# define DSBPM_PROTOCOL_CMD_RECORDERS_LO_SOFT_TRIGGER        0x0500

#endif /* _DS_BPM_PROTOCOL_ */
