`default_nettype none

module bht (
    input wire clk, rst,
    // Read Ports[IF]
    input wire [31:0] read_pc,
    output wire predict_taken,
    // Write Ports[EX]
    input wire updated_en,
    input [31:0] updated_pc,
    input wire branch_taken
);
    /*
    Implements a 64-entry Branch History Table (BHT) using 2-bit saturating
    counters for dynamic branch prediction in a pipelined processor.
    
    - Uses 2-bit saturating counters.
    
    IF Stage :
        * The lower 6 bits of the Program Counter (PC) are used to index the BHT.
        * The MSB of the selected 2-bit counter determines the prediction:
              0 -> Predict Not Taken
              1 -> Predict Taken
    EX Stage :
        * When the actual branch outcome becomes available, the corresponding counter is updated.
        * If the branch was taken, the counter increments (up to 3).
        * If the branch was not taken, the counter decrements (down to 0).
    
    00[Strongly Not taken] 01[Weakly Not Taken] 10[Weakly Taken] 11[Strongly Taken]          
    */
    
    reg [1:0] bht_table [0:63];
    integer i;

    wire [5:0] read_index    = read_pc [5:0];
    wire [5:0] updated_index = updated_pc [5:0];

    // If MSB of the state is 1 then prediction is 1 else it is 0
    assign predict_taken = bht_table[read_index][1];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 64; i=i+1) begin
                // Initialize to Weakly Not Taken
                // If taken goes to 10, else goes to 00
                bht_table[i] <= 2'b01;
            end
        end
        else if (updated_en) begin
            if (branch_taken) begin 
                bht_table[updated_index] <= (bht_table[updated_index] == 2'b11) ? 2'b11 : bht_table[updated_index] + 1'b1;
            end
            else begin
                bht_table[updated_index] <= (bht_table[updated_index] == 2'b00) ? 2'b00 : bht_table[updated_index] - 1'b1;
            end
        end
    end
endmodule
