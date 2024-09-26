module dsbpm_vcxo_117_lbl208 #(
    parameter DDR_ILA_CHIPSCOPE_DBG     = "FALSE",
    parameter DAC_ILA_CHIPSCOPE_DBG     = "FALSE",
    parameter ADC_WIDTH                 = 14,
    parameter AXI_ADC_SAMPLE_WIDTH      = ((ADC_WIDTH + 7) / 8) * 8,
    parameter AXI_ADDR_WIDTH            = 35,
    parameter AXI_ADC_DATA_WIDTH        = 256, // 2 * 8 * I/Q ADC samples
    parameter AXI_MAG_DATA_WIDTH        = 128,
    parameter DAC_WIDTH                 = 14,
    parameter DAC_SAMPLE_WIDTH          = ((DAC_WIDTH + 7) / 8) * 8,
    parameter IQ_DATA                   = "TRUE",
    parameter SYSCLK_RATE               = 99999001,  // From block design
    parameter BD_ADC_CHANNEL_COUNT      = 16,
    parameter BD_DAC_CHANNEL_COUNT      = 8,
    parameter ADC_CHANNEL_DEBUG         = "false",
    parameter LO_WIDTH                  = 18,
    parameter MAG_WIDTH                 = 26,
    parameter PRODUCT_WIDTH             = AXI_ADC_SAMPLE_WIDTH + LO_WIDTH - 1,
    parameter ACQ_WIDTH                 = 32,
    parameter SITE_SAMPLES_PER_TURN     = 81,
    parameter SITE_TURNS_PER_PT         = 19, // 11/19 PT
    parameter SITE_CIC_FA_DECIMATE      = 76,
    parameter SITE_CIC_SA_DECIMATE      = 1000,
    parameter SITE_CIC_STAGES           = 2) (
    input  USER_MGT_SI570_CLK_P, USER_MGT_SI570_CLK_N,
    input  SFP2_RX_P, SFP2_RX_N,
    output SFP2_TX_P, SFP2_TX_N,
    output SFP2_TX_ENABLE,

    input  FPGA_REFCLK_OUT_C_P, FPGA_REFCLK_OUT_C_N,
    input  SYSREF_FPGA_C_P, SYSREF_FPGA_C_N,
    input  SYSREF_RFSOC_C_P, SYSREF_RFSOC_C_N,
    input  RFMC_ADC_00_P, RFMC_ADC_00_N,
    input  RFMC_ADC_01_P, RFMC_ADC_01_N,
    input  RF1_CLKO_B_C_P, RF1_CLKO_B_C_N,
    input  RFMC_ADC_02_P, RFMC_ADC_02_N,
    input  RFMC_ADC_03_P, RFMC_ADC_03_N,
    input  RFMC_ADC_04_P, RFMC_ADC_04_N,
    input  RFMC_ADC_05_P, RFMC_ADC_05_N,
    input  RFMC_ADC_06_P, RFMC_ADC_06_N,
    input  RFMC_ADC_07_P, RFMC_ADC_07_N,

    output  RFMC_DAC_00_P, RFMC_DAC_00_N,
    output  RFMC_DAC_01_P, RFMC_DAC_01_N,
    output  RFMC_DAC_02_P, RFMC_DAC_02_N,
    output  RFMC_DAC_03_P, RFMC_DAC_03_N,
    input   RF4_CLKO_B_C_P, RF4_CLKO_B_C_N,
    output  RFMC_DAC_04_P, RFMC_DAC_04_N,
    output  RFMC_DAC_05_P, RFMC_DAC_05_N,
    output  RFMC_DAC_06_P, RFMC_DAC_06_N,
    output  RFMC_DAC_07_P, RFMC_DAC_07_N,

    input   SYS_CLK_C0_P, SYS_CLK_C0_N,

    output          DDR4_C0_ACT_N,
    output [16:0]   DDR4_C0_ADR,
    output [1:0]    DDR4_C0_BA,
    output [1:0]    DDR4_C0_BG,
    output          DDR4_C0_CK_C,
    output          DDR4_C0_CK_T,
    output          DDR4_C0_CKE,
    output [1:0]    DDR4_C0_CS_N,
    inout  [3:0]    DDR4_C0_DM_DBI_N,
    inout  [31:0]   DDR4_C0_DQ,
    inout  [3:0]    DDR4_C0_DQS_C,
    inout  [3:0]    DDR4_C0_DQS_T,
    output          DDR4_C0_ODT,
    output          DDR4_C0_RESET_N,

    output wire SFP_REC_CLK_P,
    output wire SFP_REC_CLK_N,

    output wire EVR_FB_CLK,
    output wire CLK104_SYNC_IN,
    output wire EVR_SROC,

    input             GPIO_SW_W,
    input             GPIO_SW_E,
    input             GPIO_SW_N,
    input       [7:0] DIP_SWITCH,
    output wire [7:0] GPIO_LEDS,

    output wire [1:0] AFE_SPI_CLK,
    output wire [1:0] AFE_SPI_SDI,
    output wire [1:0] AFE_SPI_LE,

    output wire       CLK_SPI_MUX_SEL0,
    output wire       CLK_SPI_MUX_SEL1
);

