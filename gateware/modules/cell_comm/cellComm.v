//
// Wrapper around CW/CCW aurora cores and BPM data switches
//
module cellComm #(
    parameter NUM_BPMS             = 2,
    parameter ADC_COUNT            = 4,
    parameter FOFB_IDX_WIDTH       = 9,
    parameter DATA_WIDTH           = 32,
    parameter CCW_MGT_DEBUG        = "false",
    parameter CCW_CONVERSION_DEBUG = "false",
    parameter CW_MGT_DEBUG         = "false",
    parameter CW_CONVERSION_DEBUG  = "false"
) (
    input  wire                              sysClk,
    input  wire                       [31:0] sysGpioData,

    input  wire                              sysCCWCsrStrobe,
    output wire                       [31:0] sysCCWCsr,

    input  wire                              sysCWCsrStrobe,
    output wire                       [31:0] sysCWCsr,

    input  wire               [NUM_BPMS-1:0] sysBPMCsrStrobe,
    output wire            [NUM_BPMS*32-1:0] sysBPMCsr,

    input  wire    [NUM_BPMS*DATA_WIDTH-1:0] sysFA_X,
    input  wire    [NUM_BPMS*DATA_WIDTH-1:0] sysFA_Y,
    input  wire    [NUM_BPMS*DATA_WIDTH-1:0] sysFA_S,
    input  wire               [NUM_BPMS-1:0] sysFaToggle,
    input  wire     [NUM_BPMS*ADC_COUNT-1:0] sysClippedAdc,

    input  wire                              GT_REFCLK,

    output wire                              CCW_TX_N,
    output wire                              CCW_TX_P,
    input  wire                              CCW_RX_N,
    input  wire                              CCW_RX_P,

    output wire                              CCW_LED0,
    output wire                              CCW_LED1,

    output wire                              CW_TX_N,
    output wire                              CW_TX_P,
    input  wire                              CW_RX_N,
    input  wire                              CW_RX_P,

    output reg                        [31:0] ccwCRCfaults = 0,
    output reg                        [31:0] cwCRCfaults = 0);

// CW AXIS
wire         cwAxisUserClk;
wire         cwAxisUserReset;

wire         cwChannelUp;

wire         cwAxisTxTvalid;
wire         cwAxisTxTlast;
wire  [31:0] cwAxisTxTdata;
wire         cwAxisTxTready;

wire         cwAxisRxTvalid;
wire         cwAxisRxTlast;
wire  [31:0] cwAxisRxTdata;
wire         cwAxisRxCRCvalid;
wire         cwAxisRxCRCpass;

// CCW AXIS
wire         ccwAxisUserClk;
wire         ccwAxisUserReset;

wire         ccwChannelUp;

wire         ccwAxisTxTvalid;
wire         ccwAxisTxTlast;
wire  [31:0] ccwAxisTxTdata;
wire         ccwAxisTxTready;

wire         ccwAxisRxTvalid;
wire         ccwAxisRxTlast;
wire  [31:0] ccwAxisRxTdata;
wire         ccwAxisRxCRCvalid;
wire         ccwAxisRxCRCpass;

