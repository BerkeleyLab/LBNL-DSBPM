//
// Send FA data to neighbours
//
module cellCommBPM #(
    parameter ADC_COUNT      = 4,
    parameter FOFB_IDX_WIDTH = 9,
    parameter DATA_WIDTH     = 32) (
    input  wire                   sysClk,
    input  wire                   sysCsrStrobe,
    input  wire            [31:0] sysGpioData,
    output wire            [31:0] sysCsr,

    input  wire  [DATA_WIDTH-1:0] sysFA_X,
    input  wire  [DATA_WIDTH-1:0] sysFA_Y,
    input  wire  [DATA_WIDTH-1:0] sysFA_S,
    input  wire                   sysFaToggle,
    input  wire   [ADC_COUNT-1:0] sysClippedAdc,

    // CW AXIS
    input wire                    cwAxisUserClk,

    input wire                    cwChannelUp,

    output wire                   cwAxisTxTvalid,
    output wire                   cwAxisTxTlast,
    output wire            [31:0] cwAxisTxTdata,
    input  wire                   cwAxisTxTready,

    input wire                    cwAxisRxTvalid,
    input wire                    cwAxisRxTlast,
    input wire             [31:0] cwAxisRxTdata,
    input wire                    cwAxisRxCRCvalid,
    input wire                    cwAxisRxCRCpass,

    // CCW AXIS
    input wire                    ccwAxisUserClk,

    input wire                    ccwChannelUp,

    output wire                   ccwAxisTxTvalid,
    output wire                   ccwAxisTxTlast,
    output wire            [31:0] ccwAxisTxTdata,
    input  wire                   ccwAxisTxTready,

    input wire                    ccwAxisRxTvalid,
    input wire                    ccwAxisRxTlast,
    input wire             [31:0] ccwAxisRxTdata,
    input wire                    ccwAxisRxCRCvalid,
    input wire                    ccwAxisRxCRCpass);

// Reduce ADC status to a single bit
wire sysIsClipping;
assign sysIsClipping = |sysClippedAdc;

//
// Microblaze interface
//
reg                     sysFOFBvalid = 0;
reg [FOFB_IDX_WIDTH-1:0] sysFOFBindex = ~0;
assign sysCsr = { {16-1-FOFB_IDX_WIDTH{1'b0}}, sysFOFBvalid, sysFOFBindex,
                  {16{1'b0}} };
always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        if (sysGpioData[FOFB_IDX_WIDTH+16+1]) begin
            sysFOFBvalid <= sysGpioData[FOFB_IDX_WIDTH+16];
            sysFOFBindex <= sysGpioData[FOFB_IDX_WIDTH+16-1:16];
        end
    end
end

///////////////////////////////////////////////////////////////////////////////
//                             Data Forwarding                               //
///////////////////////////////////////////////////////////////////////////////
cellCommDataSwitch #(
    .FOFB_IDX_WIDTH(FOFB_IDX_WIDTH),
    .DATA_WIDTH(DATA_WIDTH))
  sendToCCW(
    .sysClk(sysClk),
    .sysIsClipping(sysIsClipping),
    .sysFA_X(sysFA_X),
    .sysFA_Y(sysFA_Y),
    .sysFA_S(sysFA_S),
    .sysFaToggle(sysFaToggle),
    .sysFOFBvalid(sysFOFBvalid),
    .sysFOFBindex(sysFOFBindex),
    .rxClk(cwAxisUserClk),
    .rxValid(cwAxisRxTvalid),
    .rxLast(cwAxisRxTlast),
    .rxData(cwAxisRxTdata),
    .rxCRCvalid(cwAxisRxCRCvalid),
    .rxCRCpass(cwAxisRxCRCpass),
    .txClk(ccwAxisUserClk),
    .txAuroraChannelUp(ccwChannelUp),
    .txValid(ccwAxisTxTvalid),
    .txLast(ccwAxisTxTlast),
    .txData(ccwAxisTxTdata),
    .txReady(ccwAxisTxTready));

cellCommDataSwitch #(
    .FOFB_IDX_WIDTH(FOFB_IDX_WIDTH),
    .DATA_WIDTH(DATA_WIDTH))
  sendToCW(
    .sysClk(sysClk),
    .sysIsClipping(sysIsClipping),
    .sysFA_X(sysFA_X),
    .sysFA_Y(sysFA_Y),
    .sysFA_S(sysFA_S),
    .sysFaToggle(sysFaToggle),
    .sysFOFBvalid(sysFOFBvalid),
    .sysFOFBindex(sysFOFBindex),
    .rxClk(ccwAxisUserClk),
    .rxValid(ccwAxisRxTvalid),
    .rxLast(ccwAxisRxTlast),
    .rxData(ccwAxisRxTdata),
    .rxCRCvalid(ccwAxisRxCRCvalid),
    .rxCRCpass(ccwAxisRxCRCpass),
    .txClk(cwAxisUserClk),
    .txAuroraChannelUp(cwChannelUp),
    .txValid(cwAxisTxTvalid),
    .txLast(cwAxisTxTlast),
    .txData(cwAxisTxTdata),
    .txReady(cwAxisTxTready));

endmodule
