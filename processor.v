`default_nettype none

module MIPS32_pipeline (
    input clk,
    input rst              // Active high synchronous reset
);
    integer i;
    // Between Instruction Fetch and Instruction Decode Stages
    reg [31:0] PC, IF_ID_IR, IF_ID_NPC;
    reg [31:0] IF_ID_PC, IF_ID_pred_target;    // Tracking PC for predection acrosee stages
    reg IF_ID_pred_taken;

    // Between Instruction Decode and Execution Stages
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
    reg [2:0]  ID_EX_type, EX_MEM_type, MEM_WB_type;
    reg ID_EX_RegWrite;                        // for Data Hazard
    reg [31:0] ID_EX_PC, ID_EX_pred_target;
    reg ID_EX_pred_taken;

    // Between Execution and Memory Stages
    reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B;
    reg  EX_MEM_cond;
    reg EX_MEM_RegWrite;                       // for Data Hazard

    // Between Memory and Write Back Stages
    reg [31:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD;
    reg MEM_WB_RegWrite;                       // for Data Hazard

    reg [31:0] RegBank [0:31];                 // Register Bank(32 x 32)
    reg [31:0] Mem [0:1023];                   // 1024 x 32 memory  

    // r - type and i - type instructions
    parameter ADD = 6'b000000, SUB = 6'b000001, AND  = 6'b000010, OR   = 6'b000011, SLT  = 6'b000100, MUL   = 6'b000101, HLT  = 6'b111111,
              LW  = 6'b001000, SW  = 6'b001001, ADDI = 6'b001010, SUBI = 6'b001011, SLTI = 6'b001100, BNEQZ = 6'b001101, BEQZ = 6'b001110,
              NOOPR = 6'b101100;
    
    // Types of instructions
    parameter RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010, STORE = 3'b011, BRANCH = 3'b100, HALT = 3'b101;
    parameter NOP = 3'd110;                    // For Hazards

    reg HALTED;                                // Set after HLT instruction is completed

    // Branch Prediction Wires and Registers
    wire btb_hit;
    wire [31:0] predicted_target;
    wire predict_taken;

    // Misprediction Evaluation Signals in EX Stage
    wire actual_branch_taken;
    wire [31:0] actual_target_val;
    wire misprediction;
    wire [31:0] corrected_pc;
    wire btb_bht_update_en;

    // Destination Registers fo forwarding
    reg [4:0] ID_EX_Dest;
    reg [4:0] EX_MEM_Dest;
    reg [4:0] MEM_WB_Dest;

    // If hazard occurs for load instruction
    wire load_stall;
    assign load_stall = (ID_EX_type == LOAD) && ((ID_EX_IR[20:16] == IF_ID_IR[25:21]) || (ID_EX_IR[20:16] == IF_ID_IR[20:16])) && (ID_EX_IR[20:16] != 5'b00000);

    // Early Halt Detection
    wire stop_fetch;
    assign stop_fetch = (IF_ID_IR[31:26] == HLT) || (ID_EX_type == HALT) || (EX_MEM_type == HALT) || (MEM_WB_type == HALT) || HALTED;

    // Combinational WB to ID Register Forwarding
    wire [31:0] wb_data = (MEM_WB_type == LOAD) ? MEM_WB_LMD : MEM_WB_ALUOut;
    wire [31:0] rs_data = (IF_ID_IR[25:21] == 5'b00000) ? 32'h00000000 : 
                          (MEM_WB_RegWrite && (MEM_WB_Dest == IF_ID_IR[25:21])) ? wb_data : 
                          RegBank[IF_ID_IR[25:21]];
                          
    wire [31:0] rt_data = (IF_ID_IR[20:16] == 5'b00000) ? 32'h00000000 : 
                          (MEM_WB_RegWrite && (MEM_WB_Dest == IF_ID_IR[20:16])) ? wb_data : 
                          RegBank[IF_ID_IR[20:16]];

    // Instantiate bht and btb modules
    btb u_btb (
        .clk(clk),
        .rst(rst),
        .read_pc(PC),
        .btb_hit(btb_hit),
        .predicted_target(predicted_target),
        .updated_en(btb_bht_update_en),
        .updated_pc(ID_EX_PC),
        .actual_target(actual_target_val)
    );

    bht u_bht (
        .clk(clk),
        .rst(rst),
        .read_pc(PC),
        .predict_taken(predict_taken),
        .updated_en(btb_bht_update_en),
        .updated_pc(ID_EX_PC),
        .branch_taken(actual_branch_taken)
    );
    

    // Instruction Fetch[IF] Stage
    always @(posedge clk) begin
        if (rst) begin
            PC                <= 32'h00000000;  // Reset Address
            IF_ID_IR          <= {NOOPR,26'b0}; // No operation
            IF_ID_NPC         <= 32'h00000000;
            IF_ID_PC          <= 32'h00000000;
            IF_ID_pred_taken  <= 1'b0;
            IF_ID_pred_target <= 32'h00000000;
        end
        else if(misprediction) begin
            PC                <= corrected_pc;
            IF_ID_IR          <= {NOOPR,26'b0}; // Flush with NOP
            IF_ID_NPC         <= 32'h00000000;
            IF_ID_PC          <= 32'h00000000;
            IF_ID_pred_taken  <= 1'b0;
            IF_ID_pred_target <= 32'h00000000;
        end
        else if(load_stall) begin
            PC        <= PC;
            IF_ID_IR  <= IF_ID_IR;
            IF_ID_NPC <= IF_ID_NPC;
            IF_ID_PC          <= IF_ID_PC;
            IF_ID_pred_taken  <= IF_ID_pred_taken;
            IF_ID_pred_target <= IF_ID_pred_target;
        end
        else if (HALTED == 0) begin
            if (stop_fetch) begin
                // Freeze PC and inject NOPs behind the HLT instruction 
                PC                <= PC;
                IF_ID_IR          <= {NOOPR,26'b0};
                IF_ID_NPC         <= IF_ID_NPC;
                IF_ID_PC          <= IF_ID_PC;
                IF_ID_pred_taken  <= 1'b0;
                IF_ID_pred_target <= 32'h00000000;
            end else begin
                IF_ID_IR          <= Mem[PC];
                IF_ID_NPC         <= PC + 1;
                IF_ID_PC          <= PC;
                IF_ID_pred_taken  <= btb_hit && predict_taken;
                IF_ID_pred_target <= predicted_target;
                
                // Next PC Generation
                if (btb_hit && predict_taken) begin
                    PC <= predicted_target;
                end else begin
                    PC <= PC + 1;
                end
            end
        end
    end

    // Instruction Decode[ID] Stage
    always @(posedge clk) begin
        if (rst) begin
            ID_EX_A           <= 32'h00000000;
            ID_EX_B           <= 32'h00000000;
            ID_EX_NPC         <= 32'h00000000;
            ID_EX_IR          <= 32'h00000000;
            ID_EX_Imm         <= 32'h00000000;
            ID_EX_type        <= NOP;               
            ID_EX_RegWrite    <= 1'b0;
            ID_EX_Dest        <= 5'b00000;
            ID_EX_PC          <= 32'h00000000;
            ID_EX_pred_taken  <= 1'b0;
            ID_EX_pred_target <= 32'h00000000;
        end
        else if (misprediction) begin
            // Flush ID/EX register because this instruction is from the wrong spec path
            ID_EX_A           <= 32'h00000000;
            ID_EX_B           <= 32'h00000000;
            ID_EX_NPC         <= 32'h00000000;
            ID_EX_IR          <= 32'h00000000;
            ID_EX_Imm         <= 32'h00000000;
            ID_EX_type        <= NOP;
            ID_EX_RegWrite    <= 1'b0;
            ID_EX_Dest        <= 5'b00000;
            ID_EX_PC          <= 32'h00000000;
            ID_EX_pred_taken  <= 1'b0;
            ID_EX_pred_target <= 32'h00000000;
        end
        else if(load_stall) begin
            ID_EX_RegWrite <= 0;
            ID_EX_type     <= NOP;
        end
        else if (HALTED == 0) begin
            ID_EX_A <= rs_data;
            ID_EX_B <= rt_data;

            ID_EX_NPC         <= IF_ID_NPC;
            ID_EX_IR          <= IF_ID_IR;
            ID_EX_Imm         <= {{16{IF_ID_IR[15]}}, {IF_ID_IR[15 : 0]}};
            ID_EX_PC          <= IF_ID_PC;
            ID_EX_pred_taken  <= IF_ID_pred_taken;
            ID_EX_pred_target <= IF_ID_pred_target;

            case (IF_ID_IR[31 : 26])
                ADD, SUB, AND, OR, MUL, SLT : begin
                    ID_EX_type     <= RR_ALU;
                    ID_EX_RegWrite <= 1'b1;
                    ID_EX_Dest     <= IF_ID_IR[15:11];
                end 
                ADDI, SUBI, SLTI            : begin
                    ID_EX_type     <= RM_ALU;
                    ID_EX_RegWrite <= 1'b1;
                    ID_EX_Dest     <= IF_ID_IR[20:16];
                end 
                LW                          : begin
                    ID_EX_type     <= LOAD;
                    ID_EX_RegWrite <= 1'b1;
                    ID_EX_Dest     <= IF_ID_IR[20:16];
                end
                SW                          : begin
                    ID_EX_type     <= STORE;
                    ID_EX_RegWrite <= 1'b0;
                    ID_EX_Dest     <= 5'b00000;
                end
                BNEQZ, BEQZ                 : begin
                    ID_EX_type     <= BRANCH;
                    ID_EX_RegWrite <= 1'b0;
                    ID_EX_Dest     <= 5'b00000;
                end
                HLT                         : begin
                    ID_EX_type     <= HALT;
                    ID_EX_RegWrite <= 1'b0;
                    ID_EX_Dest     <= 5'b00000;
                end
                default                     : begin
                    ID_EX_type     <= NOP;
                    ID_EX_RegWrite <= 1'b0;
                    ID_EX_Dest     <= 5'b00000;
                end
            endcase
        end
    end

    // Execution[EX] Stage
    assign actual_branch_taken = (ID_EX_IR [31:26] == BEQZ) ? (forwardA == 32'h0) : (ID_EX_IR [31:26] == BNEQZ) ? (forwardA != 32'h0) : 1'b0;
    assign actual_target_val = ID_EX_NPC + ID_EX_Imm;
    // misprediction when the prediction is wrong or the prediction is correct but the address is wrong
    assign misprediction = (ID_EX_type == BRANCH) && ((ID_EX_pred_taken != actual_branch_taken) || (actual_branch_taken && (ID_EX_pred_target != actual_target_val)));
    assign corrected_pc = actual_branch_taken ? actual_target_val : ID_EX_NPC;
    //Enabling
    assign btb_bht_update_en = (ID_EX_type == BRANCH) && (HALTED == 0);
    // Forwarding Unit
    reg[31 : 0] forwardA, forwardB;
    always @(*) begin
        // default values in registers A and B
        forwardA = ID_EX_A;
        forwardB = ID_EX_B;

        // Forward A(rs)
        // EX Hazard
        if(EX_MEM_RegWrite && (EX_MEM_Dest != 5'b00000) && (EX_MEM_Dest == ID_EX_IR[25 : 21])) begin
            forwardA = EX_MEM_ALUOut;
        end
        // Mem Hazard
        else if(MEM_WB_RegWrite && (MEM_WB_Dest != 5'b00000) && (MEM_WB_Dest == ID_EX_IR[25 : 21])) begin
            forwardA = (MEM_WB_type == LOAD) ? MEM_WB_LMD : MEM_WB_ALUOut;
        end

        // Forward B(rt)
        // EX Hazard
        if (EX_MEM_RegWrite && (EX_MEM_Dest != 5'b00000) && (EX_MEM_Dest == ID_EX_IR[20 : 16])) begin
            forwardB = EX_MEM_ALUOut;
        end
        // Mem Hazard
        else if (MEM_WB_RegWrite && (MEM_WB_Dest != 5'b00000) && (MEM_WB_Dest == ID_EX_IR[20 : 16])) begin
            forwardB = (MEM_WB_type == LOAD) ? MEM_WB_LMD : MEM_WB_ALUOut; 
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            EX_MEM_type     <= NOP;
            EX_MEM_IR       <= 32'h00000000;
            EX_MEM_ALUOut   <= 32'h00000000;
            EX_MEM_B        <= 32'h00000000;
            EX_MEM_cond     <= 1'b0;
            EX_MEM_RegWrite <= 1'b0;
            EX_MEM_Dest     <= 5'b00000;
        end
        else if (HALTED == 0) begin
            EX_MEM_type     <= ID_EX_type;
            EX_MEM_IR       <= ID_EX_IR;
            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_Dest     <= ID_EX_Dest;

            case (ID_EX_type)
                RR_ALU : begin
                    case (ID_EX_IR[31 : 26])
                        ADD : EX_MEM_ALUOut <= forwardA + forwardB;
                        SUB : EX_MEM_ALUOut <= forwardA - forwardB;
                        AND : EX_MEM_ALUOut <= forwardA & forwardB; 
                        OR  : EX_MEM_ALUOut <= forwardA | forwardB; 
                        SLT : EX_MEM_ALUOut <= forwardA < forwardB; 
                        MUL : EX_MEM_ALUOut <= forwardA * forwardB;  
                        default: EX_MEM_ALUOut <= 32'hxxxxxxxx;
                    endcase
                end

                RM_ALU : begin
                    case (ID_EX_IR[31 : 26])
                        ADDI : EX_MEM_ALUOut <= forwardA + ID_EX_Imm; 
                        SUBI : EX_MEM_ALUOut <= forwardA - ID_EX_Imm; 
                        SLTI : EX_MEM_ALUOut <= forwardA < ID_EX_Imm; 
                        default: EX_MEM_ALUOut <= 32'hxxxxxxxx;
                    endcase
                end

                LOAD, STORE : begin
                    EX_MEM_ALUOut <= forwardA + ID_EX_Imm;
                    EX_MEM_B      <= forwardB;
                end

                BRANCH : begin
                    EX_MEM_ALUOut <= ID_EX_NPC + ID_EX_Imm;
                    EX_MEM_cond   <= (forwardA == 0);
                end 
            endcase
        end
    end

    // Memory[MEM] Stage
    always @(posedge clk) begin
        if (rst) begin
            MEM_WB_type     <= NOP;
            MEM_WB_IR       <= 32'h00000000;
            MEM_WB_ALUOut   <= 32'h00000000;
            MEM_WB_LMD      <= 32'h00000000;
            MEM_WB_RegWrite <= 1'b0;
            MEM_WB_Dest     <= 5'b00000;
        end
        else if (HALTED == 0) begin
            MEM_WB_type     <= EX_MEM_type;
            MEM_WB_IR       <= EX_MEM_IR;
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_Dest     <= EX_MEM_Dest;

            case (EX_MEM_type)
                RR_ALU, RM_ALU : MEM_WB_ALUOut <= EX_MEM_ALUOut;
                LOAD           : MEM_WB_LMD    <= Mem[EX_MEM_ALUOut];
                STORE          : Mem[EX_MEM_ALUOut] <= EX_MEM_B;
                default: ;
            endcase
        end
    end

    // Write Back[WB] Stage
    always @(posedge clk) begin
        if (rst) begin
            HALTED <= 1'b0;
            // Clear all registers in the Register Bank to prevent simulation 'X' states
            for (i = 0; i < 32; i = i + 1) begin
                RegBank[i] <= 32'h00000000;
            end
        end
        else if (MEM_WB_RegWrite && (MEM_WB_Dest != 5'b00000)) begin
            RegBank[MEM_WB_Dest] <= (MEM_WB_type == LOAD) ? MEM_WB_LMD : MEM_WB_ALUOut;
        end
        else if (MEM_WB_type == HALT) begin
            HALTED <= 1'b1;
        end      
    end
endmodule