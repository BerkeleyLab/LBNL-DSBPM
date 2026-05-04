module adder_tb #(
    parameter int INPUT_WIDTH = 32,
    parameter int OUTPUT_WIDTH = 32,
    parameter CLK_PERIOD  = 10.0
);

logic clk = 0;
logic valid_in = 0;
logic signed [INPUT_WIDTH-1:0] a;
logic signed [INPUT_WIDTH-1:0] b;
logic valid_out;
logic signed [OUTPUT_WIDTH-1:0] sum;

// Clock Generation
always #(CLK_PERIOD/2) clk = ~clk;

// Function to handle resizing, sign extension, and rounding
function automatic logic [OUTPUT_WIDTH-1:0] sat_data (
    input logic signed [INPUT_WIDTH:0] full_sum
);
    logic [OUTPUT_WIDTH-1:0] resized_val;
    localparam int extra_bits = (INPUT_WIDTH+1) - OUTPUT_WIDTH;
    localparam signed [OUTPUT_WIDTH-1:0] MAX_VAL = {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
    localparam signed [OUTPUT_WIDTH-1:0] MIN_VAL = {1'b1, {(OUTPUT_WIDTH-1){1'b0}}};

    // Widths match exactly, no resizing needed
    if (extra_bits == 0) begin
        resized_val = full_sum;
    end
    else if (extra_bits > 0) begin
        resized_val = full_sum > MAX_VAL? MAX_VAL :
                      full_sum < MIN_VAL? MIN_VAL :
                      full_sum[OUTPUT_WIDTH-1:0];
    end
    else begin // extra_bits < 0
        // Replicates the sign bit (MSB) to fill the upper bits
        resized_val = { {(-extra_bits){full_sum[INPUT_WIDTH]}}, full_sum };
    end

    return resized_val;
endfunction

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("adder.vcd");
        $dumpvars(0, adder_tb);
    end
end

// Scoreboarding
logic signed [OUTPUT_WIDTH-1:0] expected_queue [$];
logic signed [OUTPUT_WIDTH-1:0] expected_val;
integer errors = 0;

// Instantiate DUT
adder #(
    .INPUT_WIDTH(INPUT_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) dut (.*);

// Stimulus Process
logic signed [INPUT_WIDTH-1:0] next_a;
logic signed [INPUT_WIDTH-1:0] next_b;
logic signed [INPUT_WIDTH:0] full_sum = 0;

initial begin
    valid_in = 0;
    errors = 0;

    a = 0;
    b = 0;
    next_a = 0;
    next_b = 0;

    repeat(5) begin
        @(posedge clk);
    end

    for (int i = 0; i < 200; i++) begin

        // Randomly decide if this cycle is valid (70% chance of valid)
        if (($random % 100) < 70) begin

            next_a = $random;
            next_b = $random;

            valid_in <= 1;
            a <= next_a;
            b <= next_b;

            // Add expected result to queue
            full_sum = next_a + next_b;
            expected_val = sat_data(full_sum);
            expected_queue.push_back(expected_val);
        end else begin
            valid_in <= 0;
            a <= 'x;
            b <= 'x;
        end

        @(posedge clk);
    end

    // End of stream
    valid_in <= 0;
    a <= 'x;
    b <= 'x;
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
    if (valid_out) begin
        if (expected_queue.size() == 0) begin
            $display("Error: Unexpected valid_out received (Queue empty)");
            errors++;
        end else begin
            expected_val = expected_queue.pop_front();
            if (sum !== expected_val) begin
                $display("Error: Expected %d, Got %d", expected_val, sum);
                errors++;
            end
        end
    end
end

endmodule
