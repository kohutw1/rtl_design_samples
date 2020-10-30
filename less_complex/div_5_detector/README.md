# How to run simulation and view waveforms

Description of design is located in header of SystemVerilog design file.

Freely available tools required to compile, simulate, and view waveform for this RTL sample:
    1. Compile and simulate using Icarus Verilog: http://iverilog.icarus.com
    2. View waveform using GTKWave: http://gtkwave.sourceforge.net

To compile and simulate:
    ```
    make [SEED=<random_seed>] [NUM_CYCLES=<num_cycles_to_simulate>]
    ```

To view waveform:
    ```
    gtkwave top.gtkw
    ```
