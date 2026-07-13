module cpu_pipeline (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc_out_dbg,
    output wire [31:0] instruction_dbg,
    output wire [31:0] alu_result_dbg,
    output wire        mem_we_dbg,
    output wire        mem_read_dbg
);

// ═══════════════════════════════════════════════════════════════
// IF STAGE WIRES
// ═══════════════════════════════════════════════════════════════
wire [31:0] pc_out;
wire [31:0] pc_plus4;
wire [31:0] pc_target;
wire        actual_pc_src;
wire        pc_write;
wire [31:0] if_instruction;

assign pc_plus4 = pc_out + 32'd4;

// ═══════════════════════════════════════════════════════════════
// IF/ID PIPELINE REGISTER OUTPUTS
// ═══════════════════════════════════════════════════════════════
wire [31:0] if_id_instr;
wire [31:0] if_id_pc;
wire [31:0] if_id_pc_plus4;

// ═══════════════════════════════════════════════════════════════
// ID STAGE WIRES
// ═══════════════════════════════════════════════════════════════
wire [4:0]  if_id_rs1_addr  = if_id_instr[19:15];
wire [4:0]  if_id_rs2_addr  = if_id_instr[24:20];
wire [4:0]  if_id_rd_addr   = if_id_instr[11:7];
wire [6:0]  if_id_opcode    = if_id_instr[6:0];

wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [31:0] immediate;

wire        id_reg_we;
wire        id_alu_src;
wire [3:0]  id_alu_op;
wire        id_mem_we;
wire        id_mem_read;
wire        id_mem_to_reg;
wire [2:0]  id_imm_sel;
wire        id_pc_src;

// ═══════════════════════════════════════════════════════════════
// IF/ID AND ID/EX FLUSH/WRITE CONTROL
// ═══════════════════════════════════════════════════════════════
wire        if_id_write;
wire        if_id_flush;
wire        id_ex_flush;

// ═══════════════════════════════════════════════════════════════
// ID/EX PIPELINE REGISTER OUTPUTS
// ═══════════════════════════════════════════════════════════════
wire [31:0] id_ex_rs1_data;
wire [31:0] id_ex_rs2_data;
wire [31:0] id_ex_immediate;
wire [31:0] id_ex_pc;
wire [31:0] id_ex_pc_plus4;
wire [4:0]  id_ex_rs1_addr;
wire [4:0]  id_ex_rs2_addr;
wire [4:0]  id_ex_rd_addr;
wire [3:0]  id_ex_alu_op;
wire        id_ex_alu_src;
wire        id_ex_mem_we;
wire        id_ex_mem_read;
wire        id_ex_mem_to_reg;
wire        id_ex_reg_we;

// ═══════════════════════════════════════════════════════════════
// EX STAGE WIRES
// ═══════════════════════════════════════════════════════════════
wire [1:0]  forward_a;
wire [1:0]  forward_b;

wire [31:0] ex_mem_alu_result;  // forward declaration — used in EX muxes
wire [31:0] wb_rd_data;         // forward declaration — used in EX muxes

wire [31:0] alu_input_a_fwd;
wire [31:0] alu_input_b_fwd;
wire [31:0] alu_input_a;
wire [31:0] alu_input_b;
wire [31:0] alu_result;
wire        alu_zero;

wire [6:0]  id_ex_opcode   = id_ex_immediate[6:0]; // NOTE: opcode carried via instr
// Here we use a dedicated approach: decode from if_id for hazard,
// and pass is_jump flag through pipeline as a control signal.

