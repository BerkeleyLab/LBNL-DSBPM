// SPI interface to analog front end components
// 16 or 24 bits

module genericSPI #(
    parameter CLK_RATE  = 100000000,
    parameter BIT_RATE  = 12500000,
    parameter CSB_WIDTH = 9,
    parameter DEBUG     = "false",
    // Don't change these
    parameter LE_WIDTH = CSB_WIDTH
    ) (
    input                      clk,
    (*mark_debug=DEBUG*) input csrStrobe,
    input               [31:0] gpioOut,
    output wire         [31:0] status,

    (*mark_debug=DEBUG*) output reg                 SPI_CLK = 0,
    (*mark_debug=DEBUG*) output reg [CSB_WIDTH-1:0] SPI_CSB = {CSB_WIDTH{1'b1}},
    (*mark_debug=DEBUG*) output reg [LE_WIDTH-1:0]  SPI_LE = {LE_WIDTH{1'b0}},
    (*mark_debug=DEBUG*) output wire                SPI_SDI,
    (*mark_debug=DEBUG*) input                      SPI_SDO);

localparam BITRATE_DIVISOR = ((CLK_RATE / 2) + BIT_RATE - 1) / BIT_RATE;
localparam TICK_COUNTER_WIDTH = $clog2(BITRATE_DIVISOR-1)+1;
localparam TICK_COUNTER_RELOAD = BITRATE_DIVISOR - 2;
reg [TICK_COUNTER_WIDTH-1:0] tickCounter;
wire tick = tickCounter[TICK_COUNTER_WIDTH-1];

localparam SHIFTREG_WIDTH = 24;
reg [SHIFTREG_WIDTH-1:0] shiftReg;
reg lsbFirst = 0;
assign SPI_SDI = lsbFirst ? shiftReg[0] : shiftReg[SHIFTREG_WIDTH-1];

localparam BIT_COUNTER_WIDTH = $clog2(SHIFTREG_WIDTH-1);
reg [BIT_COUNTER_WIDTH:0] bitCounter;
wire bitCounterOdd = bitCounter[0];
wire bitCounterEven = ~bitCounter[0];
wire done = bitCounter[BIT_COUNTER_WIDTH];

// State machine
localparam S_IDLE     = 0,
           S_TRANSFER = 1,
           S_CSB_LE   = 2,
           S_FINISH   = 3;
(*mark_debug=DEBUG*) reg [1:0] state = S_IDLE;
reg busy = 0;

assign status = { busy, {32-1-SHIFTREG_WIDTH{1'b0}}, shiftReg };

localparam DEVSEL_WIDTH = CSB_WIDTH > 1 ? $clog2(CSB_WIDTH) : 1;

wire [DEVSEL_WIDTH-1:0] deviceSelect = gpioOut[SHIFTREG_WIDTH+:DEVSEL_WIDTH];
wire [SHIFTREG_WIDTH-1:0] spiData = gpioOut[0+:SHIFTREG_WIDTH];
wire spiLargeTransfer = gpioOut[31];
wire spiLSBFirst = gpioOut[30];

always @(posedge clk) begin
    if (state == S_IDLE) begin
        tickCounter <= TICK_COUNTER_RELOAD;
        if (csrStrobe) begin
            busy <= 1;
            // full 24-bit transfer, all good
            shiftReg <= spiLargeTransfer? spiData :
            // 16-bit transfer needs to be aligned depending
            // if transfering LSB or MSB first
                (!spiLSBFirst) ? {spiData[0+:SHIFTREG_WIDTH-8], 8'h00} :
                               {8'h00, spiData[0+:SHIFTREG_WIDTH-8]};
            bitCounter <= spiLargeTransfer? 24 - 2 : 16 - 2;
            lsbFirst <= spiLSBFirst;
            SPI_CSB[deviceSelect] <= 0;
            SPI_LE[deviceSelect] <= 0;
            state <= S_TRANSFER;
        end
        else begin
            SPI_CSB <= {CSB_WIDTH{1'b1}};
            SPI_LE <= 0;
            SPI_CLK <= 0;
            busy <= 0;
        end
    end
    else if (tick) begin
        case (state)
        S_TRANSFER: begin
            tickCounter <= TICK_COUNTER_RELOAD;
            SPI_CLK <= !SPI_CLK;
            if (SPI_CLK) begin
                bitCounter <= bitCounter - 1;
                if (done) begin
                    state <= S_CSB_LE;
                end
                else begin
                    if (lsbFirst) begin
                        shiftReg[0+:SHIFTREG_WIDTH-1] <=
                            shiftReg[1+:SHIFTREG_WIDTH-1];
                    end else begin
                        shiftReg[1+:SHIFTREG_WIDTH-1] <=
                            shiftReg[0+:SHIFTREG_WIDTH-1];
                    end
                end
            end
            else begin
                // Only sample after the shift
                if (bitCounterOdd) begin
                    if (lsbFirst) begin
                        shiftReg[SHIFTREG_WIDTH-1] <= SPI_SDO;
                    end else begin
                        shiftReg[0] <= SPI_SDO;
                    end
                end
            end
        end
        S_CSB_LE: begin
            tickCounter <= TICK_COUNTER_RELOAD;
            SPI_CSB <= {CSB_WIDTH{1'b1}};
            SPI_LE[deviceSelect] <= 1;
            state <= S_FINISH;
        end
        S_FINISH: begin
            tickCounter <= TICK_COUNTER_RELOAD;
            SPI_LE[deviceSelect] <= 0;
            state <= S_IDLE;
        end
        default: state <= S_IDLE;
        endcase
    end
    else begin
        tickCounter <= tickCounter - 1;
    end
end

endmodule
