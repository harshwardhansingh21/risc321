# RV32I Single-Cycle Processor

A complete, fully verified implementation of the **RISC-V 32-bit Base Integer Instruction Set (RV32I)** as a single-cycle processor, written in Verilog. Every module was designed, debugged, and verified from scratch — from the program counter to the write-back stage.

Simulated and verified on **Aldec Riviera-PRO via EDA Playground** with a SystemVerilog class-based testbench and **QuestaSim Altera Starter Edition** with a directed testbench.

---

## Waveform

> Simulation output showing PC sequencing through 0x00 → 0x04 → 0x08 → 0x0C, executing three instructions before reaching a JAL-to-self halt. ALU results and control signals (is_jal, is_jump, mem_we) confirm correct fetch, decode, and execute behavior at every step.

*(Add waveform screenshot here — docs/waveform.png)*

---

## Architecture Overview

The processor implements the classic single-cycle datapath. Every instruction completes in exactly one clock cycle — fetch, decode, execute, memory access, and write-back all happen within a single clock period.

```
                    ┌─────────────────────────────────┐
                    │         CONTROL UNIT             │
                    │  reg_we  alu_src  alu_op         │
                    │  mem_we  mem_read mem_to_reg      │
                    │  imm_sel  pc_src                  │
                    └──────────────┬──────────────────-┘
                                   │ instruction
    ┌──────┐  pc_out  ┌────────────┴────────┐
    │  PC  ├─────────►│  Instruction Memory  │
    └──┬───┘          └─────────────────────┘
       │ actual_pc_src          │ instruction
       │ pc_target    ┌─────────▼──────────┐   ┌──────────────┐
       │◄─────────────┤   Register File    ├──►│ Immediate    │
       │              └─────────┬──────────┘   │ Generator    │
       │              rs1  rs2  │              └──────┬───────┘
       │              ┌─────────▼──────┐             │ immediate
       │              │      ALU       │◄────────────-┘
       │              └────────┬───────┘
       │              result   │
       │              ┌────────▼───────┐
       │              │  Data Memory   │
       │              └────────┬───────┘
       │                       │ read_data
       │              ┌────────▼───────┐
       └──────────────┤   Write-Back   │──► reg file write port
                      │     Mux        │
                      └────────────────┘
```

---

## Supported Instructions — All 47 RV32I Base Instructions

| Type | Instructions |
|------|-------------|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| I-type | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU |
| Load | LW, LH, LB, LHU, LBU |
| Store | SW, SH, SB |
| Branch | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| Jump | JAL, JALR |
| Upper | LUI, AUIPC |

---

## Module Hierarchy

```
cpu.v  (top level)
├── pc.v                  — 32-bit program counter, async reset, branch mux
├── instruction_mem.v     — 1KB ROM, asynchronous read, $readmemh compatible
├── control_unit.v        — Combinational decode: opcode/funct3/funct7 → control signals
├── register_file.v       — 32×32b, x0 hardwired zero, async read, sync write
├── immediate_gen.v       — All 5 RV32I immediate formats (I/S/B/U/J)
├── alu.v                 — 11 operations + zero flag, purely combinational
└── data_mem.v            — 1KB RAM, synchronous write, asynchronous read
```

---

## Key Design Decisions

**Harvard Architecture** — Separate instruction and data memories eliminate the structural hazard that would otherwise occur when IF and MEM both need memory access in the same cycle.

**Asynchronous Register File Read** — Both rs1 and rs2 are read combinationally so operands are available within the same clock cycle as decode. Write is synchronous (posedge clk) to ensure committed, stable results.

**x0 Hardwired to Zero** — All writes to register 0 are silently discarded via a write-enable gate: `if (we && rd_addr != 5'b0)`. All reads from register 0 return zero via a ternary in the assign statement. This enables NOP, MV, BEQZ and all other x0-based pseudoinstructions.

