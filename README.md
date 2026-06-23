# MIPS32_Pipelined_Processor
A 5-stage pipelined MIPS32 processor implemented in Verilog with data forwarding, load-use hazard detection, branch prediction using a 64-entry BTB and 2-bit BHT, and a write-first register file.

## Features
- 32 bit MIPS Processor
- Five stage pipelined
-   - Instruction Fetch
    - Instruction Decode
    - Execution
    - Memory Access
    - Write Back

## Project Structure
```text
MIPS32-Processor/
│
├── rtl/
│    ├── processor.v
│    ├── btb.v
│    ├── bht.v
├── testbench/
│    └── tb.v
├── waveforms/
│    └── mips.vcd
└── README.md
```