common_dsbpm_top #(
    .DDR_ILA_CHIPSCOPE_DBG(DDR_ILA_CHIPSCOPE_DBG),
    .DAC_ILA_CHIPSCOPE_DBG(DAC_ILA_CHIPSCOPE_DBG),
    .ADC_WIDTH(ADC_WIDTH),
    .AXI_ADC_SAMPLE_WIDTH(AXI_ADC_SAMPLE_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ADC_DATA_WIDTH(AXI_ADC_DATA_WIDTH),
    .AXI_MAG_DATA_WIDTH(AXI_MAG_DATA_WIDTH),
    .DAC_WIDTH(DAC_WIDTH),
    .DAC_SAMPLE_WIDTH(DAC_SAMPLE_WIDTH),
    .IQ_DATA(IQ_DATA),
    .SYSCLK_RATE(SYSCLK_RATE),
    .BD_ADC_CHANNEL_COUNT(BD_ADC_CHANNEL_COUNT),
    .BD_DAC_CHANNEL_COUNT(BD_DAC_CHANNEL_COUNT),
    .ADC_CHANNEL_DEBUG(ADC_CHANNEL_DEBUG),
    .LO_WIDTH(LO_WIDTH),
    .MAG_WIDTH(MAG_WIDTH),
    .PRODUCT_WIDTH(PRODUCT_WIDTH),
    .ACQ_WIDTH(ACQ_WIDTH),
    .SITE_SAMPLES_PER_TURN(SITE_SAMPLES_PER_TURN),
    .SITE_TURNS_PER_PT(SITE_TURNS_PER_PT),
    .SITE_CIC_FA_DECIMATE(SITE_CIC_FA_DECIMATE),
    .SITE_CIC_SA_DECIMATE(SITE_CIC_SA_DECIMATE),
    .SITE_CIC_STAGES(SITE_CIC_STAGES)
    )
    common_dsbpm_top_inst (
    .USER_MGT_SI570_CLK_P(USER_MGT_SI570_CLK_P),
    .USER_MGT_SI570_CLK_N(USER_MGT_SI570_CLK_N),
    .SFP2_RX_P(SFP2_RX_P),
    .SFP2_RX_N(SFP2_RX_N),
    .SFP2_TX_P(SFP2_TX_P),
    .SFP2_TX_N(SFP2_TX_N),
    .SFP2_TX_ENABLE(SFP2_TX_ENABLE),

    .FPGA_REFCLK_OUT_C_P(FPGA_REFCLK_OUT_C_P),
    .FPGA_REFCLK_OUT_C_N(FPGA_REFCLK_OUT_C_N),
    .SYSREF_FPGA_C_P(SYSREF_FPGA_C_P),
    .SYSREF_FPGA_C_N(SYSREF_FPGA_C_N),
    .SYSREF_RFSOC_C_P(SYSREF_RFSOC_C_P),
    .SYSREF_RFSOC_C_N(SYSREF_RFSOC_C_N),
    .RFMC_ADC_00_P(RFMC_ADC_00_P),
    .RFMC_ADC_00_N(RFMC_ADC_00_N),
    .RFMC_ADC_01_P(RFMC_ADC_01_P),
    .RFMC_ADC_01_N(RFMC_ADC_01_N),
    .RF1_CLKO_B_C_P(RF1_CLKO_B_C_P),
    .RF1_CLKO_B_C_N(RF1_CLKO_B_C_N),
    .RFMC_ADC_02_P(RFMC_ADC_02_P),
    .RFMC_ADC_02_N(RFMC_ADC_02_N),
    .RFMC_ADC_03_P(RFMC_ADC_03_P),
    .RFMC_ADC_03_N(RFMC_ADC_03_N),
    .RFMC_ADC_04_P(RFMC_ADC_04_P),
    .RFMC_ADC_04_N(RFMC_ADC_04_N),
    .RFMC_ADC_05_P(RFMC_ADC_05_P),
    .RFMC_ADC_05_N(RFMC_ADC_05_N),
    .RFMC_ADC_06_P(RFMC_ADC_06_P),
    .RFMC_ADC_06_N(RFMC_ADC_06_N),
    .RFMC_ADC_07_P(RFMC_ADC_07_P),
    .RFMC_ADC_07_N(RFMC_ADC_07_N),

    .RFMC_DAC_00_P(RFMC_DAC_00_P),
    .RFMC_DAC_00_N(RFMC_DAC_00_N),
    .RFMC_DAC_01_P(RFMC_DAC_01_P),
    .RFMC_DAC_01_N(RFMC_DAC_01_N),
    .RFMC_DAC_02_P(RFMC_DAC_02_P),
    .RFMC_DAC_02_N(RFMC_DAC_02_N),
    .RFMC_DAC_03_P(RFMC_DAC_03_P),
    .RFMC_DAC_03_N(RFMC_DAC_03_N),
    .RF4_CLKO_B_C_P(RF4_CLKO_B_C_P),
    .RF4_CLKO_B_C_N(RF4_CLKO_B_C_N),
    .RFMC_DAC_04_P(RFMC_DAC_04_P),
    .RFMC_DAC_04_N(RFMC_DAC_04_N),
    .RFMC_DAC_05_P(RFMC_DAC_05_P),
    .RFMC_DAC_05_N(RFMC_DAC_05_N),
    .RFMC_DAC_06_P(RFMC_DAC_06_P),
    .RFMC_DAC_06_N(RFMC_DAC_06_N),
    .RFMC_DAC_07_P(RFMC_DAC_07_P),
    .RFMC_DAC_07_N(RFMC_DAC_07_N),

    .SYS_CLK_C0_P(SYS_CLK_C0_P),
    .SYS_CLK_C0_N(SYS_CLK_C0_N),

    .DDR4_C0_ACT_N(DDR4_C0_ACT_N),
    .DDR4_C0_ADR(DDR4_C0_ADR),
    .DDR4_C0_BA(DDR4_C0_BA),
    .DDR4_C0_BG(DDR4_C0_BG),
    .DDR4_C0_CK_C(DDR4_C0_CK_C),
    .DDR4_C0_CK_T(DDR4_C0_CK_T),
    .DDR4_C0_CKE(DDR4_C0_CKE),
    .DDR4_C0_CS_N(DDR4_C0_CS_N),
    .DDR4_C0_DM_DBI_N(DDR4_C0_DM_DBI_N),
    .DDR4_C0_DQ(DDR4_C0_DQ),
    .DDR4_C0_DQS_C(DDR4_C0_DQS_C),
    .DDR4_C0_DQS_T(DDR4_C0_DQS_T),
    .DDR4_C0_ODT(DDR4_C0_ODT),
    .DDR4_C0_RESET_N(DDR4_C0_RESET_N),

    .SFP_REC_CLK_P(SFP_REC_CLK_P),
    .SFP_REC_CLK_N(SFP_REC_CLK_N),

    .EVR_FB_CLK(EVR_FB_CLK),
    .CLK104_SYNC_IN(CLK104_SYNC_IN),
    .EVR_SROC(EVR_SROC),

    .GPIO_SW_W(GPIO_SW_W),
    .GPIO_SW_E(GPIO_SW_E),
    .GPIO_SW_N(GPIO_SW_N),
    .DIP_SWITCH(DIP_SWITCH),
    .GPIO_LEDS(GPIO_LEDS),

    .AFE_SPI_CLK(AFE_SPI_CLK),
    .AFE_SPI_SDI(AFE_SPI_SDI),
    .AFE_SPI_LE(AFE_SPI_LE),

    .CLK_SPI_MUX_SEL0(CLK_SPI_MUX_SEL0),
    .CLK_SPI_MUX_SEL1(CLK_SPI_MUX_SEL1)
);

endmodule
