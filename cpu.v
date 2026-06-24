module cpu (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc_out_dbg,
    output wire [31:0] instruction_dbg,
    output wire [31:0] alu_result_dbg,
    output wire [31:0] rs2_data_dbg,
    output wire        mem_we_dbg,
    output wire        mem_read_dbg
);

wire [31:0] pc_out;
wire [31:0] instruction;

// control_unit outputs — exactly matching control_unit.v ports
wire        reg_we;
wire        alu_src;
wire [3:0]  alu_op;
wire        mem_we;
wire        mem_read;
wire        mem_to_reg;
wire [2:0]  imm_sel;
wire        pc_src_ctrl;

// register addresses extracted directly from instruction
wire [4:0]  rs1_addr = instruction[19:15];
wire [4:0]  rs2_addr = instruction[24:20];
wire [4:0]  rd_addr  = instruction[11:7];
wire [6:0]  opcode   = instruction[6:0];
wire [2:0]  funct3   = instruction[14:12];

wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [31:0] immediate;
wire [31:0] alu_a;
wire [31:0] alu_b;
wire [31:0] alu_result;
wire        alu_zero;
wire [31:0] mem_rd_data;
wire [31:0] rd_data;
wire [31:0] pc_target;
wire        actual_pc_src;

wire is_branch = (opcode == 7'b1100011);
wire is_jal    = (opcode == 7'b1101111);
wire is_jalr   = (opcode == 7'b1100111);
wire is_auipc  = (opcode == 7'b0010111);
wire is_jump   = is_jal | is_jalr;

assign alu_a = is_auipc ? pc_out : rs1_data;
assign alu_b = alu_src ? immediate : rs2_data;

wire branch_condition =
    (funct3 == 3'b000) ?  alu_zero       :
    (funct3 == 3'b001) ? ~alu_zero       :
    (funct3 == 3'b100) ?  alu_result[0]  :
    (funct3 == 3'b101) ? ~alu_result[0]  :
    (funct3 == 3'b110) ?  alu_result[0]  :
    (funct3 == 3'b111) ? ~alu_result[0]  :
    1'b0;

assign pc_target     = is_jalr ? {alu_result[31:1], 1'b0} : pc_out + immediate;
assign actual_pc_src = (is_branch & branch_condition) | is_jal | is_jalr;
assign rd_data       = is_jump    ? (pc_out + 32'd4) :
                       mem_to_reg ? mem_rd_data       :
                                    alu_result;

pc pc_inst (
    .clk       (clk),
    .rst       (rst),
    .pc_src    (actual_pc_src),
    .pc_target (pc_target),
    .pc_out    (pc_out)
);

instruction_mem imem_inst (
    .addr  (pc_out),
    .instr (instruction)
);

// control_unit — only the ports it actually declares
control_unit ctrl_inst (
    .instruction (instruction),
    .reg_we      (reg_we),
    .alu_src     (alu_src),
    .alu_op      (alu_op),
    .mem_we      (mem_we),
    .mem_read    (mem_read),
    .mem_to_reg  (mem_to_reg),
    .imm_sel     (imm_sel),
    .pc_src      (pc_src_ctrl)
);

register_file regfile_inst (
    .clk      (clk),
    .we       (reg_we),
    .rs1_addr (rs1_addr),
    .rs2_addr (rs2_addr),
    .rd_addr  (rd_addr),
    .rd_data  (rd_data),
    .rs1_data (rs1_data),
    .rs2_data (rs2_data)
);

immediate_gen imm_gen_inst (
    .instr   (instruction),
    .imm_sel (imm_sel),
    .imm_out (immediate)
);

alu alu_inst (
    .a      (alu_a),
    .b      (alu_b),
    .alu_op (alu_op),
    .result (alu_result),
    .zero   (alu_zero)
);

data_mem dmem_inst (
    .clk  (clk),
    .we   (mem_we),
    .addr (alu_result),
    .din  (rs2_data),
    .dout (mem_rd_data)
);

assign pc_out_dbg      = pc_out;
assign instruction_dbg = instruction;
assign alu_result_dbg  = alu_result;
assign rs2_data_dbg    = rs2_data;
assign mem_we_dbg      = mem_we;
assign mem_read_dbg    = mem_read;

endmodule
