`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 01:15:53 PM
// Design Name: 
// Module Name: tb_output_decoder
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


module tb_output_decoder();

    //params
    localparam int NUM_NEURONS = 16;
    localparam int WIDTH = 16;
    localparam int FRAC_WIDTH = 8;
    localparam int ADDR_WIDTH = 4;
    
    //I/O
    logic clk;
    logic reset;
    logic [NUM_NEURONS-1:0] spike_in;
    logic weight_en;
    logic [ADDR_WIDTH-1:0] weight_addr;
    logic signed [WIDTH-1:0] weight_data;
    logic start;
    logic done;
    logic signed [31:0] prediction;
    
    //DUT
    output_decoder #(
        .NUM_NEURONS(NUM_NEURONS),
        .WIDTH(WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .spike_in(spike_in),
        .weight_en(weight_en),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .start(start),
        .done(done),
        .prediction(prediction)
    );
    
    //generate clock
    always #5 clk = ~clk;
    
    task load_weight(input [ADDR_WIDTH-1:0] addr, input [WIDTH-1:0] data);
        @(posedge clk);
        weight_en = 1;
        weight_addr = addr;
        weight_data = data;
        @(posedge clk);
        weight_en = 0;
    endtask
    
    initial begin
        clk = 0;
        reset = 0;
        spike_in = '0;
        weight_en = 0;
        weight_addr = 0;
        weight_data = 0;
        start = 0;
        
        repeat(5) @(posedge clk);
        reset = 1;
        $display("--RESET--");
        
        //init weights to 0
        for (int i = 0; i < NUM_NEURONS; i++) begin
            load_weight(i, 16'h0000); 
        end
        
        //load weights
        load_weight(4'b0000, 16'sh0200);  //2
        load_weight(4'b0001, 16'shFF00);  //-1
        load_weight(4'd3, 16'sh0040);  //0.25
        load_weight(4'd6, 16'shFF80);  //-0.5
        load_weight(4'd10, 16'sh7FFF);  //127.99
        load_weight(4'd12, 16'sh8000);  //-128.0
        load_weight(4'd15, 16'sh0001);  //0.0039
        $display("--WEIGHTS LOADED--");
        
        //large values decay longer
        repeat(10) begin
            @(posedge clk);
            spike_in[10] = 1'b1;
            spike_in[12] = 1'b1;
        end
        spike_in[10] = 1'b0;
        spike_in[12] = 1'b0;
        
        //other values
        repeat(20) begin
            @(posedge clk);
            spike_in[0] = 1'b1;
            spike_in[1] = 1'b1;
            spike_in[3] = 1'b1;
            spike_in[6] = 1'b1;
            spike_in[15] = 1'b1;
        end
        spike_in[0] = 1'b0;
        spike_in[1] = 1'b0;
        spike_in[3] = 1'b0;
        spike_in[6] = 1'b0;
        spike_in[15] = 1'b0;
        
        //decode
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(done);
        
        //check
        $display("--- Decoding Finished ---");
        $display("Neuron 0 LPF: %d, Weight: %d", dut.lpf_outputs[0], dut.weights[0]);
        $display("Neuron 1 LPF: %d, Weight: %d", dut.lpf_outputs[1], dut.weights[1]);
        $display("Neuron 3 LPF: %d, Weight: %d", dut.lpf_outputs[3], dut.weights[3]);
        $display("Neuron 6 LPF: %d, Weight: %d", dut.lpf_outputs[6], dut.weights[6]);
        $display("Neuron 10 LPF: %d, Weight: %d", dut.lpf_outputs[10], dut.weights[10]);
        $display("Neuron 12 LPF: %d, Weight: %d", dut.lpf_outputs[12], dut.weights[12]);
        $display("Neuron 15 LPF: %d, Weight: %d", dut.lpf_outputs[15], dut.weights[15]);
        $display("Raw Accumulator: %h", dut.accum);
        $display("Final Prediction (Hex): %h", prediction);
        $display("Final Prediction (Decimal Fixed-Point): %f", $itor(prediction) / (2**(FRAC_WIDTH*2)));
        
        #100;
        $finish;
        
    end
    
endmodule
