module common_dsbpm_top #(
    parameter TEST_BYPASS_RECORDERS     = "FALSE",
    parameter TEST_BYPASS_PRELIM_PROC   = "FALSE",
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
    parameter SITE_SAMPLES_PER_TURN     = 100,  // Max samples per turn
    parameter SITE_TURNS_PER_PT         = 19,   // 11/19 PT
    parameter SITE_CIC_FA_DECIMATE      = 100,  // Max FA decimation rate
    parameter SITE_CIC_SA_DECIMATE      = 2000, // Max SA decimation rate
    parameter SITE_CIC_STAGES           = 2) (
    input  USER_MGT_SI570_CLK_P, USER_MGT_SI570_CLK_N,
    input  IDT_8A34001_Q7_CLK_P, IDT_8A34001_Q7_CLK_N,
    input  IDT_8A34001_Q11_CLK_P, IDT_8A34001_Q11_CLK_N,

    input  [2:0] SFP_RX_P,
    input  [2:0] SFP_RX_N,
    output [2:0] SFP_TX_P,
    output [2:0] SFP_TX_N,

    output [2:0] SFP_TX_ENABLE,

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
    output wire EVR_HB,
    output wire EVR_HB_2,

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

//////////////////////////////////////////////////////////////////////////////
// Static outputs
assign SFP_TX_ENABLE[2] = 1'b1;
assign SFP_TX_ENABLE[1] = 1'b1;
assign SFP_TX_ENABLE[0] = 1'b1;

//////////////////////////////////////////////////////////////////////////////
// General-purpose I/O block
// Include file is machine generated from C header
`include "gpioIDX.v"
wire                    [31:0] GPIO_IN[0:GPIO_IDX_COUNT-1];
wire                    [31:0] GPIO_OUT;
wire      [GPIO_IDX_COUNT-1:0] GPIO_STROBES;
wire [(GPIO_IDX_COUNT*32)-1:0] GPIO_IN_FLATTENED;
genvar i;
generate
for (i = 0 ; i < GPIO_IDX_COUNT ; i = i + 1) begin : gpio_flatten
    assign GPIO_IN_FLATTENED[i*32+:32] = GPIO_IN[i];
end
endgenerate

`include "firmwareBuildDate.v"
assign GPIO_IN[GPIO_IDX_FIRMWARE_BUILD_DATE] = FIRMWARE_BUILD_DATE;
`include "gitHash.vh"
assign GPIO_IN[GPIO_IDX_GITHASH] = GIT_REV_32BIT;

//////////////////////////////////////////////////////////////////////////////
// Clocks
wire sysClk, evrClk, adcClk, dacClk;
wire adcClkLocked, dacClkLocked;
wire sysReset_n;

// Get USER MGT reference clock
// Configure ODIV2 to run at O/2.
wire USER_MGT_SI570_CLK, USER_MGT_SI570_CLK_O2;
IBUFDS_GTE4 #(.REFCLK_HROW_CK_SEL(2'b01))
  EVR_GTY_refclkBuf(.I(USER_MGT_SI570_CLK_P),
                              .IB(USER_MGT_SI570_CLK_N),
                              .CEB(1'b0),
                              .O(USER_MGT_SI570_CLK),
                              .ODIV2(USER_MGT_SI570_CLK_O2));
wire mgtRefClkMonitor;
BUFG_GT userMgtChkClkBuf (.O(mgtRefClkMonitor),
                          .CE(1'b1),
                          .CEMASK(1'b0),
                          .CLR(1'b0),
                          .CLRMASK(1'b0),
                          .DIV(3'd0),
                          .I(USER_MGT_SI570_CLK_O2));

// Get IDT_8A34001_Q7_CLK MGT reference clock
// Configure ODIV2 to run at O/2.
wire IDT_8A34001_Q7_CLK, IDT_8A34001_Q7_CLK_O2;
IBUFDS_GTE4 #(.REFCLK_HROW_CK_SEL(2'b01))
  EVR_GTY_gt129_refclk1Buf(.I(IDT_8A34001_Q7_CLK_P),
                              .IB(IDT_8A34001_Q7_CLK_N),
                              .CEB(1'b0),
                              .O(IDT_8A34001_Q7_CLK),
                              .ODIV2(IDT_8A34001_Q7_CLK_O2));
wire mgt129Refclk1Monitor;
BUFG_GT userMgt129Refclk1Buf (.O(mgt129Refclk1Monitor),
                          .CE(1'b1),
                          .CEMASK(1'b0),
                          .CLR(1'b0),
                          .CLRMASK(1'b0),
                          .DIV(3'd0),
                          .I(IDT_8A34001_Q7_CLK_O2));

// Get USER MGT reference clock
// Configure ODIV2 to run at O/2.
wire IDT_8A34001_Q11_CLK, IDT_8A34001_Q11_CLK_O2;
IBUFDS_GTE4 #(.REFCLK_HROW_CK_SEL(2'b01))
  EVR_GTY_gt128_refclk1Buf(.I(IDT_8A34001_Q11_CLK_P),
                              .IB(IDT_8A34001_Q11_CLK_N),
                              .CEB(1'b0),
                              .O(IDT_8A34001_Q11_CLK),
                              .ODIV2(IDT_8A34001_Q11_CLK_O2));
wire mgt128Refclk1Monitor;
BUFG_GT userMgt128Refclk1Buf (.O(mgt128Refclk1Monitor),
                          .CE(1'b1),
                          .CEMASK(1'b0),
                          .CLR(1'b0),
                          .CLRMASK(1'b0),
                          .DIV(3'd0),
                          .I(IDT_8A34001_Q11_CLK_O2));

//////////////////////////////////////////////////////////////////////////////
// Front panel controls
// Also provide on-board alternatives in case the front panel board is absent.
(*ASYNC_REG="TRUE"*) reg Reset_RecoveryModeSwitch_m, Reset_RecoveryModeSwitch;
(*ASYNC_REG="TRUE"*) reg DisplayModeSwitch_m, DisplayModeSwitch;
always @(posedge sysClk) begin
    Reset_RecoveryModeSwitch_m <= GPIO_SW_W;
    DisplayModeSwitch_m        <= GPIO_SW_E;
    Reset_RecoveryModeSwitch   <= Reset_RecoveryModeSwitch_m;
    DisplayModeSwitch          <= DisplayModeSwitch_m;
end

//////////////////////////////////////////////////////////////////////////////
// Timekeeping
clkIntervalCounters #(.CLK_RATE(SYSCLK_RATE))
  clkIntervalCounters (
    .clk(sysClk),
    .microsecondsSinceBoot(GPIO_IN[GPIO_IDX_MICROSECONDS_SINCE_BOOT]),
    .secondsSinceBoot(GPIO_IN[GPIO_IDX_SECONDS_SINCE_BOOT]));

/////////////////////////////////////////////////////////////////////////////
// Event receiver support
wire        evrRxSynchronized;
wire [15:0] evrChars;
wire  [1:0] evrCharIsK;
wire  [1:0] evrCharIsComma;
wire [63:0] evrTimestamp;

wire evrTxClk;
evrGTYwrapper #(.DEBUG("false"))
  evrGTYwrapper (
    .sysClk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_GTY_CSR]),
    .drpStrobe(GPIO_STROBES[GPIO_IDX_EVR_GTY_DRP]),
    .GPIO_OUT(GPIO_OUT),
    .csr(GPIO_IN[GPIO_IDX_GTY_CSR]),
    .drp(GPIO_IN[GPIO_IDX_EVR_GTY_DRP]),
    .refClk(USER_MGT_SI570_CLK),
    .evrTxClk(evrTxClk),
    .RX_N(SFP_RX_N[2]),
    .RX_P(SFP_RX_P[2]),
    .TX_N(SFP_TX_N[2]),
    .TX_P(SFP_TX_P[2]),
    .evrClk(evrClk),
    .evrRxSynchronized(evrRxSynchronized),
    .evrChars(evrChars),
    .evrCharIsK(evrCharIsK),
    .evrCharIsComma(evrCharIsComma));

// EVR triggers. Events 4 to 7 are reesrved for the user,
// and they are forwarded to other the waveform recorder
wire [7:0] evrTriggerBus;
wire evrHeartbeat = evrTriggerBus[0];
wire evrPulsePerSecond = evrTriggerBus[1];
wire evrSinglePass = evrTriggerBus[2];
wire evrHeartbeat2 = evrTriggerBus[3];
assign GPIO_LEDS[0] = evrHeartbeat;
assign GPIO_LEDS[1] = evrPulsePerSecond;

`ifndef SIMULATE
// Reference clock for RF ADC jitter cleaner
wire evrClkF;
ODDRE1 ODDRE1_EVR_CLK_F (
   .Q(evrClkF),
   .C(evrClk),
   .D1(1'b1),
   .D2(1'b0),
   .SR(1'b0)
);

OBUFDS #(
    .SLEW("FAST")
) OBUFDS_SFP_REC_CLK (
    .O(SFP_REC_CLK_P),
    .OB(SFP_REC_CLK_N),
    .I(evrClkF)
);

// Monitor reference clock
wire evrClkMon;
ODDRE1 ODDRE1_EVR_CLK_MON (
   .Q(evrClkMon),
   .C(evrClk),
   .D1(1'b1),
   .D2(1'b0),
   .SR(1'b0)
);

OBUF #(
    .SLEW("FAST")
) OBUF_EVR_FB_CLK (
    .O(EVR_FB_CLK),
    .I(evrClkMon)
);
`endif

// CLk104 SYNC in reference clock
assign CLK104_SYNC_IN = 1'b0;

// Check EVR markers
wire [31:0] evrSyncStatus;
wire evrSROCsynced;
wire evrSROCClk;
evrSROC #(.SYSCLK_FREQUENCY(SYSCLK_RATE),
          .DEBUG("false"))
  evrSROC(.sysClk(sysClk),
          .csrStrobe(GPIO_STROBES[GPIO_IDX_EVR_SYNC_CSR]),
          .GPIO_OUT(GPIO_OUT),
          .csr(evrSyncStatus),
          .evrClk(evrClk),
          .evrHeartbeatMarker(evrHeartbeat),
          .evrPulsePerSecondMarker(evrPulsePerSecond),
          .evrSROCsynced(evrSROCsynced),
          .evrSROC(evrSROCClk),
          .evrSROCstrobe());
assign GPIO_IN[GPIO_IDX_EVR_SYNC_CSR] = evrSyncStatus;
wire isHBvalid = evrSyncStatus[1];
wire isPPSvalid = evrSyncStatus[2];

OBUF #(
   .SLEW("FAST")
) OBUF_EVR_SROC (
   .O(EVR_SROC),
   .I(evrSROCClk)
);

OBUF #(
   .SLEW("FAST")
) OBUF_EVR_HB (
   .O(EVR_HB),
   .I(evrHeartbeat)
);

OBUF #(
   .SLEW("FAST")
) OBUF_EVR_HB_2 (
   .O(EVR_HB_2),
   .I(evrHeartbeat2)
);

// Debug counter synched with SROC
wire [31:0] adcSyncStatus;
wire adcSROCsynced;
wire adcSROCClk;
wire [31:0] adcCounterHB;
evrSROC #(.SYSCLK_FREQUENCY(SYSCLK_RATE),
          .DEBUG("false"))
  adcSROC(.sysClk(sysClk),
          .csrStrobe(GPIO_STROBES[GPIO_IDX_ADC_SYNC_CSR]),
          .GPIO_OUT(GPIO_OUT),
          .csr(adcSyncStatus),
          .evrClk(adcClk),
          .evrHeartbeatMarker(evrHeartbeat),
          .evrPulsePerSecondMarker(evrPulsePerSecond),
          .evrSROCsynced(adcSROCsynced),
          .evrSROC(adcSROCClk),
          .evrSROCstrobe(),
          .evrCounterHBDbg(adcCounterHB));
assign GPIO_IN[GPIO_IDX_ADC_SYNC_CSR] = adcSyncStatus;

/////////////////////////////////////////////////////////////////////////////
// Generate tile synchronization user_sysref_adc
wire FPGA_REFCLK_OUT_C;
wire FPGA_REFCLK_OUT_C_unbuf;
wire user_sysref_adc;
wire user_sysref_dac;

IBUFDS FPGA_REFCLK_IBUFDS(
    .I(FPGA_REFCLK_OUT_C_P),
    .IB(FPGA_REFCLK_OUT_C_N),
    .O(FPGA_REFCLK_OUT_C_unbuf)
);
BUFG FPGA_REFCLK_BUFG(
    .I(FPGA_REFCLK_OUT_C_unbuf),
    .O(FPGA_REFCLK_OUT_C)
);

wire SYSREF_FPGA_C_unbuf;
IBUFDS SYSREF_FPGA_IBUFDS(
    .I(SYSREF_FPGA_C_P),
    .IB(SYSREF_FPGA_C_N),
    .O(SYSREF_FPGA_C_unbuf)
);

sysrefSync #(
    .DEBUG("false"),
    .COUNTER_WIDTH(10)) // up to 1023 SYSREF periods
  sysrefSyncADC (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_SYSREF_ADC_CSR]),
    .GPIO_OUT(GPIO_OUT),
    .sysStatusReg(GPIO_IN[GPIO_IDX_SYSREF_ADC_CSR]),
    .FPGA_REFCLK_OUT_C(FPGA_REFCLK_OUT_C),
    .SYSREF_FPGA_C_UNBUF(SYSREF_FPGA_C_unbuf),
    .clk(adcClk),
    .user_sysref_resampled(user_sysref_adc));

sysrefSync #(
    .DEBUG("false"),
    .COUNTER_WIDTH(10)) // up to 1023 SYSREF periods
  sysrefSyncDAC (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_SYSREF_DAC_CSR]),
    .GPIO_OUT(GPIO_OUT),
    .sysStatusReg(GPIO_IN[GPIO_IDX_SYSREF_DAC_CSR]),
    .FPGA_REFCLK_OUT_C(FPGA_REFCLK_OUT_C),
    .SYSREF_FPGA_C_UNBUF(SYSREF_FPGA_C_unbuf),
    .clk(dacClk),
    .user_sysref_resampled(user_sysref_dac));

/////////////////////////////////////////////////////////////////////////////
// Monitor range of signals at ADC inputs
wire [(CFG_ADC_PHYSICAL_COUNT*AXI_ADC_SAMPLE_WIDTH)-1:0] adcsMagTDATA;
wire                    [CFG_DSBPM_COUNT-1:0] adcsMagTVALID;
wire                    [CFG_DSBPM_COUNT-1:0] adcsMagTCLK;
adcRangeCheck #(
    .AXI_CHANNEL_COUNT(CFG_ADC_PHYSICAL_COUNT),
    .AXI_SAMPLE_WIDTH(AXI_ADC_SAMPLE_WIDTH),
    .AXI_SAMPLES_PER_CLOCK(CFG_ADC_AXI_SAMPLES_PER_CLOCK),
    .ADC_WIDTH(AXI_ADC_SAMPLE_WIDTH))
  adcRangeCheck (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_ADC_RANGE_CSR]),
    .GPIO_OUT(GPIO_OUT),
    .sysReadout(GPIO_IN[GPIO_IDX_ADC_RANGE_CSR]),
    .adcClk(adcsMagTCLK[0]),
    .axiValid(adcsMagTVALID[0]),
    .axiData(adcsMagTDATA));

genvar dsbpm;
generate
for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin : adc_data
    assign adcsMagTDATA[dsbpm*4*AXI_ADC_SAMPLE_WIDTH+:4*AXI_ADC_SAMPLE_WIDTH] = {
        prelimProcADC3Mag[dsbpm],
        prelimProcADC2Mag[dsbpm],
        prelimProcADC1Mag[dsbpm],
        prelimProcADC0Mag[dsbpm]
    };
    assign adcsMagTVALID[dsbpm] = 1'b1;
    assign adcsMagTCLK[dsbpm] = adcClk;
end
endgenerate

//
// Forward the EVR trigger bus and time stamp to the ADC clock domain.
//
wire [63:0] adcTimestamp;
forwardData #(.DATA_WIDTH(64))
  forwardTimestampToADC(.inClk(evrClk),
             .inData(evrTimestamp),
             .outClk(adcClk),
             .outData(adcTimestamp));

(* mark_debug = "true" *) wire [7:0] adcTriggerBus;
forwardMultiCDC #(
    .DATA_WIDTH(8))
  forwardMultiCDCToADC (
    .dataIn(evrTriggerBus),
    .clk(adcClk),
    .dataOut(adcTriggerBus));

//
// Forward the EVR trigger bus and time stamp to the system clock domain.
//
wire [63:0] sysTimestamp;
forwardData #(.DATA_WIDTH(64))
  forwardTimestampToSys(.inClk(evrClk),
             .inData(evrTimestamp),
             .outClk(sysClk),
             .outData(sysTimestamp));

(* mark_debug = "true" *) wire [7:0] sysTriggerBus;
forwardMultiCDC #(
    .DATA_WIDTH(8))
  forwardMultiCDCToSys (
    .dataIn(evrTriggerBus),
    .clk(sysClk),
    .dataOut(sysTriggerBus));

//
// Forward the EVR trigger bus and time stamp to the DDR clock domain.
//
wire [63:0] ddrTimestamp;
forwardData #(.DATA_WIDTH(64))
  forwardTimestampToDDR(.inClk(evrClk),
             .inData(evrTimestamp),
             .outClk(ddr4_ui_clk),
             .outData(ddrTimestamp));

(* mark_debug = "true" *) wire [7:0] ddrTriggerBus;
forwardMultiCDC #(
    .DATA_WIDTH(8))
  forwardMultiCDCToDDR (
    .dataIn(evrTriggerBus),
    .clk(ddr4_ui_clk),
    .dataOut(ddrTriggerBus));

/////////////////////////////////////////////////////////////////////////////
// Measure clock rates
localparam FREQ_COUNTERS_NUM = 13;
localparam FREQ_SEL_WIDTH = $clog2(FREQ_COUNTERS_NUM+1);
reg  [FREQ_SEL_WIDTH-1:0] frequencyMonitorSelect;
wire [29:0] measuredFrequency;
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_FREQ_MONITOR_CSR]) begin
        frequencyMonitorSelect <= GPIO_OUT[FREQ_SEL_WIDTH-1:0];
    end
end
assign GPIO_IN[GPIO_IDX_FREQ_MONITOR_CSR] = { 2'b0, measuredFrequency };
wire rfdc_adc0_clk;
wire rfdc_dac0_clk;
freq_multi_count #(
        .NF(FREQ_COUNTERS_NUM),  // number of frequency counters in a block
        .NG(1),  // number of frequency counter blocks
        .gw(4),  // Gray counter width
        .cw(1),  // macro-cycle counter width
        .rw($clog2(SYSCLK_RATE*4/3)), // reference counter width
        .uw(30)) // unknown counter width
  frequencyCounters (
    .unk_clk({user_sysref_dac, user_sysref_adc,
              dacClk, rfdc_dac0_clk,
              mgt128Refclk1Monitor,
              mgt129Refclk1Monitor,
              mgtRefClkMonitor,
              FPGA_REFCLK_OUT_C, rfdc_adc0_clk,
              adcClk, evrTxClk,
              evrClk, sysClk}),
    .refclk(sysClk),
    .refMarker(isPPSvalid & evrPulsePerSecond),
    .addr(frequencyMonitorSelect),
    .frequency(measuredFrequency));

/////////////////////////////////////////////////////////////////////////////
// Miscellaneous
assign GPIO_IN[GPIO_IDX_USER_GPIO_CSR] = {
               Reset_RecoveryModeSwitch, DisplayModeSwitch, 5'b0, adcClkLocked,
               evrTriggerBus,
               8'b0,
               DIP_SWITCH }; // DFE Serial Number

//////////////////////////////////////////////////////////////////////////////
// Interlocks
reg interlockRelayControl = 0;
wire interlockResetButton = GPIO_SW_N;
wire interlockRelayOpen = 1'b0;
wire interlockRelayClosed = 1'b1;
assign GPIO_LEDS[7] = 1'b0;
assign GPIO_LEDS[6] = 1'b0;
assign GPIO_LEDS[5] = dacClkLocked;
assign GPIO_LEDS[4] = adcClkLocked;
assign GPIO_LEDS[3] = GPIO_IN[GPIO_IDX_SECONDS_SINCE_BOOT][1];
assign GPIO_LEDS[2] = GPIO_IN[GPIO_IDX_SECONDS_SINCE_BOOT][0];
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_INTERLOCK_CSR]) begin
        interlockRelayControl <= GPIO_OUT[0];
    end
end
assign GPIO_IN[GPIO_IDX_INTERLOCK_CSR] = { 28'b0, interlockRelayClosed,
                                                  interlockRelayOpen,
                                                  1'b0,
                                                  interlockResetButton };

/////////////////////////////////////////////////////////////////////////////
// Acquisition common
localparam ADC_SAMPLE_WIDTH    = CFG_ADC_AXI_SAMPLES_PER_CLOCK * AXI_ADC_SAMPLE_WIDTH;
localparam ACQ_ADC_SAMPLE_WIDTH = ACQ_WIDTH;

// I and Q interleaved
localparam AXIS_DAC_SAMPLE_WIDTH = CFG_DAC_AXI_SAMPLES_PER_CLOCK * DAC_SAMPLE_WIDTH;

// FIFO sizes
localparam ADC_FIFO_CAPACITY = 2048;
localparam DDC_FIFO_CAPACITY = 256;

//////////////////////////////////////////////////////////////////////////////
// Waveform recorders
//
// All waveform recorders share these burst parameters
wire  [1:0] BURST_TYPE_INCR = 2'b01;
wire  [3:0] CACHE_NORMAL_NONCACHE_BUFF = 4'b0011;

// ADC
wire   [AXI_ADDR_WIDTH-1:0]     wr_adc_axi_AWADDR[0:CFG_DSBPM_COUNT-1];
wire   [7:0]                    wr_adc_axi_AWLEN[0:CFG_DSBPM_COUNT-1];
wire                            wr_adc_axi_AWVALID[0:CFG_DSBPM_COUNT-1];
wire                            wr_adc_axi_AWREADY[0:CFG_DSBPM_COUNT-1];
wire   [2:0]                    wr_adc_axi_AWSIZE[0:CFG_DSBPM_COUNT-1];
wire   [AXI_ADC_DATA_WIDTH-1:0] wr_adc_axi_WDATA[0:CFG_DSBPM_COUNT-1];
wire                            wr_adc_axi_WLAST[0:CFG_DSBPM_COUNT-1];
wire                            wr_adc_axi_WVALID[0:CFG_DSBPM_COUNT-1];
wire   [AXI_ADC_DATA_WIDTH/8-1:0] wr_adc_axi_WSTRB[0:CFG_DSBPM_COUNT-1];
wire                            wr_adc_axi_WREADY[0:CFG_DSBPM_COUNT-1];
wire   [1:0]                    wr_adc_axi_BRESP[0:CFG_DSBPM_COUNT-1];
wire                            wr_adc_axi_BVALID[0:CFG_DSBPM_COUNT-1];

// TBT
wire   [AXI_ADDR_WIDTH-1:0]     wr_tbt_axi_AWADDR[0:CFG_DSBPM_COUNT-1];
wire   [7:0]                    wr_tbt_axi_AWLEN[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_axi_AWVALID[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_axi_AWREADY[0:CFG_DSBPM_COUNT-1];
wire   [2:0]                    wr_tbt_axi_AWSIZE[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH-1:0] wr_tbt_axi_WDATA[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_axi_WLAST[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_axi_WVALID[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH/8-1:0] wr_tbt_axi_WSTRB[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_axi_WREADY[0:CFG_DSBPM_COUNT-1];
wire   [1:0]                    wr_tbt_axi_BRESP[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_axi_BVALID[0:CFG_DSBPM_COUNT-1];

// FA
wire   [AXI_ADDR_WIDTH-1:0]     wr_fa_axi_AWADDR[0:CFG_DSBPM_COUNT-1];
wire   [7:0]                    wr_fa_axi_AWLEN[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_axi_AWVALID[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_axi_AWREADY[0:CFG_DSBPM_COUNT-1];
wire   [2:0]                    wr_fa_axi_AWSIZE[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH-1:0] wr_fa_axi_WDATA[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_axi_WLAST[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_axi_WVALID[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH/8-1:0] wr_fa_axi_WSTRB[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_axi_WREADY[0:CFG_DSBPM_COUNT-1];
wire   [1:0]                    wr_fa_axi_BRESP[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_axi_BVALID[0:CFG_DSBPM_COUNT-1];

// PL
wire   [AXI_ADDR_WIDTH-1:0]     wr_pl_axi_AWADDR[0:CFG_DSBPM_COUNT-1];
wire   [7:0]                    wr_pl_axi_AWLEN[0:CFG_DSBPM_COUNT-1];
wire                            wr_pl_axi_AWVALID[0:CFG_DSBPM_COUNT-1];
wire                            wr_pl_axi_AWREADY[0:CFG_DSBPM_COUNT-1];
wire   [2:0]                    wr_pl_axi_AWSIZE[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH-1:0] wr_pl_axi_WDATA[0:CFG_DSBPM_COUNT-1];
wire                            wr_pl_axi_WLAST[0:CFG_DSBPM_COUNT-1];
wire                            wr_pl_axi_WVALID[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH/8-1:0] wr_pl_axi_WSTRB[0:CFG_DSBPM_COUNT-1];
wire                            wr_pl_axi_WREADY[0:CFG_DSBPM_COUNT-1];
wire   [1:0]                    wr_pl_axi_BRESP[0:CFG_DSBPM_COUNT-1];
wire                            wr_pl_axi_BVALID[0:CFG_DSBPM_COUNT-1];

// PH
wire   [AXI_ADDR_WIDTH-1:0]     wr_ph_axi_AWADDR[0:CFG_DSBPM_COUNT-1];
wire   [7:0]                    wr_ph_axi_AWLEN[0:CFG_DSBPM_COUNT-1];
wire                            wr_ph_axi_AWVALID[0:CFG_DSBPM_COUNT-1];
wire                            wr_ph_axi_AWREADY[0:CFG_DSBPM_COUNT-1];
wire   [2:0]                    wr_ph_axi_AWSIZE[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH-1:0] wr_ph_axi_WDATA[0:CFG_DSBPM_COUNT-1];
wire                            wr_ph_axi_WLAST[0:CFG_DSBPM_COUNT-1];
wire                            wr_ph_axi_WVALID[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH/8-1:0] wr_ph_axi_WSTRB[0:CFG_DSBPM_COUNT-1];
wire                            wr_ph_axi_WREADY[0:CFG_DSBPM_COUNT-1];
wire   [1:0]                    wr_ph_axi_BRESP[0:CFG_DSBPM_COUNT-1];
wire                            wr_ph_axi_BVALID[0:CFG_DSBPM_COUNT-1];

// TBT Position
wire   [AXI_ADDR_WIDTH-1:0]     wr_tbt_pos_axi_AWADDR[0:CFG_DSBPM_COUNT-1];
wire   [7:0]                    wr_tbt_pos_axi_AWLEN[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_pos_axi_AWVALID[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_pos_axi_AWREADY[0:CFG_DSBPM_COUNT-1];
wire   [2:0]                    wr_tbt_pos_axi_AWSIZE[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH-1:0] wr_tbt_pos_axi_WDATA[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_pos_axi_WLAST[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_pos_axi_WVALID[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH/8-1:0] wr_tbt_pos_axi_WSTRB[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_pos_axi_WREADY[0:CFG_DSBPM_COUNT-1];
wire   [1:0]                    wr_tbt_pos_axi_BRESP[0:CFG_DSBPM_COUNT-1];
wire                            wr_tbt_pos_axi_BVALID[0:CFG_DSBPM_COUNT-1];

// FA Postion
wire   [AXI_ADDR_WIDTH-1:0]     wr_fa_pos_axi_AWADDR[0:CFG_DSBPM_COUNT-1];
wire   [7:0]                    wr_fa_pos_axi_AWLEN[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_pos_axi_AWVALID[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_pos_axi_AWREADY[0:CFG_DSBPM_COUNT-1];
wire   [2:0]                    wr_fa_pos_axi_AWSIZE[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH-1:0] wr_fa_pos_axi_WDATA[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_pos_axi_WLAST[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_pos_axi_WVALID[0:CFG_DSBPM_COUNT-1];
wire   [AXI_MAG_DATA_WIDTH/8-1:0] wr_fa_pos_axi_WSTRB[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_pos_axi_WREADY[0:CFG_DSBPM_COUNT-1];
wire   [1:0]                    wr_fa_pos_axi_BRESP[0:CFG_DSBPM_COUNT-1];
wire                            wr_fa_pos_axi_BVALID[0:CFG_DSBPM_COUNT-1];

(* mark_debug = "true" *) reg softTrigger[0:CFG_DSBPM_COUNT-1];
(* mark_debug = "true" *) wire adcLossOffBeamTrigger[0:CFG_DSBPM_COUNT-1];
(* mark_debug = "true" *) wire adcSoftTrigger[0:CFG_DSBPM_COUNT-1];
(* mark_debug = "true" *) wire ddrLossOffBeamTrigger[0:CFG_DSBPM_COUNT-1];
(* mark_debug = "true" *) wire ddrSoftTrigger[0:CFG_DSBPM_COUNT-1];

generate
if (TEST_BYPASS_RECORDERS != "TRUE" && TEST_BYPASS_RECORDERS != "FALSE") begin
    TEST_BYPASS_RECORDERS_only_TRUE_or_FALSE_SUPPORTED error();
end
endgenerate

generate
for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin : dram_recorders
    if (TEST_BYPASS_RECORDERS == "FALSE") begin

    //
    // Waveform recorder triggers
    // Stretch soft trigger to ensure it is seen across clock boundaries
    //
    reg [3:0] softTriggerStretch;
    always @(posedge sysClk) begin
        if (GPIO_STROBES[GPIO_IDX_WFR_SOFT_TRIGGER + dsbpm*GPIO_IDX_PER_DSBPM]) begin
            softTrigger[dsbpm] <= 1;
            softTriggerStretch <= ~0;
        end
        else if (softTriggerStretch) begin
            softTriggerStretch <= softTriggerStretch - 1;
        end
        else begin
            softTrigger[dsbpm] <= 0;
        end
    end

    forwardMultiCDC #(
        .DATA_WIDTH(2))
      forwardTriggersMultiCDCToADC(
        .dataIn({lossOfBeamTrigger[dsbpm], softTrigger[dsbpm]}),
        .clk(adcClk),
        .dataOut({adcLossOffBeamTrigger[dsbpm], adcSoftTrigger[dsbpm]}));

    forwardMultiCDC #(
        .DATA_WIDTH(2))
      forwardTriggersMultiCDCToToDDR(
        .dataIn({lossOfBeamTrigger[dsbpm], softTrigger[dsbpm]}),
        .clk(ddr4_ui_clk),
        .dataOut({ddrLossOffBeamTrigger[dsbpm], ddrSoftTrigger[dsbpm]}));

    wire [7:0] sysRecorderTriggerBus = { sysTriggerBus[7:4],
                                      1'b0,
                                      sysSingleTrig[dsbpm],
                                      lossOfBeamTrigger[dsbpm],
                                      softTrigger[dsbpm] };

    wire [7:0] adcRecorderTriggerBus = { adcTriggerBus[7:4],
                                      1'b0,
                                      adcSingleTrig[dsbpm],
                                      adcLossOffBeamTrigger[dsbpm],
                                      adcSoftTrigger[dsbpm] };

    //
    // ADC waveform recorder
    //
    wire [31:0] adcWfrCSR, adcWfrPretrigCount, adcWfrAcqCount, adcWfrAcqAddrMSB, adcWfrAcqAddrLSB;
    wire [63:0] adcWfrWhenTriggered;
    assign GPIO_IN[GPIO_IDX_ADC_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+0] = adcWfrCSR;
    assign GPIO_IN[GPIO_IDX_ADC_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+1] = adcWfrPretrigCount;
    assign GPIO_IN[GPIO_IDX_ADC_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+2] = adcWfrAcqCount;
    assign GPIO_IN[GPIO_IDX_ADC_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+3] = adcWfrAcqAddrLSB;
    assign GPIO_IN[GPIO_IDX_ADC_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+4] = adcWfrAcqAddrMSB;
    assign GPIO_IN[GPIO_IDX_ADC_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+5] = adcWfrWhenTriggered[63:32];
    assign GPIO_IN[GPIO_IDX_ADC_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+6] = adcWfrWhenTriggered[31:0];

    genericWaveformRecorder #(
        .HIGH_BANDWIDTH_MODE("TRUE"),
        .ACQ_CAPACITY(CFG_RECORDER_ADC_SAMPLE_CAPACITY),
        .DATA_WIDTH(8*AXI_ADC_SAMPLE_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(16*AXI_ADC_SAMPLE_WIDTH), // twice as large as input (DATA_WIDTH)
        .FIFO_CAPACITY(ADC_FIFO_CAPACITY),
        .CHIPSCOPE_DBG((dsbpm == 0)? "TRUE" : "FALSE"))
      adcWaveformRecorder(
        .sysClk(sysClk),
        .writeData(GPIO_OUT),
        .regStrobes(GPIO_STROBES[GPIO_IDX_ADC_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+:5]),
        .csr(adcWfrCSR),
        .pretrigCount(adcWfrPretrigCount),
        .acqCount(adcWfrAcqCount),
        .acqAddressMSB(adcWfrAcqAddrMSB),
        .acqAddressLSB(adcWfrAcqAddrLSB),
        .whenTriggered(adcWfrWhenTriggered),

        .clk(adcClk),
        .data({
            prelimProcADCQ3[dsbpm],
            prelimProcADC3[dsbpm],
            prelimProcADCQ2[dsbpm],
            prelimProcADC2[dsbpm],
            prelimProcADCQ1[dsbpm],
            prelimProcADC1[dsbpm],
            prelimProcADCQ0[dsbpm],
            prelimProcADC0[dsbpm]}),
        .testData({
            {prelimProcADCQ3[dsbpm][AXI_ADC_SAMPLE_WIDTH-1:1], adcUseThisSample[dsbpm]},
            {prelimProcADC3[dsbpm][AXI_ADC_SAMPLE_WIDTH-1:1], adcUseThisSample[dsbpm]},
            {prelimProcADCQ2[dsbpm][AXI_ADC_SAMPLE_WIDTH-1:1], adcTbtLoadAccumulator[dsbpm]},
            {prelimProcADC2[dsbpm][AXI_ADC_SAMPLE_WIDTH-1:1], adcTbtLoadAccumulator[dsbpm]},
            {prelimProcADCQ1[dsbpm][AXI_ADC_SAMPLE_WIDTH-1:1], adcTbtLatchAccumulator[dsbpm]},
            {prelimProcADC1[dsbpm][AXI_ADC_SAMPLE_WIDTH-1:1], adcTbtLatchAccumulator[dsbpm]},
            {prelimProcADCQ0[dsbpm][AXI_ADC_SAMPLE_WIDTH-1:1], adcMtLoadAndLatch[dsbpm]},
            {prelimProcADC0[dsbpm][AXI_ADC_SAMPLE_WIDTH-1:1], adcMtLoadAndLatch[dsbpm]}
            }),
        .valid(1'b1),
        .triggers(adcRecorderTriggerBus),
        .timestamp(adcTimestamp),

        .diagExtMode(1'b1),
        .diagExtData(adcCounterHB),

        .axi_AWADDR(wr_adc_axi_AWADDR[dsbpm]),
        .axi_AWLEN(wr_adc_axi_AWLEN[dsbpm]),
        .axi_AWVALID(wr_adc_axi_AWVALID[dsbpm]),
        .axi_AWREADY(wr_adc_axi_AWREADY[dsbpm]),
        .axi_AWSIZE(wr_adc_axi_AWSIZE[dsbpm]),
        .axi_WDATA(wr_adc_axi_WDATA[dsbpm]),
        .axi_WLAST(wr_adc_axi_WLAST[dsbpm]),
        .axi_WVALID(wr_adc_axi_WVALID[dsbpm]),
        .axi_WSTRB(wr_adc_axi_WSTRB[dsbpm]),
        .axi_WREADY(wr_adc_axi_WREADY[dsbpm]),
        .axi_BRESP(wr_adc_axi_BRESP[dsbpm]),
        .axi_BVALID(wr_adc_axi_BVALID[dsbpm]));

    ///////////////////////////////////////////////////////////////////////////////
    // Magnitude recorders
    ///////////////////////////////////////////////////////////////////////////////

    //
    // TbT waveform recorder
    //
    wire [31:0] tbtWfrCSR, tbtWfrPretrigCount, tbtWfrAcqCount, tbtWfrAcqAddrMSB, tbtWfrAcqAddrLSB;
    wire [63:0] tbtWfrWhenTriggered;
    assign GPIO_IN[GPIO_IDX_TBT_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+0] = tbtWfrCSR;
    assign GPIO_IN[GPIO_IDX_TBT_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+1] = tbtWfrPretrigCount;
    assign GPIO_IN[GPIO_IDX_TBT_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+2] = tbtWfrAcqCount;
    assign GPIO_IN[GPIO_IDX_TBT_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+3] = tbtWfrAcqAddrLSB;
    assign GPIO_IN[GPIO_IDX_TBT_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+4] = tbtWfrAcqAddrMSB;
    assign GPIO_IN[GPIO_IDX_TBT_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+5] = tbtWfrWhenTriggered[63:32];
    assign GPIO_IN[GPIO_IDX_TBT_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+6] = tbtWfrWhenTriggered[31:0];

    genericWaveformRecorder #(
        .ACQ_CAPACITY(CFG_RECORDER_TBT_SAMPLE_CAPACITY),
        .DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .FIFO_CAPACITY(DDC_FIFO_CAPACITY))
      tbtWaveformRecorder(
        .sysClk(sysClk),
        .writeData(GPIO_OUT),
        .regStrobes(GPIO_STROBES[GPIO_IDX_TBT_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+:5]),
        .csr(tbtWfrCSR),
        .pretrigCount(tbtWfrPretrigCount),
        .acqCount(tbtWfrAcqCount),
        .acqAddressMSB(tbtWfrAcqAddrMSB),
        .acqAddressLSB(tbtWfrAcqAddrLSB),
        .whenTriggered(tbtWfrWhenTriggered),

        .clk(sysClk),
        .data({
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcRfTbtMag3[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcRfTbtMag2[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcRfTbtMag1[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcRfTbtMag0[dsbpm]}),
        .testData(0),
        .valid(prelimProcRfTbtMagValid[dsbpm]),
        .triggers(sysRecorderTriggerBus),
        .timestamp(sysTimestamp),
        .diagExtMode(1'b0),
        .axi_AWADDR(wr_tbt_axi_AWADDR[dsbpm]),
        .axi_AWLEN(wr_tbt_axi_AWLEN[dsbpm]),
        .axi_AWVALID(wr_tbt_axi_AWVALID[dsbpm]),
        .axi_AWREADY(wr_tbt_axi_AWREADY[dsbpm]),
        .axi_AWSIZE(wr_tbt_axi_AWSIZE[dsbpm]),
        .axi_WDATA(wr_tbt_axi_WDATA[dsbpm]),
        .axi_WLAST(wr_tbt_axi_WLAST[dsbpm]),
        .axi_WVALID(wr_tbt_axi_WVALID[dsbpm]),
        .axi_WSTRB(wr_tbt_axi_WSTRB[dsbpm]),
        .axi_WREADY(wr_tbt_axi_WREADY[dsbpm]),
        .axi_BRESP(wr_tbt_axi_BRESP[dsbpm]),
        .axi_BVALID(wr_tbt_axi_BVALID[dsbpm]));

    //
    // FA waveform recorder
    //
    wire [31:0] faWfrCSR, faWfrPretrigCount, faWfrAcqCount, faWfrAcqAddrMSB, faWfrAcqAddrLSB;
    wire [63:0] faWfrWhenTriggered;
    assign GPIO_IN[GPIO_IDX_FA_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+0] = faWfrCSR;
    assign GPIO_IN[GPIO_IDX_FA_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+1] = faWfrPretrigCount;
    assign GPIO_IN[GPIO_IDX_FA_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+2] = faWfrAcqCount;
    assign GPIO_IN[GPIO_IDX_FA_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+3] = faWfrAcqAddrLSB;
    assign GPIO_IN[GPIO_IDX_FA_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+4] = faWfrAcqAddrMSB;
    assign GPIO_IN[GPIO_IDX_FA_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+5] = faWfrWhenTriggered[63:32];
    assign GPIO_IN[GPIO_IDX_FA_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+6] = faWfrWhenTriggered[31:0];

    genericWaveformRecorder #(
        .ACQ_CAPACITY(CFG_RECORDER_FA_SAMPLE_CAPACITY),
        .DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .FIFO_CAPACITY(DDC_FIFO_CAPACITY))
      faWaveformRecorder(
        .sysClk(sysClk),
        .writeData(GPIO_OUT),
        .regStrobes(GPIO_STROBES[GPIO_IDX_FA_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+:5]),
        .csr(faWfrCSR),
        .pretrigCount(faWfrPretrigCount),
        .acqCount(faWfrAcqCount),
        .acqAddressMSB(faWfrAcqAddrMSB),
        .acqAddressLSB(faWfrAcqAddrLSB),
        .whenTriggered(faWfrWhenTriggered),

        .clk(sysClk),
        .data({
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcRfFaMag3[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcRfFaMag2[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcRfFaMag1[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcRfFaMag0[dsbpm]}),
        .testData(0),
        .valid(prelimProcRfFaMagValid[dsbpm]),
        .triggers(sysRecorderTriggerBus),
        .timestamp(sysTimestamp),
        .diagExtMode(1'b0),
        .axi_AWADDR(wr_fa_axi_AWADDR[dsbpm]),
        .axi_AWLEN(wr_fa_axi_AWLEN[dsbpm]),
        .axi_AWVALID(wr_fa_axi_AWVALID[dsbpm]),
        .axi_AWREADY(wr_fa_axi_AWREADY[dsbpm]),
        .axi_AWSIZE(wr_fa_axi_AWSIZE[dsbpm]),
        .axi_WDATA(wr_fa_axi_WDATA[dsbpm]),
        .axi_WLAST(wr_fa_axi_WLAST[dsbpm]),
        .axi_WVALID(wr_fa_axi_WVALID[dsbpm]),
        .axi_WSTRB(wr_fa_axi_WSTRB[dsbpm]),
        .axi_WREADY(wr_fa_axi_WREADY[dsbpm]),
        .axi_BRESP(wr_fa_axi_BRESP[dsbpm]),
        .axi_BVALID(wr_fa_axi_BVALID[dsbpm]));

    //
    // Low pilot tone waveform recorder
    //
    wire [31:0] plWfrCSR, plWfrPretrigCount, plWfrAcqCount, plWfrAcqAddrMSB, plWfrAcqAddrLSB;
    wire [63:0] plWfrWhenTriggered;
    assign GPIO_IN[GPIO_IDX_PL_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+0] = plWfrCSR;
    assign GPIO_IN[GPIO_IDX_PL_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+1] = plWfrPretrigCount;
    assign GPIO_IN[GPIO_IDX_PL_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+2] = plWfrAcqCount;
    assign GPIO_IN[GPIO_IDX_PL_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+3] = plWfrAcqAddrLSB;
    assign GPIO_IN[GPIO_IDX_PL_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+4] = plWfrAcqAddrMSB;
    assign GPIO_IN[GPIO_IDX_PL_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+5] = plWfrWhenTriggered[63:32];
    assign GPIO_IN[GPIO_IDX_PL_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+6] = plWfrWhenTriggered[31:0];

    genericWaveformRecorder #(
        .ACQ_CAPACITY(CFG_RECORDER_PT_SAMPLE_CAPACITY),
        .DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .FIFO_CAPACITY(DDC_FIFO_CAPACITY))
      plWaveformRecorder(
        .sysClk(sysClk),
        .writeData(GPIO_OUT),
        .regStrobes(GPIO_STROBES[GPIO_IDX_PL_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+:5]),
        .csr(plWfrCSR),
        .pretrigCount(plWfrPretrigCount),
        .acqCount(plWfrAcqCount),
        .acqAddressMSB(plWfrAcqAddrMSB),
        .acqAddressLSB(plWfrAcqAddrLSB),
        .whenTriggered(plWfrWhenTriggered),

        .clk(sysClk),
        .data({
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcPlFaMag3[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcPlFaMag2[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcPlFaMag1[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcPlFaMag0[dsbpm]}),
        .testData(0),
        .valid(prelimProcPtFaValid[dsbpm]),
        .triggers(sysRecorderTriggerBus),
        .timestamp(sysTimestamp),
        .diagExtMode(1'b0),
        .axi_AWADDR(wr_pl_axi_AWADDR[dsbpm]),
        .axi_AWLEN(wr_pl_axi_AWLEN[dsbpm]),
        .axi_AWVALID(wr_pl_axi_AWVALID[dsbpm]),
        .axi_AWREADY(wr_pl_axi_AWREADY[dsbpm]),
        .axi_AWSIZE(wr_pl_axi_AWSIZE[dsbpm]),
        .axi_WDATA(wr_pl_axi_WDATA[dsbpm]),
        .axi_WLAST(wr_pl_axi_WLAST[dsbpm]),
        .axi_WVALID(wr_pl_axi_WVALID[dsbpm]),
        .axi_WSTRB(wr_pl_axi_WSTRB[dsbpm]),
        .axi_WREADY(wr_pl_axi_WREADY[dsbpm]),
        .axi_BRESP(wr_pl_axi_BRESP[dsbpm]),
        .axi_BVALID(wr_pl_axi_BVALID[dsbpm]));

    //
    // High pilot tone waveform recorder
    //
    wire [31:0] phWfrCSR, phWfrPretrigCount, phWfrAcqCount, phWfrAcqAddrMSB, phWfrAcqAddrLSB;
    wire [63:0] phWfrWhenTriggered;
    assign GPIO_IN[GPIO_IDX_PH_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+0] = phWfrCSR;
    assign GPIO_IN[GPIO_IDX_PH_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+1] = phWfrPretrigCount;
    assign GPIO_IN[GPIO_IDX_PH_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+2] = phWfrAcqCount;
    assign GPIO_IN[GPIO_IDX_PH_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+3] = phWfrAcqAddrLSB;
    assign GPIO_IN[GPIO_IDX_PH_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+4] = phWfrAcqAddrMSB;
    assign GPIO_IN[GPIO_IDX_PH_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+5] = phWfrWhenTriggered[63:32];
    assign GPIO_IN[GPIO_IDX_PH_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+6] = phWfrWhenTriggered[31:0];

    genericWaveformRecorder #(
        .ACQ_CAPACITY(CFG_RECORDER_PT_SAMPLE_CAPACITY),
        .DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .FIFO_CAPACITY(DDC_FIFO_CAPACITY))
      phWaveformRecorder(
        .sysClk(sysClk),
        .writeData(GPIO_OUT),
        .regStrobes(GPIO_STROBES[GPIO_IDX_PH_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+:5]),
        .csr(phWfrCSR),
        .pretrigCount(phWfrPretrigCount),
        .acqCount(phWfrAcqCount),
        .acqAddressMSB(phWfrAcqAddrMSB),
        .acqAddressLSB(phWfrAcqAddrLSB),
        .whenTriggered(phWfrWhenTriggered),

        .clk(sysClk),
        .data({
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcPhFaMag3[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcPhFaMag2[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcPhFaMag1[dsbpm],
            {ACQ_ADC_SAMPLE_WIDTH-MAG_WIDTH{1'b0}},
                                         prelimProcPhFaMag0[dsbpm]}),
        .testData(0),
        .valid(prelimProcPtFaValid[dsbpm]),
        .triggers(sysRecorderTriggerBus),
        .timestamp(sysTimestamp),
        .diagExtMode(1'b0),
        .axi_AWADDR(wr_ph_axi_AWADDR[dsbpm]),
        .axi_AWLEN(wr_ph_axi_AWLEN[dsbpm]),
        .axi_AWVALID(wr_ph_axi_AWVALID[dsbpm]),
        .axi_AWREADY(wr_ph_axi_AWREADY[dsbpm]),
        .axi_AWSIZE(wr_ph_axi_AWSIZE[dsbpm]),
        .axi_WDATA(wr_ph_axi_WDATA[dsbpm]),
        .axi_WLAST(wr_ph_axi_WLAST[dsbpm]),
        .axi_WVALID(wr_ph_axi_WVALID[dsbpm]),
        .axi_WSTRB(wr_ph_axi_WSTRB[dsbpm]),
        .axi_WREADY(wr_ph_axi_WREADY[dsbpm]),
        .axi_BRESP(wr_ph_axi_BRESP[dsbpm]),
        .axi_BVALID(wr_ph_axi_BVALID[dsbpm]));

    ///////////////////////////////////////////////////////////////////////////////
    // Position recorders
    ///////////////////////////////////////////////////////////////////////////////

    //
    // TbT position waveform recorder
    //
    wire [31:0] tbtPosWfrCSR, tbtPosWfrPretrigCount, tbtPosWfrAcqCount, tbtPosWfrAcqAddrMSB, tbtPosWfrAcqAddrLSB;
    wire [63:0] tbtPosWfrWhenTriggered;
    assign GPIO_IN[GPIO_IDX_TBT_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+0] = tbtPosWfrCSR;
    assign GPIO_IN[GPIO_IDX_TBT_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+1] = tbtPosWfrPretrigCount;
    assign GPIO_IN[GPIO_IDX_TBT_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+2] = tbtPosWfrAcqCount;
    assign GPIO_IN[GPIO_IDX_TBT_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+3] = tbtPosWfrAcqAddrLSB;
    assign GPIO_IN[GPIO_IDX_TBT_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+4] = tbtPosWfrAcqAddrMSB;
    assign GPIO_IN[GPIO_IDX_TBT_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+5] = tbtPosWfrWhenTriggered[63:32];
    assign GPIO_IN[GPIO_IDX_TBT_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+6] = tbtPosWfrWhenTriggered[31:0];

    genericWaveformRecorder #(
        .ACQ_CAPACITY(CFG_RECORDER_TBT_POS_SAMPLE_CAPACITY),
        .DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .FIFO_CAPACITY(DDC_FIFO_CAPACITY))
      tbtPosWaveformRecorder(
        .sysClk(sysClk),
        .writeData(GPIO_OUT),
        .regStrobes(GPIO_STROBES[GPIO_IDX_TBT_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+:5]),
        .csr(tbtPosWfrCSR),
        .pretrigCount(tbtPosWfrPretrigCount),
        .acqCount(tbtPosWfrAcqCount),
        .acqAddressMSB(tbtPosWfrAcqAddrMSB),
        .acqAddressLSB(tbtPosWfrAcqAddrLSB),
        .whenTriggered(tbtPosWfrWhenTriggered),

        .clk(sysClk),
        .data({
            positionCalcTbtS[dsbpm],
            positionCalcTbtQ[dsbpm],
            positionCalcTbtY[dsbpm],
            positionCalcTbtX[dsbpm]}),
        .testData(0),
        .valid(positionCalcTbtValid[dsbpm]),
        .triggers(sysRecorderTriggerBus),
        .timestamp(sysTimestamp),
        .diagExtMode(1'b0),
        .axi_AWADDR(wr_tbt_pos_axi_AWADDR[dsbpm]),
        .axi_AWLEN(wr_tbt_pos_axi_AWLEN[dsbpm]),
        .axi_AWVALID(wr_tbt_pos_axi_AWVALID[dsbpm]),
        .axi_AWREADY(wr_tbt_pos_axi_AWREADY[dsbpm]),
        .axi_AWSIZE(wr_tbt_pos_axi_AWSIZE[dsbpm]),
        .axi_WDATA(wr_tbt_pos_axi_WDATA[dsbpm]),
        .axi_WLAST(wr_tbt_pos_axi_WLAST[dsbpm]),
        .axi_WVALID(wr_tbt_pos_axi_WVALID[dsbpm]),
        .axi_WSTRB(wr_tbt_pos_axi_WSTRB[dsbpm]),
        .axi_WREADY(wr_tbt_pos_axi_WREADY[dsbpm]),
        .axi_BRESP(wr_tbt_pos_axi_BRESP[dsbpm]),
        .axi_BVALID(wr_tbt_pos_axi_BVALID[dsbpm]));

    //
    // FA position waveform recorder
    //

    wire [31:0] faPosWfrCSR, faPosWfrPretrigCount, faPosWfrAcqCount, faPosWfrAcqAddrMSB, faPosWfrAcqAddrLSB;
    wire [63:0] faPosWfrWhenTriggered;
    assign GPIO_IN[GPIO_IDX_FA_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+0] = faPosWfrCSR;
    assign GPIO_IN[GPIO_IDX_FA_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+1] = faPosWfrPretrigCount;
    assign GPIO_IN[GPIO_IDX_FA_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+2] = faPosWfrAcqCount;
    assign GPIO_IN[GPIO_IDX_FA_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+3] = faPosWfrAcqAddrLSB;
    assign GPIO_IN[GPIO_IDX_FA_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+4] = faPosWfrAcqAddrMSB;
    assign GPIO_IN[GPIO_IDX_FA_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+5] = faPosWfrWhenTriggered[63:32];
    assign GPIO_IN[GPIO_IDX_FA_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+6] = faPosWfrWhenTriggered[31:0];

    genericWaveformRecorder #(
        .ACQ_CAPACITY(CFG_RECORDER_FA_POS_SAMPLE_CAPACITY),
        .DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(4*ACQ_ADC_SAMPLE_WIDTH),
        .FIFO_CAPACITY(DDC_FIFO_CAPACITY))
      faPosWaveformRecorder(
        .sysClk(sysClk),
        .writeData(GPIO_OUT),
        .regStrobes(GPIO_STROBES[GPIO_IDX_FA_POS_RECORDER_BASE+(dsbpm*GPIO_IDX_RECORDER_PER_DSBPM)+:5]),
        .csr(faPosWfrCSR),
        .pretrigCount(faPosWfrPretrigCount),
        .acqCount(faPosWfrAcqCount),
        .acqAddressMSB(faPosWfrAcqAddrMSB),
        .acqAddressLSB(faPosWfrAcqAddrLSB),
        .whenTriggered(faPosWfrWhenTriggered),

        .clk(sysClk),
        .data({
            positionCalcFaS[dsbpm],
            positionCalcFaQ[dsbpm],
            positionCalcFaY[dsbpm],
            positionCalcFaX[dsbpm]}),
        .testData(0),
        .valid(positionCalcFaValid[dsbpm]),
        .triggers(sysRecorderTriggerBus),
        .timestamp(sysTimestamp),
        .diagExtMode(1'b0),
        .axi_AWADDR(wr_fa_pos_axi_AWADDR[dsbpm]),
        .axi_AWLEN(wr_fa_pos_axi_AWLEN[dsbpm]),
        .axi_AWVALID(wr_fa_pos_axi_AWVALID[dsbpm]),
        .axi_AWREADY(wr_fa_pos_axi_AWREADY[dsbpm]),
        .axi_AWSIZE(wr_fa_pos_axi_AWSIZE[dsbpm]),
        .axi_WDATA(wr_fa_pos_axi_WDATA[dsbpm]),
        .axi_WLAST(wr_fa_pos_axi_WLAST[dsbpm]),
        .axi_WVALID(wr_fa_pos_axi_WVALID[dsbpm]),
        .axi_WSTRB(wr_fa_pos_axi_WSTRB[dsbpm]),
        .axi_WREADY(wr_fa_pos_axi_WREADY[dsbpm]),
        .axi_BRESP(wr_fa_pos_axi_BRESP[dsbpm]),
        .axi_BVALID(wr_fa_pos_axi_BVALID[dsbpm]));

    end // if (TEST_BYPASS_RECORDERS == "FALSE") begin
end // for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1)
endgenerate

//////////////////////////////////////////////////////////////////////////////
wire [(BD_ADC_CHANNEL_COUNT*ADC_SAMPLE_WIDTH)-1:0] adcsTDATA;
wire                    [BD_ADC_CHANNEL_COUNT-1:0] adcsTVALID;

wire [(BD_DAC_CHANNEL_COUNT*AXIS_DAC_SAMPLE_WIDTH)-1:0] dacsTDATA;
wire                         [BD_DAC_CHANNEL_COUNT-1:0] dacsTVALID;
wire                         [BD_DAC_CHANNEL_COUNT-1:0] dacsTREADY;

// Make this a black box for simulation
`ifndef SIMULATE
wire ddr4_ui_clk;
wire ddr4_calib_complete;
wire ddr4_rst;

wire [1:0]      ddr_aximm_dbg_ARBURST;
wire [3:0]      ddr_aximm_dbg_ARCACHE;
wire [7:0]      ddr_aximm_dbg_ARLEN;
wire [0:0]      ddr_aximm_dbg_ARLOCK;
wire [2:0]      ddr_aximm_dbg_ARPROT;
wire [3:0]      ddr_aximm_dbg_ARQOS;
wire            ddr_aximm_dbg_ARREADY;
wire [2:0]      ddr_aximm_dbg_ARSIZE;
wire [15:0]     ddr_aximm_dbg_ARUSER;
wire            ddr_aximm_dbg_ARVALID;
wire [31:0]     ddr_aximm_dbg_AWADDR;
wire [1:0]      ddr_aximm_dbg_AWBURST;
wire [3:0]      ddr_aximm_dbg_AWCACHE;
wire [7:0]      ddr_aximm_dbg_AWLEN;
wire [0:0]      ddr_aximm_dbg_AWLOCK;
wire [2:0]      ddr_aximm_dbg_AWPROT;
wire [3:0]      ddr_aximm_dbg_AWQOS;
wire            ddr_aximm_dbg_AWREADY;
wire [2:0]      ddr_aximm_dbg_AWSIZE;
wire [15:0]     ddr_aximm_dbg_AWUSER;
wire            ddr_aximm_dbg_AWVALID;
wire            ddr_aximm_dbg_BREADY;
wire [1:0]      ddr_aximm_dbg_BRESP;
wire            ddr_aximm_dbg_BVALID;
wire [255:0]    ddr_aximm_dbg_RDATA;
wire            ddr_aximm_dbg_RLAST;
wire            ddr_aximm_dbg_RREADY;
wire [1:0]      ddr_aximm_dbg_RRESP;
wire            ddr_aximm_dbg_RVALID;
wire [255:0]    ddr_aximm_dbg_WDATA;
wire            ddr_aximm_dbg_WLAST;
wire            ddr_aximm_dbg_WREADY;
wire [31:0]     ddr_aximm_dbg_WSTRB;
wire            ddr_aximm_dbg_WVALID;

//////////////////////////////////////////////////////////////////////////////
// ZYNQ processor system

generate
if (TEST_BYPASS_RECORDERS == "FALSE") begin

system
  system_i (
    .sysClk(sysClk),
    .sysReset_n(sysReset_n),

    .GPIO_IN(GPIO_IN_FLATTENED),
    .GPIO_OUT(GPIO_OUT),
    .GPIO_STROBES(GPIO_STROBES),

    .evrCharIsComma(evrCharIsComma),
    .evrCharIsK(evrCharIsK),
    .evrClk(evrClk),
    .evrChars(evrChars),
    .evrMgtResetDone(evrRxSynchronized),
    .evrTriggerBus(evrTriggerBus),
    .evrTimestamp(evrTimestamp),

    .FPGA_REFCLK_OUT_C(FPGA_REFCLK_OUT_C),
    .adcClk(adcClk),
    .adcClkLocked(adcClkLocked),
    .clk_adc0_0(rfdc_adc0_clk),

    // ADC tile 225 distributes clock to all others
    //.adc01_clk_n(),
    //.adc01_clk_p(),
    .adc23_clk_n(RF1_CLKO_B_C_N),
    .adc23_clk_p(RF1_CLKO_B_C_P),
    //.adc45_clk_n(),
    //.adc45_clk_p(),
    //.adc67_clk_n(),
    //.adc67_clk_p(),
    .user_sysref_adc(user_sysref_adc),

    // DAC tile 0 must be enabled dfor sysref
    // to be distributed to ADC/DAC for RFSoC GEN3
    .sysref_in_diff_n(SYSREF_RFSOC_C_N),
    .sysref_in_diff_p(SYSREF_RFSOC_C_P),

    .dacClk(dacClk),
    .dacClkLocked(dacClkLocked),
    .clk_dac0_0(rfdc_dac0_clk),

    // DAC tile 230 distributes clock to all others
    .dac45_clk_n(RF4_CLKO_B_C_N),
    .dac45_clk_p(RF4_CLKO_B_C_P),
    .user_sysref_dac(user_sysref_dac),

    .vin0_v_n(RFMC_ADC_00_N),
    .vin0_v_p(RFMC_ADC_00_P),
    .vin1_v_n(RFMC_ADC_01_N),
    .vin1_v_p(RFMC_ADC_01_P),
    .vin2_v_n(RFMC_ADC_02_N),
    .vin2_v_p(RFMC_ADC_02_P),
    .vin3_v_n(RFMC_ADC_03_N),
    .vin3_v_p(RFMC_ADC_03_P),
    .vin4_v_n(RFMC_ADC_04_N),
    .vin4_v_p(RFMC_ADC_04_P),
    .vin5_v_n(RFMC_ADC_05_N),
    .vin5_v_p(RFMC_ADC_05_P),
    .vin6_v_n(RFMC_ADC_06_N),
    .vin6_v_p(RFMC_ADC_06_P),
    .vin7_v_n(RFMC_ADC_07_N),
    .vin7_v_p(RFMC_ADC_07_P),

    .adc0stream_tdata(adcsTDATA[0*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc1stream_tdata(adcsTDATA[2*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc2stream_tdata(adcsTDATA[4*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc3stream_tdata(adcsTDATA[6*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc4stream_tdata(adcsTDATA[8*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc5stream_tdata(adcsTDATA[10*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc6stream_tdata(adcsTDATA[12*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc7stream_tdata(adcsTDATA[14*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc0Qstream_tdata(adcsTDATA[1*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc1Qstream_tdata(adcsTDATA[3*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc2Qstream_tdata(adcsTDATA[5*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc3Qstream_tdata(adcsTDATA[7*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc4Qstream_tdata(adcsTDATA[9*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc5Qstream_tdata(adcsTDATA[11*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc6Qstream_tdata(adcsTDATA[13*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc7Qstream_tdata(adcsTDATA[15*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc0stream_tvalid(adcsTVALID[0]),
    .adc1stream_tvalid(adcsTVALID[2]),
    .adc2stream_tvalid(adcsTVALID[4]),
    .adc3stream_tvalid(adcsTVALID[6]),
    .adc4stream_tvalid(adcsTVALID[8]),
    .adc5stream_tvalid(adcsTVALID[10]),
    .adc6stream_tvalid(adcsTVALID[12]),
    .adc7stream_tvalid(adcsTVALID[14]),
    .adc0Qstream_tvalid(adcsTVALID[1]),
    .adc1Qstream_tvalid(adcsTVALID[3]),
    .adc2Qstream_tvalid(adcsTVALID[5]),
    .adc3Qstream_tvalid(adcsTVALID[7]),
    .adc4Qstream_tvalid(adcsTVALID[9]),
    .adc5Qstream_tvalid(adcsTVALID[11]),
    .adc6Qstream_tvalid(adcsTVALID[13]),
    .adc7Qstream_tvalid(adcsTVALID[15]),
    .adc0stream_tready(1'b1),
    .adc1stream_tready(1'b1),
    .adc2stream_tready(1'b1),
    .adc3stream_tready(1'b1),
    .adc4stream_tready(1'b1),
    .adc5stream_tready(1'b1),
    .adc6stream_tready(1'b1),
    .adc7stream_tready(1'b1),
    .adc0Qstream_tready(1'b1),
    .adc1Qstream_tready(1'b1),
    .adc2Qstream_tready(1'b1),
    .adc3Qstream_tready(1'b1),
    .adc4Qstream_tready(1'b1),
    .adc5Qstream_tready(1'b1),
    .adc6Qstream_tready(1'b1),
    .adc7Qstream_tready(1'b1),

    .dac0stream_tdata(dacsTDATA[0*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac1stream_tdata(dacsTDATA[1*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac2stream_tdata(dacsTDATA[2*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac3stream_tdata(dacsTDATA[3*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac4stream_tdata(dacsTDATA[4*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac5stream_tdata(dacsTDATA[5*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac6stream_tdata(dacsTDATA[6*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac7stream_tdata(dacsTDATA[7*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac0stream_tvalid(dacsTVALID[0]),
    .dac1stream_tvalid(dacsTVALID[1]),
    .dac2stream_tvalid(dacsTVALID[2]),
    .dac3stream_tvalid(dacsTVALID[3]),
    .dac4stream_tvalid(dacsTVALID[4]),
    .dac5stream_tvalid(dacsTVALID[5]),
    .dac6stream_tvalid(dacsTVALID[6]),
    .dac7stream_tvalid(dacsTVALID[7]),
    .dac0stream_tready(dacsTREADY[0]),
    .dac1stream_tready(dacsTREADY[1]),
    .dac2stream_tready(dacsTREADY[2]),
    .dac3stream_tready(dacsTREADY[3]),
    .dac4stream_tready(dacsTREADY[4]),
    .dac5stream_tready(dacsTREADY[5]),
    .dac6stream_tready(dacsTREADY[6]),
    .dac7stream_tready(dacsTREADY[7]),

    .vout0_v_n(RFMC_DAC_00_N),
    .vout0_v_p(RFMC_DAC_00_P),
    .vout1_v_n(RFMC_DAC_01_N),
    .vout1_v_p(RFMC_DAC_01_P),
    .vout2_v_n(RFMC_DAC_02_N),
    .vout2_v_p(RFMC_DAC_02_P),
    .vout3_v_n(RFMC_DAC_03_N),
    .vout3_v_p(RFMC_DAC_03_P),
    .vout4_v_n(RFMC_DAC_04_N),
    .vout4_v_p(RFMC_DAC_04_P),
    .vout5_v_n(RFMC_DAC_05_N),
    .vout5_v_p(RFMC_DAC_05_P),
    .vout6_v_n(RFMC_DAC_06_N),
    .vout6_v_p(RFMC_DAC_06_P),
    .vout7_v_n(RFMC_DAC_07_N),
    .vout7_v_p(RFMC_DAC_07_P),

    // DDR
    .sys_clk_300mhz_clk_n(SYS_CLK_C0_N),
    .sys_clk_300mhz_clk_p(SYS_CLK_C0_P),
    .sys_rst(1'b0),

    .ddr4_sdram_act_n(DDR4_C0_ACT_N),
    .ddr4_sdram_adr(DDR4_C0_ADR),
    .ddr4_sdram_ba(DDR4_C0_BA),
    .ddr4_sdram_bg(DDR4_C0_BG),
    .ddr4_sdram_ck_c(DDR4_C0_CK_C),
    .ddr4_sdram_ck_t(DDR4_C0_CK_T),
    .ddr4_sdram_cke(DDR4_C0_CKE),
    .ddr4_sdram_cs_n(DDR4_C0_CS_N),
    .ddr4_sdram_dm_n(DDR4_C0_DM_DBI_N),
    .ddr4_sdram_dq(DDR4_C0_DQ),
    .ddr4_sdram_dqs_c(DDR4_C0_DQS_C),
    .ddr4_sdram_dqs_t(DDR4_C0_DQS_T),
    .ddr4_sdram_odt(DDR4_C0_ODT),
    .ddr4_sdram_reset_n(DDR4_C0_RESET_N),

    .ddr4_ui_clk(ddr4_ui_clk),
    .ddr4_calib_complete(ddr4_calib_complete),
    .ddr4_rst(ddr4_rst),

    /////////////////////////////////////////////
    // DSBPM 0
    ////////////////////////////////////////////

    // ADC recorder
    .wr_adc_0_axi_awaddr(wr_adc_axi_AWADDR[0]),
    .wr_adc_0_axi_awburst(BURST_TYPE_INCR),
    .wr_adc_0_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_adc_0_axi_awlen(wr_adc_axi_AWLEN[0]),
    .wr_adc_0_axi_awready(wr_adc_axi_AWREADY[0]),
    .wr_adc_0_axi_awsize(wr_adc_axi_AWSIZE[0]),
    .wr_adc_0_axi_awvalid(wr_adc_axi_AWVALID[0]),
    .wr_adc_0_axi_bready(1'b1),
    .wr_adc_0_axi_bresp(wr_adc_axi_BRESP[0]),
    .wr_adc_0_axi_bvalid(wr_adc_axi_BVALID[0]),
    .wr_adc_0_axi_wdata(wr_adc_axi_WDATA[0]),
    .wr_adc_0_axi_wlast(wr_adc_axi_WLAST[0]),
    .wr_adc_0_axi_wready(wr_adc_axi_WREADY[0]),
    .wr_adc_0_axi_wstrb(wr_adc_axi_WSTRB[0]),
    .wr_adc_0_axi_wvalid(wr_adc_axi_WVALID[0]),

    // TbT recorder
    .wr_tbt_0_axi_awaddr(wr_tbt_axi_AWADDR[0]),
    .wr_tbt_0_axi_awburst(BURST_TYPE_INCR),
    .wr_tbt_0_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_tbt_0_axi_awlen(wr_tbt_axi_AWLEN[0]),
    .wr_tbt_0_axi_awready(wr_tbt_axi_AWREADY[0]),
    .wr_tbt_0_axi_awsize(wr_tbt_axi_AWSIZE[0]),
    .wr_tbt_0_axi_awvalid(wr_tbt_axi_AWVALID[0]),
    .wr_tbt_0_axi_bready(1'b1),
    .wr_tbt_0_axi_bresp(wr_tbt_axi_BRESP[0]),
    .wr_tbt_0_axi_bvalid(wr_tbt_axi_BVALID[0]),
    .wr_tbt_0_axi_wdata(wr_tbt_axi_WDATA[0]),
    .wr_tbt_0_axi_wlast(wr_tbt_axi_WLAST[0]),
    .wr_tbt_0_axi_wready(wr_tbt_axi_WREADY[0]),
    .wr_tbt_0_axi_wstrb(wr_tbt_axi_WSTRB[0]),
    .wr_tbt_0_axi_wvalid(wr_tbt_axi_WVALID[0]),

    // FA recorder
    .wr_fa_0_axi_awaddr(wr_fa_axi_AWADDR[0]),
    .wr_fa_0_axi_awburst(BURST_TYPE_INCR),
    .wr_fa_0_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_fa_0_axi_awlen(wr_fa_axi_AWLEN[0]),
    .wr_fa_0_axi_awready(wr_fa_axi_AWREADY[0]),
    .wr_fa_0_axi_awsize(wr_fa_axi_AWSIZE[0]),
    .wr_fa_0_axi_awvalid(wr_fa_axi_AWVALID[0]),
    .wr_fa_0_axi_bready(1'b1),
    .wr_fa_0_axi_bresp(wr_fa_axi_BRESP[0]),
    .wr_fa_0_axi_bvalid(wr_fa_axi_BVALID[0]),
    .wr_fa_0_axi_wdata(wr_fa_axi_WDATA[0]),
    .wr_fa_0_axi_wlast(wr_fa_axi_WLAST[0]),
    .wr_fa_0_axi_wready(wr_fa_axi_WREADY[0]),
    .wr_fa_0_axi_wstrb(wr_fa_axi_WSTRB[0]),
    .wr_fa_0_axi_wvalid(wr_fa_axi_WVALID[0]),

    // PL recorder
    .wr_pl_0_axi_awaddr(wr_pl_axi_AWADDR[0]),
    .wr_pl_0_axi_awburst(BURST_TYPE_INCR),
    .wr_pl_0_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_pl_0_axi_awlen(wr_pl_axi_AWLEN[0]),
    .wr_pl_0_axi_awready(wr_pl_axi_AWREADY[0]),
    .wr_pl_0_axi_awsize(wr_pl_axi_AWSIZE[0]),
    .wr_pl_0_axi_awvalid(wr_pl_axi_AWVALID[0]),
    .wr_pl_0_axi_bready(1'b1),
    .wr_pl_0_axi_bresp(wr_pl_axi_BRESP[0]),
    .wr_pl_0_axi_bvalid(wr_pl_axi_BVALID[0]),
    .wr_pl_0_axi_wdata(wr_pl_axi_WDATA[0]),
    .wr_pl_0_axi_wlast(wr_pl_axi_WLAST[0]),
    .wr_pl_0_axi_wready(wr_pl_axi_WREADY[0]),
    .wr_pl_0_axi_wstrb(wr_pl_axi_WSTRB[0]),
    .wr_pl_0_axi_wvalid(wr_pl_axi_WVALID[0]),

    // PH recorder
    .wr_ph_0_axi_awaddr(wr_ph_axi_AWADDR[0]),
    .wr_ph_0_axi_awburst(BURST_TYPE_INCR),
    .wr_ph_0_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_ph_0_axi_awlen(wr_ph_axi_AWLEN[0]),
    .wr_ph_0_axi_awready(wr_ph_axi_AWREADY[0]),
    .wr_ph_0_axi_awsize(wr_ph_axi_AWSIZE[0]),
    .wr_ph_0_axi_awvalid(wr_ph_axi_AWVALID[0]),
    .wr_ph_0_axi_bready(1'b1),
    .wr_ph_0_axi_bresp(wr_ph_axi_BRESP[0]),
    .wr_ph_0_axi_bvalid(wr_ph_axi_BVALID[0]),
    .wr_ph_0_axi_wdata(wr_ph_axi_WDATA[0]),
    .wr_ph_0_axi_wlast(wr_ph_axi_WLAST[0]),
    .wr_ph_0_axi_wready(wr_ph_axi_WREADY[0]),
    .wr_ph_0_axi_wstrb(wr_ph_axi_WSTRB[0]),
    .wr_ph_0_axi_wvalid(wr_ph_axi_WVALID[0]),

    // TbT position recorder
    .wr_tbt_pos_0_axi_awaddr(wr_tbt_pos_axi_AWADDR[0]),
    .wr_tbt_pos_0_axi_awburst(BURST_TYPE_INCR),
    .wr_tbt_pos_0_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_tbt_pos_0_axi_awlen(wr_tbt_pos_axi_AWLEN[0]),
    .wr_tbt_pos_0_axi_awready(wr_tbt_pos_axi_AWREADY[0]),
    .wr_tbt_pos_0_axi_awsize(wr_tbt_pos_axi_AWSIZE[0]),
    .wr_tbt_pos_0_axi_awvalid(wr_tbt_pos_axi_AWVALID[0]),
    .wr_tbt_pos_0_axi_bready(1'b1),
    .wr_tbt_pos_0_axi_bresp(wr_tbt_pos_axi_BRESP[0]),
    .wr_tbt_pos_0_axi_bvalid(wr_tbt_pos_axi_BVALID[0]),
    .wr_tbt_pos_0_axi_wdata(wr_tbt_pos_axi_WDATA[0]),
    .wr_tbt_pos_0_axi_wlast(wr_tbt_pos_axi_WLAST[0]),
    .wr_tbt_pos_0_axi_wready(wr_tbt_pos_axi_WREADY[0]),
    .wr_tbt_pos_0_axi_wstrb(wr_tbt_pos_axi_WSTRB[0]),
    .wr_tbt_pos_0_axi_wvalid(wr_tbt_pos_axi_WVALID[0]),

    // FA position recorder
    .wr_fa_pos_0_axi_awaddr(wr_fa_pos_axi_AWADDR[0]),
    .wr_fa_pos_0_axi_awburst(BURST_TYPE_INCR),
    .wr_fa_pos_0_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_fa_pos_0_axi_awlen(wr_fa_pos_axi_AWLEN[0]),
    .wr_fa_pos_0_axi_awready(wr_fa_pos_axi_AWREADY[0]),
    .wr_fa_pos_0_axi_awsize(wr_fa_pos_axi_AWSIZE[0]),
    .wr_fa_pos_0_axi_awvalid(wr_fa_pos_axi_AWVALID[0]),
    .wr_fa_pos_0_axi_bready(1'b1),
    .wr_fa_pos_0_axi_bresp(wr_fa_pos_axi_BRESP[0]),
    .wr_fa_pos_0_axi_bvalid(wr_fa_pos_axi_BVALID[0]),
    .wr_fa_pos_0_axi_wdata(wr_fa_pos_axi_WDATA[0]),
    .wr_fa_pos_0_axi_wlast(wr_fa_pos_axi_WLAST[0]),
    .wr_fa_pos_0_axi_wready(wr_fa_pos_axi_WREADY[0]),
    .wr_fa_pos_0_axi_wstrb(wr_fa_pos_axi_WSTRB[0]),
    .wr_fa_pos_0_axi_wvalid(wr_fa_pos_axi_WVALID[0]),

    /////////////////////////////////////////////
    // DSBPM 1
    ////////////////////////////////////////////

    // ADC recorder
    .wr_adc_1_axi_awaddr(wr_adc_axi_AWADDR[1]),
    .wr_adc_1_axi_awburst(BURST_TYPE_INCR),
    .wr_adc_1_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_adc_1_axi_awlen(wr_adc_axi_AWLEN[1]),
    .wr_adc_1_axi_awready(wr_adc_axi_AWREADY[1]),
    .wr_adc_1_axi_awsize(wr_adc_axi_AWSIZE[1]),
    .wr_adc_1_axi_awvalid(wr_adc_axi_AWVALID[1]),
    .wr_adc_1_axi_bready(1'b1),
    .wr_adc_1_axi_bresp(wr_adc_axi_BRESP[1]),
    .wr_adc_1_axi_bvalid(wr_adc_axi_BVALID[1]),
    .wr_adc_1_axi_wdata(wr_adc_axi_WDATA[1]),
    .wr_adc_1_axi_wlast(wr_adc_axi_WLAST[1]),
    .wr_adc_1_axi_wready(wr_adc_axi_WREADY[1]),
    .wr_adc_1_axi_wstrb(wr_adc_axi_WSTRB[1]),
    .wr_adc_1_axi_wvalid(wr_adc_axi_WVALID[1]),

    // TbT recorder
    .wr_tbt_1_axi_awaddr(wr_tbt_axi_AWADDR[1]),
    .wr_tbt_1_axi_awburst(BURST_TYPE_INCR),
    .wr_tbt_1_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_tbt_1_axi_awlen(wr_tbt_axi_AWLEN[1]),
    .wr_tbt_1_axi_awready(wr_tbt_axi_AWREADY[1]),
    .wr_tbt_1_axi_awsize(wr_tbt_axi_AWSIZE[1]),
    .wr_tbt_1_axi_awvalid(wr_tbt_axi_AWVALID[1]),
    .wr_tbt_1_axi_bready(1'b1),
    .wr_tbt_1_axi_bresp(wr_tbt_axi_BRESP[1]),
    .wr_tbt_1_axi_bvalid(wr_tbt_axi_BVALID[1]),
    .wr_tbt_1_axi_wdata(wr_tbt_axi_WDATA[1]),
    .wr_tbt_1_axi_wlast(wr_tbt_axi_WLAST[1]),
    .wr_tbt_1_axi_wready(wr_tbt_axi_WREADY[1]),
    .wr_tbt_1_axi_wstrb(wr_tbt_axi_WSTRB[1]),
    .wr_tbt_1_axi_wvalid(wr_tbt_axi_WVALID[1]),

    // FA recorder
    .wr_fa_1_axi_awaddr(wr_fa_axi_AWADDR[1]),
    .wr_fa_1_axi_awburst(BURST_TYPE_INCR),
    .wr_fa_1_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_fa_1_axi_awlen(wr_fa_axi_AWLEN[1]),
    .wr_fa_1_axi_awready(wr_fa_axi_AWREADY[1]),
    .wr_fa_1_axi_awsize(wr_fa_axi_AWSIZE[1]),
    .wr_fa_1_axi_awvalid(wr_fa_axi_AWVALID[1]),
    .wr_fa_1_axi_bready(1'b1),
    .wr_fa_1_axi_bresp(wr_fa_axi_BRESP[1]),
    .wr_fa_1_axi_bvalid(wr_fa_axi_BVALID[1]),
    .wr_fa_1_axi_wdata(wr_fa_axi_WDATA[1]),
    .wr_fa_1_axi_wlast(wr_fa_axi_WLAST[1]),
    .wr_fa_1_axi_wready(wr_fa_axi_WREADY[1]),
    .wr_fa_1_axi_wstrb(wr_fa_axi_WSTRB[1]),
    .wr_fa_1_axi_wvalid(wr_fa_axi_WVALID[1]),

    // PL recorder
    .wr_pl_1_axi_awaddr(wr_pl_axi_AWADDR[1]),
    .wr_pl_1_axi_awburst(BURST_TYPE_INCR),
    .wr_pl_1_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_pl_1_axi_awlen(wr_pl_axi_AWLEN[1]),
    .wr_pl_1_axi_awready(wr_pl_axi_AWREADY[1]),
    .wr_pl_1_axi_awsize(wr_pl_axi_AWSIZE[1]),
    .wr_pl_1_axi_awvalid(wr_pl_axi_AWVALID[1]),
    .wr_pl_1_axi_bready(1'b1),
    .wr_pl_1_axi_bresp(wr_pl_axi_BRESP[1]),
    .wr_pl_1_axi_bvalid(wr_pl_axi_BVALID[1]),
    .wr_pl_1_axi_wdata(wr_pl_axi_WDATA[1]),
    .wr_pl_1_axi_wlast(wr_pl_axi_WLAST[1]),
    .wr_pl_1_axi_wready(wr_pl_axi_WREADY[1]),
    .wr_pl_1_axi_wstrb(wr_pl_axi_WSTRB[1]),
    .wr_pl_1_axi_wvalid(wr_pl_axi_WVALID[1]),

    // PH recorder
    .wr_ph_1_axi_awaddr(wr_ph_axi_AWADDR[1]),
    .wr_ph_1_axi_awburst(BURST_TYPE_INCR),
    .wr_ph_1_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_ph_1_axi_awlen(wr_ph_axi_AWLEN[1]),
    .wr_ph_1_axi_awready(wr_ph_axi_AWREADY[1]),
    .wr_ph_1_axi_awsize(wr_ph_axi_AWSIZE[1]),
    .wr_ph_1_axi_awvalid(wr_ph_axi_AWVALID[1]),
    .wr_ph_1_axi_bready(1'b1),
    .wr_ph_1_axi_bresp(wr_ph_axi_BRESP[1]),
    .wr_ph_1_axi_bvalid(wr_ph_axi_BVALID[1]),
    .wr_ph_1_axi_wdata(wr_ph_axi_WDATA[1]),
    .wr_ph_1_axi_wlast(wr_ph_axi_WLAST[1]),
    .wr_ph_1_axi_wready(wr_ph_axi_WREADY[1]),
    .wr_ph_1_axi_wstrb(wr_ph_axi_WSTRB[1]),
    .wr_ph_1_axi_wvalid(wr_ph_axi_WVALID[1]),

    // TbT position recorder
    .wr_tbt_pos_1_axi_awaddr(wr_tbt_pos_axi_AWADDR[1]),
    .wr_tbt_pos_1_axi_awburst(BURST_TYPE_INCR),
    .wr_tbt_pos_1_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_tbt_pos_1_axi_awlen(wr_tbt_pos_axi_AWLEN[1]),
    .wr_tbt_pos_1_axi_awready(wr_tbt_pos_axi_AWREADY[1]),
    .wr_tbt_pos_1_axi_awsize(wr_tbt_pos_axi_AWSIZE[1]),
    .wr_tbt_pos_1_axi_awvalid(wr_tbt_pos_axi_AWVALID[1]),
    .wr_tbt_pos_1_axi_bready(1'b1),
    .wr_tbt_pos_1_axi_bresp(wr_tbt_pos_axi_BRESP[1]),
    .wr_tbt_pos_1_axi_bvalid(wr_tbt_pos_axi_BVALID[1]),
    .wr_tbt_pos_1_axi_wdata(wr_tbt_pos_axi_WDATA[1]),
    .wr_tbt_pos_1_axi_wlast(wr_tbt_pos_axi_WLAST[1]),
    .wr_tbt_pos_1_axi_wready(wr_tbt_pos_axi_WREADY[1]),
    .wr_tbt_pos_1_axi_wstrb(wr_tbt_pos_axi_WSTRB[1]),
    .wr_tbt_pos_1_axi_wvalid(wr_tbt_pos_axi_WVALID[1]),

    // FA position recorder
    .wr_fa_pos_1_axi_awaddr(wr_fa_pos_axi_AWADDR[1]),
    .wr_fa_pos_1_axi_awburst(BURST_TYPE_INCR),
    .wr_fa_pos_1_axi_awcache(CACHE_NORMAL_NONCACHE_BUFF),
    .wr_fa_pos_1_axi_awlen(wr_fa_pos_axi_AWLEN[1]),
    .wr_fa_pos_1_axi_awready(wr_fa_pos_axi_AWREADY[1]),
    .wr_fa_pos_1_axi_awsize(wr_fa_pos_axi_AWSIZE[1]),
    .wr_fa_pos_1_axi_awvalid(wr_fa_pos_axi_AWVALID[1]),
    .wr_fa_pos_1_axi_bready(1'b1),
    .wr_fa_pos_1_axi_bresp(wr_fa_pos_axi_BRESP[1]),
    .wr_fa_pos_1_axi_bvalid(wr_fa_pos_axi_BVALID[1]),
    .wr_fa_pos_1_axi_wdata(wr_fa_pos_axi_WDATA[1]),
    .wr_fa_pos_1_axi_wlast(wr_fa_pos_axi_WLAST[1]),
    .wr_fa_pos_1_axi_wready(wr_fa_pos_axi_WREADY[1]),
    .wr_fa_pos_1_axi_wstrb(wr_fa_pos_axi_WSTRB[1]),
    .wr_fa_pos_1_axi_wvalid(wr_fa_pos_axi_WVALID[1]),

    // debug from AXISM to DDR core
    .ddr_aximm_dbg_araddr(ddr_aximm_dbg_ARADDR),
    .ddr_aximm_dbg_arburst(ddr_aximm_dbg_ARBURST),
    .ddr_aximm_dbg_arcache(ddr_aximm_dbg_ARCACHE),
    .ddr_aximm_dbg_arlen(ddr_aximm_dbg_ARLEN),
    .ddr_aximm_dbg_arlock(ddr_aximm_dbg_ARLOCK),
    .ddr_aximm_dbg_arprot(ddr_aximm_dbg_ARPROT),
    .ddr_aximm_dbg_arqos(ddr_aximm_dbg_ARQOS),
    .ddr_aximm_dbg_arready(ddr_aximm_dbg_ARREADY),
    .ddr_aximm_dbg_arsize(ddr_aximm_dbg_ARSIZE),
    .ddr_aximm_dbg_aruser(ddr_aximm_dbg_ARUSER),
    .ddr_aximm_dbg_arvalid(ddr_aximm_dbg_ARVALID),
    .ddr_aximm_dbg_awaddr(ddr_aximm_dbg_AWADDR),
    .ddr_aximm_dbg_awburst(ddr_aximm_dbg_AWBURST),
    .ddr_aximm_dbg_awcache(ddr_aximm_dbg_AWCACHE),
    .ddr_aximm_dbg_awlen(ddr_aximm_dbg_AWLEN),
    .ddr_aximm_dbg_awlock(ddr_aximm_dbg_AWLOCK),
    .ddr_aximm_dbg_awprot(ddr_aximm_dbg_AWPROT),
    .ddr_aximm_dbg_awqos(ddr_aximm_dbg_AWQOS),
    .ddr_aximm_dbg_awready(ddr_aximm_dbg_AWREADY),
    .ddr_aximm_dbg_awsize(ddr_aximm_dbg_AWSIZE),
    .ddr_aximm_dbg_awuser(ddr_aximm_dbg_AWUSER),
    .ddr_aximm_dbg_awvalid(ddr_aximm_dbg_AWVALID),
    .ddr_aximm_dbg_bready(ddr_aximm_dbg_BREADY),
    .ddr_aximm_dbg_bresp(ddr_aximm_dbg_BRESP),
    .ddr_aximm_dbg_bvalid(ddr_aximm_dbg_BVALID),
    .ddr_aximm_dbg_rdata(ddr_aximm_dbg_RDATA),
    .ddr_aximm_dbg_rlast(ddr_aximm_dbg_RLAST),
    .ddr_aximm_dbg_rready(ddr_aximm_dbg_RREADY),
    .ddr_aximm_dbg_rresp(ddr_aximm_dbg_RRESP),
    .ddr_aximm_dbg_rvalid(ddr_aximm_dbg_RVALID),
    .ddr_aximm_dbg_wdata(ddr_aximm_dbg_WDATA),
    .ddr_aximm_dbg_wlast(ddr_aximm_dbg_WLAST),
    .ddr_aximm_dbg_wready(ddr_aximm_dbg_WREADY),
    .ddr_aximm_dbg_wstrb(ddr_aximm_dbg_WSTRB),
    .ddr_aximm_dbg_wvalid(ddr_aximm_dbg_WVALID)
    );

end
else begin

system
  system_i (
    .sysClk(sysClk),
    .sysReset_n(sysReset_n),

    .GPIO_IN(GPIO_IN_FLATTENED),
    .GPIO_OUT(GPIO_OUT),
    .GPIO_STROBES(GPIO_STROBES),

    .evrCharIsComma(evrCharIsComma),
    .evrCharIsK(evrCharIsK),
    .evrClk(evrClk),
    .evrChars(evrChars),
    .evrMgtResetDone(evrRxSynchronized),
    .evrTriggerBus(evrTriggerBus),
    .evrTimestamp(evrTimestamp),

    .FPGA_REFCLK_OUT_C(FPGA_REFCLK_OUT_C),
    .adcClk(adcClk),
    .adcClkLocked(adcClkLocked),
    .clk_adc0_0(rfdc_adc0_clk),

    // ADC tile 225 distributes clock to all others
    //.adc01_clk_n(),
    //.adc01_clk_p(),
    .adc23_clk_n(RF1_CLKO_B_C_N),
    .adc23_clk_p(RF1_CLKO_B_C_P),
    //.adc45_clk_n(),
    //.adc45_clk_p(),
    //.adc67_clk_n(),
    //.adc67_clk_p(),
    .user_sysref_adc(user_sysref_adc),

    // DAC tile 0 must be enabled dfor sysref
    // to be distributed to ADC/DAC for RFSoC GEN3
    .sysref_in_diff_n(SYSREF_RFSOC_C_N),
    .sysref_in_diff_p(SYSREF_RFSOC_C_P),

    .dacClk(dacClk),
    .dacClkLocked(dacClkLocked),
    .clk_dac0_0(rfdc_dac0_clk),

    // DAC tile 230 distributes clock to all others
    .dac45_clk_n(RF4_CLKO_B_C_N),
    .dac45_clk_p(RF4_CLKO_B_C_P),
    .user_sysref_dac(user_sysref_dac),

    .vin0_v_n(RFMC_ADC_00_N),
    .vin0_v_p(RFMC_ADC_00_P),
    .vin1_v_n(RFMC_ADC_01_N),
    .vin1_v_p(RFMC_ADC_01_P),
    .vin2_v_n(RFMC_ADC_02_N),
    .vin2_v_p(RFMC_ADC_02_P),
    .vin3_v_n(RFMC_ADC_03_N),
    .vin3_v_p(RFMC_ADC_03_P),
    .vin4_v_n(RFMC_ADC_04_N),
    .vin4_v_p(RFMC_ADC_04_P),
    .vin5_v_n(RFMC_ADC_05_N),
    .vin5_v_p(RFMC_ADC_05_P),
    .vin6_v_n(RFMC_ADC_06_N),
    .vin6_v_p(RFMC_ADC_06_P),
    .vin7_v_n(RFMC_ADC_07_N),
    .vin7_v_p(RFMC_ADC_07_P),

    .adc0stream_tdata(adcsTDATA[0*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc1stream_tdata(adcsTDATA[2*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc2stream_tdata(adcsTDATA[4*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc3stream_tdata(adcsTDATA[6*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc4stream_tdata(adcsTDATA[8*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc5stream_tdata(adcsTDATA[10*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc6stream_tdata(adcsTDATA[12*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc7stream_tdata(adcsTDATA[14*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc0Qstream_tdata(adcsTDATA[1*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc1Qstream_tdata(adcsTDATA[3*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc2Qstream_tdata(adcsTDATA[5*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc3Qstream_tdata(adcsTDATA[7*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc4Qstream_tdata(adcsTDATA[9*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc5Qstream_tdata(adcsTDATA[11*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc6Qstream_tdata(adcsTDATA[13*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc7Qstream_tdata(adcsTDATA[15*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),
    .adc0stream_tvalid(adcsTVALID[0]),
    .adc1stream_tvalid(adcsTVALID[2]),
    .adc2stream_tvalid(adcsTVALID[4]),
    .adc3stream_tvalid(adcsTVALID[6]),
    .adc4stream_tvalid(adcsTVALID[8]),
    .adc5stream_tvalid(adcsTVALID[10]),
    .adc6stream_tvalid(adcsTVALID[12]),
    .adc7stream_tvalid(adcsTVALID[14]),
    .adc0Qstream_tvalid(adcsTVALID[1]),
    .adc1Qstream_tvalid(adcsTVALID[3]),
    .adc2Qstream_tvalid(adcsTVALID[5]),
    .adc3Qstream_tvalid(adcsTVALID[7]),
    .adc4Qstream_tvalid(adcsTVALID[9]),
    .adc5Qstream_tvalid(adcsTVALID[11]),
    .adc6Qstream_tvalid(adcsTVALID[13]),
    .adc7Qstream_tvalid(adcsTVALID[15]),
    .adc0stream_tready(1'b1),
    .adc1stream_tready(1'b1),
    .adc2stream_tready(1'b1),
    .adc3stream_tready(1'b1),
    .adc4stream_tready(1'b1),
    .adc5stream_tready(1'b1),
    .adc6stream_tready(1'b1),
    .adc7stream_tready(1'b1),
    .adc0Qstream_tready(1'b1),
    .adc1Qstream_tready(1'b1),
    .adc2Qstream_tready(1'b1),
    .adc3Qstream_tready(1'b1),
    .adc4Qstream_tready(1'b1),
    .adc5Qstream_tready(1'b1),
    .adc6Qstream_tready(1'b1),
    .adc7Qstream_tready(1'b1),

    .dac0stream_tdata(dacsTDATA[0*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac1stream_tdata(dacsTDATA[1*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac2stream_tdata(dacsTDATA[2*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac3stream_tdata(dacsTDATA[3*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac4stream_tdata(dacsTDATA[4*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac5stream_tdata(dacsTDATA[5*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac6stream_tdata(dacsTDATA[6*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac7stream_tdata(dacsTDATA[7*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .dac0stream_tvalid(dacsTVALID[0]),
    .dac1stream_tvalid(dacsTVALID[1]),
    .dac2stream_tvalid(dacsTVALID[2]),
    .dac3stream_tvalid(dacsTVALID[3]),
    .dac4stream_tvalid(dacsTVALID[4]),
    .dac5stream_tvalid(dacsTVALID[5]),
    .dac6stream_tvalid(dacsTVALID[6]),
    .dac7stream_tvalid(dacsTVALID[7]),
    .dac0stream_tready(dacsTREADY[0]),
    .dac1stream_tready(dacsTREADY[1]),
    .dac2stream_tready(dacsTREADY[2]),
    .dac3stream_tready(dacsTREADY[3]),
    .dac4stream_tready(dacsTREADY[4]),
    .dac5stream_tready(dacsTREADY[5]),
    .dac6stream_tready(dacsTREADY[6]),
    .dac7stream_tready(dacsTREADY[7]),

    .vout0_v_n(RFMC_DAC_00_N),
    .vout0_v_p(RFMC_DAC_00_P),
    .vout1_v_n(RFMC_DAC_01_N),
    .vout1_v_p(RFMC_DAC_01_P),
    .vout2_v_n(RFMC_DAC_02_N),
    .vout2_v_p(RFMC_DAC_02_P),
    .vout3_v_n(RFMC_DAC_03_N),
    .vout3_v_p(RFMC_DAC_03_P),
    .vout4_v_n(RFMC_DAC_04_N),
    .vout4_v_p(RFMC_DAC_04_P),
    .vout5_v_n(RFMC_DAC_05_N),
    .vout5_v_p(RFMC_DAC_05_P),
    .vout6_v_n(RFMC_DAC_06_N),
    .vout6_v_p(RFMC_DAC_06_P),
    .vout7_v_n(RFMC_DAC_07_N),
    .vout7_v_p(RFMC_DAC_07_P)
    );

    assign DDR4_C0_ACT_N = 1'b1;
    assign DDR4_C0_ADR = 0;
    assign DDR4_C0_BA = 0;
    assign DDR4_C0_BG = 0;

    OBUFDS ddr4_c0_ck_obufds (
        .O(DDR4_C0_CK_T),
        .OB(DDR4_C0_CK_C),
        .I(1'b0)
    );

    assign DDR4_C0_CKE = 1'b0;
    assign DDR4_C0_CS_N = {2{1'b1}};

    assign DDR4_C0_DM_DBI_N = {4{1'bz}};
    assign DDR4_C0_DQ = {32{1'bz}};

    for(i = 0; i < 4; i = i + 1) begin

        OBUFTDS ddr4_c0_dqs_obuftds (
            .O(DDR4_C0_DQS_T[i]),
            .OB(DDR4_C0_DQS_C[i]),
            .I(1'b0),
            .T(1'b1) // High-Z
        );

    end

    assign DDR4_C0_ODT = 1'b0;
    assign DDR4_C0_RESET_N = 1'b1;

end // if (TEST_BYPASS_RECORDERS == "FALSE") begin
endgenerate

generate
if (DDR_ILA_CHIPSCOPE_DBG != "TRUE" && DDR_ILA_CHIPSCOPE_DBG != "FALSE") begin
    DDR_ILA_CHIPSCOPE_DBG_only_TRUE_or_FALSE_SUPPORTED();
end
endgenerate

generate
if (DDR_ILA_CHIPSCOPE_DBG == "TRUE") begin

wire [255:0] ddr_probe;
ila_td256_s4096_cap ddr_ila_td256_s4096_cap_inst (
    .clk(ddr4_ui_clk),
    .probe0(ddr_probe)
);

assign ddr_probe[0]       = ddr_aximm_dbg_WVALID;
assign ddr_probe[1]       = ddr_aximm_dbg_WLAST;
assign ddr_probe[2]       = ddr_aximm_dbg_WREADY;
assign ddr_probe[3]       = ddr_aximm_dbg_AWVALID;
assign ddr_probe[4]       = ddr_aximm_dbg_AWREADY;
assign ddr_probe[5]       = ddrSoftTrigger[0];
assign ddr_probe[9:6]     = ddrTriggerBus[7:4];

assign ddr_probe[32+:8]   = ddr_aximm_dbg_AWLEN;
assign ddr_probe[64+:32]  = ddr_aximm_dbg_AWADDR;

assign ddr_probe[128+:32] = ddr_aximm_dbg_WDATA[0+:32];
assign ddr_probe[160+:32] = ddr_aximm_dbg_WDATA[32+:32];
assign ddr_probe[192+:32] = ddr_aximm_dbg_WDATA[64+:32];
assign ddr_probe[224+:32] = ddr_aximm_dbg_WDATA[96+:32];

end // end if
endgenerate

`endif // `ifndef SIMULATE

//
// Create slow (SA) and fast (FA) acquistion triggers
// based on event system trigger 0 (heartbeat).
//
wire evrFaMarker, evrSaMarker;
wire [31:0] sysFAstatus, sysSAstatus;
wire evrFaSynced, evrSaSynced;
acqSync acqSync(
    .sysClk(sysClk),
    .sysGPIO_OUT(GPIO_OUT),
    .sysFAstrobe(GPIO_STROBES[GPIO_IDX_EVR_FA_RELOAD]),
    .sysSAstrobe(GPIO_STROBES[GPIO_IDX_EVR_SA_RELOAD]),
    .sysFAstatus(sysFAstatus),
    .sysSAstatus(sysSAstatus),
    .evrClk(evrClk),
    .evrHeartbeat(evrHeartbeat),
    .evrFaMarker(evrFaMarker),
    .evrSaMarker(evrSaMarker));
assign GPIO_IN[GPIO_IDX_EVR_FA_RELOAD] = sysFAstatus;
assign GPIO_IN[GPIO_IDX_EVR_SA_RELOAD] = sysSAstatus;
assign evrFaSynced = sysFAstatus[31];
assign evrSaSynced = sysSAstatus[31];

//
// Preliminary processing (compute magnitude of ADC signals)
//
wire adcUseThisSample[0:CFG_DSBPM_COUNT-1];
wire adcExceedsThreshold[0:CFG_DSBPM_COUNT-1];
wire adcSingleTrig [0:CFG_DSBPM_COUNT-1];
wire sysSingleTrig [0:CFG_DSBPM_COUNT-1];
wire [32-MAG_WIDTH-1:0] magPAD = 0;
wire                 adcLoSynced[0:CFG_DSBPM_COUNT-1];
wire                 adcTbtLoadAccumulator[0:CFG_DSBPM_COUNT-1];
wire                 adcTbtLatchAccumulator[0:CFG_DSBPM_COUNT-1];
wire                 adcMtLoadAndLatch[0:CFG_DSBPM_COUNT-1];

wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADC0[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADC1[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADC2[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADC3[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADCQ0[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADCQ1[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADCQ2[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADCQ3[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADC0Mag[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADC1Mag[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADC2Mag[0:CFG_DSBPM_COUNT-1];
wire [AXI_ADC_SAMPLE_WIDTH-1:0] prelimProcADC3Mag[0:CFG_DSBPM_COUNT-1];

wire                 prelimProcADCValid[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcTbtToggle[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcRfTbtMagValid[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfTbtMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfTbtMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfTbtMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfTbtMag3[0:CFG_DSBPM_COUNT-1];

wire                 prelimProcRfFaToggle[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcRfFaMagValid[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfFaMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfFaMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfFaMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfFaMag3[0:CFG_DSBPM_COUNT-1];

wire                 prelimProcRfCicFaMagValid[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfCicFaMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfCicFaMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfCicFaMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfCicFaMag3[0:CFG_DSBPM_COUNT-1];

wire                 prelimProcRfSaToggle[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcRfSaValid[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfSaMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfSaMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfSaMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfSaMag3[0:CFG_DSBPM_COUNT-1];

wire                 prelimProcPtFaToggle[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcPtFaValid[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlFaMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlFaMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlFaMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlFaMag3[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhFaMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhFaMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhFaMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhFaMag3[0:CFG_DSBPM_COUNT-1];

wire                 prelimProcPtSaToggle[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcPtSaValid[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlSaMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlSaMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlSaMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlSaMag3[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhSaMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhSaMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhSaMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhSaMag3[0:CFG_DSBPM_COUNT-1];

wire [8*PRODUCT_WIDTH-1:0] rfProducts[0:CFG_DSBPM_COUNT-1];
wire [8*PRODUCT_WIDTH-1:0] plProducts[0:CFG_DSBPM_COUNT-1];
wire [8*PRODUCT_WIDTH-1:0] phProducts[0:CFG_DSBPM_COUNT-1];

wire [LO_WIDTH-1:0] rfLOcos[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] rfLOsin[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] plLOcos[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] plLOsin[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] phLOcos[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] phLOsin[0:CFG_DSBPM_COUNT-1];

wire prelimProcOverflow[0:CFG_DSBPM_COUNT-1];

wire [8*MAG_WIDTH-1:0] tbtSums[0:CFG_DSBPM_COUNT-1];
wire tbtSumsValid[0:CFG_DSBPM_COUNT-1];
wire [4*MAG_WIDTH-1:0] tbtMags[0:CFG_DSBPM_COUNT-1];
wire tbtMagsValid[0:CFG_DSBPM_COUNT-1];

generate
if (IQ_DATA != "TRUE") begin
    IQ_DATA_false_NOT_SUPPORTED error();
end
endgenerate

localparam ADC_SIGNALS_PER_DSP = CFG_ADC_CHANNEL_COUNT / CFG_DSBPM_COUNT;
localparam DAC_SIGNAL_OFFSET_PER_DSP = CFG_DAC_CHANNEL_COUNT / CFG_DSBPM_COUNT;

generate
if (TEST_BYPASS_PRELIM_PROC != "TRUE" && TEST_BYPASS_PRELIM_PROC != "FALSE") begin
    TEST_BYPASS_PRELIM_PROC_only_TRUE_or_FALSE_SUPPORTED error();
end
endgenerate


generate
for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin : prelim_chain
    if (TEST_BYPASS_PRELIM_PROC == "FALSE") begin

    wire [(BD_ADC_CHANNEL_COUNT*ADC_SAMPLE_WIDTH)-1:0] adcsProcTDATA;
    wire                                            adcsProcTVALID;

    adcProcessing #(
        // because we are using DDC, the ADC samples are 16-bits, even though
        // the ADC is 14-bits
        .ADC_WIDTH(AXI_ADC_SAMPLE_WIDTH),
        .DATA_WIDTH(AXI_ADC_SAMPLE_WIDTH))
      adcProcessing (
        .sysClk(sysClk),
        .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_ADC_PROCESSING + dsbpm*GPIO_IDX_PER_DSBPM]),
        .GPIO_OUT(GPIO_OUT),
        .sysReadout(GPIO_IN[GPIO_IDX_ADC_PROCESSING + dsbpm*GPIO_IDX_PER_DSBPM]),

        .adcClk(adcClk),
        .adcValidIn(adcsTVALID[dsbpm*ADC_SIGNALS_PER_DSP]),
        .adc0In(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 0)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),  // I0
        .adc1In(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 2)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),  // I1
        .adc2In(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 4)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),  // I2
        .adc3In(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 6)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),  // I3
        .adc0QIn(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 1)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q0
        .adc1QIn(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 3)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q1
        .adc2QIn(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 5)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q2
        .adc3QIn(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 7)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q3

        .adcValidOut(adcsProcTVALID),
        .adc0Out(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 0)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),  // I0
        .adc1Out(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 2)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),  // I1
        .adc2Out(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 4)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),  // I2
        .adc3Out(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 6)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]),  // I3
        .adc0QOut(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 1)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q0
        .adc1QOut(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 3)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q1
        .adc2QOut(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 5)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q2
        .adc3QOut(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 7)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q3

        .adcUseThisSample(adcUseThisSample[dsbpm]),
        .adcExceedsThreshold(adcExceedsThreshold[dsbpm]));

    assign GPIO_IN[GPIO_IDX_PRELIM_STATUS + dsbpm*GPIO_IDX_PER_DSBPM] = {
        {32-1{1'b0}},
        prelimProcOverflow[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_RF_MAG_0 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcRfSaMag0[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_RF_MAG_1 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcRfSaMag1[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_RF_MAG_2 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcRfSaMag2[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_RF_MAG_3 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcRfSaMag3[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_PT_LO_MAG_0 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcPlSaMag0[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_PT_LO_MAG_1 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcPlSaMag1[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_PT_LO_MAG_2 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcPlSaMag2[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_PT_LO_MAG_3 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcPlSaMag3[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_PT_HI_MAG_0 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcPhSaMag0[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_PT_HI_MAG_1 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcPhSaMag1[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_PT_HI_MAG_2 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcPhSaMag2[dsbpm] };
    assign GPIO_IN[GPIO_IDX_PRELIM_PT_HI_MAG_3 + dsbpm*GPIO_IDX_PER_DSBPM] = {
        magPAD, prelimProcPhSaMag3[dsbpm] };
    preliminaryProcessing #(.CHIPSCOPE_DBG("FALSE"),
                            .SYSCLK_RATE(SYSCLK_RATE),
                            .ADC_WIDTH(AXI_ADC_SAMPLE_WIDTH),
                            .MAG_WIDTH(MAG_WIDTH),
                            .IQ_DATA(IQ_DATA),
                            .SAMPLES_PER_TURN(SITE_SAMPLES_PER_TURN),
                            .LO_WIDTH(LO_WIDTH),
                            .TURNS_PER_PT(SITE_TURNS_PER_PT),
                            .CIC_STAGES(SITE_CIC_STAGES),
                            .CIC_FA_DECIMATE(SITE_CIC_FA_DECIMATE),
                            .CIC_SA_DECIMATE(SITE_CIC_SA_DECIMATE),
                            .GPIO_LO_RF_ROW_CAPACITY(CFG_LO_RF_ROW_CAPACITY),
                            .GPIO_LO_PT_ROW_CAPACITY(CFG_LO_PT_ROW_CAPACITY))
      prelimProc(
        .clk(sysClk),
        .gpioData(GPIO_OUT),

        .localOscillatorAddressStrobe(GPIO_STROBES[GPIO_IDX_LOTABLE_ADDRESS + dsbpm*GPIO_IDX_PER_DSBPM]),
        .localOscillatorCsrStrobe(GPIO_STROBES[GPIO_IDX_LOTABLE_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
        .localOscillatorCsr(GPIO_IN[GPIO_IDX_LOTABLE_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
        .sumShiftCsrStrobe(GPIO_STROBES[GPIO_IDX_SUM_SHIFT_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
        .sumShiftCsr(GPIO_IN[GPIO_IDX_SUM_SHIFT_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
        .autotrimCsrStrobe(GPIO_STROBES[GPIO_IDX_AUTOTRIM_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
        .autotrimThresholdStrobe(GPIO_STROBES[GPIO_IDX_AUTOTRIM_THRESHOLD + dsbpm*GPIO_IDX_PER_DSBPM]),
        .autotrimGainStrobes({GPIO_STROBES[GPIO_IDX_ADC_GAIN_FACTOR_3 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_ADC_GAIN_FACTOR_2 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_ADC_GAIN_FACTOR_1 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_ADC_GAIN_FACTOR_0 + dsbpm*GPIO_IDX_PER_DSBPM]}),
        .autotrimCsr(GPIO_IN[GPIO_IDX_AUTOTRIM_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
        .autotrimThreshold(GPIO_IN[GPIO_IDX_AUTOTRIM_THRESHOLD + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainRBK0(GPIO_IN[GPIO_IDX_ADC_GAIN_FACTOR_0 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainRBK1(GPIO_IN[GPIO_IDX_ADC_GAIN_FACTOR_1 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainRBK2(GPIO_IN[GPIO_IDX_ADC_GAIN_FACTOR_2 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainRBK3(GPIO_IN[GPIO_IDX_ADC_GAIN_FACTOR_3 + dsbpm*GPIO_IDX_PER_DSBPM]),

        .calRFGainStrobes({GPIO_STROBES[GPIO_IDX_RF_GAIN_FACTOR_3 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_RF_GAIN_FACTOR_2 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_RF_GAIN_FACTOR_1 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_RF_GAIN_FACTOR_0 + dsbpm*GPIO_IDX_PER_DSBPM]}),
        .gainCalRFRBK0(GPIO_IN[GPIO_IDX_RF_GAIN_FACTOR_0 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalRFRBK1(GPIO_IN[GPIO_IDX_RF_GAIN_FACTOR_1 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalRFRBK2(GPIO_IN[GPIO_IDX_RF_GAIN_FACTOR_2 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalRFRBK3(GPIO_IN[GPIO_IDX_RF_GAIN_FACTOR_3 + dsbpm*GPIO_IDX_PER_DSBPM]),

        .calPLGainStrobes({GPIO_STROBES[GPIO_IDX_PL_GAIN_FACTOR_3 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_PL_GAIN_FACTOR_2 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_PL_GAIN_FACTOR_1 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_PL_GAIN_FACTOR_0 + dsbpm*GPIO_IDX_PER_DSBPM]}),
        .gainCalPLRBK0(GPIO_IN[GPIO_IDX_PL_GAIN_FACTOR_0 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalPLRBK1(GPIO_IN[GPIO_IDX_PL_GAIN_FACTOR_1 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalPLRBK2(GPIO_IN[GPIO_IDX_PL_GAIN_FACTOR_2 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalPLRBK3(GPIO_IN[GPIO_IDX_PL_GAIN_FACTOR_3 + dsbpm*GPIO_IDX_PER_DSBPM]),

        .calPHGainStrobes({GPIO_STROBES[GPIO_IDX_PH_GAIN_FACTOR_3 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_PH_GAIN_FACTOR_2 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_PH_GAIN_FACTOR_1 + dsbpm*GPIO_IDX_PER_DSBPM],
                              GPIO_STROBES[GPIO_IDX_PH_GAIN_FACTOR_0 + dsbpm*GPIO_IDX_PER_DSBPM]}),
        .gainCalPHRBK0(GPIO_IN[GPIO_IDX_PH_GAIN_FACTOR_0 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalPHRBK1(GPIO_IN[GPIO_IDX_PH_GAIN_FACTOR_1 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalPHRBK2(GPIO_IN[GPIO_IDX_PH_GAIN_FACTOR_2 + dsbpm*GPIO_IDX_PER_DSBPM]),
        .gainCalPHRBK3(GPIO_IN[GPIO_IDX_PH_GAIN_FACTOR_3 + dsbpm*GPIO_IDX_PER_DSBPM]),

        .sysTimestamp(sysTimestamp),

        .adcClk(adcClk),
        .adc0(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 0)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // I0
        .adc1(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 2)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // I1
        .adc2(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 4)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // I2
        .adc3(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 6)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // I3
        .adcQ0(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 1)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q0
        .adcQ1(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 3)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q1
        .adcQ2(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 5)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q2
        .adcQ3(adcsProcTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 7)*ADC_SAMPLE_WIDTH+:ADC_SAMPLE_WIDTH]), // Q3
        // All ADC data clocked with adcClk
        .adc0Out(prelimProcADC0[dsbpm]),
        .adc1Out(prelimProcADC1[dsbpm]),
        .adc2Out(prelimProcADC2[dsbpm]),
        .adc3Out(prelimProcADC3[dsbpm]),
        .adc0QOut(prelimProcADCQ0[dsbpm]),
        .adc1QOut(prelimProcADCQ1[dsbpm]),
        .adc2QOut(prelimProcADCQ2[dsbpm]),
        .adc3QOut(prelimProcADCQ3[dsbpm]),
        .adc0OutMag(prelimProcADC0Mag[dsbpm]),
        .adc1OutMag(prelimProcADC1Mag[dsbpm]),
        .adc2OutMag(prelimProcADC2Mag[dsbpm]),
        .adc3OutMag(prelimProcADC3Mag[dsbpm]),

        .adcExceedsThreshold(adcExceedsThreshold[dsbpm]),
        .adcUseThisSample(adcUseThisSample[dsbpm]),
        .adcTbtLoadAccumulator(adcTbtLoadAccumulator[dsbpm]),
        .adcTbtLatchAccumulator(adcTbtLatchAccumulator[dsbpm]),
        .adcMtLoadAndLatch(adcMtLoadAndLatch[dsbpm]),

        .evrClk(evrClk),
        .evrFaMarker(evrFaMarker),
        .evrSaMarker(evrSaMarker),
        .evrTimestamp(evrTimestamp),
        .evrSinglePassTrigger(evrSinglePass),
        .evrHbMarker(evrHeartbeat),
        .sysSingleTrig(sysSingleTrig[dsbpm]),
        .adcSingleTrig(adcSingleTrig[dsbpm]),
        .adcLoSynced(adcLoSynced[dsbpm]),

        .rfTbtToggle(prelimProcTbtToggle[dsbpm]),
        .rfTbtMagValid(prelimProcRfTbtMagValid[dsbpm]),
        .rfTbtMag0(prelimProcRfTbtMag0[dsbpm]),
        .rfTbtMag1(prelimProcRfTbtMag1[dsbpm]),
        .rfTbtMag2(prelimProcRfTbtMag2[dsbpm]),
        .rfTbtMag3(prelimProcRfTbtMag3[dsbpm]),

        .rfFaToggle(prelimProcRfFaToggle[dsbpm]),
        .rfFaMagValid(prelimProcRfFaMagValid[dsbpm]),
        .rfFaMag0(prelimProcRfFaMag0[dsbpm]),
        .rfFaMag1(prelimProcRfFaMag1[dsbpm]),
        .rfFaMag2(prelimProcRfFaMag2[dsbpm]),
        .rfFaMag3(prelimProcRfFaMag3[dsbpm]),

        .rfSaToggle(prelimProcRfSaToggle[dsbpm]),
        .rfSaValid(prelimProcRfSaValid[dsbpm]),
        .sysSaTimestamp({GPIO_IN[GPIO_IDX_SA_TIMESTAMP_SEC + dsbpm*GPIO_IDX_PER_DSBPM],
                         GPIO_IN[GPIO_IDX_SA_TIMESTAMP_FRACTION + dsbpm*GPIO_IDX_PER_DSBPM]}),
        .rfSaMag0(prelimProcRfSaMag0[dsbpm]),
        .rfSaMag1(prelimProcRfSaMag1[dsbpm]),
        .rfSaMag2(prelimProcRfSaMag2[dsbpm]),
        .rfSaMag3(prelimProcRfSaMag3[dsbpm]),

        .ptFaToggle(prelimProcPtFaToggle[dsbpm]),
        .ptFaValid(prelimProcPtFaValid[dsbpm]),
        .overflowFlag(prelimProcOverflow[dsbpm]),
        .plFaMag0(prelimProcPlFaMag0[dsbpm]),
        .plFaMag1(prelimProcPlFaMag1[dsbpm]),
        .plFaMag2(prelimProcPlFaMag2[dsbpm]),
        .plFaMag3(prelimProcPlFaMag3[dsbpm]),
        .phFaMag0(prelimProcPhFaMag0[dsbpm]),
        .phFaMag1(prelimProcPhFaMag1[dsbpm]),
        .phFaMag2(prelimProcPhFaMag2[dsbpm]),
        .phFaMag3(prelimProcPhFaMag3[dsbpm]),

        .ptSaToggle(prelimProcPtSaToggle[dsbpm]),
        .ptSaValid(prelimProcPtSaValid[dsbpm]),
        .plSaMag0(prelimProcPlSaMag0[dsbpm]),
        .plSaMag1(prelimProcPlSaMag1[dsbpm]),
        .plSaMag2(prelimProcPlSaMag2[dsbpm]),
        .plSaMag3(prelimProcPlSaMag3[dsbpm]),
        .phSaMag0(prelimProcPhSaMag0[dsbpm]),
        .phSaMag1(prelimProcPhSaMag1[dsbpm]),
        .phSaMag2(prelimProcPhSaMag2[dsbpm]),
        .phSaMag3(prelimProcPhSaMag3[dsbpm]),

        .rfProductsDbg(rfProducts[dsbpm]),
        .plProductsDbg(plProducts[dsbpm]),
        .phProductsDbg(phProducts[dsbpm]),
        .rfLOcosDbg(rfLOcos[dsbpm]),
        .rfLOsinDbg(rfLOsin[dsbpm]),
        .plLOcosDbg(plLOcos[dsbpm]),
        .plLOsinDbg(plLOsin[dsbpm]),
        .phLOcosDbg(phLOcos[dsbpm]),
        .phLOsinDbg(phLOsin[dsbpm]),
        .tbtSumsDbg(tbtSums[dsbpm]),
        .tbtSumsValidDbg(tbtSumsValid[dsbpm]),
        .tbtMagsDbg(tbtMags[dsbpm]),
        .tbtMagsValidDbg(tbtMagsValid[dsbpm]),
        .cicFaMagValidDbg(prelimProcRfCicFaMagValid[dsbpm]),
        .cicFaMag0Dbg(prelimProcRfCicFaMag0[dsbpm]),
        .cicFaMag1Dbg(prelimProcRfCicFaMag1[dsbpm]),
        .cicFaMag2Dbg(prelimProcRfCicFaMag2[dsbpm]),
        .cicFaMag3Dbg(prelimProcRfCicFaMag3[dsbpm])
    );

    assign GPIO_IN[GPIO_IDX_CLOCK_STATUS + dsbpm*GPIO_IDX_PER_DSBPM] = {
             16'b0,
             1'b0, 1'b0, 1'b0, 1'b0,
             1'b0, 1'b0, isHBvalid, isPPSvalid,
             evrRxSynchronized, evrSROCsynced, evrSaSynced, evrFaSynced,
             1'b0, 1'b0, 1'b0, adcLoSynced[dsbpm] };

    end // if (TEST_BYPASS_PRELIM_PROC == "FALSE")
end // for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1)
endgenerate

//
// Position calculation
//
wire [31:0] positionCalcCSR[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcXcal[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcYcal[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcQcal[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcTbtX[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcTbtY[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcTbtQ[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcTbtS[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcFaX[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcFaY[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcFaQ[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcFaS[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcSaX[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcSaY[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcSaQ[0:CFG_DSBPM_COUNT-1];
wire [31:0] positionCalcSaS[0:CFG_DSBPM_COUNT-1];
wire positionCalcTbtToggle[0:CFG_DSBPM_COUNT-1];
wire positionCalcFaToggle[0:CFG_DSBPM_COUNT-1];
wire positionCalcSaToggle[0:CFG_DSBPM_COUNT-1];
wire positionCalcTbtValid[0:CFG_DSBPM_COUNT-1];
wire positionCalcFaValid[0:CFG_DSBPM_COUNT-1];
wire positionCalcSaValid[0:CFG_DSBPM_COUNT-1];
wire [31:0] lossOfBeamThreshold [0:CFG_DSBPM_COUNT-1];
wire lossOfBeamTrigger[0:CFG_DSBPM_COUNT-1];
wire [31:0] wideXrms[0:CFG_DSBPM_COUNT-1];
wire [31:0] wideYrms[0:CFG_DSBPM_COUNT-1];
wire [31:0] narrowXrms[0:CFG_DSBPM_COUNT-1];
wire [31:0] narrowYrms[0:CFG_DSBPM_COUNT-1];

generate
for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin : pos_chain
assign GPIO_IN[GPIO_IDX_POSITION_CALC_CSR + dsbpm*GPIO_IDX_PER_DSBPM] = positionCalcCSR[dsbpm];
assign GPIO_IN[GPIO_IDX_POSITION_CALC_XCAL + dsbpm*GPIO_IDX_PER_DSBPM] = positionCalcXcal[dsbpm];
assign GPIO_IN[GPIO_IDX_POSITION_CALC_YCAL + dsbpm*GPIO_IDX_PER_DSBPM] = positionCalcYcal[dsbpm];
assign GPIO_IN[GPIO_IDX_POSITION_CALC_QCAL + dsbpm*GPIO_IDX_PER_DSBPM] = positionCalcQcal[dsbpm];
assign GPIO_IN[GPIO_IDX_POSITION_CALC_SA_X + dsbpm*GPIO_IDX_PER_DSBPM] = positionCalcSaX[dsbpm];
assign GPIO_IN[GPIO_IDX_POSITION_CALC_SA_Y + dsbpm*GPIO_IDX_PER_DSBPM] = positionCalcSaY[dsbpm];
assign GPIO_IN[GPIO_IDX_POSITION_CALC_SA_Q + dsbpm*GPIO_IDX_PER_DSBPM] = positionCalcSaQ[dsbpm];
assign GPIO_IN[GPIO_IDX_POSITION_CALC_SA_S + dsbpm*GPIO_IDX_PER_DSBPM] = positionCalcSaS[dsbpm];
positionCalc #(.MAG_WIDTH(MAG_WIDTH))
  positionCalc(
    .clk(sysClk),
    .gpioData(GPIO_OUT),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_POSITION_CALC_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
    .xCalStrobe(GPIO_STROBES[GPIO_IDX_POSITION_CALC_XCAL + dsbpm*GPIO_IDX_PER_DSBPM]),
    .yCalStrobe(GPIO_STROBES[GPIO_IDX_POSITION_CALC_YCAL + dsbpm*GPIO_IDX_PER_DSBPM]),
    .qCalStrobe(GPIO_STROBES[GPIO_IDX_POSITION_CALC_QCAL + dsbpm*GPIO_IDX_PER_DSBPM]),
    .tbt0(prelimProcRfTbtMag0[dsbpm]),
    .tbt1(prelimProcRfTbtMag1[dsbpm]),
    .tbt2(prelimProcRfTbtMag2[dsbpm]),
    .tbt3(prelimProcRfTbtMag3[dsbpm]),
    .tbtInToggle(prelimProcTbtToggle[dsbpm]),
    .fa0(prelimProcRfFaMag0[dsbpm]),
    .fa1(prelimProcRfFaMag1[dsbpm]),
    .fa2(prelimProcRfFaMag2[dsbpm]),
    .fa3(prelimProcRfFaMag3[dsbpm]),
    .faInToggle(prelimProcRfFaToggle[dsbpm]),
    .sa0(prelimProcRfSaMag0[dsbpm]),
    .sa1(prelimProcRfSaMag1[dsbpm]),
    .sa2(prelimProcRfSaMag2[dsbpm]),
    .sa3(prelimProcRfSaMag3[dsbpm]),
    .saInToggle(prelimProcRfSaToggle[dsbpm]),
    .csr(positionCalcCSR[dsbpm]),
    .xCalibration(positionCalcXcal[dsbpm]),
    .yCalibration(positionCalcYcal[dsbpm]),
    .qCalibration(positionCalcQcal[dsbpm]),
    .tbtX(positionCalcTbtX[dsbpm]),
    .tbtY(positionCalcTbtY[dsbpm]),
    .tbtQ(positionCalcTbtQ[dsbpm]),
    .tbtS(positionCalcTbtS[dsbpm]),
    .tbtToggle(positionCalcTbtToggle[dsbpm]),
    .tbtValid(positionCalcTbtValid[dsbpm]),
    .faX(positionCalcFaX[dsbpm]),
    .faY(positionCalcFaY[dsbpm]),
    .faQ(positionCalcFaQ[dsbpm]),
    .faS(positionCalcFaS[dsbpm]),
    .faToggle(positionCalcFaToggle[dsbpm]),
    .faValid(positionCalcFaValid[dsbpm]),
    .saX(positionCalcSaX[dsbpm]),
    .saY(positionCalcSaY[dsbpm]),
    .saQ(positionCalcSaQ[dsbpm]),
    .saS(positionCalcSaS[dsbpm]),
    .saToggle(positionCalcSaToggle[dsbpm]),
    .saValid(positionCalcSaValid[dsbpm]));

//
// Loss-of-beam detection
//
assign GPIO_IN[GPIO_IDX_LOSS_OF_BEAM_THRSH + dsbpm*GPIO_IDX_PER_DSBPM] = lossOfBeamThreshold[dsbpm];
assign GPIO_IN[GPIO_IDX_LOSS_OF_BEAM_TRIGGER + dsbpm*GPIO_IDX_PER_DSBPM] = lossOfBeamTrigger[dsbpm];
lossOfBeam lossOfBeam(.clk(sysClk),
                    .thresholdStrobe(GPIO_STROBES[GPIO_IDX_LOSS_OF_BEAM_THRSH + dsbpm*GPIO_IDX_PER_DSBPM]),
                    .gpioData(GPIO_OUT),
                    .threshold(lossOfBeamThreshold[dsbpm]),
                    .turnByTurnToggle(positionCalcTbtToggle[dsbpm]),
                    .buttonSum(positionCalcTbtS[dsbpm]),
                    .lossOfBeamTrigger(lossOfBeamTrigger[dsbpm]));

//
// RMS motion calculation
//
assign GPIO_IN[GPIO_IDX_RMS_X_WIDE + dsbpm*GPIO_IDX_PER_DSBPM] = wideXrms[dsbpm];
assign GPIO_IN[GPIO_IDX_RMS_Y_WIDE + dsbpm*GPIO_IDX_PER_DSBPM] = wideYrms[dsbpm];
assign GPIO_IN[GPIO_IDX_RMS_X_NARROW + dsbpm*GPIO_IDX_PER_DSBPM] = narrowXrms[dsbpm];
assign GPIO_IN[GPIO_IDX_RMS_Y_NARROW + dsbpm*GPIO_IDX_PER_DSBPM] = narrowYrms[dsbpm];
rmsCalc rmsCalc(.clk(sysClk),
                .faToggle(positionCalcFaToggle[dsbpm]),
                .faX(positionCalcFaX[dsbpm]),
                .faY(positionCalcFaY[dsbpm]),
                .wideXrms(wideXrms[dsbpm]),
                .wideYrms(wideYrms[dsbpm]),
                .narrowXrms(narrowXrms[dsbpm]),
                .narrowYrms(narrowYrms[dsbpm]));
//
// DAC streamer
//

genericDACStreamer #(
  .AXIS_DATA_WIDTH(AXIS_DAC_SAMPLE_WIDTH),
  .DAC_DATA_WIDTH(DAC_SAMPLE_WIDTH),
  .DAC_ADDRESS_WIDTH(16)
) genericDACStreamer (
    .sysClk(sysClk),
    .sysGpioData(GPIO_OUT),
    .sysGpioCsr(GPIO_IN[GPIO_IDX_DACTABLE_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
    .sysAddressStrobe(GPIO_STROBES[GPIO_IDX_DACTABLE_ADDRESS + dsbpm*GPIO_IDX_PER_DSBPM]),
    .sysGpioStrobe(GPIO_STROBES[GPIO_IDX_DACTABLE_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),

    .evrHbMarker(evrHeartbeat2),

    .axis_CLK(dacClk),
    .axis_TDATA(dacsTDATA[(dsbpm*DAC_SIGNAL_OFFSET_PER_DSP)*AXIS_DAC_SAMPLE_WIDTH+:AXIS_DAC_SAMPLE_WIDTH]),
    .axis_TVALID(dacsTVALID[dsbpm*DAC_SIGNAL_OFFSET_PER_DSP]),
    .axis_TREADY(dacsTREADY[dsbpm*DAC_SIGNAL_OFFSET_PER_DSP])
);

//////////////////////////////////////////////////////////////////////////////
// Analog front end SPI components

wire spiCLK, spiLE, spiSDI;
afeSPI #(
  .CLK_RATE(SYSCLK_RATE),
  .CSB_WIDTH(1),
  .BIT_RATE(100000),
  .DEBUG("false")
) afeSPI (
    .clk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_AFE_SPI_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
    .gpioOut(GPIO_OUT),
    .status(GPIO_IN[GPIO_IDX_AFE_SPI_CSR + dsbpm*GPIO_IDX_PER_DSBPM]),
    .SPI_CLK(spiCLK),
    .SPI_CSB(),
    .SPI_LE(spiLE),
    .SPI_SDI(spiSDI),
    .SPI_SDO(0)
);

assign AFE_SPI_CLK[dsbpm] = ~spiCLK;
assign AFE_SPI_LE[dsbpm] = ~spiLE;
assign AFE_SPI_SDI[dsbpm] = ~spiSDI;

end // for
endgenerate // generate

//
// FOFB communication
//

wire [CFG_DSBPM_COUNT*32-1:0] sysBPMCsrFlatten;
generate
for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin : gpio_cell_comm_bpm_gpio
    assign GPIO_IN[GPIO_IDX_CELL_COMM_BPM_CSR+(dsbpm*GPIO_IDX_CELL_COMM_BPM_PER_DSBPM)] =
        sysBPMCsrFlatten[32*dsbpm+:32];
end
endgenerate

wire [CFG_DSBPM_COUNT*32-1:0] positionCalcFaXFlatten;
wire [CFG_DSBPM_COUNT*32-1:0] positionCalcFaYFlatten;
wire [CFG_DSBPM_COUNT*32-1:0] positionCalcFaSFlatten;
wire [CFG_DSBPM_COUNT-1:0] positionCalcFaToggleFlatten;
generate
for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin : gpio_cell_comm_bpm_position

if (TEST_BYPASS_PRELIM_PROC == "FALSE") begin
    assign positionCalcFaXFlatten[32*dsbpm+:32] = positionCalcFaX[dsbpm];
    assign positionCalcFaYFlatten[32*dsbpm+:32] = positionCalcFaY[dsbpm];
    assign positionCalcFaSFlatten[32*dsbpm+:32] = positionCalcFaS[dsbpm];
    assign positionCalcFaToggleFlatten[dsbpm] = positionCalcFaToggle[dsbpm];
end
else begin
    reg [15:0] positionCalcFaFake = 0;
    (* ASYNC_REG="TRUE" *) reg sysFaEvent_m = 0, sysFaEvent = 0;
    reg sysFaEvent_d1, sysFAstrobe;

    always @(posedge sysClk) begin
        sysFaEvent_m  <= evrFaMarker;
        sysFaEvent    <= sysFaEvent_m;
        sysFaEvent_d1 <= sysFaEvent;
        if (sysFaEvent && !sysFaEvent_d1) begin
            sysFaStrobe <= 1;
        end
        else begin
            sysFaStrobe <= 0;
        end

        if (sysFAstrobe) begin
            positionCalcFaFake <= positionCalcFaFake + 1;
        end
    end

    assign positionCalcFaXFlatten[32*i+:32] = {16'hcafe, positionCalcFaFake};
    assign positionCalcFaYFlatten[32*i+:32] = {16'hbeef, positionCalcFaFake};
    assign positionCalcFaSFlatten[32*i+:32] = {16'hbead, positionCalcFaFake};
end

end
endgenerate

cellComm #(
    .NUM_BPMS(CFG_DSBPM_COUNT),
    // A, B, C, D
    .ADC_COUNT(4))
  cellComm (
    .sysClk(sysClk),
    .sysGpioData(GPIO_OUT),

    .sysCCWCsrStrobe(GPIO_STROBES[GPIO_IDX_CELL_COMM_CCW_CSR]),
    .sysCCWCsr(GPIO_IN[GPIO_IDX_CELL_COMM_CCW_CSR]),

    .sysCWCsrStrobe(GPIO_STROBES[GPIO_IDX_CELL_COMM_CW_CSR]),
    .sysCWCsr(GPIO_IN[GPIO_IDX_CELL_COMM_CW_CSR]),

    .sysBPMCsrStrobe(GPIO_STROBES[GPIO_IDX_CELL_COMM_BPM_CSR+:CFG_DSBPM_COUNT]),
    .sysBPMCsr(sysBPMCsrFlatten),

    .sysFA_X(positionCalcFaXFlatten),
    .sysFA_Y(positionCalcFaYFlatten),
    .sysFA_S(positionCalcFaSFlatten),
    .sysFaToggle(positionCalcFaToggleFlatten),
    // FIXME: Add ADC clip status
    .sysClippedAdc(0),

    .GT_REFCLK(IDT_8A34001_Q11_CLK),

    .CCW_TX_N(SFP_TX_N[0]),
    .CCW_TX_P(SFP_TX_P[0]),
    .CCW_RX_N(SFP_RX_N[0]),
    .CCW_RX_P(SFP_RX_P[0]),

    .CW_TX_N(SFP_TX_N[1]),
    .CW_TX_P(SFP_TX_P[1]),
    .CW_RX_N(SFP_RX_N[1]),
    .CW_RX_P(SFP_RX_P[1]),

    .ccwCRCfaults(GPIO_IN[GPIO_IDX_BPM_CCW_CRC_FAULTS]),
    .cwCRCfaults(GPIO_IN[GPIO_IDX_BPM_CW_CRC_FAULTS]));

//
// Debug probes
//

generate
if (DAC_ILA_CHIPSCOPE_DBG != "TRUE" && DAC_ILA_CHIPSCOPE_DBG != "FALSE") begin
    DAC_ILA_CHIPSCOPE_DBG_only_TRUE_or_FALSE_SUPPORTED();
end
endgenerate

generate
if (DAC_ILA_CHIPSCOPE_DBG == "TRUE") begin

`ifndef SIMULATE
wire [255:0] dac_probe;
ila_td256_s4096_cap dac_ila_td256_s4096_cap_inst (
    .clk(dacClk),
    .probe0(dac_probe)
);

assign dac_probe[0]       = dacsTREADY[0];
assign dac_probe[1]       = dacsTREADY[4];
assign dac_probe[2]       = dacsTVALID[0];
assign dac_probe[3]       = dacsTVALID[4];

assign dac_probe[32+:DAC_SAMPLE_WIDTH] = dacsTDATA[0*AXIS_DAC_SAMPLE_WIDTH+:DAC_SAMPLE_WIDTH];
assign dac_probe[64+:DAC_SAMPLE_WIDTH] = dacsTDATA[(0*AXIS_DAC_SAMPLE_WIDTH+DAC_SAMPLE_WIDTH)+:DAC_SAMPLE_WIDTH];

assign dac_probe[96+:DAC_SAMPLE_WIDTH]  = dacsTDATA[4*AXIS_DAC_SAMPLE_WIDTH+:DAC_SAMPLE_WIDTH];
assign dac_probe[128+:DAC_SAMPLE_WIDTH] = dacsTDATA[(4*AXIS_DAC_SAMPLE_WIDTH+DAC_SAMPLE_WIDTH)+:DAC_SAMPLE_WIDTH];
`endif

end // end if
endgenerate

evrLogger evrLogger (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_EVENT_LOG_CSR]),
    .sysGpioOut(GPIO_OUT),
    .sysCsr(GPIO_IN[GPIO_IDX_EVENT_LOG_CSR]),
    .sysDataTicks(GPIO_IN[GPIO_IDX_EVENT_LOG_TICKS]),
    .evrClk(evrClk),
    .evrChar(evrChars[7:0]),
    .evrCharIsK(evrCharIsK[0]));

wire [31:0] spiMuxSel;
gpioReg spiMuxSelReg (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_CLK104_SPI_MUX_CSR]),
    .sysGpioOut(GPIO_OUT),
    .sysCsr(GPIO_IN[GPIO_IDX_CLK104_SPI_MUX_CSR]),
    .gpioOut(spiMuxSel));

assign CLK_SPI_MUX_SEL0 = spiMuxSel[0];
assign CLK_SPI_MUX_SEL1 = spiMuxSel[1];

endmodule
