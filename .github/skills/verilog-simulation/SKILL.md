---
name: verilog-simulation
description: 'Simulate Verilog/SystemVerilog projects with ModelSim or Questa using vlog and vsim. Use when compiling RTL, running testbenches, inspecting transcript output, reading wave.do or WLF waveform data, and deciding whether a hardware change is functionally correct.'
argument-hint: '[testbench or do-file] [optional top module]'
user-invocable: true
disable-model-invocation: false
---

# Verilog Simulation

## Purpose

Compile and simulate an existing Verilog/SystemVerilog project, then verify behavior from both textual simulation output and recorded waveform data. Do not declare a simulation successful from compilation alone or from a zero exit code alone.

## When to Use

- Validate RTL changes with `vlog` and `vsim`.
- Run an existing ModelSim/Questa `.do` file.
- Diagnose failed assertions, unexpected outputs, or state-machine behavior.
- Inspect `transcript`, `wave.do`, and `.wlf` waveform data.
- Compare a waveform signal against a testbench expectation or an RTL control path.

## Inputs To Identify

Before running commands, identify:

- The project root and simulator executable (`vsim` or `vsim.exe`).
- Source files, include directories, libraries, and the intended top-level testbench.
- Existing `.do` files, especially compile, run, and waveform setup scripts.
- Expected completion text, pass/fail counters, assertions, stop time, and key signals.
- The waveform output path, usually `vsim.wlf` or a path set by `vsim -wlf`.

Prefer the repository's existing `.do` files and launch scripts. Preserve their compile order and library names unless a failure demonstrates that they are stale.

## Procedure

### 1. Inspect the simulation entry point

Read the relevant `.do` or batch file before changing commands. Determine whether it:

- Calls `vlog` or `vcom`.
- Creates or maps a `work` library.
- Starts `vsim` with the correct top-level testbench.
- Loads `wave.do` or adds signals with `add wave`.
- Runs for a fixed time or until `$finish`.
- Writes a transcript or WLF file.

If no script exists, form a minimal command sequence from the source files and testbench rather than guessing a top module from filenames alone.

### 2. Compile with `vlog`

Run compilation from the project root or the script's expected working directory. Use the existing command first. A typical fallback is:

```powershell
vlog -work work path\to\rtl\*.sv path\to\testbench.sv
```

For SystemVerilog, preserve the project's language switches and library options. Capture the complete output. Treat warnings as findings when they involve width truncation, undriven signals, inferred latches, multiple drivers, or unsupported constructs.

Do not proceed past a compile error. Fix only the requested RTL/testbench issue or report the blocking error with the source file and message.

### 3. Run with `vsim`

Use command-line mode for repeatable runs when possible:

```powershell
vsim -c -wlf simulation.wlf work.<testbench> -do "run -all; exit"
```

When an existing `.do` file owns setup, use it:

```powershell
vsim -c -do run_test.do
```

Ensure the run produces a transcript and a WLF file. If the testbench uses a finite stop time, use that exact time. If it waits for `$finish`, use `run -all` and confirm that the run actually terminates. After collecting required transcript or signal values, run `exit` to fully close ModelSim and release `work` library and WLF file locks. If a `.do` script stops at `$stop`, append `exit` after the run or send `exit` to the active session once inspection is complete.

### 4. Read textual output

Inspect the simulator transcript and command output for:

- Compile or elaboration errors.
- Assertion failures and `$error` messages.
- `FAIL`, `ERROR`, ` mismatch`, or nonzero failure counters.
- Expected pass summaries and test counts.
- Warnings that indicate unknown (`X`) or high-impedance (`Z`) values.
- Evidence that reset occurred and the testbench reached its intended end.

A successful process exit is insufficient if the transcript contains a failed assertion or the testbench never reached its completion condition.

### 5. Read waveform setup and data

Read `wave.do` to learn which signals and hierarchy paths matter. Confirm that the WLF was produced after the current compile/run, not reused from an older simulation.

Prefer scripted CLI signal logging so waveform checks are repeatable in VS Code. Use the WLF with the ModelSim/Questa GUI only when the user explicitly requests interactive inspection. A command-line inspection pattern is:

```tcl
vsim -view simulation.wlf
# or, in an active session:
view wave
add wave -r sim:/<top>/*
```

Use the waveform to verify the behavior that textual output cannot establish, such as:

- Reset deassertion and initial state.
- Clock-to-clock state transitions.
- Instruction fetch, decode, and writeback timing.
- Register-file addresses and write enables.
- ALU inputs, operation select, result, and flags.
- PC updates and branch targets.
- RAM addresses, read/write enables, and returned data.
- Absence of unexpected `X`/`Z` propagation.

Use a `.do` script with `add wave`, `log`, `run`, and targeted signal reporting, or use ModelSim transcript commands to print the relevant signal values. State explicitly which waveform checks could not be performed. Do not claim that a WLF was visually inspected unless the GUI was actually requested and used.

### 6. Correlate output with the RTL contract

For each reported failure or suspicious waveform segment:

1. Identify the first incorrect cycle, not just the final wrong value.
2. Compare the relevant input signals, control signals, and state with the RTL and testbench expectation.
3. Determine whether the defect is in compilation, reset, stimulus, RTL logic, timing, or the expected-value checker.
4. Check that the instruction encoding or interface field order matches the consuming hardware.
5. Prefer a focused RTL or testbench fix over changing the test to accept incorrect behavior.

For processor projects, correlate instruction bits with FSM fields and datapath ports before changing assembler output or control logic.

### 7. Report completion

Report:

- Commands or `.do` files used.
- Compile result and relevant warnings.
- Simulation result, pass/fail counts, and termination evidence.
- WLF/transcript paths inspected.
- Waveform signals and cycles checked.
- Any remaining warnings, stale artifacts, or unverified waveform claims.

Declare the simulation verified only when compilation succeeds, the transcript shows the intended test completion with no relevant failures, and waveform data confirms the key behavior.

## Failure Branches

- **`vlog` not found:** locate ModelSim/Questa or use the project's configured launcher; do not silently substitute a different simulator.
- **Library or top-level not found:** inspect the `.do` compile order and `work` mapping before changing source files.
- **Simulation hangs:** inspect reset, clock generation, `$finish`, and event controls; use a bounded run to capture the last active cycle.
- **ModelSim resources remain locked:** run `exit` in the active ModelSim session before retrying; do not rely on `$stop` or `quit -f` alone to release the `work` library or WLF file.
- **No WLF generated:** check `-wlf`, simulator permissions, and whether the run was terminated before waveform writing.
- **Stale waveform:** delete or rename only the generated WLF, re-run, and compare its timestamp or header with the current run.
- **Transcript passes but waveform disagrees:** treat the waveform and checker discrepancy as unresolved; inspect signal timing and testbench sampling edges.
- **GUI requested but unavailable:** use command-line wave logging or transcript signal inspection, and report that interactive inspection was unavailable rather than claiming it occurred.

## Completion Checklist

- [ ] Correct source files and testbench identified.
- [ ] `vlog` compilation completed without relevant errors.
- [ ] `vsim` elaborated the intended top-level testbench.
- [ ] Reset and clock startup observed.
- [ ] Testbench reached its intended completion condition.
- [ ] Transcript/assertion output reviewed.
- [ ] Fresh WLF waveform data or scripted signal logging confirmed.
- [ ] Key control, data, and timing signals inspected.
- [ ] Relevant `X`/`Z`, width, latch, and driver warnings reviewed.
- [ ] Results and remaining limitations reported clearly.
