module pc (
    input clk,
    input rst,
    input pc_src,
    input [31:0] pc_target,
    output [31:0] pc_out
);

reg [31:0] pc_reg;

assign pc_out = pc_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc_reg <= 32'b0;
    end else if (pc_src) begin
        pc_reg <= pc_target;
    end else begin
        pc_reg <= pc_reg + 4;
    end
end

endmodule