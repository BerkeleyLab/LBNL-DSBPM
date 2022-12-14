module dsbpm_zcu208_top #(
    parameter ADC_WIDTH                 = 14,
    parameter AXI_SAMPLE_WIDTH          = ((ADC_WIDTH + 7) / 8) * 8,
    parameter IQ_DATA                   = "TRUE",
    parameter SYSCLK_RATE               = 99999001,  // From block design
    parameter BD_ADC_CHANNEL_COUNT      = 16,
    parameter ADC_CHANNEL_DEBUG         = "false",
    parameter LO_WIDTH                  = 18,
    parameter MAG_WIDTH                 = 26,
    parameter PRODUCT_WIDTH             = AXI_SAMPLE_WIDTH + LO_WIDTH - 1,
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

    output wire SFP_REC_CLK_P,
    output wire SFP_REC_CLK_N,

    output wire EVR_FB_CLK,

    input             GPIO_SW_W,
    input             GPIO_SW_E,
    input             GPIO_SW_N,
    input       [7:0] DIP_SWITCH,
    output wire [7:0] GPIO_LEDS,

    output wire [7:0] AFE_SPI_CSB,
    output wire       AFE_SPI_SDI,
    input             AFE_SPI_SDO,
    output wire       AFE_SPI_CLK,
    output wire       TRAINING_SIGNAL,
    output wire       BCM_SROC_GND,
    output wire       AFE_DACIO_00,

    output wire       CLK_SPI_MUX_SEL0,
    output wire       CLK_SPI_MUX_SEL1
);

`include "firmwareBuildDate.v"

//////////////////////////////////////////////////////////////////////////////
// Static outputs
assign SFP2_TX_ENABLE = 1'b1;

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
assign GPIO_IN[GPIO_IDX_FIRMWARE_BUILD_DATE] = FIRMWARE_BUILD_DATE;

//////////////////////////////////////////////////////////////////////////////
// Clocks
wire sysClk, evrClk, adcClk, dacClk, prbsClk;
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
    .RX_N(SFP2_RX_N),
    .RX_P(SFP2_RX_P),
    .TX_N(SFP2_TX_N),
    .TX_P(SFP2_TX_P),
    .evrClk(evrClk),
    .evrRxSynchronized(evrRxSynchronized),
    .evrChars(evrChars),
    .evrCharIsK(evrCharIsK),
    .evrCharIsComma(evrCharIsComma));

// EVR triggers
wire [7:0] evrTriggerBus;
wire evrHeartbeat = evrTriggerBus[0];
wire evrPulsePerSecond = evrTriggerBus[1];
wire evrSROCsynced;
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

// We can't use both OBUF and OBUFS, as the ODDR Q pin
// can access just 2 OBUFs, not 3. This leads to impossible
// routing. So, just use the "wrong" way of forwarding a clock
// as we are only using this for monitoring anyway.
OBUF #(
   .SLEW("FAST")
) OBUF_EVR_FB_CLK (
   .O(EVR_FB_CLK),
   .I(evrClk)
);
`endif

// Check EVR markers
wire [31:0] evrSyncStatus;
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
          .evrSROC(AFE_DACIO_00),
          .evrSROCstrobe());
assign GPIO_IN[GPIO_IDX_EVR_SYNC_CSR] = evrSyncStatus;
wire isPPSvalid = evrSyncStatus[2];

/////////////////////////////////////////////////////////////////////////////
// Generate tile synchronization user_sysref_adc
wire FPGA_REFCLK_OUT_C;
wire FPGA_REFCLK_OUT_C_unbuf;
wire user_sysref_adc;

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
    .COUNTER_WIDTH(10)) // up to 1023 SYSREF poeriods
  sysrefSync (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_SYSREF_CSR]),
    .GPIO_OUT(GPIO_OUT),
    .sysStatusReg(GPIO_IN[GPIO_IDX_SYSREF_CSR]),
    .FPGA_REFCLK_OUT_C(FPGA_REFCLK_OUT_C),
    .SYSREF_FPGA_C_UNBUF(SYSREF_FPGA_C_unbuf),
    .adcClk(adcClk),
    .user_sysref_adc(user_sysref_adc));

