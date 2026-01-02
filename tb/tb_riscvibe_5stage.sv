//==============================================================================
// RISC-Vibe RV32I Processor - 5-Stage Pipeline Testbench
//==============================================================================
// This testbench instantiates the riscvibe_5stage_top module and provides:
//   - Clock generation (100MHz, 10ns period)
//   - Reset sequence
//   - Configurable simulation cycles
//   - Pipeline stage monitoring
//   - Register monitoring and display
//   - ECALL/EBREAK detection for simulation termination
//   - VCD waveform dump for GTKWave
//
// Note: Pass/fail validation is handled by the regression_pipeline.py script
// which checks test-specific expected register values.
//==============================================================================

`timescale 1ns/1ps

module tb_riscvibe_5stage;

  //============================================================================
  // Testbench Parameters
  //============================================================================
  parameter int    IMEM_DEPTH       = 1024;                    // Instruction memory depth
  parameter int    DMEM_DEPTH       = 4096;                    // Data memory depth
  parameter int    MAX_CYCLES_VAL   = 10000;                   // Maximum simulation cycles
  parameter int    DISPLAY_INTERVAL = 100;                     // Cycles between register dumps

  // Test program file - defaults to test_alu.hex
`ifndef TESTPROG_FILE
  `define TESTPROG_FILE "../programs/test_alu.hex"
`endif

  //============================================================================
  // Clock and Reset Signals
  //============================================================================
  logic clk;
  logic rst_n;

  //============================================================================
  // Clock Generation - 100MHz (10ns period)
  //============================================================================
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 5ns half-period = 10ns period = 100MHz
  end

  //============================================================================
  // DUT Instantiation
  //============================================================================
  riscvibe_5stage_top #(
    .IMEM_DEPTH     (IMEM_DEPTH),
    .DMEM_DEPTH     (DMEM_DEPTH),
    .IMEM_INIT_FILE (`TESTPROG_FILE)
  ) dut (
    .clk   (clk),
    .rst_n (rst_n)
  );

  //============================================================================
  // Simulation Variables
  //============================================================================
  int cycle_count;
  logic [31:0] current_pc;
  logic [31:0] if_instruction;
  logic [31:0] id_instruction;
  logic [6:0]  id_opcode;
  logic        ecall_ebreak_detected;

  //============================================================================
  // Pipeline Stage Monitoring
  //============================================================================
  // IF Stage
  assign current_pc = dut.u_if_stage.pc_reg;
  assign if_instruction = dut.if_id_out.instruction;

  // ID Stage
  assign id_instruction = dut.if_id_reg.instruction;
  assign id_opcode = id_instruction[6:0];

  // ECALL/EBREAK Detection
  // SYSTEM opcode is 0x73 (7'b1110011)
  // ECALL:  instruction = 0x00000073
  // EBREAK: instruction = 0x00100073
  // Detect in MEM/WB stage to ensure instruction has completed
  assign ecall_ebreak_detected = dut.mem_wb_reg.valid &&
                                  (dut.ex_mem_reg.valid == 1'b0) &&
                                  (id_opcode == 7'h73);

  //============================================================================
  // VCD Waveform Dump
  //============================================================================
  initial begin
    $dumpfile("riscvibe_5stage.vcd");
    $dumpvars(0, tb_riscvibe_5stage);
    $display("========================================");
    $display("RISC-Vibe 5-Stage Pipeline Testbench");
    $display("========================================");
    $display("Test Program: %s", `TESTPROG_FILE);
    $display("Max Cycles:   %0d", MAX_CYCLES_VAL);
    $display("Clock Period: 10ns (100MHz)");
    $display("========================================");
  end

  //============================================================================
  // Reset Sequence
  //============================================================================
  initial begin
    rst_n = 1'b0;
    cycle_count = 0;

    // Hold reset for 5 clock cycles
    repeat (5) @(posedge clk);

    $display("[%0t] Releasing reset...", $time);
    rst_n = 1'b1;

    // Wait one cycle for reset to propagate
    @(posedge clk);
    $display("[%0t] Reset released, starting execution", $time);
    $display("========================================");
  end

  //============================================================================
  // Main Simulation Loop
  //============================================================================
  always @(posedge clk) begin
    if (rst_n) begin
      cycle_count <= cycle_count + 1;

      // Debug output for each cycle
      if (cycle_count > 0) begin
        $display("[Cycle %5d] IF_PC=0x%08h  IF_Instr=0x%08h  ID_Instr=0x%08h  Stall=%b  Flush=%b",
                 cycle_count, current_pc, if_instruction, id_instruction,
                 dut.stall_if, dut.flush_id);
      end

      // Periodic register dump
      if ((cycle_count % DISPLAY_INTERVAL == 0) && (cycle_count > 0)) begin
        display_registers();
        display_pipeline_state();
      end

      // Check for ECALL/EBREAK (detect when SYSTEM instruction reaches WB)
      // We check when the pipeline has an ECALL/EBREAK and it's been committed
      if (cycle_count > 5) begin
        // Check if we see ECALL/EBREAK in the ID stage and previous stages are empty
        if ((id_opcode == 7'h73) &&
            (id_instruction == 32'h00000073 || id_instruction == 32'h00100073)) begin
          // Wait a few cycles for pipeline to drain
          repeat (5) @(posedge clk);
          cycle_count = cycle_count + 5;

          $display("");
          $display("========================================");
          if (id_instruction == 32'h00000073) begin
            $display("ECALL detected");
          end else begin
            $display("EBREAK detected");
          end
          $display("Stopping simulation after %0d cycles", cycle_count);
          $display("========================================");

          // Display final register state
          display_registers();
          display_pipeline_state();

          // Display x10 for quick reference (validation done by regression script)
          display_x10_summary();

          $finish;
        end
      end

      // Check for maximum cycles
      if (cycle_count >= MAX_CYCLES_VAL) begin
        $display("");
        $display("========================================");
        $display("ERROR: Maximum cycles (%0d) reached!", MAX_CYCLES_VAL);
        $display("Simulation timeout - possible infinite loop");
        $display("========================================");

        // Display final register state
        display_registers();
        display_pipeline_state();

        // Display x10 for quick reference (validation done by regression script)
        display_x10_summary();

        $finish;
      end
    end
  end

  //============================================================================
  // Task: Display Register Contents
  //============================================================================
  task display_registers();
    $display("");
    $display("--- Register File Contents (Cycle %0d) ---", cycle_count);
    $display("PC  = 0x%08h", current_pc);
    $display("");

    // x0 is always 0 (hardwired)
    $display("x0  (zero) = 0x%08h    x16 (a6)   = 0x%08h", 32'h0, dut.u_id_stage.u_register_file.registers[16]);
    $display("x1  (ra)   = 0x%08h    x17 (a7)   = 0x%08h", dut.u_id_stage.u_register_file.registers[1], dut.u_id_stage.u_register_file.registers[17]);
    $display("x2  (sp)   = 0x%08h    x18 (s2)   = 0x%08h", dut.u_id_stage.u_register_file.registers[2], dut.u_id_stage.u_register_file.registers[18]);
    $display("x3  (gp)   = 0x%08h    x19 (s3)   = 0x%08h", dut.u_id_stage.u_register_file.registers[3], dut.u_id_stage.u_register_file.registers[19]);
    $display("x4  (tp)   = 0x%08h    x20 (s4)   = 0x%08h", dut.u_id_stage.u_register_file.registers[4], dut.u_id_stage.u_register_file.registers[20]);
    $display("x5  (t0)   = 0x%08h    x21 (s5)   = 0x%08h", dut.u_id_stage.u_register_file.registers[5], dut.u_id_stage.u_register_file.registers[21]);
    $display("x6  (t1)   = 0x%08h    x22 (s6)   = 0x%08h", dut.u_id_stage.u_register_file.registers[6], dut.u_id_stage.u_register_file.registers[22]);
    $display("x7  (t2)   = 0x%08h    x23 (s7)   = 0x%08h", dut.u_id_stage.u_register_file.registers[7], dut.u_id_stage.u_register_file.registers[23]);
    $display("x8  (s0)   = 0x%08h    x24 (s8)   = 0x%08h", dut.u_id_stage.u_register_file.registers[8], dut.u_id_stage.u_register_file.registers[24]);
    $display("x9  (s1)   = 0x%08h    x25 (s9)   = 0x%08h", dut.u_id_stage.u_register_file.registers[9], dut.u_id_stage.u_register_file.registers[25]);
    $display("x10 (a0)   = 0x%08h    x26 (s10)  = 0x%08h", dut.u_id_stage.u_register_file.registers[10], dut.u_id_stage.u_register_file.registers[26]);
    $display("x11 (a1)   = 0x%08h    x27 (s11)  = 0x%08h", dut.u_id_stage.u_register_file.registers[11], dut.u_id_stage.u_register_file.registers[27]);
    $display("x12 (a2)   = 0x%08h    x28 (t3)   = 0x%08h", dut.u_id_stage.u_register_file.registers[12], dut.u_id_stage.u_register_file.registers[28]);
    $display("x13 (a3)   = 0x%08h    x29 (t4)   = 0x%08h", dut.u_id_stage.u_register_file.registers[13], dut.u_id_stage.u_register_file.registers[29]);
    $display("x14 (a4)   = 0x%08h    x30 (t5)   = 0x%08h", dut.u_id_stage.u_register_file.registers[14], dut.u_id_stage.u_register_file.registers[30]);
    $display("x15 (a5)   = 0x%08h    x31 (t6)   = 0x%08h", dut.u_id_stage.u_register_file.registers[15], dut.u_id_stage.u_register_file.registers[31]);
    $display("--------------------------------------------");
    $display("");
  endtask

  //============================================================================
  // Task: Display Pipeline State
  //============================================================================
  task display_pipeline_state();
    $display("");
    $display("--- Pipeline State (Cycle %0d) ---", cycle_count);
    $display("IF/ID: PC=0x%08h Instr=0x%08h Valid=%b",
             dut.if_id_reg.pc, dut.if_id_reg.instruction, dut.if_id_reg.valid);
    $display("ID/EX: PC=0x%08h rd=%0d rs1=%0d rs2=%0d RegWr=%b MemRd=%b MemWr=%b Valid=%b",
             dut.id_ex_reg.pc, dut.id_ex_reg.rd_addr, dut.id_ex_reg.rs1_addr,
             dut.id_ex_reg.rs2_addr, dut.id_ex_reg.reg_write,
             dut.id_ex_reg.mem_read, dut.id_ex_reg.mem_write, dut.id_ex_reg.valid);
    $display("EX/MEM: ALU=0x%08h rd=%0d RegWr=%b MemRd=%b MemWr=%b Valid=%b",
             dut.ex_mem_reg.alu_result, dut.ex_mem_reg.rd_addr,
             dut.ex_mem_reg.reg_write, dut.ex_mem_reg.mem_read,
             dut.ex_mem_reg.mem_write, dut.ex_mem_reg.valid);
    $display("MEM/WB: ALU=0x%08h MemData=0x%08h rd=%0d RegWr=%b Valid=%b",
             dut.mem_wb_reg.alu_result, dut.mem_wb_reg.mem_read_data,
             dut.mem_wb_reg.rd_addr, dut.mem_wb_reg.reg_write, dut.mem_wb_reg.valid);
    $display("Forwarding: A=%b B=%b  Hazard: StallIF=%b StallID=%b FlushID=%b FlushEX=%b",
             dut.forward_a, dut.forward_b, dut.stall_if, dut.stall_id,
             dut.flush_id, dut.flush_ex);
    $display("-----------------------------------------");
    $display("");
  endtask

  //============================================================================
  // Task: Display Simulation Complete
  //============================================================================
  task display_x10_summary();
    $display("");
    $display("========================================");
    $display("        SIMULATION COMPLETE");
    $display("========================================");
    $display("Run regression_pipeline.py for pass/fail validation.");
    $display("========================================");
  endtask

endmodule : tb_riscvibe_5stage
