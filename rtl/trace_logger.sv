//==============================================================================
// RISC-Vibe RV32I Processor - Trace Logger Module
//==============================================================================
// This module generates JSON Lines (.jsonl) trace output capturing full
// processor state each cycle for visualization and debugging purposes.
//
// Output format: One JSON object per line containing:
//   - Cycle count
//   - All pipeline stage states (IF, ID, EX, MEM, WB)
//   - Register file contents
//   - Hazard and forwarding signals
//   - Branch/jump information
//==============================================================================

module trace_logger
  import riscvibe_pkg::*;
#(
  parameter string TRACE_FILE = "trace.jsonl"
) (
  // Clock and control
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // Cycle count
  input  logic [31:0] cycle_count,

  // Pipeline registers
  input  if_id_reg_t  if_id_reg,
  input  id_ex_reg_t  id_ex_reg,
  input  ex_mem_reg_t ex_mem_reg,
  input  mem_wb_reg_t mem_wb_reg,

  // Register file values (32 x 32-bit)
  input  logic [31:0] reg_file [32],

  // Hazard signals
  input  logic        stall_if,
  input  logic        stall_id,
  input  logic        flush_id,
  input  logic        flush_ex,

  // Forwarding signals
  input  logic [1:0]  forward_a,
  input  logic [1:0]  forward_b,

  // Current PC (from IF stage)
  input  logic [31:0] current_pc,

  // Current instruction being fetched
  input  logic [31:0] current_instr,

  // ALU operands and result (from EX stage)
  input  logic [31:0] alu_operand_a,
  input  logic [31:0] alu_operand_b,
  input  logic [31:0] alu_result,

  // Branch signals
  input  logic        branch_taken,
  input  logic [31:0] branch_target
);

  //============================================================================
  // File Handle
  //============================================================================
  integer trace_fd;
  logic   file_opened;

  //============================================================================
  // Shadow Pipeline Registers for Instruction Tracking
  //============================================================================
  // The actual pipeline registers don't carry PC/instruction through all stages,
  // so we maintain shadow registers just for visualization purposes.
  logic [31:0] ex_pc_shadow, ex_instr_shadow;
  logic [31:0] mem_pc_shadow, mem_instr_shadow;
  logic [31:0] wb_pc_shadow, wb_instr_shadow;

  //============================================================================
  // Formatting Functions
  //============================================================================

  // Convert 32-bit value to 8-digit lowercase hex string with 0x prefix
  // Handles undefined (x) values by treating them as 0
  function automatic string hex32(input logic [31:0] val);
    logic [31:0] safe_val;
    // Replace any x or z bits with 0 for safe JSON output
    safe_val = val;
    for (int i = 0; i < 32; i++) begin
      if (val[i] === 1'bx || val[i] === 1'bz) begin
        safe_val[i] = 1'b0;
      end
    end
    return $sformatf("0x%08x", safe_val);
  endfunction

  // Convert boolean to JSON boolean string
  // Handles undefined (x) values by treating them as false
  function automatic string bool_str(input logic val);
    if (val === 1'b1) return "true";
    else return "false";  // Treat x, z, or 0 as false
  endfunction

  // Convert ALU operation enum to string
  function automatic string alu_op_str(input alu_op_t op);
    case (op)
      ALU_ADD:  return "ADD";
      ALU_SUB:  return "SUB";
      ALU_SLL:  return "SLL";
      ALU_SLT:  return "SLT";
      ALU_SLTU: return "SLTU";
      ALU_XOR:  return "XOR";
      ALU_SRL:  return "SRL";
      ALU_SRA:  return "SRA";
      ALU_OR:   return "OR";
      ALU_AND:  return "AND";
      default:  return "UNKNOWN";
    endcase
  endfunction

  // Convert forward select to string
  function automatic string forward_str(input logic [1:0] fwd);
    case (fwd)
      2'b00:   return "NONE";
      2'b01:   return "WB";
      2'b10:   return "MEM";
      default: return "UNKNOWN";
    endcase
  endfunction

  // Convert reg_wr_src_t to string
  function automatic string reg_wr_src_str(input reg_wr_src_t src);
    case (src)
      REG_WR_ALU: return "ALU";
      REG_WR_MEM: return "MEM";
      REG_WR_PC4: return "PC4";
      REG_WR_IMM: return "IMM";
      default:    return "UNKNOWN";
    endcase
  endfunction

  // Build register file JSON array
  function automatic string build_reg_array();
    string result;
    result = "[";
    for (int i = 0; i < 32; i++) begin
      if (i == 0) begin
        // x0 is always 0
        result = {result, "\"0x00000000\""};
      end else begin
        result = {result, "\"", hex32(reg_file[i]), "\""};
      end
      if (i < 31) result = {result, ","};
    end
    result = {result, "]"};
    return result;
  endfunction

  //============================================================================
  // Compute WB stage write data
  //============================================================================
  function automatic logic [31:0] get_wb_data();
    case (mem_wb_reg.reg_wr_src)
      REG_WR_ALU: return mem_wb_reg.alu_result;
      REG_WR_MEM: return mem_wb_reg.mem_read_data;
      REG_WR_PC4: return mem_wb_reg.pc_plus_4;
      REG_WR_IMM: return mem_wb_reg.alu_result; // LUI uses ALU passthrough
      default:    return 32'h0;
    endcase
  endfunction

  //============================================================================
  // File Open on First Enable After Reset
  //============================================================================
  initial begin
    file_opened = 1'b0;
    trace_fd = 0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      if (file_opened && trace_fd != 0) begin
        $fclose(trace_fd);
      end
      file_opened <= 1'b0;
      trace_fd <= 0;
      // Reset shadow registers
      ex_pc_shadow <= 32'h0;
      ex_instr_shadow <= 32'h0;
      mem_pc_shadow <= 32'h0;
      mem_instr_shadow <= 32'h0;
      wb_pc_shadow <= 32'h0;
      wb_instr_shadow <= 32'h0;
    end else if (enable && !file_opened) begin
      trace_fd = $fopen(TRACE_FILE, "w");
      if (trace_fd == 0) begin
        $display("ERROR: trace_logger could not open file: %s", TRACE_FILE);
      end else begin
        $display("trace_logger: Opened trace file: %s", TRACE_FILE);
        file_opened <= 1'b1;
      end
    end else if (enable) begin
      // Update shadow pipeline registers each cycle
      // EX gets ID's PC/instruction (considering stalls)
      if (!stall_id) begin
        ex_pc_shadow <= if_id_reg.pc;
        ex_instr_shadow <= if_id_reg.instruction;
      end
      // MEM gets EX's shadow values
      mem_pc_shadow <= ex_pc_shadow;
      mem_instr_shadow <= ex_instr_shadow;
      // WB gets MEM's shadow values
      wb_pc_shadow <= mem_pc_shadow;
      wb_instr_shadow <= mem_instr_shadow;
    end
  end

  //============================================================================
  // Trace Logging - Write JSON Line Each Cycle
  //============================================================================
  always_ff @(posedge clk) begin
    if (rst_n && enable && file_opened && trace_fd != 0) begin
      // Build and write JSON line
      $fwrite(trace_fd, "{");

      // Cycle count
      $fwrite(trace_fd, "\"cycle\":%0d,", cycle_count);

      // IF Stage
      $fwrite(trace_fd, "\"if\":{");
      $fwrite(trace_fd, "\"pc\":\"%s\",", hex32(current_pc));
      $fwrite(trace_fd, "\"instr\":\"%s\",", hex32(current_instr));
      $fwrite(trace_fd, "\"valid\":%s", bool_str(1'b1));  // IF always fetching
      $fwrite(trace_fd, "},");

      // ID Stage (from IF/ID register)
      $fwrite(trace_fd, "\"id\":{");
      $fwrite(trace_fd, "\"pc\":\"%s\",", hex32(if_id_reg.pc));
      $fwrite(trace_fd, "\"instr\":\"%s\",", hex32(if_id_reg.instruction));
      $fwrite(trace_fd, "\"rs1\":%0d,", if_id_reg.instruction[19:15]);
      $fwrite(trace_fd, "\"rs2\":%0d,", if_id_reg.instruction[24:20]);
      $fwrite(trace_fd, "\"rd\":%0d,", if_id_reg.instruction[11:7]);
      $fwrite(trace_fd, "\"valid\":%s", bool_str(if_id_reg.valid));
      $fwrite(trace_fd, "},");

      // EX Stage (from ID/EX register + shadow)
      $fwrite(trace_fd, "\"ex\":{");
      $fwrite(trace_fd, "\"pc\":\"%s\",", hex32(id_ex_reg.pc));
      $fwrite(trace_fd, "\"instr\":\"%s\",", hex32(ex_instr_shadow));
      $fwrite(trace_fd, "\"rd\":%0d,", id_ex_reg.rd_addr);
      $fwrite(trace_fd, "\"rs1\":%0d,", id_ex_reg.rs1_addr);
      $fwrite(trace_fd, "\"rs2\":%0d,", id_ex_reg.rs2_addr);
      $fwrite(trace_fd, "\"alu_op\":\"%s\",", alu_op_str(id_ex_reg.alu_op));
      $fwrite(trace_fd, "\"result\":\"%s\",", hex32(alu_result));
      $fwrite(trace_fd, "\"valid\":%s", bool_str(id_ex_reg.valid));
      $fwrite(trace_fd, "},");

      // MEM Stage (from EX/MEM register + shadow)
      $fwrite(trace_fd, "\"mem\":{");
      $fwrite(trace_fd, "\"pc\":\"%s\",", hex32(mem_pc_shadow));
      $fwrite(trace_fd, "\"instr\":\"%s\",", hex32(mem_instr_shadow));
      $fwrite(trace_fd, "\"addr\":\"%s\",", hex32(ex_mem_reg.alu_result));
      $fwrite(trace_fd, "\"rd\":%0d,", ex_mem_reg.rd_addr);
      $fwrite(trace_fd, "\"read\":%s,", bool_str(ex_mem_reg.mem_read));
      $fwrite(trace_fd, "\"write\":%s,", bool_str(ex_mem_reg.mem_write));
      $fwrite(trace_fd, "\"valid\":%s", bool_str(ex_mem_reg.valid));
      $fwrite(trace_fd, "},");

      // WB Stage (from MEM/WB register + shadow)
      $fwrite(trace_fd, "\"wb\":{");
      $fwrite(trace_fd, "\"pc\":\"%s\",", hex32(wb_pc_shadow));
      $fwrite(trace_fd, "\"instr\":\"%s\",", hex32(wb_instr_shadow));
      $fwrite(trace_fd, "\"rd\":%0d,", mem_wb_reg.rd_addr);
      $fwrite(trace_fd, "\"data\":\"%s\",", hex32(get_wb_data()));
      $fwrite(trace_fd, "\"write\":%s,", bool_str(mem_wb_reg.reg_write));
      $fwrite(trace_fd, "\"valid\":%s", bool_str(mem_wb_reg.valid));
      $fwrite(trace_fd, "},");

      // Register file
      $fwrite(trace_fd, "\"regs\":%s,", build_reg_array());

      // Hazard signals
      $fwrite(trace_fd, "\"hazard\":{");
      $fwrite(trace_fd, "\"stall_if\":%s,", bool_str(stall_if));
      $fwrite(trace_fd, "\"stall_id\":%s,", bool_str(stall_id));
      $fwrite(trace_fd, "\"flush_id\":%s,", bool_str(flush_id));
      $fwrite(trace_fd, "\"flush_ex\":%s", bool_str(flush_ex));
      $fwrite(trace_fd, "},");

      // Forwarding signals
      $fwrite(trace_fd, "\"forward\":{");
      $fwrite(trace_fd, "\"a\":\"%s\",", forward_str(forward_a));
      $fwrite(trace_fd, "\"b\":\"%s\"", forward_str(forward_b));
      $fwrite(trace_fd, "}");

      // Close JSON object and newline
      $fwrite(trace_fd, "}\n");

      // Flush to ensure data is written
      $fflush(trace_fd);
    end
  end

  //============================================================================
  // Close File on Simulation End
  //============================================================================
  final begin
    if (file_opened && trace_fd != 0) begin
      $fclose(trace_fd);
      $display("trace_logger: Closed trace file: %s", TRACE_FILE);
    end
  end

endmodule : trace_logger
