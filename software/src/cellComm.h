/*
 * BPM/cell controller communication
 */

#ifndef _CELLCOMM_H_
#define _CELLCOMM_H_

/*
 * MGT CSR W bits
 */
#define CELLCOMM_MGT_CSR_POWER_DOWN                 0x1
#define CELLCOMM_MGT_CSR_AURORA_RESET               0x2
#define CELLCOMM_MGT_CSR_GT_RESET                   0x4
#define CELLCOMM_MGT_CSR_TX_PCS_RESET               0x8
#define CELLCOMM_MGT_CSR_TX_PMA_RESET               0x10
#define CELLCOMM_MGT_CSR_TX_POLARITY                0x20

/*
 * MGT CSR R bits
 */
#define CELLCOMM_MGT_CSR_CPLL_LOCK           0x1
#define CELLCOMM_MGT_CSR_TX_PLL_LOCK         0x2
#define CELLCOMM_MGT_CSR_MMCM_NOT_LOCK       0x4
#define CELLCOMM_MGT_CSR_RX_RESET_DONE       0x8
#define CELLCOMM_MGT_CSR_TX_RESET_DONE       0x10
#define CELLCOMM_MGT_CSR_GT_CRC_PASS         0x20
#define CELLCOMM_MGT_CSR_CRC_VALID           0x40
#define CELLCOMM_MGT_CSR_CRC_PASS            0x80
#define CELLCOMM_MGT_CSR_CHANNEL_UP          0x100
#define CELLCOMM_MGT_CSR_LANE_UP             0x200
#define CELLCOMM_MGT_CSR_SOFT_ERR            0x400
#define CELLCOMM_MGT_CSR_HARD_ERR            0x800

#define CELLCOMM_MGT_CSR_LOCKS_MASK         (CELLCOMM_MGT_CSR_CPLL_LOCK | \
                                             CELLCOMM_MGT_CSR_TX_PLL_LOCK | \
                                             CELLCOMM_MGT_CSR_MMCM_NOT_LOCK)
#define CELLCOMM_MGT_CSR_LOCKS_GOOD         (CELLCOMM_MGT_CSR_CPLL_LOCK | \
                                             CELLCOMM_MGT_CSR_TX_PLL_LOCK)

#define CELLCOMM_MGT_CSR_RESETS_MASK        (CELLCOMM_MGT_CSR_RX_RESET_DONE | \
                                             CELLCOMM_MGT_CSR_TX_RESET_DONE)
#define CELLCOMM_MGT_CSR_RESETS_GOOD        (CELLCOMM_MGT_CSR_RX_RESET_DONE | \
                                             CELLCOMM_MGT_CSR_TX_RESET_DONE)

int cellCommInit();
void cellCommCrank();
int cellCommStatus();
void cellCommSetFOFB(int fofbIndex);
int cellCommGetFOFB();

#endif
