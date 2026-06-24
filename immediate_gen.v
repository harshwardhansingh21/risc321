    module immediate_gen(
    input [31:0] instr ,
    input [2:0] imm_sel,
    output [31:0] imm_out
);
wire [31:0] i_type_imm;//3'b000
wire [31:0] s_type_imm;//3'b001
wire [31:0] b_type_imm;//3'b010
wire [31:0] u_type_imm;//3'b011
wire [31:0] j_type_imm;//3'b100

assign i_type_imm={{20{instr[31]}},instr[31:20]};//sign-extend the 12-bit immediate to 32 bits
assign s_type_imm={{20{instr[31]}},instr[31:25],instr[11:7]};
assign b_type_imm={{20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0};//the least significant bit is always 0 because branch targets are word-aligned
assign u_type_imm={instr[31:12],12'b0};//the least significant 12 bits are always 0 because U-type immediates are used for upper 20 bits of addresses
assign j_type_imm={{12{instr[31]}},instr[19:12],instr[20],instr[30:21],1'b0};//the least significant bit is always 0 because jump targets are word-aligned

assign imm_out = (imm_sel == 3'b000) ? i_type_imm :
                 (imm_sel == 3'b001) ? s_type_imm :
                 (imm_sel == 3'b010) ? b_type_imm :
                 (imm_sel == 3'b011) ? u_type_imm :
                 (imm_sel == 3'b100) ? j_type_imm :
                 32'b0;

endmodule
