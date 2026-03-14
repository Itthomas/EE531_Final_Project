# EE531 Final Presentation Outline

## 1. Presentation Goal and Framing
- Title slide: Fixed-Weight Spiking Neural Network for ECG Classification
- Team slide: list the three team members and each person’s role
  - Suggested split: architecture/RTL, verification/debug, synthesis/physical design
- Opening framing
  - Problem statement: design, verify, and synthesize a complete digital system for a meaningful application
  - Chosen system: a spiking neural network implemented in SystemVerilog with fixed-point arithmetic and fixed hidden-layer weights
  - Application context: ECG-driven binary classification
- High-level thesis for the audience
  - This is not “AI in software” running on a CPU
  - This is a hardware architecture that performs SNN-style inference directly in RTL
  - The project succeeded at three levels: functional design, verification, and synthesis

## 2. Motivation and Background

### 2.1 Why This Project
- Explain why an SNN is a good VLSI final project
  - Combines signal processing, digital design, state machines, arithmetic, and architectural tradeoffs
  - Has a clear hardware interpretation because spikes are discrete events
  - Creates a natural bridge between machine learning concepts and digital circuits
- Explain why ECG was chosen
  - Time-series signal with visible structure and recurring peaks
  - Good fit for event-driven encoding
  - Makes it easy to visualize both the original input and the spike-based representation

### 2.2 ANN vs SNN for a Mixed Audience
- Briefly remind the class what a conventional ANN does
  - Real-valued activations
  - Multiply-accumulate-heavy computation
  - Layer-by-layer feedforward updates in software or specialized hardware
- Introduce the SNN concept clearly
  - Information is represented as spikes over time rather than only as static activations
  - Neurons integrate incoming events and fire when membrane voltage crosses threshold
  - Time is part of the computation, not just the dataset index
- Key contrast slide
  - ANN: dense synchronous numeric processing
  - SNN: event-driven temporal processing
  - ANN neuron output: real number
  - SNN neuron output: spike or no spike at each timestep
- Important message for non-SNN audience members
  - An SNN is still a neural network, but it is closer to a dynamical system implemented over time

### 2.3 Why SNNs Matter in Hardware
- Event-driven behavior can reduce unnecessary switching when activity is sparse
- Neuron models naturally map to sequential logic and state registers
- Fixed-point arithmetic is practical and synthesizable
- Hardware design tradeoff
  - More timesteps and stateful behavior
  - Less dependence on large floating-point datapaths

## 3. Project Specification

### 3.1 What the System Must Do
- Accept an ECG sample stream as input
- Convert the signal into spike events
- Propagate spike information through multiple hidden layers
- Produce a final binary classification output
  - `match = 1` for a detected target pattern/class
  - `match = 0` otherwise
- Expose internal observability for verification
  - Delta-modulator spike raster
  - Hidden-layer spike raster
  - Decoder prediction value
  - Inference done flag

### 3.2 Concrete Top-Level Architecture From the RTL
- Source file for the architecture: snn_top.sv
- Parameters visible in the implemented design
  - ECG input width: 11 bits
  - Delta modulator channels: 2
  - Hidden layers: 4
  - Neurons per hidden layer: 8
  - Neuron state width: 16 bits
  - Weight width: 8 bits in hidden layers
  - Default number of timesteps per inference: 10
- Explain that this is a compact but complete network suitable for course-scale synthesis and debug

### 3.3 Design Philosophy
- Use a modular hardware architecture rather than one large behavioral block
- Favor fixed-point arithmetic and shift-based operations over multipliers where possible
- Keep hidden-layer weights fixed at compile time for implementation simplicity
- Keep output weights programmable to make final classification tunable without rebuilding the full hidden network

## 4. End-to-End System Story

### 4.1 Dataflow Overview
- Input ECG sample enters delta_mod
- Delta-modulator outputs two channels of spikes
  - Up spike
  - Down spike
- AER handler serializes active spikes into address events
- Synapse accumulators convert event addresses into weighted summed currents
- LIF neurons update membrane state and emit new spikes
- This repeats across all hidden layers
- Final layer spikes feed the output decoder
- Output decoder converts spike history into a scalar prediction and binary match decision

### 4.2 One Important Project-Specific Point
- The design is pipelined across timesteps, not purely combinational across layers
- Downstream layers consume registered spike outputs from earlier layers on later timesteps
- Therefore, total inference length includes both useful computation and pipeline fill/drain latency
- This is explicitly stated in the top-level comments and reflected in the `NUM_TIMESTEPS` design choice

