derive_pll_clocks
derive_clock_uncertainty

set clk_sys   {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}
set clk_uart1 {*|pll|pll_inst|altera_pll_i|*[1].*|divclk}
set clk_mpu   {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}
set clk_audio {pll_audio|pll_audio_inst|altera_pll_i|*[0].*|divclk}
set clk_vga   {*|pll|pll_inst|altera_pll_i|*[4].*|divclk}
set clk_uart2 {*|pll|pll_inst|altera_pll_i|*[5].*|divclk}

set_false_path -from [get_clocks $clk_sys]   -to [get_clocks $clk_vga]
set_false_path -from [get_clocks $clk_vga]   -to [get_clocks $clk_sys]

set_false_path -from [get_clocks $clk_audio] -to [get_clocks $clk_sys]
set_false_path -from [get_clocks $clk_sys]   -to [get_clocks $clk_audio]

set_false_path -from [get_clocks $clk_sys]   -to [get_clocks $clk_uart1]
set_false_path -from [get_clocks $clk_uart1] -to [get_clocks $clk_sys]
set_false_path -from [get_clocks $clk_sys]   -to [get_clocks $clk_uart2]
set_false_path -from [get_clocks $clk_uart2] -to [get_clocks $clk_sys]

set_false_path -from [get_clocks $clk_sys]   -to [get_clocks $clk_mpu]
set_false_path -from [get_clocks $clk_mpu]   -to [get_clocks $clk_sys]

set_multicycle_path -from {emu:emu|reset*} -setup 2
set_multicycle_path -from {emu:emu|reset*} -hold 1

