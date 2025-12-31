//==============================================================================
// RISC-Vibe RV32I Processor - Top-Level Testbench
//==============================================================================
// This testbench instantiates the riscvibe_top module and provides:
//   - Clock generation (100MHz, 10ns period)
//   - Reset sequence
//   - Configurable simulation cycles
//   - Register monitoring and display
//   - ECALL/EBREAK detection for simulation termination
//   - Pass/fail reporting based on x10 (a0) register
//   - VCD waveform dump for GTKWave
//==============================================================================

`timescale 1ns/1ps

module tb_riscvibe_top;

  //============================================================================
  // Testbench Parameters
  //============================================================================
  parameter int    IMEM_DEPTH       = 1024;                    // Instruction memory depth
  parameter int    DMEM_DEPTH       = 4096;                    // Data memory depth
  parameter int    MAX_CYCLES_VAL   = 10000;                   // Maximum simulation cycles
  parameter int    DISPLAY_INTERVAL = 100;                     // Cycles between register dumps

  // Test program file - defaults to test_alu.hex
  // Override by setting INIT_FILE parameter in instruction_mem
  // Note: path is relative to where vvp runs (sim/ directory)
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
  riscvibe_top #(
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
  logic [31:0] current_instr;
  logic [6:0]  current_opcode;
  logic        ecall_ebreak_detected;
  logic [31:0] x10_value;  // a0 register for pass/fail

  //============================================================================
  // ECALL/EBREAK Detection
  //============================================================================
  // SYSTEM opcode is 0x73 (7'b1110011)
  // ECALL:  instruction = 0x00000073
  // EBREAK: instruction = 0x00100073
  assign current_pc     = dut.pc;
  assign current_instr  = dut.instruction;
  assign current_opcode = current_instr[6:0];
  assign ecall_ebreak_detected = (current_opcode == 7'h73);

  //============================================================================
  // VCD Waveform Dump
  //============================================================================
  initial begin
    $dumpfile("riscvibe.vcd");
    $dumpvars(0, tb_riscvibe_top);
    $display("========================================");
    $display("RISC-Vibe RV32I Testbench Started");
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

      // Debug output for each instruction
      if (cycle_count > 0) begin
        $display("[Cycle %5d] PC=0x%08h  Instr=0x%08h",
                 cycle_count, current_pc, current_instr);
      end

      // Periodic register dump
      if ((cycle_count % DISPLAY_INTERVAL == 0) && (cycle_count > 0)) begin
        display_registers();
      end

      // Check for ECALL/EBREAK
      if (ecall_ebreak_detected && (cycle_count > 0)) begin
        $display("");
        $display("========================================");
        if (current_instr == 32'h00000073) begin
          $display("ECALL detected at PC=0x%08h", current_pc);
        end else if (current_instr == 32'h00100073) begin
          $display("EBREAK detected at PC=0x%08h", current_pc);
        end else begin
          $display("SYSTEM instruction detected at PC=0x%08h", current_pc);
        end
        $display("Stopping simulation after %0d cycles", cycle_count);
        $display("========================================");

        // Display final register state
        display_registers();

        // Check pass/fail based on x10 (a0)
        check_result();

        $finish;
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

        // Check pass/fail based on x10 (a0)
        check_result();

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
    $display("x0  (zero) = 0x%08h    x16 (a6)   = 0x%08h", 32'h0, dut.u_register_file.registers[16]);
    $display("x1  (ra)   = 0x%08h    x17 (a7)   = 0x%08h", dut.u_register_file.registers[1], dut.u_register_file.registers[17]);
    $display("x2  (sp)   = 0x%08h    x18 (s2)   = 0x%08h", dut.u_register_file.registers[2], dut.u_register_file.registers[18]);
    $display("x3  (gp)   = 0x%08h    x19 (s3)   = 0x%08h", dut.u_register_file.registers[3], dut.u_register_file.registers[19]);
    $display("x4  (tp)   = 0x%08h    x20 (s4)   = 0x%08h", dut.u_register_file.registers[4], dut.u_register_file.registers[20]);
    $display("x5  (t0)   = 0x%08h    x21 (s5)   = 0x%08h", dut.u_register_file.registers[5], dut.u_register_file.registers[21]);
    $display("x6  (t1)   = 0x%08h    x22 (s6)   = 0x%08h", dut.u_register_file.registers[6], dut.u_register_file.registers[22]);
    $display("x7  (t2)   = 0x%08h    x23 (s7)   = 0x%08h", dut.u_register_file.registers[7], dut.u_register_file.registers[23]);
    $display("x8  (s0)   = 0x%08h    x24 (s8)   = 0x%08h", dut.u_register_file.registers[8], dut.u_register_file.registers[24]);
    $display("x9  (s1)   = 0x%08h    x25 (s9)   = 0x%08h", dut.u_register_file.registers[9], dut.u_register_file.registers[25]);
    $display("x10 (a0)   = 0x%08h    x26 (s10)  = 0x%08h", dut.u_register_file.registers[10], dut.u_register_file.registers[26]);
    $display("x11 (a1)   = 0x%08h    x27 (s11)  = 0x%08h", dut.u_register_file.registers[11], dut.u_register_file.registers[27]);
    $display("x12 (a2)   = 0x%08h    x28 (t3)   = 0x%08h", dut.u_register_file.registers[12], dut.u_register_file.registers[28]);
    $display("x13 (a3)   = 0x%08h    x29 (t4)   = 0x%08h", dut.u_register_file.registers[13], dut.u_register_file.registers[29]);
    $display("x14 (a4)   = 0x%08h    x30 (t5)   = 0x%08h", dut.u_register_file.registers[14], dut.u_register_file.registers[30]);
    $display("x15 (a5)   = 0x%08h    x31 (t6)   = 0x%08h", dut.u_register_file.registers[15], dut.u_register_file.registers[31]);
    $display("--------------------------------------------");
    $display("");
  endtask

  //============================================================================
  // Task: Check Test Result
  //============================================================================
  // Convention: x10 (a0) = 0 means PASS, non-zero means FAIL
  task check_result();
    x10_value = dut.u_register_file.registers[10];

    $display("");
    $display("========================================");
    $display("        TEST RESULT SUMMARY");
    $display("========================================");
    $display("x10 (a0) = 0x%08h (%0d)", x10_value, x10_value);
    $display("");

    if (x10_value == 32'h0) begin
      $display("  ######     ##     ######   ###### ");
      $display("  ##   ##   ####   ##    ## ##    ##");
      $display("  ######   ##  ##  ##       ##      ");
      $display("  ##      ########  ######   ###### ");
      $display("  ##      ##    ##       ##       ##");
      $display("  ##      ##    ## ##    ## ##    ##");
      $display("  ##      ##    ##  ######   ###### ");
      $display("");
      $display("TEST PASSED!");
    end else begin
      $display("  #######   ##     ## ##      ");
      $display("  ##       ####    ## ##      ");
      $display("  #####   ##  ##   ## ##      ");
      $display("  ##     ########  ## ##      ");
      $display("  ##     ##    ##  ## ##      ");
      $display("  ##     ##    ##  ## ########");
      $display("");
      $display("TEST FAILED! (Error code: %0d)", x10_value);
    end
    $display("========================================");
  endtask

endmodule : tb_riscvibe_top
