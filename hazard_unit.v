module hazard_unit (
    input  wire [4:0] id_ex_rd_addr,
    input  wire       id_ex_mem_read,
    input  wire [4:0] if_id_rs1_addr,
    input  wire [4:0] if_id_rs2_addr,
    input  wire       branch_taken,
    output wire       pc_write,
    output wire       if_id_write,
    output wire       if_id_flush,
    output wire       id_ex_flush
);
reg load_use;
always@(*) begin
    load_use=0;
    if(id_ex_mem_read==1 && (id_ex_rd_addr == if_id_rs1_addr || id_ex_rd_addr == if_id_rs2_addr) && id_ex_rd_addr != 5'b0) begin
        load_use=1'b1;
    end
    else load_use=0;
end

  assign  pc_write=~load_use;
  assign  if_id_write=~load_use;
  assign  if_id_flush=branch_taken;
  assign  id_ex_flush=(load_use || branch_taken);


endmodule