/*
 * Board Info
 */

#ifndef _BOARD_INFO_H_
#define _BOARD_INFO_H_

#include <stdint.h>

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
    uint8_t configMode[2];
};

extern struct boardInfo boardInfo;

struct infoChunks {
    size_t size;
    size_t offset;
    size_t memOffset;
};

void boardInfoDisplay(void);
void boardInfoInit(int verbose);

#endif
