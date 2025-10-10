`timescale 1ns / 1ns

module genericSPI_tb #(
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
localparam WR_W_CSR_CPOL                     = 'h20000000;
localparam WR_W_CSR_CPHA                     = 'h10000000;

//
// Read CSR fields
//
localparam WR_R_CSR_BUSY                     = 'h80000000;

reg module_done = 0;
integer errors = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("genericSPI.vcd");
        $dumpvars(0, genericSPI_tb);
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
wire                 SPI_SDO;
reg [15:0]           SPI_SDO_r = 0;
reg                  lsbFirst = 0, largeTransfer = 0;
reg                  cpol = 0, cpha = 0;

localparam SPI_PERIPH_REG_DATA = 16'h55AA;

genericSPI #(
    .CLK_RATE(CLK_RATE),
    .BIT_RATE(BIT_RATE),
    .CSB_WIDTH(CSB_WIDTH)
) genericSPI (
    .clk(clk),
    .csrStrobe(GPIO_STROBES[0]),
    .gpioOut(GPIO_OUT),
    .status(csr),

    .SPI_CLK(SPI_CLK),
    .SPI_CSB(SPI_CSB),
    .SPI_LE(SPI_LE),
    .SPI_SDI(SPI_SDI),
    .SPI_SDO(SPI_SDO)
);

// set-up module
reg [15:0] data = 0;
initial begin
    module_done = 0;
    wait(CSR0.ready);
    @(posedge clk);

    // Test 1
    // 8-bit address, 8-bit data
    data = 'h07 << 8 | 'hAA;
    lsbFirst = 1;
    largeTransfer = 0;
    cpol = 0;
    cpha = 0;
    CSR0.write32(WR_REG_OFFSET_CSR, (largeTransfer? WR_W_CSR_24_BIT_OP : 0) |
                                    (lsbFirst? WR_W_CSR_LSB_FIRST : 0) |
                                    (cpol? WR_W_CSR_CPOL : 0) |
                                    (cpha? WR_W_CSR_CPHA : 0) |
                                    (0 << WR_W_CSR_DEVSEL_SHIFT) |
                                    data);
    repeat(200) begin
        @(posedge clk);
    end

    // Test 2
    // 8-bit address, 8-bit data
    data = 'h07 << 8 | 'hAA;
    lsbFirst = 1;
    largeTransfer = 0;
    cpol = 0;
    cpha = 1;
    CSR0.write32(WR_REG_OFFSET_CSR, (largeTransfer? WR_W_CSR_24_BIT_OP : 0) |
                                    (lsbFirst? WR_W_CSR_LSB_FIRST : 0) |
                                    (cpol? WR_W_CSR_CPOL : 0) |
                                    (cpha? WR_W_CSR_CPHA : 0) |
                                    (0 << WR_W_CSR_DEVSEL_SHIFT) |
                                    data);
    repeat(200) begin
        @(posedge clk);
    end

    module_done = 1;
end

// Peripheral
reg SPI_CLK_d = 0;
reg spiClkFirst = 0;
wire SPI_CLK_re = SPI_CLK & ~SPI_CLK_d;
wire SPI_CLK_fe = ~SPI_CLK & SPI_CLK_d;
wire SPI_CLK_tick = cpol == 0? SPI_CLK_re : SPI_CLK_fe;
always @(posedge clk) begin
    SPI_CLK_d <= SPI_CLK;

    if (SPI_CSB[0]) begin
        spiClkFirst <= 1;
    end else begin
        if (cpha == 1) begin
            if (SPI_CLK_tick) begin
                if (spiClkFirst) begin
                    SPI_SDO_r <= SPI_PERIPH_REG_DATA;
                    spiClkFirst <= 0;
                end else begin
                    if (lsbFirst) begin
                        SPI_SDO_r[0+:15] <= SPI_SDO_r[1+:15];
                    end else begin
                        SPI_SDO_r[1+:15] <= SPI_SDO_r[0+:15];
                    end
                end
            end
        end else begin
            if (spiClkFirst) begin
                SPI_SDO_r <= SPI_PERIPH_REG_DATA;
                spiClkFirst <= 0;
            end else if (SPI_CLK_tick) begin
                spiClkFirst <= 0;
                if (lsbFirst) begin
                    SPI_SDO_r[0+:15] <= SPI_SDO_r[1+:15];
                end else begin
                    SPI_SDO_r[1+:15] <= SPI_SDO_r[0+:15];
                end
            end
        end
    end
end

assign SPI_SDO = lsbFirst? SPI_SDO_r[0] : SPI_SDO_r[15];

endmodule
