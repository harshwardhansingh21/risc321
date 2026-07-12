// ================================================================
// RV32I Pipelined Processor — Testbench
// Changes from single-cycle TB:
//   1. tb_top instantiates cpu_pipeline instead of cpu
//   2. monitor adds 2-cycle delay queue to align instruction
//      with alu_result (which appears in EX, 2 cycles after IF)
//   3. timeout increased to 5000ns to allow pipeline to drain
// Everything else — transaction, generator, driver, scoreboard,
// environment — is identical to the single-cycle testbench.
// ================================================================

// ================================================================
// TRANSACTION
// ================================================================
class transaction;
    rand bit [31:0] instruction;
    rand bit signed [31:0] imm;
    rand bit [6:0]  opcode;
    rand bit [4:0]  rd;
    rand bit [4:0]  rs1;
    rand bit [4:0]  rs2;
    rand bit [2:0]  funct3;
    rand bit [6:0]  funct7;

    constraint valid_opcode {
        opcode inside {
            7'b0110011, 7'b0010011, 7'b0000011, 7'b0100011,
            7'b1100011, 7'b1101111, 7'b1100111,
            7'b0110111, 7'b0010111
        };
    }

    constraint imm_constraints {
        if (opcode inside {7'b0010011, 7'b1100111,
                           7'b0000011, 7'b0100011, 7'b1100011})
            imm inside {[-4096:4095]};
        if (opcode == 7'b1100011)
            imm[0] == 1'b0;
        if (opcode inside {7'b0110111, 7'b0010111})
            imm[11:0] == 12'b0;
        if (opcode == 7'b1101111) {
            imm inside {[-1048576:1048575]};
            imm[0] == 1'b0;
        }
    }

    function void post_randomize();
        case (opcode)
            7'b0110011: instruction = {funct7, rs2, rs1, funct3, rd, opcode};
            7'b0010011: instruction = {imm[11:0], rs1, funct3, rd, opcode};
            7'b0000011: instruction = {imm[11:0], rs1, funct3, rd, opcode};
            7'b0100011: instruction = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
            7'b1100011: instruction = {imm[12], imm[10:5], rs2, rs1,
                                       funct3, imm[4:1], imm[11], opcode};
            7'b0110111: instruction = {imm[31:12], rd, opcode};
            7'b0010111: instruction = {imm[31:12], rd, opcode};
            7'b1101111: instruction = {imm[20], imm[10:1], imm[11],
                                       imm[19:12], rd, opcode};
            7'b1100111: instruction = {imm[11:0], rs1, funct3, rd, opcode};
            default:    instruction = 32'b0;
        endcase
    endfunction
endclass


// ================================================================
// INTERFACE — unchanged from single-cycle TB
// ================================================================
interface rv32i_if (input logic clk);
    logic        rst;
    logic [31:0] pc_out;
    logic [31:0] instruction;
    logic [31:0] alu_result;
    logic [31:0] rs2_data;
    logic        mem_we;
    logic        mem_read;

    clocking cb @(posedge clk);
        default input #1ns output #1ns;
        input pc_out;
        input instruction;
        input alu_result;
        input rs2_data;
        input mem_we;
        input mem_read;
    endclocking

    modport DRV (clocking cb, output rst);
    modport MON (clocking cb);
endinterface


// ================================================================
// GENERATOR — unchanged
// ================================================================
class generator;
    mailbox #(transaction) gen_to_drv;
    transaction tx;
    int num_packets;
    event gen_done;

    function new(mailbox #(transaction) gen_to_drv);
        this.gen_to_drv = gen_to_drv;
    endfunction

    task run();
        repeat (num_packets) begin
            tx = new();
            if (!tx.randomize())
                $error("Randomization failed");
            else begin
                $display("[GEN] opcode=%b", tx.opcode);
                gen_to_drv.put(tx);
            end
        end
        -> gen_done;
    endtask
endclass


// ================================================================
// DRIVER — unchanged
// ================================================================
class driver;
    mailbox #(transaction) gen_to_drv;
    virtual rv32i_if.DRV   vif;
    transaction tx;

    function new(mailbox #(transaction) gen_to_drv, virtual rv32i_if.DRV vif);
        this.gen_to_drv = gen_to_drv;
        this.vif        = vif;
    endfunction

    task reset();
        vif.rst <= 1'b1;
        repeat (5) @(vif.cb);   // longer reset for pipeline flush
        vif.rst <= 1'b0;
    endtask

    task run();
        forever begin
            gen_to_drv.get(tx);
            @(vif.cb);
        end
    endtask
endclass


// ================================================================
// MONITOR — CHANGED: 2-cycle delay queue added
//
// In a pipelined processor:
//   Cycle N:   instruction enters IF → visible on instruction_dbg
//   Cycle N+2: instruction in EX    → alu_result_dbg shows result
//
// The monitor holds the last 2 captured instructions in a shift
// register. Each cycle it sends the 2-cycle-old instruction to
// the scoreboard, paired with the alu_result currently on the bus.
// This alignment is what makes the scoreboard comparisons valid.
// ================================================================
class monitor;
    mailbox #(transaction) mon_to_scr;
    virtual rv32i_if.MON   vif;

    // 2-entry shift register — index 0 = last cycle, index 1 = 2 cycles ago
    transaction delay_queue [2];

    function new(mailbox #(transaction) mon_to_scr, virtual rv32i_if.MON vif);
        this.mon_to_scr = mon_to_scr;
        this.vif        = vif;
        delay_queue[0]  = new();
        delay_queue[1]  = new();
    endfunction

    task run();
        forever begin
            transaction tx_current;
            transaction tx_delayed;
            @(vif.cb);

            // Shift queue — [1] gets what was in [0], [0] gets new capture
            delay_queue[1] = delay_queue[0];

            // Capture instruction entering IF this cycle
            tx_current             = new();
            tx_current.instruction = vif.cb.instruction;
            tx_current.opcode      = vif.cb.instruction[6:0];
            tx_current.rd          = vif.cb.instruction[11:7];
            tx_current.rs1         = vif.cb.instruction[19:15];
            tx_current.rs2         = vif.cb.instruction[24:20];
            tx_current.funct3      = vif.cb.instruction[14:12];
            tx_current.funct7      = vif.cb.instruction[31:25];
            delay_queue[0]         = tx_current;

            // Send the 2-cycle-old instruction to scoreboard
            // alu_result on the bus RIGHT NOW belongs to that instruction
            tx_delayed = new();
            tx_delayed = delay_queue[1];
            mon_to_scr.put(tx_delayed);
        end
    endtask
endclass


// ================================================================
// SCOREBOARD — unchanged from single-cycle TB
// Receives correctly-timed transactions from the monitor.
// ================================================================
class scoreboard;
    mailbox #(transaction) mon_to_scr;
    virtual rv32i_if       vif;

    bit [31:0] expected_reg_file [32];
    bit [31:0] predicted_result;
    int match_count    = 0;
    int mismatch_count = 0;

    function new(mailbox #(transaction) mon_to_scr, virtual rv32i_if vif);
        this.mon_to_scr = mon_to_scr;
        this.vif        = vif;
        for (int i = 0; i < 32; i++)
            expected_reg_file[i] = 32'b0;
    endfunction

    function automatic bit [31:0] sign_extend_12(bit [11:0] imm12);
        return {{20{imm12[11]}}, imm12};
    endfunction

    task check_result(input string name, input bit [4:0] rd,
                      input bit [31:0] expected, input bit [31:0] got);
        if (got === expected) begin
            $display("[MATCH]    %-10s | rd=x%-2d | exp=%h | got=%h | PC=%h",
                     name, rd, expected, got, vif.cb.pc_out);
            match_count++;
        end else begin
            $error("[MISMATCH] %-10s | rd=x%-2d | exp=%h | got=%h | PC=%h",
                   name, rd, expected, got, vif.cb.pc_out);
            mismatch_count++;
        end
    endtask

    task run();
        transaction       tx;
        bit [2:0]         funct3;
        bit [6:0]         funct7;
        bit signed [31:0] rs1_val;
        bit signed [31:0] rs2_val;
        bit signed [31:0] imm_val;
        bit [31:0]        mem_addr;

        forever begin
            mon_to_scr.get(tx);
            funct3  = tx.funct3;
            funct7  = tx.funct7;
            rs1_val = expected_reg_file[tx.rs1];
            rs2_val = expected_reg_file[tx.rs2];

            case (tx.opcode)
                7'b0110011: begin // R-type
                    case (funct3)
                        3'b000: predicted_result = funct7[5] ?
                                    (rs1_val-rs2_val) : (rs1_val+rs2_val);
                        3'b001: predicted_result = expected_reg_file[tx.rs1] << rs2_val[4:0];
                        3'b010: predicted_result = (rs1_val < rs2_val) ? 32'd1 : 32'd0;
                        3'b011: predicted_result = (expected_reg_file[tx.rs1] <
                                    expected_reg_file[tx.rs2]) ? 32'd1 : 32'd0;
                        3'b100: predicted_result = expected_reg_file[tx.rs1] ^
                                    expected_reg_file[tx.rs2];
                        3'b101: predicted_result = funct7[5] ?
                                    (rs1_val>>>rs2_val[4:0]) :
                                    (expected_reg_file[tx.rs1]>>rs2_val[4:0]);
                        3'b110: predicted_result = expected_reg_file[tx.rs1] |
                                    expected_reg_file[tx.rs2];
                        3'b111: predicted_result = expected_reg_file[tx.rs1] &
                                    expected_reg_file[tx.rs2];
                        default: predicted_result = 32'b0;
                    endcase
                    if (tx.rd != 5'd0) expected_reg_file[tx.rd] = predicted_result;
                    else predicted_result = 32'b0;
                    check_result("R-TYPE", tx.rd, predicted_result, vif.cb.alu_result);
                end

                7'b0010011: begin // I-type
                    imm_val = sign_extend_12(tx.instruction[31:20]);
                    case (funct3)
                        3'b000: predicted_result = rs1_val + imm_val;
                        3'b010: predicted_result = (rs1_val < imm_val) ? 32'd1 : 32'd0;
                        3'b011: predicted_result = (expected_reg_file[tx.rs1] <
                                    $unsigned(imm_val)) ? 32'd1 : 32'd0;
                        3'b100: predicted_result = expected_reg_file[tx.rs1] ^ imm_val;
                        3'b110: predicted_result = expected_reg_file[tx.rs1] | imm_val;
                        3'b111: predicted_result = expected_reg_file[tx.rs1] & imm_val;
                        3'b001: predicted_result = expected_reg_file[tx.rs1] << imm_val[4:0];
                        3'b101: predicted_result = tx.instruction[30] ?
                                    (rs1_val>>>imm_val[4:0]) :
                                    (expected_reg_file[tx.rs1]>>imm_val[4:0]);
                        default: predicted_result = 32'b0;
                    endcase
                    if (tx.rd != 5'd0) expected_reg_file[tx.rd] = predicted_result;
                    else predicted_result = 32'b0;
                    check_result("I-TYPE", tx.rd, predicted_result, vif.cb.alu_result);
                end

                7'b0000011: begin // LOAD — check address only
                    imm_val          = sign_extend_12(tx.instruction[31:20]);
                    predicted_result = expected_reg_file[tx.rs1] + imm_val;
                    check_result("LOAD-ADDR", tx.rd, predicted_result, vif.cb.alu_result);
                end

                7'b0100011: begin // STORE — check mem_we
                    if (vif.cb.mem_we !== 1'b1) begin
                        $error("[MISMATCH] STORE | mem_we not asserted | PC=%h",
                               vif.cb.pc_out);
                        mismatch_count++;
                    end else begin
                        $display("[MATCH]    STORE      | PC=%h", vif.cb.pc_out);
                        match_count++;
                    end
                end

                7'b1100011: begin // BRANCH
                    $display("[INFO]     BRANCH    | funct3=%b | PC=%h",
                             funct3, vif.cb.pc_out);
                end

                7'b0110111: begin // LUI
                    predicted_result = {tx.instruction[31:12], 12'b0};
                    if (tx.rd != 5'd0) expected_reg_file[tx.rd] = predicted_result;
                    check_result("LUI", tx.rd, predicted_result, vif.cb.alu_result);
                end

                7'b0010111: begin // AUIPC
                    predicted_result = vif.cb.pc_out + {tx.instruction[31:12], 12'b0};
                    if (tx.rd != 5'd0) expected_reg_file[tx.rd] = predicted_result;
                    check_result("AUIPC", tx.rd, predicted_result, vif.cb.alu_result);
                end

                7'b1101111: begin // JAL
                    predicted_result = vif.cb.pc_out + 32'd4;
                    if (tx.rd != 5'd0) expected_reg_file[tx.rd] = predicted_result;
                    check_result("JAL", tx.rd, predicted_result, vif.cb.alu_result);
                end

                7'b1100111: begin // JALR
                    predicted_result = vif.cb.pc_out + 32'd4;
                    if (tx.rd != 5'd0) expected_reg_file[tx.rd] = predicted_result;
                    check_result("JALR", tx.rd, predicted_result, vif.cb.alu_result);
                end

                default:
                    $display("[INFO]     UNKNOWN | opcode=%b | PC=%h",
                             tx.opcode, vif.cb.pc_out);
            endcase
        end
    endtask
endclass


// ================================================================
// ENVIRONMENT — unchanged except num_packets
// ================================================================
class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scr;
    mailbox #(transaction) gen_to_drv;
    mailbox #(transaction) mon_to_scr;
    virtual rv32i_if vif;

    function new(virtual rv32i_if vif);
        this.vif   = vif;
        gen_to_drv = new();
        mon_to_scr = new();
        gen = new(gen_to_drv);
        drv = new(gen_to_drv, vif.DRV);
        mon = new(mon_to_scr, vif.MON);
        scr = new(mon_to_scr, vif);
        gen.num_packets = 100;
    endfunction

    task pre_task();  drv.reset(); endtask

    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            scr.run();
        join_any
        @(gen.gen_done);
        #100ns;        // extra drain time for pipeline to flush
        disable fork;
    endtask

    task post_task();
        #100ns;
        $display("--------------------------------------------------");
        $display("[ENV] Simulation Finished");
        $display("[ENV] Total Matches:    %0d", scr.match_count);
        $display("[ENV] Total Mismatches: %0d", scr.mismatch_count);
        $display("--------------------------------------------------");
    endtask

    task run();
        pre_task();
        test();
        post_task();
        $finish;
    endtask
endclass


// ================================================================
// TOP LEVEL — CHANGED: cpu → cpu_pipeline, timeout increased
// ================================================================
module tb_top;
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    rv32i_if inf (clk);

    // CHANGED: cpu_pipeline instead of cpu
    cpu_pipeline dut (
        .clk             (inf.clk),
        .rst             (inf.rst),
        .pc_out_dbg      (inf.pc_out),
        .instruction_dbg (inf.instruction),
        .alu_result_dbg  (inf.alu_result),
        .mem_we_dbg      (inf.mem_we),
        .mem_read_dbg    (inf.mem_read)
    );

    environment env;

    initial begin
        $dumpfile("rv32i_pipeline_tb.vcd");
        $dumpvars(0, tb_top);
        env = new(inf);
        env.run();
    end

    // CHANGED: increased from 2000ns to 5000ns
    // Pipeline needs extra cycles to drain after last instruction
    initial begin
        #5000;
        $display("TIMEOUT: forcing simulation end");
        $finish;
    end
endmodule