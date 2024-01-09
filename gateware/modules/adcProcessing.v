//
// Calculate ADC statistics and basic DC-washout for
// RMS calculation
//
// Values starting with adc or ADC are in ADC clock domain.
// Values starting with anything else are in system clock domain.

module adcProcessing #(
    // Actual number of ADC bits, without any padding
    parameter ADC_WIDTH                   = -1,
    // ADC word mumber of bits, with padding
    parameter DATA_WIDTH                  = -1
    ) (
    input                            sysClk,
    input                            sysCsrStrobe,
    input                     [31:0] GPIO_OUT,
    output wire               [31:0] sysReadout,

    input                            adcClk,
    input                            adcValidIn,
    input           [DATA_WIDTH-1:0] adc0In, adc1In, adc2In, adc3In,
    input           [DATA_WIDTH-1:0] adc0QIn, adc1QIn, adc2QIn, adc3QIn,

    output                            adcValidOut,
    output           [DATA_WIDTH-1:0] adc0Out, adc1Out, adc2Out, adc3Out,
    output           [DATA_WIDTH-1:0] adc0QOut, adc1QOut, adc2QOut, adc3QOut,
    output reg                       adcUseThisSample = 0,
    output reg                       adcExceedsThreshold = 0);

localparam NUM_CHANNELS = 4;

generate
if (DATA_WIDTH < ADC_WIDTH) begin
    DATA_WIDTH_must_be_greater_or_equal_than_ADC_WIDTH error();
end
endgenerate

wire signed [NUM_CHANNELS*DATA_WIDTH-1:0] adcsIn = {adc3In, adc2In, adc1In, adc0In};
wire signed [NUM_CHANNELS*DATA_WIDTH-1:0] adcsQIn = {adc3QIn, adc2QIn, adc1QIn, adc0QIn};

// Find ranges
genvar i;
generate
for (i = 0 ; i < NUM_CHANNELS ; i = i + 1) begin : sample

wire                        adcValid = adcValidIn;
wire signed [ADC_WIDTH-1:0] adcVal =
      adcsIn[(i*DATA_WIDTH)+(DATA_WIDTH-ADC_WIDTH)+:ADC_WIDTH];
wire signed [ADC_WIDTH-1:0] adcQVal =
      adcsQIn[(i*DATA_WIDTH)+(DATA_WIDTH-ADC_WIDTH)+:ADC_WIDTH];

end
endgenerate

//
// Latch data.
//
generate
for (i = 0 ; i < NUM_CHANNELS ; i = i + 1) begin : latch

reg adcLatchedDataValid;
reg signed [ADC_WIDTH-1:0] adcLatchedData;
reg signed [ADC_WIDTH-1:0] adcLatchedDataQ;
wire signed [ADC_WIDTH-1:0] adcRawData;
wire signed [ADC_WIDTH-1:0] adcRawDataQ;
wire adcRawDataValid;
always @(posedge adcClk) begin
    adcLatchedDataValid <= sample[i].adcValid;
    adcLatchedData <= sample[i].adcVal;
    adcLatchedDataQ <= sample[i].adcQVal;
end

assign adcRawData = adcLatchedData;
assign adcRawDataQ = adcLatchedDataQ;
assign adcRawDataValid = adcLatchedDataValid;

end
endgenerate

//
// Process latched ADC values
//

localparam THRESHOLD_WIDTH = 2*ADC_WIDTH;

wire      [THRESHOLD_WIDTH-1:0] adcThreshold;
wire   [NUM_CHANNELS-1:0] adcsAboveThreshold;
wire                      adcsAboveThresholdValid;

generate
for (i = 0 ; i < NUM_CHANNELS ; i = i + 1) begin : mag

wire adcAboveThreshold = (adcFakeMag > adcThreshold);
wire adcAboveThresholdValid = adcFakeMagValid;

//
// Calculate proportional magnitude for I/Q signal pair.
//

localparam MIXER_LATENCY_CYCLES = 4;

