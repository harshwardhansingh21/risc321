module EXMEM_pipeline_reg (
    input  wire        clk,
    input  wire        rst,

    // Group 1 — ALU result
    input  wire [31:0] in_alu_result,

    // Group 2 — Store data
    input  wire [31:0] in_rs2_data,

    // Group 3 — Destination and pass-through
    input  wire [4:0]  in_rd_addr,
    input  wire [31:0] in_pc_plus4,

    // Group 4 — Control signals
    input  wire        in_reg_we,
    input  wire        in_mem_we,
    input  wire        in_mem_read,
    input  wire        in_mem_to_reg,

    // Group 1 out
    output reg  [31:0] out_alu_result,

    // Group 2 out
    output reg  [31:0] out_rs2_data,

    // Group 3 out
    output reg  [4:0]  out_rd_addr,
    output reg  [31:0] out_pc_plus4,

    // Group 4 out
    output reg         out_reg_we,
    output reg         out_mem_we,
    output reg         out_mem_read,
    output reg         out_mem_to_reg
);

always @(posedge clk) begin

    if(rst) begin
    out_alu_result  <= 0;
    out_rs2_data    <= 0;
    out_rd_addr     <= 0;
    out_pc_plus4    <= 0;
    out_reg_we      <= 0;
    out_mem_we      <= 0;
    out_mem_read    <= 0;
    out_mem_to_reg  <= 0;   
    end
    else begin
    out_alu_result  <= in_alu_result;
    out_rs2_data    <= in_rs2_data;
    out_rd_addr     <= in_rd_addr;
    out_pc_plus4    <= in_pc_plus4;
    out_reg_we      <= in_reg_we;
    out_mem_we      <= in_mem_we;
    out_mem_read    <= in_mem_read;
    out_mem_to_reg  <= in_mem_to_reg;
    end
end

endmodule