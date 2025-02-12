//
// Full multiplier inferring DSP48 for Xilinx FPGAs
//
module fullMultiplier #(
    // Number of pipeline levels. 2 is the minimum:
    // 1 -> input register
    // 2 -> multiplication
    parameter NUM_PIPELINE_LEVELS = 2,
    parameter A_WIDTH = 32,
    parameter B_WIDTH = 32
) (
    input                         clk,
    input           [A_WIDTH-1:0] a,
    input           [B_WIDTH-1:0] b,
    output  [A_WIDTH+B_WIDTH-1:0] p
);

generate
if (NUM_PIPELINE_LEVELS < 2) begin
    NUM_PIPELINE_LEVELS_is_less_than_2 error();
end
endgenerate

reg [A_WIDTH-1:0] a_in;
reg [B_WIDTH-1:0] b_in;
reg [A_WIDTH+B_WIDTH-1:0] p_r[0:NUM_PIPELINE_LEVELS-2];
always @(posedge clk) begin
    a_in <= a;
    b_in <= b;

    p_r[0] <= a_in * b_in;
end

genvar i;
generate for(i = 0; i < NUM_PIPELINE_LEVELS-2; i = i + 1) begin
    always @(posedge clk) begin
        p_r[i+1] <= p_r[i];
    end
end
endgenerate

assign p = p_r[NUM_PIPELINE_LEVELS-2];

endmodule
