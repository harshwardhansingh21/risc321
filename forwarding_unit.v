module forwarding_unit (
    // From ID/EX — what current EX instruction needs
    input  wire [4:0] id_ex_rs1_addr,
    input  wire [4:0] id_ex_rs2_addr,

    // From EX/MEM — what MEM-stage instruction will produce
    input  wire [4:0] ex_mem_rd_addr,
    input  wire       ex_mem_reg_we,

    // From MEM/WB — what WB-stage instruction will produce
    input  wire [4:0] mem_wb_rd_addr,
    input  wire       mem_wb_reg_we,

    // Outputs — mux selects for ALU inputs A and B
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

always@(*) begin
    forward_a=2'b00;
    forward_b=2'b00;

    if(ex_mem_reg_we==1 && (ex_mem_rd_addr != 5'b0) && (id_ex_rs1_addr ==ex_mem_rd_addr)) begin
        forward_a=2'b10;
    end
    else if(mem_wb_reg_we==1 && (mem_wb_rd_addr != 5'b0) && (id_ex_rs1_addr ==mem_wb_rd_addr)) begin
        forward_a=2'b01;
    end

     if(ex_mem_reg_we==1 && (ex_mem_rd_addr != 5'b0) && (id_ex_rs2_addr ==ex_mem_rd_addr)) begin
        forward_b=2'b10;
    end
    else if(mem_wb_reg_we==1 && (mem_wb_rd_addr != 5'b0) && (id_ex_rs2_addr ==mem_wb_rd_addr)) begin
        forward_b=2'b01;
    end
end

endmodule