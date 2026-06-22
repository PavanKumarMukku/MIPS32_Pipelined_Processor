module test_MIPS32;

    reg clk1, rst;
    integer k;

    MIPS32_pipeline mips(clk1, rst);

    // Clock Generation
    initial begin
        clk1 = 0;
        rst = 0;

        forever begin
            #5 clk1 = 1;
            #5 clk1 = 0;
        end
    end

    task reset_cpu;
    begin
        rst = 1;
        #20;
        rst = 0;

        mips.PC = 0;
        mips.HALTED = 0;
    end
    endtask

    // Program 1
    task load_program1;
    begin
        // Initialize Register Bank
        for (k = 0; k < 31; k = k + 1)
            mips.RegBank[k] = k;

        // Load Program into Memory
        mips.Mem[0] = 32'h2801000a; // ADDI R1, R0, 10
        mips.Mem[1] = 32'h28020014; // ADDI R2, R0, 20
        mips.Mem[2] = 32'h28030019; // ADDI R3, R0, 25
        mips.Mem[3] = 32'h00222000; // AND R4, R1, R2
        mips.Mem[4] = 32'h00832800; // AND R5, R4, R3
        mips.Mem [7]= 32'hfc000000; // HLT

        // Initialize Processor
        mips.HALTED = 0;
        mips.PC = 0;
    end
    endtask

    // Program 2
    task load_program2;
    begin
        // Initialize Register Bank
        for (k = 0; k < 31; k = k + 1)
            mips.RegBank[k] = k;

        // Load Program into Memory
        mips.Mem[0] = 32'h28010078; // ADDI R1, R0, 120
        mips.Mem[1] = 32'h20220000; // LW R2, 0(R1)
        mips.Mem[2] = 32'h2842002d; // ADDI R2, R2, 45
        mips.Mem[3] = 32'h24220001; // SW R2, 1(R1)
        mips.Mem [7]= 32'hfc000000; // HLT

        // Data Memory
        mips.Mem[120] = 85;

        // Initialize Processor
        mips.PC = 0;
        mips.HALTED = 0;
    end
    endtask

    // Program 3 
    task load_program3;
    begin
        // Initialize Register Bank
        for (k = 0; k < 31; k = k + 1)
            mips.RegBank[k] = k;

        // Load Program into Memory
        mips.Mem [0] = 32'h280a00c8; // ADDI R10, R0, 200
        mips.Mem [1] = 32'h28020001; // ADDI R2, R0, 1
        mips.Mem [2] = 32'h21430000; // LW R3, 0(R10)
        mips.Mem [3] = 32'h14431000; // LOOP : MUL R2, R2, R3
        mips.Mem [4] = 32'h2c630001; // SUBI R3, R3, 1
        mips.Mem [5] = 32'h3460fffd; // BNEQZ R3, LOOP ( offset -3)
        mips.Mem [6] = 32'h2542fffe; // SW R2, -2(R10)
        mips.Mem [7] = 32'hfc000000; // HLT

        // Data Memory
        mips.Mem[200] = 7;

        // Initialize Processor
        mips.PC = 0;
        mips.HALTED = 0;
    end
    endtask


    initial begin

        // Execute Program 1
        reset_cpu();
        load_program1();

        #280;
        for (k = 0; k < 6; k = k + 1)
            $display("R%1d = %2d", k, mips.RegBank[k]);

        // Execute Program 2
        reset_cpu();
        load_program2();

        #500;
        $display("Mem[120] = %4d", mips.Mem[120]);
        $display("Mem[121] = %4d", mips.Mem[121]);

        // Execute Program 3
        reset_cpu();
        load_program3();

        #2000;
        $display("Mem[200] = %2d", mips.Mem[200]);
        $display("Mem[198] = %6d", mips.Mem[198]);
    end

    // Dump Waveforms
    initial begin
        $dumpfile("mips.vcd");
        $dumpvars(0, test_MIPS32);
        // $monitor("R2 : %4d", mips.RegBank[2]);
    end

    
    // Finish Simulation
    initial begin
        #3000 $finish;
    end

endmodule