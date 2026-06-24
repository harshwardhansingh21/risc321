module instruction_mem (
    input  wire [31:0] addr,
    output wire [31:0] instr
);

reg [31:0] mem [0:255];

assign instr = mem[addr[9:2]];

initial begin
    mem[0] = 32'h00000093;    // addi x1, x0, 0   (x1 = 0)
    mem[1] = 32'h00100113;    // addi x2, x0, 1   (x2 = 1)
    mem[2] = 32'h002081b3;    // add  x3, x1, x2  (x3 = x1 + x2 = 1)

    // Halt pattern: JAL x0, 0 — jumps to itself forever.
    // rd=x0 discards the return address write, offset=0 means
    // target == current PC, so the CPU parks here safely instead
    // of fetching undefined/uninitialized opcodes.
    mem[3] = 32'h0000006f;    // jal x0, 0

    // Fill remainder explicitly with the same halt pattern so
    // nothing is left to simulator-default behavior.
    for (int i = 4; i < 256; i = i + 1)
        mem[i] = 32'h0000006f; // jal x0, 0
end

endmodule


