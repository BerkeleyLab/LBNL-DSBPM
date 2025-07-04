// Preliminary signal processing
// Convert ADC values to synchronously-demodulated or RMS magnitudes
//
module preliminaryProcessing #(
    parameter CHIPSCOPE_DBG           = "FALSE",
    parameter SYSCLK_RATE             = 100000000,
    parameter MAG_WIDTH               = 26,
    parameter IQ_DATA                 = "FALSE",
    parameter SAMPLES_PER_TURN        = 77,
    parameter NADC                    = 4,
    parameter ADC_WIDTH               = 16,
    parameter DATA_WIDTH              = 32,
    parameter TURNS_PER_PT            = 19,
    parameter CIC_STAGES              = 3,
    parameter CIC_FA_DECIMATE         = 76,
    parameter CIC_SA_DECIMATE         = 1000,
    parameter GPIO_LO_RF_ROW_CAPACITY = -1,
    parameter GPIO_LO_PT_ROW_CAPACITY = -1,
    parameter LO_WIDTH                = 18,
    parameter GAIN_WIDTH              = MAG_WIDTH + 1,
    parameter PRODUCT_WIDTH           = ADC_WIDTH + LO_WIDTH - 1) (
    input                        clk,

    input       [DATA_WIDTH-1:0] gpioData,
    input                        localOscillatorAddressStrobe,
    input                        localOscillatorCsrStrobe,
    output wire [DATA_WIDTH-1:0] localOscillatorCsr,
    input                        sumShiftCsrStrobe,
    output wire [DATA_WIDTH-1:0] sumShiftCsr,
    input  wire                  autotrimCsrStrobe,
    input  wire                  autotrimThresholdStrobe,
    input             [NADC-1:0] autotrimGainStrobes,
    output wire [DATA_WIDTH-1:0] autotrimCsr, autotrimThreshold,
    output wire [DATA_WIDTH-1:0] gainRBK0, gainRBK1, gainRBK2, gainRBK3,

    input             [NADC-1:0] calRFGainStrobes,
    output wire [DATA_WIDTH-1:0] gainCalRFRBK0, gainCalRFRBK1, gainCalRFRBK2, gainCalRFRBK3,

    input             [NADC-1:0] calPLGainStrobes,
    output wire [DATA_WIDTH-1:0] gainCalPLRBK0, gainCalPLRBK1, gainCalPLRBK2, gainCalPLRBK3,
    input             [NADC-1:0] calPHGainStrobes,
    output wire [DATA_WIDTH-1:0] gainCalPHRBK0, gainCalPHRBK1, gainCalPHRBK2, gainCalPHRBK3,

    input                 [63:0] sysTimestamp,
    input                        adcClk,
    input        [ADC_WIDTH-1:0] adc0, adc1, adc2, adc3,
    // Only used when IQ_DATA == "TRUE"
    input        [ADC_WIDTH-1:0] adcQ0, adcQ1, adcQ2, adcQ3,
    output wire  [ADC_WIDTH-1:0] adc0Out, adc1Out, adc2Out, adc3Out,
    // Only used when IQ_DATA == "TRUE"
    output wire  [ADC_WIDTH-1:0] adc0QOut, adc1QOut, adc2QOut, adc3QOut,
    output wire  [ADC_WIDTH-1:0] adc0OutMag, adc1OutMag, adc2OutMag, adc3OutMag,
    output wire  [ADC_WIDTH-1:0] adc0OutPh, adc1OutPh, adc2OutPh, adc3OutPh,
    input                        adcExceedsThreshold, adcUseThisSample,
    output wire                  adcLoSynced,

    input                        evrClk,
    input                        evrFaMarker, evrSaMarker,
    input                 [63:0] evrTimestamp,
    input                        evrSinglePassTrigger,evrHbMarker,

    output reg                   sysSingleTrig,
    output wire                  adcSingleTrig,

    output wire                  rfTbtToggle,
    output reg                   rfTbtMagValid,
    output wire  [MAG_WIDTH-1:0] rfTbtMag0, rfTbtMag1, rfTbtMag2, rfTbtMag3,

    output wire                  rfFaToggle,
    output reg                   rfFaMagValid,
    output wire  [MAG_WIDTH-1:0] rfFaMag0, rfFaMag1, rfFaMag2, rfFaMag3,

    output wire                  ptFaToggle,
    output reg                   ptFaValid,
    output wire  [MAG_WIDTH-1:0] plFaMag0, plFaMag1, plFaMag2, plFaMag3,
    output wire  [MAG_WIDTH-1:0] phFaMag0, phFaMag1, phFaMag2, phFaMag3,

    output wire                  adcTbtLoadAccumulator,
    output wire                  adcTbtLatchAccumulator,
    output wire                  adcMtLoadAndLatch,

    output reg                   rfSaToggle,
    output reg                   rfSaValid,
    output reg            [63:0] sysSaTimestamp,

    output reg   [MAG_WIDTH-1:0] rfSaMag0, rfSaMag1, rfSaMag2, rfSaMag3,
    output reg                   overflowFlag,

    output reg                   ptSaToggle,
    output reg                   ptSaValid,
    output reg   [MAG_WIDTH-1:0] plSaMag0, plSaMag1, plSaMag2, plSaMag3,
    output reg   [MAG_WIDTH-1:0] phSaMag0, phSaMag1, phSaMag2, phSaMag3,

    // Debug outputs
    output wire  [8*PRODUCT_WIDTH-1:0] rfProductsDbg,
    output wire  [8*PRODUCT_WIDTH-1:0] plProductsDbg,
    output wire  [8*PRODUCT_WIDTH-1:0] phProductsDbg,

    output wire  [LO_WIDTH-1:0]  rfLOcosDbg,
    output wire  [LO_WIDTH-1:0]  rfLOsinDbg,
    output wire  [LO_WIDTH-1:0]  plLOcosDbg,
    output wire  [LO_WIDTH-1:0]  plLOsinDbg,
    output wire  [LO_WIDTH-1:0]  phLOcosDbg,
    output wire  [LO_WIDTH-1:0]  phLOsinDbg,

    output wire  [8*MAG_WIDTH-1:0] tbtSumsDbg,
    output wire                    tbtSumsValidDbg,

    output wire  [4*MAG_WIDTH-1:0] tbtMagsDbg,
    output wire                    tbtMagsValidDbg,

    output wire  [MAG_WIDTH-1:0] cicFaMag0Dbg,
    output wire  [MAG_WIDTH-1:0] cicFaMag1Dbg,
    output wire  [MAG_WIDTH-1:0] cicFaMag2Dbg,
    output wire  [MAG_WIDTH-1:0] cicFaMag3Dbg,
    output wire                  cicFaMagValidDbg
);

wire sysUseRMS           = localOscillatorCsr[2];
wire sysIsSinglePassMode = localOscillatorCsr[1];
wire sysPtSimulateBeam   = autotrimCsr[31];

//////////////////////////////////////////////////////////////////////////////
//                              EVR CLOCK DOMAIN                            //
//                                                                          //

