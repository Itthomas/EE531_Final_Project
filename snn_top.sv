// Top-level SNN
// ecg_in → delta_mod → [layer 0..N-1 (accum + neuron + AER)] → output_decoder → prediction
// Load output decoder weights via weight_en/addr/data before pulsing inference_start.
//
// Section map:
//   Parameters & ports       18-40
//   Locals & FSM types       42-53
//   Delta modulator           54-69
//   Inter-layer wiring        71-73
//   Input AER handler         75-91
//   Layer 0 (accum + neuron)  92-128
//   Hidden layers 1..N-1     129-181
//   Output decoder            182-200
//   FSM logic                 202-262

import snn_weights_pkg::*;

module snn_top #(
    parameter int DATA_WIDTH       = 11,
    parameter int STEP_SIZE        = 4,
    parameter int NUM_HIDDEN_LAYERS = 4,
    parameter int LAYER_SIZE       = 8,
    parameter int WIDTH            = 16,
    parameter int FRAC_WIDTH       = 8,
    parameter int I_WIDTH          = 16,
    parameter int I_FRAC_WIDTH     = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int NUM_TIMESTEPS    = 100
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic [DATA_WIDTH-1:0]     ecg_in,
    input  logic                      inference_start,
    output logic                      inference_done,
    output logic signed [31:0]        prediction,
    input  logic                      weight_en,
    input  logic [$clog2(LAYER_SIZE)-1:0] weight_addr,
    input  logic signed [WIDTH-1:0]   weight_data
);

    localparam int ADDR_WIDTH    = $clog2(LAYER_SIZE);
    localparam int DM_INPUTS     = 2;
    localparam int DM_ADDR_WIDTH = $clog2(DM_INPUTS);

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE, S_SAMPLE, S_PROCESS, S_UPDATE, S_OUTPUT, S_DONE
    } fsm_state_t;

    fsm_state_t state, state_next;
    logic [$clog2(NUM_TIMESTEPS)-1:0] step_cnt, step_cnt_next;
    logic neuron_en, step_rst, accum_rst, output_start;

    // Delta modulator
    logic [1:0]            dm_spike_out;
    logic [DATA_WIDTH-1:0] dm_signal;

    delta_mod #(
        .DATA_WIDTH(DATA_WIDTH),
        .STEP_SIZE(STEP_SIZE),
        .MAX_VAL((1 << DATA_WIDTH) - 1),
        .MIN_VAL(0)
    ) u_delta_mod (
        .clk       (clk),
        .dm_reset  (~rst_n),
        .ecg_in    (ecg_in),
        .dm_spike_out(dm_spike_out),
        .signal    (dm_signal)
    );

    // Inter-layer wiring
    logic [LAYER_SIZE-1:0] layer_spike [0:NUM_HIDDEN_LAYERS-1];
    logic [NUM_HIDDEN_LAYERS-1:0] aer_valid;

    // Input AER (2 delta_mod channels)
    logic [DM_ADDR_WIDTH-1:0] input_aer_addr;
    logic                     input_aer_valid;

    aer_handler #(
        .NUM_NEURONS(DM_INPUTS)
    ) u_input_aer (
        .clk       (clk),
        .rst_n     (rst_n),
        .step_rst  (step_rst),
        .spike_vec (dm_spike_out),
        .aer_addr  (input_aer_addr),
        .aer_valid (input_aer_valid)
    );

    assign aer_valid[0] = input_aer_valid;

    // Layer 0: 2 synapses per neuron
    logic signed [I_WIDTH-1:0] layer0_accum [0:LAYER_SIZE-1];

    genvar n;
    generate
        for (n = 0; n < LAYER_SIZE; n++) begin : gen_layer0_accum
            synapse_accumulator #(
                .NUM_SYNAPSES(DM_INPUTS),
                .WEIGHT_WIDTH(WEIGHT_WIDTH),
                .ACCUM_WIDTH(I_WIDTH),
                .WEIGHTS(INPUT_WEIGHTS[n])
            ) u_accum (
                .clk        (clk),
                .rst_n      (rst_n),
                .accum_rst  (accum_rst),
                .spike_valid(input_aer_valid),
                .spike_addr (input_aer_addr),
                .accum_out  (layer0_accum[n])
            );
        end

        for (n = 0; n < LAYER_SIZE; n++) begin : gen_layer0_neuron
            lif_neuron_fixed #(
                .I_WIDTH(I_WIDTH),
                .I_FRAC_WIDTH(I_FRAC_WIDTH),
                .WIDTH(WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) u_neuron (
                .clk          (clk),
                .rst_n        (rst_n),
                .en           (neuron_en),
                .input_current(layer0_accum[n]),
                .spike        (layer_spike[0][n])
            );
        end
    endgenerate

    // Hidden layers 1..NUM_HIDDEN_LAYERS-1
    logic [ADDR_WIDTH-1:0] hidden_aer_addr [1:NUM_HIDDEN_LAYERS-1];
    logic                  hidden_aer_valid [1:NUM_HIDDEN_LAYERS-1];
    logic signed [I_WIDTH-1:0] hidden_accum [1:NUM_HIDDEN_LAYERS-1][0:LAYER_SIZE-1];

    generate
        for (genvar L = 1; L < NUM_HIDDEN_LAYERS; L++) begin : gen_hidden_layer
            aer_handler #(
                .NUM_NEURONS(LAYER_SIZE)
            ) u_aer (
                .clk       (clk),
                .rst_n     (rst_n),
                .step_rst  (step_rst),
                .spike_vec (layer_spike[L-1]),
                .aer_addr  (hidden_aer_addr[L]),
                .aer_valid (hidden_aer_valid[L])
            );

            assign aer_valid[L] = hidden_aer_valid[L];

            for (genvar N = 0; N < LAYER_SIZE; N++) begin : gen_accum
                synapse_accumulator #(
                    .NUM_SYNAPSES(LAYER_SIZE),
                    .WEIGHT_WIDTH(WEIGHT_WIDTH),
                    .ACCUM_WIDTH(I_WIDTH),
                    .WEIGHTS(HIDDEN_WEIGHTS[L-1][N])
                ) u_accum (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .accum_rst  (accum_rst),
                    .spike_valid(hidden_aer_valid[L]),
                    .spike_addr (hidden_aer_addr[L]),
                    .accum_out  (hidden_accum[L][N])
                );
            end

            for (genvar N = 0; N < LAYER_SIZE; N++) begin : gen_neuron
                lif_neuron_fixed #(
                    .I_WIDTH(I_WIDTH),
                    .I_FRAC_WIDTH(I_FRAC_WIDTH),
                    .WIDTH(WIDTH),
                    .FRAC_WIDTH(FRAC_WIDTH)
                ) u_neuron (
                    .clk          (clk),
                    .rst_n        (rst_n),
                    .en           (neuron_en),
                    .input_current(hidden_accum[L][N]),
                    .spike        (layer_spike[L][N])
                );
            end
        end
    endgenerate

    // Output decoder
    logic output_done;

    output_decoder #(
        .NUM_NEURONS(LAYER_SIZE),
        .WIDTH(WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_output_decoder (
        .clk        (clk),
        .reset      (rst_n),
        .spike_in   (layer_spike[NUM_HIDDEN_LAYERS-1]),
        .weight_en  (weight_en),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .start      (output_start),
        .done       (output_done),
        .prediction (prediction)
    );

    // FSM
    logic all_aer_done;
    assign all_aer_done = (aer_valid == '0);

    always_comb begin
        state_next     = state;
        step_cnt_next  = step_cnt;
        neuron_en      = 1'b0;
        step_rst       = 1'b0;
        accum_rst      = 1'b0;
        output_start   = 1'b0;
        inference_done = 1'b0;

        case (state)
            S_IDLE:
                if (inference_start) state_next = S_SAMPLE;

            S_SAMPLE: begin
                step_rst     = 1'b1;
                accum_rst    = 1'b1;
                output_start = 1'b1;
                state_next   = S_PROCESS;
            end

            S_PROCESS:
                if (all_aer_done && output_done) state_next = S_UPDATE;

            S_UPDATE: begin
                neuron_en     = 1'b1;
                step_cnt_next = step_cnt + 1;
                if (step_cnt + 1 >= NUM_TIMESTEPS)
                    state_next = S_OUTPUT;
                else
                    state_next = S_SAMPLE;
            end

            S_OUTPUT: begin
                output_start = 1'b1;
                if (output_done) state_next = S_DONE;
            end

            S_DONE: begin
                inference_done = 1'b1;
                state_next     = S_IDLE;
            end

            default: state_next = S_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            step_cnt <= '0;
        end else begin
            state    <= state_next;
            step_cnt <= step_cnt_next;
        end
    end

endmodule