wire        id_is_branch   = (if_id_opcode == 7'b1100011);
wire        id_is_jal      = (if_id_opcode == 7'b1101111);
wire        id_is_jalr     = (if_id_opcode == 7'b1100111);
wire        id_is_auipc    = (if_id_opcode == 7'b0010111);
wire        id_is_jump     = id_is_jal | id_is_jalr;

// ── Forwarding mux — ALU input A ──────────────────────────────
assign alu_input_a_fwd =
    (forward_a == 2'b10) ? ex_mem_alu_result :
    (forward_a == 2'b01) ? wb_rd_data        :
                           id_ex_rs1_data;

// AUIPC override — ALU input A becomes PC
assign alu_input_a = id_is_auipc ? id_ex_pc : alu_input_a_fwd;

// ── Forwarding mux — ALU input B candidate ────────────────────
assign alu_input_b_fwd =
    (forward_b == 2'b10) ? ex_mem_alu_result :
    (forward_b == 2'b01) ? wb_rd_data        :
                           id_ex_rs2_data;

// ── ALU B final mux — register or immediate ───────────────────
assign alu_input_b = id_ex_alu_src ? id_ex_immediate : alu_input_b_fwd;

// ── Branch condition ──────────────────────────────────────────
wire [2:0]  id_ex_funct3;

wire branch_taken;
assign branch_taken = (id_is_branch & id_pc_src & branch_condition);
wire        branch_condition;
// Replace the current branch_condition assign
assign branch_condition =
    (!id_ex_alu_op[3] && !id_ex_alu_op[2] && !id_ex_alu_op[1] && id_ex_alu_op[0])
                                             ?  alu_zero      :  // BEQ/BNE use SUB (0001)
    (id_ex_alu_op == 4'b1000)               ?  alu_result[0] :  // BLT/BGE use SLT
    (id_ex_alu_op == 4'b1001)               ?  alu_result[0] :  // BLTU/BGEU use SLTU
    1'b0;

// Make actual_pc_src safe — default 0
assign actual_pc_src = (id_is_branch & branch_condition)
                     | id_is_jal
                     | id_is_jalr;

assign pc_target = id_is_jalr ? {alu_result[31:1], 1'b0}
                               : if_id_pc + immediate;                     

// ═══════════════════════════════════════════════════════════════
// EX/MEM PIPELINE REGISTER OUTPUTS
// ═══════════════════════════════════════════════════════════════
// ex_mem_alu_result declared above (forward reference)
wire [31:0] ex_mem_rs2_data;
wire [4:0]  ex_mem_rd_addr;
wire [31:0] ex_mem_pc_plus4;
wire        ex_mem_reg_we;
wire        ex_mem_mem_we;
wire        ex_mem_mem_read;
wire        ex_mem_mem_to_reg;

// ═══════════════════════════════════════════════════════════════
// MEM STAGE WIRES
// ═══════════════════════════════════════════════════════════════
wire [31:0] mem_read_data;

// ═══════════════════════════════════════════════════════════════
// MEM/WB PIPELINE REGISTER OUTPUTS
// ═══════════════════════════════════════════════════════════════
wire [31:0] mem_wb_alu_result;
wire [31:0] mem_wb_read_data;
wire [31:0] mem_wb_pc_plus4;
wire [4:0]  mem_wb_rd_addr;
wire        mem_wb_reg_we;
wire        mem_wb_mem_to_reg;

// ═══════════════════════════════════════════════════════════════
// WB STAGE — write-back mux
// wb_rd_data declared above (forward reference for EX forwarding)
// ═══════════════════════════════════════════════════════════════
wire        mem_wb_is_jump = 1'b0; // simplified — extend by carrying is_jump flag
assign wb_rd_data = mem_wb_is_jump    ? mem_wb_pc_plus4    :
                    mem_wb_mem_to_reg ? mem_wb_read_data   :
                                        mem_wb_alu_result;

// ═══════════════════════════════════════════════════════════════
// MODULE INSTANTIATIONS
// ═══════════════════════════════════════════════════════════════

// ── 1. PC — gains pc_write from hazard unit ───────────────────
pc pc_inst (
    .clk       (clk),
    .rst       (rst),
    .pc_write  (pc_write),    
    .pc_src    (actual_pc_src),
    .pc_target (pc_target),
    .pc_out    (pc_out)
);

// ── 2. Instruction Memory ─────────────────────────────────────
instruction_mem imem_inst (
    .addr  (pc_out),
    .instr (if_instruction)
);

// ── 3. IF/ID Pipeline Register ───────────────────────────────
IFID_pipeline_reg if_id_reg (
    .clk         (clk),
    .rst          (rst),
    .write       (if_id_write),
    .flush       (if_id_flush),
    .in_instr    (if_instruction),
    .in_pc       (pc_out),
    .in_pc_plus_4 (pc_plus4),
    .out_instr   (if_id_instr),
    .out_pc      (if_id_pc),
    .out_pc_plus_4(if_id_pc_plus4)
);

// ── 4. Control Unit — driven by IF/ID instruction ─────────────
control_unit ctrl_inst (
    .instruction (if_id_instr),
    .reg_we      (id_reg_we),
    .alu_src     (id_alu_src),
    .alu_op      (id_alu_op),
    .mem_we      (id_mem_we),
    .mem_read    (id_mem_read),
    .mem_to_reg  (id_mem_to_reg),
    .imm_sel     (id_imm_sel),
    .pc_src      (id_pc_src)
);

// ── 5. Immediate Generator — driven by IF/ID instruction ──────
immediate_gen imm_gen_inst (
    .instr   (if_id_instr),
    .imm_sel (id_imm_sel),
    .imm_out (immediate)
);

// ── 6. Register File
//       READ  addresses → from IF/ID (decode stage)
//       WRITE address   → from MEM/WB (write-back stage)
register_file regfile_inst (
    .clk      (clk),
    .we       (mem_wb_reg_we),
    .rs1_addr (if_id_rs1_addr),
    .rs2_addr (if_id_rs2_addr),
    .rd_addr  (mem_wb_rd_addr),
    .rd_data  (wb_rd_data),
    .rs1_data (rs1_data),
    .rs2_data (rs2_data)
);

// ── 7. ID/EX Pipeline Register ───────────────────────────────
IDEX_pipeline_reg id_ex_reg (
    .clk           (clk),
    .rst           (rst),
    .flush         (id_ex_flush),
    .in_rs1_data   (rs1_data),
    .in_rs2_data   (rs2_data),
    .in_immediate  (immediate),
    .in_pc         (if_id_pc),
    .in_pc_plus4   (if_id_pc_plus4),
    .in_rs1_addr   (if_id_rs1_addr),
    .in_rs2_addr   (if_id_rs2_addr),
    .in_rd_addr    (if_id_rd_addr),
    .in_alu_op     (id_alu_op),
    .in_alu_src    (id_alu_src),
    .in_mem_we     (id_mem_we),
    .in_mem_read   (id_mem_read),
    .in_mem_to_reg (id_mem_to_reg),
    .in_reg_we     (id_reg_we),
    .out_rs1_data  (id_ex_rs1_data),
    .out_rs2_data  (id_ex_rs2_data),
    .out_immediate (id_ex_immediate),
    .out_pc        (id_ex_pc),
    .out_pc_plus4  (id_ex_pc_plus4),
    .out_rs1_addr  (id_ex_rs1_addr),
    .out_rs2_addr  (id_ex_rs2_addr),
    .out_rd_addr   (id_ex_rd_addr),
    .out_alu_op    (id_ex_alu_op),
    .out_alu_src   (id_ex_alu_src),
    .out_mem_we    (id_ex_mem_we),
    .out_mem_read  (id_ex_mem_read),
    .out_mem_to_reg(id_ex_mem_to_reg),
    .out_reg_we    (id_ex_reg_we)
);

// ── 8. Forwarding Unit ────────────────────────────────────────
forwarding_unit fwd_inst (
    .id_ex_rs1_addr  (id_ex_rs1_addr),
    .id_ex_rs2_addr  (id_ex_rs2_addr),
    .ex_mem_rd_addr  (ex_mem_rd_addr),
    .ex_mem_reg_we   (ex_mem_reg_we),
    .mem_wb_rd_addr  (mem_wb_rd_addr),
    .mem_wb_reg_we   (mem_wb_reg_we),
    .forward_a       (forward_a),
    .forward_b       (forward_b)
);

// ── 9. Hazard Unit ────────────────────────────────────────────
hazard_unit haz_inst (
    .id_ex_rd_addr   (id_ex_rd_addr),
    .id_ex_mem_read  (id_ex_mem_read),
    .if_id_rs1_addr  (if_id_rs1_addr),
    .if_id_rs2_addr  (if_id_rs2_addr),
    .branch_taken    (branch_taken),
    .pc_write        (pc_write),
    .if_id_write     (if_id_write),
    .if_id_flush     (if_id_flush),
    .id_ex_flush     (id_ex_flush)
);

// ── 10. ALU ───────────────────────────────────────────────────
alu alu_inst (
    .a      (alu_input_a),
    .b      (alu_input_b),
    .alu_op (id_ex_alu_op),
    .result (alu_result),
    .zero   (alu_zero)
);

// ── 11. EX/MEM Pipeline Register ─────────────────────────────
EXMEM_pipeline_reg ex_mem_reg (
    .clk           (clk),
    .rst           (rst),
    .in_alu_result (alu_result),
    .in_rs2_data   (alu_input_b_fwd),
    .in_rd_addr    (id_ex_rd_addr),
    .in_pc_plus4   (id_ex_pc_plus4),
    .in_reg_we     (id_ex_reg_we),
    .in_mem_we     (id_ex_mem_we),
    .in_mem_read   (id_ex_mem_read),
    .in_mem_to_reg (id_ex_mem_to_reg),
    .out_alu_result(ex_mem_alu_result),
    .out_rs2_data  (ex_mem_rs2_data),
    .out_rd_addr   (ex_mem_rd_addr),
    .out_pc_plus4  (ex_mem_pc_plus4),
    .out_reg_we    (ex_mem_reg_we),
    .out_mem_we    (ex_mem_mem_we),
    .out_mem_read  (ex_mem_mem_read),
    .out_mem_to_reg(ex_mem_mem_to_reg)
);

// ── 12. Data Memory — driven by EX/MEM fields ─────────────────
data_mem dmem_inst (
    .clk  (clk),
    .we   (ex_mem_mem_we),
    .addr (ex_mem_alu_result),
    .din  (ex_mem_rs2_data),
    .dout (mem_read_data)
);

// ── 13. MEM/WB Pipeline Register ─────────────────────────────
MEMWB_pipeline_reg mem_wb_reg (
    .clk           (clk),
    .rst           (rst),
    .in_alu_result (ex_mem_alu_result),
    .in_read_data  (mem_read_data),
    .in_pc_plus4   (ex_mem_pc_plus4),
    .in_rd_addr    (ex_mem_rd_addr),
    .in_reg_we     (ex_mem_reg_we),
    .in_mem_to_reg (ex_mem_mem_to_reg),
    .out_alu_result(mem_wb_alu_result),
    .out_read_data (mem_wb_read_data),
    .out_pc_plus4  (mem_wb_pc_plus4),
    .out_rd_addr   (mem_wb_rd_addr),
    .out_reg_we    (mem_wb_reg_we),
    .out_mem_to_reg(mem_wb_mem_to_reg)
);

// ═══════════════════════════════════════════════════════════════
// DEBUG OUTPUTS
// ═══════════════════════════════════════════════════════════════
assign pc_out_dbg      = pc_out;
assign instruction_dbg = if_id_instr;
assign alu_result_dbg  = alu_result;
assign mem_we_dbg      = ex_mem_mem_we;
assign mem_read_dbg    = ex_mem_mem_read;

endmodule