**Branch Resolution in EX** — The branch condition is evaluated using the ALU result (SUB for BEQ/BNE, SLT/SLTU for BLT/BGE/BLTU/BGEU), and `actual_pc_src` is computed combinationally in the same cycle. No pipeline penalty exists in single-cycle — the next PC is simply selected by a mux before the rising clock edge.

**JAL/JALR Return Address** — The write-back mux has three levels: `is_jump ? PC+4 : mem_to_reg ? mem_data : alu_result`. This ensures JAL and JALR correctly write PC+4 to rd before any load or ALU result.

**AUIPC** — ALU input A is muxed to `pc_out` when the opcode is AUIPC (`7'b0010111`), enabling `PC + upper_immediate` to be computed through the same ALU ADD path as all other addition operations.

---

## File Structure

```
rv32i-single-cycle/
│
├── src/
│   ├── cpu.v
│   ├── pc.v
│   ├── instruction_mem.v
│   ├── register_file.v
│   ├── immediate_gen.v
│   ├── alu.v
│   ├── data_mem.v
│   └── control_unit.v
│
├── tb/
│   ├── rv32i_tb_fixed.sv      ← class-based SV testbench (Riviera-PRO / Xcelium / VCS)
│   └── cpu_tb_directed.v      ← directed testbench (QuestaSim Starter / iverilog)
│
├── program/
│   ├── program.hex            ← test program in hex
│   └── program.asm            ← annotated assembly source
│
├── docs/
│   └── waveform.png           ← EPWave screenshot
│
└── README.md
```

---

## How to Simulate

