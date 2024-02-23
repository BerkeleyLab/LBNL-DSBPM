/////////////////////////////////////////////////////////////////////////////
// Generate tile synchronization user_sysref
// As shown in PG269 (v2.1) Zynq UltraScale+ RFSoC RF Data Converter
//   Figure 105: Clocking for Multi-Tile Synchronization
//   Figures 81 and 83 display similar examples
// Two stage sampling:
//   First stage at FPGA_REFCLK_OUT_C rate
//   Second stage at ADC AXI rate (adcClk or dacClk)
// Check that SYSREF capture is free of race conditions.
// Output FPGA_REFCLK_OUT_C so it can be taken to an MMCM block
// which multiplies it to provide the ADC AXI clock (adcClk or dacClk).

module sysrefSync #(
    parameter COUNTER_WIDTH = 8,
    parameter DEBUG         = "false"
    ) (
    input              sysClk,
    input              sysCsrStrobe,
    input       [31:0] GPIO_OUT,
    output wire [31:0] sysStatusReg,

    input              FPGA_REFCLK_OUT_C,
    input              SYSREF_FPGA_C_UNBUF,

    input              clk,
    output reg         user_sysref_resampled);

// Domain-crossing values
(*mark_debug=DEBUG*) reg clkNewValueToggle = 0;
(*mark_debug=DEBUG*) reg [COUNTER_WIDTH-1:0] clkCount = 0;
(*mark_debug=DEBUG*) reg refClkNewValueToggle = 0;
(*mark_debug=DEBUG*) reg [COUNTER_WIDTH-1:0] refClkCount = 0;

//////////////////////////////////////////////////////////////////////////////
// System clock domain
// Verify that number of clocks between sysref assertions meet expectations.

(*ASYNC_REG="TRUE"*) reg newClkValueToggle_m = 0, newClkValueToggle = 0;
reg newClkValueMatch = 0;
(*ASYNC_REG="TRUE"*) reg newRefValueToggle_m = 0, newRefValueToggle = 0;
reg newRefValueMatch = 0;

(*mark_debug=DEBUG*) reg [COUNTER_WIDTH-1:0] expectedClkCount, expectedRefCount;
(*mark_debug=DEBUG*) reg clkFault = 0, refFault = 0;

assign sysStatusReg = { clkFault, {16-1-COUNTER_WIDTH{1'b0}}, clkCount,
                        refFault, {16-1-COUNTER_WIDTH{1'b0}}, refClkCount };

always @(posedge sysClk) begin
    newClkValueToggle_m <= clkNewValueToggle;
    newRefValueToggle_m <= refClkNewValueToggle;
    if (sysCsrStrobe) begin
        if (GPIO_OUT[31]) clkFault <= 0;
        if (GPIO_OUT[15]) refFault <= 0;
        if (!GPIO_OUT[31] && !GPIO_OUT[15]) begin
            expectedRefCount <= GPIO_OUT[0+:COUNTER_WIDTH];
            expectedClkCount <= GPIO_OUT[16+:COUNTER_WIDTH];
        end
    end
    else begin
        newClkValueToggle <= newClkValueToggle_m;
        if (newClkValueToggle != newClkValueMatch) begin
            newClkValueMatch <= !newClkValueMatch;
            if (clkCount != expectedClkCount) begin
                clkFault <= 1;
            end
        end
        newRefValueToggle <= newRefValueToggle_m;
        if (newRefValueToggle != newRefValueMatch) begin
            newRefValueMatch <= !newRefValueMatch;
            if (refClkCount != expectedRefCount) begin
                refFault <= 1;
            end
        end
    end
end

//////////////////////////////////////////////////////////////////////////////
// FPGA_REFCLK_OUT_C clock domain
// Count clocks between SYSREF assertions.

(*mark_debug=DEBUG*) reg [COUNTER_WIDTH-1:0] refClkCounter = 0;
(*ASYNC_REG="TRUE"*) reg sysrefSampled;
reg sysrefSampled_d = 1;

always @(posedge FPGA_REFCLK_OUT_C) begin
    sysrefSampled   <= SYSREF_FPGA_C_UNBUF;
    sysrefSampled_d <= sysrefSampled;
    if (sysrefSampled && !sysrefSampled_d) begin
        refClkCount <= refClkCounter;
        refClkCounter <= 0;
        refClkNewValueToggle <= !refClkNewValueToggle;
    end
    else begin
        refClkCounter <= refClkCounter + 1;
    end
end


//////////////////////////////////////////////////////////////////////////////
// clk clock domain
// Count clocks between SYSREF assertions.

(*mark_debug=DEBUG*) reg [COUNTER_WIDTH-1:0] clkCounter = 0;
reg user_sysref_resampled_d = 1;

always @(posedge clk) begin
    user_sysref_resampled   <= sysrefSampled;
    user_sysref_resampled_d <= user_sysref_resampled;
    if (user_sysref_resampled && !user_sysref_resampled_d) begin
        clkCount <= clkCounter;
        clkCounter <= 0;
        clkNewValueToggle <= !clkNewValueToggle;
    end
    else begin
        clkCounter <= clkCounter + 1;
    end
end

endmodule
