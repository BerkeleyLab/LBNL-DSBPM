//
// Map physical to logical channels
//
module channelMapping #(
    parameter NUM_CHANNELS      = 8,
    parameter CHANNEL_WIDTH     = 16
) (
    input               sysClk,
    input               csrStrobe,
    input       [31:0]  GPIO_OUT,
    output      [31:0]  csr,

    input                                        clk,
    input       [NUM_CHANNELS*CHANNEL_WIDTH-1:0] physicalData,
    input                     [NUM_CHANNELS-1:0] physicalValid,

    output reg [NUM_CHANNELS*CHANNEL_WIDTH-1:0] logicalData,
    output reg               [NUM_CHANNELS-1:0] logicalValid
);

localparam MAX_CHANNELS = 8;
localparam OPERAND_WIDTH = $clog2(MAX_CHANNELS);

generate
if (NUM_CHANNELS > MAX_CHANNELS) begin
    NUM_CHANNELS_greater_than_MAX_CHANNELS_unsupported();
end
endgenerate

reg [31:0] sysChannelMap = 0;
assign csr = sysChannelMap;
always @(posedge sysClk) begin
    if(csrStrobe) begin
        sysChannelMap <= GPIO_OUT;
    end
end

wire [31:0] channelMap;
forwardData #(
    .DATA_WIDTH(32))
  forwardData(
    .inClk(sysClk),
    .inData(sysChannelMap),
    .outClk(clk),
    .outData(channelMap));

genvar i;
generate
for (i = 0; i < NUM_CHANNELS; i = i + 1) begin

    wire [OPERAND_WIDTH-1:0] physicalChannel =
        channelMap[(i+1)*OPERAND_WIDTH-1:i*OPERAND_WIDTH];

    always @(posedge clk) begin
        logicalData[(i+1)*CHANNEL_WIDTH-1:i*CHANNEL_WIDTH] <=
            physicalData[physicalChannel*CHANNEL_WIDTH+:CHANNEL_WIDTH];
        logicalValid[i] <=
            physicalValid[physicalChannel];
    end

end
endgenerate

endmodule
