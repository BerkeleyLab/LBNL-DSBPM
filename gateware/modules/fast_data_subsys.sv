//
// Fast data subsystem
//

`resetall
`default_nettype none

module fast_data_subsys #(
    parameter int unsigned ADC_SETS_COUNT          = 2,
    parameter int unsigned ADCS_PER_SET_COUNT      = 4,
    parameter int unsigned ADC_CHANNEL_COUNT       = 8,
    parameter int unsigned ADC_SAMPLE_WIDTH        = 16,
    parameter int unsigned ADC_SAMPLES_PER_CHANNEL = 2,
    parameter int unsigned ADC_SAMPLES_PER_CLOCK   = 10,
    parameter int unsigned DAC_SETS_COUNT          = 2,
    parameter int unsigned DACS_PER_SET_COUNT      = 4,
    parameter int unsigned DAC_CHANNEL_COUNT       = 8,
    parameter int unsigned DAC_SAMPLE_WIDTH        = 16,
    parameter int unsigned DAC_SAMPLES_PER_CLOCK   = 1,
    parameter int unsigned DAC_SAMPLES_PER_CHANNEL = 2,
    parameter int unsigned SWAP_ADC_SETS           = 1,
    parameter int unsigned REVERSE_ADC_SET_ORDER   = 1,
    parameter int unsigned SWAP_DAC_SETS           = 1,
    parameter int unsigned REVERSE_DAC_SET_ORDER   = 0
    ) (
    input  wire logic       clk_adc_fast,
    input  wire logic       clk_adc_slow,

    input wire logic    [(ADC_CHANNEL_COUNT*
                           ADC_SAMPLES_PER_CHANNEL*
                           ADC_SAMPLES_PER_CLOCK*
                           ADC_SAMPLE_WIDTH)-1:0] adcs_phy_TDATA,
    input wire logic      [ADC_CHANNEL_COUNT-1:0] adcs_phy_TVALID,

    output wire logic   [(ADC_CHANNEL_COUNT*
                          ADC_SAMPLES_PER_CHANNEL*
                          ADC_SAMPLES_PER_CLOCK*
                          ADC_SAMPLE_WIDTH)-1:0] adcs_TDATA,
    output wire logic    [ADC_CHANNEL_COUNT-1:0] adcs_TVALID,

    input wire logic   [(DAC_CHANNEL_COUNT*
                         DAC_SAMPLES_PER_CHANNEL*
                         DAC_SAMPLES_PER_CLOCK*
                         DAC_SAMPLE_WIDTH)-1:0] dacs_phy_TDATA,
    input wire logic    [DAC_CHANNEL_COUNT-1:0] dacs_phy_TVALID,
    output wire logic   [DAC_CHANNEL_COUNT-1:0] dacs_phy_TREADY,

    output  wire logic   [(DAC_CHANNEL_COUNT*
                            DAC_SAMPLES_PER_CHANNEL*
                            DAC_SAMPLES_PER_CLOCK*
                            DAC_SAMPLE_WIDTH)-1:0] dacs_TDATA,
    output wire logic      [DAC_CHANNEL_COUNT-1:0] dacs_TVALID,
    input wire logic       [DAC_CHANNEL_COUNT-1:0] dacs_TREADY
    );

localparam int unsigned IQ_ADC_SAMPLE_WIDTH  = ADC_SAMPLE_WIDTH * ADC_SAMPLES_PER_CLOCK;
localparam int unsigned IQ_DAC_SAMPLE_WIDTH  = DAC_SAMPLE_WIDTH * DAC_SAMPLES_PER_CLOCK;

generate
if (SWAP_ADC_SETS != 1 && SWAP_ADC_SETS != 0) begin
    SWAP_ADC_SETS_only_TRUE_or_FALSE_SUPPORTED();
end
endgenerate

generate
if (REVERSE_ADC_SET_ORDER != 1 && REVERSE_ADC_SET_ORDER != 0) begin
    REVERSE_ADC_SET_ORDER_only_TRUE_or_FALSE_SUPPORTED();
end
endgenerate

generate
if (SWAP_DAC_SETS != 1 && SWAP_DAC_SETS != 0) begin
    SWAP_DAC_SETS_only_TRUE_or_FALSE_SUPPORTED();
end
endgenerate

generate
if (REVERSE_DAC_SET_ORDER != 1 && REVERSE_DAC_SET_ORDER != 0) begin
    REVERSE_DAC_SET_ORDER_only_TRUE_or_FALSE_SUPPORTED();
