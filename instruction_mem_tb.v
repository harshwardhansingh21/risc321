`timescale 1ns/1ps

module instruction_mem_tb;
reg [31:0] addr;
wire [31:0] instr;

instruction_mem uut (
    .addr(addr),
    .instr(instr)
);

initial begin
    $dumpfile("instruction_mem_waveform.vcd");
    $dumpvars(0, instruction_mem_tb);

    addr = 32'h0000_0000;
    #5;
    $display("addr=%h instr=%h", addr, instr);

    #10 addr = 32'h0000_0004;
    #10 $display("addr=%h instr=%h", addr, instr);

    #10 addr = 32'h0000_0008;
    #10 $display("addr=%h instr=%h", addr, instr);

    #10 addr = 32'h0000_000c;
    #10 $display("addr=%h instr=%h", addr, instr);

    #10 $finish;
end

endmodule
