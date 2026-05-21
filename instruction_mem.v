module instruction_mem (
    input wire [31:0] addr,
    output wire [31:0] instr
);

// Number of 32-bit instructions stored in ROM.
localparam MEM_WORDS = 256;

reg [31:0] rom [0:MEM_WORDS-1];
wire [31:0] word_index = addr[31:2]; // word-aligned address

assign instr = rom[word_index];

initial begin
    integer i;
    for (i = 0; i < MEM_WORDS; i = i + 1) begin
        rom[i] = 32'h0000_0013; // RISC-V NOP: addi x0, x0, 0
    end

    // Example program initialization. Replace these values with your own
    // instruction words for the RISC-V 32-bit processor.
    rom[0] = 32'h0040_0093; // addi x1, x0, 4
    rom[1] = 32'h0080_0113; // addi x2, x0, 8
    rom[2] = 32'h0020_81b3; // add x3, x1, x2
    rom[3] = 32'h0010_0073; // ebreak (breakpoint) or use other instruction
end

endmodule
