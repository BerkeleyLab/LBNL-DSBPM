//
// Send FA data to neighbours, with N BPM numbers
//
module cellCommBPMCore #(
    parameter NUM_BPMS       = 2,
    parameter ADC_COUNT      = 4,
    parameter FOFB_IDX_WIDTH = 9,
    parameter DATA_WIDTH     = 32) (
    input  wire                            sysClk,
    input  wire             [NUM_BPMS-1:0] sysCsrStrobe,
    input  wire                     [31:0] sysGpioData,
    output wire          [NUM_BPMS*32-1:0] sysCsr,

    input  wire  [NUM_BPMS*DATA_WIDTH-1:0] sysFA_X,
    input  wire  [NUM_BPMS*DATA_WIDTH-1:0] sysFA_Y,
    input  wire  [NUM_BPMS*DATA_WIDTH-1:0] sysFA_S,
    input  wire             [NUM_BPMS-1:0] sysFaToggle,
    input  wire   [NUM_BPMS*ADC_COUNT-1:0] sysClippedAdc,

    // CW AXIS
    input wire           cwAxisUserClk,
    input wire           cwAxisUserReset,

    input wire           cwChannelUp,

    output wire          cwAxisTxTvalid,
    output wire          cwAxisTxTlast,
    output wire   [31:0] cwAxisTxTdata,
    input  wire          cwAxisTxTready,

    input wire           cwAxisRxTvalid,
    input wire           cwAxisRxTlast,
    input wire    [31:0] cwAxisRxTdata,
    input wire           cwAxisRxCRCvalid,
    input wire           cwAxisRxCRCpass,

    // CCW AXIS
    input wire           ccwAxisUserClk,
    input wire           ccwAxisUserReset,

    input wire           ccwChannelUp,

    output wire          ccwAxisTxTvalid,
    output wire          ccwAxisTxTlast,
    output wire   [31:0] ccwAxisTxTdata,
    input  wire          ccwAxisTxTready,

    input wire           ccwAxisRxTvalid,
    input wire           ccwAxisRxTlast,
    input wire    [31:0] ccwAxisRxTdata,
    input wire           ccwAxisRxCRCvalid,
    input wire           ccwAxisRxCRCpass);

// This is defined by the Mux module below
localparam MAX_NUM_BPMS = 4;

generate
if (NUM_BPMS > MAX_NUM_BPMS) begin
    cellCommBPMCore_NUM_BPMS_CANNOT_BE_GREATER_THAN_4 error();
end
endgenerate

wire        bpmCwAxisUserClk[0:MAX_NUM_BPMS-1];
wire        bpmCwAxisUserReset[0:MAX_NUM_BPMS-1];
wire        bpmCwChannelUp[0:MAX_NUM_BPMS-1];

wire        bpmCwAxisTxTvalid[0:MAX_NUM_BPMS-1];
wire        bpmCwAxisTxTlast[0:MAX_NUM_BPMS-1];
wire [31:0] bpmCwAxisTxTdata[0:MAX_NUM_BPMS-1];
wire        bpmCwAxisTxTready[0:MAX_NUM_BPMS-1];

wire        bpmCwAxisRxTvalid[0:MAX_NUM_BPMS-1];
wire        bpmCwAxisRxTlast[0:MAX_NUM_BPMS-1];
wire [31:0] bpmCwAxisRxTdata[0:MAX_NUM_BPMS-1];
wire        bpmCwAxisRxCRCvalid[0:MAX_NUM_BPMS-1];
wire        bpmCwAxisRxCRCpass[0:MAX_NUM_BPMS-1];

wire        bpmCcwAxisUserClk[0:MAX_NUM_BPMS-1];
wire        bpmCcwAxisUserReset[0:MAX_NUM_BPMS-1];
wire        bpmCcwChannelUp[0:MAX_NUM_BPMS-1];

wire        bpmCcwAxisTxTvalid[0:MAX_NUM_BPMS-1];
wire        bpmCcwAxisTxTlast[0:MAX_NUM_BPMS-1];
wire [31:0] bpmCcwAxisTxTdata[0:MAX_NUM_BPMS-1];
wire        bpmCcwAxisTxTready[0:MAX_NUM_BPMS-1];

wire        bpmCcwAxisRxTvalid[0:MAX_NUM_BPMS-1];
wire        bpmCcwAxisRxTlast[0:MAX_NUM_BPMS-1];
wire [31:0] bpmCcwAxisRxTdata[0:MAX_NUM_BPMS-1];
wire        bpmCcwAxisRxCRCvalid[0:MAX_NUM_BPMS-1];
wire        bpmCcwAxisRxCRCpass[0:MAX_NUM_BPMS-1];

