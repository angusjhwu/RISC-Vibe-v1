# 5-Stage PIPELINE.md
Adapting the current RISC-Vibe processor to use a standard 5 stage-pipeline FDXMW

## Goal
- Implement a 5-stage pipeline with stages Fetch, Decode, Execute, Memory, Writeback
- Implement for all currently supported (rv32I) instrucitons, found in './project-docs/riscv-isa-manual/src/rv32.adoc'
- Update our assembler in "./riscvibe_asm"

## Work Flow
- Document all user prompts in a history file
- When working on a new feature, first create a new planning document in ./project-docs, then compress current context, before proceeding
- Verify functionality of every feature, including example risc-v programs
- Use subagents for planning, implementation, and verification

## Local Environment
- MacOS
- Can use Icarus-verilog or Verilator for verification