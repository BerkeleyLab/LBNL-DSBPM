#include <stdio.h>
#include <xil_io.h>
#include <stdbool.h>
#include "boardInfo.h"
#include "util.h"
#include "iic.h"

static uint8_t eepromBuf[128];

static const struct infoChunks infoChunks[] ={
    [BOARD_INFO_NAME] = {
        .size = member_size(struct boardInfo, name),
        .offset = offsetof(struct boardInfo, name),
        .memOffset = 0x0,
    },
    [BOARD_INFO_REV] = {
        .size = member_size(struct boardInfo, rev),
        .offset = offsetof(struct boardInfo, rev),
        .memOffset = 0x11,
    },
    [BOARD_INFO_SN] = {
        .size = member_size(struct boardInfo, sn),
        .offset = offsetof(struct boardInfo, sn),
        .memOffset = 0x14,
    },
    [BOARD_INFO_FORMAT_VER] = {
        .size = member_size(struct boardInfo, formatVer),
        .offset = offsetof(struct boardInfo, formatVer),
        .memOffset = 0x20,
    },
    [BOARD_INFO_MAC_0] = {
        .size = member_size(struct boardInfo, mac0),
        .offset = offsetof(struct boardInfo, mac0),
        .memOffset = 0x23,
    },
    [BOARD_INFO_MAC_1] = {
        .size = member_size(struct boardInfo, mac1),
        .offset = offsetof(struct boardInfo, mac1),
        .memOffset = 0x29,
    },
    [BOARD_INFO_MAC_2] = {
        .size = member_size(struct boardInfo, mac2),
        .offset = offsetof(struct boardInfo, mac2),
        .memOffset = 0x2f,
    },
    [BOARD_INFO_MAC_3] = {
        .size = member_size(struct boardInfo, mac3),
        .offset = offsetof(struct boardInfo, mac3),
        .memOffset = 0x35,
    },
    [BOARD_INFO_ACTIVE] = {
        .size = member_size(struct boardInfo, active),
        .offset = offsetof(struct boardInfo, active),
        .memOffset = 0x3b,
    },
    [BOARD_INFO_CFG_MODE] = {
        .size = member_size(struct boardInfo, configMode),
        .offset = offsetof(struct boardInfo, configMode),
        .memOffset = 0x3c,
    },
};

#define INFO_CHUNKS_SIZE ARRAY_SIZE(infoChunks)

struct boardInfo boardInfo;

static int
getBoardInfo(int verbose)
{
    int ret = eepromRead(0, eepromBuf, sizeof(eepromBuf));

    if (!ret) {
        return -1;
    }

    if (verbose) {
        eepromDisplay(eepromBuf, sizeof(eepromBuf));
    }

    for (int i = 0; i < INFO_CHUNKS_SIZE; i++) {
        size_t offset = infoChunks[i].offset;
        size_t memOffset = infoChunks[i].memOffset;
        size_t size = infoChunks[i].size;

        if ((offset + size > sizeof(struct boardInfo)) ||
                (memOffset + size > sizeof(eepromBuf))) {
            return -1;
        }

        memcpy((char *)&boardInfo + offset,
                (const char *)eepromBuf + memOffset,
                size);
    }

    return 0;
}

void
boardInfoDisplay(void)
{
    printf("Board info:\n");
    printf("    name: %.*s\n",
            (int) sizeof(boardInfo.name), (const char *) boardInfo.name);
    printf("    revision: %.*s\n",
            (int) sizeof(boardInfo.rev), (const char *) boardInfo.rev);
    printf("    serial number: %.*s\n",
            (int) sizeof(boardInfo.sn), (const char *) boardInfo.sn);
    printf("    format version: %.*s\n",
            (int) sizeof(boardInfo.formatVer), (const char *) boardInfo.formatVer);
    printf("    mac0: %02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X\n",
            *boardInfo.mac0, *(boardInfo.mac0+1),
            *(boardInfo.mac0+2), *(boardInfo.mac0+3),
            *(boardInfo.mac0+4), *(boardInfo.mac0+5),
            *(boardInfo.mac0+6), *(boardInfo.mac0+7));
    printf("    mac1: %02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X\n",
            *boardInfo.mac1, *(boardInfo.mac1+1),
            *(boardInfo.mac1+2), *(boardInfo.mac1+3),
            *(boardInfo.mac1+4), *(boardInfo.mac1+5),
            *(boardInfo.mac1+6), *(boardInfo.mac1+7));
    printf("    mac2: %02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X\n",
            *boardInfo.mac2, *(boardInfo.mac2+1),
            *(boardInfo.mac2+2), *(boardInfo.mac2+3),
            *(boardInfo.mac2+4), *(boardInfo.mac2+5),
            *(boardInfo.mac2+6), *(boardInfo.mac2+7));
    printf("    mac3: %02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X\n",
            *boardInfo.mac3, *(boardInfo.mac3+1),
            *(boardInfo.mac3+2), *(boardInfo.mac3+3),
            *(boardInfo.mac3+4), *(boardInfo.mac3+5),
            *(boardInfo.mac3+6), *(boardInfo.mac3+7));
    printf("    active: %c\n", (const char) boardInfo.active);
    printf("    config mode: %02X\n", *boardInfo.configMode);
}

void
boardInfoInit(int verbose)
{
    int ret = getBoardInfo(verbose);

    if (ret != 0) {
        warn("Board info request");
        return;
    }

    if (verbose) {
        boardInfoDisplay();
    }
}

/*
 * To be used with EPICS routines. This returns the number of uint32_t
 * words used
 */
int
boardInfoFetch(uint32_t *buf, enum boardInfoProp prop)
{
    size_t size = infoChunks[prop].size;
    size_t offset = infoChunks[prop].offset;

    memcpy((char *)buf,
            (const char *)&boardInfo + offset,
            size);

    return (size + 3)/4;
}