wire signed [(2*ADC_WIDTH-1)-1:0] adcSquared;
mixer #(
    .dwi(ADC_WIDTH),
    .davr(ADC_WIDTH-1),
    .dwlo(ADC_WIDTH))
  adcSquare(
    .clk(adcClk),
    .adcf(latch[i].adcRawData),
    .mult(latch[i].adcRawData),
    .mixout(adcSquared));

wire signed [(2*ADC_WIDTH-1)-1:0] adcSquaredQ;
mixer #(
    .dwi(ADC_WIDTH),
    .davr(ADC_WIDTH-1),
    .dwlo(ADC_WIDTH))
  adcSquareQ(
    .clk(adcClk),
    .adcf(latch[i].adcRawDataQ),
    .mult(latch[i].adcRawDataQ),
    .mixout(adcSquaredQ));

wire adcSquaredValid;
reg_delay #(
    .dw(1),
    .len(MIXER_LATENCY_CYCLES)
) mixerValidDelay (
    .clk(adcClk),
    .reset(1'b0),
    .gate(1'b1),
    .din(latch[i].adcRawDataValid),
    .dout(adcSquaredValid)
);

`define SAT(x,old,new) ((~|x[old:new] | &x[old:new]) ? x[new:0] : {x[old],{new{~x[old]}}})

reg adcFakeMagFullValid = 0;
reg signed [2*ADC_WIDTH:0] adcFakeMagFull;
reg adcFakeMagValid = 0;
reg signed [2*ADC_WIDTH-1:0] adcFakeMag;
always @(posedge adcClk) begin
    adcFakeMagFullValid <= adcSquaredValid;
    adcFakeMagFull <= adcSquared + adcSquaredQ;

    adcFakeMagValid <= adcFakeMagFullValid;
    adcFakeMag <= `SAT(adcFakeMagFull, 2*ADC_WIDTH, 2*ADC_WIDTH-1);
end

assign adcsAboveThreshold[i] = adcAboveThreshold;
assign adcsAboveThresholdValid = adcAboveThresholdValid;

end
endgenerate

//
// Delay values to give single pass self triggering time to process
//

localparam CYCLES_DELAY = 12;

wire [NUM_CHANNELS*ADC_WIDTH-1:0] adcsDelayed;
reg_delay #(
    .dw(8*DATA_WIDTH+1),  // Width of data = 4 channels of I and Q, 1 valid
    .len(CYCLES_DELAY)      // Cycles to delay
) adcReadoutDelay (
    .clk(adcClk),
    .reset(1'b0),
    .gate(1'b1),
    .din({adcValidIn, adc3QIn, adc2QIn, adc1QIn, adc0QIn,
          adc3In, adc2In, adc1In, adc0In}),
    .dout({adcValidOut, adc3QOut, adc2QOut, adc1QOut, adc0QOut,
          adc3Out, adc2Out, adc1Out, adc0Out})
);

//
// CSR logic
//

reg  [THRESHOLD_WIDTH-1:0] threshold = 0;
assign sysReadout[THRESHOLD_WIDTH-1:0] = threshold;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        threshold <= GPIO_OUT[0+:THRESHOLD_WIDTH];
    end
end
forwardData #(.DATA_WIDTH(THRESHOLD_WIDTH)) fwThreshold(.inClk(sysClk),
                                                  .inData(threshold),
                                                  .outClk(adcClk),
                                                  .outData(adcThreshold));

// Use about equal number of samples pre and post trigger for RMS.
// The delay block provides 12 samples delay of which 4 are taken up
// by the trigger computation before the RMS summation blocks.
reg [4:0] adcUseSampleCounter = 0;
always @(posedge adcClk) begin
    if (adcsAboveThresholdValid) begin
        if (|adcsAboveThreshold) begin
            adcExceedsThreshold <= 1;
            adcUseThisSample <= 1;
            adcUseSampleCounter <= 18;
        end
        else begin
            adcExceedsThreshold <= 0;
            if (adcUseSampleCounter != 0) begin
                adcUseSampleCounter <= adcUseSampleCounter - 1;
            end
            else begin
                adcUseThisSample <= 0;
            end
        end
    end
end

endmodule
