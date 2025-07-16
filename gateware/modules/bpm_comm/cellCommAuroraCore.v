//
// Send FA data to neighbours
//
module cellCommAuroraCore #(
    parameter CCW_MGT_DEBUG        = "false",
    parameter CCW_CONVERSION_DEBUG = "false",
    parameter CW_MGT_DEBUG         = "false",
    parameter CW_CONVERSION_DEBUG  = "false") (
    input  wire                    sysClk,
    input  wire             [31:0] sysGpioData,

    input  wire                    sysCCWCsrStrobe,
    output wire             [31:0] sysCCWCsr,

    input  wire                    sysCWCsrStrobe,
    output wire             [31:0] sysCWCsr,

    input  wire                    GT_REFCLK,

    output wire                    CCW_TX_N,
    output wire                    CCW_TX_P,
    input  wire                    CCW_RX_N,
    input  wire                    CCW_RX_P,

    output wire                    CW_TX_N,
    output wire                    CW_TX_P,
    input  wire                    CW_RX_N,
    input  wire                    CW_RX_P,

    // CCW AXIS
    output wire                    ccwAxisUserClk,
    output wire                    ccwAxisUserReset,

    output wire                    ccwChannelUp,

    input  wire                    ccwAxisTxTvalid,
    input  wire                    ccwAxisTxTlast,
    input  wire             [31:0] ccwAxisTxTdata,
    output wire                    ccwAxisTxTready,

    output wire                    ccwAxisRxTvalid,
    output wire                    ccwAxisRxTlast,
    output wire             [31:0] ccwAxisRxTdata,
    output wire                    ccwAxisRxCRCvalid,
    output wire                    ccwAxisRxCRCpass,

    // CW AXIS
    output wire                    cwAxisUserClk,
    output wire                    cwAxisUserReset,

    output wire                    cwChannelUp,

    input  wire                    cwAxisTxTvalid,
    input  wire                    cwAxisTxTlast,
    input  wire             [31:0] cwAxisTxTdata,
    output wire                    cwAxisTxTready,

    output wire                    cwAxisRxTvalid,
    output wire                    cwAxisRxTlast,
    output wire             [31:0] cwAxisRxTdata,
    output wire                    cwAxisRxCRCvalid,
    output wire                    cwAxisRxCRCpass,

    output reg              [31:0] ccwCRCfaults = 0,
    output reg              [31:0] cwCRCfaults = 0);

///////////////////////////////////////////////////////////////////////////////
//                                 CCW link                                  //
///////////////////////////////////////////////////////////////////////////////

//
// CCW Aurora block
//

wire ccwAuMGTclk;
wire ccwAuUserClk;
wire ccwAuUserReset;
wire ccwMmcmLocked;

wire ccwMgtHardErr;
wire ccwMgtSoftErr;
wire ccwMgtLaneUp;
wire ccwMgtChannelUP;
wire ccwMgtTxResetDone;
wire ccwMgtRxResetDone;
wire ccwMgtMmcmNotLocked;

wire [7:0] ccwAxisRxTuser;

auroraLink #(
    .MGT_DEBUG(CCW_MGT_DEBUG),
    .CONVERSION_DEBUG(CCW_CONVERSION_DEBUG),
    .USE_INTERNAL_MMCM("true")
) auroraCellCommCCW (
    .sysClk(sysClk),
    .GPIO_OUT(sysGpioData),
    .mgtCSR(sysCCWCsr),
    .mgtCSRstrobe(sysCCWCsrStrobe),

    .refClk(GT_REFCLK),
    .MGT_TX_P(CCW_TX_P),
    .MGT_TX_N(CCW_TX_N),
    .MGT_RX_P(CCW_RX_P),
    .MGT_RX_N(CCW_RX_N),

    // Clocks in case of USE_INTERNAL_MMCM = "true"
    .auMGTclkOut(ccwAuMGTclk),
    .auUserClkOut(ccwAuUserClk),
    .auUserResetOut(ccwAuUserReset),
    .mmcmLockedOut(ccwMmcmLocked),

    .axiRxTdata(ccwAxisRxTdata),
    .axiRxTkeep(),
    .axiRxTuser(ccwAxisRxTuser),
    .axiRxTlast(ccwAxisRxTlast),
    .axiRxTvalid(ccwAxisRxTvalid),

    .axiTxTdata(ccwAxisTxTdata),
    .axiTxTready(ccwAxisTxTready),
    .axiTxTlast(ccwAxisTxTlast),
    .axiTxTvalid(ccwAxisTxTvalid),

    // Status from aurora core
    .mgtHardErr(ccwMgtHardErr),
    .mgtSoftErr(ccwMgtSoftErr),
    .mgtLaneUp(ccwMgtLaneUp),
    .mgtChannelUP(ccwMgtChannelUP),
    .mgtTxResetDone(ccwMgtTxResetDone),
    .mgtRxResetDone(ccwMgtRxResetDone),
    .mgtMmcmNotLocked(ccwMgtMmcmNotLocked)
);