// Get values to EVR clock domain
// Latch in EVR clock domain to ensure that all BPMs
// have exactly the same SA timestamp.
reg  adcMtLoadAndLatchToggle = 0;
(* ASYNC_REG="TRUE" *) reg evrMtLoadAndLatchToggle_m;
reg evrMtLoadAndLatchToggle, evrMtLoadAndLatchToggle_d;
reg [63:0] evrSaTimestamp;
reg evrSaMarker_d;
always @(posedge evrClk) begin
    evrMtLoadAndLatchToggle_m <= adcMtLoadAndLatchToggle;
    evrMtLoadAndLatchToggle   <= evrMtLoadAndLatchToggle_m;
    evrMtLoadAndLatchToggle_d <= evrMtLoadAndLatchToggle;

    evrSaMarker_d <= evrSaMarker;
    if (evrSaMarker && !evrSaMarker_d) evrSaTimestamp <= evrTimestamp;
end

//////////////////////////////////////////////////////////////////////////////
//                              ADC CLOCK DOMAIN                            //
//                                                                          //

//
// Get assorted timing values into ADC clock domain.
//
(* ASYNC_REG="TRUE" *) reg adcUseRMS_m = 0;
(* ASYNC_REG="TRUE" *) reg adcIsSinglePassMode_m = 0;
(* ASYNC_REG="TRUE" *) reg adcFaEvent_m = 0, adcSaEvent_m = 0;
(* ASYNC_REG="TRUE" *) reg adcHbEvent_m = 0, adcSpEvent_m = 0;
reg adcUseRMS = 0;
reg adcIsSinglePassMode = 0;
reg adcFaEvent = 0, adcFaEvent_d1 = 0, adcFaSync = 0;
reg adcSaEvent = 0, adcSaEvent_d1 = 0, adcSaSync = 0;
reg adcHbEvent = 0, adcHbEvent_d1 = 0;
reg adcSpEvent = 0;
reg adcFaDecimateFlag = 0, adcSaDecimateFlag = 0;
reg adcUsingEvrTrigger = 0;
reg [1:0] adcHbDivider = 2; reg adcSyncMarker = 0;
always @(posedge adcClk) begin
    adcUseRMS_m           <= sysUseRMS;
    adcUseRMS             <= adcUseRMS_m;
    adcIsSinglePassMode_m <= sysIsSinglePassMode;
    adcIsSinglePassMode   <= adcIsSinglePassMode_m;

    adcFaEvent_m  <= evrFaMarker;
    adcFaEvent    <= adcFaEvent_m;
    adcFaEvent_d1 <= adcFaEvent;
    if (adcFaEvent && !adcFaEvent_d1 && !adcFaSync) adcFaSync <= 1;

    adcSaEvent_m  <= evrSaMarker;
    adcSaEvent    <= adcSaEvent_m;
    adcSaEvent_d1 <= adcSaEvent;
    if (adcSaEvent && !adcSaEvent_d1 && !adcSaSync) adcSaSync <= 1;

    adcHbEvent_m  <= evrHbMarker;
    adcHbEvent    <= adcHbEvent_m;
    adcHbEvent_d1 <= adcHbEvent;

    adcSpEvent_m  <= evrSinglePassTrigger;
    adcSpEvent    <= adcSpEvent_m;
    if (adcSpEvent) adcUsingEvrTrigger <= 1;

    // Generate decimation requests
    if (adcMtLoadAndLatch) begin
        adcMtLoadAndLatchToggle <= !adcMtLoadAndLatchToggle;
        if (adcFaSync) begin
            adcFaSync <= 0;
            adcFaDecimateFlag <= 1;
        end
        else begin
            adcFaDecimateFlag <= 0;
        end
        if (adcSaSync) begin
            adcSaSync <= 0;
            adcSaDecimateFlag <= 1;
        end
        else begin
            adcSaDecimateFlag <= 0;
        end
    end

    if (adcHbEvent && !adcHbEvent_d1) begin
        // Use only every third hearbeat event to allow for RF accumulation
        // over multiples of three turns.  We assume that the ADC ticks per
        // heartbeat is already a multiple of two and five.
        if (adcHbDivider == 0) begin
            adcHbDivider <= 2;
            adcSyncMarker <= 1;
        end
        else begin
            adcHbDivider <= adcHbDivider - 1;
        end
    end
    else begin
        adcSyncMarker <= 0;
    end
end

//
// Local oscillator
//
reg adcHoldoff = 0;
wire adcSinglePassStart = adcIsSinglePassMode && !adcHoldoff &&
                   ((adcExceedsThreshold && !adcUsingEvrTrigger) || adcSpEvent);
wire [LO_WIDTH-1:0] adcRfCos, adcRfSin, adcPlCos, adcPlSin, adcPhCos, adcPhSin;
(*mark_debug="false"*)
localOscillator #(.OUTPUT_WIDTH(LO_WIDTH),
                  .GPIO_LO_RF_ROW_CAPACITY(GPIO_LO_RF_ROW_CAPACITY),
                  .GPIO_LO_PT_ROW_CAPACITY(GPIO_LO_PT_ROW_CAPACITY))
  localOscillator(.clk(adcClk),
                  .adcSyncMarker(adcSyncMarker),
                  .singleStart(adcSinglePassStart),
                  .sysClk(clk),
                  .sysAddressStrobe(localOscillatorAddressStrobe),
                  .sysGpioStrobe(localOscillatorCsrStrobe),
                  .sysGpioData(gpioData),
                  .sysGpioCsr(localOscillatorCsr),
                  .tbtLoadAccumulator(adcTbtLoadAccumulator),
                  .tbtLatchAccumulator(adcTbtLatchAccumulator),
                  .mtLoadAndLatch(adcMtLoadAndLatch),
                  .loSynced(adcLoSynced),
                  .rfCos(adcRfCos),
                  .rfSin(adcRfSin),
                  .plCos(adcPlCos),
                  .plSin(adcPlSin),
                  .phCos(adcPhCos),
                  .phSin(adcPhSin));

assign rfLOcosDbg = adcRfCos;
assign rfLOsinDbg = adcRfSin;
assign plLOcosDbg = adcPlCos;
assign plLOsinDbg = adcPlSin;
assign phLOcosDbg = adcPhCos;
assign phLOsinDbg = adcPhSin;

// Syncronous demodulator multipliers
// Product can be one bit narrower since the local oscillator value, or
// the scaled ADC value taking the place of the local oscillator can
// never take on negative full scale value.
wire [4*ADC_WIDTH-1:0] adcs = { adc3, adc2, adc1, adc0 };
wire [4*ADC_WIDTH-1:0] adcsQ = { adcQ3, adcQ2, adcQ1, adcQ0 };
wire [8*PRODUCT_WIDTH-1:0] rfProducts, plProducts, phProducts;

genvar i; generate
for (i = 0 ; i < NADC ; i = i + 1) begin : adcDemod

