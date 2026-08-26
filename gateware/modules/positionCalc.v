//
// Convert button signal magnitudes to X, Y, Q, Sum.
//
module positionCalc #(
    parameter  MAG_WIDTH = 24,
    parameter DATA_WIDTH = 32)(
    input                   clk,

    input   [MAG_WIDTH-1:0] tbt0, tbt1, tbt2, tbt3,
    input   [MAG_WIDTH-1:0] fa0,  fa1,  fa2,  fa3,
    input   [MAG_WIDTH-1:0] sa0,  sa1,  sa2,  sa3,
    input                   tbtInToggle, faInToggle, saInToggle,

    input       [DATA_WIDTH-1:0] gpioData,
    input                        csrStrobe, xCalStrobe, yCalStrobe, qCalStrobe,
    output wire [DATA_WIDTH-1:0] csr,
    output reg signed [DATA_WIDTH-1:0] xCalibration, yCalibration, qCalibration,

    input                        posXOffsetStrobe,
    output wire [DATA_WIDTH-1:0] posXOffsetRBK,
    input                        posYOffsetStrobe,
    output wire [DATA_WIDTH-1:0] posYOffsetRBK,
    input                        posQOffsetStrobe,
    output wire [DATA_WIDTH-1:0] posQOffsetRBK,

    output wire signed [DATA_WIDTH-1:0] tbtX, tbtY, tbtQ, tbtS,
    output wire signed [DATA_WIDTH-1:0] faX,  faY,  faQ,  faS,
    output wire signed [DATA_WIDTH-1:0] saX,  saY,  saQ,  saS,
    output wire                  tbtToggle,
    output wire                  faToggle,
    output wire                  saToggle,
    output wire                  tbtValid,
    output wire                  faValid,
    output wire                  saValid);

// Pad divider I/O to 8-bit boundary
// Divider actual widths:
//    Dividend = DIFFERENCE_WIDTH
//    Divisor  = 1 + SUM_WIDTH (since dividend must always be positive)
//    Quotient = 56 bits (28 bit integer, 28 bit fraction)
parameter SUM_WIDTH        = MAG_WIDTH + 2;
parameter DIFFERENCE_WIDTH = MAG_WIDTH + 2;
parameter DIVIDEND_WIDTH  = 32;
parameter DIVISOR_WIDTH   = 32;
parameter QUOTIENT_WIDTH  = 56;

