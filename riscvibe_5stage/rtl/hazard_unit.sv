// Hazard Detection Unit for 5-stage RISC-V Pipeline
// Detects load-use hazards (data hazards) and control hazards (branch taken)

module hazard_unit
    import riscvibe_pkg::*;
(
    // Source register addresses from IF/ID stage
    input  logic [4:0] if_id_rs1_addr,
    input  logic [4:0] if_id_rs2_addr,

    // Destination register and control signals from ID/EX stage
    input  logic [4:0] id_ex_rd_addr,
    input  logic       id_ex_mem_read,  // Indicates LOAD instruction
    input  logic       id_ex_valid,

    // Branch control from EX stage
    input  logic       branch_taken,

    // Stall signals
    output logic       stall_if,        // Stall IF stage (hold PC)
    output logic       stall_id,        // Stall ID stage (hold IF/ID register)

    // Flush signals
    output logic       flush_id,        // Flush ID stage (insert bubble in ID/EX)
    output logic       flush_ex         // Flush EX stage (insert bubble in EX/MEM)
);

    // Internal hazard detection signals
    logic load_use_hazard;
    logic control_hazard;

    // =========================================================================
    // Load-Use Hazard Detection (Data Hazard - requires stall)
    // =========================================================================
    // A load instruction in EX stage is followed by an instruction in ID
    // that uses the loaded register. We must stall for one cycle to allow
    // the load to complete before the dependent instruction can proceed.

    always_comb begin
        load_use_hazard = id_ex_mem_read && id_ex_valid &&
                          (id_ex_rd_addr != 5'b0) &&
                          ((id_ex_rd_addr == if_id_rs1_addr) ||
                           (id_ex_rd_addr == if_id_rs2_addr));
    end

    // =========================================================================
    // Control Hazard Detection (Branch Taken)
    // =========================================================================
    // When a branch is taken in EX stage, we need to flush the instructions
    // that were speculatively fetched in IF and ID stages.

    always_comb begin
        control_hazard = branch_taken;
    end

    // =========================================================================
    // Combined Hazard Control Logic
    // =========================================================================
    // When both hazards occur simultaneously, the control hazard takes
    // precedence because the branch makes the load-use irrelevant
    // (the dependent instruction will be flushed anyway).

    always_comb begin
        // Stall signals - only for load-use hazard
        stall_if = load_use_hazard;
        stall_id = load_use_hazard;

        // Flush ID stage - for both load-use (insert bubble) and control hazard
        flush_id = load_use_hazard || control_hazard;

        // Flush EX stage - only for control hazard (branch taken)
        flush_ex = control_hazard;
    end

endmodule