# PR-2c.12 (iter 165): FPU combinational arith/converter datapath multicycle.
# The floatx80 add/sub/mul + load/store converters compute the result that
# lands in execute_fpu's z_lat/flags_lat through ~106 ns of series logic
# (convert -> classify -> align -> add/mul -> normalize -> round -> pack),
# which cannot close in one 11.1 ns (90 MHz clk_sys) cycle.  execute_fpu now
# parks these ops ARITH_WAIT_CYCLES(=12) cycles in S_ARITHWAIT with the
# operand registers held stable (mem-form keeps mem_z live from mem_data_lat;
# reg-form holds b_lat), capturing z_lat/flags_lat only on the final cycle.
# Relax the setup check on these paths to 12 cycles (hold 11) to match.  The
# operands are guaranteed stable for 13 physical cycles before capture, so 12
# leaves one cycle of margin.  Iterative div/rem/sqrt/bcd are unaffected (their
# results reach z_lat from their own clocked-primitive output registers).
#
# SOURCE x DESTINATION anchored.  The FPU combinational compute is a function of
# the per-op latches in execute_fpu (operands a_lat/b_lat/mem_data_lat/mem80_hi_lat
# AND the control latches fild_width_lat/is_fbld_lat/is_fild_lat/is_mem_form_lat/
# mem_fmt_lat/kind_lat/reverse_lat/is_fld_m80_lat/... — ALL the *_lat regs).  Its
# result fans out to THREE capture sites, every one of them clocked only after the
# FSM wait, i.e. >=13 cycles after the latches stabilize at S_IDLE/S_COMPUTE:
#   - z_lat / flags_lat        (captured in S_ARITHWAIT / the div-rem-sqrt waits)
#   - fpu_csr's c_lo / status  (condition codes + exc flags, captured at S_RETIRE)
# So multicycle EXACTLY those compute->result paths: -from the stable *_lat regs,
# -to {z_lat, flags_lat, every fpu_csr reg}.  Both lists are needed:
#   * -from restricted to *_lat EXCLUDES state/arith_wait_cnt (the only per-cycle
#     regs), so the FSM next-state logic (e.g. state <= kind_lat==KIND_DIV?...)
#     and fpu_busy/fpu_done gating stay correctly SINGLE-cycle.
#   * -to restricted to z_lat/flags_lat/fpu_csr EXCLUDES the control->FSM cone and
#     the FLDCW/external cw-load path into fpu_csr (whose launch is not a *_lat).
# DESTINATION-ANCHORED (no -from).  The deep FPU combinational compute is fed by
# THREE source modules — execute_fpu (operands/control latches AND the FSM `state`,
# which is a data input via the arith_b mux), fpu_regfile (rd_data), and fpu_csr
# (cw precision/rounding).  Chasing each launch module with -from is whack-a-mole
# (this constraint was wrong four times for exactly that reason — see trail below).
# But the CAPTURE side is small and fixed: only z_lat, flags_lat, and the fpu_csr
# status/condition-code bits ever clock the deep result; every other FPU-fed
# register (regfile write data, tags, ...) receives an already-REGISTERED value.
# So anchor purely on the destination: every path ENDING at z_lat/flags_lat/fpu_csr
# is multicycle, whatever its launch.  Sound because all three capture sites are
# clocked only in/after the FSM wait (S_ARITHWAIT / div-rem-sqrt-bcd waits / the
# S_RETIRE strobe), i.e. >=13 cycles after every feeding latch, regfile read, and
# cw stabilize.  Paths into fpu_csr that are NOT the FPU compute (FLDCW/FNINIT cw
# loads, sw accumulate) are shallow reg->reg/constant hops that pass single-cycle,
# so relaxing them is harmless; FPU ops are >=18 cycles apart so the sw|=flags
# accumulate self-loop is likewise safe at -setup 12.
#
# Constraint-evolution trail (each -from restriction left a different uncovered
# launch register dominating the failing set):
#   -from {a/b/mem_data/mem80}        -> fild_width_lat->z_lat        -60 ns
#   -to   {z_lat/flags_lat} only      -> mem_data_lat->c_lo           -51 ns
#   -from {*_lat*}                     -> state.S_COMPUTE->z_lat       -53 ns
#   -from {all execute_fpu regs}      -> fpu_regfile|rd_data->z_lat   -52 ns
#   -to {z_lat/flags_lat/fpu_csr}, NO -from                           <-- this
# Destinations also include the whole FPU register file (u_fpu_regfile|data/tag):
# the load-and-push ops (FLD/FILD/FBLD m32/m64/m80/int/BCD) write rf_wr_data = the
# COMBINATIONAL converter output mem_z (int_to_floatx80 / bcd_to_int64->floatx80 /
# floatN_to_floatx80) straight into the regfile at the push state, bypassing z_lat.
# That converter chain (esp. FBLD's bcd_to_int64) is as deep as the arith cone and
# launches from the same per-op latches.  The regfile is FPU-PRIVATE (written only by
# execute_fpu, only at a push/retire strobe many cycles into the op; read only at the
# next op's S_FETCH, >=18 cycles later), so a -to-only relax needs no -from guard.
# Destinations ALSO include the iterative primitives' start-loaded operand-capture
# registers (u_div|a_reg/b_reg, u_floatx80_remainder|a_reg/b_reg/rnd_reg,
# u_floatx80_sqrt|a_reg, u_int64_to_bcd|val_reg).  These freeze op_a/op_b (= the deep
# mem-form convert/align cone, ~55 ns) on the start pulse, which PR-2c.13 moved to the
# TERMINAL S_ARITHWAIT cycle so the cone has ARITH_WAIT_CYCLES to settle first.  Only
# the CAPTURE registers are listed (NOT the per-cycle iteration state a_reg->root_reg/
# quotient/etc, which MUST stay single-cycle); a -to on the load relaxes only paths
# ENDING at the capture reg, leaving the capture-reg-> iteration paths at 1 cycle.
# All FPU-private (fed only by the FPU operand cone), so -to-only needs no -from guard.
# wr_fpu_store_data[*] (pipeline write_inst): the FPU memory-store value for FST/FSTP
# m32/m64, FIST/FISTP, FBSTP.  execute_fpu drives store_data COMBINATIONALLY from a_lat
# through the narrowing converter (floatx80->float32/64, floatx80->int, int64->BCD) and
# strobes the write-stage capture (store_ready) at S_RETIRE — >=12 cycles after a_lat is
# latched (S_FETCH_B -> S_COMPUTE -> S_ARITHWAIT(12) -> S_POST -> S_RETIRE).  FPU-private
# (only FPU stores write it, all FSM-serialized >=18 cyc apart), so -to-only is safe.
set fpu_dst [get_registers {*u_execute_fpu|z_lat* *u_execute_fpu|flags_lat* *u_fpu_csr|* *u_fpu_regfile|* \
                            *u_div|a_reg* *u_div|b_reg* \
                            *u_div|a_sign_reg* *u_div|a_exp_reg* *u_div|a_sig_reg* \
                            *u_div|b_sign_reg* *u_div|b_exp_reg* *u_div|b_sig_reg* \
                            *u_floatx80_remainder|a_reg* *u_floatx80_remainder|b_reg* *u_floatx80_remainder|rnd_reg* \
                            *u_floatx80_sqrt|a_reg* \
                            *u_int64_to_bcd|val_reg* \
                            *u_bcd_to_int64|bcd_reg* \
                            *write_inst|wr_fpu_store_data*}]
set_multicycle_path -to $fpu_dst -setup 12
set_multicycle_path -to $fpu_dst -hold  11