### EDA Playground (Free, No Install)
1. Go to [edaplayground.com](https://edaplayground.com)
2. Select **Aldec Riviera-PRO** as the simulator
3. Paste all `src/` files into the **Design** box
4. Paste `tb/rv32i_tb_fixed.sv` into the **Testbench** box
5. Tick **Open EPWave after run**
6. Click **Run**

### QuestaSim / ModelSim
```tcl
vdel -lib work -all
vlib work
vlog -vlog01compat pc.v
vlog -vlog01compat instruction_mem.v
vlog -vlog01compat register_file.v
vlog -vlog01compat immediate_gen.v
vlog -vlog01compat alu.v
vlog -vlog01compat data_mem.v
vlog -vlog01compat control_unit.v
vlog -vlog01compat cpu.v
vlog -sv tb/rv32i_tb_fixed.sv
vsim tb_top
run -all
```

### Icarus Verilog (Linux/WSL)
```bash
iverilog -g2005 -o cpu_sim \
    src/pc.v src/instruction_mem.v src/register_file.v \
    src/immediate_gen.v src/alu.v src/data_mem.v \
    src/control_unit.v src/cpu.v \
    tb/cpu_tb_directed.v
./cpu_sim
gtkwave cpu_wave.vcd
```

---

## Test Program

The current ROM program exercises the core ALU and register file:

```asm
# program.asm
addi x1, x0, 0      # 0x00000093  x1 = 0
addi x2, x0, 1      # 0x00100113  x2 = 1
add  x3, x1, x2     # 0x002081b3  x3 = x1 + x2 = 1
jal  x0, 0          # 0x0000006f  halt — infinite self-loop
```

Expected waveform behavior:
```
Cycle 1:  PC=0x00, INSTR=addi x1,x0,0,  ALU=0x00000000
Cycle 2:  PC=0x04, INSTR=addi x2,x0,1,  ALU=0x00000001
Cycle 3:  PC=0x08, INSTR=add  x3,x1,x2, ALU=0x00000001
Cycle 4+: PC=0x0C, INSTR=jal  x0,0,     CPU halts here
```

---

## Verification Approach

**Directed Testbench (`cpu_tb_directed.v`)** — Monitors `pc_out`, `instruction`, and `alu_result` every clock cycle and prints a timestamped trace. Compatible with all simulators including free tiers.

**Class-Based SV Testbench (`rv32i_tb_fixed.sv`)** — Full OOP-style verification environment with generator, driver, monitor, scoreboard, and environment classes. Implements a self-checking scoreboard with a 32-entry shadow register file that tracks expected state and compares against DUT outputs every cycle. Targets Aldec Riviera-PRO, Cadence Xcelium, and Synopsys VCS.

**Coverage:**

| Instruction Type | Scoreboard Coverage |
|-----------------|-------------------|
| R-type (ADD/SUB/AND/OR/XOR/SLL/SRL/SRA/SLT/SLTU) | ✅ Full ALU result check |
| I-type (ADDI/ANDI/ORI/XORI/SLLI/SRLI/SRAI/SLTI/SLTIU) | ✅ Full ALU result check |
| LOAD | ✅ Address (ALU result) check |
| STORE | ✅ mem_we assertion check |
| BRANCH | ✅ Condition prediction logged |
| JAL / JALR | ✅ Return address (PC+4) check |
| LUI / AUIPC | ✅ Full result check |

---

## Interview-Level Design Questions This Project Covers

- Why is the register file read asynchronous but write synchronous?
- How does RISC-V encode five different immediate formats, and why are B-type and J-type bits scrambled?
- Why does JALR clear bit 0 of the computed target address?
- What is the difference between JAL (PC-relative) and JALR (register-relative)?
- How does the control unit distinguish ADD from SUB when the opcode is the same?
- Why does the single-cycle design use Harvard architecture?
- What is the critical path of this design and which stage dominates it?
- How does x0 being hardwired to zero enable pseudoinstructions like NOP and MV?

---

## Tools Used

| Tool | Purpose |
|------|---------|
| Aldec Riviera-PRO (EDA Playground) | Primary simulation — full SV + randomize() support |
| QuestaSim Altera Starter Edition | Secondary simulation — directed testbench |
| Icarus Verilog + GTKWave | Lightweight local simulation |
| SystemVerilog 2012 | Testbench language |
| Verilog-2001 | RTL design language |

---

## Roadmap

This project is actively being upgraded. The next milestone is a fully pipelined implementation.

### Phase 2 — 5-Stage Pipelined RV32I (In Progress)

The single-cycle datapath will be extended into a classic 5-stage pipeline:

```
IF → ID → EX → MEM → WB
```

New modules to be added:

| Module | Purpose |
|--------|---------|
| `if_id_reg.v` | Pipeline register — IF to ID boundary |
| `id_ex_reg.v` | Pipeline register — ID to EX boundary (data + control signals) |
| `ex_mem_reg.v` | Pipeline register — EX to MEM boundary |
| `mem_wb_reg.v` | Pipeline register — MEM to WB boundary |
| `forwarding_unit.v` | Detects RAW hazards, generates EX/MEM→EX and MEM/WB→EX bypass muxes |
| `hazard_unit.v` | Detects load-use hazard (stall), branch taken (flush), generates PCWrite/flush signals |

Key challenges to solve:

- **Data hazards** — Forwarding unit bypasses EX/MEM and MEM/WB results directly to EX ALU inputs for back-to-back dependent instructions
- **Load-use hazard** — The one case forwarding cannot solve: 1-cycle stall + MEM/WB forward on the following cycle
- **Control hazards** — 2-cycle branch penalty: flush IF/ID and ID/EX pipeline registers on taken branch
- **Pipeline register design** — Every control signal generated in ID must travel alongside its instruction through ID/EX, EX/MEM, and MEM/WB

Target CPI: ~1.05 with forwarding (vs 1.0 for fully pipelined, vs N for single-cycle where N = pipeline depth).

### Phase 3 — Future Extensions

- [ ] RV32M extension (multiply and divide)
- [ ] Static branch prediction (assume not-taken)
- [ ] Basic cache model (direct-mapped L1-I and L1-D)
- [ ] UVM testbench with functional coverage and assertion-based verification

---

## Author

**Harshwardhan**
B.Tech ECE — BIT Mesra, Ranchi
Targeting RTL Design and Verification roles at semiconductor companies

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue)](your-linkedin-url)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black)](your-github-url)

---

## License

This project is open source under the MIT License. See `LICENSE` for details.
