/*
 * Common serializer/deserializer routines
 */

#ifndef _SERDES_H_
#define _SERDES_H_

#include <stdint.h>

char *formatIP(const void *val);
int   parseIP(const char *str, void *val);
char *formatMAC(const void *val);
int   parseMAC(const char *str, void *val);

char *formatMAC(const void *val);
int parseMAC(const char *str, void *val);

char * formatIP(const void *val);
int parseIP(const char *str, void *val);

char *formatDouble(void *val);
int parseDouble(const char *str, void *val);

char *formatFloat(const void *val);
int parseFloat(const char *str, void *val);

char *formatInt(const void *val);
char *formatInt4(const void *val);
int parseInt(const char *str, void *val);

int parseHex(const char *str, void *val);
char *formatHex(const void *val);

#endif
