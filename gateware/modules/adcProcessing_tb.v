`timescale 1ns / 1ns

module adcProcessing_tb #(
    parameter CSR_DATA_BUS_WIDTH = 32,
    parameter CSR_STROBE_BUS_WIDTH = 1,

    parameter DATA_WIDTH = 16,
    parameter ADC_WIDTH = 14
);

//
// Register offsets
//
localparam WR_REG_OFFSET_CSR       = 0;

//
// Write CSR fields
//
localparam WR_W_CSR_THRESHOLD_MASK = (1 << (2*ADC_WIDTH))-1;

//
// Read CSR fields
//
localparam WR_R_CSR_TRIGGER_MASK   = (1 << (2*ADC_WIDTH))-1;

reg module_done = 0;
reg module_ready = 0;
integer errors = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("adcProcessing.vcd");
        $dumpvars(0, adcProcessing_tb);
    end

    wait(module_done);
    $display("%s",errors==0?"# PASS":"# FAIL");
    $finish();
end

integer cc;
reg clk = 0;
initial begin
    clk = 0;
    for (cc = 0; cc < 3000; cc = cc+1) begin
        clk = 0; #5;
        clk = 1; #5;
    end
end

integer adcCC;
reg adcClk = 0;
initial begin
    adcClk = 0;
    for (adcCC = 0; adcCC < 3000; adcCC = adcCC+1) begin
        adcClk = 0; #4;
        adcClk = 1; #4;
    end
end

//
// CSR
//

csrTestMaster # (
    .CSR_DATA_BUS_WIDTH(CSR_DATA_BUS_WIDTH),
    .CSR_STROBE_BUS_WIDTH(CSR_STROBE_BUS_WIDTH)
) CSR0 (
    .clk(clk)
);

wire [CSR_DATA_BUS_WIDTH-1:0] GPIO_IN[0:CSR_STROBE_BUS_WIDTH-1];
wire [CSR_STROBE_BUS_WIDTH-1:0] GPIO_STROBES = CSR0.csr_stb_o;
wire [CSR_DATA_BUS_WIDTH-1:0] GPIO_OUT = CSR0.csr_data_o;

genvar i;
generate for(i = 0; i < CSR_STROBE_BUS_WIDTH; i = i + 1) begin
    assign CSR0.csr_data_i[(i+1)*CSR_DATA_BUS_WIDTH-1:i*CSR_DATA_BUS_WIDTH] = GPIO_IN[i];
end
endgenerate

//
// ADC processing
//

wire [31:0] CSR;
wire adcUseThisSample, adcExceedsThreshold;
reg adcValidIn = 0;
reg [DATA_WIDTH-1:0] adc0In = 0,
    adc0QIn = 0,
    adc1In = 0,
    adc1QIn = 0,
    adc2In = 0,
    adc2QIn = 0,
    adc3In = 0,
    adc3QIn = 0;
wire adcValidOut;
wire [DATA_WIDTH-1:0] adc0Out,
    adc0QOut,
    adc1Out,
    adc1QOut,
    adc2Out,
    adc2QOut,
    adc3Out,
    adc3QOut;

assign GPIO_IN[WR_REG_OFFSET_CSR] = CSR;

adcProcessing #(
    .ADC_WIDTH(DATA_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) DUT (
    .sysClk(clk),
    .sysCsrStrobe(GPIO_STROBES[0]),
    .GPIO_OUT(GPIO_OUT),
    .sysReadout(CSR),

    .adcClk(adcClk),
    .adcValidIn(adcValidIn),
    .adc0In(adc0In),
    .adc1In(adc1In),
    .adc2In(adc2In),
    .adc3In(adc3In),
    .adc0QIn(adc0QIn),
    .adc1QIn(adc1QIn),
    .adc2QIn(adc2QIn),
    .adc3QIn(adc3QIn),

    .adcValidOut(adcValidOut),
    .adc0Out(adc0Out),
    .adc1Out(adc1Out),
    .adc2Out(adc2Out),
    .adc3Out(adc3Out),
    .adc0QOut(adc0QOut),
    .adc1QOut(adc1QOut),
    .adc2QOut(adc2QOut),
    .adc3QOut(adc3QOut),

    .adcUseThisSample(adcUseThisSample),
    .adcExceedsThreshold(adcExceedsThreshold));

// stimulus
initial begin
    wait(CSR0.ready);
    @(posedge clk);

    module_done = 0;
    @(posedge clk);
    CSR0.write32(WR_REG_OFFSET_CSR, 10_000);

    @(posedge clk);
    module_ready = 1;

    repeat(1000) begin
        @(posedge clk);
    end
    module_done = 1;
end

initial begin
    wait(CSR0.ready);
    wait(module_ready);

    @(posedge adcClk);
    adcValidIn <= 1'b1;
    adc0In     <= 16'd0;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adcValidIn <= 1'b1;
    adc0In     <= 16'd20;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd40;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd60;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd80;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd80;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd100;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd200;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd50;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd80;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd40;
    adc0QIn    <= 0;

    @(posedge adcClk);
    adc0In     <= 16'd30;
    adc0QIn    <= 0;

    repeat(10) begin
        @(posedge adcClk);
    end

    @(posedge adcClk);
    adc0In     <= 16'd0;
    adc0QIn    <= 0;
end

endmodule