/////////////////////////////////////////////////////////////////////////////
// Triggers
localparam ACQ_TRIGGER_BUS_WIDTH = 7;
reg [ACQ_TRIGGER_BUS_WIDTH-1:0] adcEventTriggerStrobes = 0;
// Software trigger
reg [3:0] sysSoftTriggerCounter = 0;
wire sysSoftTrigger = sysSoftTriggerCounter[3];
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_SOFT_TRIGGER]) begin
        sysSoftTriggerCounter = ~0;
    end
    else if (sysSoftTrigger) begin
        sysSoftTriggerCounter <= sysSoftTriggerCounter - 1;
    end
end

// Get event and soft triggers into ADC clock domain
(*ASYNC_REG="TRUE"*) reg [ACQ_TRIGGER_BUS_WIDTH-1:0] adcEventTriggers_m = 0;
(*ASYNC_REG="TRUE"*) reg [ACQ_TRIGGER_BUS_WIDTH-1:0] adcEventTriggers = 0;
reg [ACQ_TRIGGER_BUS_WIDTH-1:0] adcEventTriggers_d = 0;
always @(posedge adcClk) begin
    adcEventTriggers_m <= { evrTriggerBus[7:2], sysSoftTrigger };
    adcEventTriggers   <= adcEventTriggers_m;
    adcEventTriggers_d <= adcEventTriggers;
    adcEventTriggerStrobes <= (adcEventTriggers & ~adcEventTriggers_d);
end

/////////////////////////////////////////////////////////////////////////////
// Acquisition common
localparam SAMPLES_WIDTH    = CFG_AXI_SAMPLES_PER_CLOCK * AXI_SAMPLE_WIDTH;
localparam ACQ_SAMPLES_WIDTH = ACQ_WIDTH;
wire [(BD_ADC_CHANNEL_COUNT*SAMPLES_WIDTH)-1:0] adcsTDATA;
wire                 [BD_ADC_CHANNEL_COUNT-1:0] adcsTVALID;

// Calibration support
calibration #(
    .ADC_COUNT(CFG_ADC_CHANNEL_COUNT),
    .SAMPLES_PER_CLOCK(CFG_AXI_SAMPLES_PER_CLOCK),
    .ADC_WIDTH(ACQ_SAMPLES_WIDTH),
    .AXI_SAMPLE_WIDTH(ACQ_SAMPLES_WIDTH))
  calibration (
    .sysClk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_CALIBRATION_CSR]),
    .GPIO_OUT(GPIO_OUT),
    .readout(GPIO_IN[GPIO_IDX_CALIBRATION_CSR]),
    .prbsClk(prbsClk),
    .trainingSignal(TRAINING_SIGNAL),
    // The first CFG_ADC_CHANNEL_COUNT channels are I/Q ADC samples
    .adcClk(acqTCLK[0]),
    .adcsTVALID(acqTVALID[0]),
    .adcsTDATA(acqTDATA[0+:CFG_ADC_CHANNEL_COUNT*ACQ_SAMPLES_WIDTH]));

/////////////////////////////////////////////////////////////////////////////
// Monitor range of signals at ADC inputs
wire [(CFG_ADC_PHYSICAL_COUNT*AXI_SAMPLE_WIDTH)-1:0] adcsMagTDATA;
wire                    [CFG_DSBPM_COUNT-1:0] adcsMagTVALID;
wire                    [CFG_DSBPM_COUNT-1:0] adcsMagTCLK;
adcRangeCheck #(
    .AXI_CHANNEL_COUNT(CFG_ADC_PHYSICAL_COUNT),
    .AXI_SAMPLE_WIDTH(AXI_SAMPLE_WIDTH),
    .AXI_SAMPLES_PER_CLOCK(CFG_AXI_SAMPLES_PER_CLOCK),
    .ADC_WIDTH(AXI_SAMPLE_WIDTH))
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
    assign adcsMagTDATA[dsbpm*4*AXI_SAMPLE_WIDTH+:4*AXI_SAMPLE_WIDTH] = {
        prelimProcADC3Mag[dsbpm],
        prelimProcADC2Mag[dsbpm],
        prelimProcADC1Mag[dsbpm],
        prelimProcADC0Mag[dsbpm]
    };
    assign adcsMagTVALID[dsbpm] = 1'b1;
    assign adcsMagTCLK[dsbpm] = adcClk;
end
endgenerate

/////////////////////////////////////////////////////////////////////////////
// Acquisition per style of firmware