cellCommAuroraCore #(
    .CCW_MGT_DEBUG              (CCW_MGT_DEBUG),
    .CCW_CONVERSION_DEBUG       (CCW_CONVERSION_DEBUG),
    .CW_MGT_DEBUG               (CW_MGT_DEBUG),
    .CW_CONVERSION_DEBUG        (CW_CONVERSION_DEBUG))
  cellCommAuroraCore (
    .sysClk                     (sysClk),
    .sysGpioData                (sysGpioData),

    .sysCCWCsrStrobe            (sysCCWCsrStrobe),
    .sysCCWCsr                  (sysCCWCsr),

    .sysCWCsrStrobe             (sysCWCsrStrobe),
    .sysCWCsr                   (sysCWCsr),

    .GT_REFCLK                  (GT_REFCLK),

    .CCW_TX_N                   (CCW_TX_N),
    .CCW_TX_P                   (CCW_TX_P),
    .CCW_RX_N                   (CCW_RX_N),
    .CCW_RX_P                   (CCW_RX_P),

    .CW_TX_N                    (CW_TX_N),
    .CW_TX_P                    (CW_TX_P),
    .CW_RX_N                    (CW_RX_N),
    .CW_RX_P                    (CW_RX_P),

    // CCW AXIS
    .ccwAxisUserClk             (ccwAxisUserClk),
    .ccwAxisUserReset           (ccwAxisUserReset),

    .ccwChannelUp               (ccwChannelUp),

    .ccwAxisTxTvalid            (ccwAxisTxTvalid),
    .ccwAxisTxTlast             (ccwAxisTxTlast),
    .ccwAxisTxTdata             (ccwAxisTxTdata),
    .ccwAxisTxTready            (ccwAxisTxTready),

    .ccwAxisRxTvalid            (ccwAxisRxTvalid),
    .ccwAxisRxTlast             (ccwAxisRxTlast),
    .ccwAxisRxTdata             (ccwAxisRxTdata),
    .ccwAxisRxCRCvalid          (ccwAxisRxCRCvalid),
    .ccwAxisRxCRCpass           (ccwAxisRxCRCpass),

    // CW AXIS
    .cwAxisUserClk              (cwAxisUserClk),
    .cwAxisUserReset            (cwAxisUserReset),

    .cwChannelUp                (cwChannelUp),

    .cwAxisTxTvalid             (cwAxisTxTvalid),
    .cwAxisTxTlast              (cwAxisTxTlast),
    .cwAxisTxTdata              (cwAxisTxTdata),
    .cwAxisTxTready             (cwAxisTxTready),

    .cwAxisRxTvalid             (cwAxisRxTvalid),
    .cwAxisRxTlast              (cwAxisRxTlast),
    .cwAxisRxTdata              (cwAxisRxTdata),
    .cwAxisRxCRCvalid           (cwAxisRxCRCvalid),
    .cwAxisRxCRCpass            (cwAxisRxCRCpass),

    .ccwCRCfaults               (ccwCRCfaults),
    .cwCRCfaults                (cwCRCfaults)
);

cellCommBPMCore #(
    .NUM_BPMS                   (NUM_BPMS),
    .ADC_COUNT                  (ADC_COUNT),
    .FOFB_IDX_WIDTH             (FOFB_IDX_WIDTH),
    .DATA_WIDTH                 (DATA_WIDTH))
  cellCommBPMCore (
    .sysClk                     (sysClk),
    .sysCsrStrobe               (sysBPMCsrStrobe),
    .sysGpioData                (sysGpioData),
    .sysCsr                     (sysBPMCsr),

    .sysFA_X                    (sysFA_X),
    .sysFA_Y                    (sysFA_Y),
    .sysFA_S                    (sysFA_S),
    .sysFaToggle                (sysFaToggle),
    .sysClippedAdc              (sysClippedAdc),

    // CW AXIS
    .cwAxisUserClk              (cwAxisUserClk),
    .cwAxisUserReset            (cwAxisUserReset),

    .cwChannelUp                (cwChannelUp),

    .cwAxisTxTvalid             (cwAxisTxTvalid),
    .cwAxisTxTlast              (cwAxisTxTlast),
    .cwAxisTxTdata              (cwAxisTxTdata),
    .cwAxisTxTready             (cwAxisTxTready),

    .cwAxisRxTvalid             (cwAxisRxTvalid),
    .cwAxisRxTlast              (cwAxisRxTlast),
    .cwAxisRxTdata              (cwAxisRxTdata),
    .cwAxisRxCRCvalid           (cwAxisRxCRCvalid),
    .cwAxisRxCRCpass            (cwAxisRxCRCpass),

    // CCW AXIS
    .ccwAxisUserClk             (ccwAxisUserClk),
    .ccwAxisUserReset           (ccwAxisUserReset),

    .ccwChannelUp               (ccwChannelUp),

    .ccwAxisTxTvalid            (ccwAxisTxTvalid),
    .ccwAxisTxTlast             (ccwAxisTxTlast),
    .ccwAxisTxTdata             (ccwAxisTxTdata),
    .ccwAxisTxTready            (ccwAxisTxTready),

    .ccwAxisRxTvalid            (ccwAxisRxTvalid),
    .ccwAxisRxTlast             (ccwAxisRxTlast),
    .ccwAxisRxTdata             (ccwAxisRxTdata),
    .ccwAxisRxCRCvalid          (ccwAxisRxCRCvalid),
    .ccwAxisRxCRCpass           (ccwAxisRxCRCpass));

endmodule
