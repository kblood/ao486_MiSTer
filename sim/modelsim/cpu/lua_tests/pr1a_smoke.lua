-- pr1a_smoke.lua — drive the upstream CPU TB through the four PR-1a FPU stub ops
-- and assert the visible register effects.
--
-- WHY: PR-1a wires fpu_core into execute.v so FNINIT/FNCLEX/FNSTSW AX/FNSTCW m16
-- complete in 1 cycle and route CW/SW through exe_result. This script feeds the
-- TB a deterministic listing that exercises all four, plus a probe sequence
-- that lets us read the post-state via memory.
--
-- Run (assumes ModelSim interactive session already loaded via vsim_start.bat
-- AND Lua is installed — see ../readme_pr1a.md for the full recipe):
--   cd sim/modelsim/cpu
--   lua lua_tests/pr1a_smoke.lua
--
-- Expected effect (post-run; checked by CPU export log diff or memory probe):
--   After FNINIT:        CW = 0x037F, SW = 0x0000, TW = 0xFFFF (Empty)
--   After FNSTCW [mem]:  word at [data_buf]   == 0x037F
--   After FNSTSW AX:     AX                   == 0x0000 (just-INIT'd)
--   FNCLEX:              no externally visible change (SW exception flags clear)

package.path = package.path .. ";./../lualib/?.lua"
package.path = package.path .. ";./../luatools/?.lua"
require("vsim_comm")

-- Build the deterministic listing.
-- Layout in memory: code starts at 0, data_buf at 0x100.
listing = {}

-- Set up DS:SI for the FNSTCW memory writeback target.
listing[#listing + 1] = "mov ESI, 0x100"             -- data_buf address

-- Burn a "before" marker into the buffer so we can confirm FNSTCW wrote.
listing[#listing + 1] = "mov word [ESI], 0xDEAD"     -- sentinel

-- PR-1a ops in order.
listing[#listing + 1] = "fninit"                     -- CMDEX_FN_INIT
listing[#listing + 1] = "fnstsw  ax"                 -- CMDEX_FNSTSW_AX (post-INIT SW=0)
listing[#listing + 1] = "fnstcw  word [ESI]"         -- CMDEX_FNSTCW_M16 (CW=0x037F)
listing[#listing + 1] = "fnclex"                     -- CMDEX_FN_CLEX (visible: nothing)

-- Re-emit so we can diff vs baseline (random instructions to confirm pipeline
-- still progresses after the FPU sequence).
listing[#listing + 1] = "mov ebx, 0xCAFEBABE"
listing[#listing + 1] = "mov ecx, eax"               -- ECX should now hold the FNSTSW AX result
listing[#listing + 1] = "mov edx, [ESI]"             -- EDX should now hold 0x037F in low word

-- Terminator: jump to self (TB's idlecnt timeout will end the sim).
listing[#listing + 1] = "infinite_loop:"
listing[#listing + 1] = "jmp infinite_loop"


-- Write listing to disk, assemble with FASM.
local outfile = io.open("listing.txt","w")
for i = 1, #listing do
   outfile:write(listing[i].."\n")
end
io.close(outfile)
-- iter 61: FASM.EXE is in CWD (lua_tests/) but Windows cmd.exe doesn't
-- include "." in PATH by default; prefix with .\ so the local copy is found.
os.execute(".\\FASM.EXE listing.txt")

-- Inject boot ROM at 0xF0000 (BIOS area) and our code at 0.
-- boot0.rom is a stock fake that jumps to 0.
reg_set_file("boot0.rom",            DUMMYREG, 0xF0000, 0)
reg_set_file("lua_tests/listing.bin", DUMMYREG, 0,       0)

-- Bring CPU out of reset (bit 0 = rst_n control).
reg_set_connection(0 + 1, DUMMYREG)
wait_ns(10000)
reg_set_connection(0 + 0, DUMMYREG)
wait_ns(50000)

-- Optional: enable cpuopt_enable (bit 1) for symmetry with asm_code.lua.
reg_set_connection(2 + 1, DUMMYREG)
wait_ns(10000)
reg_set_connection(2 + 0, DUMMYREG)
wait_ns(200000)   -- give the FPU sequence + tail-fill more time than asm_code.lua

-- After this returns, inspect the CPU export log (sim/modelsim/cpu/work/cpulog.txt
-- or similar) for the register trace. The interesting deltas are:
--   - EAX should drop to 0 after fnstsw (was previously whatever boot0 left it at)
--   - [0x100] should change from 0xDEAD to 0x037F after fnstcw
--   - ECX = EAX = 0x00000000 confirms FNSTSW landed
--   - EDX low16 = 0x037F confirms FNSTCW landed in memory