`ifdef FIRMWARE_STYLE_HSD
//
// High speed digitizer acquisition
//
localparam NUMBER_OF_BONDED_GROUPS =
                    (CFG_DSP_CHANNEL_COUNT + CFG_DSPS_PER_BONDED_GROUP -1 ) /
                                                      CFG_DSPS_PER_BONDED_GROUP;
genvar dsp;
//generate
for (dsbpm = 0; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin
 for (i = 0 ; i < NUMBER_OF_BONDED_GROUPS ; i = i + 1) begin
  wire bondedWriteEnable[0:CFG_DSPS_PER_BONDED_GROUP-1];
  wire [$clog2(CFG_ACQUISITION_BUFFER_CAPACITY/CFG_AXI_SAMPLES_PER_CLOCK)-1:0]
                               bondedWriteAddress[0:CFG_DSPS_PER_BONDED_GROUP-1];
  for (dsp = (dsbpm * CFG_DSP_CHANNEL_COUNT) + i * CFG_DSPS_PER_BONDED_GROUP ;
                              (dsp <
                                ((dsbpm * CFG_DSP_CHANNEL_COUNT) +
                                (i + 1) * CFG_DSPS_PER_BONDED_GROUP)) &&
                              (dsp < CFG_DSP_CHANNEL_COUNT * CFG_DSBPM_COUNT); dsp = dsp + 1) begin
     localparam integer rOff = dsp * GPIO_IDX_PER_ADC;
     acquisitionHSD #(
         .ACQUISITION_BUFFER_CAPACITY(CFG_ACQUISITION_BUFFER_CAPACITY),
         .LONG_SEGMENT_CAPACITY(CFG_LONG_SEGMENT_CAPACITY),
         .SHORT_SEGMENT_CAPACITY(CFG_SHORT_SEGMENT_CAPACITY),
         .EARLY_SEGMENTS_COUNT(CFG_EARLY_SEGMENTS_COUNT),
         .SEGMENT_PRETRIGGER_COUNT(CFG_SEGMENT_PRETRIGGER_COUNT),
         .AXI_SAMPLES_PER_CLOCK(CFG_AXI_SAMPLES_PER_CLOCK),
         .AXI_SAMPLE_WIDTH(ACQ_SAMPLES_WIDTH),
         .ADC_WIDTH(ACQ_SAMPLES_WIDTH),
         .TRIGGER_BUS_WIDTH(ACQ_TRIGGER_BUS_WIDTH),
         .DEBUG((dsp == 0) ? ADC_CHANNEL_DEBUG : "false"))
       dspChannel (
         .sysClk(sysClk),
         .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_ADC_0_CSR+rOff]),
         .sysTriggerConfigStrobe(GPIO_STROBES[GPIO_IDX_ADC_0_TRIGGER_CONFIG+rOff]),
         .sysAcqConfig1Strobe(GPIO_STROBES[GPIO_IDX_ADC_0_CONFIG_1+rOff]),
         .sysAcqConfig2Strobe(GPIO_STROBES[GPIO_IDX_ADC_0_CONFIG_2+rOff]),
         .GPIO_OUT(GPIO_OUT),
         .sysStatus(GPIO_IN[GPIO_IDX_ADC_0_CSR+rOff]),
         .sysData(GPIO_IN[GPIO_IDX_ADC_0_DATA+rOff]),
         .sysTriggerLocation(GPIO_IN[GPIO_IDX_ADC_0_TRIGGER_LOCATION+rOff]),
         .sysTriggerTimestamp({GPIO_IN[GPIO_IDX_ADC_0_SECONDS+rOff],
                               GPIO_IN[GPIO_IDX_ADC_0_TICKS+rOff]}),
         .evrClk(evrClk),
         .evrTimestamp(evrTimestamp),
         .adcClk(acqTCLK[dsp]),
         .axiValid(acqTVALID[dsp]),
         .axiData(acqTDATA[dsp*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH]),
         .eventTriggerStrobes(adcEventTriggerStrobes),
         .bondedWriteEnableIn(bondedWriteEnable[0]),
         .bondedWriteAddressIn(bondedWriteAddress[0]),
         .bondedWriteEnableOut(bondedWriteEnable[dsp%CFG_DSPS_PER_BONDED_GROUP]),
         .bondedWriteAddressOut(bondedWriteAddress[dsp%CFG_DSPS_PER_BONDED_GROUP]));
  end
 end
end
`endif

