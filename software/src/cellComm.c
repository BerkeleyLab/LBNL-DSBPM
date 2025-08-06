/*
 * BPM/cell controller communication
 */

#include <stdio.h>
#include <string.h>
#include <xparameters.h>
#include "dsbpmProtocol.h"
#include "cellComm.h"
#include "gpio.h"
#include "util.h"

/* Number of communication links: CCW and CW */
#define CELL_COMM_LINK_CW_IDX                       0
#define CELL_COMM_LINK_CCW_IDX                      1
#define CELL_COMM_LINKS_COUNT                       2

static int _fofbIndex;

struct cellCommInfo {
    const char *name;
    enum auState
        {S_UP, S_DOWN1, S_AURORA_RESET1, S_DOWN2, S_BOTH_RESET, S_AURORA_RESET2}
                oldState, state;
    uint32_t    gpioIdx;
    uint32_t    gtReset;
    uint32_t    auroraReset;
    uint32_t    channelUp;
    uint32_t    control;
    uint32_t    base;
    uint32_t    limit;
};

static struct cellCommInfo cellCommInfos[CELL_COMM_LINKS_COUNT] =
{
    {
        .name        = "CCW",
        .state       = S_UP,
        .gpioIdx     = GPIO_IDX_CELL_COMM_CCW_CSR,
        .gtReset     = CELLCOMM_MGT_CSR_GT_RESET,
        .auroraReset = CELLCOMM_MGT_CSR_AURORA_RESET,
        .channelUp   = CELLCOMM_MGT_CSR_CHANNEL_UP
    },
    {
        .name        = "CW",
        .state       = S_UP,
        .gpioIdx     = GPIO_IDX_CELL_COMM_CW_CSR,
        .gtReset     = CELLCOMM_MGT_CSR_GT_RESET,
        .auroraReset = CELLCOMM_MGT_CSR_AURORA_RESET,
        .channelUp   = CELLCOMM_MGT_CSR_CHANNEL_UP
    },
};

static const char *
stateName(enum auState state)
{
    switch (state) {
    case S_UP:            return "S_UP";
    case S_DOWN1:         return "S_DOWN1";
    case S_AURORA_RESET1: return "S_AURORA_RESET1";
    case S_DOWN2:         return "S_DOWN2";
    case S_BOTH_RESET:    return "S_BOTH_RESET";
    case S_AURORA_RESET2: return "S_AURORA_RESET2";
    default:              return "S_?";
    }
}

static void
crank(struct cellCommInfo *cellp)
{
    uint32_t usec = MICROSECONDS_SINCE_BOOT();
    uint32_t status = GPIO_READ(cellp->gpioIdx);
    int timeout = ((usec - cellp->base) > cellp->limit);
    cellp->oldState = cellp->state;

    switch (cellp->state) {
    case S_UP:
        if ((status & cellp->channelUp) == 0) {
            cellp->base = usec;
            cellp->control = 0;
            cellp->limit = 30000000;
            cellp->state = S_DOWN1;
        }
        break;

    case S_DOWN1:
        if (status & cellp->channelUp) {
            cellp->state = S_UP;
        }
        else if (timeout) {
            cellp->control |= cellp->auroraReset;
            GPIO_WRITE(cellp->gpioIdx, cellp->control);
            cellp->base = usec;
            cellp->limit = 100000;
            cellp->state = S_AURORA_RESET1;
        }
        break;

    case S_AURORA_RESET1:
        if (timeout) {
            cellp->control &= ~cellp->auroraReset;
            GPIO_WRITE(cellp->gpioIdx, cellp->control);
            cellp->base = usec;
            cellp->limit = 1000000;
            cellp->state = S_DOWN2;
        }
        break;

    case S_DOWN2:
        if (status & cellp->channelUp) {
            cellp->state = S_UP;
        }
        else if (timeout) {
            cellp->control |= cellp->auroraReset | cellp->gtReset;
            GPIO_WRITE(cellp->gpioIdx, cellp->control);
            cellp->base = usec;
            cellp->limit = 100000;
            cellp->state = S_BOTH_RESET;
        }
        break;

    case S_BOTH_RESET:
        if (timeout) {
            cellp->control &= ~cellp->gtReset;
            GPIO_WRITE(cellp->gpioIdx, cellp->control);
            cellp->base = usec;
            cellp->limit = 1000000;
            cellp->state = S_AURORA_RESET2;
        }
        break;

    case S_AURORA_RESET2:
        if (timeout) {
            cellp->control &= ~cellp->auroraReset;
            GPIO_WRITE(cellp->gpioIdx, cellp->control);
            cellp->base = usec;
            cellp->limit = 30000000;
            cellp->state = S_DOWN1;
        }
        break;
    }

    if ((debugFlags & DEBUGFLAG_CELL_COMM) && (cellp->state != cellp->oldState))
        printf("%3s cellp->control 0x%02x, status 0x%02x, state %s\n", cellp->name,
            cellp->control, status, stateName(cellp->state));
}

