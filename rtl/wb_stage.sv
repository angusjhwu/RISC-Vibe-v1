//==============================================================================
// RISC-Vibe RV32I Processor - Writeback Stage
//==============================================================================
// This module implements the Writeback (WB) stage of the 5-stage pipeline.
// It selects the appropriate data source for register file write-back based
// on the instruction type and generates the write enable signal.
//==============================================================================

module wb_stage
  import riscvibe_pkg::*;
(
  //----------------------------------------------------------------------------
  // Pipeline Register Input
  //----------------------------------------------------------------------------
  input  mem_wb_reg_t       mem_wb_in,      // Input from MEM/WB pipeline register

  //----------------------------------------------------------------------------
  // Register File Write Interface
  //----------------------------------------------------------------------------
  output logic [4:0]        wb_rd_addr,     // Destination register address
  output logic [31:0]       wb_rd_data,     // Data to write to register file
  output logic              wb_reg_write    // Write enable for register file
);

  //============================================================================
  // Writeback Data Selection
  //============================================================================
  // Select the data to write back to the register file based on reg_wr_src:
  // - REG_WR_ALU: ALU result (arithmetic/logical operations)
  // - REG_WR_MEM: Memory read data (load instructions)
  // - REG_WR_PC4: PC + 4 (JAL/JALR link address)
  // - REG_WR_IMM: Immediate value via ALU result (LUI/AUIPC)
  //              Note: For LUI, the immediate is passed through the ALU
  //              with operand_a=0 and op=ADD, so alu_result contains the value

  always_comb begin
    case (mem_wb_in.reg_wr_src)
      REG_WR_ALU:  wb_rd_data = mem_wb_in.alu_result;
      REG_WR_MEM:  wb_rd_data = mem_wb_in.mem_read_data;
      REG_WR_PC4:  wb_rd_data = mem_wb_in.pc_plus_4;
      REG_WR_IMM:  wb_rd_data = mem_wb_in.alu_result;  // Immediate passed through ALU
      default:     wb_rd_data = mem_wb_in.alu_result;
    endcase
  end

  //============================================================================
  // Output Assignments
  //============================================================================
  // Pass through the destination register address from the pipeline register.
  // Only enable register write when the instruction is valid - this prevents
  // writes from flushed or invalid instructions in the pipeline.

  assign wb_rd_addr   = mem_wb_in.rd_addr;
  assign wb_reg_write = mem_wb_in.reg_write && mem_wb_in.valid;

endmodule : wb_stage
