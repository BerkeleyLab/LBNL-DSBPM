`timescale 1ns / 1ns

module adder_tree_tb #(
    parameter NUM_INPUTS  = 10,
    parameter DATA_WIDTH  = 16,
    parameter CLK_PERIOD  = 2.0  // 500 MHz
);

localparam DEPTH = $clog2(NUM_INPUTS);

logic clk = 0;
logic rst = 0;
logic valid_in = 0;
logic signed [NUM_INPUTS-1:0][DATA_WIDTH-1:0] data_in;
logic valid_out;
logic signed [DATA_WIDTH+DEPTH-1:0] data_out;

// Clock Generation
always #(CLK_PERIOD/2) clk = ~clk;

// Helper function to calculate sum
function automatic int sum_reduction(
    input logic signed [NUM_INPUTS-1:0][DATA_WIDTH-1:0] data);
    int sum = 0;

    for (int i = 0; i < NUM_INPUTS; i++) begin
        sum += data[i];
    end

    return sum;
endfunction

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("adder_tree.vcd");
        $dumpvars(0, adder_tree_tb);
    end
end

// Scoreboarding
int expected_queue [$];
int expected_val;
integer errors = 0;

// Instantiate DUT
adder_tree #(
    .NUM_INPUTS(NUM_INPUTS),
    .DATA_WIDTH(DATA_WIDTH)
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
logic signed [NUM_INPUTS-1:0][DATA_WIDTH-1:0] next_data_in;

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
                next_data_in[i] = $random % 10;
            end

            valid_in <= 1;
            data_in <= next_data_in;

            // Add expected result to queue
            expected_queue.push_back(sum_reduction(next_data_in));
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