# FCOMI / FUCOMI integer-EFLAGS writeback.  These ops drive cflag/pflag/zflag in
# the integer write_register_inst directly from execute_fpu's compare result
# (fpu_eflags_value_direct[2:0], strobed by fpu_eflags_we_direct at S_RETIRE).
# That compare is the SAME deep floatx80 classify/align cone as the arith ops, so
# it likewise needs 12 cycles.  cflag/pflag/zflag are SHARED with the integer ALU
# (which MUST stay single-cycle), so unlike the z_lat/fpu_csr group this MUST be
# SOURCE-anchored: relax only paths whose launch is inside the FPU sub-hierarchy
# {execute_fpu, fpu_regfile, fpu_csr}.  The integer-ALU->cflag launch is outside
# those modules and stays at 1 cycle.  The FPU result is held stable from S_IDLE/
# S_COMPUTE until the S_RETIRE strobe (>=13 cycles), so 12 setup / 11 hold is safe.
set fpu_src    [get_registers {*u_execute_fpu|* *u_fpu_regfile|* *u_fpu_csr|*}]
# The deep FPU compare result is first captured in the write stage's FPU-only
# holding register wr_fpu_eflags_value[*] (in pipeline write_inst), strobed at
# S_RETIRE; cflag/pflag/zflag are then loaded from it one fast reg->reg hop later.
# Anchor the multicycle on BOTH (wr_fpu_eflags_value is the binding deep path; the
# cflag/pflag/zflag entries are belt-and-suspenders).  Source-restricted to the FPU
# sub-hierarchy so the integer-ALU->cflag launch stays single-cycle.
set fpu_eflags [get_registers {*write_inst|wr_fpu_eflags_value* *write_register_inst|cflag *write_register_inst|pflag *write_register_inst|zflag}]
set_multicycle_path -from $fpu_src -to $fpu_eflags -setup 12
set_multicycle_path -from $fpu_src -to $fpu_eflags -hold  11

# b_lat deep-converter arms (PR-2c.14 iter 165c).  For mem-form loads/arith and FBLD,
# b_lat captures the ~45 ns converter output (mem_data_lat/mem80_hi_lat -> mem_z /
# fbld_x80 / m80 concat).  PR-2c.14 defers that capture to the S_ARITHWAIT terminal
# cycle so the cone settles ARITH_WAIT_CYCLES; relax those paths to match.  SOURCE-
# anchored on the mem latches ONLY: the reg-form arm (rf_rd_data, launched from
# fpu_regfile) is still captured at S_COMPUTE and READ during S_ARITHWAIT, so it MUST
# stay single-cycle — excluding fpu_regfile from -from leaves it untouched.
set fpu_bsrc [get_registers {*u_execute_fpu|mem_data_lat* *u_execute_fpu|mem80_hi_lat*}]
set fpu_blat [get_registers {*u_execute_fpu|b_lat*}]
set_multicycle_path -from $fpu_bsrc -to $fpu_blat -setup 12
set_multicycle_path -from $fpu_bsrc -to $fpu_blat -hold  11

# Divider operand-normalize cone (PR-2c.17 iter 165g).  softfloat_div_x80 fed the
# seq_divider its divisor as div_den = b_sig = floatx80_normalize(b_reg) -- a CLZ +
# 64-bit barrel-shift cone (~17 ns) that the restoring divider's per-cycle subtract
# re-traversed EVERY one of the 64 divide cycles (STA: u_div|...|seq_divider|rem_q[*]
# = -11 ns, the binding setup path, launched from b_reg[12]).  The divisor and the
# pass-1 numerator are CONSTANT for the whole divide, so softfloat_div_x80 now freezes
# a_reg/b_reg, dwells in D_SETTLE while the normalize cones settle, and registers the
# normalized divisor (b_sig -> u_div|den_reg) and pass-1 numerator (num128_first ->
# u_div|num_reg) ONCE.  The divider then reads stable registers, leaving only its
# 65-bit subtract per cycle.  Relax the one-shot capture path a_reg/b_reg -> num_reg/
# den_reg: a_reg/b_reg are frozen at D_IDLE.start and the capture fires 4 cycles later
# at D_SETTLE cnt==0, so they are stable for the whole window -- -setup 3 (hold 2) has
# a full cycle of margin.  FPU-private (u_div is reached only by FPU divide ops, which
# are FSM-serialized >=18 cycles apart).  PRESERVE_REGISTER ON num_reg/den_reg (qsf)
# stops the fitter retiming them back into the normalize cone and re-splitting the path.
set fpu_divsrc [get_registers {*u_div|a_reg* *u_div|b_reg*}]
set fpu_divdst [get_registers {*u_div|num_reg* *u_div|den_reg*}]
set_multicycle_path -from $fpu_divsrc -to $fpu_divdst -setup 3
set_multicycle_path -from $fpu_divsrc -to $fpu_divdst -hold  2
