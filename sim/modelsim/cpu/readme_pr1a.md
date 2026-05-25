# PR-1a runtime smoke under the upstream CPU TB

The upstream `sim/modelsim/cpu/` has a complete CPU TB driven by a
Lua-over-socket framework: FASM assembles ASM, Lua uploads it into the
TB's RAM model, the CPU runs it, and every register change gets logged
via `cpu_export.vhd` for diff.

`lua_tests/pr1a_smoke.lua` is a fixed-listing test that exercises all
four PR-1a stub ops (FNINIT, FNSTSW AX, FNSTCW m16, FNCLEX) and leaves
visible register/memory state we can grep the log for.

## One-time setup on this workstation

1. **Lua 5.1+** — not currently installed. Options:
   - `winget install DEVCOM.Lua` (verify which package version winget surfaces)
   - or grab https://luabinaries.sourceforge.net/ portable zip → drop
     `lua54.exe` into `tools/lua/bin/` and add to PATH for the session
2. **altera_mf library path in vsim_start.bat** — current script reads
   `-L C:\Projekte\ao486_MiSTer_dev\rtl\ao486\altera_mf_both` which is
   the original author's tree, not present here. Replace with our
   ModelSim ASE install:
   ```
   vsim -novopt work.etb -t 1ps -L C:\intelFPGA_lite\17.0\modelsim_ase\altera\verilog\altera_mf
   ```
3. **Build the work library with PR-1a** — `vcom_all.bat` in this dir
   compiles the pristine TB, but for the PR-1a path you want our
   `../cpu_pr1a_elab.bat` followed by the VHDL TB compile steps from
   `vcom_all.bat` (the last `vcom -2008 cpu_export.vhd / globals.vhd /
   stringprocessor.vhd / tb.vhd` block). Easiest: pre-compile rtl with
   our batch, then run only the VHDL section of vcom_all.bat to layer
   in tb.vhd into the same work library.

## Run procedure

Two terminals.

Terminal A (ModelSim):
```cmd
cd C:\LLM\MiSTer\AO486\repos\ao486_MiSTer\sim\modelsim\cpu
vsim -novopt work.etb -t 1ps -L C:\intelFPGA_lite\17.0\modelsim_ase\altera\verilog\altera_mf
# in the vsim console:
run -all
```
The TB will print socket-listener init then idle waiting for input.

Terminal B (Lua driver):
```cmd
cd C:\LLM\MiSTer\AO486\repos\ao486_MiSTer\sim\modelsim\cpu
lua lua_tests\pr1a_smoke.lua
```
The Lua script invokes FASM (already in `lua_tests/FASM.EXE`), uploads
the binary, releases reset, and waits 260 µs simulated time for the
sequence to complete + tail-fill.

## What to look for in the CPU export log

The CPU export feature (in `cpu_export.vhd`) writes one line per
register change. Filter for:

| Event | Expected log entry |
|---|---|
| Post-FNINIT FPU CW | (no direct line; CW lives in fpu_core not in arch regs) |
| FNSTSW AX → EAX[15:0] | `EAX <= 00000000` (assumes pre-state had any value) |
| FNSTCW [0x100] | memory write trace: `MEM W 32 @00000100 037F037F` *or whatever the export format is for word writes* |
| Tail probe `mov ecx, eax` | `ECX <= 00000000` |
| Tail probe `mov edx, [ESI]` | `EDX <= 0000037F` |

If all four deltas land, **PR-1a is behavior-validated** and the next
gate is PR-1b (flip the CPUID FPU bit on so software starts trying real
ops, which then need PR-2's softfloatx80 microcode).

## Status

- pr1a_smoke.lua **written** (this iter).
- Run **deferred** — needs Lua install + vsim_start.bat path fix.
- Expected outcome documented (above).
- Smoke is a contract test: it doesn't validate arithmetic, only that
  the stub ops complete and write the right architectural state.

Real-arithmetic validation is F-A.1+ territory (Bochs softfloatx80
oracle in `sim/bochs_bridge/`).
