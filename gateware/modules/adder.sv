`resetall
`default_nettype none

module adder #(
    parameter int INPUT_WIDTH = 32,
    parameter int OUTPUT_WIDTH = 32
) (
    input logic                             clk,
    input logic signed    [INPUT_WIDTH-1:0] a,
    input logic signed    [INPUT_WIDTH-1:0] b,
    input logic                             valid_in,
    output logic signed  [OUTPUT_WIDTH-1:0] sum,
    output logic                            valid_out
);

logic signed [INPUT_WIDTH:0] full_sum;
assign full_sum = a + b;

`define SAT(x,old,new) ((~|x[old:new] | &x[old:new]) ? x[new:0] : {x[old],{new{~x[old]}}})

generate
if (OUTPUT_WIDTH > INPUT_WIDTH) begin

always_ff @(posedge clk) begin
    sum <= OUTPUT_WIDTH'(full_sum);
    valid_out <= valid_in;
end

end
endgenerate

generate
if (OUTPUT_WIDTH <= INPUT_WIDTH) begin

always_ff @(posedge clk) begin
    sum <= `SAT(full_sum, INPUT_WIDTH, OUTPUT_WIDTH-1);
    valid_out <= valid_in;
end

end
endgenerate


endmodule

`resetall
