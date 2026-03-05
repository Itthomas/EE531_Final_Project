`timescale 1ns / 1ps

module tb_aer_handler;

    // ---------------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------------
    localparam int NUM_NEURONS = 4;
    localparam int ADDR_WIDTH  = $clog2(NUM_NEURONS);
    localparam int CLK_PERIOD  = 10;

    // ---------------------------------------------------------------
    // DUT signals
    // ---------------------------------------------------------------
    logic                        clk, rst_n, step_rst;
    logic [NUM_NEURONS-1:0]      spike_vec;
    logic [ADDR_WIDTH-1:0]       aer_addr;
    logic                        aer_valid;

    aer_handler #(
        .NUM_NEURONS(NUM_NEURONS)
    ) dut (.*);

    // ---------------------------------------------------------------
    // Scoreboard
    // ---------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0;

    task automatic check(input string name, input logic cond);
        if (cond) begin
            $display("[PASS] %s", name);
            pass_cnt++;
        end else begin
            $display("[FAIL] %s", name);
            fail_cnt++;
        end
    endtask

    task automatic check_addr(input string name,
                              input logic [ADDR_WIDTH-1:0] exp_addr,
                              input logic exp_valid);
        check({name, " - valid"},  aer_valid === exp_valid);
        if (exp_valid)
            check({name, " - addr"}, aer_addr === exp_addr);
    endtask

    // ---------------------------------------------------------------
    // Clock
    // ---------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Helper: full reset
    task automatic do_reset();
        rst_n     = 1'b0;
        step_rst  = 1'b0;
        spike_vec = '0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    endtask

    // Helper: wait one clock for serviced mask to register
    task automatic tick();
        @(posedge clk);
        #1;  // small delta for combinational settle
    endtask

    // ---------------------------------------------------------------
    // Main stimulus
    // ---------------------------------------------------------------
    initial begin
        $timeformat(-9, 0, " ns", 8);

        // ---- Test 1: Reset ----
        do_reset();
        check("T1 Reset - aer_valid=0", aer_valid === 1'b0);

        // ---- Test 2: Single spike (neuron 1) ----
        spike_vec = 4'b0010;
        #1;
        check_addr("T2 Single spike", 2'd1, 1'b1);

        // Let it get serviced
        tick();
        check("T2 After servicing - valid=0", aer_valid === 1'b0);

        // ---- Test 3: Priority order (neurons 1 & 3) ----
        do_reset();
        spike_vec = 4'b1010;
        #1;
        check_addr("T3 Priority - first grants neuron 1", 2'd1, 1'b1);

        tick();  // neuron 1 serviced
        check_addr("T3 Priority - next grants neuron 3", 2'd3, 1'b1);

        tick();  // neuron 3 serviced
        check("T3 All serviced - valid=0", aer_valid === 1'b0);

        // ---- Test 4: All neurons spike ----
        do_reset();
        spike_vec = 4'b1111;
        #1;
        check_addr("T4 All spikes - cycle 0", 2'd0, 1'b1);

        tick();
        check_addr("T4 All spikes - cycle 1", 2'd1, 1'b1);

        tick();
        check_addr("T4 All spikes - cycle 2", 2'd2, 1'b1);

        tick();
        check_addr("T4 All spikes - cycle 3", 2'd3, 1'b1);

        tick();
        check("T4 All serviced - valid=0", aer_valid === 1'b0);

        // ---- Test 5: Serviced mask persistence ----
        // spike_vec still 4'b1111 from test 4, no step_rst issued
        spike_vec = 4'b1111;
        repeat (3) tick();
        check("T5 Mask persists - valid stays 0", aer_valid === 1'b0);

        // ---- Test 6: step_rst clears mask ----
        @(negedge clk);
        step_rst = 1'b1;
        @(negedge clk);
        step_rst = 1'b0;
        #1;
        // Same spike_vec, should restart from neuron 0
        check_addr("T6 step_rst - re-grants neuron 0", 2'd0, 1'b1);

        // Clean up remaining
        repeat (4) tick();

        // ---- Test 7: No spikes ----
        do_reset();
        spike_vec = 4'b0000;
        #1;
        check("T7 No spikes - valid=0", aer_valid === 1'b0);
        repeat (3) tick();
        check("T7 Still no spikes - valid=0", aer_valid === 1'b0);

        // ---- Test 8: Late spike arrival ----
        do_reset();
        spike_vec = 4'b0001;  // only neuron 0
        #1;
        check_addr("T8 Initial spike - neuron 0", 2'd0, 1'b1);

        tick();  // neuron 0 serviced
        check("T8 After servicing - valid=0", aer_valid === 1'b0);

        // New spike appears on neuron 2
        spike_vec = 4'b0101;  // neuron 0 already serviced, neuron 2 is new
        #1;
        check_addr("T8 Late arrival - neuron 2", 2'd2, 1'b1);

        tick();
        check("T8 Late arrival serviced - valid=0", aer_valid === 1'b0);

        // ---- Summary ----
        $display("");
        $display("==========================");
        $display("  AER HANDLER TB");
        $display("  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt);
        $display("==========================");
        $finish;
    end

endmodule
