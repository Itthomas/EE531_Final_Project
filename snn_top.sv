// Top-level pipelined SNN module that integrates the delta modulator, synapse accumulators,
// LIF neurons, and output decoder. Downstream layers consume registered spike outputs from
// upstream layers on later timesteps, so NUM_TIMESTEPS includes pipeline fill and drain latency.

// Load weight definitions
import snn_weights_pkg::*;

module snn_top #(
    parameter int ECG_WIDTH          = 11,  // Bit width of input ECG samples. 11 for 2048 max value
    parameter int DM_STEP_SIZE       = 4,   // Step size for delta modulator (threshold for spiking)
    parameter int NUM_HIDDEN_LAYERS  = 4,
    parameter int NEURONS_PER_LAYER  = 8,
    parameter int NEURON_WIDTH       = 16,  // Bit widths for neuron state and computations.
    parameter int NEURON_FRAC_WIDTH  = 8,   // (reduce these if needed to fit synthesis constraints)
    parameter int CURRENT_WIDTH      = 16,
    parameter int CURRENT_FRAC_WIDTH = 1,
    parameter int WEIGHT_WIDTH       = 8,
    parameter int NUM_TIMESTEPS      = 10,  // Total inference timesteps, including pipeline fill and drain latency
    parameter logic signed [31:0] MATCH_THRESHOLD = 32'h0001_0000
)(
    input  logic                                clk,
    input  logic                                rst_n,
    input  logic [ECG_WIDTH-1:0]                ecg_in,
    input  logic                                inference_start,
    output logic                                inference_done,
    output logic                                match,
    output logic [DM_CHANNELS-1:0]              dm_spike_raster,
    output logic [NUM_HIDDEN_LAYERS*NEURONS_PER_LAYER-1:0] spike_raster,
    output logic signed [31:0]                  prediction,
    input  logic                                weight_en,
    input  logic [$clog2(NEURONS_PER_LAYER)-1:0] weight_addr,
    input  logic signed [NEURON_WIDTH-1:0]      weight_data
);

    localparam int NEURON_ADDR_WIDTH = $clog2(NEURONS_PER_LAYER);
    localparam int DM_CHANNELS       = 2;
    localparam int DM_ADDR_WIDTH     = $clog2(DM_CHANNELS);

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE, S_SAMPLE, S_PROCESS, S_UPDATE, S_OUTPUT, S_DONE
    } fsm_state_t;

    fsm_state_t state, state_next;
    logic [$clog2(NUM_TIMESTEPS)-1:0] timestep, timestep_next;
    logic neuron_en, timestep_rst, synapse_rst, output_start;

    // Delta modulator
    logic [1:0]           dm_spikes;
    logic [ECG_WIDTH-1:0] dm_reconstructed;

    delta_mod #(
        .DATA_WIDTH(ECG_WIDTH),
        .STEP_SIZE(DM_STEP_SIZE),
        .MAX_VAL((1 << ECG_WIDTH) - 1),
        .MIN_VAL(0)
    ) u_delta_mod (
        .clk       (clk),
        .rst_n     (rst_n),
        .ecg_in    (ecg_in),
        .dm_spike_out(dm_spikes),
        .signal    (dm_reconstructed)
    );

    assign dm_spike_raster = dm_spikes;

    // Inter-layer wiring
    logic [NEURONS_PER_LAYER-1:0] layer_spikes [0:NUM_HIDDEN_LAYERS-1];
    logic [NUM_HIDDEN_LAYERS-1:0] layer_aer_active;

    // Input AER (2 delta_mod channels)
    logic [DM_ADDR_WIDTH-1:0] input_aer_addr;
    logic                     input_aer_valid;

    aer_handler #(
        .NUM_NEURONS(DM_CHANNELS)
    ) u_input_aer (
        .clk       (clk),
        .rst_n     (rst_n),
        .step_rst  (timestep_rst),
        .spike_vec (dm_spikes),
        .aer_addr  (input_aer_addr),
        .aer_valid (input_aer_valid)
    );

    assign layer_aer_active[0] = input_aer_valid;

    // Layer 0: DM_CHANNELS synapses per neuron
    logic signed [CURRENT_WIDTH-1:0] layer0_current [0:NEURONS_PER_LAYER-1];

    genvar n;
    generate
        for (n = 0; n < NEURONS_PER_LAYER; n++) begin : gen_layer0_accum
            synapse_accumulator #(
                .NUM_SYNAPSES(DM_CHANNELS),
                .WEIGHT_WIDTH(WEIGHT_WIDTH),
                .ACCUM_WIDTH(CURRENT_WIDTH),
                .WEIGHTS(INPUT_WEIGHTS[n])
            ) u_accum (
                .clk        (clk),
                .rst_n      (rst_n),
                .accum_rst  (synapse_rst),
                .spike_valid(input_aer_valid),
                .spike_addr (input_aer_addr),
                .accum_out  (layer0_current[n])
            );
        end

        for (n = 0; n < NEURONS_PER_LAYER; n++) begin : gen_layer0_neuron
            lif_neuron_fixed #(
                .I_WIDTH(CURRENT_WIDTH),
                .I_FRAC_WIDTH(CURRENT_FRAC_WIDTH),
                .WIDTH(NEURON_WIDTH),
                .FRAC_WIDTH(NEURON_FRAC_WIDTH)
            ) u_neuron (
                .clk          (clk),
                .rst_n        (rst_n),
                .en           (neuron_en),
                .input_current(layer0_current[n]),
                .spike        (layer_spikes[0][n])
            );
        end
    endgenerate

    // Hidden layers 1..NUM_HIDDEN_LAYERS-1.
    // Each layer consumes the previous layer's registered spikes, creating a timestep pipeline.
    logic [NEURON_ADDR_WIDTH-1:0] hidden_aer_addr [1:NUM_HIDDEN_LAYERS-1];
    logic                         hidden_aer_valid [1:NUM_HIDDEN_LAYERS-1];
    logic signed [CURRENT_WIDTH-1:0] hidden_current [1:NUM_HIDDEN_LAYERS-1][0:NEURONS_PER_LAYER-1];

    generate
        for (genvar L = 1; L < NUM_HIDDEN_LAYERS; L++) begin : gen_hidden_layer
            aer_handler #(
                .NUM_NEURONS(NEURONS_PER_LAYER)
            ) u_aer (
                .clk       (clk),
                .rst_n     (rst_n),
                .step_rst  (timestep_rst),
                .spike_vec (layer_spikes[L-1]),
                .aer_addr  (hidden_aer_addr[L]),
                .aer_valid (hidden_aer_valid[L])
            );

            assign layer_aer_active[L] = hidden_aer_valid[L];

            for (genvar N = 0; N < NEURONS_PER_LAYER; N++) begin : gen_accum
                synapse_accumulator #(
                    .NUM_SYNAPSES(NEURONS_PER_LAYER),
                    .WEIGHT_WIDTH(WEIGHT_WIDTH),
                    .ACCUM_WIDTH(CURRENT_WIDTH),
                    .WEIGHTS(HIDDEN_WEIGHTS[L-1][N])
                ) u_accum (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .accum_rst  (synapse_rst),
                    .spike_valid(hidden_aer_valid[L]),
                    .spike_addr (hidden_aer_addr[L]),
                    .accum_out  (hidden_current[L][N])
                );
            end

            for (genvar N = 0; N < NEURONS_PER_LAYER; N++) begin : gen_neuron
                lif_neuron_fixed #(
                    .I_WIDTH(CURRENT_WIDTH),
                    .I_FRAC_WIDTH(CURRENT_FRAC_WIDTH),
                    .WIDTH(NEURON_WIDTH),
                    .FRAC_WIDTH(NEURON_FRAC_WIDTH)
                ) u_neuron (
                    .clk          (clk),
                    .rst_n        (rst_n),
                    .en           (neuron_en),
                    .input_current(hidden_current[L][N]),
                    .spike        (layer_spikes[L][N])
                );
            end
        end
    endgenerate

    // Output decoder
    logic output_done;

    output_decoder #(
        .NUM_NEURONS(NEURONS_PER_LAYER),
        .WIDTH(NEURON_WIDTH),
        .FRAC_WIDTH(NEURON_FRAC_WIDTH),
        .ADDR_WIDTH(NEURON_ADDR_WIDTH),
        .THRESHOLD(MATCH_THRESHOLD)
    ) u_output_decoder (
        .clk        (clk),
        .rst_n      (rst_n),
        .spike_in   (layer_spikes[NUM_HIDDEN_LAYERS-1]),
        .weight_en  (weight_en),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .start      (output_start),
        .done       (output_done),
        .prediction (prediction),
        .match      (match)
    );

    generate
        for (genvar L = 0; L < NUM_HIDDEN_LAYERS; L++) begin : gen_spike_raster
            assign spike_raster[(L+1)*NEURONS_PER_LAYER-1 -: NEURONS_PER_LAYER] = layer_spikes[L];
        end
    endgenerate

    // FSM
    logic all_aer_done;
    assign all_aer_done = (layer_aer_active == '0);

    always_comb begin
        state_next     = state;
        timestep_next  = timestep;
        neuron_en      = 1'b0;
        timestep_rst   = 1'b0;
        synapse_rst    = 1'b0;
        output_start   = 1'b0;
        inference_done = 1'b0;

        case (state)
            S_IDLE:
                // Wait for inference_start signal
                if (inference_start) begin
                    timestep_next = '0;
                    state_next    = S_SAMPLE;
                end

            S_SAMPLE: begin
                // Clear accumulators, reset AER state, and kick off the decoder pass for this timestep
                timestep_rst = 1'b1;
                synapse_rst  = 1'b1;
                output_start = 1'b1;
                state_next   = S_PROCESS;
            end

            S_PROCESS:
                // Wait for all AER events to be processed and output to be done
                if (all_aer_done && output_done) state_next = S_UPDATE;

            S_UPDATE: begin
                // Enable neurons to update their states based on the current inputs
                neuron_en     = 1'b1;
                timestep_next = timestep + 1;
                if (timestep + 1 >= NUM_TIMESTEPS)
                    state_next = S_OUTPUT;
                else
                    state_next = S_SAMPLE;
            end

            S_OUTPUT: begin
                // Start final output decoding after the pipeline run completes
                output_start = 1'b1;
                if (output_done) state_next = S_DONE;
            end

            S_DONE: begin
                // Inference complete, hold final prediction and signal done
                inference_done = 1'b1;
                state_next     = S_IDLE;
            end

            default: state_next = S_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            timestep <= '0;
        end else begin
            state    <= state_next;
            timestep <= timestep_next;
        end
    end

endmodule