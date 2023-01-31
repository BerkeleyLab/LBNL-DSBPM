`timescale 1ns / 1ns

module genericWaveformRecorder_tb #(
    parameter CSR_DATA_BUS_WIDTH = 32,
    parameter CSR_STROBE_BUS_WIDTH = 8,

    parameter ACQ_CAPACITY = 1024,
    parameter DATA_WIDTH = 16,
    parameter AXI_ADDR_WIDTH = 35,
    parameter AXI_DATA_WIDTH = 128
);

//
// Register offsets
//
localparam WR_REG_OFFSET_CSR                  = 0;
localparam WR_REG_OFFSET_PRETRIGGER_COUNT     = 1;
localparam WR_REG_OFFSET_ACQUISITION_COUNT    = 2;
localparam WR_REG_OFFSET_ADDRESS_LSB          = 3;
localparam WR_REG_OFFSET_ADDRESS_MSB          = 4;
localparam WR_REG_OFFSET_TIMESTAMP_SECONDS    = 5;
localparam WR_REG_OFFSET_TIMESTAMP_TICKS      = 6;

//
// CSR fields
//
localparam WR_CSR_TRIGGER_MASK             = 'hFF000000;
localparam WR_CSR_EVENT_TRIGGER_7_ENABLE   = 'h80000000;
localparam WR_CSR_EVENT_TRIGGER_6_ENABLE   = 'h40000000;
localparam WR_CSR_EVENT_TRIGGER_5_ENABLE   = 'h20000000;
localparam WR_CSR_EVENT_TRIGGER_4_ENABLE   = 'h10000000;
localparam WR_CSR_SOFT_TRIGGER_ENABLE      = 'h01000000;
localparam WR_CSR_RESET_BAR_MODE           = 'h400;
localparam WR_CSR_TEST_ACQUISITION_MODE    = 'h200;
localparam WR_CSR_DIAGNOSTIC_MODE          = 'h100;
localparam WR_CSR_ARM                      = 'h1;

reg test_done = 0;
integer errors = 0;
integer idx = 0;
initial begin
	if ($test$plusargs("vcd")) begin
		$dumpfile("genericWaveformRecorder.vcd");
		$dumpvars(0, genericWaveformRecorder_tb);
	end

    wait(test_done);
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

integer adc_cc;
reg adc_clk = 0;
initial begin
	adc_clk = 0;
	for (adc_cc = 0; adc_cc < 1000; adc_cc = adc_cc+1) begin
		adc_clk = 0; #4;
		adc_clk = 1; #4;
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

wire [31:0] wfr_CSR, wfr_pretrig_count, wfr_acq_count, wfr_acq_addr_MSB, wfr_acq_addr_LSB;
wire [63:0] wfr_when_triggered;
assign GPIO_IN[WR_REG_OFFSET_CSR              ] = wfr_CSR;
assign GPIO_IN[WR_REG_OFFSET_PRETRIGGER_COUNT ] = wfr_pretrig_count;
assign GPIO_IN[WR_REG_OFFSET_ACQUISITION_COUNT] = wfr_acq_count;
assign GPIO_IN[WR_REG_OFFSET_ADDRESS_LSB      ] = wfr_acq_addr_LSB;
assign GPIO_IN[WR_REG_OFFSET_ADDRESS_MSB      ] = wfr_acq_addr_MSB;
assign GPIO_IN[WR_REG_OFFSET_TIMESTAMP_SECONDS] = wfr_when_triggered[63:32];
assign GPIO_IN[WR_REG_OFFSET_TIMESTAMP_TICKS  ] = wfr_when_triggered[31:0];

wire  [AXI_ADDR_WIDTH-1:0] wr_axi_AWADDR;
wire                 [7:0] wr_axi_AWLEN;
wire                       wr_axi_AWVALID;
wire                       wr_axi_AWREADY = 1'b1;
wire  [AXI_DATA_WIDTH-1:0] wr_axi_WDATA;
wire                       wr_axi_WLAST;
wire                       wr_axi_WVALID;
wire                       wr_axi_WREADY = 1'b1;
wire                 [1:0] wr_axi_BRESP = 2'b00; // OKAY
reg                        wr_axi_BVALID = 0;

reg       [DATA_WIDTH-1:0] data = 0;
reg       [DATA_WIDTH-1:0] counter = 0;
reg                        valid = 0;
reg                  [7:0] triggers = 0;
reg                 [63:0] timestamp = 0;

genericWaveformRecorder #(
    .ACQ_CAPACITY(ACQ_CAPACITY),
    .DATA_WIDTH(8*DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .FIFO_CAPACITY(16)
  )
  DUT(
    .sysClk(clk),
    .writeData(GPIO_OUT),
    .regStrobes(GPIO_STROBES[0+:5]),
    .csr(wfr_CSR),
    .pretrigCount(wfr_pretrig_count),
    .acqCount(wfr_acq_count),
    .acqAddressMSB(wfr_acq_addr_MSB),
    .acqAddressLSB(wfr_acq_addr_LSB),
    .whenTriggered(wfr_when_triggered),

    .clk(adc_clk),
    .data({8{data}}),
    .valid(valid),
    .triggers(triggers),
    .timestamp(timestamp),
    .axi_AWADDR(wr_axi_AWADDR),
    .axi_AWLEN(wr_axi_AWLEN),
    .axi_AWVALID(wr_axi_AWVALID),
    .axi_AWREADY(wr_axi_AWREADY),
    .axi_WDATA(wr_axi_WDATA),
    .axi_WLAST(wr_axi_WLAST),
    .axi_WVALID(wr_axi_WVALID),
    .axi_WREADY(wr_axi_WREADY),
    .axi_BRESP(wr_axi_BRESP),
    .axi_BVALID(wr_axi_BVALID));

// trivial driving of AXI slave
always @(posedge adc_clk) begin
    wr_axi_BVALID <= wr_axi_WVALID;
end

// stimulus
initial begin
    wait(CSR0.ready);
    @(posedge clk);

    @(posedge clk);
    CSR0.write32(WR_REG_OFFSET_PRETRIGGER_COUNT, 10);
    @(posedge clk);
    CSR0.write32(WR_REG_OFFSET_ACQUISITION_COUNT, 100);
    @(posedge clk);
    CSR0.write32(WR_REG_OFFSET_ADDRESS_LSB, 32'h00010000);
    @(posedge clk);
    CSR0.write32(WR_REG_OFFSET_ADDRESS_MSB, 0);
    @(posedge clk);
    CSR0.write32(WR_REG_OFFSET_CSR,
        WR_CSR_SOFT_TRIGGER_ENABLE |
        WR_CSR_ARM);

    repeat(1000) begin
        @(posedge clk);
    end

    test_done = 1;
end

initial begin
    repeat(100) begin
        @(posedge adc_clk);
    end

    triggers <= 8'h1;
    @(posedge adc_clk);
    triggers <= 8'h0;
end

// simulate something with at least < 10% valids,
// such as TbT, FA, SA
wire valid_comb = !(cc % 10)? 1 : 0;
always @(posedge adc_clk) begin
    valid <= valid_comb;
    data <= valid_comb ? counter : 'hdead;

    if (valid_comb)
        counter <= counter + 1;
end

always @(posedge adc_clk) begin
    timestamp <= timestamp + 1;
end

endmodule
