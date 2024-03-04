`timescale 1ns / 1ns

module afeSPI_tb #(
    parameter CSR_DATA_BUS_WIDTH = 32,
    parameter CSR_STROBE_BUS_WIDTH = 1,

    parameter CLK_RATE  = 100000000,
    parameter BIT_RATE  = 12500000,
    parameter CSB_WIDTH = 4,
    parameter LE_WIDTH = CSB_WIDTH
);

//
// Register offsets
//
localparam WR_REG_OFFSET_CSR                  = 0;

//
// Write CSR fields
//
localparam WR_W_CSR_DEVSEL_SHIFT             = 24;
localparam WR_W_CSR_DEVSEL_MASK              = 'h0F000000;

localparam WR_W_CSR_24_BIT_OP                = 'h80000000;
localparam WR_W_CSR_LSB_FIRST                = 'h40000000;

//
// Read CSR fields
//
localparam WR_R_CSR_BUSY                     = 'h80000000;

reg module_done = 0;
reg module_ready = 0;
integer errors = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("afeSPI.vcd");
        $dumpvars(0, afeSPI_tb);
    end

    wait(module_done);
    $display("%s",errors==0?"# PASS":"# FAIL");
    $finish();
end

integer cc;
reg clk = 0;
initial begin
    clk = 0;
    for (cc = 0; cc < 1000; cc = cc+1) begin
        clk = 0; #5;
        clk = 1; #5;
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

// DUT

wire [31:0] csr;
assign GPIO_IN[0] = csr;

wire                 SPI_CLK;
wire [CSB_WIDTH-1:0] SPI_CSB;
wire [LE_WIDTH-1:0]  SPI_LE;
wire                 SPI_SDI;

afeSPI #(
    .CLK_RATE(CLK_RATE),
    .BIT_RATE(BIT_RATE),
    .CSB_WIDTH(CSB_WIDTH)
) afeSPI (
    .clk(clk),
    .csrStrobe(GPIO_STROBES[0]),
    .gpioOut(GPIO_OUT),
    .status(csr),

    .SPI_CLK(SPI_CLK),
    .SPI_CSB(SPI_CSB),
    .SPI_LE(SPI_LE),
    .SPI_SDI(SPI_SDI),
    .SPI_SDO(1'b0)
);

// set-up module
reg [15:0] data = 0;
initial begin
    module_done = 0;
    wait(CSR0.ready);
    @(posedge clk);

    // 8-bit address, 8-bit data
    data = 'h07 << 8 | 'hAA;
    CSR0.write32(WR_REG_OFFSET_CSR, WR_W_CSR_LSB_FIRST |
                                    (0 << WR_W_CSR_DEVSEL_SHIFT) |
                                    data);
    @(posedge clk);

    module_ready = 1;
    @(posedge clk);

    repeat(1000) begin
        @(posedge clk);
    end
    module_done = 1;
end

endmodule
