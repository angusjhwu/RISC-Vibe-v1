//==============================================================================
// RISC-Vibe RV32I Processor - Execute Stage (EX)
//==============================================================================
// This module implements the Execute stage of the 5-stage pipeline.
// It performs ALU operations, calculates branch targets, and handles
// data forwarding from later pipeline stages.
//==============================================================================

module ex_stage
  import riscvibe_pkg::*;
(
    // Clock and reset
    input  logic            clk,
    input  logic            rst_n,

    // Pipeline register input from ID stage
    input  id_ex_reg_t      id_ex_in,

    // Forwarding control inputs
    input  logic [1:0]      forward_a,        // Forwarding select for operand A
    input  logic [1:0]      forward_b,        // Forwarding select for operand B

    // Forwarded data inputs
    input  logic [31:0]     ex_mem_alu_result, // Forwarded from EX/MEM stage
    input  logic [31:0]     mem_wb_rd_data,    // Forwarded from MEM/WB (already muxed)

    // Pipeline register output to MEM stage
    output ex_mem_reg_t     ex_mem_out,

    // Branch/jump outputs to IF stage and hazard unit
    output logic            branch_taken,
    output logic [31:0]     branch_target,
    output logic [31:0]     jalr_target,
    output branch_type_t    branch_type_out
);

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // Forwarded operand values
    logic [31:0] forwarded_rs1;
    logic [31:0] forwarded_rs2;

    // ALU operands after source selection
    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;

    // ALU outputs
    logic [31:0] alu_result;
    logic        alu_zero;

    //==========================================================================
    // Forwarding Muxes
    //==========================================================================
    // Select operand sources based on forwarding control signals
    // forward_a/b = 00: use ID/EX register value (no forwarding)
    // forward_a/b = 01: use MEM/WB data (forward from writeback)
    // forward_a/b = 10: use EX/MEM ALU result (forward from memory stage)

    always_comb begin
        case (forward_a)
            2'b00:   forwarded_rs1 = id_ex_in.rs1_data;
            2'b01:   forwarded_rs1 = mem_wb_rd_data;
            2'b10:   forwarded_rs1 = ex_mem_alu_result;
            default: forwarded_rs1 = id_ex_in.rs1_data;
        endcase
    end

    always_comb begin
        case (forward_b)
            2'b00:   forwarded_rs2 = id_ex_in.rs2_data;
            2'b01:   forwarded_rs2 = mem_wb_rd_data;
            2'b10:   forwarded_rs2 = ex_mem_alu_result;
            default: forwarded_rs2 = id_ex_in.rs2_data;
        endcase
    end

    //==========================================================================
    // ALU Source Selection Muxes
    //==========================================================================
    // Select between forwarded register values, PC, or immediate

    // ALU Source A: forwarded rs1 or PC (for AUIPC)
    always_comb begin
        if (id_ex_in.alu_src_a) begin
            alu_operand_a = id_ex_in.pc;
        end else begin
            alu_operand_a = forwarded_rs1;
        end
    end

    // ALU Source B: forwarded rs2 or immediate
    always_comb begin
        if (id_ex_in.alu_src_b) begin
            alu_operand_b = id_ex_in.immediate;
        end else begin
            alu_operand_b = forwarded_rs2;
        end
    end

    //==========================================================================
    // ALU Instance
    //==========================================================================

    alu u_alu (
        .operand_a (alu_operand_a),
        .operand_b (alu_operand_b),
        .alu_op    (id_ex_in.alu_op),
        .result    (alu_result),
        .zero      (alu_zero)
    );

    //==========================================================================
    // Branch Unit Instance
    //==========================================================================
    // Note: Branch unit uses FORWARDED rs1/rs2 data for comparison

    branch_unit u_branch_unit (
        .rs1_data     (forwarded_rs1),
        .rs2_data     (forwarded_rs2),
        .branch_type  (id_ex_in.branch_type),
        .branch_cmp   (id_ex_in.branch_cmp),
        .branch_taken (branch_taken)
    );

    //==========================================================================
    // Branch Target Calculation
    //==========================================================================
    // Branch target: PC + immediate (for branches and JAL)
    // JALR target: (rs1 + immediate) & ~1 (LSB cleared per RISC-V spec)

    assign branch_target = id_ex_in.pc + id_ex_in.immediate;
    assign jalr_target   = (forwarded_rs1 + id_ex_in.immediate) & ~32'h1;

    //==========================================================================
    // Branch Type Output
    //==========================================================================
    // Pass branch type to IF stage for PC selection

    assign branch_type_out = id_ex_in.branch_type;

    //==========================================================================
    // EX/MEM Pipeline Register Output
    //==========================================================================
    // Pass through relevant signals to the Memory stage

    always_comb begin
        ex_mem_out.pc_plus_4  = id_ex_in.pc_plus_4;
        ex_mem_out.alu_result = alu_result;
        ex_mem_out.rs2_data   = forwarded_rs2;       // Forwarded value for stores
        ex_mem_out.rd_addr    = id_ex_in.rd_addr;
        ex_mem_out.mem_read   = id_ex_in.mem_read;
        ex_mem_out.mem_write  = id_ex_in.mem_write;
        ex_mem_out.mem_width  = id_ex_in.mem_width;
        ex_mem_out.reg_write  = id_ex_in.reg_write;
        ex_mem_out.reg_wr_src = id_ex_in.reg_wr_src;
        ex_mem_out.valid      = id_ex_in.valid;
    end

endmodule : ex_stage
