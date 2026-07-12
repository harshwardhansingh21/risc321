module IFID_pipeline_reg(
    input clk,
    input write,
    input flush,
    input rst,
    input [31:0] in_instr,
    input [31:0] in_pc,
    input [31:0] in_pc_plus_4,
    output reg [31:0] out_instr,
    output reg [31:0] out_pc,
    output reg [31:0] out_pc_plus_4
);
always @(posedge clk) begin
 if (rst) begin             
        out_instr    <= 32'h0000_0013;
        out_pc       <= 32'b0;
        out_pc_plus4 <= 32'b0;
    end
    else if (flush) begin
        out_instr    <= 32'h0000_0013;
        out_pc       <= 32'b0;
        out_pc_plus4 <= 32'b0;
    end
    else if (write) begin
        out_instr    <= in_instr;
        out_pc       <= in_pc;
        out_pc_plus4 <= in_pc_plus4;
    end
end

endmodule