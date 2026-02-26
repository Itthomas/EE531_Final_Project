module lif_neuron_optimized #(
    // Bit-width parameters
    parameter int I_WIDTH      = 8,
    parameter int I_FRAC_WIDTH = 4,
    parameter int WIDTH        = 16,
    parameter int FRAC_WIDTH   = 8,

    parameter logic signed [WIDTH-1:0] A_OPT   = 232,    // Decay factor (Q8.8)
    parameter logic signed [WIDTH-1:0] B_OPT   = 256,    // Input weight (Q8.8)
    parameter logic signed [WIDTH-1:0] V_RESET = -20480  // Reset voltage (Q8.8)
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic signed [I_WIDTH-1:0] input_current,
    output logic                      spike
);

    // Width constants and types
    localparam int MULT_WIDTH  = 2 * WIDTH;
    localparam int ACCUM_WIDTH = MULT_WIDTH + 2;

    typedef logic signed [WIDTH-1:0]       state_t;
    typedef logic signed [MULT_WIDTH-1:0]  mult_t;
    typedef logic signed [ACCUM_WIDTH-1:0] accum_t;

    localparam state_t MAX_VAL = {1'b0, {(WIDTH-1){1'b1}}};
    localparam state_t MIN_VAL = {1'b1, {(WIDTH-1){1'b0}}};

    state_t v_reg, v_next;
    logic   spike_next;

    // Datapath
    mult_t  prod_decay, prod_input;
    accum_t term_decay, term_input, v_next_pre;

    always_comb begin
        // Decay term: v * A, realigned to FRAC_WIDTH
        prod_decay = $signed(v_reg) * $signed(A_OPT);
        term_decay = accum_t'(prod_decay >>> FRAC_WIDTH);

        // Input term: B * I, realigned to FRAC_WIDTH
        prod_input = $signed(B_OPT) * $signed(input_current);
        term_input = accum_t'(prod_input >>> I_FRAC_WIDTH);

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