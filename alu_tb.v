module alu_tb();

reg [31:0] a, b;
reg [3:0] alu_op;
wire [31:0] result;
wire zero;

alu dut (
    .a(a),
    .b(b),
    .alu_op(alu_op),
    .result(result),
    .zero(zero)
);

initial begin
    $monitor("Time=%0t | a=%d, b=%d, op=%b | result=%d, zero=%b",
             $time, a, b, alu_op, result, zero);
    
    // Test ADD
    a = 10; b = 5; alu_op = 4'b0000; #10;
    
    // Test SUB
    a = 10; b = 5; alu_op = 4'b0001; #10;
    
    // Test AND
    a = 32'hFF00FF00; b = 32'h00FF00FF; alu_op = 4'b0010; #10;
    
    // Test OR
    a = 32'hFF000000; b = 32'h00FF0000; alu_op = 4'b0011; #10;
    
    // Test XOR
    a = 32'hFFFFFFFF; b = 32'h00000000; alu_op = 4'b0100; #10;
    
    // Test SLL
    a = 32'h00000001; b = 32'h00000003; alu_op = 4'b0101; #10;
    
    // Test SRL
    a = 32'h00001000; b = 32'h00000002; alu_op = 4'b0110; #10;
    
    // Test SRA (arithmetic)
    a = 32'h80000000; b = 32'h00000001; alu_op = 4'b0111; #10;
    
    // Test SLT (signed less than)
    a = -5; b = 3; alu_op = 4'b1000; #10;
    
    // Test SLTU (unsigned less than)
    a = 32'hFFFFFFFF; b = 32'h00000001; alu_op = 4'b1001; #10;
    
    // Test zero flag
    a = 10; b = 10; alu_op = 4'b0001; #10;  // 10 - 10 = 0
    
    $finish;
end

endmodule
