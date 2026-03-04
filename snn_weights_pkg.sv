// snn_weights_pkg — Compile-time weight arrays for the SNN.
//
// Contains weight tables for each layer's synapse accumulators.
// Layer 0 has 2 input synapses (UP/DOWN from delta_mod).
// Hidden layers 1..NUM_HIDDEN_LAYERS-1 have LAYER_SIZE synapses each.
// All weights are deterministically pseudo-random initialized for testing.

package snn_weights_pkg;

    localparam int LAYER_SIZE        = 8;
    localparam int NUM_HIDDEN_LAYERS = 4;
    localparam int WEIGHT_WIDTH      = 8;

    // Layer 0: 2 inputs (delta_mod UP/DOWN) → LAYER_SIZE neurons
    // Each neuron gets a weight array of size 2
    typedef logic signed [WEIGHT_WIDTH-1:0] input_weight_t [0:1];
    typedef input_weight_t input_layer_weights_t [0:LAYER_SIZE-1];

    localparam input_layer_weights_t INPUT_WEIGHTS = '{
        '{  8'sd12,  -8'sd8 },  // neuron 0
        '{  8'sd15,  -8'sd3 },  // neuron 1
        '{ -8'sd6,   8'sd10 },  // neuron 2
        '{  8'sd9,   8'sd7  },  // neuron 3
        '{ -8'sd11,  8'sd14 },  // neuron 4
        '{  8'sd5,  -8'sd13 },  // neuron 5
        '{ -8'sd4,   8'sd2  },  // neuron 6
        '{  8'sd16, -8'sd1  }   // neuron 7
    };

    // Hidden layers 1..NUM_HIDDEN_LAYERS-1: LAYER_SIZE inputs → LAYER_SIZE neurons
    typedef logic signed [WEIGHT_WIDTH-1:0] hidden_weight_t [0:LAYER_SIZE-1];
    typedef hidden_weight_t hidden_layer_weights_t [0:LAYER_SIZE-1];
    typedef hidden_layer_weights_t all_hidden_weights_t [0:NUM_HIDDEN_LAYERS-2];

    localparam all_hidden_weights_t HIDDEN_WEIGHTS = '{
        // Layer 1
        '{
            '{  8'sd5,  -8'sd3,   8'sd7,   8'sd1,  -8'sd9,   8'sd4,  -8'sd2,   8'sd6  },
            '{ -8'sd8,   8'sd10,  8'sd2,  -8'sd5,   8'sd3,  -8'sd7,   8'sd11, -8'sd1  },
            '{  8'sd6,   8'sd4,  -8'sd12,  8'sd8,  -8'sd2,   8'sd9,   8'sd3,  -8'sd6  },
            '{ -8'sd3,   8'sd7,   8'sd5,  -8'sd10,  8'sd14, -8'sd4,   8'sd1,   8'sd8  },
            '{  8'sd9,  -8'sd6,  -8'sd1,   8'sd11, -8'sd5,   8'sd3,  -8'sd8,   8'sd2  },
            '{ -8'sd7,   8'sd2,   8'sd13, -8'sd4,   8'sd6,  -8'sd11,  8'sd5,   8'sd10 },
            '{  8'sd4,  -8'sd9,   8'sd3,   8'sd7,   8'sd1,  -8'sd6,  -8'sd10,  8'sd15 },
            '{ -8'sd2,   8'sd8,  -8'sd5,   8'sd6,  -8'sd3,   8'sd12,  8'sd7,  -8'sd4  }
        },
        // Layer 2
        '{
            '{  8'sd8,  -8'sd4,   8'sd6,   8'sd2,  -8'sd7,   8'sd3,  -8'sd1,   8'sd5  },
            '{ -8'sd5,   8'sd9,   8'sd1,  -8'sd8,   8'sd4,  -8'sd6,   8'sd10, -8'sd3  },
            '{  8'sd3,   8'sd7,  -8'sd11,  8'sd5,  -8'sd1,   8'sd8,   8'sd2,  -8'sd9  },
            '{ -8'sd6,   8'sd4,   8'sd12, -8'sd3,   8'sd7,  -8'sd10,  8'sd1,   8'sd8  },
            '{  8'sd10, -8'sd2,  -8'sd4,   8'sd9,  -8'sd6,   8'sd5,  -8'sd7,   8'sd3  },
            '{ -8'sd1,   8'sd6,   8'sd8,  -8'sd7,   8'sd11, -8'sd3,   8'sd4,   8'sd2  },
            '{  8'sd7,  -8'sd8,   8'sd2,   8'sd4,   8'sd3,  -8'sd5,  -8'sd9,   8'sd13 },
            '{ -8'sd4,   8'sd5,  -8'sd6,   8'sd3,  -8'sd2,   8'sd11,  8'sd8,  -8'sd7  }
        },
        // Layer 3
        '{
            '{  8'sd11, -8'sd5,   8'sd3,   8'sd7,  -8'sd2,   8'sd6,  -8'sd4,   8'sd1  },
            '{ -8'sd9,   8'sd3,   8'sd8,  -8'sd1,   8'sd5,  -8'sd7,   8'sd12, -8'sd6  },
            '{  8'sd4,   8'sd10, -8'sd7,   8'sd2,  -8'sd8,   8'sd5,   8'sd1,  -8'sd3  },
            '{ -8'sd2,   8'sd6,   8'sd9,  -8'sd5,   8'sd3,  -8'sd12,  8'sd7,   8'sd4  },
            '{  8'sd7,  -8'sd3,  -8'sd6,   8'sd10, -8'sd4,   8'sd1,  -8'sd5,   8'sd8  },
            '{ -8'sd8,   8'sd4,   8'sd5,  -8'sd9,   8'sd6,  -8'sd2,   8'sd3,   8'sd11 },
            '{  8'sd2,  -8'sd7,   8'sd4,   8'sd6,   8'sd8,  -8'sd1,  -8'sd11,  8'sd9  },
            '{ -8'sd6,   8'sd1,  -8'sd3,   8'sd8,  -8'sd7,   8'sd10,  8'sd5,  -8'sd2  }
        }
    };

endpackage
