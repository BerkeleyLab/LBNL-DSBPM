//
// Map physical to logical ADC channels
//
module adcMapping #(
    parameter ADC_NUM_CHANNELS  = 8,
    parameter ADC_WIDTH         = 16
) (
    input               sysClk,
    input               csrStrobe,
    input       [31:0]  GPIO_OUT,
    output      [31:0]  csr,

    input                                        adcClk,
    input       [ADC_NUM_CHANNELS*ADC_WIDTH-1:0] adcPhysicalData,
    input                 [ADC_NUM_CHANNELS-1:0] adcPhysicalValid,

    output reg  [ADC_NUM_CHANNELS*ADC_WIDTH-1:0] adcLogicalData,
    output reg            [ADC_NUM_CHANNELS-1:0] adcLogicalValid
);

localparam ADC_MAX_CHANNELS = 8;
localparam ADC_OPERAND_WIDTH = $clog2(ADC_MAX_CHANNELS);

generate
if (ADC_NUM_CHANNELS > ADC_MAX_CHANNELS) begin
    ADC_NUM_CHANNELS_greater_than_ADC_MAX_CHANNELS_unsupported();
end
endgenerate

reg [31:0] sysAdcMap = 0;
assign csr = sysAdcMap;
always @(posedge sysClk) begin
    if(csrStrobe) begin
        sysAdcMap <= GPIO_OUT;
    end
end

wire [31:0] adcMap;
forwardData #(
    .DATA_WIDTH(32))
  forwardData(
    .inClk(sysClk),
    .inData(sysAdcMap),
    .outClk(adcClk),
    .outData(adcMap));

genvar i;
generate
for (i = 0; i < ADC_NUM_CHANNELS; i = i + 1) begin

    wire [ADC_OPERAND_WIDTH-1:0] adcPhysicalChannel =
        adcMap[(i+1)*ADC_OPERAND_WIDTH-1:i*ADC_OPERAND_WIDTH];

    always @(posedge adcClk) begin
        adcLogicalData[(i+1)*ADC_WIDTH-1:i*ADC_WIDTH] <=
            adcPhysicalData[(adcPhysicalChannel+1)*ADC_WIDTH-1:
                             adcPhysicalChannel*ADC_WIDTH];
        adcLogicalValid[i] <=
            adcPhysicalValid[adcPhysicalChannel];
    end

end
endgenerate

endmodule
