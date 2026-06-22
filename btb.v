`default_nettype none

module btb (
    input wire clk, rst,
    // Read Ports[IF]
    input wire [31:0] read_pc,
    output wire btb_hit,
    output wire [31:0] predicted_target,
    // Write Ports[EX]
    input wire updated_en,
    input wire [31:0] updated_pc, actual_target
);
    reg [31:0] target_table [0:63];
    reg [25:0] tag_table [0:63];
    reg valid_table [0:63];
    integer i;

    wire [5:0]  read_index    = read_pc [5:0];
    wire [5:0]  updated_index = updated_pc [5:0];
    wire [25:0] read_tag      = read_pc [31:6];
    wire [25:0] updated_tag   = updated_pc [31:6];

    assign btb_hit          = valid_table[read_index] && (tag_table[read_index] == read_tag);
    assign predicted_target = target_table[read_index];

    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i<64; i=i+1) begin
                valid_table[i]  <= 1'b0;
                tag_table[i]    <= 26'b0;
                target_table[i] <= 32'b0;
            end
        end
        else if (updated_en) begin
            valid_table[updated_index]  <= 1'b1;
            tag_table[updated_index]    <= updated_tag;
            target_table[updated_index] <= actual_target;
        end
    end
endmodule