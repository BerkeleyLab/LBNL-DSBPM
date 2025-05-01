module forwardSingleCDC (
    input       dataIn,

    input       clk,
    output wire dataOut,
    output reg  dataOut_pp = 0
);

reg_tech_cdc regCDC (
    .I(dataIn),
    .C(clk),
    .O(dataOut)
);

reg dataOut_d = 0;
always @(posedge clk) begin
    dataOut_d <= dataOut;
    dataOut_pp <= (dataOut && ~dataOut_d);
end

endmodule
