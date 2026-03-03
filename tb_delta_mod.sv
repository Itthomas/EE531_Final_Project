`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2026 11:35:24 AM
// Design Name: 
// Module Name: tb_delta_mod
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


module tb_delta_mod();

    parameter int DATA_WIDTH = 11;
    
    logic clk;
    logic reset;
    logic [DATA_WIDTH-1:0] ecg_sample;
    logic [1:0] spike_out;
    logic [DATA_WIDTH-1:0] signal;
    
    integer infile, outfile;
    integer status;
    integer sample_count = 0;
    
    delta_mod dm_dut(
        .clk(clk),
        .dm_reset(reset),
        .ecg_in(ecg_sample),
        .dm_spike_out(spike_out),
        .signal(signal)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        reset = 1;
        
        
        //DM
        #10
        ecg_sample = DATA_WIDTH'(0);
        
        //File
        infile = $fopen("ecg_input_100.txt", "r");
        if (infile == 0) begin
            $display("Failed to open input file");
            $finish;
        end
        
        outfile = $fopen("dm_output.txt", "w");
        if (outfile == 0) begin
            $display("Failed to open output file");
            $finish;
        end
        
        status = $fscanf(infile, "%d\n", ecg_sample);
        @(posedge clk);

        reset = 0;
        #10;
        
        //Modulator
        while (!$feof(infile)) begin
            sample_count = sample_count + 1;
            status = $fscanf(infile, "%d\n", ecg_sample);
            
            if (ecg_sample > 2047 || ecg_sample < 0) begin
                $display("Sample #%0d out-of-range: %d", sample_count, ecg_sample);
            end
            repeat(1)
                @(posedge clk);
//            $fwrite(outfile, "t=%0t, sample=%0d, dm_out=%0d\n",
//                    $time, ecg_sample, dm_out);        
        end

        $finish;
    end
    
endmodule
