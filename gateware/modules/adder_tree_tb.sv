`timescale 1ns / 1ns

module adder_tree_tb #(
    parameter NUM_INPUTS  = 8,
    parameter DATA_WIDTH  = 16,
    parameter CLK_PERIOD  = 2.0  // 500 MHz
);

localparam DEPTH = $clog2(NUM_INPUTS);

logic clk = 0;
logic rst = 0;
logic valid_in = 0;
logic [DATA_WIDTH-1:0] data_in [0:NUM_INPUTS-1];
logic [NUM_INPUTS*DATA_WIDTH-1:0] data_in_flat;

logic [DATA_WIDTH+DEPTH-1:0] data_out;
logic valid_out;

// Clock Generation
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// Helper function to calculate sum
function signed [DATA_WIDTH+DEPTH-1:0] calc_sum;
    input [NUM_INPUTS*DATA_WIDTH-1:0] flat_data;
    integer k;
    logic signed [DATA_WIDTH-1:0] temp;
    begin
        calc_sum = 0;
        for (k = 0; k < NUM_INPUTS; k = k + 1) begin
            temp = flat_data[k*DATA_WIDTH+:DATA_WIDTH];
            calc_sum = calc_sum + temp;
        end
    end
endfunction

// Helper task to randomize data
task randomize_inputs;
    integer i;
    begin
        for(i = 0; i < NUM_INPUTS; i = i+1) begin
            data_in[i] = $random % 10;
        end
    end
endtask

genvar ix;
generate
for(ix = 0; ix < NUM_INPUTS; ix = ix+1) begin
    assign data_in_flat[ix*DATA_WIDTH+:DATA_WIDTH] = data_in[ix];
end
endgenerate

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("adder_tree.vcd");
        $dumpvars(0, adder_tree_tb);
    end
end

// Scoreboarding
logic [DATA_WIDTH+DEPTH-1:0] expected_queue [$];
logic [DATA_WIDTH+DEPTH-1:0] expected_val;
integer errors = 0;

// Instantiate DUT
adder_tree #(
    .NUM_INPUTS(NUM_INPUTS),
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .data_in(data_in_flat),
    .data_out(data_out),
    .valid_out(valid_out)
);

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
integer j;
initial begin
    rst = 1;
    valid_in = 0;
    errors = 0;

    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        data_in[j] = 0;
    end

    repeat(5) begin
        @(posedge clk);
    end

    rst = 0;

    repeat(2) begin
        @(posedge clk);
    end

    for (j = 0; j < 200; j = j + 1) begin

        // Randomly decide if this cycle is valid (70% chance of valid)
        if (($random % 100) < 70) begin
            valid_in <= 1;
            randomize_inputs();

            // Add expected result to queue
            expected_queue.push_back(calc_sum(data_in_flat));
        end else begin
            valid_in <= 0;
            // Data on invalid cycles shouldn't matter, but we randomize it
            // to ensure the DUT doesn't accidentally process it.
            randomize_inputs();
        end

        @(posedge clk);
    end

    // End of stream
    valid_in <= 0;
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
        $stop(0);
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
