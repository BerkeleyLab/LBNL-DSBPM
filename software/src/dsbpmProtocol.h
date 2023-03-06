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
#define DSBPM_PROTOCOL_RECORDER_COUNT             5

// echo "DSBPM_PROTOCOL_MAGIC" | md5sum | cut -b1-8 | tac -rs .. | echo $(tr -d '\n')
#define DSBPM_PROTOCOL_MAGIC                    0xD06F9691
#define DSBPM_PROTOCOL_MAGIC_SWAPPED            0x91966FD0
#define DSBPM_PROTOCOL_MAGIC_SLOW_ACQUISITION   0xD06F9692
#define DSBPM_PROTOCOL_MAGIC_SWAPPED_SLOW_ACQUISITION \
                                                0x92966FD0
#define DSBPM_PROTOCOL_MAGIC_WAVEFORM_HEADER    0xD06F9693
#define DSBPM_PROTOCOL_MAGIC_SWAPPED_WAVEFORM_HEADER \
                                                0x93966FD0
#define DSBPM_PROTOCOL_MAGIC_WAVEFORM_DATA      0xD06F9694
#define DSBPM_PROTOCOL_MAGIC_SWAPPED_WAVEFORM_DATA \
                                                0x94966FD0
#define DSBPM_PROTOCOL_MAGIC_WAVEFORM_ACK       0xD06F9695
#define DSBPM_PROTOCOL_MAGIC_SWAPPED_WAVEFORM_ACK \
                                                0x95966FD0

#define DSBPM_PROTOCOL_ARG_CAPACITY    350
#define DSBPM_PROTOCOL_ADC_COUNT       8
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
    epicsUInt8  syncStatus;
    epicsUInt8  clipStatus;
    epicsUInt8  cellCommStatus;
    epicsUInt8  autotrimStatus;
    epicsUInt8  sdSyncStatus;
    epicsUInt8  pad1;
    epicsUInt8  pad2;
    epicsUInt16 adcPeak[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 rfMag[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 ptLoMag[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 ptHiMag[DSBPM_PROTOCOL_ADC_COUNT];
    epicsUInt32 gainFactor[DSBPM_PROTOCOL_ADC_COUNT];
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
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_ACQ_STATUS          0x03
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_DFE_SERIAL_NUMBER   0x04
# define DSBPM_PROTOCOL_CMD_LONGIN_IDX_AFE_SERIAL_NUMBER   0x05

#define DSBPM_PROTOCOL_CMD_HI_LONGOUT          0x1000
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_NO_VALUE        0x0000
#  define DSBPM_PROTOCOL_CMD_LONGOUT_NV_IDX_CLEAR_POWERUP_STATUS  0x00
#  define DSBPM_PROTOCOL_CMD_LONGOUT_NV_IDX_SOFT_TRIGGER          0x01
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_TRIM                   0x0080
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_SEGMENTED_MODE     0x0100
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_DSA                    0x0180
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_EARLY_SEGMENT_INTERVAL 0x0200
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_LATER_SEGMENT_INTERVAL 0x0300
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_TRIGGER_LEVEL          0x0400
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_TRIGGER_ENABLES    0x0500
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_PRETRIGGER_SAMPLES 0x0600
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_REARM                  0x0700
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_GAIN               0x0800
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_EVENT_ACTION       0x0900
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_TRIGGER_DELAY      0x0A00
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_COUPLING           0x0C00
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_TRIGGER_EDGE       0x0D00
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_INPUT_BONDING      0x0E00
# define DSBPM_PROTOCOL_CMD_LONGOUT_LO_GENERIC                0x0F00
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_IDX_REBOOT           0x00
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_EVR_CLK_PER_TURN     0x01
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_ENABLE_TRAINING_TONE 0x02
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_SET_CALIBRATION_DAC  0x03
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_LOB_THRSH            0x20
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_TBT_SUM_SHIFT        0x21
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_MT_SUM_SHIFT         0x22
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_BUTTON_DSP           0x23
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_AUTOTRIM_CTL         0x24
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_AUTOTRIM_THRS        0x25
#  define DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_AUTOTRIM_FILT_SHFT   0x26

// For compatibility
#  define DSBPM_PROTOCOL_CMD_LONGOUT_LOB_THRSH     DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_LOB_THRSH
#  define DSBPM_PROTOCOL_CMD_LONGOUT_TBT_SUM_SHIFT DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_TBT_SUM_SHIFT
#  define DSBPM_PROTOCOL_CMD_LONGOUT_MT_SUM_SHIFT  DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_MT_SUM_SHIFT

#define DSBPM_PROTOCOL_CMD_HI_SYSMON           0x2000
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_INT32       0x0000
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_UINT16_LO   0x0100
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_UINT16_HI   0x0200
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_INT16_LO    0x0300
# define DSBPM_PROTOCOL_CMD_SYSMON_LO_INT16_HI    0x0400

#define DSBPM_PROTOCOL_CMD_HI_WAVEFORM         0x3000

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