// If RMS values are being computed:
//  - the RF ADC value is replaced with 0 if adcUseThisSample is not asserted
//    or pilot tones may be on.
//  - the PT ADC value is replaced with 0 if adcUseThisSample is not asserted
//    and pulse pilot tones are enabled.
//  - the local oscillator sine term is replaced with 0.
//  - the local oscillator cosine term is replaced with the scaled ADC value.
//    Note that the ADC value is not shifted all the way up.  This is to
//    ensure that the 'local oscillator' value can never take on the full
//    scale negative value.
wire [ADC_WIDTH-1:0] adc = adcs[i*ADC_WIDTH+:ADC_WIDTH];
wire [ADC_WIDTH-1:0] adcQ = adcsQ[i*ADC_WIDTH+:ADC_WIDTH];
wire [LO_WIDTH-1:0]  adcLO  ={adc[ADC_WIDTH-1], adc, {LO_WIDTH-ADC_WIDTH-1{1'b0}}};
wire [LO_WIDTH-1:0]  adcQLO ={adcQ[ADC_WIDTH-1], adcQ, {LO_WIDTH-ADC_WIDTH-1{1'b0}}};
wire [ADC_WIDTH-1:0] rfADC = (adcUseRMS && !adcUseThisSample) ?
                                                        {ADC_WIDTH{1'b0}} : adc;
wire [ADC_WIDTH-1:0] rfADCQ = (adcUseRMS && !adcUseThisSample) ?
                                                        {ADC_WIDTH{1'b0}} : adcQ;
wire [ADC_WIDTH-1:0] ptADC = (adcUseRMS && !adcUseThisSample) ?
                                                        {ADC_WIDTH{1'b0}} : adc;
wire [ADC_WIDTH-1:0] ptADCQ = (adcUseRMS && !adcUseThisSample) ?
                                                        {ADC_WIDTH{1'b0}} : adcQ;
// Set multiplier to ADC value for RMS computation or table entry for I-Q.
wire [LO_WIDTH-1:0] rfLOcos = adcUseRMS ? adcLO : adcRfCos;
wire [LO_WIDTH-1:0] rfLOsin = adcUseRMS ? {LO_WIDTH{1'b0}} : adcRfSin;
wire [LO_WIDTH-1:0] plLOcos = adcUseRMS ? adcLO : adcPlCos;
wire [LO_WIDTH-1:0] plLOsin = adcUseRMS ? {LO_WIDTH{1'b0}} : adcPlSin;
wire [LO_WIDTH-1:0] phLOcos = adcUseRMS ? adcLO : adcPhCos;
wire [LO_WIDTH-1:0] phLOsin = adcUseRMS ? {LO_WIDTH{1'b0}} : adcPhSin;
wire signed [PRODUCT_WIDTH-1:0] adcRfPrdI, adcRfPrdQ;
wire signed [PRODUCT_WIDTH-1:0] adcPlPrdI, adcPlPrdQ, adcPhPrdI, adcPhPrdQ;

if (IQ_DATA == "TRUE") begin

// For RMS we need PrdI = I^2 and PrdQ = Q^2. But complex multiplcation
// doesn't give us that if we 0 cos or sin. So, when calculating RMS,
// PrdI comes for free by making cos = I and sin = 0
// ProdQ needs to come from a different multiplier.
wire signed [PRODUCT_WIDTH-1:0] adcRfPrdIComplex, adcRfPrdQComplex;
wire signed [PRODUCT_WIDTH-1:0] adcPlPrdIComplex, adcPlPrdQComplex;
wire signed [PRODUCT_WIDTH-1:0] adcPhPrdIComplex, adcPhPrdQComplex;

wire signed [PRODUCT_WIDTH-1:0] adcRfPrdISquared, adcRfPrdQSquared;
wire signed [PRODUCT_WIDTH-1:0] adcPlPrdISquared, adcPlPrdQSquared;
wire signed [PRODUCT_WIDTH-1:0] adcPhPrdISquared, adcPhPrdQSquared;

complexMixer #(.AWIDTH(ADC_WIDTH),
               .BWIDTH(LO_WIDTH),
               .SIZEOUT(PRODUCT_WIDTH))
  dmMulRf(.clk(adcClk),
    .sload(1'b1),
    .ar(rfADC),
    .ai(rfADCQ),
    .br(rfLOcos),
    .bi(rfLOsin),
    .pr(adcRfPrdIComplex),
    .pi(adcRfPrdQComplex));

mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulRfISquare(.clk(adcClk),
    .adcf(rfADC),
    .mult(adcLO),
    .mixout(adcRfPrdISquared));

mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulRfQSquare(.clk(adcClk),
    .adcf(rfADCQ),
    .mult(adcQLO),
    .mixout(adcRfPrdQSquared));

assign adcRfPrdI = adcUseRMS ? adcRfPrdISquared : adcRfPrdIComplex;
assign adcRfPrdQ = adcUseRMS ? adcRfPrdQSquared : adcRfPrdQComplex;

complexMixer #(.AWIDTH(ADC_WIDTH),
               .BWIDTH(LO_WIDTH),
               .SIZEOUT(PRODUCT_WIDTH))
  dmMulPl(.clk(adcClk),
    .sload(1'b1),
    .ar(ptADC),
    .ai(ptADCQ),
    .br(plLOcos),
    .bi(plLOsin),
    .pr(adcPlPrdIComplex),
    .pi(adcPlPrdQComplex));

mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulPlISquare(.clk(adcClk),
    .adcf(ptADC),
    .mult(adcLO),
    .mixout(adcPlPrdISquared));

mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulPlQSquared(.clk(adcClk),
    .adcf(ptADCQ),
    .mult(adcQLO),
    .mixout(adcPlPrdQSquared));

assign adcPlPrdI = adcUseRMS ? adcPlPrdISquared : adcPlPrdIComplex;
assign adcPlPrdQ = adcUseRMS ? adcPlPrdQSquared : adcPlPrdQComplex;

complexMixer #(.AWIDTH(ADC_WIDTH),
               .BWIDTH(LO_WIDTH),
               .SIZEOUT(PRODUCT_WIDTH))
  dmMulPh(.clk(adcClk),
    .sload(1'b1),
    .ar(ptADC),
    .ai(ptADCQ),
    .br(phLOcos),
    .bi(phLOsin),
    .pr(adcPhPrdIComplex),
    .pi(adcPhPrdQComplex));

// Pilot Tone High = Pilot Tone Low is RMS is on
assign adcPhPrdISquared = adcPlPrdISquared;
assign adcPhPrdQSquared = adcPlPrdQSquared;

assign adcPhPrdI = adcUseRMS ? adcPhPrdISquared : adcPhPrdIComplex;
assign adcPhPrdQ = adcUseRMS ? adcPhPrdQSquared : adcPhPrdQComplex;

end
else if (IQ_DATA == "FALSE") begin

mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulRfI(.clk(adcClk),
    .adcf(rfADC),
    .mult(rfLOcos),
    .mixout(adcRfPrdI));
mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulRfQ(.clk(adcClk),
      .adcf(rfADC),
      .mult(rfLOsin),
      .mixout(adcRfPrdQ));
mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulPlI(.clk(adcClk),
    .adcf(ptADC),
    .mult(plLOcos),
    .mixout(adcPlPrdI));
mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulPlQ(.clk(adcClk),
    .adcf(ptADC),
    .mult(plLOsin),
    .mixout(adcPlPrdQ));
mixer #(.dwi(ADC_WIDTH),
        .davr(LO_WIDTH-1),
        .dwlo(LO_WIDTH))
  dmMulPhI(.clk(adcClk),
    .adcf(ptADC),
    .mult(phLOcos),
    .mixout(adcPhPrdI));
mixer #(.dwi(ADC_WIDTH),
    .davr(LO_WIDTH-1),
    .dwlo(LO_WIDTH))
  dmMulPhQ(.clk(adcClk),
    .adcf(ptADC),
    .mult(phLOsin),
    .mixout(adcPhPrdQ));

end

assign rfProducts[i*2*PRODUCT_WIDTH+:2*PRODUCT_WIDTH] = {adcRfPrdQ, adcRfPrdI};
assign plProducts[i*2*PRODUCT_WIDTH+:2*PRODUCT_WIDTH] = {adcPlPrdQ, adcPlPrdI};
assign phProducts[i*2*PRODUCT_WIDTH+:2*PRODUCT_WIDTH] = {adcPhPrdQ, adcPhPrdI};

end // endfor
endgenerate

assign {adc3Out, adc2Out, adc1Out, adc0Out} = adcs;
assign {adc3QOut, adc2QOut, adc1QOut, adc0QOut} = adcsQ;

assign rfProductsDbg = rfProducts;
assign plProductsDbg = plProducts;
assign phProductsDbg = phProducts;

// Magnitude of ADC for monitor purposes
wire [4*ADC_WIDTH-1:0] adcOutMag;
wire [4*ADC_WIDTH-1:0] adcOutPh;
generate
for (i = 0 ; i < NADC ; i = i + 1) begin : adcMag

wire signed [ADC_WIDTH-1:0] adcC = adcs[i*ADC_WIDTH+:ADC_WIDTH];
wire signed [ADC_WIDTH-1:0] adcQC = adcsQ[i*ADC_WIDTH+:ADC_WIDTH];
wire [ADC_WIDTH-1:0] adcMag;
wire [ADC_WIDTH-1:0] adcPh;
cordicg_b22 #(
    .width(ADC_WIDTH),
    .nstg(ADC_WIDTH+2),
    .def_op(1)) // default is Rectangular -> Polar
  cordicg_b22 (
    .clk(adcClk),
    .opin(2'b01),
    .xin(adcC),
    .yin(adcQC),
    .phasein({(ADC_WIDTH+1){1'b0}}),
    .xout(adcMag),
    .yout(adcPh)
);

assign adcOutMag[i*ADC_WIDTH+:ADC_WIDTH] = adcMag;
assign adcOutPh[i*ADC_WIDTH+:ADC_WIDTH] = adcPh;

end
endgenerate

assign {adc3OutMag, adc2OutMag, adc1OutMag, adc0OutMag} = adcOutMag;
assign {adc3OutPh, adc2OutPh, adc1OutPh, adc0OutPh} = adcOutPh;

// Watch for accumulator overflows
// Stretch to allow detection in system clock domain.
reg adcOverflowFlag = 0;
wire tbtSumOverflow, rfSumOverflow, plSumOverflow, phSumOverflow;
reg [3:0] adcOverflowsStretched;
reg [9:0] adcOvTimer = ~0;
always @(posedge adcClk) begin
    if (tbtSumOverflow || rfSumOverflow || plSumOverflow || phSumOverflow) begin
        adcOvTimer <= ~0;
        adcOverflowsStretched <= adcOverflowsStretched |
                  {phSumOverflow, plSumOverflow, rfSumOverflow, tbtSumOverflow};
        adcOverflowFlag <= 1;
    end
    else begin
        adcOvTimer <= adcOvTimer - 1;
        if (adcOvTimer == 0) begin
            adcOverflowFlag <= 0;
            adcOverflowsStretched <= 0;
        end
    end
end

// Hold off single-pass triggers after single pass trigger.
reg [25:0] adcHoldoffCounter;
always @(posedge adcClk) begin
    if (adcSinglePassStart) begin
        adcHoldoff <= 1;
        adcHoldoffCounter <= ~0;
    end
    else if (adcHoldoffCounter != 0) begin
        adcHoldoffCounter <= adcHoldoffCounter - 1;
    end
    else begin
        adcHoldoff <= 0;
    end
end

assign adcSingleTrig = adcHoldoff;

//
// Synchronous demodulator accumulators
//
reg [3:0] adcTbtSumShift = 0, adcMtSumShift = 0;
wire adcTbtToggle, adcMtToggle;
wire [8*MAG_WIDTH-1:0] tbtSums, rfSums, plSums, phSums;

// Turn-by-turn
// Used for single-pass, too.
sdAccumulate #(.PRODUCT_WIDTH(PRODUCT_WIDTH),
               .SUM_WIDTH(MAG_WIDTH),
               .SAMPLES_PER_TURN(SAMPLES_PER_TURN),
               .TURNS_PER_SUM(1))
  sdTBTaccumulator(.clk(adcClk),
    .useRMS(adcUseRMS),
    .products(rfProducts),
    .loadEnable(adcTbtLoadAccumulator),
    .latchEnable(adcTbtLatchAccumulator),
    .sumShift(adcTbtSumShift),
    .sumsToggle(adcTbtToggle),
    .sums(tbtSums),
    .overflowFlag(tbtSumOverflow));

// Remainder of accumulators update over identical multi-turn interval.
// Assume typical case for TURNS_PER_SUM.
// Multi-turn sum shift will get things back into range if necessary.
sdAccumulate #(.PRODUCT_WIDTH(PRODUCT_WIDTH),
               .SUM_WIDTH(MAG_WIDTH),
               .SAMPLES_PER_TURN(SAMPLES_PER_TURN),
               .TURNS_PER_SUM(TURNS_PER_PT))
  sdRFaccumulator(.clk(adcClk),
    .useRMS(adcUseRMS),
    .products(rfProducts),
    .loadEnable(adcMtLoadAndLatch),
    .latchEnable(adcMtLoadAndLatch),
    .sumShift(adcMtSumShift),
    .sumsToggle(adcMtToggle),
    .sums(rfSums),
    .overflowFlag(rfSumOverflow));

sdAccumulate #(.PRODUCT_WIDTH(PRODUCT_WIDTH),
               .SUM_WIDTH(MAG_WIDTH),
               .SAMPLES_PER_TURN(SAMPLES_PER_TURN),
               .TURNS_PER_SUM(TURNS_PER_PT))
  sdPLaccumulator(.clk(adcClk),
    .useRMS(adcUseRMS),
    .products(plProducts),
    .loadEnable(adcMtLoadAndLatch),
    .latchEnable(adcMtLoadAndLatch),
    .sumShift(adcMtSumShift),
    .sums(plSums),
    .overflowFlag(plSumOverflow));

sdAccumulate #(.PRODUCT_WIDTH(PRODUCT_WIDTH),
               .SUM_WIDTH(MAG_WIDTH),
               .SAMPLES_PER_TURN(SAMPLES_PER_TURN),
               .TURNS_PER_SUM(TURNS_PER_PT))
  sdPHaccumulator(.clk(adcClk),
    .useRMS(adcUseRMS),
    .products(phProducts),
    .loadEnable(adcMtLoadAndLatch),
    .latchEnable(adcMtLoadAndLatch),
    .sumShift(adcMtSumShift),
    .sums(phSums),
    .overflowFlag(phSumOverflow));

//                                                                          //
//                              ADC CLOCK DOMAIN                            //
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
//                             SYSTEM CLOCK DOMAIN                          //
//                                                                          //

// Watch for overflows
// Widen for easy detection by IOC
(* ASYNC_REG="TRUE" *) reg sysAdcOverflowFlag_m = 0, sysAdcOverflowFlag = 0;
(* ASYNC_REG="TRUE" *) reg sysSingleTrig_m;
reg [$clog2(SYSCLK_RATE/2)-1:0] ovTimer;
always @(posedge clk) begin
    sysAdcOverflowFlag_m <= adcOverflowFlag;
    sysAdcOverflowFlag   <= sysAdcOverflowFlag_m;
    if (sysAdcOverflowFlag || cordicOverflowFlag) begin
        ovTimer <= ~0;
        overflowFlag <= 1;
    end
    else begin
        ovTimer <= ovTimer - 1;
        if (ovTimer == 0) overflowFlag <= 0;
    end
    sysSingleTrig_m <= adcHoldoff;
    sysSingleTrig   <= sysSingleTrig_m;
end

//
// Multiplex all channels through the single normalize/CORDIC block.
// Prioritize turn-by-turn, then low then high pilot tones, then rf.
//
localparam STREAM_SELECT_WIDTH = 2;
localparam STREAM_TBT = 2'd0,
           STREAM_RF  = 2'd1,
           STREAM_PL  = 2'd2,
           STREAM_PH  = 2'd3;

// Get ADC 'accumulator ready' toggles into system clock domain
(* ASYNC_REG="TRUE" *) reg sysTbtToggle_m, sysMtToggle_m;
(* ASYNC_REG="TRUE" *) reg sysTbtToggle, sysMtToggle_p;
reg sysMtToggle;
reg sysTbtMatch, sysMtMatch_p, sysRfMatch, sysPlMatch, sysPhMatch;
reg sysFaDecimateFlag, sysSaDecimateFlag;

wire sysTbtValid = sysTbtMatch != sysTbtToggle;
wire sysPlValid = sysPlMatch != sysMtToggle;
wire sysPhValid = sysPhMatch != sysMtToggle;
wire sysRfValid = sysRfMatch != sysMtToggle;

wire cordicREADY;

wire sumVALID = ((sysTbtValid)
              || (sysPlValid)
              || (sysPhValid)
              || (sysRfValid));

wire [STREAM_SELECT_WIDTH-1:0] sumSelect =
                       (sysTbtValid) ? STREAM_TBT :
                       (sysPlValid)  ? STREAM_PL  :
                       (sysPhValid)  ? STREAM_PH  : STREAM_RF;

wire [(8*MAG_WIDTH)-1:0] sums = (sumSelect == STREAM_TBT) ? tbtSums :
                                (sumSelect == STREAM_PL)  ? plSums  :
                                (sumSelect == STREAM_PH)  ? phSums  : rfSums;


// Don't bother with any fancy clock domain crossing logic for the sum
// shift values since changes to these are rare and will at worst cause
// one (TBT, RF or Pilot Tone) value to be computed improperly.

assign tbtSumsDbg = tbtSums;
assign tbtSumsValidDbg = sysTbtValid;

reg [3:0] faCICshift = 0;
wire [2:0] cicStageCount = CIC_STAGES;
wire [9:0] cicFaDecimate = CIC_FA_DECIMATE;
assign sumShiftCsr = { cicStageCount,
                       cicFaDecimate,
                       {DATA_WIDTH-3-10-4-3*4{1'b0}},
                       adcOverflowsStretched,
                       faCICshift, adcMtSumShift, adcTbtSumShift };
always @(posedge clk) begin
    if (sumShiftCsrStrobe) begin
        {faCICshift,adcMtSumShift,adcTbtSumShift} <= gpioData[0+:3*4];
    end
    sysTbtToggle_m <= adcTbtToggle;
    sysTbtToggle   <= sysTbtToggle_m;
    sysMtToggle_m <= adcMtToggle;
    sysMtToggle_p <= sysMtToggle_m;
    sysMtToggle   <= sysMtToggle_p;
    // Sample decimation flags one cycle early so they're
    // valid when sumVALID is asserted.
    if (sysMtMatch_p != sysMtToggle_p) begin
        sysMtMatch_p <= sysMtToggle_p;
        sysFaDecimateFlag <= adcFaDecimateFlag;
        sysSaDecimateFlag <= adcSaDecimateFlag;
    end
    if (cordicREADY) begin
        // Ensure that sumVALID and sumSelect ordering matches this.
        if (sysTbtValid) sysTbtMatch <= !sysTbtMatch;
        else if (sysPlValid) sysPlMatch <= !sysPlMatch;
        else if (sysPhValid) sysPhMatch <= !sysPhMatch;
        else if (sysRfValid) sysRfMatch <= !sysRfMatch;
    end
end

///////////////////////////////////////////////////////////////////////////////
// The CORDIC block
// Shared by all channels and all streams
// Extra bits are SA decimation flag, FA decimation flag and channel number.
///////////////////////////////////////////////////////////////////////////////
localparam CORDIC_M_TUSER_WIDTH = STREAM_SELECT_WIDTH + 4;
wire [CORDIC_M_TUSER_WIDTH-1:0] cordicTUSER;
wire [1:0] cordicADC = cordicTUSER[0+:2];
wire [STREAM_SELECT_WIDTH-1:0] cordicStream=cordicTUSER[2+:STREAM_SELECT_WIDTH];
wire cordicFaDecimateFlag = cordicTUSER[2+STREAM_SELECT_WIDTH];
wire cordicSaDecimateFlag = cordicTUSER[3+STREAM_SELECT_WIDTH];
wire cordicTVALID;
wire cordicOverflowFlag;
wire  [MAG_WIDTH-1:0] cordicMagnitude;
fourCordic #(.IO_WIDTH(MAG_WIDTH),
             .S_TUSER_WIDTH(2+STREAM_SELECT_WIDTH))
  fourCordic (.clk(clk),
              .S_TDATA(sums),
              .S_TUSER({sysSaDecimateFlag, sysFaDecimateFlag, sumSelect}),
              .S_TVALID(sumVALID),
              .S_TREADY(cordicREADY),
              .M_TDATA(cordicMagnitude),
              .M_TUSER(cordicTUSER),
              .M_TVALID(cordicTVALID),
              .overflowFlag(cordicOverflowFlag));

// TBT values don't undergo any filtering
reg [(NADC*MAG_WIDTH)-1:0] tbtUncalMags;
reg tbtUncalTrimStrobe = 0;
always @(posedge clk) begin
    if (cordicTVALID && (cordicStream == STREAM_TBT)) begin
        tbtUncalMags[cordicADC*MAG_WIDTH+: MAG_WIDTH] <= cordicMagnitude;
        if (cordicADC == 2'd3) tbtUncalTrimStrobe <= 1;
    end
    else begin
        tbtUncalTrimStrobe <= 0;
    end
end

// Calibration gain for TbT magnitudes
wire [(NADC*MAG_WIDTH)-1:0] tbtMags;
wire tbtTrimStrobe;
trimGPIO #(.NUM_GAINS(NADC),
           .MAG_WIDTH(MAG_WIDTH),
           .GAIN_WIDTH(GAIN_WIDTH))
  tbtCalibrationTrim (
    .clk(clk),

    .gpioData(gpioData),
    .gainStrobes(calRFGainStrobes),
    .gainRBK({gainCalRFRBK3, gainCalRFRBK2, gainCalRFRBK1, gainCalRFRBK0}),

    .strobe(tbtUncalTrimStrobe),
    .magnitudes(tbtUncalMags),
    .trimmedStrobe(tbtTrimStrobe),
    .trimmed(tbtMags));

assign tbtMagsDbg = tbtMags;
assign tbtMagsValidDbg = tbtTrimStrobe;

// CIC PILOT TONE FA DECIMATION
wire ptDecimatedToggle;
wire [(NADC*MAG_WIDTH)-1:0] decimatedPlUncalMags, decimatedPhUncalMags;
faDecimate #(.DATA_WIDTH(MAG_WIDTH),
             .DECIMATION_FACTOR(CIC_FA_DECIMATE),
             .STAGES(CIC_STAGES))
  plDecimate (
    .clk(clk),
    .inputData(cordicMagnitude),
    .inputChannel(cordicADC),
    .inputValid(cordicTVALID && (cordicStream == STREAM_PL)),
    .cicShift(faCICshift),
    .decimateFlag(cordicFaDecimateFlag),
    .outputData(decimatedPlUncalMags));

faDecimate #(.DATA_WIDTH(MAG_WIDTH),
             .DECIMATION_FACTOR(CIC_FA_DECIMATE),
             .STAGES(CIC_STAGES))
  phDecimate (
    .clk(clk),
    .inputData(cordicMagnitude),
    .inputChannel(cordicADC),
    .inputValid(cordicTVALID && (cordicStream == STREAM_PH)),
    .cicShift(faCICshift),
    .decimateFlag(cordicFaDecimateFlag),
    // High pilot tone comes last so use it to flip ptDecimatedToggle.
    .outputToggle(ptDecimatedToggle),
    .outputData(decimatedPhUncalMags));

// Pilot tone toggle.
reg ptDecimatedMatch = 0;
reg [MAG_WIDTH-1:0] plUncalMag0, plUncalMag1, plUncalMag2, plUncalMag3;
reg [MAG_WIDTH-1:0] phUncalMag0, phUncalMag1, phUncalMag2, phUncalMag3;
reg ptUncalToggle = 0;
reg ptUncalToggle_d = 0;
reg ptUncalSrobe;
always @(posedge clk) begin
    ptUncalToggle_d <= ptUncalToggle;

    if (ptDecimatedMatch != ptDecimatedToggle) begin
        ptDecimatedMatch <= ptDecimatedToggle;
        {plUncalMag3, plUncalMag2, plUncalMag1, plUncalMag0} <= decimatedPlUncalMags;
        {phUncalMag3, phUncalMag2, phUncalMag1, phUncalMag0} <= decimatedPhUncalMags;
        ptUncalToggle <= !ptUncalToggle;
    end

    if (ptUncalToggle != ptUncalToggle_d) begin
        ptUncalSrobe <= 1'b1;
    end
    else begin
        ptUncalSrobe <= 1'b0;
    end
end

// Calibration gain for PL magnitudes
trimGPIO #(.NUM_GAINS(NADC),
           .MAG_WIDTH(MAG_WIDTH),
           .GAIN_WIDTH(GAIN_WIDTH))
  plCalibrationTrim (
    .clk(clk),

    .gpioData(gpioData),
    .gainStrobes(calPLGainStrobes),
    .gainRBK({gainCalPLRBK3, gainCalPLRBK2, gainCalPLRBK1, gainCalPLRBK0}),

    .strobe(ptUncalSrobe),
    .magnitudes({plUncalMag3, plUncalMag2, plUncalMag1, plUncalMag0}),
    .trimmedToggle(),
    .trimmed({plFaMag3, plFaMag2, plFaMag1, plFaMag0}));

// Calibration gain for PH magnitudes
trimGPIO #(.NUM_GAINS(NADC),
           .MAG_WIDTH(MAG_WIDTH),
           .GAIN_WIDTH(GAIN_WIDTH))
  phCalibrationTrim (
    .clk(clk),

    .gpioData(gpioData),
    .gainStrobes(calPHGainStrobes),
    .gainRBK({gainCalPHRBK3, gainCalPHRBK2, gainCalPHRBK1, gainCalPHRBK0}),

    .strobe(ptUncalSrobe),
    .magnitudes({phUncalMag3, phUncalMag2, phUncalMag1, phUncalMag0}),
    .trimmedToggle(ptFaToggle),
    .trimmed({phFaMag3, phFaMag2, phFaMag1, phFaMag0}));

// CIC RF FA DECIMATION
wire rfUncalDecimatedToggle;
wire [MAG_WIDTH-1:0] cicFaUncalMag0, cicFaUncalMag1, cicFaUncalMag2, cicFaUncalMag3;
reg saDecimateFlag;
always @(posedge clk) begin
    if (cordicTVALID && cordicFaDecimateFlag) begin
        saDecimateFlag <= cordicSaDecimateFlag;
    end
end
faDecimate #(.DATA_WIDTH(MAG_WIDTH),
             .DECIMATION_FACTOR(CIC_FA_DECIMATE),
             .STAGES(CIC_STAGES))
  rfDecimate (
    .clk(clk),
    .inputData(cordicMagnitude),
    .inputChannel(cordicADC),
    .inputValid(cordicTVALID && (cordicStream == STREAM_RF)),
    .cicShift(faCICshift),
    .decimateFlag(cordicFaDecimateFlag),
    .outputToggle(rfUncalDecimatedToggle),
    .outputData({cicFaUncalMag3, cicFaUncalMag2, cicFaUncalMag1, cicFaUncalMag0}));

// Calibration gain for FA magnitudes

reg rfUncalDecimatedToggle_d;
reg rfUncalDecimatedSrobe;
always @(posedge clk) begin
    rfUncalDecimatedToggle_d <= rfUncalDecimatedToggle;

    if (rfUncalDecimatedToggle != rfUncalDecimatedToggle_d) begin
        rfUncalDecimatedSrobe <= 1'b1;
    end
    else begin
        rfUncalDecimatedSrobe <= 1'b0;
    end
end

// Calibration gain for FA magnitudes. We apply the same gains
// for TbT and FA
wire rfDecimatedToggle;
wire rfDecimatedStrobe;
wire [MAG_WIDTH-1:0] cicFaMag0, cicFaMag1, cicFaMag2, cicFaMag3;
trimGPIO #(.NUM_GAINS(NADC),
           .MAG_WIDTH(MAG_WIDTH),
           .GAIN_WIDTH(GAIN_WIDTH))
  faCalibrationTrim (
    .clk(clk),

    // We apply the same gains for TbT and FA. No need to read
    // the readback from FA
    .gpioData(gpioData),
    .gainStrobes(calRFGainStrobes),
    .gainRBK(),

    .strobe(rfUncalDecimatedSrobe),
    .magnitudes({cicFaUncalMag3, cicFaUncalMag2, cicFaUncalMag1, cicFaUncalMag0}),
    .trimmedToggle(rfDecimatedToggle),
    .trimmedStrobe(rfDecimatedStrobe),
    .trimmed({cicFaMag3, cicFaMag2, cicFaMag1, cicFaMag0}));

assign cicFaMagValidDbg = rfDecimatedStrobe;
assign cicFaMag3Dbg = cicFaMag3;
assign cicFaMag2Dbg = cicFaMag2;
assign cicFaMag1Dbg = cicFaMag1;
assign cicFaMag0Dbg = cicFaMag0;

//
// Auto trim
//
wire [GAIN_WIDTH-1:0] gain0, gain1, gain2, gain3;
wire gainDoneToggle;
autotrim #(.GPIO_WIDTH(DATA_WIDTH),
           .NADC(NADC),
           .MAG_WIDTH(MAG_WIDTH),
           .GAIN_WIDTH(GAIN_WIDTH))
  autotrim (
      .clk(clk),
      .gpioData(gpioData),
      .csrStrobe(autotrimCsrStrobe),
      .thresholdStrobe(autotrimThresholdStrobe),
      .gainStrobes(autotrimGainStrobes),
      .statusReg(autotrimCsr),
      .thresholdReg(autotrimThreshold),
      .ptToggle(ptFaToggle),
      .plMags({plFaMag3, plFaMag2, plFaMag1, plFaMag0}),
      .phMags({phFaMag3, phFaMag2, phFaMag1, phFaMag0}),
      .gainToggle(gainDoneToggle),
      .gains({gain3, gain2, gain1, gain0}));

assign gainRBK0 = { {(DATA_WIDTH-GAIN_WIDTH){1'b0}}, gain0 };
assign gainRBK1 = { {(DATA_WIDTH-GAIN_WIDTH){1'b0}}, gain1 };
assign gainRBK2 = { {(DATA_WIDTH-GAIN_WIDTH){1'b0}}, gain2 };
assign gainRBK3 = { {(DATA_WIDTH-GAIN_WIDTH){1'b0}}, gain3 };

// Apply trim factors
// Hold off trimming FA until auto trim has completed
reg ptFaToggle_d = 0, awaitGainsAndRf = 0;
reg rfDecimatedMatch = 0, gainDoneMatch = 0;
reg faTrimStrobe = 0;
always @(posedge clk) begin
    ptFaToggle_d <= ptFaToggle;
    if (ptFaToggle_d != ptFaToggle) begin
        // Set up to watch for new gain and RF values
        gainDoneMatch <= gainDoneToggle;
        rfDecimatedMatch <= rfDecimatedToggle;
        awaitGainsAndRf <= 1;
        faTrimStrobe <= 0;
    end
    else if (awaitGainsAndRf && (gainDoneMatch != gainDoneToggle) &&
                                (rfDecimatedMatch != rfDecimatedToggle)) begin
        faTrimStrobe <= 1;
        awaitGainsAndRf <= 0;
    end
    else begin
        faTrimStrobe <= 0;
    end
end

trim #(.NUM_GAINS(NADC),
       .MAG_WIDTH(MAG_WIDTH),
       .GAIN_WIDTH(GAIN_WIDTH))
  faTrim (
    .clk(clk),
    .strobe(faTrimStrobe),
    .magnitudes({cicFaMag3, cicFaMag2, cicFaMag1, cicFaMag0}),
    .gains({gain3, gain2, gain1, gain0}),
    .trimmedToggle(rfFaToggle),
    .trimmed({rfFaMag3, rfFaMag2, rfFaMag1, rfFaMag0}));

trim #(.NUM_GAINS(NADC),
       .MAG_WIDTH(MAG_WIDTH),
       .GAIN_WIDTH(GAIN_WIDTH))
  tbtTrim (
    .clk(clk),
    .strobe(tbtTrimStrobe),
    .magnitudes(tbtMags),
    .gains({gain3, gain2, gain1, gain0}),
    .trimmedToggle(rfTbtToggle),
    .trimmed({rfTbtMag3, rfTbtMag2, rfTbtMag1, rfTbtMag0}));

// TbT/FA valid generation
reg rfTbtToggle_d = 0;
reg rfFaToggle_d = 0;
always @(posedge clk) begin
    rfTbtToggle_d <= rfTbtToggle;
    rfFaToggle_d <= rfFaToggle;

    if (rfTbtToggle != rfTbtToggle_d) begin
        rfTbtMagValid <= 1'b1;
    end
    else begin
        rfTbtMagValid <= 1'b0;
    end

    if (rfFaToggle != rfFaToggle_d) begin
        rfFaMagValid <= 1'b1;
    end
    else begin
        rfFaMagValid <= 1'b0;
    end

    if (ptFaToggle != ptFaToggle_d) begin
        ptFaValid <= 1'b1;
    end
    else begin
        ptFaValid <= 1'b0;
    end
end

// CIC SA DECIMATION
wire [MAG_WIDTH-1:0] rfSaDecimatedMag0, rfSaDecimatedMag1, rfSaDecimatedMag2, rfSaDecimatedMag3;
wire saDecimatedToggle;
saDecimate #(.DATA_WIDTH(MAG_WIDTH),
             .DECIMATION_FACTOR(CIC_SA_DECIMATE),
             .STAGES(CIC_STAGES),
             .CHANNEL_COUNT(4))
  saDecimate (.clk(clk),
              .inputData({rfFaMag3, rfFaMag2, rfFaMag1, rfFaMag0}),
              .inputToggle(rfFaToggle),
              .decimateFlag(saDecimateFlag),
              .outputToggle(saDecimatedToggle),
              .outputData({rfSaDecimatedMag3, rfSaDecimatedMag2, rfSaDecimatedMag1, rfSaDecimatedMag0}));

wire [MAG_WIDTH-1:0] plSaDecimatedMag0, plSaDecimatedMag1, plSaDecimatedMag2, plSaDecimatedMag3;
saDecimate #(.DATA_WIDTH(MAG_WIDTH),
             .DECIMATION_FACTOR(CIC_SA_DECIMATE),
             .STAGES(CIC_STAGES),
             .CHANNEL_COUNT(4))
  plSaDecimate (.clk(clk),
              .inputData({plFaMag3, plFaMag2, plFaMag1, plFaMag0}),
              .inputToggle(ptFaToggle),
              .decimateFlag(saDecimateFlag),
              .outputToggle(),
              .outputData({plSaDecimatedMag3, plSaDecimatedMag2, plSaDecimatedMag1, plSaDecimatedMag0}));

wire [MAG_WIDTH-1:0] phSaDecimatedMag0, phSaDecimatedMag1, phSaDecimatedMag2, phSaDecimatedMag3;
wire ptSaDecimatedToggle;
saDecimate #(.DATA_WIDTH(MAG_WIDTH),
             .DECIMATION_FACTOR(CIC_SA_DECIMATE),
             .STAGES(CIC_STAGES),
             .CHANNEL_COUNT(4))
  phSaDecimate (.clk(clk),
              .inputData({phFaMag3, phFaMag2, phFaMag1, phFaMag0}),
              .inputToggle(ptFaToggle),
              .decimateFlag(saDecimateFlag),
              .outputToggle(ptSaDecimatedToggle),
              .outputData({phSaDecimatedMag3, phSaDecimatedMag2, phSaDecimatedMag1, phSaDecimatedMag0}));

// In single-pass mode set SA values from turn-by-turn results and generate
// SA update on every single pass trigger, or if no single pass trigger
// occurs, then the most recent pilot tone update, or if no pilot tone
// update has ocurrred then every third heartbeat.
reg rfTbtMatch = 0, ptFaMatch = 0;
reg saSend = 0;
(* ASYNC_REG="TRUE" *) reg sysHbEvent_m, sysHoldoff_m = 0;
reg sysHbEvent, sysHbEvent_d, sysHoldoff = 0, sysHoldoff_d = 0;
reg [$clog2(SYSCLK_RATE)-1:0] ptWatchdog = SYSCLK_RATE - 1;
reg [1:0] hbWatchdog;
reg [63:0] sysSinglePassTimestamp;
always @(posedge clk) begin
    sysHoldoff_m  <= adcHoldoff;
    sysHoldoff    <= sysHoldoff_m;
    sysHoldoff_d  <= sysHoldoff;
    sysHbEvent_m  <= evrHbMarker;
    sysHbEvent    <= sysHbEvent_m;
    sysHbEvent_d  <= sysHbEvent;

    if (sysIsSinglePassMode) begin
        /*
         * Note time at end of pilot tone acquisition and beginning
         * of single-pass button acquisition for use when we send
         * the SA values.
         */
        if (sysHoldoff && !sysHoldoff_d) begin
            sysSinglePassTimestamp <= sysTimestamp;
        end
        if (saSend) begin
            rfSaMag0 <= rfTbtMag0;
            rfSaMag1 <= rfTbtMag1;
            rfSaMag2 <= rfTbtMag2;
            rfSaMag3 <= rfTbtMag3;
            rfSaToggle <= !rfSaToggle;
            saSend <= 0;
            ptWatchdog <= 0;
            hbWatchdog <= 3;
        end
        else begin
            if (sysHbEvent && !sysHbEvent_d && (hbWatchdog != 0)) begin
                hbWatchdog <= hbWatchdog - 1;
            end
            if (rfTbtMatch != rfTbtToggle) begin
                rfTbtMatch <= rfTbtToggle;
                sysSaTimestamp <= sysSinglePassTimestamp;
                saSend <= 1;
            end
            else if (ptFaMatch != ptFaToggle) begin
                ptFaMatch <= ptFaToggle;
                ptWatchdog <= SYSCLK_RATE - 1;
            end
            else begin
                if (ptWatchdog != 0) begin
                    ptWatchdog <= ptWatchdog - 1;
                end
                if (ptWatchdog == 1) begin
                    sysSaTimestamp <=sysSinglePassTimestamp;
                    saSend <= 1;
                end
                else if (hbWatchdog == 0) begin
                    sysSaTimestamp <= sysTimestamp;
                    saSend <= 1;
                end
            end
        end
    end
    else begin
        rfSaMag0 <= rfSaDecimatedMag0;
        rfSaMag1 <= rfSaDecimatedMag1;
        rfSaMag2 <= rfSaDecimatedMag2;
        rfSaMag3 <= rfSaDecimatedMag3;
        rfSaToggle <= saDecimatedToggle;
        /*
         * No clock crossing worries here since evrSaTimestamp
         * will have been latched before the CORDIC/trim computations.
         */
        sysSaTimestamp <= evrSaTimestamp;
    end
end

// SA valid generation
reg rfSaToggle_d;
always @(posedge clk) begin
    rfSaToggle_d <= rfSaToggle;

    if (rfSaToggle != rfSaToggle_d) begin
        rfSaValid <= 1'b1;
    end
    else begin
        rfSaValid <= 1'b0;
    end
end

// align pilot tones data to RF na provide valid signal
reg ptSaToggle_d;
always @(posedge clk) begin
    // Pilot tone low
    ptSaToggle_d <= ptSaToggle;

    if (ptSaToggle != ptSaToggle_d) begin
        ptSaValid <= 1'b1;
    end
    else begin
        ptSaValid <= 1'b0;
    end

    ptSaToggle <= ptSaDecimatedToggle;

    plSaMag0 <= plSaDecimatedMag0;
    plSaMag1 <= plSaDecimatedMag1;
    plSaMag2 <= plSaDecimatedMag2;
    plSaMag3 <= plSaDecimatedMag3;

    phSaMag0 <= phSaDecimatedMag0;
    phSaMag1 <= phSaDecimatedMag1;
    phSaMag2 <= phSaDecimatedMag2;
    phSaMag3 <= phSaDecimatedMag3;
end

generate
if (CHIPSCOPE_DBG != "TRUE" && CHIPSCOPE_DBG != "FALSE") begin
    CHIPSCOPE_DBG_only_TRUE_or_FALSE_SUPPORTED();
end
endgenerate

generate
if (CHIPSCOPE_DBG == "TRUE") begin

`ifndef SIMULATE

wire [255:0] probe;
ila_td256_s4096_cap ila_td256_s4096_cap_inst (
    .clk(clk),
    .probe0(probe)
);

assign probe[3] = ptFaToggle;
assign probe[4] = ptFaToggle_d;
assign probe[7] = ptDecimatedToggle;
assign probe[8] = ptDecimatedMatch;
assign probe[9] = awaitGainsAndRf;
assign probe[10] = gainDoneMatch;
assign probe[11] = rfDecimatedMatch;
assign probe[12] = rfDecimatedToggle;
assign probe[13] = faTrimStrobe;
assign probe[14] = adcMtLoadAndLatch;
assign probe[15] = rfFaMagValid;
assign probe[16] = faTrimStrobe;
assign probe[18:17] = cordicADC;
assign probe[19] = cordicTVALID;
assign probe[21:20] = cordicStream;
assign probe[22] = adcFaSync;
assign probe[23] = adcFaDecimateFlag;
assign probe[24] = sysFaDecimateFlag;
assign probe[25] = sysMtMatch_p;
assign probe[26] = sysMtToggle_p;
assign probe[27] = evrFaMarker;
assign probe[28] = adcFaEvent_m;
assign probe[29] = adcFaEvent;
assign probe[30] = adcFaEvent_d1;
assign probe[31] = adcMtLoadAndLatchToggle;
assign probe[32] = saDecimateFlag;
assign probe[33] = saDecimatedToggle;
assign probe[34] = rfSaValid;
assign probe[35] = rfFaToggle;
assign probe[36] = evrSaMarker;
assign probe[37] = adcSaSync;
assign probe[38] = adcSaDecimateFlag;
assign probe[39] = sysSaDecimateFlag;
assign probe[40] = cordicSaDecimateFlag;
assign probe[41] = cordicFaDecimateFlag;

assign probe[64+MAG_WIDTH-1:64] = rfFaMag0;
assign probe[96+MAG_WIDTH-1:96] = cicFaMag0;
assign probe[128+MAG_WIDTH-1:128] = cordicMagnitude;
assign probe[160+MAG_WIDTH-1:160] = rfSaDecimatedMag0;

`endif

end // end if
endgenerate

endmodule
