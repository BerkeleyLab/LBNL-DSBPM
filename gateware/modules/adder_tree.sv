//
// Adder tree
//

`resetall
`default_nettype none

module adder_tree #(
    parameter int unsigned NUM_INPUTS = 10,
    parameter int unsigned INPUT_WIDTH = 16,
    parameter int unsigned OUTPUT_WIDTH = 16,
    parameter logic ROUND_CONVERGENT = 1'b1
    ) (
    input  wire logic       clk,
    input  wire logic       rst,

    input  wire logic       valid_in,
    input  wire logic signed [NUM_INPUTS-1:0][INPUT_WIDTH-1:0]
                            data_in,

    output wire logic signed [OUTPUT_WIDTH-1:0]
                            data_out,
    output wire logic       valid_out);

generate if (NUM_INPUTS < 2) begin:
    NUM_INPUTS_less_than_2_not_supported error();
end
endgenerate

localparam int unsigned DEPTH = $clog2(NUM_INPUTS);

// Calculate adder tree stage size. Each stage halves the number
// of operands. For each stage:
// num_output = (num_input + 1) / 2
function automatic int get_stage_size(int num_inputs, int stage);
    int stage_size = (num_inputs + (1 << stage) -1) >> stage;
    return stage_size;
endfunction

localparam int unsigned FULL_WIDTH = INPUT_WIDTH + DEPTH;

// Function to handle resizing, sign extension, and rounding
function automatic logic [OUTPUT_WIDTH-1:0] resize_data(
    input logic [FULL_WIDTH-1:0] val_in,
    input logic round_convergent
);
    logic [OUTPUT_WIDTH-1:0] resized_val;
    logic is_exact_half;
    logic round_bit;

    // Apprently Icarus doens't understand this:
    // localparam int extra_bits = $bits(val_in) - $bits(resized_val);
    localparam int extra_bits = FULL_WIDTH - OUTPUT_WIDTH;

    // Widths match exactly, no resizing needed
    if (extra_bits == 0) begin
        resized_val = val_in[FULL_WIDTH-1:0];
    end
    // Rounding/Truncation needed (Input is wider than Output)
    else if (extra_bits > 0) begin
        if (round_convergent) begin
            // Check if the fractional part is exactly 0.5 (100...0)
            // We check if the MSB of the extra bits is 1, and all lower bits are 0.
            is_exact_half = (val_in[extra_bits-1:0] == {1'b1, {(extra_bits-1){1'b0}}});

            // Convergent Rounding Rule:
            // If exactly 0.5: Round to nearest even (add LSB of integer part)
            // If not 0.5:     Standard round (add MSB of fractional part)
            round_bit = is_exact_half ? val_in[extra_bits] : val_in[extra_bits-1];

            resized_val = val_in[FULL_WIDTH-1:extra_bits] + round_bit;
        end
        else begin
            // Floor (Truncation) - default behavior
            resized_val = val_in[FULL_WIDTH-1:extra_bits];
        end
    end
    // Sign Extension needed (Input is narrower than Output)
    else begin // extra_bits < 0
        // Replicates the sign bit (MSB) to fill the upper bits
        resized_val = { {(-extra_bits){val_in[FULL_WIDTH-1]}}, val_in };
    end

    return resized_val;
endfunction

// Pipeline memory for Data. Rely on the optimizer to
// remove stages we won't be using
logic signed [FULL_WIDTH-1:0] pipe [0:DEPTH][0:NUM_INPUTS-1];

// Pipeline register for Valid signal
// Size is DEPTH+1 because we need index 0 (input) to index DEPTH (output)
logic [DEPTH:0] valid_pipe = '0;

//
// Stage 0: Load inputs
//
always_ff @(posedge clk) begin
    if (rst) begin
        valid_pipe[0] <= 1'b0;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            pipe[0][i] <= '0;
        end
    end else begin
        valid_pipe[0] <= valid_in;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            pipe[0][i] <= data_in[i];
        end
    end
end

//
// Stages 1 to N: adder tree itself
//
generate
genvar s, i;

// Loop through levels of the tree
for (s = 0; s < DEPTH; s++) begin : STAGES
    // Calculate sizes at build time
    localparam int NUM_STAGE_INPUTS = get_stage_size(NUM_INPUTS, s);
    localparam int NUM_STAGE_OUTPUTS = get_stage_size(NUM_INPUTS, s+1);

    // Generate registers for this stage
    for (i = 0; i < NUM_STAGE_OUTPUTS; i++) begin : TREE
        always_ff @(posedge clk) begin
            if (rst) begin
                pipe[s+1][i] <= '0;
                valid_pipe[s+1] <= 1'b0;
            end else begin
                // Add pairs if they exist. If odd number of inputs,
                // passthrough.
                if ((2*i+1) < NUM_STAGE_INPUTS) begin
                    pipe[s+1][i] <= pipe[s][2*i] + pipe[s][2*i+1];
                end else begin
                    pipe[s+1][i] <= pipe[s][2*i];
                end

                valid_pipe[s+1] <= valid_pipe[s];
            end
        end
    end
end

endgenerate

//
// Round output
//
logic signed [OUTPUT_WIDTH-1:0] data_rs;
logic valid_rs;
always_ff @(posedge clk) begin
    if (rst) begin
        data_rs <= '0;
        valid_rs <= 1'b0;
    end else begin
        data_rs <= resize_data(pipe[DEPTH][0], ROUND_CONVERGENT);
        valid_rs <= valid_pipe[DEPTH];
    end
end

assign data_out = data_rs;
assign valid_out = valid_rs;

endmodule

`resetall
