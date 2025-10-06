/*
 * Deal with physical to logical ADC mapping
 */

#include <stdio.h>
#include <stdint.h>
#include "gpio.h"
#include "systemParameters.h"

/*
 * AdcOperand selection
 * Dividend = (OP0 + OP1) - (OP2 + OP3)
 */
#define OP0_SHIFT 0
#define OP1_SHIFT 3
#define OP2_SHIFT 6
#define OP3_SHIFT 9
#define OP4_SHIFT 12
#define OP5_SHIFT 15
#define OP6_SHIFT 18
#define OP7_SHIFT 21
#define OP0(x)  ((x) << OP0_SHIFT)
#define OP1(x)  ((x) << OP1_SHIFT)
#define OP2(x)  ((x) << OP2_SHIFT)
#define OP3(x)  ((x) << OP3_SHIFT)
#define OP4(x)  ((x) << OP4_SHIFT)
#define OP5(x)  ((x) << OP5_SHIFT)
#define OP6(x)  ((x) << OP6_SHIFT)
#define OP7(x)  ((x) << OP7_SHIFT)

void
adcMappingInit()
{
    int ADC_0 = ((systemParameters.adcOrder / 10000000) % 10) & 0x7;
    int ADC_1 = ((systemParameters.adcOrder / 1000000 ) % 10) & 0x7;
    int ADC_2 = ((systemParameters.adcOrder / 100000  ) % 10) & 0x7;
    int ADC_3 = ((systemParameters.adcOrder / 10000   ) % 10) & 0x7;
    int ADC_4 = ((systemParameters.adcOrder / 1000    ) % 10) & 0x7;
    int ADC_5 = ((systemParameters.adcOrder / 100     ) % 10) & 0x7;
    int ADC_6 = ((systemParameters.adcOrder / 10      ) % 10) & 0x7;
    int ADC_7 = ((systemParameters.adcOrder / 1       ) % 10) & 0x7;
    uint32_t adcMapping =
        OP7(ADC_7) | OP6(ADC_6) | OP5(ADC_5) | OP4(ADC_4) |
        OP3(ADC_3) | OP2(ADC_2) | OP1(ADC_1) | OP0(ADC_0);

    GPIO_WRITE(GPIO_IDX_ADC_MAPPING, adcMapping);
}
