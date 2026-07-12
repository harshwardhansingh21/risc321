module MEMWB_pipeline_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] in_alu_result,
    input  wire [31:0] in_read_data,
    input  wire [31:0] in_pc_plus4,
    input  wire [4:0]  in_rd_addr,
    input  wire        in_reg_we,
    input  wire        in_mem_to_reg,
    output reg  [31:0] out_alu_result,
    output reg  [31:0] out_read_data,
    output reg  [31:0] out_pc_plus4,
    output reg  [4:0]  out_rd_addr,
    output reg         out_reg_we,
    output reg         out_mem_to_reg
);

always @(posedge clk) begin
    if(rst) begin
    out_alu_result  <= 0;
    out_read_data   <= 0;
    out_pc_plus4    <= 0;
    out_rd_addr     <= 0;
    out_reg_we      <= 0;
    out_mem_to_reg  <= 0;   
    end
    else begin
    out_alu_result  <= in_alu_result;
    out_read_data   <= in_read_data;
    out_pc_plus4    <= in_pc_plus4;
    out_rd_addr     <= in_rd_addr;
    out_reg_we      <= in_reg_we;
    out_mem_to_reg  <= in_mem_to_reg;
    end
end

endmodule