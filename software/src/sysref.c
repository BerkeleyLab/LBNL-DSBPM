#include <stdio.h>
#include <stdint.h>
#include "sysref.h"
#include "gpio.h"
#include "util.h"

#define SYSREF_CSR_SAMPLED_CLK_FAULT            (1 << 31)
#define SYSREF_CSR_SAMPLED_CLK_DIVISOR_SHIFT    16
#define SYSREF_CSR_REF_CLK_FAULT                (1 << 15)
#define SYSREF_CSR_REF_CLK_DIVISOR_SHIFT        0

void
sysrefInit(unsigned int type)
{
    unsigned int index = (type == 0)? GPIO_IDX_SYSREF_ADC_CSR :
        GPIO_IDX_SYSREF_DAC_CSR;
    unsigned int clkPerSysref = (type == 0)? ADC_CLK_PER_SYSREF :
        DAC_CLK_PER_SYSREF;
    GPIO_WRITE(index,
               ((clkPerSysref-1) << SYSREF_CSR_SAMPLED_CLK_DIVISOR_SHIFT) |
               ((REFCLK_OUT_PER_SYSREF-1) << SYSREF_CSR_REF_CLK_DIVISOR_SHIFT));
    GPIO_WRITE(index, SYSREF_CSR_SAMPLED_CLK_FAULT |
                                    SYSREF_CSR_REF_CLK_FAULT);

    if (debugFlags & DEBUGFLAG_SHOW_ADC_SYSREF) sysrefShow(0);
    if (debugFlags & DEBUGFLAG_SHOW_DAC_SYSREF) sysrefShow(1);
}

void
sysrefShow(unsigned int type)
{
    unsigned int index = (type == 0)? GPIO_IDX_SYSREF_ADC_CSR :
        GPIO_IDX_SYSREF_DAC_CSR;
    unsigned int clkPerSysref = (type == 0)? ADC_CLK_PER_SYSREF :
        DAC_CLK_PER_SYSREF;
    const char *typeStr = (type == 0)? "ADC" : "DAC";
    uint32_t v = GPIO_READ(index);
    printf("%d %s AXI clocks per SYSREF (expect %d).\n",
                           ((v >> SYSREF_CSR_SAMPLED_CLK_DIVISOR_SHIFT) & 0x3FF) + 1,
                           typeStr,
                           clkPerSysref);
    printf("%d FPGA_REFCLK_OUT_C clocks per SYSREF (expect %d).\n",
                           ((v >> SYSREF_CSR_REF_CLK_DIVISOR_SHIFT) & 0x3FF) + 1,
                           REFCLK_OUT_PER_SYSREF);
    if (v & SYSREF_CSR_SAMPLED_CLK_FAULT) {
        print("%s AXI SYSREF fault.\n", typeStr);
        GPIO_WRITE(index, SYSREF_CSR_SAMPLED_CLK_FAULT);
    }
    if (v & SYSREF_CSR_REF_CLK_FAULT) {
        print("FPGA_REFCLK_OUT_C SYSREF fault.\n");
        GPIO_WRITE(index, SYSREF_CSR_REF_CLK_FAULT);
    }
}
