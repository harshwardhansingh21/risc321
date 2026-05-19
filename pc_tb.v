`timescale 1ns/1ps

module pc_tb;
reg clk;
reg rst;
reg pc_src;
reg [31:0] pc_target;
wire [31:0] pc_out;

// Initialize inputs before starting the clock to avoid X propagation
initial begin
    rst = 1;
    #10 clk=~clk; // 10ns clock period
    pc_target = 32'h0;
    clk = 0;
    forever begin
        #10 clk = ~clk;
    end 
end

pc uut(
    .clk(clk),
    .rst(rst),
    .pc_src(pc_src),
    .pc_target(pc_target),
    .pc_out(pc_out)
);

initial begin
        // Wait for initial input setup and clock start
        #1;

        // Create the waveform dump files for viewing in any compatible VCD viewer (e.g., GTKWave)
        $dumpfile("pc_waveform.vcd");
        $dumpvars(0, pc_tb);

        // Hold reset for 20ns, then release
        #20 rst = 0;
        
        // Let it increment sequentially for a few cycles
        #40;
        
        // Set pc_target and assert pc_src to simulate a jump/branch execution
        pc_target = 32'h0000_2040;
        pc_src = 1;
        #10; // Wait one clock cycle for the jump to register
        
        // Return to sequential mode from the new target address
        pc_src = 0;
        #40;

        // End simulation after all test cases have been executed.
        // Add further tests above this line if more scenarios need to be validated in the future.
        $finish;
    end
endmodule