assign ccwAxisUserClk = ccwAuUserClk;
assign ccwAxisUserReset = ccwAuUserReset;
assign ccwChannelUp = ccwMgtChannelUP;
assign ccwAxisRxCRCpass = ccwAxisRxTuser[0];
assign ccwAxisRxCRCvalid = ccwAxisRxTuser[1];

always @(posedge ccwAxisUserClk) begin
    if (ccwAxisRxCRCvalid && !ccwAxisRxCRCpass) ccwCRCfaults <= ccwCRCfaults + 1;
end

///////////////////////////////////////////////////////////////////////////////
//                                 CW link                                  //
///////////////////////////////////////////////////////////////////////////////

//
// CW Aurora block
//

wire cwAuMGTclk = ccwAuMGTclk;
wire cwAuUserClk = ccwAuUserClk;
wire cwMmcmLocked = ccwMmcmLocked;

wire cwAuUserReset;

wire cwMgtHardErr;
wire cwMgtSoftErr;
wire cwMgtLaneUp;
wire cwMgtChannelUP;
wire cwMgtTxResetDone;
wire cwMgtRxResetDone;
wire cwMgtMmcmNotLocked;

wire [7:0] cwAxisRxTuser;

auroraLink #(
    .MGT_DEBUG(CW_MGT_DEBUG),
    .CONVERSION_DEBUG(CW_CONVERSION_DEBUG),
    .USE_INTERNAL_MMCM("false")
) auroraCellCommCW (
    .sysClk(sysClk),
    .GPIO_OUT(sysGpioData),
    .mgtCSR(sysCWCsr),
    .mgtCSRstrobe(sysCWCsrStrobe),
    .auResetOut(),

    .refClk(GT_REFCLK),
    .MGT_TX_P(CW_TX_P),
    .MGT_TX_N(CW_TX_N),
    .MGT_RX_P(CW_RX_P),
    .MGT_RX_N(CW_RX_N),

    // Clocks in case of USE_INTERNAL_MMCM = "false"
    .auMGTclkIn(cwAuMGTclk),
    .auUserClkIn(cwAuUserClk),
    .mmcmLockedIn(cwMmcmLocked),

    .auUserResetOut(cwAuUserReset),

    .axiRxTdata(cwAxisRxTdata),
    .axiRxTkeep(),
    .axiRxTuser(cwAxisRxTuser),
    .axiRxTlast(cwAxisRxTlast),
    .axiRxTvalid(cwAxisRxTvalid),

    .axiTxTdata(cwAxisTxTdata),
    .axiTxTready(cwAxisTxTready),
    .axiTxTlast(cwAxisTxTlast),
    .axiTxTvalid(cwAxisTxTvalid),

    // Status from aurora core
    .mgtHardErr(cwMgtHardErr),
    .mgtSoftErr(cwMgtSoftErr),
    .mgtLaneUp(cwMgtLaneUp),
    .mgtChannelUP(cwMgtChannelUP),
    .mgtTxResetDone(cwMgtTxResetDone),
    .mgtRxResetDone(cwMgtRxResetDone),
    .mgtMmcmNotLocked(cwMgtMmcmNotLocked)
);

assign cwAxisUserClk = cwAuUserClk;
assign cwAxisUserReset = cwAuUserReset;
assign cwChannelUp = cwMgtChannelUP;
assign cwAxisRxCRCpass = cwAxisRxTuser[0];
assign cwAxisRxCRCvalid = cwAxisRxTuser[1];

always @(posedge cwAxisUserClk) begin
    if (cwAxisRxCRCvalid && !cwAxisRxCRCpass) cwCRCfaults <= cwCRCfaults + 1;
end

endmodule
