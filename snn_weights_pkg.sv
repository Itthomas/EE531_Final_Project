// snn_weights_pkg: Compile-time weight arrays for the SNN.
// 4 hidden layers with 8 neurons each, and an input layer with 2 inputs (delta modulator UP/DOWN).

package snn_weights_pkg;

    // Layer 0: 2 inputs (delta_mod UP/DOWN) to 8 neurons
    // Each neuron gets a weight array of size 2
    typedef logic signed [7:0] input_weight_t [0:1];
    typedef input_weight_t input_layer_weights_t [0:7];

    localparam input_layer_weights_t INPUT_WEIGHTS = '{
        '{  8'sd96,  -8'sd94 },
        '{  8'sd120,  8'sd74  },
        '{  8'sd98,   8'sd80  },
        '{  8'sd92,   -8'sd86  },
        '{  -8'sd88,   8'sd112 },
        '{  8'sd70,   8'sd104 },
        '{  8'sd112,   -8'sd16  },
        '{  -8'sd128,  8'sd86   }
    };

    // Hidden layers 1-3:
    typedef logic signed [7:0] hidden_weight_t [0:7];
    typedef hidden_weight_t hidden_layer_weights_t [0:7];
    typedef hidden_layer_weights_t all_hidden_weights_t [0:2];

    localparam all_hidden_weights_t HIDDEN_WEIGHTS = '{
        // Layer 1
        '{
            '{  8'sd40,  -8'sd24,   8'sd56,   8'sd8,    8'sd72,   8'sd32,   8'sd16,   8'sd48  },
            '{  8'sd64,   8'sd80,   8'sd16,   8'sd40,   8'sd24,   8'sd56,   8'sd88,   8'sd8   },
            '{  8'sd48,   8'sd32,   8'sd96,   8'sd64,   8'sd16,   8'sd72,   8'sd24,   8'sd48  },
            '{  8'sd24,   8'sd56,   8'sd40,  -8'sd80,   8'sd112,  8'sd32,   8'sd8,    8'sd64  },
            '{  8'sd72,   8'sd48,   8'sd8,    8'sd88,   8'sd40,   8'sd24,   8'sd64,   8'sd16  },
            '{  8'sd56,   8'sd16,   8'sd104,  8'sd32,   8'sd48,  -8'sd88,   8'sd40,   8'sd80  },
            '{  8'sd52,   8'sd102,   8'sd84,   8'sd56,   8'sd80,    8'sd18,   8'sd110,   8'sd20 },
            '{  8'sd16,   8'sd64,   8'sd40,   8'sd48,  -8'sd24,   8'sd96,   8'sd56,  -8'sd32  }
        },
        // Layer 2
        '{
            '{  8'sd64,  -8'sd32,   8'sd48,   8'sd16,   8'sd56,   8'sd24,   8'sd8,    8'sd40  },
            '{  8'sd40,   8'sd72,   8'sd8,    8'sd64,   8'sd32,   8'sd48,   8'sd80,   8'sd24  },
            '{  8'sd24,   8'sd56,   8'sd88,   8'sd40,   8'sd8,    8'sd64,   8'sd16,   8'sd72  },
            '{  8'sd48,   8'sd32,   8'sd96,   8'sd24,   8'sd56,  -8'sd80,   8'sd8,    8'sd64  },
            '{  8'sd80,   8'sd16,   8'sd32,   8'sd72,   8'sd48,   8'sd40,   8'sd56,   8'sd24  },
            '{  8'sd8,    8'sd48,   8'sd64,  -8'sd56,   8'sd88,   8'sd24,   8'sd32,   8'sd16  },
            '{  8'sd56,   8'sd64,   8'sd16,   8'sd32,   8'sd24,   8'sd40,  -8'sd72,   8'sd104 },
            '{  8'sd32,   8'sd40,   8'sd48,   8'sd24,  -8'sd16,   8'sd88,   8'sd64,  -8'sd56  }
        },
        // Layer 3
        '{
            '{  8'sd88,  -8'sd40,   8'sd24,   8'sd56,   8'sd16,   8'sd48,   8'sd32,   8'sd8   },
            '{  8'sd72,   8'sd24,   8'sd64,   8'sd8,    8'sd40,   8'sd56,   8'sd96,   8'sd48  },
            '{  8'sd32,   8'sd80,   8'sd56,   8'sd16,   8'sd64,   8'sd40,   8'sd8,    8'sd24  },
            '{  8'sd16,   8'sd48,   8'sd72,  -8'sd40,   8'sd24,   8'sd96,   8'sd56,   8'sd32  },
            '{  8'sd56,   8'sd24,   8'sd48,   8'sd80,   8'sd32,   8'sd8,    8'sd40,   8'sd64  },
            '{  8'sd64,   8'sd32,   8'sd40,   8'sd72,   8'sd48,  -8'sd16,   8'sd24,   8'sd88  },
            '{  8'sd16,   8'sd56,   8'sd32,   8'sd48,   8'sd64,   8'sd8,   -8'sd88,   8'sd72  },
            '{  8'sd48,   8'sd8,    8'sd24,   8'sd64,  -8'sd56,   8'sd80,   8'sd40,  -8'sd16  }
        }
    };

endpackage