## 5. Top-Level Control in snn_top.sv

### 5.1 Why Focus on snn_top.sv
- It is the architectural integration point for the whole project
- It defines the sequencing of sampling, event processing, neuron updates, and final decode
- It exposes the signals that matter most for demo, verification, and discussion

### 5.2 Top-Level Ports and Observability
- Inputs
  - `clk`, `rst_n`
  - `ecg_in`
  - `inference_start`
  - Output weight programming interface: `weight_en`, `weight_addr`, `weight_data`
- Outputs
  - `inference_done`
  - `match`
  - `prediction`
  - `dm_spike_raster`
  - `spike_raster`
- Emphasize that the design is instrumented for debug, not just minimal functionality

### 5.3 FSM Walkthrough
- Present the six top-level states from the RTL
  - `S_IDLE`
  - `S_SAMPLE`
  - `S_PROCESS`
  - `S_UPDATE`
  - `S_OUTPUT`
  - `S_DONE`
- Explain the purpose of each state
  - `S_IDLE`: wait for inference request
  - `S_SAMPLE`: clear per-timestep state and start decoder pass
  - `S_PROCESS`: allow AER traffic and decoder processing to complete
  - `S_UPDATE`: advance neuron states for one timestep
  - `S_OUTPUT`: perform final decode after the time pipeline completes
  - `S_DONE`: raise completion flag and hold result
- Explain the control signals derived from the FSM
  - `timestep_rst`
  - `synapse_rst`
  - `neuron_en`
  - `output_start`

### 5.4 Architectural Decisions Worth Explaining
- Why reset AER and synapse accumulators every timestep
  - Each timestep should process a fresh event set
- Why neuron updates occur in a separate phase
  - Clean separation between event accumulation and membrane-state update
- Why the decoder is triggered during timestep processing and again at the end
  - Supports ongoing decoding behavior and final classification output
- Why `all_aer_done` is used as a global progress condition
  - Prevents advancing before all layer event traffic is serviced

## 6. Input Encoding: delta_mod.sv

### 6.1 Role in the System
- Converts the analog-like ECG amplitude sequence into a discrete spike-based representation
- Produces a 2-bit raster
  - Bit 0: upward event
  - Bit 1: downward event

### 6.2 Algorithmic Behavior
- Maintains an internal reconstructed signal
- Compares incoming sample against the reconstructed value plus/minus a step size
- Emits an up spike when input exceeds the upper threshold
- Emits a down spike when input falls below the lower threshold
- Clamps reconstruction between min and max bounds

### 6.3 Specific Implementation Decisions
- Uses an initialization phase to seed the reconstructed signal with the first sample
- Uses `last_cycle_spiked` to suppress immediate repeated spikes on the next cycle
- Uses thresholding with `STEP_SIZE` rather than transmitting full amplitude values

### 6.4 Design Rationale
- Reduces raw sample stream into event-driven information
- Captures directional changes instead of full-resolution values at every stage
- Fits the SNN paradigm better than passing raw ECG values directly into all neurons

### 6.5 Slide Visuals
- ECG plot from the project’s plotting script
- Simple illustration of a rising edge generating an up spike and a falling edge generating a down spike

## 7. Event Serialization: aer_handler.sv

### 7.1 Why AER Is Used
- Multiple neurons can spike simultaneously
- Downstream logic is simpler if spikes are serialized into one address/event stream
- This reduces fanout and regularizes synapse access

### 7.2 Module Behavior
- Takes a parallel spike vector as input
- Tracks which spikes have already been serviced in the current timestep
- Uses a priority encoder to grant the lowest-index pending spike first
- Outputs
  - `aer_addr`
  - `aer_valid`

### 7.3 Design Choices
- `step_rst` clears the serviced mask at the start of each timestep
- Forward priority scan provides deterministic ordering
- `aer_valid = 0` means all current spikes have been handled

### 7.4 Why This Matters Architecturally
- This is the bridge between spike-producing neurons and synaptic accumulation
- It makes the multi-neuron system easier to schedule in synchronous RTL
- It introduces a clean notion of “event traffic is complete for this timestep”

## 8. Weighted Event Integration: synapse_accumulator.sv

### 8.1 Role in the Network
- Converts an incoming AER spike address into a weighted current contribution
- Builds the total synaptic input current seen by one neuron during the timestep

