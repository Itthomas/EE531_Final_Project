// snn_weights_pkg: Compile-time weight arrays for the SNN.
// 4 hidden layers with 8 neurons each, and an input layer with 2 inputs (delta modulator UP/DOWN).

package snn_weights_pkg;

    // Layer 0: 2 inputs (delta_mod UP/DOWN) to 8 neurons
    // Each neuron gets a weight array of size 2
    typedef logic signed [7:0] input_weight_t [0:1];
    typedef input_weight_t input_layer_weights_t [0:7];

    localparam input_layer_weights_t INPUT_WEIGHTS = '{
        '{  8'sd12,  -8'sd8 },
        '{  8'sd15,  -8'sd3 },
        '{ -8'sd6,   8'sd10 },
        '{  8'sd9,   8'sd7  },
        '{ -8'sd11,  8'sd14 },
        '{  8'sd5,  -8'sd13 },
        '{ -8'sd4,   8'sd2  },
        '{  8'sd16, -8'sd1  }
    };

    // Hidden layers 1-3:
    typedef logic signed [7:0] hidden_weight_t [0:7];
    typedef hidden_weight_t hidden_layer_weights_t [0:7];
    typedef hidden_layer_weights_t all_hidden_weights_t [0:2];

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
