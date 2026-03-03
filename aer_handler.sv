// aer_handler — Serializes a parallel spike vector onto a single AER address bus.
//
// Each cycle, encodes the lowest-index unserviced spike into aer_addr/aer_valid.
// Internally tracks serviced neurons via a registered mask.
//
// Integration:
//   - Drive spike_vec from the neuron layer's spike outputs (active-high, held stable per step).
//   - Connect aer_addr/aer_valid to downstream synapse_accumulator(s).
//   - Assert step_rst for one cycle at the start of each time step to clear the serviced mask.
//   - Use aer_valid as the bus-active flag (low = all spikes processed).

module aer_handler #(
    parameter int NUM_NEURONS = 16
)(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            step_rst,
    input  logic [NUM_NEURONS-1:0]          spike_vec,
    output logic [$clog2(NUM_NEURONS)-1:0]  aer_addr,
    output logic                            aer_valid
);

    localparam int ADDR_WIDTH = $clog2(NUM_NEURONS);

    logic [NUM_NEURONS-1:0]  serviced;
    logic [NUM_NEURONS-1:0]  pending;
    logic [ADDR_WIDTH-1:0]   grant_idx;
    logic                    any_pending;

    assign pending = spike_vec & ~serviced;

    // Priority encoder: forward scan, first hit wins
    always_comb begin
        grant_idx   = '0;
        any_pending = 1'b0;
        for (int i = 0; i < NUM_NEURONS; i++) begin
            if (pending[i] && !any_pending) begin
                grant_idx   = ADDR_WIDTH'(i);
                any_pending = 1'b1;
            end
        end
    end

    // Tracks serviced neurons, cleared each time step
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            serviced <= '0;
        else if (step_rst)
            serviced <= '0;
        else if (any_pending)
            serviced[grant_idx] <= 1'b1;
    end

    assign aer_addr  = grant_idx;
    assign aer_valid = any_pending;

endmodule