### 8.2 Module Behavior
- Uses the spike address to index a compile-time weight array
- Adds the signed weight to an accumulator register
- Uses saturation to prevent overflow
- Resets the accumulator each timestep using `accum_rst`

### 8.3 Design Decisions
- Hidden-layer weights are parameterized as ROM-like compile-time arrays
- Saturating arithmetic is used instead of wraparound arithmetic
- Each neuron gets its own accumulator instance

### 8.4 Why This Is a Good Hardware Choice
- Very clear dataflow
- Easy to synthesize
- Bounded numeric behavior during long event bursts
- Maps naturally onto repeated per-neuron structures

## 9. Neuron Model: lif_neuron_fixed.sv

### 9.1 Conceptual Background
- LIF stands for leaky integrate-and-fire
- A neuron maintains a membrane voltage
- Input current increases or decreases the state
- The membrane leaks over time
- A spike occurs when voltage exceeds threshold

### 9.2 What This RTL Implements
- Hardcoded decay approximately equal to 510/512
- Signed fixed-point membrane voltage state
- Input-current alignment based on fractional widths
- Spike output when voltage saturates above the positive limit
- Reset to a negative reset potential after spike

### 9.3 Important Numeric Choices
- 16-bit neuron state
- Fractional representation for fixed-point operation
- Shift-and-subtract decay approximation rather than a general multiplier
- Saturation at both positive and negative limits

### 9.4 Why These Choices Matter
- Shift-based decay is much cheaper than a true multiplier in hardware
- Fixed-point arithmetic is much more synthesis-friendly than floating point
- Saturation protects against unstable growth
- Reset-after-spike creates repeatable spike behavior over time

### 9.5 Presentation Angle
- This is the best place to connect neuroscience-inspired behavior to actual synchronous digital logic
- Show one equation slide, then show how that equation was simplified for synthesis

## 10. Compile-Time Network Weights: snn_weights_pkg.sv

### 10.1 What the Package Contains
- Input-layer weights from 2 delta-modulator channels into 8 first-layer neurons
- Hidden-layer weight arrays for the remaining hidden layers
- 8 signed weights per neuron for hidden-to-hidden connections

### 10.2 Project-Specific Interpretation
- The network’s internal feature extraction is fixed in the RTL package
- This keeps the hidden network deterministic and hardware-friendly
- The package acts like embedded ROM data for the hidden layers

### 10.3 Why Fixed Weights Were a Good Course Project Decision
- Simplifies synthesis and integration
- Removes the need for on-chip training or large external memory
- Keeps focus on inference architecture instead of training infrastructure

### 10.4 Point to Explain Carefully
- Hidden-layer weights are fixed at compile time
- Output-layer weights are loaded separately at runtime through the top-level programming interface
- This hybrid approach provides structure plus some final-stage flexibility

## 11. Output Stage: output_decoder.sv and lpf_unit.sv

### 11.1 Why an Output Decoder Is Needed
- Final hidden-layer spikes are still event sequences, not a single classification number
- The decoder turns temporal spike activity into a scalar decision

### 11.2 Two-Stage Output Strategy
- Stage 1: `lpf_unit` converts each spike train into a leaky continuous activity value
- Stage 2: `output_decoder` performs a weighted regression-like accumulation across neurons

### 11.3 lpf_unit Design
- Each output neuron has an LPF instance
- Spike adds a fixed contribution
- State decays over time using the same efficient shift/subtract style used elsewhere
- Output is clipped to a nonnegative range

### 11.4 output_decoder Control Flow
- Receives the last hidden-layer spike vector
- Maintains a weight memory for output weights
- On `start`, snapshots the LPF outputs
- Walks through the snapshot one neuron at a time in an FSM
- Accumulates weighted contributions into `prediction`
- Compares prediction against a threshold to produce `match`

### 11.5 Important Design Decision From the README
- The decoder snapshots LPF outputs before the regression pass
- Reason: without snapshotting, the LPF bank could keep changing while the FSM iterates across neurons
- Benefit: all multiply-accumulate operations use one coherent time state
- This is an excellent design-decision slide because it shows a real hardware timing issue and the fix

### 11.6 Why the Output Layer Is Architecturally Strong
- Separates temporal filtering from classification
- Avoids a giant combinational multiply-accumulate block
- Keeps the result interpretable as an accumulated confidence value plus threshold comparison

## 12. Pipeline and Timing Interpretation

