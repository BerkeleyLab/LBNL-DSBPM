//
// Position offset subtraction
//
module subOffset #(
    parameter integer NUM_SIGNALS   = 4,
    parameter integer SIGNAL_WIDTH  = 32,
    parameter integer OFFSET_WIDTH  = 32
    ) (
    input                                           clk,
    input                                           validIn,
    input signed   [(SIGNAL_WIDTH*NUM_SIGNALS)-1:0] signalIn,
    input signed   [(OFFSET_WIDTH*NUM_SIGNALS)-1:0] offsetIn,
    output                                          validOut,
    output signed  [(SIGNAL_WIDTH*NUM_SIGNALS)-1:0] signalOut
);

`define SAT(x,old,new) ((~|x[old:new] | &x[old:new]) ? x[new:0] : {x[old],{new{~x[old]}}})

genvar i;
generate
for (i = 0 ; i < NUM_SIGNALS ; i = i + 1) begin : g_offs
    wire signed [SIGNAL_WIDTH-1:0] signal = signalIn[i*SIGNAL_WIDTH+:SIGNAL_WIDTH];
    wire signed [OFFSET_WIDTH-1:0] offset = offsetIn[i*OFFSET_WIDTH+:OFFSET_WIDTH];
    reg signed [SIGNAL_WIDTH:0] signalFull = 0;
    reg signed [SIGNAL_WIDTH-1:0] signalSat = 0;

    always @(posedge clk) begin
        signalFull <= signal - offset;
        signalSat <= `SAT(signalFull, SIGNAL_WIDTH, SIGNAL_WIDTH-1);
    end

    assign signalOut[i*SIGNAL_WIDTH+:SIGNAL_WIDTH] = signalSat;
end
endgenerate

reg validFull = 0;
reg validSat = 0;

always @(posedge clk) begin
    validFull <= validIn;
    validSat <= validFull;
end

assign validOut = validSat;

endmodule
