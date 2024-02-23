//
// Dual-port RAM with different write/read widths
//
module genericDPRAM #(
    parameter WRITE_DATA_WIDTH    = 14,
    parameter WRITE_ADDRESS_WIDTH = 16,
    // Must be a multiple of WRITE_DATA_WIDTH
    parameter READ_DATA_WIDTH     = 256,
    parameter READ_ADDRESS_WIDTH  = 10
    ) (
    input                           wClk,
    input                           wEnable,
    input [WRITE_ADDRESS_WIDTH-1:0] wAddr,
    input    [WRITE_DATA_WIDTH-1:0] wData,

    input                                rClk,
    input       [READ_ADDRESS_WIDTH-1:0] rAddr,
    output reg     [READ_DATA_WIDTH-1:0] rData
);

localparam SAMPLES_PER_CLOCK = READ_DATA_WIDTH / WRITE_DATA_WIDTH;
localparam SAMPLES_PER_CLOCK_WIDTH = $clog2(SAMPLES_PER_CLOCK);

generate
if (WRITE_DATA_WIDTH > READ_DATA_WIDTH) begin
    WRITE_DATA_WIDTH_is_bigger_than_READ_DATA_WIDTH error();
end
endgenerate

generate
if ((READ_DATA_WIDTH % WRITE_DATA_WIDTH) != 0) begin
    WRITE_DATA_WIDTH_is_not_a_submultiple_of_READ_DATA_WIDTH error();
end
endgenerate

generate
if (2**($clog2(SAMPLES_PER_CLOCK)) != SAMPLES_PER_CLOCK) begin
    SAMPLES_PER_CLOCK_is_not_a_power_of_2 error();
end
endgenerate

generate
if (READ_ADDRESS_WIDTH != (WRITE_ADDRESS_WIDTH - SAMPLES_PER_CLOCK_WIDTH)) begin
    READ_ADDRESS_WIDTH_is_not_a_related_to_data_widths error();
end
endgenerate

localparam READ_CAPACITY = 1 << READ_ADDRESS_WIDTH;

wire [WRITE_ADDRESS_WIDTH-1-(SAMPLES_PER_CLOCK_WIDTH):0] dpramWaddr =
    wAddr[WRITE_ADDRESS_WIDTH-1:SAMPLES_PER_CLOCK_WIDTH];

// Generate DPRAMs and index them by the LSB addresses bits
genvar i;
generate
for (i = 0; i < SAMPLES_PER_CLOCK; i = i + 1) begin

reg [WRITE_DATA_WIDTH-1:0] dpram [0:READ_CAPACITY-1];
always @(posedge wClk) begin
    if (wEnable && (wAddr[SAMPLES_PER_CLOCK_WIDTH-1:0] == i))
        dpram[dpramWaddr] <= wData;
end

always @(posedge rClk) begin
    rData[(i+1)*WRITE_DATA_WIDTH-1:i*WRITE_DATA_WIDTH] <=
        dpram[rAddr];
end

end
endgenerate

endmodule
