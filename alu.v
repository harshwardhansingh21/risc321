module alu (
    input  wire [31:0] a,           // Operand A (rs1)
    input  wire [31:0] b,           // Operand B (rs2 or immediate)
    input  wire [3:0]  alu_op,      // ALU operation select
    output wire [31:0] result,      // ALU result
    output wire        zero         // Zero flag (for branch decisions)
);

// ALU operation codes (RV32I)
localparam ADD  = 4'b0000;  // ADD / ADDI
localparam SUB  = 4'b0001;  // SUB
localparam AND  = 4'b0010;  // AND / ANDI
localparam OR   = 4'b0011;  // OR / ORI
localparam XOR  = 4'b0100;  // XOR / XORI
localparam SLL  = 4'b0101;  // Shift Left Logical (SLL, SLLI)
localparam SRL  = 4'b0110;  // Shift Right Logical (SRL, SRLI)
localparam SRA  = 4'b0111;  // Shift Right Arithmetic (SRA, SRAI)
localparam SLT  = 4'b1000;  // Set Less Than (SLT, SLTI)
localparam SLTU = 4'b1001;  // Set Less Than Unsigned (SLTU, SLTIU)
localparam PASS_A = 4'b1010; // Pass A through (for LUI, AUIPC)

wire [31:0] add_result, sub_result, and_result, or_result, xor_result;
wire [31:0] sll_result, srl_result, sra_result;
wire [31:0] slt_result, sltu_result;

// Arithmetic operations
assign add_result = a + b;
assign sub_result = a - b;

// Logical operations
assign and_result = a & b;
assign or_result  = a | b;
assign xor_result = a ^ b;

// Shift operations (use only lower 5 bits of b for shift amount)
assign sll_result = a << b[4:0];
assign srl_result = a >> b[4:0];
assign sra_result = $signed(a) >>> b[4:0];

// Set Less Than (signed)
assign slt_result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;

// Set Less Than Unsigned
assign sltu_result = (a < b) ? 32'd1 : 32'd0;

// ALU multiplexer - select output based on alu_op
assign result = (alu_op == ADD)    ? add_result  :
                (alu_op == SUB)    ? sub_result  :
                (alu_op == AND)    ? and_result  :
                (alu_op == OR)     ? or_result   :
                (alu_op == XOR)    ? xor_result  :
                (alu_op == SLL)    ? sll_result  :
                (alu_op == SRL)    ? srl_result  :
                (alu_op == SRA)    ? sra_result  :
                (alu_op == SLT)    ? slt_result  :
                (alu_op == SLTU)   ? sltu_result :
                (alu_op == PASS_A) ? a           :
                32'd0;  // default

// Zero flag: set if result is zero
assign zero = (result == 32'd0);

endmodule
