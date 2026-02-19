/*
 * System monitoring 2
 */
#ifndef _SYSMON_2_H_
#define _SYSMON_2_H_

void sysmon2Init(void);
int sysmon2Fetch(uint32_t *args);
int sysmon2Draw(void);
void sysmon2Display(void);

#endif  /* _SYSMON_H_ */
