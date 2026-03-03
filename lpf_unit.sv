`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 08:02:18 PM
// Design Name: 
// Module Name: lpf_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*
'Leaky integrator' to convert spikes into continous activity level: Q8.8 integer
*/
module lpf_unit #(
    parameter int WIDTH = 16,
    parameter int FRAC_WIDTH = 8
)(
    input logic clk,
    input logic reset,
    input logic spike_in,
    output logic signed [WIDTH-1:0] y_out
);

    typedef logic signed [WIDTH-1:0] state_t;
    typedef logic signed [WIDTH+10-1:0] decay_t;
    typedef logic signed [(2*WIDTH)+2-1:0] accum_t; 

    state_t y_reg;
    
    decay_t decay_x512, decay_x2, decay_x510;
    accum_t term_decay, term_input, y_next_pre;
    
    localparam state_t MAX_VAL = {1'b0, {(WIDTH-1){1'b1}}};
    localparam state_t MIN_VAL = '0;
    
    always_comb begin
        //decay
        decay_x512 = decay_t'($signed(y_reg)) <<< 9;
        decay_x2   = decay_t'($signed(y_reg)) <<< 1;
        decay_x510 = decay_x512 - decay_x2;
        term_decay = accum_t'(decay_x510 >>> 9);
        
        //integrate and update
        term_input = spike_in ? (accum_t'(1) << FRAC_WIDTH) : '0;
        y_next_pre = term_decay + term_input;
    
        //saturation logic
        if (y_next_pre >= accum_t'(MAX_VAL))
            y_out = MAX_VAL;
        else if (y_next_pre <= accum_t'(MIN_VAL))
            y_out = MIN_VAL;
        else
            y_out = state_t'(y_next_pre[WIDTH-1:0]);
            
    end

    always_ff @(posedge clk or negedge reset) begin
        if (!reset)
            y_reg <= 16'h0000;
        else
            y_reg <= y_out;
    end

endmodule