end
endgenerate

//////////////////////////////////////////////////////////////////////////////
// Remap ADC / DAC channels according to hardware input definitions

genvar dsbpm;
genvar channel;
generate
for dsbpm = 0 ; dsbpm < ADC_SETS_COUNT ; dsbpm = dsbpm + 1 begin
    for (channel = 0 ; channel < ADCS_PER_SET_COUNT ; channel = channel + 1) begin

        always_comb begin
            localparam OFFSET_REMAP = (SWAP_ADC_SETS == 1)?
                ADCS_PER_SET_COUNT : 0;

            localparam int unsigned adc = dsbpm*ADCS_PER_SET_COUNT + channel;

            localparam int unsigned adcRev = (REVERSE_ADC_SET_ORDER == 1)?
                dsbpm*ADCS_PER_SET_COUNT + (ADCS_PER_SET_COUNT-1 - channel) :
                dsbpm*ADCS_PER_SET_COUNT + channel;

            localparam int unsigned adcRemap = (adcRev + OFFSET_REMAP) % (ADC_SETS_COUNT*ADCS_PER_SET_COUNT);

            adcs_TVALID[adcRemap] = adcs_phy_TVALID[adc];
            adcs_TDATA[adcRemap*ADC_SAMPLES_PER_CHANNEL*IQ_ADC_SAMPLE_WIDTH+:
                                   ADC_SAMPLES_PER_CHANNEL*IQ_ADC_SAMPLE_WIDTH] =
                adcs_phy_TDATA[adc*ADC_SAMPLES_PER_CHANNEL*IQ_ADC_SAMPLE_WIDTH+:
                                      ADC_SAMPLES_PER_CHANNEL*IQ_ADC_SAMPLE_WIDTH];
        end
    end
end
endgenerate

generate
for (dsbpm = 0 ; dsbpm < DAC_SETS_COUNT ; dsbpm = dsbpm + 1) begin
    for (channel = 0 ; channel < DACS_PER_SET_COUNT ; channel = channel + 1) begin

        always_comb begin
            localparam OFFSET_REMAP = (SWAP_DAC_SETS == 1)?
                DACS_PER_SET_COUNT : 0;

            localparam int unsigned dac = dsbpm*DACS_PER_SET_COUNT + channel;

            localparam int unsigned dacRev = (REVERSE_DAC_SET_ORDER == 1)?
                dsbpm*DACS_PER_SET_COUNT + (DACS_PER_SET_COUNT-1 - channel) :
                dsbpm*DACS_PER_SET_COUNT + channel;

            localparam int unsigned dacRemap = (dacRev + OFFSET_REMAP) % (DAC_SETS_COUNT*DACS_PER_SET_COUNT);

            dacs_TREADY[dacRemap] = dacs_phy_TREADY[dac];
            dacs_phy_TVALID[dac] = dacs_TVALID[dacRemap];
            dacs_phy_TDATA[dac*DAC_SAMPLES_PER_CHANNEL*IQ_DAC_SAMPLE_WIDTH+:
                                  DAC_SAMPLES_PER_CHANNEL*IQ_DAC_SAMPLE_WIDTH] =
                dacs_TDATA[dacRemap*DAC_SAMPLES_PER_CHANNEL*IQ_DAC_SAMPLE_WIDTH+:
                                       DAC_SAMPLES_PER_CHANNEL*IQ_DAC_SAMPLE_WIDTH];
        end
    end
end
endgenerate

//////////////////////////////////////////////////////////////////////////////
// Remap ADC data to 2-D system verilog array

logic signed [INPUTS-1:0][INPUT_WIDTH-1:0] data_in;
logic valid_out;

//////////////////////////////////////////////////////////////////////////////
// Perform decimation on Fast ADC data
module adder_tree #(
    .INPUTS(),
    .INPUT_WIDTH(ADC_SAMPLE_WIDTH),
    .OUTPUT_WIDTH(ADC_SAMPLE_WIDTH)
    ) (
    .clk(clk_adc_fast),
    .rst(1'b0),

    input  wire logic       valid_in,
    input  wire logic signed [INPUTS-1:0][INPUT_WIDTH-1:0]
                            data_in,

    output wire logic signed [OUTPUT_WIDTH-1:0]
                            data_out,
    output wire logic       valid_out);

endmodule

`resetall
