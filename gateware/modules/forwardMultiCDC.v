module forwardMultiCDC #(
    parameter   DATA_WIDTH = 8
)(
    input       [DATA_WIDTH-1:0] dataIn,

    input                        clk,
    output wire [DATA_WIDTH-1:0] dataOut,
    output wire [DATA_WIDTH-1:0] dataOut_pp
);

genvar i;
generate
for (i = 0; i < DATA_WIDTH; i = i+1) begin

forwardSingleCDC
  forwardSingleCDC (
    .dataIn(dataIn[i]),
    .clk(clk),
    .dataOut(dataOut[i]),
    .dataOut_pp(dataOut_pp[i]));

end
endgenerate

endmodule
