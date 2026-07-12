module instruction_mem (
    input  wire [31:0] addr,
    output wire [31:0] instr
);

reg [31:0] mem [0:255];

assign instr = mem[addr[9:2]];

integer i;

initial begin
    mem[0]  = 32'h00500093;   // addi x1, x0, 5     x1=5
    mem[1]  = 32'h00300113;   // addi x2, x0, 3     x2=3
    mem[2]  = 32'h002081b3;   // add  x3, x1, x2    x3=8
    mem[3] = 32'h40208233;    // sub  x4, x1, x2     x4=2  
    mem[4]  = 32'h0030f2b3;   // and  x5, x1, x2    x5=1
    mem[5]  = 32'h0030e333;   // or   x6, x1, x2    x6=7
    mem[6]  = 32'h0000006f;   // jal  x0, 0  halt
    for (i = 7; i < 256; i = i + 1)
        mem[i] = 32'h0000006f;
end

endmodule