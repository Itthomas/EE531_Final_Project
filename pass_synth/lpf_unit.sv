module lpf_unit #(
    parameter int WIDTH = 16,
    parameter int FRAC_WIDTH = 8
)(
    input logic clk,
    input logic rst_n,
    input logic spike_in,
    output logic signed [WIDTH-1:0] y_out
);

    typedef logic signed [WIDTH+10-1:0] decay_t;
    typedef logic signed [(2*WIDTH)+2-1:0] accum_t; 

    logic [WIDTH-1:0] y_reg;
    logic [WIDTH-1:0] y_next;
    
    decay_t decay_x512, decay_x2, decay_x510;
    accum_t term_decay, term_input, y_next_pre;
    
    localparam logic [WIDTH-1:0] MAX_VAL = {1'b0, {(WIDTH-1){1'b1}}};
    localparam logic [WIDTH-1:0] MIN_VAL = '0;
    
    always_comb begin
        //decay
        decay_x512 = decay_t'($signed(y_reg)) <<< 9;
        decay_x2   = decay_t'($signed(y_reg)) <<< 1;
        decay_x510 = decay_x512 - decay_x2;
        term_decay = accum_t'($signed(decay_x510) >>> 9);
        
        //integrate and update
        term_input = spike_in ? (accum_t'(1) << FRAC_WIDTH) : accum_t'(0);
        y_next_pre = term_decay + term_input;
    
        //saturation logic
        if ($signed(y_next_pre) >= $signed(accum_t'(MAX_VAL)))
            y_next = MAX_VAL;
        else if ($signed(y_next_pre) <= $signed(accum_t'(MIN_VAL)))
            y_next = MIN_VAL;
        else
            y_next = y_next_pre[WIDTH-1:0];
            
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_reg <= 16'h0000;
            y_out <= 16'h0000;
        end else begin
            y_reg <= y_next;
            y_out <= y_next;
        end
    end

endmodule
