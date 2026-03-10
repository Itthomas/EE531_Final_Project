# EE531_Final_Project

### Note for the presentation and report:
The SNN implemented here is pipelined, meaning if we were to implement the same exact one on SNN torch we would need to model this by adding a delay of 1 timestep to each neuron's inputs.

## Change to output_decoder.sv

I updated the decoder so it snapshots the LPF outputs when start is asserted, then runs the multi-cycle regression pass over that frozen snapshot instead of reading the live LPF bank every cycle. The previous behavior could mix different LPF time states into one prediction because the LPF units continue updating while the FSM walks across neurons. This change keeps the decoder behavior aligned with the intended single-state classification pass without changing the overall FSM structure.
