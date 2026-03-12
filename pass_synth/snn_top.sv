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
    input  logic                                        clk,
    input  logic                                        rst_n,
    input  logic [ECG_WIDTH-1:0]                        ecg_in,
    input  logic                                        inference_start,
    output logic                                        inference_done,
    output logic                                        match,
    output logic [1:0]                                  dm_spike_raster, //DM_CHANNELS(2)-1 to 1
    output logic [NUM_HIDDEN_LAYERS*NEURONS_PER_LAYER-1:0] spike_raster,
    output logic signed [31:0]                          prediction,
    input  logic                                        weight_en,
    input  logic [$clog2(NEURONS_PER_LAYER)-1:0]        weight_addr,
    input  logic signed [NEURON_WIDTH-1:0]              weight_data
);



// FLAT - Reordered for i*8 indexing
    // The list starts with Neuron 7 Synapse 1 and ends with Neuron 0 Synapse 0 (Bit 0)
    localparam logic [127:0] INPUT_WEIGHTS_FLAT = {
        8'sd86,  -8'sd128, // N7 [S1, S0]
        -8'sd16,  8'sd112, // N6
        8'sd104,  8'sd70,  // N5
        8'sd112, -8'sd88,  // N4
        -8'sd86,  8'sd92,  // N3
        8'sd80,   8'sd98,  // N2
        8'sd74,   8'sd120, // N1
        -8'sd94,  8'sd96   // N0 [S1, S0] -> Bits [15:0]
    };
        
    // Layer 1: 512 bits 
    // Format: { N7[S7...S0], N6[S7...S0], ..., N0[S7...S0] }
    localparam logic [511:0] L1_WEIGHTS = {
        -8'sd32,  8'sd56,  8'sd96, -8'sd24,  8'sd48,  8'sd40,  8'sd64,  8'sd16,  // N7 [S7...S0]
         8'sd20,  8'sd110, 8'sd18,  8'sd80,  8'sd56,  8'sd84,  8'sd102, 8'sd52,  // N6
         8'sd80,  8'sd40, -8'sd88,  8'sd48,  8'sd32,  8'sd104, 8'sd16,  8'sd56,  // N5
         8'sd16,  8'sd64,  8'sd24,  8'sd40,  8'sd88,  8'sd8,   8'sd48,  8'sd72,  // N4
         8'sd64,  8'sd8,   8'sd32,  8'sd112, -8'sd80, 8'sd40,  8'sd56,  8'sd24,  // N3
         8'sd48,  8'sd24,  8'sd72,  8'sd16,  8'sd64,  8'sd96,  8'sd32,  8'sd48,  // N2
         8'sd8,   8'sd88,  8'sd56,  8'sd24,  8'sd40,  8'sd16,  8'sd80,  8'sd64,  // N1
         8'sd48,  8'sd16,  8'sd32,  8'sd72,  8'sd8,   8'sd56, -8'sd24,  8'sd40   // N0 [S7...S0]
    };

    // Layer 2: 512 bits
    localparam logic [511:0] L2_WEIGHTS = {
        -8'sd56,  8'sd64,  8'sd88, -8'sd16,  8'sd24,  8'sd48,  8'sd40,  8'sd32,  // N7
         8'sd104, -8'sd72, 8'sd40,  8'sd24,  8'sd32,  8'sd16,  8'sd64,  8'sd56,  // N6
         8'sd16,  8'sd32,  8'sd24,  8'sd88, -8'sd56, 8'sd64,  8'sd48,  8'sd8,   // N5
         8'sd24,  8'sd56,  8'sd40,  8'sd48,  8'sd72,  8'sd32,  8'sd16,  8'sd80,  // N4
         8'sd64,  8'sd8,  -8'sd80,  8'sd56,  8'sd24,  8'sd96,  8'sd32,  8'sd48,  // N3
         8'sd72,  8'sd16,  8'sd64,  8'sd8,   8'sd40,  8'sd88,  8'sd56,  8'sd24,  // N2
         8'sd24,  8'sd80,  8'sd48,  8'sd32,  8'sd64,  8'sd8,   8'sd72,  8'sd40,  // N1
         8'sd40,  8'sd8,   8'sd24,  8'sd56,  8'sd16,  8'sd48, -8'sd32,  8'sd64   // N0
    };

    // Layer 3: 512 bits
    localparam logic [511:0] L3_WEIGHTS = {
        -8'sd16,  8'sd40,  8'sd80, -8'sd56,  8'sd64,  8'sd24,  8'sd8,   8'sd48,  // N7
         8'sd72, -8'sd88,  8'sd8,   8'sd64,  8'sd48,  8'sd32,  8'sd56,  8'sd16,  // N6
         8'sd88,  8'sd24, -8'sd16,  8'sd48,  8'sd72,  8'sd40,  8'sd32,  8'sd64,  // N5
         8'sd64,  8'sd40,  8'sd8,   8'sd32,  8'sd80,  8'sd48,  8'sd24,  8'sd56,  // N4
         8'sd32,  8'sd56,  8'sd96,  8'sd24, -8'sd40, 8'sd72,  8'sd48,  8'sd16,  // N3
         8'sd24,  8'sd8,   8'sd40,  8'sd64,  8'sd16,  8'sd56,  8'sd80,  8'sd32,  // N2
         8'sd48,  8'sd96,  8'sd56,  8'sd40,  8'sd8,   8'sd64,  8'sd24,  8'sd72,  // N1
         8'sd8,   8'sd32,  8'sd48,  8'sd16,  8'sd56,  8'sd24, -8'sd40,  8'sd88   // N0
    };

    // Combined Hidden vector: L1 at bits [511:0], L2 at [1023:512], L3 at [1535:1024]
    localparam logic [1535:0] HIDDEN_WEIGHTS_FLAT = {L3_WEIGHTS, L2_WEIGHTS, L1_WEIGHTS};



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
        .clk        (clk),
        .rst_n      (rst_n),
        .ecg_in     (ecg_in),
        .dm_spike_out(dm_spikes),
        .signal     (dm_reconstructed)
    );

    assign dm_spike_raster = dm_spikes;

    // ==========================================
    // FLATTENED INTER-LAYER WIRING
    // ==========================================
    // Replaces: logic [NEURONS_PER_LAYER-1:0] layer_spikes [0:NUM_HIDDEN_LAYERS-1];
    logic [NUM_HIDDEN_LAYERS*NEURONS_PER_LAYER-1:0] layer_spikes_flat;
    
    // Replaces: logic signed [CURRENT_WIDTH-1:0] layer0_current [0:NEURONS_PER_LAYER-1];
    logic [NEURONS_PER_LAYER*CURRENT_WIDTH-1:0] layer0_current_flat;
    
    // Replaces: logic [NEURON_ADDR_WIDTH-1:0] hidden_aer_addr [1:NUM_HIDDEN_LAYERS-1];
    logic [(NUM_HIDDEN_LAYERS-1)*NEURON_ADDR_WIDTH-1:0] hidden_aer_addr_flat;
    
    // Replaces: logic hidden_aer_valid [1:NUM_HIDDEN_LAYERS-1];
    logic [NUM_HIDDEN_LAYERS-1:1] hidden_aer_valid_flat;
    
    // Replaces: logic signed [CURRENT_WIDTH-1:0] hidden_current [1:NUM_HIDDEN_LAYERS-1][0:NEURONS_PER_LAYER-1];
    logic [(NUM_HIDDEN_LAYERS-1)*NEURONS_PER_LAYER*CURRENT_WIDTH-1:0] hidden_current_flat;
    
    // Already 1D, kept as is
    logic [NUM_HIDDEN_LAYERS-1:0] layer_aer_active; 

    // Input AER (2 delta_mod channels)
    logic [DM_ADDR_WIDTH-1:0] input_aer_addr;
    logic                     input_aer_valid;

    aer_handler #(
        .NUM_NEURONS(DM_CHANNELS)
    ) u_input_aer (
        .clk        (clk),
        .rst_n      (rst_n),
        .step_rst   (timestep_rst),
        .spike_vec  (dm_spikes),
        .aer_addr   (input_aer_addr),
        .aer_valid  (input_aer_valid)
    );

    assign layer_aer_active[0] = input_aer_valid;

    // Layer 0: DM_CHANNELS synapses per neuron
    genvar n;
    generate
        for (n = 0; n < NEURONS_PER_LAYER; n++) begin : gen_layer0_accum
            synapse_accumulator #(
                .NUM_SYNAPSES(DM_CHANNELS),
                .WEIGHT_WIDTH(WEIGHT_WIDTH),
                .ACCUM_WIDTH(CURRENT_WIDTH),
                .WEIGHTS(INPUT_WEIGHTS_FLAT[16*n +: 16])
            ) u_accum (
                .clk        (clk),
                .rst_n      (rst_n),
                .accum_rst  (synapse_rst),
                .spike_valid(input_aer_valid),
                .spike_addr (input_aer_addr),
                // Slice the 1D flat bus for this specific neuron's current
                .accum_out  (layer0_current_flat[n*CURRENT_WIDTH +: CURRENT_WIDTH])
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
                // Read from the sliced current bus
                .input_current(layer0_current_flat[n*CURRENT_WIDTH +: CURRENT_WIDTH]),
                // Output to the first layer's segment of the flat spike bus
                .spike        (layer_spikes_flat[n])
            );
        end
    endgenerate

    // Hidden layers 1..NUM_HIDDEN_LAYERS-1.
    
    generate
        for (genvar L = 1; L < NUM_HIDDEN_LAYERS; L++) begin : gen_hidden_layer
            aer_handler #(
                .NUM_NEURONS(NEURONS_PER_LAYER)
            ) u_aer (
                .clk       (clk),
                .rst_n     (rst_n),
                .step_rst  (timestep_rst),
                // Extract previous layer's spikes
                .spike_vec (layer_spikes_flat[(L-1)*NEURONS_PER_LAYER +: NEURONS_PER_LAYER]),
                // Store addresses to flat bus
                .aer_addr  (hidden_aer_addr_flat[(L-1)*NEURON_ADDR_WIDTH +: NEURON_ADDR_WIDTH]),
                .aer_valid (hidden_aer_valid_flat[L])
            );

            assign layer_aer_active[L] = hidden_aer_valid_flat[L];

            for (genvar N = 0; N < NEURONS_PER_LAYER; N++) begin : gen_accum
                synapse_accumulator #(
                    .NUM_SYNAPSES(NEURONS_PER_LAYER),
                    .WEIGHT_WIDTH(WEIGHT_WIDTH),
                    .ACCUM_WIDTH(CURRENT_WIDTH),
                    .WEIGHTS(HIDDEN_WEIGHTS_FLAT[((L-1)*512) + (N*64) +: 64])
                ) u_accum (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .accum_rst  (synapse_rst),
                    .spike_valid(hidden_aer_valid_flat[L]),
                    .spike_addr (hidden_aer_addr_flat[(L-1)*NEURON_ADDR_WIDTH +: NEURON_ADDR_WIDTH]),
                    // Write to flattened 3D array: Layer offset + Neuron offset
                    .accum_out  (hidden_current_flat[((L-1)*NEURONS_PER_LAYER + N)*CURRENT_WIDTH +: CURRENT_WIDTH])
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
                    // Read from flattened 3D array
                    .input_current(hidden_current_flat[((L-1)*NEURONS_PER_LAYER + N)*CURRENT_WIDTH +: CURRENT_WIDTH]),
                    // Write to current layer's segment in spike bus
                    .spike        (layer_spikes_flat[L*NEURONS_PER_LAYER + N])
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
        // Connect to the final layer's spikes
        .spike_in   (layer_spikes_flat[(NUM_HIDDEN_LAYERS-1)*NEURONS_PER_LAYER +: NEURONS_PER_LAYER]),
        .weight_en  (weight_en),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .start      (output_start),
        .done       (output_done),
        .prediction (prediction),
        .match      (match)
    );

    // Because layer_spikes_flat is naturally ordered exactly how the top-level 
    // spike_raster port expects it, we can replace the entire loop with a direct assignment.
    assign spike_raster = layer_spikes_flat;

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
                if (inference_start) begin
                    timestep_next = '0;
                    state_next    = S_SAMPLE;
                end

            S_SAMPLE: begin
                timestep_rst = 1'b1;
                synapse_rst  = 1'b1;
                output_start = 1'b1;
                state_next   = S_PROCESS;
            end

            S_PROCESS:
                if (all_aer_done && output_done) state_next = S_UPDATE;

            S_UPDATE: begin
                neuron_en     = 1'b1;
                timestep_next = timestep + 1;
                if (timestep + 1 >= NUM_TIMESTEPS)
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
            timestep <= '0;
        end else begin
            state    <= state_next;
            timestep <= timestep_next;
        end
    end

endmodule
