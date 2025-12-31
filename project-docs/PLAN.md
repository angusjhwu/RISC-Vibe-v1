# PLAN.md
Making a RISC-V processor from scratch, called "RISC-Vibe"

## Goal
- Make a RISC-V processor, single stage, using SystemVerilog or Verilog
- Supports RV32I (base integer)
- Follows standard RiscV calling convention
- Framework so users can input their own riscv programs and simulate processor functions

## Work Flow
- Document all user prompts in a history file
- When working on a new feature, first create a new planning document in ./project-docs, then compress current context, before proceeding
- Verify functionality of every feature, including example risc-v programs
- Make frequent git commits to track progress
- Use subagents for planning, implementation, and verification

## Local Environment
- MacOS
- Can use Icarus-verilog or Verilator for verification
- RV32I ISA can be found in './project-docs/riscv-isa-manual/src/rv32.adoc'

## Future Work
- Processor to use 5-stage pipeline (FDXMW)
- Expand to support RV32G
- Visual GUI to step through program, to track processor states, registers, and memories