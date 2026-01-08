// Forwarding Unit for 5-stage RISC-V Pipeline
// Detects RAW (Read After Write) data hazards and selects correct data source

import riscvibe_pkg::*;

module forwarding_unit (
    // Source register addresses from ID/EX stage
    input  logic [4:0] id_ex_rs1_addr,
    input  logic [4:0] id_ex_rs2_addr,

    // EX/MEM stage signals
    input  logic [4:0] ex_mem_rd_addr,
    input  logic       ex_mem_reg_write,
    input  logic       ex_mem_valid,

    // MEM/WB stage signals
    input  logic [4:0] mem_wb_rd_addr,
    input  logic       mem_wb_reg_write,
    input  logic       mem_wb_valid,

    // Forwarding select outputs
    // 00 (FWD_NONE): No forwarding - use ID/EX register data
    // 01 (FWD_WB):   Forward from MEM/WB stage
    // 10 (FWD_MEM):  Forward from EX/MEM stage
    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    // Forwarding select encoding
    localparam logic [1:0] FWD_NONE = 2'b00;  // No forwarding
    localparam logic [1:0] FWD_WB   = 2'b01;  // Forward from MEM/WB stage
    localparam logic [1:0] FWD_MEM  = 2'b10;  // Forward from EX/MEM stage

    // Forwarding logic for rs1 (forward_a)
    always_comb begin
        // EX hazard has priority (more recent instruction)
        if (ex_mem_reg_write && ex_mem_valid &&
            (ex_mem_rd_addr != 5'b0) &&
            (ex_mem_rd_addr == id_ex_rs1_addr)) begin
            forward_a = FWD_MEM;
        end
        // MEM hazard (only if no EX hazard)
        else if (mem_wb_reg_write && mem_wb_valid &&
                 (mem_wb_rd_addr != 5'b0) &&
                 (mem_wb_rd_addr == id_ex_rs1_addr)) begin
            forward_a = FWD_WB;
        end
        // No hazard - use register file data
        else begin
            forward_a = FWD_NONE;
        end
    end

    // Forwarding logic for rs2 (forward_b)
    always_comb begin
        // EX hazard has priority (more recent instruction)
        if (ex_mem_reg_write && ex_mem_valid &&
            (ex_mem_rd_addr != 5'b0) &&
            (ex_mem_rd_addr == id_ex_rs2_addr)) begin
            forward_b = FWD_MEM;
        end
        // MEM hazard (only if no EX hazard)
        else if (mem_wb_reg_write && mem_wb_valid &&
                 (mem_wb_rd_addr != 5'b0) &&
                 (mem_wb_rd_addr == id_ex_rs2_addr)) begin
            forward_b = FWD_WB;
        end
        // No hazard - use register file data
        else begin
            forward_b = FWD_NONE;
        end
    end

endmodule
