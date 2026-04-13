/*
 * Board Info
 */

#ifndef _BOARD_INFO_H_
#define _BOARD_INFO_H_

#include <stdint.h>

enum boardInfoProp {
    BOARD_INFO_NAME = 0,
    BOARD_INFO_REV = 1,
    BOARD_INFO_SN = 2,
    BOARD_INFO_FORMAT_VER = 3,
    BOARD_INFO_MAC_0 = 4,
    BOARD_INFO_MAC_1 = 5,
    BOARD_INFO_MAC_2 = 6,
    BOARD_INFO_MAC_3 = 7,
    BOARD_INFO_ACTIVE = 8,
    BOARD_INFO_CFG_MODE = 9
};

struct boardInfo {
    uint8_t name[6];
    uint8_t rev[3];
    uint8_t sn[12];
    uint8_t formatVer[3];
    uint8_t mac0[8];
    uint8_t mac1[8];
    uint8_t mac2[8];
    uint8_t mac3[8];
    uint8_t active;
    uint8_t configMode;
};

extern struct boardInfo boardInfo;

struct infoChunks {
    size_t size;
    size_t offset;
    size_t memOffset;
};

void boardInfoDisplay(void);
void boardInfoInit(int verbose);
int boardInfoFetch(uint32_t *buf, enum boardInfoProp prop);

#endif