/////////////////////////////////////////////////////////////////////////////
// Measure clock rates
reg   [2:0] frequencyMonitorSelect;
wire [29:0] measuredFrequency;
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_FREQ_MONITOR_CSR]) begin
        frequencyMonitorSelect <= GPIO_OUT[2:0];
    end
end
assign GPIO_IN[GPIO_IDX_FREQ_MONITOR_CSR] = { 2'b0, measuredFrequency };
wire rfdc_adc0_clk;
wire rfdc_dac0_clk;
freq_multi_count #(
        .NF(8),  // number of frequency counters in a block
        .NG(1),  // number of frequency counter blocks
        .gw(4),  // Gray counter width
        .cw(1),  // macro-cycle counter width
        .rw($clog2(SYSCLK_RATE*4/3)), // reference counter width
        .uw(30)) // unknown counter width
  frequencyCounters (
    .unk_clk({mgtRefClkMonitor, prbsClk,
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
// Analog front end SPI components
afeSPI #(.CLK_RATE(SYSCLK_RATE),
         .CSB_WIDTH(8),
         .BIT_RATE(12500000),
         .DEBUG("false"))
  afeSPI (
    .clk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_AFE_SPI_CSR]),
    .gpioOut(GPIO_OUT),
    .status(GPIO_IN[GPIO_IDX_AFE_SPI_CSR]),
    .SPI_CLK(AFE_SPI_CLK),
    .SPI_CSB(AFE_SPI_CSB),
    .SPI_SDI(AFE_SPI_SDI),
    .SPI_SDO(AFE_SPI_SDO));

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

// Make this a black box for simulation
`ifndef SIMULATE
//////////////////////////////////////////////////////////////////////////////
// ZYNQ processor system
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
    .user_sysref_dac(1'b0),

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

    .adc0stream_tdata(adcsTDATA[0*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc1stream_tdata(adcsTDATA[2*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc2stream_tdata(adcsTDATA[4*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc3stream_tdata(adcsTDATA[6*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc4stream_tdata(adcsTDATA[8*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc5stream_tdata(adcsTDATA[10*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc6stream_tdata(adcsTDATA[12*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc7stream_tdata(adcsTDATA[14*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc0Qstream_tdata(adcsTDATA[1*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc1Qstream_tdata(adcsTDATA[3*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc2Qstream_tdata(adcsTDATA[5*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc3Qstream_tdata(adcsTDATA[7*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc4Qstream_tdata(adcsTDATA[9*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc5Qstream_tdata(adcsTDATA[11*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc6Qstream_tdata(adcsTDATA[13*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
    .adc7Qstream_tdata(adcsTDATA[15*AXI_SAMPLE_WIDTH+:AXI_SAMPLE_WIDTH]),
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

`endif // `ifndef SIMULATE


generate
for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin : acq_data

//
// ADC I raw data
//

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 0] = adcClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 0] = 1'b1;
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 0)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-AXI_SAMPLE_WIDTH{prelimProcADC0[dsbpm][AXI_SAMPLE_WIDTH-1]}},
    prelimProcADC0[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 1] = adcClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 1] = 1'b1;
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 1)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-AXI_SAMPLE_WIDTH{prelimProcADC1[dsbpm][AXI_SAMPLE_WIDTH-1]}},
    prelimProcADC1[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 2] = adcClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 2] = 1'b1;
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 2)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-AXI_SAMPLE_WIDTH{prelimProcADC2[dsbpm][AXI_SAMPLE_WIDTH-1]}},
    prelimProcADC2[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 3] = adcClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 3] = 1'b1;
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 3)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-AXI_SAMPLE_WIDTH{prelimProcADC3[dsbpm][AXI_SAMPLE_WIDTH-1]}},
    prelimProcADC3[dsbpm]
};