void
cellCommCrank(void)
{
    struct cellCommInfo *cellp;

    for (cellp = cellCommInfos; cellp < &cellCommInfos[CELL_COMM_LINKS_COUNT]; ++cellp) {
        crank(cellp);
    }
}

static int
cellCommInitSingle(struct cellCommInfo *cellp)
{
    uint32_t then, now, start;
    uint32_t csr;

    GPIO_WRITE(cellp->gpioIdx, cellp->auroraReset |
            cellp->gtReset);
    microsecondSpin(100000);
    GPIO_WRITE(cellp->gpioIdx, cellp->auroraReset);
    microsecondSpin(1000000);
    GPIO_WRITE(cellp->gpioIdx, 0);

    then = MICROSECONDS_SINCE_BOOT();
    // Check if PLL locks and resets have been completed
    while (((csr = GPIO_READ(cellp->gpioIdx)) &
                (CELLCOMM_MGT_CSR_LOCKS_MASK | CELLCOMM_MGT_CSR_RESETS_MASK)) !=
                (CELLCOMM_MGT_CSR_LOCKS_GOOD | CELLCOMM_MGT_CSR_RESETS_GOOD)) {
        if ((MICROSECONDS_SINCE_BOOT() - then) > 250000) {
            warn("Aurora %s didn't reset: %X", cellp->name, csr);
            return -1;
        }
    }

    start = then = MICROSECONDS_SINCE_BOOT();
    while(((csr = GPIO_READ(cellp->gpioIdx)) &
            cellp->channelUp) != cellp->channelUp) {
        if ((MICROSECONDS_SINCE_BOOT() - then) > 2000000) {
            warn("Aurora %s channel down: %X", cellp->name, csr);
            return -1;
        }
    }

    printf("auroraInit %s done: %d us\n", cellp->name,
            MICROSECONDS_SINCE_BOOT() - start);

    return 0;
}

int
cellCommInit(void)
{
    int ret = 0;
    struct cellCommInfo *cellp;

    for (cellp = cellCommInfos; cellp < &cellCommInfos[CELL_COMM_LINKS_COUNT]; ++cellp) {
        ret |= cellCommInitSingle(cellp);
    }

    return ret;
}

static int
cellCommStatusSingle(struct cellCommInfo *cellp)
{
    uint32_t r;

    r = GPIO_READ(cellp->gpioIdx);

    if ((r & CELLCOMM_MGT_CSR_CHANNEL_UP) != CELLCOMM_MGT_CSR_CHANNEL_UP) {
        printf("%s", cellp->name);

        if (r & CELLCOMM_MGT_CSR_HARD_ERR) {
            printf("  hard error");
        }
        if (r & CELLCOMM_MGT_CSR_SOFT_ERR) {
            printf("  soft error");
        }
        if ((r & CELLCOMM_MGT_CSR_LANE_UP) != CELLCOMM_MGT_CSR_LANE_UP) {
            printf("  lane NOT up");
        }
        if ((r & CELLCOMM_MGT_CSR_TX_RESET_DONE) != CELLCOMM_MGT_CSR_TX_RESET_DONE) {
            printf("  TX reset NOT done");
        }
        if ((r & CELLCOMM_MGT_CSR_RX_RESET_DONE) != CELLCOMM_MGT_CSR_RX_RESET_DONE) {
            printf("  RX reset NOT done");
        }
        if ((r & CELLCOMM_MGT_CSR_MMCM_NOT_LOCK) != CELLCOMM_MGT_CSR_MMCM_NOT_LOCK) {
            printf("  MMCM NOT locked");
        }
        if ((r & CELLCOMM_MGT_CSR_TX_PLL_LOCK) != CELLCOMM_MGT_CSR_TX_PLL_LOCK) {
            printf("  TX PLL NOT locked");
        }
        if ((r & CELLCOMM_MGT_CSR_CPLL_LOCK) != CELLCOMM_MGT_CSR_CPLL_LOCK) {
            printf("  CPLL NOT locked");
        }

        printf("\n");
    }

    return (r & CELLCOMM_MGT_CSR_CHANNEL_UP) != 0;
}

int
cellCommStatus(void)
{
    struct cellCommInfo *cellp;
    int i = 0;
    int ret = 0;

    for (i = 0, cellp = cellCommInfos; cellp < &cellCommInfos[CELL_COMM_LINKS_COUNT]; ++cellp, ++i) {
        ret |= (cellCommStatusSingle(cellp) << i);
    }

    return ret;
}

void
cellCommSetFOFB(int fofbIndex)
{
    _fofbIndex = fofbIndex;
}

int
cellCommGetFOFB(void)
{
    return _fofbIndex;
}
