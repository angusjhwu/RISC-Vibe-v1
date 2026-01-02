# Simulator Plan

## Goal
- Have a GUI that shows current processor states (registers, stage flags)
- Step through a program's run to visualize hardware usage, realtime is a plus

## System Environment
- Testing on Mac OS
- But this GUI should work on any platform
- Can use any GUI framework, as long as it is relatively light weight and is interactive (can accept files, and users can click buttons)

## Potential implementation (need to evaluate)
- Make a new file format (could be a csv) that outputs all the processor states at each cycle (each cycle is a row entry, each column is a processor state/value)
- GUI has all the processor states and values organized by pipeline stage
- GUI allows the input of the csv file, then user can click arrows to step through each cycle, and can see the states change
    - For example, each cycle a new instruction appears in the first stage, then next cycle instruction A move from 1st to 2nd stage, but new instruction B appears on 1st stage etc
    - It would be cool to be able to step forward and backwards in processor cycles