//
// ADC Q raw data
//

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 4] = adcClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 4] = 1'b1;
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 4)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-AXI_SAMPLE_WIDTH{prelimProcADCQ0[dsbpm][AXI_SAMPLE_WIDTH-1]}},
    prelimProcADCQ0[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 5] = adcClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 5] = 1'b1;
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 5)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-AXI_SAMPLE_WIDTH{prelimProcADCQ1[dsbpm][AXI_SAMPLE_WIDTH-1]}},
    prelimProcADCQ1[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 6] = adcClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 6] = 1'b1;
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 6)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-AXI_SAMPLE_WIDTH{prelimProcADCQ2[dsbpm][AXI_SAMPLE_WIDTH-1]}},
    prelimProcADCQ2[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 7] = adcClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 7] = 1'b1;
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 7)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-AXI_SAMPLE_WIDTH{prelimProcADCQ3[dsbpm][AXI_SAMPLE_WIDTH-1]}},
    prelimProcADCQ3[dsbpm]
};

//
// Tbt Mags
//

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 8] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 8] = prelimProcRfTbtMagValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 8)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{prelimProcRfTbtMag0[dsbpm][MAG_WIDTH-1]}},
    prelimProcRfTbtMag0[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 9] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 9] = prelimProcRfTbtMagValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 9)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{prelimProcRfTbtMag1[dsbpm][MAG_WIDTH-1]}},
    prelimProcRfTbtMag1[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 10] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 10] = prelimProcRfTbtMagValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 10)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{prelimProcRfTbtMag2[dsbpm][MAG_WIDTH-1]}},
    prelimProcRfTbtMag2[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 11] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 11] = prelimProcRfTbtMagValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 11)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{prelimProcRfTbtMag3[dsbpm][MAG_WIDTH-1]}},
    prelimProcRfTbtMag3[dsbpm]
};

//
// Tbt Positions
//

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 12] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 12] = positionCalcTbtValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 12)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{positionCalcTbtX[dsbpm][MAG_WIDTH-1]}},
    positionCalcTbtX[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 13] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 13] = positionCalcTbtValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 13)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{positionCalcTbtY[dsbpm][MAG_WIDTH-1]}},
    positionCalcTbtY[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 14] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 14] = positionCalcTbtValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 14)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{positionCalcTbtQ[dsbpm][MAG_WIDTH-1]}},
    positionCalcTbtQ[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 15] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 15] = positionCalcTbtValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 15)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{positionCalcTbtS[dsbpm][MAG_WIDTH-1]}},
    positionCalcTbtS[dsbpm]
};

//
// Fa Mags
//

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 16] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 16] = prelimProcRfFaMagValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 16)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{prelimProcRfFaMag0[dsbpm][MAG_WIDTH-1]}},
    prelimProcRfFaMag0[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 17] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 17] = prelimProcRfFaMagValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 17)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{prelimProcRfFaMag1[dsbpm][MAG_WIDTH-1]}},
    prelimProcRfFaMag1[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 18] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 18] = prelimProcRfFaMagValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 18)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{prelimProcRfFaMag2[dsbpm][MAG_WIDTH-1]}},
    prelimProcRfFaMag2[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 19] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 19] = prelimProcRfFaMagValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 19)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{prelimProcRfFaMag3[dsbpm][MAG_WIDTH-1]}},
    prelimProcRfFaMag3[dsbpm]
};

//
// Fa Positions
//

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 20] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 20] = positionCalcFaValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 20)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{positionCalcFaX[dsbpm][MAG_WIDTH-1]}},
    positionCalcFaX[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 21] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 21] = positionCalcFaValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 21)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{positionCalcFaY[dsbpm][MAG_WIDTH-1]}},
    positionCalcFaY[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 22] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 22] = positionCalcFaValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 22)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{positionCalcFaQ[dsbpm][MAG_WIDTH-1]}},
    positionCalcFaQ[dsbpm]
};

assign acqTCLK[dsbpm*CFG_DSP_CHANNEL_COUNT + 23] = sysClk;
assign acqTVALID[dsbpm*CFG_DSP_CHANNEL_COUNT + 23] = positionCalcFaValid[dsbpm];
assign acqTDATA[(dsbpm*CFG_DSP_CHANNEL_COUNT + 23)*ACQ_SAMPLES_WIDTH+:ACQ_SAMPLES_WIDTH] = {
    {ACQ_SAMPLES_WIDTH-MAG_WIDTH{positionCalcFaS[dsbpm][MAG_WIDTH-1]}},
    positionCalcFaS[dsbpm]
};

end // for
endgenerate // generate

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
// Create slow (SA) and fast (FA) acquistion triggers
// based on ADC trigger 0 (fake heartbeat).
//

