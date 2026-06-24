module control_unit(
    input [31:0] instruction,
    output reg reg_we,
    output reg alu_src,
    output reg [3:0] alu_op,    
    output reg mem_we,
    output reg mem_read,
    output reg mem_to_reg,
    output reg [2:0]imm_sel,
    output reg pc_src
);
wire [6:0] opcode=instruction[6:0];
wire [2:0] funct3=instruction[14:12];
wire [6:0] funct7=instruction[31:25];

always@(*) begin
    reg_we=0;
    alu_src=0;
    alu_op=4'b0000;
    mem_we=0;
    mem_read=0;
    mem_to_reg=0;
    imm_sel=0;
    pc_src=0;

    case(opcode)
    7'b0110011: begin//R TYPE
    reg_we=1;
    alu_src=0;
    case(funct3)
    3'b000: alu_op = funct7[5] ? 4'b0001 : 4'b0000; // SUB : ADD
                3'b001: alu_op = 4'b0101;  // SLL
                3'b010: alu_op = 4'b1000;  // SLT
                3'b011: alu_op = 4'b1001;  // SLTU
                3'b100: alu_op = 4'b0100;  // XOR
                3'b101: alu_op = funct7[5] ? 4'b0111 : 4'b0110; // SRA : SRL
                3'b110: alu_op = 4'b0011;  // OR
                3'b111: alu_op = 4'b0010;  // AND
    endcase
    end
    
    7'b0010011: begin//I TYPE
    reg_we=1;
    alu_src=1;
    case(funct3)
    3'b000: alu_op = 4'b0000;  // ADDI
                3'b001: alu_op = 4'b0101;  // SLLI
                3'b010: alu_op = 4'b1000;  // SLTI
                3'b011: alu_op = 4'b1001;  // SLTIU
                3'b100: alu_op = 4'b0100;  // XORI
                3'b101: alu_op = instruction[30] ? 4'b0111 : 4'b0110; // SRAI : SRLI
                3'b110: alu_op = 4'b0011;  // ORI
                3'b111: alu_op = 4'b0010;  // ANDI


    endcase
    end

    7'b0000011: begin//LOAD
    reg_we=1;
    alu_src=1;
    mem_read=1;
    mem_to_reg=1;
    alu_op=4'b0000; // ADD for address calculation
    end

    7'b0100011: begin//STORE
    alu_src=1;
    mem_we=1;
    imm_sel=3'b001; // S-type immediate 
    alu_op=4'b0000; // ADD for address calculation

    end

    7'b1100011: begin//BRANCH
    imm_sel=3'b010; // B-type immediate
    pc_src=1; // PC source is the branch target
    case(funct3)
    3'b000 : alu_op = 4'b0001; // BEQ uses SUB to compare
    3'b001 : alu_op = 4'b0001; // BNE uses SUB to compare
    3'b100 : alu_op = 4'b1000; // BLT uses SLT
    3'b101 : alu_op = 4'b1000; // BGE uses SLT
    3'b110 : alu_op = 4'b1001; // BLTU uses SLTU
    3'b111 : alu_op = 4'b1001; // BGEU uses SLTU
    endcase
    end

    7'b1101111: begin//JAL
    reg_we=1;
    alu_src=1;
    imm_sel=3'b011; // J-type immediate
    pc_src=1; // PC source is the jump target
    alu_op=4'b1010; // PASS B THROUGH FOR JALR INSTRUCTION
    end

    7'b1100111: begin//JALR
    reg_we=1;
    alu_src=1;
    alu_op=4'b0000; // ADD for address calculation  
    imm_sel=3'b100; // I-type immediate
    pc_src=1; // PC source is the jump target
    end

    7'b0010111: begin//AUIPC
    reg_we=1;
    alu_src=1;
    alu_op=4'b0000; // ADD for address calculation
    imm_sel=3'b011; // U-type immediate (upper 20 bits of the instruction)
    end

    7'b0110111: begin//LUI
    reg_we=1;
    alu_src=1;
    alu_op=4'b1010; // PASS B THROUGH FOR LUI INSTRUCTION
    imm_sel=3'b011; // U-type immediate (upper 20 bits of the instruction)
    end

    endcase
end


endmodule