// Dividend TUSER is channel number, divisor TUSER is sum
parameter TUSER_OUT_WIDTH = 4 + SUM_WIDTH;
//
// Microblaze interface
//
reg        overrun = 0;
reg [29:0] operandMap = 0;
assign csr = { overrun, 1'b0, operandMap };
always @(posedge clk) begin
    if (csrStrobe)  operandMap   <= gpioData[29:0];
    if (xCalStrobe) xCalibration <= gpioData;
    if (yCalStrobe) yCalibration <= gpioData;
    if (qCalStrobe) qCalibration <= gpioData;
end

reg signed [DATA_WIDTH-1:0] posXOffset = 0;
reg signed [DATA_WIDTH-1:0] posYOffset = 0;
reg signed [DATA_WIDTH-1:0] posQOffset = 0;
always @(posedge clk) begin
    if (posXOffsetStrobe)  begin
        posXOffset <= gpioData[DATA_WIDTH-1:0];
    end

    if (posYOffsetStrobe)  begin
        posYOffset <= gpioData[DATA_WIDTH-1:0];
    end

    if (posQOffsetStrobe)  begin
        posQOffset <= gpioData[DATA_WIDTH-1:0];
    end
end

assign posXOffsetRBK = posXOffset;
assign posYOffsetRBK = posYOffset;
assign posQOffsetRBK = posQOffset;

//
// Computation state machine
//
parameter S_IDLE  = 0;
parameter S_FILL0 = 1;
parameter S_FILL1 = 2;
parameter S_FILL2 = 3;
parameter S_DIV0  = 4;
parameter S_DIV1  = 5;
parameter S_DIV2  = 6;
reg        tbtInToggle_d = 0;
reg        tbtInMatch = 0, faInMatch = 0, saInMatch = 0;
reg  [2:0] state = 0;
reg        dividerInputsValid = 0;
reg  [1:0] sourceSelect, operandSelect, dividendSelect;
wire [3:0] dividerInputChannel;
assign     dividerInputChannel = { sourceSelect, dividendSelect };
wire       computationEnable;
assign     computationEnable = (state == S_FILL0) ||
                               (state == S_FILL1) ||
                               (state == S_FILL2) ||
                               ((state == S_DIV0) &&  dividerReady) ||
                               ((state == S_DIV1) &&  dividerReady);
always @(posedge clk) begin
    //
    // Detect overrun
    //
    tbtInToggle_d <= tbtInToggle;
    if ((tbtInToggle != tbtInToggle_d) && (tbtInToggle == tbtInMatch)) begin
        overrun <= 1;
    end

    //
    // Crank state machine
    //
    case (state)
    //
    // Load source select muxes when magnitudes are ready
    //
    S_IDLE: begin
                operandSelect <= 0;
                if (tbtInToggle != tbtInMatch) begin
                    tbtInMatch <= tbtInToggle;
                    mag0 <= tbt0;
                    mag1 <= tbt1;
                    mag2 <= tbt2;
                    mag3 <= tbt3;
                    sourceSelect <= 0;
                    state <= S_FILL0;
                end
                else if (faInToggle != faInMatch) begin
                    faInMatch <= faInToggle;
                    mag0 <= fa0;
                    mag1 <= fa1;
                    mag2 <= fa2;
                    mag3 <= fa3;
                    sourceSelect <= 1;
                    state <= S_FILL0;
                end
                else if (saInToggle != saInMatch) begin
                    saInMatch <= saInToggle;
                    mag0 <= sa0;
                    mag1 <= sa1;
                    mag2 <= sa2;
                    mag3 <= sa3;
                    sourceSelect <= 2;
                    state <= S_FILL0;
                end
            end

    //
    // On entry, first operands at operand mux inputs
    //
    S_FILL0: begin
                operandSelect <= 1;
                state <= S_FILL1;
             end

    //
    // On entry, first operands at adder inputs
    //
    S_FILL1: begin
                operandSelect <= 2;
                state <= S_FILL2;
             end

    //
    // On entry, first operands at subtracter inputs
    //
    S_FILL2: begin
                dividerInputsValid <= 1;
                dividendSelect <= 0;
                state <= S_DIV0;
             end

    //
    // On entry, first operands at divider inputs
    // On exit, first operands will be clocked into divider
    //
    S_DIV0: begin
                if (dividerReady) begin
                    dividendSelect <= 1;
                    state <= S_DIV1;
                end
            end

    //
    // On entry, second operands at divider inputs
    // On exit, second operands will be clocked into divider
    //
    S_DIV1: begin
                if (dividerReady) begin
                    dividendSelect <= 2;
                    state <= S_DIV2;
                end
            end

    //
    // On entry, third operands at divider inputs
    // On exit, third operands will be clocked into divider
    //
    S_DIV2: begin
                if (dividerReady) begin
                    dividerInputsValid <= 0;
                    state <= S_IDLE;
                end
            end

    default: ;
    endcase
end

//
// Intermediate results
//
reg               [MAG_WIDTH-1:0] mag0, mag1, mag2, mag3;
reg               [MAG_WIDTH-1:0] mux0, mux1, mux2, mux3;
reg           [(1+MAG_WIDTH)-1:0] sum01, sum23;
reg signed [DIFFERENCE_WIDTH-1:0] diff;

//
// Dividend computation
//
wire [9:0] opMap;
assign opMap = (operandSelect == 0) ? operandMap[ 9: 0] :
               (operandSelect == 1) ? operandMap[19:10] :
                                      operandMap[29:20];
always @(posedge clk) begin
    if (computationEnable) begin
        mux0 <= (opMap[1:0] == 0) ? mag0 :
                (opMap[1:0] == 1) ? mag1 :
                (opMap[1:0] == 2) ? mag2 : mag3;
        mux1 <= (opMap[4:2] == 0) ? mag0 :
                (opMap[4:2] == 1) ? mag1 :
                (opMap[4:2] == 2) ? mag2 :
                (opMap[4:2] == 3) ? mag3 : 0;
        mux2 <= (opMap[6:5] == 0) ? mag0 :
                (opMap[6:5] == 1) ? mag1 :
                (opMap[6:5] == 2) ? mag2 : mag3;
        mux3 <= (opMap[9:7] == 0) ? mag0 :
                (opMap[9:7] == 1) ? mag1 :
                (opMap[9:7] == 2) ? mag2 :
                (opMap[9:7] == 3) ? mag3 : 0;
        sum01 <= { 1'b0, mux0 } + { 1'b0, mux1 };
        sum23 <= { 1'b0, mux2 } + { 1'b0, mux3 };
        diff  <= $signed({ 1'b0, sum01}) - $signed({ 1'b0, sum23});
    end
end

//
// Compute sum of button magnitudes
//
reg [(1+MAG_WIDTH)-1:0] bSum01;
reg [(1+MAG_WIDTH)-1:0] bSum23;
reg     [SUM_WIDTH-1:0] buttonSum;
always @(posedge clk) begin
    bSum01 <= { 1'b0, mag0 } +  { 1'b0, mag1 };
    bSum23 <= { 1'b0, mag2 } +  { 1'b0, mag3 };
    buttonSum <= { 1'b0, bSum01 } + { 1'b0, bSum23 };
end

//
// Division
//
wire                             dividerOutputsValid, dividerReady;
wire signed [DIVIDEND_WIDTH-1:0] dividend = diff;
wire         [DIVISOR_WIDTH-1:0] divisor = buttonSum;
wire signed [QUOTIENT_WIDTH-1:0] quotient;
wire       [TUSER_OUT_WIDTH-1:0] dividerTuserOut;
`ifndef SIMULATE
positionCalcDivider positionCalcDivider (
                              .aclk(clk),
                              .s_axis_divisor_tvalid(dividerInputsValid),
                              .s_axis_divisor_tready(dividerReady),
                              .s_axis_divisor_tuser(buttonSum),
                              .s_axis_divisor_tdata(divisor),
                              .s_axis_dividend_tvalid(dividerInputsValid),
                              .s_axis_dividend_tuser(dividerInputChannel),
                              .s_axis_dividend_tdata(dividend),
                              .m_axis_dout_tvalid(dividerOutputsValid),
                              .m_axis_dout_tuser(dividerTuserOut),
                              .m_axis_dout_tdata(quotient));
`endif
reg signed [DATA_WIDTH-1:0] rawPosition;
wire       [SUM_WIDTH-1:0] dividerTuserOutSum;
wire                 [3:0] dividerTuserOutChannel;
assign dividerTuserOutChannel = dividerTuserOut[TUSER_OUT_WIDTH-1:SUM_WIDTH];
assign dividerTuserOutSum     = dividerTuserOut[SUM_WIDTH-1:0];
reg                  [3:0] calibrationChannel, calibratedChannel;
reg                        calibrationValid, calibratedValid;

//
// Apply calibration factor
//
parameter PRODUCT_WIDTH = 2*DATA_WIDTH;
reg signed [DATA_WIDTH-1:0] calibrationFactor;
wire signed [PRODUCT_WIDTH-1:0] product;
// Multiplier is signed (both inputs)
`ifndef SIMULATE
positionCalcMultiplier
  positionCalcMultiplier(
    .CLK(clk),
    .A(rawPosition),
    .B(calibrationFactor),
    .P(product));
`endif
wire signed [DATA_WIDTH-1:0] calibrated;
// Drop top four bits since divider fraction width is only 28 bits, not 32.
assign calibrated = product[PRODUCT_WIDTH-4-1:PRODUCT_WIDTH-DATA_WIDTH-4];

reg tbtToggleRaw = 0, faToggleRaw = 0, saToggleRaw = 0;
reg tbtValidRaw = 0, faValidRaw = 0, saValidRaw = 0;

reg signed [DATA_WIDTH-1:0] tbtXRaw = 0, tbtYRaw = 0, tbtQRaw = 0, tbtSRaw = 0;
reg signed [DATA_WIDTH-1:0] faXRaw = 0, faYRaw = 0, faQRaw = 0, faSRaw = 0;
reg signed [DATA_WIDTH-1:0] saXRaw = 0, saYRaw =0,  saQRaw = 0,  saSRaw = 0;

always @(posedge clk) begin
    //
    // Prepare multiplier inputs
    //
    rawPosition <= quotient[DATA_WIDTH-1:0];
    calibrationFactor <= (dividerTuserOutChannel[1:0] == 0) ? xCalibration :
                         (dividerTuserOutChannel[1:0] == 1) ? yCalibration :
                                                              qCalibration;
    calibrationChannel <= dividerTuserOutChannel;
    calibrationValid <= dividerOutputsValid;

    //
    // Allow clock cycle for gain compensation
    //
    calibratedChannel <= calibrationChannel;
    calibratedValid <= calibrationValid;

    //
    // Send value to appropriate destination
    //
    if (dividerOutputsValid) begin
        case (dividerTuserOutChannel[3:2])
        4'h0: tbtSRaw <= { {DATA_WIDTH-SUM_WIDTH{1'b0}}, dividerTuserOutSum };
        4'h1: faSRaw  <= { {DATA_WIDTH-SUM_WIDTH{1'b0}}, dividerTuserOutSum };
        4'h2: saSRaw  <= { {DATA_WIDTH-SUM_WIDTH{1'b0}}, dividerTuserOutSum };
        default: ;
        endcase
    end


    tbtValidRaw <= 1'b0;
    faValidRaw <= 1'b0;
    saValidRaw <= 1'b0;
    if (calibratedValid) begin
        case (calibratedChannel)
        4'h0: tbtXRaw <= calibrated;
        4'h1: tbtYRaw <= calibrated;
        4'h2: begin
              tbtQRaw <= calibrated;
              tbtToggleRaw = !tbtToggleRaw;
              tbtValidRaw <= 1'b1;
              end
        4'h4: faXRaw <= calibrated;
        4'h5: faYRaw <= calibrated;
        4'h6: begin
              faQRaw <= calibrated;
              faToggleRaw = !faToggleRaw;
              faValidRaw <= 1'b1;
              end
        4'h8: saXRaw <= calibrated;
        4'h9: saYRaw <= calibrated;
        4'hA: begin
              saQRaw <= calibrated;
              saToggleRaw = !saToggleRaw;
              saValidRaw <= 1'b1;
              end
        default: ;
        endcase
    end