### 12.1 The Meaning of a Timestep in This Design
- A timestep is not just “one clock cycle”
- A timestep contains multiple phases
  - Reset/prepare step-local state
  - Drain AER events
  - Run decoder work for that cycle
  - Update neuron states

### 12.2 Why This Matters for the Audience
- The network is temporal in two ways
  - It processes spike timing
  - It is architecturally pipelined across layers over time
- The presentation should explicitly distinguish biological inspiration from digital scheduling

### 12.3 Suggested Timing Diagram Slide
- Show one inference spanning several timesteps
- Mark when spikes are generated, serialized, accumulated, and committed into neuron state
- Show why the final decode happens only after the pipeline has fully propagated the activity

## 13. Verification Strategy

### 13.1 Verification Philosophy
- Verify each reusable block independently before trusting the integrated system
- Then run top-level system tests with real ECG samples and output-weight files
- Collect waveforms, console pass/fail logs, and spike rasters for evidence

### 13.2 Unit Tests Present in the Project
- `tb_synapse_accumulator.sv`
  - Reset behavior
  - Positive and negative accumulation
  - Saturation
  - Back-to-back addressing
- `tb_lif_neuron_fixed.sv`
  - Reset
  - Enable gating
  - Decay behavior
  - Positive-input spiking
  - Negative saturation
  - Input alignment between fixed-point formats
- `tb_aer_handler.sv`
  - Single spike
  - Priority ordering
  - Full-vector serialization
  - Step reset behavior
  - Late-arriving spikes
- `tb_output_decoder.sv`
  - Weight loading
  - LPF activity formation
  - Final decoded prediction
- `tb_delta_mod.sv`
  - File-driven ECG stimulus for event generation

### 13.3 Unit-Test Evidence to Show
- Use the provided pass screenshots for at least these modules
  - Synapse accumulator
  - LIF neuron
  - AER handler
- For each screenshot, do not just show “PASS”
  - Explain what specific corner cases were being checked

## 14. Top-Level Verification: tb_snn_top.sv

### 14.1 What the Top-Level Testbench Does
- Loads 1000 ECG samples from a text file
- Loads output weights from a separate text file
- Programs the output decoder weights through the runtime interface
- Runs one inference per ECG sample
- Logs spike activity and prediction data to `spike_raster_log.txt`

### 14.2 Why the Top-Level Testbench Is Important
- Demonstrates end-to-end operation on realistic stimulus
- Confirms that the integrated scheduling in `snn_top.sv` actually works
- Produces data products that can be plotted and included in the presentation

### 14.3 Specific Signals Worth Showing in Waveforms
- `ecg_in`
- `inference_start`
- `inference_done`
- `dm_spike_raster`
- `spike_raster`
- `prediction`
- `match`

### 14.4 Recommended Story for the Verification Section
- Start with “we did not jump straight to the top level”
- Then show block-level evidence
- Then show a top-level waveform and spike raster to prove integration
- Then explain what a successful inference looks like in timing terms

## 15. Results Visualization

### 15.1 ECG Input Plot
- Use the ECG plot already generated from `plot_ecg.py`
- Explain the main visible peaks and why they are good candidates for spike-triggered encoding

### 15.2 Spike Raster Plot
- Use the raster generated from `plot_spike_raster.py`
- Explain what each band means
  - DM
  - L0
  - L1
  - L2
  - L3
- Explain what the viewer should notice
  - Sparse event structure
  - Propagation of activity across layers
  - Match output toggling only at selected record indices

### 15.3 Top-Level Waveform Screenshots
- Use the Vivado top-simulation screenshots
- Annotate the meaningful regions
  - sample input values
  - spike-raster activity
  - prediction evolution
  - match assertion

### 15.4 How to Present Prediction
- Avoid only showing raw integer values with no interpretation
- Explain that the output is a signed accumulated classifier score
- Show that `match` is produced by thresholding that score

## 16. Synthesis Story

### 16.1 What Was Successfully Synthesized
- According to the synthesis notes in `pass_synth/README.md`, the following modules passed Librelane synthesis
  - `delta_mod.sv`
  - `output_decoder.sv`
  - `lpf_unit.sv`
  - `lif_neuron_fixed.sv`
  - `aer_handler.sv`
  - `synapse_accumulator.sv`

### 16.2 Why Module-Level Synthesis Matters
- Confirms that the chosen coding style and arithmetic structures are physically realizable
- Validates that fixed-point, FSM-based, and event-serialized building blocks are implementation-friendly
- Helps identify which blocks dominate area

