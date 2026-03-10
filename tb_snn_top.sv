`timescale 1ns / 1ps

module tb_snn_top;

    localparam int ECG_WIDTH          = 11;
    parameter int DM_STEP_SIZE        = 2;
    localparam int NUM_HIDDEN_LAYERS  = 4;
    localparam int NEURONS_PER_LAYER  = 8;
    localparam int NEURON_WIDTH       = 16;
    localparam int NUM_TIMESTEPS      = 10;
    localparam int NUM_SAMPLES        = 1000;
    localparam int CLK_PERIOD         = 10;
    localparam string ECG_FILE        = "z:/Coursework/EE531/Final/ecg_input_100.txt";
    localparam string WEIGHT_FILE     = "z:/Coursework/EE531/Final/output_weights.txt";
    localparam string RASTER_FILE     = "z:/Coursework/EE531/Final/spike_raster_log.txt";

    logic clk;
    logic rst_n;
    logic [ECG_WIDTH-1:0] ecg_in;
    logic inference_start;
    logic inference_done;
    logic match;
    logic [1:0] dm_spike_raster;
    logic [NUM_HIDDEN_LAYERS*NEURONS_PER_LAYER-1:0] spike_raster;
    logic signed [31:0] prediction;
    logic weight_en;
    logic [$clog2(NEURONS_PER_LAYER)-1:0] weight_addr;
    logic signed [NEURON_WIDTH-1:0] weight_data;

    logic [ECG_WIDTH-1:0] ecg_samples [0:NUM_SAMPLES-1];
    logic signed [NEURON_WIDTH-1:0] output_weights [0:NEURONS_PER_LAYER-1];
    int raster_fd;

    snn_top #(
        .ECG_WIDTH(ECG_WIDTH),
        .NUM_HIDDEN_LAYERS(NUM_HIDDEN_LAYERS),
        .NEURONS_PER_LAYER(NEURONS_PER_LAYER),
        .NEURON_WIDTH(NEURON_WIDTH),
        .NUM_TIMESTEPS(NUM_TIMESTEPS),
        .DM_STEP_SIZE(DM_STEP_SIZE)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .ecg_in         (ecg_in),
        .inference_start(inference_start),
        .inference_done (inference_done),
        .match          (match),
        .dm_spike_raster(dm_spike_raster),
        .spike_raster   (spike_raster),
        .prediction     (prediction),
        .weight_en      (weight_en),
        .weight_addr    (weight_addr),
        .weight_data    (weight_data)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    function automatic string state_name(input logic [2:0] state_bits);
        case (state_bits)
            3'd0: state_name = "S_IDLE";
            3'd1: state_name = "S_SAMPLE";
            3'd2: state_name = "S_PROCESS";
            3'd3: state_name = "S_UPDATE";
            3'd4: state_name = "S_OUTPUT";
            3'd5: state_name = "S_DONE";
            default: state_name = "UNKNOWN";
        endcase
    endfunction

    task automatic load_ecg_samples();
        int ecg_fd;
        int sample_value;
        int status;
        ecg_fd = $fopen(ECG_FILE, "r");
        if (ecg_fd == 0)
            $fatal(1, "Failed to open ECG file: %s", ECG_FILE);

        for (int idx = 0; idx < NUM_SAMPLES; idx++) begin
            status = $fscanf(ecg_fd, "%d\n", sample_value);
            if (status != 1)
                $fatal(1, "Failed to read ECG sample %0d from %s", idx, ECG_FILE);
            ecg_samples[idx] = ECG_WIDTH'(sample_value);
        end

        $fclose(ecg_fd);
    endtask

    task automatic read_output_weights();
        int weight_fd;
        int weight_value;
        int status;
        weight_fd = $fopen(WEIGHT_FILE, "r");
        if (weight_fd == 0)
            $fatal(1, "Failed to open weight file: %s", WEIGHT_FILE);

        for (int idx = 0; idx < NEURONS_PER_LAYER; idx++) begin
            status = $fscanf(weight_fd, "%d\n", weight_value);
            if (status != 1)
                $fatal(1, "Failed to read output weight %0d from %s", idx, WEIGHT_FILE);
            output_weights[idx] = NEURON_WIDTH'(weight_value);
        end

        $fclose(weight_fd);
    endtask

    task automatic program_output_weights();
        for (int idx = 0; idx < NEURONS_PER_LAYER; idx++) begin
            @(posedge clk);
            weight_en   <= 1'b1;
            weight_addr <= idx[$clog2(NEURONS_PER_LAYER)-1:0];
            weight_data <= output_weights[idx];
        end
        @(posedge clk);
        weight_en   <= 1'b0;
        weight_addr <= '0;
        weight_data <= '0;
    endtask

    task automatic print_spike_raster(
        input int sample_idx,
        input logic [1:0] dm_spike_window
    );
        $display(
            "sample=%0d state=%s timestep=%0d dm=%b L0=%b L1=%b L2=%b L3=%b pred=%0d match=%0b",
            sample_idx,
            state_name(dut.state),
            dut.timestep,
            dm_spike_window,
            dut.layer_spikes[0],
            dut.layer_spikes[1],
            dut.layer_spikes[2],
            dut.layer_spikes[3],
            prediction,
            match
        );
        $fwrite(
            raster_fd,
            "sample=%0d state=%s timestep=%0d dm=%b L0=%b L1=%b L2=%b L3=%b pred=%0d match=%0b\n",
            sample_idx,
            state_name(dut.state),
            dut.timestep,
            dm_spike_window,
            dut.layer_spikes[0],
            dut.layer_spikes[1],
            dut.layer_spikes[2],
            dut.layer_spikes[3],
            prediction,
            match
        );
    endtask

    task automatic run_one_inference(input int sample_idx);
        logic [1:0] dm_spike_window;

        ecg_in = ecg_samples[sample_idx];
        dm_spike_window = '0;

        @(posedge clk);
        inference_start <= 1'b1;
        @(posedge clk);
        inference_start <= 1'b0;

        while (!inference_done) begin
            @(posedge clk);
            #1;
            dm_spike_window |= dm_spike_raster;
            if ((dut.state == 3'd3) || (dut.state == 3'd5)) begin
                print_spike_raster(sample_idx, dm_spike_window);
                dm_spike_window = '0;
            end
        end

        $display(
            "DONE sample=%0d ecg=%0d pred=%0d match=%0b final_state=%s",
            sample_idx,
            ecg_samples[sample_idx],
            prediction,
            match,
            state_name(dut.state)
        );
    endtask

    initial begin
        clk             = 1'b0;
        rst_n           = 1'b0;
        ecg_in          = '0;
        inference_start = 1'b0;
        weight_en       = 1'b0;
        weight_addr     = '0;
        weight_data     = '0;

        load_ecg_samples();
        read_output_weights();
        raster_fd = $fopen(RASTER_FILE, "w");
        if (raster_fd == 0)
            $fatal(1, "Failed to open raster log file: %s", RASTER_FILE);
        $fwrite(raster_fd, "# spike raster log\n");
        $fwrite(raster_fd, "# sample state timestep dm L0 L1 L2 L3 prediction match\n");

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        $display("Loaded %0d ECG samples from %s", NUM_SAMPLES, ECG_FILE);
        $display("Loaded %0d output weights from %s", NEURONS_PER_LAYER, WEIGHT_FILE);
        $display("Saving spike raster log to %s", RASTER_FILE);

        program_output_weights();
        $display("Output decoder weights programmed");

        for (int sample_idx = 0; sample_idx < NUM_SAMPLES; sample_idx++) begin
            run_one_inference(sample_idx);
        end

        $display("Completed %0d top-level SNN smoke-test inferences", NUM_SAMPLES);
        $fclose(raster_fd);
        #20;
        $finish;
    end

endmodule