`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 08:02:18 PM
// Design Name: 
// Module Name: output_decoder
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
Takes last layer of 1-bit spikes and turns it into a single Q8.8 16-bit int value
1. LPF Bank to convert each neuron into a continous activity level
2. FSM Regression Engine to cycle through each neuron's level, multiply by weight,
and accumulate value into classification
*/

module output_decoder#(
    parameter int NUM_NEURONS = 16,
    parameter int WIDTH = 16,
    parameter int FRAC_WIDTH = 8,
    parameter int ADDR_WIDTH = 4,
    parameter logic signed [31:0] THRESHOLD = 32'h0001_0000
)(
    input logic clk,
    input logic rst_n,
    
    input logic [NUM_NEURONS-1:0] spike_in,
    
    input logic weight_en,
    input logic [ADDR_WIDTH-1:0] weight_addr,
    input logic signed [WIDTH-1:0] weight_data,
    
    input logic start,
    output logic done,
    output logic signed [31:0] prediction,
    output logic match
    
);
    
    localparam int GUARD_BITS = $clog2(NUM_NEURONS);
    localparam int ACCUM_WIDTH = (2 * WIDTH) + GUARD_BITS;
    //filter bank
    logic signed [WIDTH-1:0] lpf_outputs [NUM_NEURONS];

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i++) begin : bank
            lpf_unit #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) lpf_inst (
                .clk(clk), .rst_n(rst_n), .spike_in(spike_in[i]), .y_out(lpf_outputs[i])
            );
        end
    endgenerate

    //weight memory
    logic signed [WIDTH-1:0] weights [NUM_NEURONS];
    always_ff @(posedge clk) begin
        if (weight_en)
            weights[weight_addr] <= weight_data;
    end
    
    typedef enum logic [1:0] {IDLE, COMPUTE, FINISH} out_dec_state_t;
    out_dec_state_t state;
    
    logic [ADDR_WIDTH-1:0] ptr;
    logic signed [ACCUM_WIDTH-1:0] accum;  
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            prediction <= '0;
            done <= '0;
            match <= '0;
            accum <= '0;
            ptr <= '0;
        end else begin
            case (state)
                IDLE: begin
                    done <= '0;
                    //match <= '0;
                    if (start) begin
                        ptr <= '0;
                        accum <= '0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    accum <= accum + ($signed({1'b0, lpf_outputs[ptr]}) * weights[ptr]);
                    if (ptr == (ADDR_WIDTH'(NUM_NEURONS - 1)))
                        state <= FINISH;
                    else
                        ptr <= ptr + 1;
                end
                
                FINISH: begin
                    prediction <= accum[31:0];
                    
                    if ($signed(accum[31:0]) > THRESHOLD)
                        match <= 1'b1;
                    else
                        match <= 1'b0;
                    
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
