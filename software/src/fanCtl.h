/*
 * Fan control
 */

#ifndef _FAN_CTL_H_
#define _FAN_CTL_H_

#include <stdint.h>

int fanCtlFanSpeeds(unsigned int fanIdx);
int fanCtlFetch(uint32_t *args);
void fanCtlInfoDisplay(void);

#endif /* _FAN_CTL_H_ */
