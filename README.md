# EE531_Final_Project

## Isaac's Notes 3/3/26
I'm going to implement a top-level module soon. 

Sanjeev, here are my observastions of the code you added. Could you go through it and make the nessesary changes? If I made a mistake in my analysis please append your own notes to this file.
### delta_mod.sv
- Currently uses active high reset (posedge dm_reset), but all others use active low.
- possible overflow error on the `ecg_in > signal + STEP_SIZE` line. We could seperate `signal + STEP_SIZE` into an intermediate variable with one additional bit of headroom before the comparison operation.
### lpf_unit.sv
- y_out is purely combinational, should probably be registered in an always_ff so that output is synced.
- `MIN_VAL` is 0, so doesn't need to be signed.
### output_decoder.sv
- Possible overflow when adding multiple products to accum. accum should probably be sized to accomidate the additional addidtion widths: `accum_width = weight_width + lpf_output_width + $clog2(num_lpf_outputs)`
- Both lpf_unit and output_decoder define typedef ... state_t, which may cause issues int the top level module.
- Should we implement a comparison to a threshold for the output as we discussed?