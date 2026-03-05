`timescale 1ns / 1ps

module tb_synapse_accumulator;

    // ---------------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------------
    localparam int NUM_SYN     = 4;
    localparam int W_WIDTH     = 8;
    localparam int A_WIDTH     = 16;
    localparam int CLK_PERIOD  = 10;
    localparam int ADDR_WIDTH  = $clog2(NUM_SYN);

    // Known weight array: {+10, -20, +50, -100}
    localparam logic signed [W_WIDTH-1:0] TEST_WEIGHTS [0:NUM_SYN-1] = '{
        8'sd10, -8'sd20, 8'sd50, -8'sd100
    };

    // Saturation bounds
    localparam logic signed [A_WIDTH-1:0] MAX_VAL = {1'b0, {(A_WIDTH-1){1'b1}}};  // 32767
    localparam logic signed [A_WIDTH-1:0] MIN_VAL = {1'b1, {(A_WIDTH-1){1'b0}}};  // -32768

    // ---------------------------------------------------------------
    // DUT signals
    // ---------------------------------------------------------------
    logic                          clk, rst_n, accum_rst, spike_valid;
    logic [ADDR_WIDTH-1:0]         spike_addr;
    logic signed [A_WIDTH-1:0]     accum_out;

    synapse_accumulator #(
        .NUM_SYNAPSES(NUM_SYN),
        .WEIGHT_WIDTH(W_WIDTH),
        .ACCUM_WIDTH(A_WIDTH),
        .WEIGHTS(TEST_WEIGHTS)
    ) dut (.*);

    // ---------------------------------------------------------------
    // Scoreboard
    // ---------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0;

    task automatic check(input string name, input logic signed [A_WIDTH-1:0] actual,
                         input logic signed [A_WIDTH-1:0] expected);
        if (actual === expected) begin
            $display("[PASS] %s (got %0d)", name, actual);
            pass_cnt++;
        end else begin
            $display("[FAIL] %s - expected %0d, got %0d", name, expected, actual);
            fail_cnt++;
        end
    endtask

    // ---------------------------------------------------------------
    // Clock
    // ---------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Helper: send one spike and wait for result
    task automatic send_spike(input logic [ADDR_WIDTH-1:0] addr);
        @(negedge clk);
        spike_valid = 1'b1;
        spike_addr  = addr;
        @(negedge clk);
        spike_valid = 1'b0;
    endtask

    // Helper: full reset sequence
    task automatic do_reset();
        rst_n = 1'b0;
        spike_valid = 1'b0;
        accum_rst   = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    endtask

    // ---------------------------------------------------------------
    // Expected accumulator tracker
    // ---------------------------------------------------------------
    logic signed [31:0] expected;

    // ---------------------------------------------------------------
    // Main stimulus
    // ---------------------------------------------------------------
    initial begin
        $timeformat(-9, 0, " ns", 8);
        spike_valid = 1'b0;
        spike_addr  = '0;
        accum_rst   = 1'b0;

        // ---- Test 1: Reset ----
        do_reset();
        check("T1 Reset - accum = 0", accum_out, '0);

        // ---- Test 2: Single positive spike (addr 0, weight +10) ----
        expected = 0;
        send_spike(2'd0);
        expected = expected + 10;
        check("T2 Single positive spike", accum_out, A_WIDTH'(expected));

        // ---- Test 3: Single negative spike (addr 1, weight -20) ----
        send_spike(2'd1);
        expected = expected - 20;
        check("T3 Negative spike - accum = -10", accum_out, A_WIDTH'(expected));

        // ---- Test 4: Multi-address accumulation ----
        send_spike(2'd2);  // +50
        expected = expected + 50;
        check("T4a Spike addr 2", accum_out, A_WIDTH'(expected));

        send_spike(2'd3);  // -100
        expected = expected - 100;
        check("T4b Spike addr 3", accum_out, A_WIDTH'(expected));

        // ---- Test 5: accum_rst ----
        @(negedge clk);
        accum_rst = 1'b1;
        @(negedge clk);
        accum_rst = 1'b0;
        check("T5 accum_rst clears to 0", accum_out, '0);
        expected = 0;

        // ---- Test 6: No-op when spike_valid=0 ----
        spike_valid = 1'b0;
        spike_addr  = 2'd2;  // weight would be +50
        repeat (3) @(posedge clk);
        check("T6 No accumulation when valid=0", accum_out, '0);

        // ---- Test 7: Positive saturation ----
        // Weight[2] = +50, need ceil(32767/50) = 656 spikes to saturate
        do_reset();
        expected = 0;
        for (int i = 0; i < 700; i++) begin
            send_spike(2'd2);
            expected = expected + 50;
        end
        check("T7 Positive saturation - clamped at MAX_VAL", accum_out, MAX_VAL);

        // ---- Test 8: Negative saturation ----
        // Weight[3] = -100, need ceil(32768/100) = 328 spikes to saturate
        do_reset();
        expected = 0;
        for (int i = 0; i < 400; i++) begin
            send_spike(2'd3);
            expected = expected - 100;
        end
        check("T8 Negative saturation - clamped at MIN_VAL", accum_out, MIN_VAL);

        // ---- Test 9: Back-to-back spikes all 4 addresses ----
        do_reset();
        send_spike(2'd0);  // +10
        send_spike(2'd1);  // -20
        send_spike(2'd2);  // +50
        send_spike(2'd3);  // -100
        // Expected: 10 - 20 + 50 - 100 = -60
        check("T9 Back-to-back all addrs - accum = -60", accum_out, -16'sd60);

        // ---- Summary ----
        $display("");
        $display("==================================");
        $display("  SYNAPSE ACCUMULATOR TB");
        $display("  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt);
        $display("==================================");
        $finish;
    end

endmodule
