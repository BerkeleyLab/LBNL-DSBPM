`timescale 1ns / 1ns

module adder_tree_tb #(
    parameter int unsigned NUM_INPUTS = 10,
    parameter int unsigned INPUT_WIDTH = 16,
    parameter int unsigned OUTPUT_WIDTH = 16,
    parameter logic ROUND_CONVERGENT = 1'b1,
    parameter CLK_PERIOD  = 2.0  // 500 MHz
);

localparam DEPTH = $clog2(NUM_INPUTS);
localparam FULL_WIDTH = INPUT_WIDTH + DEPTH;

logic clk = 0;
logic rst = 0;
logic valid_in = 0;
logic signed [NUM_INPUTS-1:0][INPUT_WIDTH-1:0] data_in;
logic valid_out;
logic signed [OUTPUT_WIDTH-1:0] data_out;

// Clock Generation
always #(CLK_PERIOD/2) clk = ~clk;

// Helper function to calculate sum
function automatic int sum_reduction(
    input logic signed [NUM_INPUTS-1:0][INPUT_WIDTH-1:0] data);
    int sum = 0;

    for (int i = 0; i < NUM_INPUTS; i++) begin
        sum += data[i];
    end

    return sum;
endfunction

// Function to handle resizing, sign extension, and rounding
function automatic logic [OUTPUT_WIDTH-1:0] resize_data(
    input int raw_sum,
    input logic round_convergent
);
    logic [OUTPUT_WIDTH-1:0] resized_val;
    logic signed [FULL_WIDTH-1:0] val_in;
    logic is_exact_half;
    logic round_bit;
    localparam int extra_bits = FULL_WIDTH - OUTPUT_WIDTH;

    val_in = raw_sum[FULL_WIDTH-1:0];

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

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("adder_tree.vcd");
        $dumpvars(0, adder_tree_tb);
    end
end

// Scoreboarding
logic signed [OUTPUT_WIDTH-1:0] expected_queue [$];
logic signed [OUTPUT_WIDTH-1:0] expected_val;
integer errors = 0;

// Instantiate DUT
adder_tree #(
    .NUM_INPUTS(NUM_INPUTS),
    .INPUT_WIDTH(INPUT_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH),
    .ROUND_CONVERGENT(ROUND_CONVERGENT)
) dut (.*);

generate

genvar r, c;
for (r = 0; r < DEPTH+1; r++) begin
    for (c = 0; c < NUM_INPUTS; c++) begin
        initial begin
            // Wait to ensure $dumpfile is set by the main initial block
            #0;
            if ($test$plusargs("vcd")) begin
                $dumpvars(0, dut.pipe[r][c]);
            end
        end
    end
end

endgenerate

// Stimulus Process
logic signed [NUM_INPUTS-1:0][INPUT_WIDTH-1:0] next_data_in;
int raw_sum = 0;
logic signed [OUTPUT_WIDTH-1:0] resized_sum = 0;

initial begin
    rst = 1;
    valid_in = 0;
    errors = 0;

    for (int i = 0; i < NUM_INPUTS; i++) begin
        data_in[i] = 0;
        next_data_in[i] = 0;
    end

    repeat(5) begin
        @(posedge clk);
    end

    rst = 0;

    repeat(2) begin
        @(posedge clk);
    end

    for (int i = 0; i < 200; i++) begin

        // Randomly decide if this cycle is valid (70% chance of valid)
        if (($random % 100) < 70) begin

            for (int i = 0; i < NUM_INPUTS; i++) begin
                next_data_in[i] = $random;
            end

            valid_in <= 1;
            data_in <= next_data_in;

            // Add expected result to queue
            raw_sum = sum_reduction(next_data_in);
            resized_sum = resize_data(raw_sum, ROUND_CONVERGENT);
            expected_queue.push_back(resized_sum);
        end else begin
            valid_in <= 0;
            data_in <= 'x;
        end

        @(posedge clk);
    end

    // End of stream
    valid_in <= 0;
    data_in <= 'x;
    @(posedge clk);

    // Wait for pipeline drain
    repeat(20) begin
        @(posedge clk);
    end

    if (errors == 0 && expected_queue.size() == 0) begin
        $display("# PASS");
        $finish(0);
    end else begin
        $display("# FAIL, %0d errors", errors);

        $finish(0);
    end
end

// Checker Process
always_ff @(posedge clk) begin
    if (!rst && valid_out) begin
        if (expected_queue.size() == 0) begin
            $display("Error: Unexpected valid_out received (Queue empty)");
            errors++;
        end else begin
            expected_val = expected_queue.pop_front();
            if (data_out !== expected_val) begin
                $display("Error: Expected %d, Got %d", expected_val, data_out);
                errors++;
            end
        end
    end
end

endmodule
