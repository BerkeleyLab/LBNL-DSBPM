`timescale 1ns / 100ps

module genericDACStreamer_tb #(
    parameter CSR_DATA_BUS_WIDTH = 32,
    parameter CSR_STROBE_BUS_WIDTH = 8,

    parameter DAC_ADDRESS_WIDTH = 14,
    parameter DAC_DATA_WIDTH = 16,
    parameter AXIS_DATA_WIDTH = 256,

    parameter NUM_DAC_TABLE_SAMPLES = 128
);

localparam SAMPLES_PER_CLOCK = AXIS_DATA_WIDTH / DAC_DATA_WIDTH;

// generate HB every 128 axis_clk
localparam HB_CNT_MAX = 128;
localparam HB_CNT_WIDTH = $clog2(HB_CNT_MAX);

//
// Register offsets
//
localparam WR_REG_OFFSET_CSR                  = 0;
localparam WR_REG_OFFSET_ADDRESS              = 1;

//
// Write CSR fields
//
localparam WR_W_CSR_GPIO_BANK                = 'h80000000;
localparam WR_W_CSR_GPIO_RUN                 = 'h00000001;

localparam WR_W_CSR_ADDRESS_BANK             = 'h00000000;
localparam WR_W_CSR_ADDRESS_MASK             = 'h00FFFFFF;

//
// Read CSR fields
//
localparam WR_R_CSR_LAST_INDEX_MASK          = 'hFFFFFF00;
localparam WR_R_CSR_SYNCED                   = 'h2;   // 0010
localparam WR_R_CSR_RUN                      = 'h1;   // 0001

reg module_done = 0;
integer errors = 0;
integer idx = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("genericDACStreamer.vcd");
        $dumpvars(0, genericDACStreamer_tb);
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
        clk = 1; #5;
        clk = 0; #5;
    end
end

// 125 MHz clock
integer evr_cc;
reg evr_clk = 0;
initial begin
    evr_clk = 0;
    for (evr_cc = 0; evr_cc < 3000; evr_cc = evr_cc+1) begin
        evr_clk = 1; #4;
        evr_clk = 0; #4;
    end
end

// 125 * 5/2 clock
// axis_clk and evr_clk coincide every 625
// edges or 2.5 MHz
integer axis_cc;
reg axis_clk = 0;
initial begin
    axis_clk = 0;
    for (axis_cc = 0; axis_cc < 3000; axis_cc = axis_cc+1) begin
        axis_clk = 1; #1.6;
        axis_clk = 0; #1.6;
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
// Generic waveform recorder
//

wire [31:0] dacCSR;
assign GPIO_IN[WR_REG_OFFSET_CSR        ] = dacCSR;

wire [AXIS_DATA_WIDTH-1:0] axis_TDATA;
wire axis_TVALID;
wire axis_TREADY;

genericDACStreamer #(
    .BUS_WIDTH(CSR_DATA_BUS_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .DAC_DATA_WIDTH(DAC_DATA_WIDTH),
    .DAC_ADDRESS_WIDTH(DAC_ADDRESS_WIDTH)
  )
  DUT(
    .sysClk(clk),
    .sysGpioData(GPIO_OUT),
    .sysGpioCsr(dacCSR),
    .sysAddressStrobe(GPIO_STROBES[WR_REG_OFFSET_ADDRESS]),
    .sysGpioStrobe(GPIO_STROBES[WR_REG_OFFSET_CSR]),

    .evrHbMarker(evrHbMarker),

    .axis_CLK(axis_clk),
    .axis_TDATA(axis_TDATA),
    .axis_TVALID(axis_TVALID),
    .axis_TREADY(axis_TREADY)
);

// stimulus
reg [DAC_ADDRESS_WIDTH-1:0] dacAddr = 0;
reg [DAC_DATA_WIDTH-1:0] dacData = 0;
reg module_start_run_table = 0;
reg module_table_run_done = 0;
reg module_start_fill_table = 0;
initial begin
    wait(CSR0.ready);
    @(posedge clk);

    module_start_fill_table = 1;
    @(posedge clk);
end

initial begin
    wait(module_start_fill_table);
    @(posedge clk);

    // Populate DAC table
    repeat(NUM_DAC_TABLE_SAMPLES) begin
        CSR0.write32(WR_REG_OFFSET_ADDRESS, dacAddr);
        @(posedge clk);
        CSR0.write32(WR_REG_OFFSET_CSR, WR_W_CSR_ADDRESS_BANK |
            (dacData & WR_W_CSR_ADDRESS_MASK));
        @(posedge clk);

        dacAddr = dacAddr + 1;
        dacData = dacData + 1;
    end

    // Start iterating table for a few cycles
    CSR0.write32(WR_REG_OFFSET_CSR, WR_W_CSR_GPIO_BANK | WR_W_CSR_GPIO_RUN);
    @(posedge clk);

    module_start_run_table = 1;
    @(posedge clk);

    wait(module_table_run_done);
    @(posedge clk);

    // Stop iterating table for a few cycles
    CSR0.write32(WR_REG_OFFSET_CSR, WR_W_CSR_GPIO_BANK & ~WR_W_CSR_GPIO_RUN);
    @(posedge clk);

    repeat(16) begin
        @(posedge clk);
    end

    module_done = 1;
end

initial begin
    wait(module_start_run_table);
    @(posedge axis_clk);

    // wait a few table cycles
    repeat(NUM_DAC_TABLE_SAMPLES/SAMPLES_PER_CLOCK*10) begin
        @(posedge axis_clk);
    end

    module_table_run_done = 1;
end

wire evrHbComb = (evrHbCnt == 0);
reg [HB_CNT_WIDTH-1:0] evrHbCnt = 0;
reg evrHbMarker = 0;
always @(posedge axis_clk) begin
    evrHbCnt <= evrHbCnt + 1;

    evrHbMarker <= evrHbComb;
    if (evrHbComb)
        evrHbCnt <= evrHbCnt+ 1;
end

// Generate stall signal every few clocks
reg stall = 0;
reg [3:0] stallCnt = 0;
always @(posedge axis_clk) begin
    stallCnt <= stallCnt + 1;
    stall <= (stallCnt == 0);
end

assign axis_TREADY = !stall;

endmodule
