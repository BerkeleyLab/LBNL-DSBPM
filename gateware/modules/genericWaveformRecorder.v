//
// Generic Waveform Recorder
//
module genericWaveformRecorder #(
    // "FALSE" = usual pause after a burst and small burst size
    // (i.e., 8 beats);
    // "TRUE" = skip pause state and larger burst
    // size (64 beats). Note that we need to use INCR burst type
    // for more than 16 beats (as per AXI protocol specification:
    // https://developer.arm.com/documentation/ihi0022/e/, page
    // A3-46)
    parameter HIGH_BANDWIDTH_MODE = "FALSE",
    parameter DATA_WIDTH      = 128,
    parameter TIMESTAMP_WIDTH = 64,
    parameter BUS_WIDTH       = 32,
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_DATA_WIDTH  = 128,
    parameter FIFO_CAPACITY   = 256, // Minimum of 16
    parameter ACQ_CAPACITY    = 1 << 23 // Max samples (4 32-bit values/sample)
    ) (
    // sysClk synchronous signals
    input                        sysClk,
    input        [BUS_WIDTH-1:0] writeData,
    input                  [4:0] regStrobes,
    output wire       [BUS_WIDTH-1:0] csr, pretrigCount, acqCount, acqAddressMSB, acqAddressLSB,
    output wire  [TIMESTAMP_WIDTH-1:0] whenTriggered,

    // clk synchronous signals
    input                        clk,
    input       [DATA_WIDTH-1:0] data,
    input                        valid,
    input                  [7:0] triggers,
    input  [TIMESTAMP_WIDTH-1:0] timestamp,

    output wire [AXI_ADDR_WIDTH-1:0] axi_AWADDR,
    output wire                [7:0] axi_AWLEN,
    output reg                       axi_AWVALID = 0,
    input                            axi_AWREADY,
    output wire [2:0]                axi_AWSIZE,
    output wire [AXI_DATA_WIDTH-1:0] axi_WDATA,
    output wire                      axi_WLAST,
    output reg                       axi_WVALID = 0,
    output wire [AXI_DATA_WIDTH/8-1:0] axi_WSTRB,
    input                            axi_WREADY,
    input                      [1:0] axi_BRESP,
    input                            axi_BVALID);

parameter WRITE_ADDR_WIDTH  = $clog2(ACQ_CAPACITY);
parameter WRITE_COUNT_WIDTH = $clog2(ACQ_CAPACITY+1);
parameter BEATCOUNT_WIDTH   = HIGH_BANDWIDTH_MODE == "TRUE"? 6:3; // 64 x 8 beats per transfer
parameter MULTI_BEAT_LENGTH = (1 << BEATCOUNT_WIDTH);
parameter FIFO_ADDR_WIDTH   = $clog2(FIFO_CAPACITY);

localparam FIFO_PROG_EMPTY_THRESHOLD = MULTI_BEAT_LENGTH-1;

//////////////////////////////////////////////////////////////////////////////
//                             SYS CLOCK DOMAIN                             //
//////////////////////////////////////////////////////////////////////////////