end

//
// Offset subtraction
//

localparam NUM_SIGNALS = 4;
localparam USER_WIDTH = 1;
localparam [DATA_WIDTH-1:0] zero = {DATA_WIDTH{1'b0}};

subOffset #(
    .NUM_SIGNALS(NUM_SIGNALS),
    .USER_WIDTH(USER_WIDTH),
    .SIGNAL_WIDTH(DATA_WIDTH),
    .OFFSET_WIDTH(DATA_WIDTH)
    )
  subOffsetTbT (
    .clk(clk),
    .userIn(tbtToggleRaw),
    .validIn(tbtValidRaw),
    .signalIn({
        tbtSRaw,
        tbtQRaw,
        tbtYRaw,
        tbtXRaw
    }),
    .offsetIn({
        zero,
        posQOffset,
        posYOffset,
        posXOffset
    }),
    .userOut(tbtToggle),
    .validOut(tbtValid),
    .signalOut({
        tbtS,
        tbtQ,
        tbtY,
        tbtX
    })
  );

subOffset #(
    .NUM_SIGNALS(NUM_SIGNALS),
    .USER_WIDTH(USER_WIDTH),
    .SIGNAL_WIDTH(DATA_WIDTH),
    .OFFSET_WIDTH(DATA_WIDTH)
    )
  subOffsetFA (
    .clk(clk),
    .userIn(faToggleRaw),
    .validIn(faValidRaw),
    .signalIn({
        faSRaw,
        faQRaw,
        faYRaw,
        faXRaw
    }),
    .offsetIn({
        zero,
        posQOffset,
        posYOffset,
        posXOffset
    }),
    .userOut(faToggle),
    .validOut(faValid),
    .signalOut({
        faS,
        faQ,
        faY,
        faX
    })
  );

subOffset #(
    .NUM_SIGNALS(NUM_SIGNALS),
    .USER_WIDTH(USER_WIDTH),
    .SIGNAL_WIDTH(DATA_WIDTH),
    .OFFSET_WIDTH(DATA_WIDTH)
    )
  subOffsetSA (
    .clk(clk),
    .userIn(saToggleRaw),
    .validIn(saValidRaw),
    .signalIn({
        saSRaw,
        saQRaw,
        saYRaw,
        saXRaw
    }),
    .offsetIn({
        zero,
        posQOffset,
        posYOffset,
        posXOffset
    }),
    .userOut(saToggle),
    .validOut(saValid),
    .signalOut({
        saS,
        saQ,
        saY,
        saX
    })
  );

endmodule
