# Processor Demo

## Goal
- The visualizer takes input of an architecture file, and a program trace
- Demo running two processors (single-stage and 5-stage), and each of their own program traces

## Task
- Use this file as a guide
- Write a more detailed implementation and verification plan, in ./project-docs/proc_demo_impl.md
- Your plan should follow the order of the below sections

## 5-stage Processor
- Currently in the git repom in ./rtl
- reorganize into a new folder called ./riscvibe_5stage
    - this folder should contain the rtl, and verification files (tb, unit tests)
- Currently the architecture file is in ./sim/visualizer/architectures/riscv_5stage
- Currently the program traces are in ./sim/*_trace.jsonl

## Single-stage Processor
- This was completed at first, then upgraded to the current 5-stage processor
- Look into the git history, and recreate the Single-stage processor in ./riscvibe_1stage
- Reference the 5-stage processor, for each unit test and test program, determine if it applies to the single stage processor. If so, create a version of these tests under riscvibe_1stage
- Reference the current ./riscvibe_asm assembler, which is built for the 5-stage processor. Write a version for the single-stage processor. Do not change the current assembler!
- Create traces using the assembler and running it through the single-stage processor
- Create the architecture file for this single-stage processor, reference ./sim/visualizer/architectures

## Documentation
- Write a guide on how to run the single-stage and 5-stage processors, and where the relevant files are located
- Update ./project-docs/history.md
- Git commit