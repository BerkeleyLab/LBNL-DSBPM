/*
 * Utility routines
 */

#ifndef _UTIL_H_
#define _UTIL_H_

#include <stdint.h>

/*
 * Convenient macros
 */
#define MB(x) ((x)*1024*1024)
#define kB(x) ((x)*1024)

#ifndef offsetof
#define offsetof(TYPE, MEMBER) ((size_t) &((TYPE *)0)->MEMBER)
#endif

#define ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))

/* Stringify MACRO */
#define STRINGIFY(s) _STRINGIFY(s)
#define _STRINGIFY(s) #s

#ifndef __TARGET_VARIANT_NAME__
#define __TARGET_VARIANT_NAME__ "UNKNOWN"
#endif

#ifndef __TARGET_SAMPLES_PER_TURN_NAME__
#define __TARGET_SAMPLES_PER_TURN_NAME__ "UNKNOWN"
#endif

#ifndef __TARGET_VCXO_TYPE_NAME__
#define __TARGET_VCXO_TYPE_NAME__ "UNKNOWN"
#endif

#ifndef __TARGET_NAME__
#define __TARGET_NAME__ "UNKNOWN"
#endif

/*
 * Diagnostics
 */
#define DEBUGFLAG_EPICS             0x01
#define DEBUGFLAG_TFTP              0x02
#define DEBUGFLAG_EVR               0x04
#define DEBUGFLAG_ACQUISITION       0x08
#define DEBUGFLAG_IIC               0x10
#define DEBUGFLAG_INFO_SHOW         0x20
#define DEBUGFLAG_DRP               0x40
#define DEBUGFLAG_CALIBRATION       0x80
#define DEBUGFLAG_SHOW_TEST         0x100
#define DEBUGFLAG_SHOW_ADC_SYSREF   0x400
#define DEBUGFLAG_SHOW_DAC_SYSREF   0x800
#define DEBUGFLAG_RFDC_MMCM_SHOW    0x1000
#define DEBUGFLAG_RF_CLK_SHOW       0x2000
#define DEBUGFLAG_RF_ADC_SHOW       0x4000
#define DEBUGFLAG_SHOW_DRP          0x8000
#define DEBUGFLAG_ACQ_SYNC          0x10000
#define DEBUGFLAG_SLIDE_MGT         0x20000
#define DEBUGFLAG_RF_DAC_SHOW       0x40000
#define DEBUGFLAG_EVR_SROC          0x80000
#define DEBUGFLAG_RESTART_AFE_ADC   0x100000
#define DEBUGFLAG_RESTART_TILES     0x200000
#define DEBUGFLAG_RESYNC_ADC        0x400000
#define DEBUGFLAG_SA_TIMING_CHECK   0x800000
#define DEBUGFLAG_PUBLISHER         0x1000000
#define DEBUGFLAG_RECORDER_DIAG     0x2000000
#define DEBUGFLAG_WAVEFORM_XFER     0x4000000
#define DEBUGFLAG_WAVEFORM_HEAD     0x8000000
#define DEBUGFLAG_LOCAL_OSC_SHOW    0x10000000

extern int debugFlags;

void fatal(const char *fmt, ...);
void warn(const char *fmt, ...);
void microsecondSpin(unsigned int us);
void resetFPGA(void);
void checkForReset(void);
int resetRecoverySwitchPressed(void);
void showReg(unsigned int i);

int serialNumberDFE(void);

const char *getVariantInfo(void);
const char *getSamplesPerTurnInfo(void);
const char *getVCXOTypeInfo(void);
const char *getTargetNameInfo(void);
void displayInfo(void);

#endif /* _UTIL_H_ */
