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
    logic signed [(WIDTH*NUM_NEURONS)-1:0] lpf_outputs;

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i++) begin : bank
            lpf_unit #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) lpf_inst (
                .clk(clk), .rst_n(rst_n), .spike_in(spike_in[i]), .y_out(lpf_outputs[i*WIDTH +: WIDTH])
            );
        end
    endgenerate

    //weight memory
    logic signed [(NUM_NEURONS*WIDTH)-1:0] weights;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weights <= '0;
        end else if (weight_en) begin
            weights[weight_addr*WIDTH +: WIDTH] <= weight_data;
        end
    end
    
    typedef enum logic [1:0] {IDLE, COMPUTE, FINISH} out_dec_state_t;
    out_dec_state_t state;
    
    logic [ADDR_WIDTH-1:0] ptr;
    logic signed [ACCUM_WIDTH-1:0] accum;  
    
    wire signed [WIDTH-1:0] current_lpf = $signed({1'b0, lpf_outputs[ptr*WIDTH +: WIDTH]});
    wire signed [WIDTH-1:0] current_weight = weights[ptr*WIDTH +: WIDTH];

    
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
                    accum <= accum + (current_lpf * current_weight);
                    if (ptr == (ADDR_WIDTH'(NUM_NEURONS - 1)))
                        state <= FINISH;
                    else
                        ptr <= ptr + 1;
                end
                
                FINISH: begin
                    logic signed [31:0] val_sat;
                    if (accum > 36'sh0_7FFF_FFFF) begin
                        val_sat = 32'sh7FFF_FFFF; 
                    end else if (accum < 36'shF_8000_0000) begin
                        val_sat = 32'sh8000_0000;
                    end else begin
                        val_sat = accum[31:0];
                    end
                    
                    prediction <= val_sat;
                    
                    if ($signed(val_sat) > THRESHOLD)
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
