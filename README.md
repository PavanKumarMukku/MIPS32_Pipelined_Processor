# MIPS32_Pipelined_Processor
A 5-stage pipelined MIPS32 processor implemented in Verilog with data forwarding, load-use hazard detection, branch prediction using a 64-entry BTB and 2-bit BHT, and a write-first register file.

## Features
- 32 bit MIPS Processor
- Five stage pipelined
    - Instruction Fetch
    - Instruction Decode
    - Execution
    - Memory Access
    - Write Back
- Dynamic Branch Presiction
    - Branch Target Buffer(BTB)
    - Branch History Table(BHT) - 2-bit saturating counter
- Data HAzards Handling
    - Forwarding Unit and stalls for load instructions
    - Write back to Decode register forwarding
- Control Hazard Reduction using Branch Prediction

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

## Pipeline Architechture
```text
     +-------------------------------+
                |       Instruction Memory      |
                +---------------+---------------+
                                |
                                v
                         +-------------+
                         |     IF      |
                         +-------------+
                                |
                                v
                         +-------------+
                         |     ID      |
                         +-------------+
                                |
                                v
                         +-------------+
                         |     EX      |
                         +-------------+
                                |
                                v
                         +-------------+
                         |    MEM      |
                         +-------------+
                                |
                                v
                         +-------------+
                         |     WB      |
                         +-------------+
```

## Branch Prediction
### Branch Target Buffer
The BTB stores the target addresses of recently  executed branch instructions
- Indexed using lower bits of PC
- Performs tag comparison for validation
- Supplies predicted tagret address during IF stage
- Upload whenever a branch instruction is executed


### Branch History Table
The BHT predicts whether a branch will be **taken** or **Not taken** using **2-bit saturating counter**
It is updated after actual branch outcome is known
- 00 -> Strongly NotTaken
- 01 -> Weakly NotTaken
- 10 -> Weakly Taken
- 11 -> Strongly Taken

## Hazard Handling
### Data Hazards
Resolves Data hazards using :
- EX → EX Forwarding
- MEM → EX Forwarding
- Write Back → Decode Forwarding

### Control Hazards
Minimized using :
- Branch Target Buffer(BTB)
- Branch History Table(BHT)
- Pipeline Flush on Branch Misprediction

## Results

- Successfully executed arithmetic, logical, load/store, and branch instructions.
- Correct implementation of dynamic branch prediction.
- Accurate BTB target prediction.
- Proper BHT updates using 2-bit saturating counters.
- Correct forwarding for dependent instructions.
- Reduced branch penalty compared to static execution.


## Author

**Pavan Kumar Mukku**

B.Tech. Electrical Engineering  
Indian Institute of Technology Madras