assign pretrigCount  = { {BUS_WIDTH-WRITE_COUNT_WIDTH{1'b0}}, sysPretrigCount_r };
assign acqCount      = { {BUS_WIDTH-WRITE_COUNT_WIDTH{1'b0}}, sysAcqCount_r };

generate
if (HIGH_BANDWIDTH_MODE != "TRUE" && HIGH_BANDWIDTH_MODE != "FALSE") begin
    HIGH_BANDWIDTH_MODE_supports_only_TRUE_or_FALSE error();
end
endgenerate

generate
if (AXI_ADDR_WIDTH > BUS_WIDTH) begin
    assign acqAddressLSB = sysAxi_AWADDR[0+:BUS_WIDTH];
    assign acqAddressMSB = { {BUS_WIDTH-(AXI_ADDR_WIDTH-BUS_WIDTH){1'b0}},
                              sysAxi_AWADDR[AXI_ADDR_WIDTH-1:BUS_WIDTH] };
end else begin
    assign acqAddressLSB = { {BUS_WIDTH-AXI_ADDR_WIDTH{1'b0}},
                            sysAxi_AWADDR[AXI_ADDR_WIDTH-1:0] };
    assign acqAddressMSB = 0;
end
endgenerate

generate
if (WRITE_ADDR_WIDTH+4 > AXI_ADDR_WIDTH-1) begin
    WRITE_ADDR_WIDTH_is_bigger_than_AXI_ADDR_WIDTH error();
end
endgenerate

generate
if (FIFO_CAPACITY < 16) begin
    FIFO_CAPACITY_is_less_then_16 error();
end
endgenerate

generate
if (!(DATA_WIDTH == AXI_DATA_WIDTH || 2*DATA_WIDTH == AXI_DATA_WIDTH)) begin
    DATA_WIDTH_is_different_than_once_or_twice_AXI_DATA_WIDTH error();
end
endgenerate

assign whenTriggered = sysWhenTriggered;

//
// Microblaze interface
//
wire sysCsrStrobe = regStrobes[0];
wire sysPretrigStrobe = regStrobes[1];
wire sysAcqCountStrobe = regStrobes[2];
wire sysAddrLSBStrobe = regStrobes[3];
wire sysAddrMSBStrobe = regStrobes[4];
reg [WRITE_COUNT_WIDTH-1:0] sysPretrigCount_r, sysAcqCount_r;
reg [7:0] sysCsrTriggerEnables = 0;
reg       sysCsrDiagMode = 0;
wire     sysFull, sysOverrun;
reg      sysCsrArmed = 0;
wire     sysAcqArmed;
wire     sysAcqPretrigLeftDone;
wire [1:0] sysCsrBRESP;
wire [2:0] sysState;
assign csr = { sysCsrTriggerEnables,
               8'b0,
               6'b0, sysAcqPretrigLeftDone, sysCsrDiagMode,
              sysFull, sysCsrBRESP, sysOverrun, sysState, sysAcqArmed };
reg [2*BUS_WIDTH-1:0] sysAcqBase;

//
// CSR
//
reg sysCsrToggle = 0;
always @(posedge sysClk) begin
    if (sysPretrigStrobe)  sysPretrigCount_r                <= writeData;
    if (sysAcqCountStrobe) sysAcqCount_r                    <= writeData;
    if (sysAddrLSBStrobe)  sysAcqBase[0+:BUS_WIDTH]         <= writeData;
    if (sysAddrMSBStrobe)  sysAcqBase[BUS_WIDTH+:BUS_WIDTH] <= writeData;
    if (sysCsrStrobe) begin
        sysCsrToggle <= ~sysCsrToggle;
        sysCsrTriggerEnables <= writeData[31:24];
        sysCsrDiagMode <= writeData[8];
        sysCsrArmed <= writeData[0];
    end
end


//
// sysClk to clk
//
wire [WRITE_COUNT_WIDTH-1:0] csrPretrigCount, csrAcqCount;
wire [7:0] csrTriggerEnables;
wire       csrToggle, csrArmed, csrDiagMode;
wire [2*BUS_WIDTH-1:0] acqBase;
forwardData #(.DATA_WIDTH(1+1+1+8+BUS_WIDTH+BUS_WIDTH+WRITE_COUNT_WIDTH+WRITE_COUNT_WIDTH))
  forwardCSRtoAcq (
    .inClk(sysClk),
    .inData({   sysCsrToggle,
                sysCsrArmed,
                sysCsrDiagMode,
                sysCsrTriggerEnables,
                sysAcqBase[0+:BUS_WIDTH], // LSB
                sysAcqBase[BUS_WIDTH+:BUS_WIDTH], // MSB
                sysAcqCount_r,
                sysPretrigCount_r }),
    .outClk(clk),
    .outData({  csrToggle,
                csrArmed,
                csrDiagMode,
                csrTriggerEnables,
                acqBase[0+:BUS_WIDTH], // LSB
                acqBase[BUS_WIDTH+:BUS_WIDTH], // MSB
                csrAcqCount,
                csrPretrigCount }));

//////////////////////////////////////////////////////////////////////////////
//                             DATA CLOCK DOMAIN                            //
//////////////////////////////////////////////////////////////////////////////

reg [7:0] triggerReg, triggerReg_d;

//
// Data transfer
//
reg [BUS_WIDTH-1:0] diagCountHold;
reg [BUS_WIDTH-1:0] diagCount;

//
// AXI state machine
//
parameter S_WAIT  = 3'd0;
parameter S_ADDR  = 3'd1;
parameter S_DATA  = 3'd2;
parameter S_ACK   = 3'd3;
parameter S_PAUSE = 3'd4;
reg                   [2:0] state = S_WAIT;
reg                   [5:0] pauseCount = 0;
reg                         triggerFlag = 0, triggered = 0;
reg                         acqPretrigLeftDone = 0;
reg [WRITE_COUNT_WIDTH-1:0] acqPretrigLeft = 0, acqLeft = 0;
reg  [WRITE_ADDR_WIDTH-1:0] writeAddr = 0;
assign axi_AWADDR = { acqBase[AXI_ADDR_WIDTH-1:WRITE_ADDR_WIDTH + 4], writeAddr, 4'b0 };
reg [BEATCOUNT_WIDTH-1:0] beatCount;
assign axi_AWLEN = { {(8-BEATCOUNT_WIDTH){1'b0}}, beatCount };
assign axi_WLAST = (state == S_DATA) && (beatCount == 0);
assign axi_WDATA = csrDiagMode ? { fifoOut[AXI_DATA_WIDTH-1:2*BUS_WIDTH],
                            {(BUS_WIDTH-BEATCOUNT_WIDTH){1'b0}}, beatCount,
                            fifoOut[BUS_WIDTH-1:0] } : fifoOut;


//
// Provide some elasticity between incoming data and AXI
//
wire                       fifo_wr_en, fifo_rd_en;
wire                       fifoOverflow, fifoEmpty, fifoProgEmpty;
wire      [AXI_DATA_WIDTH-1:0] fifoIn, fifoOut;
wire                       dataValid;
reg [DATA_WIDTH-1:0]       dataHold;
reg                        dataPhase = 0;

generate
if (DATA_WIDTH == AXI_DATA_WIDTH) begin

assign dataValid = valid;
assign fifoIn = csrDiagMode ? {data[DATA_WIDTH-1:BUS_WIDTH], diagCount} :
    data;

always @(posedge clk) begin
    if (valid) diagCount <= diagCount + 1;
end

end
if (2*DATA_WIDTH == AXI_DATA_WIDTH) begin

always @(posedge clk) begin
    if (valid) begin
        dataPhase <= !dataPhase;
        dataHold <= data;
    end
end

assign dataValid = valid && dataPhase;
assign fifoIn = csrDiagMode ? {
        data[DATA_WIDTH-1:BUS_WIDTH], diagCount,
        dataHold[DATA_WIDTH-1:BUS_WIDTH], diagCountHold} :
        {data, dataHold};

always @(posedge clk) begin
    if (valid) begin
        diagCount <= diagCount + 1;
        diagCountHold <= diagCount;
    end
end

end
endgenerate

assign fifo_wr_en = (acqArmed && dataValid
                  && (!triggerFlag || (acqLeft != 0)));
assign fifo_rd_en = (((state == S_ADDR) && axi_AWREADY)
                  || ((state == S_DATA) && (beatCount != 0) && axi_WREADY));
wire signed [FIFO_ADDR_WIDTH:0] fifoCount;
genericFifo #(
    .dw(AXI_DATA_WIDTH),
    .aw(FIFO_ADDR_WIDTH),
    .fwft(0)
) fifo (
    .clk(clk),
    .din(fifoIn),
    .we(fifo_wr_en),

    .dout(fifoOut),
    .re(fifo_rd_en),
    .full(fifoOverflow),
    .empty(fifoEmpty),
    .count(fifoCount)
);

assign fifoProgEmpty = fifoCount < FIFO_PROG_EMPTY_THRESHOLD;
assign axi_AWSIZE = $clog2(AXI_DATA_WIDTH/8);
assign axi_WSTRB = {(AXI_DATA_WIDTH/8){1'b1}};

//
// The recorder
//
reg csrStrobe = 0, csrToggle_d1 = 0;
reg acqArmed = 0, overrun = 0, full = 0;
reg [TIMESTAMP_WIDTH-1:0] acqWhenTriggered = 0;
reg [1:0] csrBRESP = 0;
always @(posedge clk) begin
    csrToggle_d1 <= csrToggle;
    csrStrobe <= csrToggle_d1 ^ csrToggle;

    if (fifoOverflow) overrun <= 1;
    if (csrStrobe) begin
        full <= 0;
        if (csrArmed) begin
            if (!acqArmed) begin
                writeAddr <= 0;
                acqPretrigLeft <= csrPretrigCount;
                acqLeft <= csrAcqCount;
                acqArmed <= 1;
            end
        end
        else begin
            acqArmed <= 0;
        end
    end

    //
    // Watch for trigger
    //
    triggerReg <= triggers;
    triggerReg_d <= triggerReg;
    if (acqArmed) begin
        if ((acqPretrigLeft == 0)
         && ((csrTriggerEnables & triggerReg & ~triggerReg_d) != 0)) begin
            triggerFlag <= 1;
        end
        if (dataValid) begin
            if (triggerFlag) begin
                triggered <= 1;
                if (!triggered) acqWhenTriggered <= timestamp;
                if (acqLeft) begin
                    acqLeft <= acqLeft - 1;
                end
                else begin
                    // FIXME. This might not be aligned with
                    // the CSR reg values forwared to the CLK
                    // domain
                    if (!csrStrobe) begin
                        acqArmed <= 0;
                        full <= 1;
                    end
                end
            end
            else begin
                if (acqPretrigLeft) begin
                    acqPretrigLeft <= acqPretrigLeft - 1;
                    if (acqLeft) acqLeft <= acqLeft - 1;
                end else begin
                    acqPretrigLeftDone <= 1;
                end
            end
        end
    end
    else begin
        triggerFlag <= 0;
        triggered <= 0;
        acqPretrigLeftDone <= 0;
    end

    //
    // Acquisition AXI master state machine
    //
    case (state)
    //
    // Wait for data
    // Use a multi-word transfer if FIFO contains enough values
    // and the write address is not going to wrap around.
    // The FIFO prog_empty threshold is equal to MULTI_BEAT_LENGTH-1.
    //
    S_WAIT: begin
        if (!fifoProgEmpty
         && (writeAddr <= (ACQ_CAPACITY-MULTI_BEAT_LENGTH))) begin
            beatCount <= MULTI_BEAT_LENGTH-1;
            axi_AWVALID <= 1;
            state <= S_ADDR;
        end
        else if (!fifoEmpty) begin
            beatCount <= 0;
            axi_AWVALID <= 1;
            state <= S_ADDR;
        end
    end

    //
    // Set up a transfer
    //
    S_ADDR: begin
        if (axi_AWREADY) begin
            axi_AWVALID <= 0;
            axi_WVALID <= 1;
            state <= S_DATA;
        end
    end

    //
    // Transfer word(s)
    //
    S_DATA: begin
        if (axi_WREADY) begin
            writeAddr <= writeAddr + 1;
            if (beatCount) begin
                beatCount <= beatCount - 1;
            end
            else begin
                axi_WVALID <= 0;
                state <= S_ACK;
            end
        end
    end

    //
    // Wait for AXI acknowledgement
    //
    S_ACK: begin
        if (axi_BVALID) begin
            csrBRESP <= axi_BRESP;
            if ((axi_BRESP != 0) && !csrStrobe) begin
                acqArmed <= 0;
                acqLeft <= 0;
            end
            pauseCount <= ~0;

            state <= S_PAUSE;
            if (HIGH_BANDWIDTH_MODE == "TRUE")
                state <= S_WAIT;
        end
    end

    //
    // Give some time for other masters to run
    //
    S_PAUSE: begin
        if (pauseCount) pauseCount <= pauseCount - 1;
        else            state <= S_WAIT;
    end

    default: state <= S_WAIT;
    endcase
end

//
// clk to sysClk
//
wire [AXI_ADDR_WIDTH-1:0] sysAxi_AWADDR;
wire [TIMESTAMP_WIDTH-1:0] sysWhenTriggered;
forwardData #(.DATA_WIDTH(AXI_ADDR_WIDTH+TIMESTAMP_WIDTH+1+1+2+3+1+1))
  forwardAcqtoCSR (
    .inClk(clk),
    .inData({   axi_AWADDR, acqWhenTriggered, overrun, full,
                csrBRESP, state, acqArmed, acqPretrigLeftDone     }),
    .outClk(sysClk),
    .outData({  sysAxi_AWADDR, sysWhenTriggered, sysOverrun, sysFull,
                sysCsrBRESP, sysState, sysAcqArmed, sysAcqPretrigLeftDone}));

endmodule
