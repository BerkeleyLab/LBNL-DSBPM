/*
 * Accept and act upon commands from the IOC
 */
#include <stdio.h>
#include <string.h>
#include <lwip/udp.h>
#include "adcProcessing.h"
#include "afe.h"
#include "platform_config.h"
#include "dsbpmProtocol.h"
#include "epics.h"
#include "epicsApplicationCommands.h"
#include "evr.h"
#include "gpio.h"
#include "mgt.h"
#include "rfclk.h"
#include "softwareBuildDate.h"
#include "sysmon.h"
#include "util.h"

int
duplicateIOCcheck(unsigned long address, unsigned int port)
{
    uint32_t now = MICROSECONDS_SINCE_BOOT()/1000000; // in seconds
    static unsigned long oldAddress;
    static unsigned short oldPort;
    static uint32_t whenChanged, whenDuplicate;

    if (address != 0) {
        if ((address != oldAddress) || (port != oldPort)) {
            if ((now - whenChanged) < 10) whenDuplicate = now;
            oldPort = port;
            oldAddress = address;
            whenChanged = now;
        }
    }
    return ((now - whenDuplicate) < 15);
}

/*
 * 32-bit endian swap
 * Assume that we're using GCC
 */
static void
bswap32(uint32_t *b, int n)
{
    while (n--) {
        *b = __builtin_bswap32(*b);
        b++;
    }
}

/*
 * Send reply to IOC
 */
static void
sendReply(struct udp_pcb *pcb, const void *buf, int n,
          const ip_addr_t *addr, u16_t port)
{
    struct pbuf *p;

    p = pbuf_alloc(PBUF_TRANSPORT, n, PBUF_RAM);
    if (p == NULL) {
        printf("Can't allocate pbuf for reply\n");
        return;
    }
    memcpy(p->payload, buf, n);
    udp_sendto(pcb, p, addr, port);
    pbuf_free(p);
}

/*
 * Set the triggers generated by the specified event
 */
static void
setEventAction(int event, uint32_t action)
{
    action = (evrGetEventAction(event) & ~0xFC) | (action & 0xFC);
    evrSetEventAction(event, action);
}

/*
 * Handle a reboot request
 */
static void
crankRebootStateMachine(int value)
{
    static uint16_t match[] = { 1, 100, 10000 };
    static int i;

    if (value == match[i]) {
        i++;
        if (i == (sizeof match / sizeof match[0])) {
            resetFPGA();
        }
    }
    else {
        i = 0;
    }
}
/*
 * Process command common to all applictions
 */

static int
epicsCommonCommand(int commandArgCount, struct dsbpmPacket *cmdp,
                                        struct dsbpmPacket *replyp)
{
    int lo = cmdp->command & DSBPM_PROTOCOL_CMD_MASK_LO;
    int idx = cmdp->command & DSBPM_PROTOCOL_CMD_MASK_IDX;
    int replyArgCount = 0;
    static int powerUpStatus = 1;

