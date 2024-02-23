`timescale 1ns / 1ns

module genericDPRAM_tb #(
    parameter CSR_DATA_BUS_WIDTH = 32,
    parameter CSR_STROBE_BUS_WIDTH = 1,

    parameter DATA_WIDTH = 16,
    parameter ADC_WIDTH = 14
);

reg module_done = 0;
reg module_ready = 0;
integer errors = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("genericDPRAM.vcd");
        $dumpvars(0, genericDPRAM_tb);
    end

    wait(module_done);
    $display("%s",errors==0?"# PASS":"# FAIL");
    $finish();
end

integer wcc;
reg wClk = 0;
initial begin
    wClk = 0;
    for (wcc = 0; wcc < 500; wcc = wcc+1) begin
        wClk = 0; #5;
        wClk = 1; #5;
    end
end

integer rcc;
reg rClk = 0;
initial begin
    rClk = 0;
    for (rcc = 0; rcc < 2000; rcc = rcc+1) begin
        rClk = 0; #2;
        rClk = 1; #2;
    end
end

//
// DPRAM
//
localparam WRITE_ADDRESS_WIDTH = 14;
localparam WRITE_DATA_WIDTH = 16;
localparam READ_DATA_WIDTH = 256;

localparam SAMPLES_PER_CLOCK = READ_DATA_WIDTH / WRITE_DATA_WIDTH;
localparam SAMPLES_PER_CLOCK_WIDTH = $clog2(SAMPLES_PER_CLOCK);
localparam READ_ADDRESS_WIDTH = WRITE_ADDRESS_WIDTH - SAMPLES_PER_CLOCK_WIDTH;

localparam WRITE_ADDRESS_MAX = 128;

reg wEnable = 0;
reg [WRITE_ADDRESS_WIDTH-1:0] wAddr = 0;
wire [WRITE_DATA_WIDTH-1:0] wData;
reg [READ_ADDRESS_WIDTH-1:0] rAddr = 0;
wire [READ_DATA_WIDTH-1:0] rData;
genericDPRAM #(
    .WRITE_ADDRESS_WIDTH(WRITE_ADDRESS_WIDTH),
    .WRITE_DATA_WIDTH(WRITE_DATA_WIDTH),
    .READ_ADDRESS_WIDTH(READ_ADDRESS_WIDTH),
    .READ_DATA_WIDTH(READ_DATA_WIDTH)
    ) DUT (
    .wClk(wClk),
    .wEnable(wEnable),
    .wAddr(wAddr),
    .wData(wData),

    .rClk(rClk),
    .rAddr(rAddr),
    .rData(rData)
);

// set-up module
initial begin
    module_ready = 0;
    @(posedge wClk);
    module_ready = 1;

    @(posedge wClk);
    wStart <= 1;
    @(posedge wClk);
    wStart <= 0;
end

// drive stimulus
initial begin
    wait(module_ready);
    wait(wDone);
    wait(rDone);

    module_done = 1;
end

// stimulus
localparam S_W_IDLE   = 2'd0;
localparam S_W_START  = 2'd1;
localparam S_W_WRITE  = 2'd2;
reg [2:0] wState = S_W_IDLE;

reg [WRITE_DATA_WIDTH/2-1:0] wCount = 0;
reg wDone = 0;
reg wStart = 0;
always @(posedge wClk) begin
    case(wState)

    S_W_IDLE: begin
        wEnable <= 0;
        if (wStart) begin
            wState <= S_W_START;
        end
    end

    S_W_START: begin
        wCount <= 0;
        wAddr <= 0;
        wEnable <= 1;
        wState <= S_W_WRITE;
    end

    S_W_WRITE: begin
        if (wAddr < WRITE_ADDRESS_MAX-1) begin
            wCount <= wCount + 1;
            wAddr <= wAddr + 1;
            wEnable <= 1;
        end else begin
            wDone <= 1;
            wEnable <= 0;
            wState <= S_W_IDLE;
        end
    end

    default:
        wState <= S_W_IDLE;
    endcase
end

assign wData[WRITE_DATA_WIDTH-1:WRITE_DATA_WIDTH/2] = wCount;
assign wData[WRITE_DATA_WIDTH/2-1:0] =
    {{WRITE_DATA_WIDTH/2-(WRITE_ADDRESS_WIDTH/2-1){1'b0}},
    wAddr[WRITE_ADDRESS_WIDTH/2-1:0]};

localparam S_R_IDLE         = 3'd0;
localparam S_R_READ         = 3'd1;
localparam S_R_READ_LAST    = 3'd2;
reg [2:0] rState = S_R_IDLE;

reg rDone = 0;
always @(posedge rClk) begin
    case(rState)

    S_R_IDLE: begin
        rAddr <= 0;
        // Don't care about CDC here, as wDone is asserted and
        // never de-asserted.
        // simulation
        if (wDone) begin
            rState <= S_R_READ;
        end
    end

    S_R_READ: begin
        if (rAddr < WRITE_ADDRESS_MAX/SAMPLES_PER_CLOCK-1) begin
            rAddr <= rAddr + 1;
        end else begin
            rState <= S_R_READ_LAST;
        end
    end

    // Account for 1-cycle read latency
    S_R_READ_LAST: begin
        rDone <= 1;
        rState <= S_R_IDLE;
    end

    default:
        rState <= S_R_IDLE;
    endcase
end

endmodule