// Common signals for all channels
genvar i;
generate for(i = 0; i < MAX_NUM_BPMS; i = i + 1) begin

assign bpmCwAxisUserClk[i] = cwAxisUserClk;
assign bpmCwChannelUp[i] = cwChannelUp;
assign bpmCwAxisUserReset[i] = cwAxisUserReset;

assign bpmCcwAxisUserClk[i] = ccwAxisUserClk;
assign bpmCcwChannelUp[i] = ccwChannelUp;
assign bpmCcwAxisUserReset[i] = ccwAxisUserReset;

end
endgenerate

generate for(i = 0; i < NUM_BPMS; i = i + 1) begin

cellCommBPM #(
    .ADC_COUNT(ADC_COUNT),
    .FOFB_IDX_WIDTH(FOFB_IDX_WIDTH),
    .DATA_WIDTH(DATA_WIDTH))
  cellCommBPM (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe[i]),
    .sysGpioData(sysGpioData),
    .sysCsr(sysCsr[i*32+:32]),

    .sysFA_X(sysFA_X[i*DATA_WIDTH+:DATA_WIDTH]),
    .sysFA_Y(sysFA_Y[i*DATA_WIDTH+:DATA_WIDTH]),
    .sysFA_S(sysFA_S[i*DATA_WIDTH+:DATA_WIDTH]),
    .sysFaToggle(sysFaToggle[i]),
    .sysClippedAdc(sysClippedAdc[i*ADC_COUNT+:ADC_COUNT]),

    // CW AXIS
    .cwAxisUserClk(bpmCwAxisUserClk[i]),

    .cwChannelUp(bpmCwChannelUp[i]),

    .cwAxisTxTvalid(bpmCwAxisTxTvalid[i]),
    .cwAxisTxTlast(bpmCwAxisTxTlast[i]),
    .cwAxisTxTdata(bpmCwAxisTxTdata[i]),
    .cwAxisTxTready(bpmCwAxisTxTready[i]),

    .cwAxisRxTvalid(bpmCwAxisRxTvalid[i]),
    .cwAxisRxTlast(bpmCwAxisRxTlast[i]),
    .cwAxisRxTdata(bpmCwAxisRxTdata[i]),
    .cwAxisRxCRCvalid(bpmCwAxisRxCRCvalid[i]),
    .cwAxisRxCRCpass(bpmCwAxisRxCRCpass[i]),

    // CCW AXIS
    .ccwAxisUserClk(bpmCcwAxisUserClk[i]),

    .ccwChannelUp(bpmCcwChannelUp[i]),

    .ccwAxisTxTvalid(bpmCcwAxisTxTvalid[i]),
    .ccwAxisTxTlast(bpmCcwAxisTxTlast[i]),
    .ccwAxisTxTdata(bpmCcwAxisTxTdata[i]),
    .ccwAxisTxTready(bpmCcwAxisTxTready[i]),

    .ccwAxisRxTvalid(bpmCcwAxisRxTvalid[i]),
    .ccwAxisRxTlast(bpmCcwAxisRxTlast[i]),
    .ccwAxisRxTdata(bpmCcwAxisRxTdata[i]),
    .ccwAxisRxCRCvalid(bpmCcwAxisRxCRCvalid[i]),
    .ccwAxisRxCRCpass(bpmCcwAxisRxCRCpass[i]));

end
endgenerate

generate for(i = NUM_BPMS; i < MAX_NUM_BPMS; i = i + 1) begin

assign bpmCwAxisTxTvalid[i] = 1'b0;
assign bpmCwAxisTxTlast[i] = 1'b0;
assign bpmCwAxisTxTdata[i] = 0;

assign bpmCcwAxisTxTvalid[i] = 1'b0;
assign bpmCcwAxisTxTlast[i] = 1'b0;
assign bpmCcwAxisTxTdata[i] = 0;

end
endgenerate

