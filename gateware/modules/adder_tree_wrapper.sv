//
// Adder tree wrapper for Verilog-2001
// compatibility
//

`resetall
`default_nettype none

module adder_tree_wrapper #(
    parameter int unsigned NUM_INPUTS = 10,
    parameter int unsigned DATA_WIDTH = 16,
    // Don't change these
    parameter int unsigned DEPTH = $clog2(NUM_INPUTS)
)(
    input  wire logic       clk,
    input  wire logic       rst,
    input  wire logic       valid_in,

    input  wire logic [NUM_INPUTS*DATA_WIDTH-1:0]
                            data_in,

    output wire logic       valid_out,
    output wire logic signed [DATA_WIDTH+DEPTH-1:0]
                            data_out);

logic signed [NUM_INPUTS-1:0][DATA_WIDTH-1:0] data_in_2d;

always_comb begin
    for (int i = 0; i < NUM_INPUTS; i++) begin
        data_in_2d[i] = data_in[i*DATA_WIDTH+:DATA_WIDTH];
    end
end

adder_tree #(
    .NUM_INPUTS(NUM_INPUTS),
    .DATA_WIDTH(DATA_WIDTH))
  adder_tree (
    .clk      (clk),
    .rst      (rst),
    .valid_in (valid_in),
    .data_in  (data_in_2d),
    .valid_out(valid_out),
    .data_out (data_out));

endmodule

`resetall
