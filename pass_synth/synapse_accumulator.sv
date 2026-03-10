module synapse_accumulator #(
    parameter int NUM_SYNAPSES = 256,
    parameter int WEIGHT_WIDTH = 8,
    parameter int ACCUM_WIDTH  = 16,
    parameter logic signed [(WEIGHT_WIDTH*NUM_SYNAPSES)-1:0] WEIGHTS = '0
)(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              accum_rst,
    input  logic                              spike_valid,
    input  logic [$clog2(NUM_SYNAPSES)-1:0]   spike_addr,
    output logic signed [ACCUM_WIDTH-1:0]     accum_out
);

    // Saturation bounds
    localparam logic signed [ACCUM_WIDTH-1:0] MAX_VAL = {1'b0, {(ACCUM_WIDTH-1){1'b1}}};
    localparam logic signed [ACCUM_WIDTH-1:0] MIN_VAL = {1'b1, {(ACCUM_WIDTH-1){1'b0}}};

    logic signed [ACCUM_WIDTH-1:0] accum_reg;
    logic signed [ACCUM_WIDTH-1:0] next_accum;
    logic signed [ACCUM_WIDTH:0] accum_wide;
    
    logic signed [WEIGHT_WIDTH-1:0] current_weight;
    assign current_weight = $signed(WEIGHTS[WEIGHT_WIDTH*spike_addr +: WEIGHT_WIDTH]);

    // Weight lookup, saturating accumulation
    always_comb begin
        accum_wide = '0;
        next_accum = accum_reg;
        
        if (spike_valid) begin
            accum_wide = accum_reg + ACCUM_WIDTH'(current_weight);
            if (accum_wide > $signed({1'b0, MAX_VAL}))
                next_accum = MAX_VAL;
            else if (accum_wide < $signed({1'b1, MIN_VAL}))
                next_accum = MIN_VAL;
            else
                next_accum = accum_wide[ACCUM_WIDTH-1:0];
        end 
    end

    // State update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            accum_reg <= '0;
        else if (accum_rst)
            accum_reg <= '0;
        else
            accum_reg <= next_accum;
    end

    assign accum_out = accum_reg;

endmodule
