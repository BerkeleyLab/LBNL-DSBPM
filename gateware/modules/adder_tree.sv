//
// Adder tree
//

`resetall
`default_nettype none

module adder_tree #(
    parameter NUM_INPUTS = 10,
    parameter DATA_WIDTH = 16,
    // Don't change these
    parameter DEPTH = $clog2(NUM_INPUTS)
    ) (
    input  wire logic       clk,
    input  wire logic       rst,

    input  wire logic       valid_in,
    input  wire logic [NUM_INPUTS*DATA_WIDTH-1:0]
                            data_in,

    output wire logic [DATA_WIDTH+DEPTH-1:0]
                            data_out,
    output wire logic       valid_out);

generate if (NUM_INPUTS < 2) begin:
    NUM_INPUTS_less_than_2_not_supported error();
end
endgenerate

// Calculate adder tree stage size. Each stage halves the number
// of operands. For each stage:
// num_output = (num_input + 1) / 2
function automatic int get_stage_size(int num_inputs, int stage);
    int stage_size = (num_inputs + (1 << stage) -1) >> stage;
    return stage_size;
endfunction

localparam MAX_WIDTH = DATA_WIDTH + DEPTH;

// Pipeline memory for Data. Rely on the optimizer to
// remove stages we won't be using
logic signed [MAX_WIDTH-1:0] pipe [0:DEPTH][0:NUM_INPUTS-1];

// Pipeline register for Valid signal
// Size is DEPTH+1 because we need index 0 (input) to index DEPTH (output)
logic [DEPTH:0] valid_pipe = '0;

//
// Stage 0: Load inputs
//
integer j;
always_ff @(posedge clk) begin
    if (rst) begin
        valid_pipe[0] <= 1'b0;
        for (j = 0; j < NUM_INPUTS; j++) begin
            pipe[0][j] <= '0;
        end
    end else begin
        valid_pipe[0] <= valid_in;
        for (j = 0; j < NUM_INPUTS; j++) begin
            pipe[0][j] <= signed'(data_in[j*DATA_WIDTH+:DATA_WIDTH]);
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
                // Add pairs if they exist. If off number of inputs,
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

assign data_out = pipe[DEPTH][0];
assign valid_out = valid_pipe[DEPTH];

endmodule

`resetall
