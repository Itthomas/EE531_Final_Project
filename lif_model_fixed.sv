// LIF neuron model with fixed parameters, aggressively optimized for resource usage (no multipliers)

module lif_neuron_fixed #(
    // Bit-width parameters
    parameter int I_WIDTH      = 8,
    parameter int I_FRAC_WIDTH = 4,
    parameter int WIDTH        = 16,
    parameter int FRAC_WIDTH   = 8
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic signed [I_WIDTH-1:0] input_current,
    output logic                      spike
);

    // Width constants and types
    localparam int ACCUM_WIDTH = 2 * WIDTH + 2;
    localparam int DECAY_WIDTH = WIDTH + 10;

    typedef logic signed [WIDTH-1:0]       state_t;
    typedef logic signed [ACCUM_WIDTH-1:0] accum_t;
    typedef logic signed [DECAY_WIDTH-1:0] decay_t;

    // Reset voltage: midpoint of the negative range
    localparam state_t V_RESET = state_t'($signed({1'b1, {(WIDTH-1){1'b0}}}) >>> 1); // -2^(WIDTH-2)

    localparam state_t MAX_VAL = {1'b0, {(WIDTH-1){1'b1}}};
    localparam state_t MIN_VAL = {1'b1, {(WIDTH-1){1'b0}}};

    state_t v_reg, v_next;
    logic   spike_next;

    // Datapath
    accum_t term_decay, term_input, v_next_pre;
    decay_t decay_x512, decay_x2, decay_x510;

    always_comb begin
        // Decay: v * 510/512 ≈ 0.996, using (512 - 2) = 1 shift + 1 sub
        decay_x512 = decay_t'($signed(v_reg)) <<< 9;
        decay_x2   = decay_t'($signed(v_reg)) <<< 1;
        decay_x510 = decay_x512 - decay_x2;
        term_decay = accum_t'(decay_x510 >>> 9);

        // Input aligned to FRAC_WIDTH fractional bits (B = 1, skip multiply)
        term_input = accum_t'($signed(input_current)) <<< (FRAC_WIDTH - I_FRAC_WIDTH);

        // Accumulate
        v_next_pre = term_decay + term_input;

        // Saturate and spike detection
        if (v_next_pre >= accum_t'(MAX_VAL)) begin
            v_next     = V_RESET;
            spike_next = 1'b1;
        end else if (v_next_pre <= accum_t'(MIN_VAL)) begin
            v_next     = MIN_VAL;
            spike_next = 1'b0;
        end else begin
            v_next     = state_t'(v_next_pre[WIDTH-1:0]);
            spike_next = 1'b0;
        end
    end

    // State update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_reg <= '0;
            spike <= 1'b0;
        end else begin
            v_reg <= v_next;
            spike <= spike_next;
        end
    end

endmodule