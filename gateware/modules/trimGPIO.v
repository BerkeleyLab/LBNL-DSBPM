//
// Apply gain compensation factors
// with processor bus gupport
//
module trimGPIO #(
    parameter GPIO_WIDTH = 32,
    parameter NUM_GAINS  = 4,
    parameter MAG_WIDTH  = 26,
    parameter GAIN_WIDTH = 27
    ) (
    input                          clk,

    // GPIO support
    input  wire              [GPIO_WIDTH-1:0] gpioData,
    input  wire               [NUM_GAINS-1:0] gainStrobes,
    output wire  [(GPIO_WIDTH*NUM_GAINS)-1:0] gainRBK,

    // Magnitudes Input/Output
    input                                     strobe,
    input         [(MAG_WIDTH*NUM_GAINS)-1:0] magnitudes,
    output wire                               trimmedToggle,
    output reg                                trimmedStrobe,
    output wire   [(MAG_WIDTH*NUM_GAINS)-1:0] trimmed);

generate
if (NUM_GAINS < 2) begin
    NUM_GAINS_needs_to_be_greater_or_equal_2 error();
end
endgenerate

generate
if (GAIN_WIDTH > GPIO_WIDTH) begin
    GAIN_WIDTH_cannot_be_greater_than_GPIO_WIDTH error();
end
endgenerate

// Gain factors from processor
reg [((NUM_GAINS-1)*GAIN_WIDTH)-1:0] psGbuf;

// Write all gain value to a temporary buffer
genvar i;
generate
for(i = 0; i < NUM_GAINS-1; i = i+1) begin
    // Handle writes from processor
    always @(posedge clk) begin
        if(gainStrobes[i]) begin
            psGbuf[i*GAIN_WIDTH+:GAIN_WIDTH] <= gpioData[0+:GAIN_WIDTH];
        end
    end
end
endgenerate

// apply all gains at once when the last gain is set.
// Initialize gains to full scale unsigned
reg [(NUM_GAINS*GAIN_WIDTH)-1:0] gains = {NUM_GAINS{1'b1,{(GAIN_WIDTH-1){1'b0}}}};
// Handle writes from processor
always @(posedge clk) begin
    if (gainStrobes[NUM_GAINS-1]) begin
        gains <= {gpioData[GAIN_WIDTH-1:0], psGbuf};
    end
end

generate
for(i = 0; i < NUM_GAINS; i = i+1) begin

assign gainRBK[i*GPIO_WIDTH+:GPIO_WIDTH] = {{(GPIO_WIDTH-GAIN_WIDTH){1'b0}} ,gains[i*GAIN_WIDTH+:GAIN_WIDTH]};

end
endgenerate

trim #(
    .NUM_GAINS(NUM_GAINS),
    .MAG_WIDTH(MAG_WIDTH),
    .GAIN_WIDTH(GAIN_WIDTH)
)
trim (
    .clk(clk),
    .strobe(strobe),
    .magnitudes(magnitudes),
    .gains(gains),
    .trimmedToggle(trimmedToggle),
    .trimmed(trimmed)
);

reg trimmedToggle_d = 0;

// 2 clock cycle strobe generation
always @(posedge clk) begin
    trimmedToggle_d <= trimmedToggle;

    if (trimmedToggle != trimmedToggle_d) begin
        trimmedStrobe <= 1'b1;
    end
    else begin
        trimmedStrobe <= 1'b0;
    end
end

endmodule
