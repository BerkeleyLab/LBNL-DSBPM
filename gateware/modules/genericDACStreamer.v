//
// Generic DAC streamer
//
module genericDACStreamer #(
    parameter BUS_WIDTH             = 32,
    parameter AXIS_DATA_WIDTH       = 256,
    parameter DAC_DATA_WIDTH        = 16,
    parameter DAC_ADDRESS_WIDTH     = 14
    ) (
    // sysClk synchronous signals
    input                        sysClk,
    input        [BUS_WIDTH-1:0] sysGpioData,
    output wire  [BUS_WIDTH-1:0] sysGpioCsr,
    input                        sysAddressStrobe,
    input                        sysGpioStrobe,

    // EVR synchornous signals
    input                        evrHbMarker,

    // axis_CLK synchronous signals
    input                             axis_CLK,
    output reg [AXIS_DATA_WIDTH-1:0]  axis_TDATA,
    output reg                        axis_TVALID,
    input                             axis_READY);

//////////////////////////////////////////////////////////////////////////////
//                             SYS CLOCK DOMAIN                             //
//////////////////////////////////////////////////////////////////////////////

localparam WRITE_ADDRESS_WIDTH = DAC_ADDRESS_WIDTH;
localparam WRITE_DATA_WIDTH = DAC_DATA_WIDTH;
localparam READ_DATA_WIDTH = AXIS_DATA_WIDTH;

localparam SAMPLES_PER_CLOCK = READ_DATA_WIDTH / WRITE_DATA_WIDTH;
localparam SAMPLES_PER_CLOCK_WIDTH = $clog2(SAMPLES_PER_CLOCK);
localparam READ_ADDRESS_WIDTH = WRITE_ADDRESS_WIDTH - SAMPLES_PER_CLOCK_WIDTH;

//
// Bits in GPIO write data
//
wire                    sysMemWrBankSelect = sysGpioData[31];
wire [WRITE_DATA_WIDTH-1:0] sysMemWrData = sysGpioData[WRITE_DATA_WIDTH-1:0];

//
// Generate RAM write-enable signals
//
wire sysMemWrStrobe = sysGpioStrobe && (sysMemWrBankSelect == 1'b0);

// Address to be written
reg [WRITE_ADDRESS_WIDTH-1:0] sysMemWrAddress;

//
// Instantiate the DAC lookup tables
//
reg [READ_ADDRESS_WIDTH-1:0] axisIndex = 0;
wire [READ_DATA_WIDTH-1:0] axisData;
genericDPRAM #(.WRITE_ADDRESS_WIDTH(WRITE_ADDRESS_WIDTH),
               .WRITE_DATA_WIDTH(WRITE_DATA_WIDTH),
               .READ_ADDRESS_WIDTH(READ_ADDRESS_WIDTH),
               .READ_DATA_WIDTH(READ_DATA_WIDTH))
  dacTable (
    .wClk(sysClk),
    .wEnable(sysMemWrStrobe),
    .wAddr(sysMemWrAddress),
    .wData(sysMemWrData),
    .rClk(axis_CLK),
    .rAddr(axisIndex),
    .rData(axisData));

//
// CSR
//
assign sysGpioCsr = { {32-8-READ_ADDRESS_WIDTH{1'b0}},
                        sysLastIdx,
                        {8-1-1{1'b0}},
                        sysSynced,
                        sysRun };
reg sysRun = 0;
// Last index to be read
reg [READ_ADDRESS_WIDTH-1:0] sysLastIdx;
always @(posedge sysClk) begin
    if (sysAddressStrobe) begin
        sysMemWrAddress <= sysGpioData[WRITE_ADDRESS_WIDTH-1:0];
    end
    if (sysGpioStrobe) begin
        case (sysMemWrBankSelect)
        1'b0: sysLastIdx <= sysMemWrAddress[SAMPLES_PER_CLOCK_WIDTH+:READ_ADDRESS_WIDTH];
        1'b1: begin
            sysRun      <= sysGpioData[0];
        end
        default: ;
        endcase
    end
end

//////////////////////////////////////////////////////////////////////////////
//                             AXIS CLOCK DOMAIN                            //
//////////////////////////////////////////////////////////////////////////////

// Caputure HB event into AXIS domain
(* ASYNC_REG="TRUE" *) reg axisHbEvent_m = 0;
reg axisHbEvent = 0, axisHbEvent_d1 = 0;
reg axisSyncMarker = 0;
always @(posedge axis_CLK) begin
    axisHbEvent_m  <= evrHbMarker;
    axisHbEvent    <= axisHbEvent_m;
    axisHbEvent_d1 <= axisHbEvent;

    axisSyncMarker <= axisHbEvent && !axisHbEvent_d1;
end

wire axisRun;
wire [READ_ADDRESS_WIDTH-1:0] axisLastIdx;

forwardData #(
    .DATA_WIDTH(1+READ_ADDRESS_WIDTH)
)
  forwardSysToAxis (
    .inClk(sysClk),
    .inData({ sysRun, sysLastIdx }),
    .outClk(axis_CLK),
    .outData({ axisRun, axisLastIdx })
);

reg axisSynced = 0;
always @(posedge axis_CLK)
begin
    if (axisRun) begin
        if (axisSyncMarker) begin
            if (axisIndex == 0) begin
                axisSynced <= 1;
            end else begin
                axisSynced <= 0;
            end
            axisIndex <= 1;
        end
        else begin
            axisIndex <= (axisIndex == axisLastIdx) ? 0 : axisIndex + 1;
        end

        axis_TDATA <= axisData;
        axis_TVALID <= 1;
    end else begin
        axis_TDATA <= 0;
        axis_TVALID <= 0;
    end
end

//
// axis_CLK to sysClk
//
wire sysSynced;
forwardData #(
    .DATA_WIDTH(1)
)
  forwardAxisToSys (
    .inClk(axis_CLK),
    .inData(axisSynced),
    .outClk(sysClk),
    .outData(sysSynced)
);

endmodule