localparam MAX_ADC_CLKS_PER_HEARTBEAT = 200000000;
localparam ADC_HEARTBEAT_WIDTH = $clog2(MAX_ADC_CLKS_PER_HEARTBEAT);

reg [ADC_HEARTBEAT_WIDTH-1:0] sysAdcHeartbeatReload = ~0;
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_ADC_HEARTBEAT_RELOAD]) begin
        sysAdcHeartbeatReload <= GPIO_OUT[ADC_HEARTBEAT_WIDTH-1:0];
    end
end

reg [ADC_HEARTBEAT_WIDTH:0] adcHeartbeatCounter = ~0;
wire adcHeartbeatCounterDone = adcHeartbeatCounter[ADC_HEARTBEAT_WIDTH];
wire adcHeartbeat = adcHeartbeatCounter[ADC_HEARTBEAT_WIDTH];
always @(posedge adcClk) begin
    if (adcHeartbeatCounterDone) begin
        adcHeartbeatCounter <= { 1'b0, sysAdcHeartbeatReload };
    end
    else begin
        adcHeartbeatCounter <= adcHeartbeatCounter - 1;
    end
end

wire adcFaMarker, adcSaMarker;
wire [31:0] sysADCFAstatus, sysADCSAstatus;
wire adcFaSynced, adcSaSynced;
acqSync acqADCSync(
    .sysClk(sysClk),
    .sysGPIO_OUT(GPIO_OUT),
    .sysFAstrobe(GPIO_STROBES[GPIO_IDX_ADC_FA_RELOAD]),
    .sysSAstrobe(GPIO_STROBES[GPIO_IDX_ADC_SA_RELOAD]),
    .sysFAstatus(sysADCFAstatus),
    .sysSAstatus(sysADCSAstatus),
    .evrClk(adcClk),
    .evrHeartbeat(adcHeartbeat),
    .evrFaMarker(adcFaMarker),
    .evrSaMarker(adcSaMarker));
assign GPIO_IN[GPIO_IDX_ADC_FA_RELOAD] = sysADCFAstatus;
assign GPIO_IN[GPIO_IDX_ADC_SA_RELOAD] = sysADCSAstatus;
assign adcFaSynced = sysADCFAstatus[31];
assign adcSaSynced = sysADCSAstatus[31];

//
// Forward the EVR trigger bus and time stamp to the ADC clock domain.
//
wire [63:0] adcTimestamp;
wire [71:0] evrForward, adcForward;
assign evrForward = { evrTriggerBus, evrTimestamp };
forwardData #(.DATA_WIDTH(72))
  forwardTimestampToADC(.inClk(evrClk),
             .inData(evrForward),
             .outClk(adcClk),
             .outData(adcForward));
assign adcTimestamp = adcForward[63:0];

//
// Forward the EVR trigger bus and time stamp to the system clock domain.
//
wire [63:0] sysTimestamp;
wire [71:0] sysForward;
forwardData #(.DATA_WIDTH(72))
  forwardTimestampToSys(.inClk(evrClk),
             .inData(evrForward),
             .outClk(sysClk),
             .outData(sysForward));
assign sysTimestamp = sysForward[63:0];

//
// Preliminary processing (compute magnitude of ADC signals)
//
wire sysSingleTrig [0:CFG_DSBPM_COUNT-1];
wire [32-MAG_WIDTH-1:0] magPAD = 0;
wire                 adcLoSynced[0:CFG_DSBPM_COUNT-1];
wire                 adcTbtLoadAccumulator[0:CFG_DSBPM_COUNT-1];
wire                 adcTbtLatchAccumulator[0:CFG_DSBPM_COUNT-1];
wire                 adcMtLoadAndLatch[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADC0[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADC1[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADC2[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADC3[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADCQ0[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADCQ1[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADCQ2[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADCQ3[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADC0Mag[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADC1Mag[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADC2Mag[0:CFG_DSBPM_COUNT-1];
wire [AXI_SAMPLE_WIDTH-1:0] prelimProcADC3Mag[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcADCValid[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcTbtToggle[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcRfTbtMagValid[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfTbtMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfTbtMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfTbtMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfTbtMag3[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcFaToggle[0:CFG_DSBPM_COUNT-1];
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
wire                 prelimProcSaToggle[0:CFG_DSBPM_COUNT-1];
wire                 prelimProcSaValid[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcRfMag3[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPlMag3[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhMag0[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhMag1[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhMag2[0:CFG_DSBPM_COUNT-1];
wire [MAG_WIDTH-1:0] prelimProcPhMag3[0:CFG_DSBPM_COUNT-1];
wire [8*PRODUCT_WIDTH-1:0] rfProducts[0:CFG_DSBPM_COUNT-1];
wire [8*PRODUCT_WIDTH-1:0] plProducts[0:CFG_DSBPM_COUNT-1];
wire [8*PRODUCT_WIDTH-1:0] phProducts[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] rfLOcos[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] rfLOsin[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] plLOcos[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] plLOsin[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] phLOcos[0:CFG_DSBPM_COUNT-1];
wire [LO_WIDTH-1:0] phLOsin[0:CFG_DSBPM_COUNT-1];
wire prelimProcPtToggle[0:CFG_DSBPM_COUNT-1];
wire prelimProcOverflow[0:CFG_DSBPM_COUNT-1];
wire [8*MAG_WIDTH-1:0] tbtSums[0:CFG_DSBPM_COUNT-1];
wire tbtSumsValid[0:CFG_DSBPM_COUNT-1];
wire [4*MAG_WIDTH-1:0] tbtMags[0:CFG_DSBPM_COUNT-1];
wire tbtMagsValid[0:CFG_DSBPM_COUNT-1];
wire [(CFG_DSBPM_COUNT*CFG_DSP_CHANNEL_COUNT*ACQ_SAMPLES_WIDTH)-1:0] acqTDATA;
wire [CFG_DSBPM_COUNT*CFG_DSP_CHANNEL_COUNT-1:0] acqTVALID;
wire [CFG_DSBPM_COUNT*CFG_DSP_CHANNEL_COUNT-1:0] acqTCLK;

generate
if (IQ_DATA != "TRUE") begin
    IQ_DATA_false_NOT_SUPPORTED();
end
endgenerate

localparam ADC_SIGNALS_PER_DSP = CFG_ADC_CHANNEL_COUNT / CFG_DSBPM_COUNT;

generate
for (dsbpm = 0 ; dsbpm < CFG_DSBPM_COUNT ; dsbpm = dsbpm + 1) begin : prelim_chain

assign GPIO_IN[GPIO_IDX_PRELIM_STATUS + dsbpm*GPIO_IDX_PER_DSBPM] = {
    {32-1{1'b0}},
    prelimProcOverflow[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_RF_MAG_0 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcRfMag0[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_RF_MAG_1 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcRfMag1[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_RF_MAG_2 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcRfMag2[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_RF_MAG_3 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcRfMag3[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_PT_LO_MAG_0 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcPlMag0[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_PT_LO_MAG_1 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcPlMag1[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_PT_LO_MAG_2 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcPlMag2[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_PT_LO_MAG_3 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcPlMag3[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_PT_HI_MAG_0 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcPhMag0[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_PT_HI_MAG_1 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcPhMag1[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_PT_HI_MAG_2 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcPhMag2[dsbpm] };
assign GPIO_IN[GPIO_IDX_PRELIM_PT_HI_MAG_3 + dsbpm*GPIO_IDX_PER_DSBPM] = {
    magPAD, prelimProcPhMag3[dsbpm] };
preliminaryProcessing #(.SYSCLK_RATE(SYSCLK_RATE),
                        .ADC_WIDTH(AXI_SAMPLE_WIDTH),
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
    .adcClk(adcClk),
    .adc0(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 0)*SAMPLES_WIDTH+:SAMPLES_WIDTH]), // I0
    .adc1(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 2)*SAMPLES_WIDTH+:SAMPLES_WIDTH]), // I1
    .adc2(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 4)*SAMPLES_WIDTH+:SAMPLES_WIDTH]), // I2
    .adc3(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 6)*SAMPLES_WIDTH+:SAMPLES_WIDTH]), // I3
    .adcQ0(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 1)*SAMPLES_WIDTH+:SAMPLES_WIDTH]), // Q0
    .adcQ1(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 3)*SAMPLES_WIDTH+:SAMPLES_WIDTH]), // Q1
    .adcQ2(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 5)*SAMPLES_WIDTH+:SAMPLES_WIDTH]), // Q2
    .adcQ3(adcsTDATA[(dsbpm*ADC_SIGNALS_PER_DSP + 7)*SAMPLES_WIDTH+:SAMPLES_WIDTH]), // Q3
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
    .adcExceedsThreshold(1'b0),
    .adcUseThisSample(1'b1),
    .evrClk(evrClk),
    .evrFaMarker(evrFaMarker),
    .evrSaMarker(evrSaMarker),
    .evrTimestamp(evrTimestamp),
    .evrPtTrigger(1'b0),
    .evrSinglePassTrigger(1'b0),
    .evrHbMarker(evrHeartbeat),
    .sysSingleTrig(sysSingleTrig[dsbpm]),
    .sysTimestamp(sysTimestamp),
    .PT_P(),
    .PT_N(),
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
    .adcLoSynced(adcLoSynced[dsbpm]),
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
    .tbtToggle(prelimProcTbtToggle[dsbpm]),
    .rfTbtMagValid(prelimProcRfTbtMagValid[dsbpm]),
    .rfTbtMag0(prelimProcRfTbtMag0[dsbpm]),
    .rfTbtMag1(prelimProcRfTbtMag1[dsbpm]),
    .rfTbtMag2(prelimProcRfTbtMag2[dsbpm]),
    .rfTbtMag3(prelimProcRfTbtMag3[dsbpm]),
    .cicFaMagValidDbg(prelimProcRfCicFaMagValid[dsbpm]),
    .cicFaMag0Dbg(prelimProcRfCicFaMag0[dsbpm]),
    .cicFaMag1Dbg(prelimProcRfCicFaMag1[dsbpm]),
    .cicFaMag2Dbg(prelimProcRfCicFaMag2[dsbpm]),
    .cicFaMag3Dbg(prelimProcRfCicFaMag3[dsbpm]),
    .faToggle(prelimProcFaToggle[dsbpm]),
    .adcTbtLoadAccumulator(adcTbtLoadAccumulator[dsbpm]),
    .adcTbtLatchAccumulator(adcTbtLatchAccumulator[dsbpm]),
    .adcMtLoadAndLatch(adcMtLoadAndLatch[dsbpm]),
    .rfFaMagValid(prelimProcRfFaMagValid[dsbpm]),
    .rfFaMag0(prelimProcRfFaMag0[dsbpm]),
    .rfFaMag1(prelimProcRfFaMag1[dsbpm]),
    .rfFaMag2(prelimProcRfFaMag2[dsbpm]),
    .rfFaMag3(prelimProcRfFaMag3[dsbpm]),
    .saToggle(prelimProcSaToggle[dsbpm]),
    .saValid(prelimProcSaValid[dsbpm]),
    .sysSaTimestamp({GPIO_IN[GPIO_IDX_SA_TIMESTAMP_SEC + dsbpm*GPIO_IDX_PER_DSBPM],
                     GPIO_IN[GPIO_IDX_SA_TIMESTAMP_TICKS + dsbpm*GPIO_IDX_PER_DSBPM]}),
    .rfMag0(prelimProcRfMag0[dsbpm]),
    .rfMag1(prelimProcRfMag1[dsbpm]),
    .rfMag2(prelimProcRfMag2[dsbpm]),
    .rfMag3(prelimProcRfMag3[dsbpm]),
    .plMag0(prelimProcPlMag0[dsbpm]),
    .plMag1(prelimProcPlMag1[dsbpm]),
    .plMag2(prelimProcPlMag2[dsbpm]),
    .plMag3(prelimProcPlMag3[dsbpm]),
    .phMag0(prelimProcPhMag0[dsbpm]),
    .phMag1(prelimProcPhMag1[dsbpm]),
    .phMag2(prelimProcPhMag2[dsbpm]),
    .phMag3(prelimProcPhMag3[dsbpm]),
    .ptToggle(prelimProcPtToggle[dsbpm]),
    .overflowFlag(prelimProcOverflow[dsbpm])
);

end // for
endgenerate // generate

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
    .faInToggle(prelimProcFaToggle[dsbpm]),
    .sa0(prelimProcRfMag0[dsbpm]),
    .sa1(prelimProcRfMag1[dsbpm]),
    .sa2(prelimProcRfMag2[dsbpm]),
    .sa3(prelimProcRfMag3[dsbpm]),
    .saInToggle(prelimProcSaToggle[dsbpm]),
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

end // for
endgenerate // generate

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
