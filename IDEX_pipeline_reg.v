module IDEX_pipeline_reg (
    input  wire        clk,
    input  wire        flush,
    input  wire         rst,
    input  wire [31:0] in_rs1_data,
    input  wire [31:0] in_rs2_data,
    input  wire [31:0] in_immediate,
    input  wire [31:0] in_pc,
    input  wire [31:0] in_pc_plus4,
    input  wire [4:0]  in_rs1_addr,
    input  wire [4:0]  in_rs2_addr,
    input  wire [4:0]  in_rd_addr,
    input  wire [3:0]  in_alu_op,
    input  wire        in_alu_src,
    input  wire        in_mem_we,
    input  wire        in_mem_read,
    input  wire        in_mem_to_reg,
    input  wire        in_reg_we,
    output reg  [31:0] out_rs1_data,
    output reg  [31:0] out_rs2_data,
    output reg  [31:0] out_immediate,
    output reg  [31:0] out_pc,
    output reg  [31:0] out_pc_plus4,
    output reg  [4:0]  out_rs1_addr,
    output reg  [4:0]  out_rs2_addr,
    output reg  [4:0]  out_rd_addr,
    output reg  [3:0]  out_alu_op,
    output reg         out_alu_src,
    output reg         out_mem_we,
    output reg         out_mem_read,
    output reg         out_mem_to_reg,
    output reg         out_reg_we
);

always @(posedge clk) begin

     if (rst) begin
     
        out_alu_op     <= 4'b0;
        out_alu_src    <= 1'b0;
        out_mem_we     <= 1'b0;
        out_mem_read   <= 1'b0;
        out_mem_to_reg <= 1'b0;
        out_reg_we     <= 1'b0;
        out_rs1_data   <= 32'b0;
        out_rs2_data   <= 32'b0;
        out_immediate  <= 32'b0;
        out_pc         <= 32'b0;
        out_pc_plus4   <= 32'b0;
        out_rs1_addr   <= 5'b0;
        out_rs2_addr   <= 5'b0;
        out_rd_addr    <= 5'b0;
    end
    else if (flush) begin
     
        out_alu_op     <= 4'b0;
        out_alu_src    <= 1'b0;
        out_mem_we     <= 1'b0;
        out_mem_read   <= 1'b0;
        out_mem_to_reg <= 1'b0;
        out_reg_we     <= 1'b0;
        out_rs1_data   <= 32'b0;
        out_rs2_data   <= 32'b0;
        out_immediate  <= 32'b0;
        out_pc         <= 32'b0;
        out_pc_plus4   <= 32'b0;
        out_rs1_addr   <= 5'b0;
        out_rs2_addr   <= 5'b0;
        out_rd_addr    <= 5'b0;
    end
    else begin
        out_rs1_data   <= in_rs1_data;
        out_rs2_data   <= in_rs2_data;
        out_immediate  <= in_immediate;
        out_pc         <= in_pc;
        out_pc_plus4   <= in_pc_plus4;
        out_rs1_addr   <= in_rs1_addr;
        out_rs2_addr   <= in_rs2_addr;
        out_rd_addr    <= in_rd_addr;
        out_alu_op     <= in_alu_op;
        out_alu_src    <= in_alu_src;
        out_mem_we     <= in_mem_we;
        out_mem_read   <= in_mem_read;
        out_mem_to_reg <= in_mem_to_reg;
        out_reg_we     <= in_reg_we;
    end
end

endmodule