    switch (cmdp->command & DSBPM_PROTOCOL_CMD_MASK_HI) {
    case DSBPM_PROTOCOL_CMD_HI_LONGIN:
        if (commandArgCount != 0) return -1;
        replyArgCount = 1;
        switch (idx) {
        case DSBPM_PROTOCOL_CMD_LONGIN_IDX_FIRMWARE_BUILD_DATE:
            replyp->args[0] = GPIO_READ(GPIO_IDX_FIRMWARE_BUILD_DATE);
            break;

        case DSBPM_PROTOCOL_CMD_LONGIN_IDX_SOFTWARE_BUILD_DATE:
            replyp->args[0] = SOFTWARE_BUILD_DATE;
            break;

        case DSBPM_PROTOCOL_CMD_LONGIN_IDX_GIT_HASH_ID:
            replyp->args[0] = GPIO_READ(GPIO_IDX_GITHASH);
            break;

        case DSBPM_PROTOCOL_CMD_LONGIN_IDX_LMX2594_STATUS:
            replyp->args[0] = lmx2594Status();
            break;

        case DSBPM_PROTOCOL_CMD_LONGIN_IDX_DFE_SERIAL_NUMBER:
            replyp->args[0] = serialNumberDFE();
            break;

        case DSBPM_PROTOCOL_CMD_LONGIN_IDX_AFE_SERIAL_NUMBER:
            replyp->args[0] = afeGetSerialNumber();
            break;

        default: return -1;
        }
        break;

    case DSBPM_PROTOCOL_CMD_HI_LONGOUT:
        if (commandArgCount != 1) return -1;
        switch (lo) {
        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_NO_VALUE:
            switch (idx) {
            case DSBPM_PROTOCOL_CMD_LONGOUT_NV_IDX_CLEAR_POWERUP_STATUS:
                powerUpStatus = 0;
                break;

            default: return -1;
            }
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_EVENT_ACTION:
            setEventAction(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_TRIGGER_DELAY:
            evrSetTriggerDelay(idx, cmdp->args[0]);
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_GAIN:
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_SET_COUPLING:
            break;

        case DSBPM_PROTOCOL_CMD_LONGOUT_LO_GENERIC:
            switch (idx) {
            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_IDX_REBOOT:
                crankRebootStateMachine(cmdp->args[0]);
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_EVR_CLK_PER_TURN:
                GPIO_WRITE(GPIO_IDX_EVR_SYNC_CSR, cmdp->args[0]<<16);
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_ENABLE_TRAINING_TONE:
                break;

            case DSBPM_PROTOCOL_CMD_LONGOUT_GENERIC_SET_CALIBRATION_DAC:
                break;

            default: return -1;
            }
            break;

        default: return -1;
        }
        break;

    case DSBPM_PROTOCOL_CMD_HI_SYSMON:
        if (commandArgCount != 0) return -1;
        replyArgCount = sysmonFetch(replyp->args);
        replyArgCount += mgtFetch(replyp->args+replyArgCount);
        replyArgCount += afeFetchADCextents(replyp->args+replyArgCount);
        replyp->args[replyArgCount++] = (CFG_ADC_PHYSICAL_COUNT << 16) |
                                                                  powerUpStatus;
        break;

    case DSBPM_PROTOCOL_CMD_HI_PLL_CONFIG:
        switch (lo) {
        case DSBPM_PROTOCOL_CMD_PLL_CONFIG_LO_SET:
            lmx2594ConfigAllSame(cmdp->args, commandArgCount);
            replyArgCount = 0;
            break;

        case DSBPM_PROTOCOL_CMD_PLL_CONFIG_LO_GET:
            replyArgCount = lmx2594ReadbackFirst(replyp->args,
                                                     DSBPM_PROTOCOL_ARG_CAPACITY);
            break;

        default: return -1;
        }
        break;

    case DSBPM_PROTOCOL_CMD_HI_WAVEFORM:
        break;

    default: return -1;
    }
    return replyArgCount;
}

/*
 * Handle commands from IOC
 */
void
epics_callback(void *arg, struct udp_pcb *pcb, struct pbuf *p,
               const ip_addr_t *fromAddr, u16_t fromPort)
{
    int mustSwap = 0;
    int commandArgCount;
    uint32_t addr = ntohl(fromAddr->addr);
    static struct dsbpmPacket command, reply;
    static int replySize;
    static uint32_t lastNonce;

    if (debugFlags & DEBUGFLAG_EPICS) {
        printf("epics_callback: %d from %d.%d.%d.%d:%d\n", p->len,
                                                    (int)((addr >> 24) & 0xFF),
                                                    (int)((addr >> 16) & 0xFF),
                                                    (int)((addr >>  8) & 0xFF),
                                                    (int)((addr      ) & 0xFF),
                                                    fromPort);
    }

    /*
     * Ignore weird-sized packets
     */
    if ((p->len < DSBPM_PROTOCOL_ARG_COUNT_TO_SIZE(0))
     || (p->len > sizeof command)
     || ((p->len % sizeof(uint32_t)) != 0)) {
        pbuf_free(p);
        if (debugFlags & DEBUGFLAG_EPICS) {
            printf("Unreasonable packet size\n");
        }
        return;
    }
    commandArgCount = DSBPM_PROTOCOL_SIZE_TO_ARG_COUNT(p->len);

    /*
     * Record last time we receive a command from a client
     * in an attempt to detect deuplicate IOC connections.
     */
    duplicateIOCcheck(addr, fromPort);

    /*
     * Must make copy rather than just using payload area
     * since the latter is not aligned on a 32-bit boundary.
     */
    memcpy(&command, p->payload, p->len);
    pbuf_free(p);
    if (command.magic == DSBPM_PROTOCOL_MAGIC_SWAPPED) {
        mustSwap = 1;
        bswap32(&command.magic, p->len / sizeof(int32_t));
    }
    if (command.magic == DSBPM_PROTOCOL_MAGIC) {
        if (debugFlags & DEBUGFLAG_EPICS) {
            printf("Command:%X args:%d  %x\n", (unsigned int)command.command,
                               commandArgCount, (unsigned int)command.args[0]);
        }
        if (command.nonce != lastNonce) {
            int replyArgCount;
            memcpy(&reply, &command, DSBPM_PROTOCOL_ARG_COUNT_TO_SIZE(0));
            if (((replyArgCount = epicsApplicationCommand(commandArgCount,
                                                      &command, &reply)) < 0)
             && ((replyArgCount = epicsCommonCommand(commandArgCount,
                                                      &command, &reply)) < 0)) {
                return;
            }
            lastNonce = command.nonce;
            replySize = DSBPM_PROTOCOL_ARG_COUNT_TO_SIZE(replyArgCount);
            if (mustSwap) {
                bswap32(&reply.magic, replySize / sizeof(int32_t));
            }
        }
        if (debugFlags & DEBUGFLAG_EPICS) {
            printf("Reply:%d\n", replySize);
        }
        sendReply(pcb, &reply, replySize, fromAddr, fromPort);
    }
    else {
        if (debugFlags & DEBUGFLAG_EPICS) {
            printf("Bad magic number 0x%08X\n", command.magic);
        }
    }
}

void
epicsInit(void)
{
    int err;
    struct udp_pcb *pcb;

    pcb = udp_new();
    if (pcb == NULL) {
        fatal("Can't create epics PCB");
        return;
    }
    err = udp_bind(pcb, IP_ADDR_ANY, DSBPM_PROTOCOL_UDP_PORT);
    if (err != ERR_OK) {
        fatal("Can't bind to EPICS port, error:%d", err);
        return;
    }
    udp_recv(pcb, epics_callback, NULL);
}
