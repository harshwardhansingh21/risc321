module register_file (
    input wire clk,
    input wire we,
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    input wire [4:0] rd_addr,
    input wire [31:0] rd_data,//destination register data to be written
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);
reg [31:0] regs [0:31];

//hardwired zero register
assign rs1_data = (rs1_addr ==5'b00000) ? 32'b0 : regs[rs1_addr];
assign rs2_data = (rs2_addr ==5'b00000) ? 32'b0 : regs[rs2_addr];

//write logic
always@(posedge clk) begin
if(we && rd_addr!=5'b00000) begin//only write if we is high and rd_addr is not zero register
regs[rd_addr] <= rd_data;
end
end
endmodule