// Merge all CW BPMs
// 32-deep packet-mode FIFO incoming streams
`ifndef SIMULATE
cellCommMux
  cellCommCWMux (
    .ACLK(cwAxisUserClk),
    .ARESETN(~cwAxisUserReset),
    .S00_AXIS_ACLK(cwAxisUserClk),
    .S01_AXIS_ACLK(cwAxisUserClk),
    .S02_AXIS_ACLK(cwAxisUserClk),
    .S03_AXIS_ACLK(cwAxisUserClk),
    .S00_AXIS_ARESETN(~cwAxisUserReset),
    .S01_AXIS_ARESETN(~cwAxisUserReset),
    .S02_AXIS_ARESETN(~cwAxisUserReset),
    .S03_AXIS_ARESETN(~cwAxisUserReset),
    .S00_AXIS_TVALID(bpmCwAxisTxTvalid[0]),
    .S00_AXIS_TDATA(bpmCwAxisTxTdata[0]),
    .S00_AXIS_TLAST(bpmCwAxisTxTlast[0]),
    .S00_AXIS_TREADY(bpmCwAxisTxTready[0]),
    .S01_AXIS_TVALID(bpmCwAxisTxTvalid[1]),
    .S01_AXIS_TDATA(bpmCwAxisTxTdata[1]),
    .S01_AXIS_TLAST(bpmCwAxisTxTlast[1]),
    .S01_AXIS_TREADY(bpmCwAxisTxTready[1]),
    .S02_AXIS_TVALID(bpmCwAxisTxTvalid[2]),
    .S02_AXIS_TDATA(bpmCwAxisTxTdata[2]),
    .S02_AXIS_TLAST(bpmCwAxisTxTlast[2]),
    .S02_AXIS_TREADY(bpmCwAxisTxTready[2]),
    .S03_AXIS_TVALID(bpmCwAxisTxTvalid[3]),
    .S03_AXIS_TDATA(bpmCwAxisTxTdata[3]),
    .S03_AXIS_TLAST(bpmCwAxisTxTlast[3]),
    .S03_AXIS_TREADY(bpmCwAxisTxTready[3]),
    .M00_AXIS_ACLK(cwAxisUserClk),
    .M00_AXIS_ARESETN(~cwAxisUserReset),
    .M00_AXIS_TVALID(cwAxisTxTvalid),
    .M00_AXIS_TREADY(cwAxisTxTready),
    .M00_AXIS_TDATA(cwAxisTxTdata),
    .M00_AXIS_TLAST(cwAxisTxTlast),
    .S00_ARB_REQ_SUPPRESS(1'b0),
    .S01_ARB_REQ_SUPPRESS(1'b0),
    .S02_ARB_REQ_SUPPRESS(1'b0),
    .S03_ARB_REQ_SUPPRESS(1'b0));
`endif

// Merge all CCW BPMs
// 32-deep packet-mode FIFO incoming streams
`ifndef SIMULATE
cellCommMux
  cellCommCCWMux (
    .ACLK(ccwAxisUserClk),
    .ARESETN(~ccwAxisUserReset),
    .S00_AXIS_ACLK(ccwAxisUserClk),
    .S01_AXIS_ACLK(ccwAxisUserClk),
    .S02_AXIS_ACLK(ccwAxisUserClk),
    .S03_AXIS_ACLK(ccwAxisUserClk),
    .S00_AXIS_ARESETN(~ccwAxisUserReset),
    .S01_AXIS_ARESETN(~ccwAxisUserReset),
    .S02_AXIS_ARESETN(~ccwAxisUserReset),
    .S03_AXIS_ARESETN(~ccwAxisUserReset),
    .S00_AXIS_TVALID(bpmccwAxisTxTvalid[0]),
    .S00_AXIS_TDATA(bpmccwAxisTxTdata[0]),
    .S00_AXIS_TLAST(bpmccwAxisTxTlast[0]),
    .S00_AXIS_TREADY(bpmccwAxisTxTready[0]),
    .S01_AXIS_TVALID(bpmccwAxisTxTvalid[1]),
    .S01_AXIS_TDATA(bpmccwAxisTxTdata[1]),
    .S01_AXIS_TLAST(bpmccwAxisTxTlast[1]),
    .S01_AXIS_TREADY(bpmccwAxisTxTready[1]),
    .S02_AXIS_TVALID(bpmccwAxisTxTvalid[2]),
    .S02_AXIS_TDATA(bpmccwAxisTxTdata[2]),
    .S02_AXIS_TLAST(bpmccwAxisTxTlast[2]),
    .S02_AXIS_TREADY(bpmccwAxisTxTready[2]),
    .S03_AXIS_TVALID(bpmccwAxisTxTvalid[3]),
    .S03_AXIS_TDATA(bpmccwAxisTxTdata[3]),
    .S03_AXIS_TLAST(bpmccwAxisTxTlast[3]),
    .S03_AXIS_TREADY(bpmccwAxisTxTready[3]),
    .M00_AXIS_ACLK(ccwAxisUserClk),
    .M00_AXIS_ARESETN(~ccwAxisUserReset),
    .M00_AXIS_TVALID(ccwAxisTxTvalid),
    .M00_AXIS_TREADY(ccwAxisTxTready),
    .M00_AXIS_TDATA(ccwAxisTxTdata),
    .M00_AXIS_TLAST(ccwAxisTxTlast),
    .S00_ARB_REQ_SUPPRESS(1'b0),
    .S01_ARB_REQ_SUPPRESS(1'b0),
    .S02_ARB_REQ_SUPPRESS(1'b0),
    .S03_ARB_REQ_SUPPRESS(1'b0));
`endif

endmodule
