`timescale 1ns / 1ps

module tb_lif_neuron_fixed;

    // ---------------------------------------------------------------
    // Parameters (default instance)
    // ---------------------------------------------------------------
    localparam int WIDTH      = 16;
    localparam int FRAC_WIDTH = 8;
    localparam int I_WIDTH    = 16;
    localparam int I_FRAC     = 8;
    localparam int CLK_PERIOD = 10;

    // Derived constants matching the DUT
    localparam logic signed [WIDTH-1:0] MAX_VAL = {1'b0, {(WIDTH-1){1'b1}}};
    localparam logic signed [WIDTH-1:0] MIN_VAL = {1'b1, {(WIDTH-1){1'b0}}};
    localparam logic signed [WIDTH-1:0] V_RESET =
        $signed({1'b1, {(WIDTH-1){1'b0}}}) >>> 1;  // -2^(WIDTH-2)

    // ---------------------------------------------------------------
    // DUT signals (default params)
    // ---------------------------------------------------------------
    logic                      clk, rst_n, en;
    logic signed [I_WIDTH-1:0] input_current;
    logic                      spike;

    lif_neuron_fixed #(
        .I_WIDTH(I_WIDTH), .I_FRAC_WIDTH(I_FRAC),
        .WIDTH(WIDTH),     .FRAC_WIDTH(FRAC_WIDTH)
    ) dut (.*);

    // ---------------------------------------------------------------
    // DUT signals (shifted-frac instance: I_FRAC_WIDTH = 4)
    // ---------------------------------------------------------------
    localparam int I_FRAC_SHIFT = 4;
    logic                      en_s;
    logic signed [I_WIDTH-1:0] input_current_s;
    logic                      spike_s;

    lif_neuron_fixed #(
        .I_WIDTH(I_WIDTH), .I_FRAC_WIDTH(I_FRAC_SHIFT),
        .WIDTH(WIDTH),     .FRAC_WIDTH(FRAC_WIDTH)
    ) dut_shift (
        .clk(clk), .rst_n(rst_n), .en(en_s),
        .input_current(input_current_s), .spike(spike_s)
    );

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

    // ---------------------------------------------------------------
    // Clock
    // ---------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Helper: pulse en for one cycle and wait for update
    task automatic pulse_en();
        @(negedge clk);
        en = 1'b1;
        @(negedge clk);
        en = 1'b0;
    endtask

    // ---------------------------------------------------------------
    // Main stimulus
    // ---------------------------------------------------------------
    initial begin
        $timeformat(-9, 0, " ns", 8);

        // Defaults
        rst_n         = 1'b0;
        en            = 1'b0;
        input_current = '0;
        en_s          = 1'b0;
        input_current_s = '0;

        // ---- Test 1: Reset ----
        repeat (2) @(posedge clk);
        check("T1 Reset spike=0", spike === 1'b0);

        rst_n = 1'b1;
        @(posedge clk);

        // ---- Test 2: Enable gating ----
        input_current = 16'sd5000;
        repeat (5) @(posedge clk);  // en stays 0
        check("T2 Enable gating - spike still 0", spike === 1'b0);

        // ---- Test 3: Pure decay ----
        // Inject current for a few cycles to build membrane
        input_current = 16'sd1000;
        repeat (3) pulse_en();

        // Capture membrane via spike (it shouldn't spike with 3 small pulses)
        // Now remove input and decay
        input_current = '0;
        // Read internal state through hierarchical access
        begin
            logic signed [WIDTH-1:0] v_before, v_after;
            v_before = dut.v_reg;
            pulse_en();
            v_after = dut.v_reg;
            // v should move toward zero (magnitude decreases)
            check("T3 Decay - |v| decreased",
                  (v_after >= 0 && v_after < v_before) ||
                  (v_after < 0  && v_after > v_before) ||
                  (v_after == 0 && v_before == 0));
        end

        // ---- Test 4: Positive accumulation → spike ----
        // Reset first
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        input_current = 16'sd4000;
        begin
            logic spiked;
            spiked = 1'b0;
            for (int i = 0; i < 200; i++) begin
                pulse_en();
                if (spike) begin spiked = 1'b1; break; end
            end
            check("T4 Positive input causes spike", spiked === 1'b1);
            check("T4 V_RESET after spike", dut.v_reg === V_RESET);
        end

        // ---- Test 5: Post-spike recovery ----
        // Keep driving same current; neuron should spike again
        begin
            logic spiked_again;
            spiked_again = 1'b0;
            for (int i = 0; i < 500; i++) begin
                pulse_en();
                if (spike) begin spiked_again = 1'b1; break; end
            end
            check("T5 Post-spike recovery - spikes again", spiked_again === 1'b1);
        end

        // ---- Test 6: Negative saturation ----
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        input_current = -16'sd30000;
        repeat (5) pulse_en();
        check("T6 Negative saturation - v_reg = MIN_VAL",
              dut.v_reg === MIN_VAL);
        check("T6 Negative saturation - no spike", spike === 1'b0);

        // ---- Test 7: Zero steady state ----
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        input_current = '0;
        repeat (10) pulse_en();
        check("T7 Zero input, zero state - v_reg = 0", dut.v_reg === '0);
        check("T7 Zero input - no spike", spike === 1'b0);

        // ---- Test 8: Input alignment (I_FRAC_WIDTH=4 vs FRAC_WIDTH=8) ----
        // Apply same raw value to both instances; shifted instance should
        // produce an internal contribution 2^(8-4) = 16× larger.
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        input_current   = 16'sd256;  // Q8.8: 1.0
        input_current_s = 16'sd256;  // Q12.4: 16.0 (same raw bits, more integer)

        // Pulse default instance
        @(negedge clk);
        en = 1'b1; en_s = 1'b0;
        @(negedge clk);
        en = 1'b0;

        begin
            logic signed [WIDTH-1:0] v_default;
            v_default = dut.v_reg;

            // Reset both, pulse shifted instance
            rst_n = 1'b0;
            repeat (2) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);

            input_current_s = 16'sd256;
            @(negedge clk);
            en_s = 1'b1; en = 1'b0;
            @(negedge clk);
            en_s = 1'b0;

            begin
                logic signed [WIDTH-1:0] v_shifted;
                v_shifted = dut_shift.v_reg;
                // Shifted instance contribution should be 16× default
                check("T8 Input alignment - shifted = 16 * default",
                      v_shifted == (v_default <<< (FRAC_WIDTH - I_FRAC_SHIFT)));
            end
        end

        // ---- Summary ----
        $display("");
        $display("==========================");
        $display("  LIF NEURON FIXED TB");
        $display("  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt);
        $display("==========================");
        $finish;
    end

endmodule
