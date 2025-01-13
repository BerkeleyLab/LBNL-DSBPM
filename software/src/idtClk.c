/*
 * RF clock generation components
 */
#include <stdio.h>
#include <stdint.h>
#include <xil_assert.h>
#include "iic.h"
#include "idtClk.h"
#include "util.h"

#define MAX_IDT_REG_DATA_SIZE 128

// FIXME Super stupid way of wasting a lot of space
struct idtReg {
    uint8_t size;
    uint8_t data[MAX_IDT_REG_DATA_SIZE];
};

typedef struct idtReg idtReg;

/*
 * Configure Renesas 8A34001 clock generator.
 */
void
initIDT8A34001(void)
{
    int i;
#if defined (__TARGET_DSBPM_ZCU208__) || defined(__TARGET_DSBPM_LBL208__)
    static const struct idtReg idtRegs[] = {
#include "idt8A34001.h"
    };
    for (i = 0 ; i < ARRAY_SIZE(idtRegs); i++) {
        iicWrite(IIC_INDEX_8A34001, idtRegs[i].data, idtRegs[i].size);
    }
#else
#   error "Unrecognized __TARGET_XXX__ macro"
#endif
}

void
mgtClkIDTInit(void)
{
    initIDT8A34001();
}