### 16.3 Interesting Synthesis-Driven Design Choices
- Avoiding multipliers in the neuron and LPF helped hardware realizability
- Fixed hidden weights avoided a large dynamic memory subsystem
- Flattening or parameter-structure adjustments were needed for some modules during synthesis flow refinement

### 16.4 Bridge to Full-System Physical Design
- Explain that a teammate pushed the design through the modern OpenLane successor flow, Librelane
- Show layout and physical-design metrics if available from the teammate
- Suggested metrics slide contents
  - cell count
  - area
  - utilization
  - timing slack
  - power if available
  - DRC/LVS status if available

### 16.5 Important Honesty Slide
- Distinguish clearly between
  - modules individually confirmed in synthesis artifacts present in the repo
  - full-chip layout and metrics held by the teammate
- This keeps the talk technically rigorous and avoids overstating what is locally documented

## 17. Key Design Decisions and Tradeoffs

### 17.1 Why Fixed-Point Instead of Floating Point
- Lower area and complexity
- Easier synthesis
- Good enough precision for a proof-of-concept SNN inference engine

### 17.2 Why Fixed Hidden Weights
- Simpler architecture
- Less storage overhead
- Better fit for a semester project focused on hardware rather than training infrastructure

### 17.3 Why Use AER
- Serial event handling keeps downstream synapse hardware regular
- Better controlled than broadcasting full parallel spike vectors into all logic simultaneously

### 17.4 Why a Pipelined Timestep Architecture
- Easier scheduling across multiple layers
- Modular control using a clear FSM
- Natural way to account for layer-to-layer spike propagation in hardware

### 17.5 Why LPF Plus Threshold for Final Decision
- Raw spike trains are hard to classify directly
- LPF captures recent firing activity as a continuous measure
- Regression plus threshold gives a clean binary output

## 18. Limitations and Lessons Learned

### 18.1 Technical Limitations
- Compact network size chosen for tractability, not maximum classification accuracy
- Hidden weights are static
- The decoder runs sequentially across neurons instead of fully parallel
- Top-level documentation in the repo is lighter than the amount of engineering actually performed

### 18.2 Lessons Learned
- Temporal systems require very careful control sequencing
- Snapshotting state is important when an FSM consumes values that continue updating elsewhere
- Unit testing is essential before full integration in stateful multi-module designs
- Synthesis constraints can feed back into architecture, not just implementation details

### 18.3 If There Were More Time
- Sweep network size and timestep count
- Compare accuracy versus area/power for different fixed-point widths
- Evaluate different neuron models or output-decoder strategies
- Add a more formal training-to-hardware export flow

## 19. Conclusion

### 19.1 Final Takeaways
- The team implemented a real SNN inference pipeline in synthesizable RTL
- The design is modular, testable, and physically grounded
- Verification evidence shows correct operation at both block and top levels
- Synthesis evidence shows the architecture is compatible with an ASIC-oriented flow

### 19.2 Closing Message for the Class
- SNNs are not just a machine-learning idea
- They can be expressed as practical hardware architectures with explicit timing, arithmetic, and control tradeoffs
- This project shows how ML-inspired systems can become real VLSI design problems

## 20. Suggested Slide Order
- 1 slide: Title and team roles
- 1 slide: Motivation and project goals
- 2 slides: ANN vs SNN background
- 1 slide: Why ECG and why event-based encoding
- 1 slide: Top-level architecture overview
- 1 slide: FSM and inference timing
- 1 slide: Delta modulator
- 1 slide: AER handler
- 1 slide: Synapse accumulator
- 1 slide: LIF neuron
- 1 slide: Weight package and fixed-point choices
- 1 slide: Output decoder and LPF bank
- 1 slide: Important design fix, decoder snapshotting
- 2 slides: Verification strategy and unit-test evidence
- 2 slides: Top-level waveform, raster, and prediction results
- 1 slide: Synthesis results
- 1 slide: Physical layout and metrics from Librelane
- 1 slide: Tradeoffs, lessons learned, future work
- 1 slide: Conclusion and questions

## 21. Recommended Appendix Slides
- Detailed fixed-point format choices
- Full top-level FSM diagram
- Example weight tables from the package
- Extra waveforms from Vivado
- Backup slide on how the raster log was generated
- Backup slide clarifying the difference between software SNN simulation and pipelined hardware execution