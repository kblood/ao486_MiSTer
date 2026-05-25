// execute_fpu.v
//
// PR-2b.3e.  Multi-cycle FPU arithmetic FSM.  Sister module to
// execute_multiply.v / execute_divide.v — owns the per-op busy signal,
// drives fpu_regfile read/write, OR's exception-flag deltas into the
// (now externally-instantiated) fpu_csr via the `exc_flags_set` OR-lane,
// and raises #MF on unmasked FPU exceptions.
//
// History:
//   PR-2b.0 — FSM skeleton (5 states, op_active hard-wired 0).
//   PR-2b.1 — lifted fpu_regfile up to execute.v so this module owns
//             the shared read+write port.
//   PR-2b.2a — softfloat_add_x80 primitive (pure comb, same-sign
//             normal-normal, RTNE).  Validated 3300 Bochs vectors.
//   PR-2b.2b — glued FSM ↔ regfile ↔ primitive; full elab clean.
//   PR-2b.2c — primitive now emits flags[5:0]; FSM latches them at
//             S_COMPUTE, computed SW deltas + #MF in S_RETIRE; outputs
//             validated by standalone unit TB (1000/1000) but landed
//             on floating receivers in execute.v.
//   PR-2b.2d — fpu_csr lifted up to execute.v.  This module now exposes
//             `exc_flags_set [5:0]` (drives the external CSR's OR-lane
//             during S_RETIRE) and drops the 16-bit `sw_out`/`sw_we`
//             ports — the CSR composes its own SW from exc_flags + cw +
//             cc + top + sf.  `exe_trigger_mf_fault` stays here because
//             the pipeline needs the #MF decision in the same cycle
//             (before the CSR has registered the new exc_flags), so we
//             compute es locally from `flags_lat & ~cw[5:0]`.
//   PR-2b.3a — second arith op: CMDEX_FSUB_ST0_STi (D8 E0+i).  Added a
//             companion softfloat_sub_x80 primitive and a 1-bit kind_lat
//             that picked add or sub based on (a.sign ^ b.sign) ^ kind_lat.
//   PR-2b.3b — third arith op: CMDEX_FMUL_ST0_STi (D8 C8+i).
//             Adds softfloat_mul_x80 primitive in parallel; kind_lat
//             widens to 2 bits encoding {ADD=0, SUB=1, MUL=2}.  Primitive
//             selection: if kind_lat==MUL pick mul outputs; else fall
//             through to the existing add/sub dispatch.  No FSM / SW /
//             CSR changes — `flags_pre` is just the mux of three sources.
//   PR-2b.3c — fourth arith op: CMDEX_FDIV_ST0_STi (D8 F0+i).
//             Adds softfloat_div_x80 primitive in parallel; kind_lat
//             encodes {ADD=0, SUB=1, MUL=2, DIV=3} (existing 2-bit
//             field fills naturally).  Introduced the
//             **unmasked-exception writeback-gate**: rf_wr_en is gated
//             off whenever any bit in flags_lat is unmasked by cw[5:0].
//   PR-2b.3d — reverse variants: CMDEX_FSUBR_ST0_STi
//             (D8 E8+i, /5) and CMDEX_FDIVR_ST0_STi (D8 F8+i, /7).
//             No new primitive, no new kind in kind_lat — instead a
//             1-bit `reverse_lat` reg is captured at op-start and swaps
//             arith_a / arith_b BEFORE they feed all four primitives.
//             FSUB and FDIV semantics are non-commutative, so the swap
//             flips them into "ST(0) <- ST(i) - ST(0)" and
//             "ST(0) <- ST(i) / ST(0)" respectively.  FADD and FMUL
//             are commutative so the swap is a no-op for them — but we
//             apply it uniformly so the dispatch / use_sub_primitive
//             / z_sign_in logic stays single-track (it just sees
//             "effective op_a" and "effective op_b").
//   PR-2b.3m (this commit) — FST ST(i) at D9 D0+i / FSTP ST(i) at
//             DD D8+i.  Pure-control "store" and "store-then-pop" ops,
//             completing the swap/push/store control-op trio that began
//             with FXCH (iter 42) and FLD (iter 43).  FST writes ST(0)
//             data+tag into ST(i); TOP unchanged.  FSTP composes FST
//             with the iter-34 pop_after_lat path (S_POP cleanup:
//             Empty tag at abs_st0, TOP++).  Reuses dst_is_sti_lat for
//             the abs_stsrc destination and pop_after_lat for FSTP; the
//             ONLY new control flag is `is_fst_lat` (covers both FST
//             and FSTP) which overrides rf_wr_data → a_lat (ST(0)) and
//             rf_wr_tag → st0_tag_lat (ST(0)'s tag).  flags_lat is
//             forced 6'b0 in S_COMPUTE (merge predicate extends to
//             is_fxch_lat | is_fld_lat | is_fst_lat) so the
//             writeback-gate / #MF / CSR OR-lane all stay quiet.  No
//             new FSM state; no new primitive.
//   PR-2b.3l — FLD ST(i) at D9 C0+i.  Pure-control "push"
//             op: TOP-- and new ST(0) := old ST(i) (data+tag).  Single-
//             cycle write at S_RETIRE: rf_wr_idx = (top_lat - 1) & 7
//             (the new ST(0) slot), rf_wr_data = b_lat (old ST(i)),
//             rf_wr_tag = stsrc_tag_lat (old ST(i) tag).  Same cycle
//             pulses top_we with top_din = top_lat - 1 (mod-8 wrap).
//             Reuses iter-42's fetch path + tag latches; the arith
//             primitives still run combinationally but their outputs
//             are ignored; flags_lat is forced 6'b0 in S_COMPUTE when
//             is_fld_lat (merge predicate with is_fxch_lat) so the
//             writeback-gate / #MF / CSR OR-lane stay quiet.  No S_FXCH2
//             companion (FLD is single-write).  #IS on Empty ST(i)
//             advisory only (stsrc_empty_lat captured, not faulted).
//   PR-2b.3k — FXCH ST(i) at D9 C8+i.  Pure-control op
//             (no math), swaps ST(0) ↔ ST(i) in two regfile writes
//             over consecutive cycles.  Reuses the existing fetch path
//             (S_FETCH_A → S_FETCH_B → S_COMPUTE) to read both slots
//             plus capture their tags; primitive outputs are computed
//             but ignored (flags_lat forced 6'b0 in S_COMPUTE when
//             is_fxch_lat).  S_RETIRE writes ST(0) := old ST(i), then
//             a new S_FXCH2 state writes ST(i) := old ST(0).  TOP
//             unchanged.  fpu_done pulses at S_FXCH2.  No #MF (flags
//             are zero so es_now = 0).
//   PR-2b.3e — pop variants: DE C0+i FADDP, DE C8+i FMULP,
//             DE E0+i FSUBRP, DE E8+i FSUBP, DE F0+i FDIVRP, DE F8+i
//             FDIVP.  Bochs' fetchdecode_x87.h annotates this group
//             "all instructions pop FPU stack" — so all six write the
//             result to ST(i) AND then bump TOP after marking the old
//             ST(0)'s tag Empty.  No new primitives — kind_lat and
//             reverse_lat are extended to cover the six DE encodings.
//             Two new control regs: `dst_is_sti_lat` redirects the
//             S_RETIRE writeback to abs_stsrc instead of abs_st0;
//             `pop_after_lat` arms a new S_POP state that fires AFTER
//             S_RETIRE, writes Empty into abs_st0's tag, and pulses
//             top_we with top_din=top_lat+1.  fpu_done shifts to the
//             terminal state (S_POP for pop ops, S_RETIRE otherwise).
//             The pop is gated by ~es_now: if an unmasked exception
//             fires at retire, BOTH the result write AND the pop are
//             suppressed (Intel SDM §8.1.5: "no result is written...
//             before [the handler] is invoked").
//
// Scope of this iter:
//   - Twelve CMDEX values dispatched: D8-family FADD/FSUB/FMUL/FDIV/
//     FSUBR/FDIVR_ST0_STi (no pop) + DE-family FADDP/FMULP/FSUBP/
//     FSUBRP/FDIVP/FDIVRP_STi_ST0 (pop).  All reg-form, normal-normal
//     (FDIV/FDIVR/FDIVP/FDIVRP also handle b=0 → ±Inf+ZE and 0/0 → IE).
//     RTNE only.  Stack-fault check still advisory.  No mem-form.

`timescale 1ns / 1ps
`include "defines.v"

module execute_fpu (
    input               clk,
    input               rst_n,

    input               exe_reset,
    input               exe_ready,           // pipeline retire pulse — frees the FSM

    // Command stream from execute_commands.v
    input       [6:0]   exe_cmd,             // CMD_fpu_arith / CMD_fpu_compare / ...
    input       [3:0]   exe_cmdex,           // CMDEX_FADD_ST0_STi / ...
    input       [2:0]   exe_modregrm_reg_3b, // modrm.reg field (operation selector
                                             // for FPU mem-form; unused for D8 C0+i)
    input       [2:0]   exe_modregrm_rm_3b,  // modrm.rm field — source ST(i) index
                                             // for register-form arith (D8/DC C0..C7)
    input               exe_is_mem_form,     // 1 = mem-source op, 0 = reg-reg
    input               exe_pop_after,       // FPU_pop() after writeback

    // Memory-form operand (driven by the existing load path)
    input       [63:0]  exe_mem_data,
    input       [1:0]   exe_mem_fmt,         // 00=m32, 01=m64, 10=m80 (PR-2b.4+)
    input               exe_mem_data_valid,

    // CSR snapshot
    input       [15:0]  cw,
    input       [15:0]  sw_in,               // sw_in[13:11] is TOP

    // PR-2b.3t (iter 51): integer-side EFLAGS bits read by FCMOVcc.  Only
    // CF, ZF, PF are consumed (FCMOV condition codes are the same subset
    // that the integer CMOVcc family used historically, minus the SF/OF
    // pair — Intel reserved the SF/OF-based mnemonics for the integer
    // side only).  Wired from execute.v's already-in-scope EFLAGS bundle
    // (cflag/zflag/pflag at execute.v:86,88,89).
    input               cflag,
    input               zflag,
    input               pflag,

    //--------------------------------------------------------------------
    // Outputs to execute.v
    //--------------------------------------------------------------------
    output              fpu_busy,
    output              fpu_done,            // 1-cycle pulse on RETIRE

    // Exception-flag OR-lane into the externally-instantiated fpu_csr.
    // Lit only during S_RETIRE; CSR OR's into its own exc_flags register
    // on the same edge.  Bit order matches CW.x M masks at cw[5:0]:
    //   [0]=IE [1]=DE [2]=ZE [3]=OE [4]=UE [5]=PE
    output      [5:0]   exc_flags_set,

    // Regfile write port
    output      [2:0]   rf_wr_idx,
    output      [79:0]  rf_wr_data,
    output      [1:0]   rf_wr_tag,
    output              rf_wr_en,

    // TOP-pointer mutation (FPU_push / FPU_pop)
    output      [2:0]   top_din,
    output              top_we,

    // PR-2b.3n: cc-lane output to the external fpu_csr.  Pulsed for one
    // cycle in S_RETIRE when is_fxam_lat is set.  4-bit payload is
    // {C3, C2, C1, C0} per Intel SDM Vol 1 §8.3.5 FXAM table.
    output      [3:0]   cc_din,
    output              cc_we,

    // PR-2b.3u (iter 52): integer EFLAGS write-back lane for FCOMI /
    // FUCOMI / FCOMIP / FUCOMIP.  Symmetric counterpart to iter-51's
    // EFLAGS-read ports (cflag/zflag/pflag — those CONSUME integer
    // EFLAGS for FCMOVcc; these PRODUCE EFLAGS bits).  Pulsed for one
    // cycle in S_RETIRE when is_cmpi_lat is set AND no unmasked
    // exception trapped (~es_now — matches iter-31 writeback-gate
    // policy per SDM §8.1.5: a trapping FCOMI leaves EFLAGS
    // unchanged).  eflags_value packs {ZF, PF, CF} derived from the
    // shared cmp_cc classifier output: ZF=cmp_cc[3], PF=cmp_cc[2],
    // CF=cmp_cc[0] (see header comment + the assign block below the
    // cmp classifier).
    //
    // This iter only emits the lane on execute_fpu's port list;
    // integration with the integer write stage (pipeline/write.v →
    // pipeline/write_commands.v → write_register.v's cflag/pflag/zflag
    // latches) is deferred to the iter that wires FCOMI into a
    // CPU-level smoke (likely paired with PR-2b.4 mem-form arith).
    // The unit TB execute_fpu_tb.v validates these outputs directly
    // off u_efpu.
    output      [2:0]   eflags_value,    // {ZF, PF, CF}
    output              eflags_we,

    // Exception lane (vector 16, #MF) — fires when retire sees any
    // unmasked SW.IE/DE/ZE/OE/UE/PE.  Computed locally as
    // |(flags_lat & ~cw[5:0]) because the pipeline needs the decision
    // in the same cycle (the external CSR has not yet registered the
    // new exc_flags on this edge).
    output              exe_trigger_mf_fault,

    //--------------------------------------------------------------------
    // Regfile read port (combinational request + 1-cycle synchronous
    // data; matches fpu_regfile.v's 1R1W interface).
    //--------------------------------------------------------------------
    output      [2:0]   rf_rd_idx,
    input       [79:0]  rf_rd_data,
    input       [1:0]   rf_rd_tag
);

    //--------------------------------------------------------------------
    // CMD recognition.  PR-2b.3a/b/c admit four CMDEXes; `kind_now` is the
    // 2-bit encoding {ADD=0, SUB=1, MUL=2, DIV=3} captured into `kind_lat`
    // at op-start so the FSM doesn't depend on later cmdex changes.
    //--------------------------------------------------------------------
    localparam [1:0] KIND_ADD = 2'd0;
    localparam [1:0] KIND_SUB = 2'd1;
    localparam [1:0] KIND_MUL = 2'd2;
    localparam [1:0] KIND_DIV = 2'd3;

    wire is_fadd_st0_sti  = (exe_cmd  == `CMD_fpu_arith) &&
                            (exe_cmdex == `CMDEX_FADD_ST0_STi);
    wire is_fsub_st0_sti  = (exe_cmd  == `CMD_fpu_arith) &&
                            (exe_cmdex == `CMDEX_FSUB_ST0_STi);
    wire is_fmul_st0_sti  = (exe_cmd  == `CMD_fpu_arith) &&
                            (exe_cmdex == `CMDEX_FMUL_ST0_STi);
    wire is_fdiv_st0_sti  = (exe_cmd  == `CMD_fpu_arith) &&
                            (exe_cmdex == `CMDEX_FDIV_ST0_STi);
    wire is_fsubr_st0_sti = (exe_cmd  == `CMD_fpu_arith) &&
                            (exe_cmdex == `CMDEX_FSUBR_ST0_STi);
    wire is_fdivr_st0_sti = (exe_cmd  == `CMD_fpu_arith) &&
                            (exe_cmdex == `CMDEX_FDIVR_ST0_STi);
    // PR-2b.3e: DE-family pop variants.  Same dispatcher; new dst/pop
    // control lats below select ST(i) destination and S_POP cleanup.
    wire is_faddp_sti_st0  = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FADDP_STi_ST0);
    wire is_fmulp_sti_st0  = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FMULP_STi_ST0);
    wire is_fsubp_sti_st0  = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FSUBP_STi_ST0);
    wire is_fsubrp_sti_st0 = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FSUBRP_STi_ST0);
    wire is_fdivp_sti_st0  = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FDIVP_STi_ST0);
    wire is_fdivrp_sti_st0 = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FDIVRP_STi_ST0);
    // PR-2b.3k: FXCH ST(i) — pure-control op, no math.  Travels along
    // the same CMD_fpu_arith path; cmdex distinguishes.  The is_fxch_lat
    // reg captured below switches the FSM into a 2-write swap sequence
    // at S_RETIRE and S_FXCH2 instead of the normal data-write retire.
    wire is_fxch_sti       = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FXCH_STi);
    // PR-2b.3l: FLD ST(i) — pure-control "push" op.  Same CMD_fpu_arith
    // path; the is_fld_lat reg captured below routes S_RETIRE to write
    // the new ST(0) slot (= (top_lat - 1) & 7) with the old ST(i)'s
    // data + tag, AND drive top_we = 1 with top_din = top_lat - 1 in
    // the same cycle.  Single-cycle write (no S_FXCH2 / S_POP).
    wire is_fld_sti        = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FLD_STi);
    // PR-2b.3m: FST ST(i) — pure-control "store" op.  Same CMD_fpu_arith
    // path; the new is_fst_lat reg (covering both FST and FSTP) routes
    // S_RETIRE to write abs_stsrc with a_lat (= ST(0) data) and tag =
    // st0_tag_lat (= ST(0)'s tag).  Destination muxing reuses the
    // existing dst_is_sti_lat lane (set true at op-start); pop afterward
    // is gated by pop_after_lat (which the FSTP variant sets).
    wire is_fst_sti        = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FST_STi);
    wire is_fstp_sti       = (exe_cmd  == `CMD_fpu_arith) &&
                             (exe_cmdex == `CMDEX_FSTP_STi);
    wire is_fst_family     = is_fst_sti | is_fstp_sti;
    // PR-2b.3n: unary control ops on ST(0).  Dispatched via the new
    // `CMD_fpu_unary` (7'd119) so they get a fresh 4-bit CMDEX namespace
    // — the CMD_fpu_arith namespace is already FULL (see defines.v).
    // No source ST(i); the FSM still walks IDLE→FETCH_A→FETCH_B→COMPUTE→
    // POST→RETIRE (the FETCH_B read of ST(rm) happens but is ignored),
    // and S_RETIRE either writes the modified ST(0) (FCHS/FABS) or pulses
    // cc_we to the external CSR (FXAM).  No exception flags fire.
    wire is_fchs           = (exe_cmd  == `CMD_fpu_unary) &&
                             (exe_cmdex == `CMDEX_FCHS);
    wire is_fabs           = (exe_cmd  == `CMD_fpu_unary) &&
                             (exe_cmdex == `CMDEX_FABS);
    wire is_fxam           = (exe_cmd  == `CMD_fpu_unary) &&
                             (exe_cmdex == `CMDEX_FXAM);
    wire is_unary_now      = is_fchs | is_fabs | is_fxam;

    // PR-2b.3o (iter 46): comparison ops on ST(0) vs ST(i).  Dispatched via
    // the new `CMD_fpu_cmp` (7'd120).  Both operands are read via the
    // existing fetch path; no regfile data writeback (rf_wr_en gated off);
    // cc_we pulses in S_RETIRE with {C3,C2,C1=0,C0} per Intel SDM Vol 1
    // §8.3.6.  FCOM/FCOMP raise IE on ANY NaN; FUCOM/FUCOMP raise IE only
    // on SNaN.  FCOMP/FUCOMP pop via the existing pop_after_lat=1 path.
    wire is_fcom           = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FCOM);
    wire is_fcomp          = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FCOMP);
    wire is_fucom          = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FUCOM);
    wire is_fucomp         = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FUCOMP);
    // PR-2b.3p (iter 47): FTST = D9 E4.  Compare ST(0) to +0.0 — single
    // operand, but flows through the iter-46 cmp classifier with cmp_b_v
    // hard-coded to 80'h0 (driven by `is_ftst_lat` below).  Lives in the
    // CMD_fpu_unary namespace (same as FCHS/FABS/FXAM) but joins is_cmp_now
    // so the cmp lane (cc_we + flags_lat IE override + no regfile write)
    // engages.  Raises IE on any NaN — FCOM-class semantics, not FUCOM.
    wire is_ftst           = (exe_cmd  == `CMD_fpu_unary) &&
                             (exe_cmdex == `CMDEX_FTST);
    // PR-2b.3q (iter 48): FCOMPP / FUCOMPP — same cmp datapath as FCOM/FUCOM
    // but POP BOTH ST(0) and ST(1) after the compare.  Drives the new
    // pop_twice_lat reg and the S_POP→S_POP2 transition.  FCOMPP follows
    // FCOM-class IE policy (any NaN raises); FUCOMPP follows FUCOM (QNaN
    // silent — joins is_cmp_unord_now).  Both join is_cmp_pop_now so the
    // existing pop_after_lat=1 mechanism fires the first pop.
    wire is_fcompp         = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FCOMPP);
    wire is_fucompp        = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FUCOMPP);
    // PR-2b.3u (iter 52): FCOMI / FUCOMI / FCOMIP / FUCOMIP — same cmp
    // datapath as iter-46 FCOM/FUCOM but write integer EFLAGS at retire
    // instead of CSR cc.  Differentiation: is_cmpi_now → is_cmpi_lat
    // routes the cmp_cc payload onto eflags_value/eflags_we instead of
    // cc_din/cc_we.  IE policy still flows through cmp_ie_now (FCOMI
    // ⇒ any-NaN, FUCOMI ⇒ SNaN-only via is_fucom_lat).
    wire is_fcomi          = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FCOMI);
    wire is_fucomi         = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FUCOMI);
    wire is_fcomip         = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FCOMIP);
    wire is_fucomip        = (exe_cmd  == `CMD_fpu_cmp) &&
                             (exe_cmdex == `CMDEX_FUCOMIP);
    wire is_cmpi_now       = is_fcomi | is_fucomi | is_fcomip | is_fucomip;
    wire is_cmp_now        = is_fcom | is_fcomp | is_fucom | is_fucomp | is_ftst |
                             is_fcompp | is_fucompp |
                             is_cmpi_now;
    wire is_cmp_unord_now  = is_fucom | is_fucomp | is_fucompp |
                             is_fucomi | is_fucomip;                // "unordered" = silent QNaN
    wire is_cmp_pop_now    = is_fcomp | is_fucomp | is_fcompp | is_fucompp |
                             is_fcomip | is_fucomip;
    // PR-2b.3q: pop-twice predicate.  Captured into pop_twice_lat at op
    // start; consumed by the S_POP→S_POP2 transition rule.  Mutually
    // exclusive with all non-FCOMPP/FUCOMPP ops (only these two set it).
    wire pop_twice_now     = is_fcompp | is_fucompp;

    // PR-2b.3r (iter 49): FFREE ST(i) = DD C0+i.  Tag-only write of Empty
    // to ST(i); data preserved (rf_wr_data routed to b_lat = ST(i)'s
    // captured data so the regfile write is data-preserving).  No TOP
    // change, no flags, no #MF.  Dispatched via CMD_fpu_stack_ctrl
    // (7'd121) — its own namespace, distinct from CMD_fpu_unary which
    // targets ST(0).
    wire is_ffree         = (exe_cmd  == `CMD_fpu_stack_ctrl) &&
                            (exe_cmdex == `CMDEX_FFREE);
    // PR-2b.3s (iter 50): three more CMD_fpu_stack_ctrl ops.
    //   FNOP    (D9 D0) — pure no-op (walks FSM, no side effects at retire).
    //   FDECSTP (D9 F6) — TOP -= 1 at retire; no regfile / tag / flags.
    //   FINCSTP (D9 F7) — TOP += 1 at retire; no regfile / tag / flags.
    wire is_fnop          = (exe_cmd  == `CMD_fpu_stack_ctrl) &&
                            (exe_cmdex == `CMDEX_FNOP);
    wire is_fdecstp       = (exe_cmd  == `CMD_fpu_stack_ctrl) &&
                            (exe_cmdex == `CMDEX_FDECSTP);
    wire is_fincstp       = (exe_cmd  == `CMD_fpu_stack_ctrl) &&
                            (exe_cmdex == `CMDEX_FINCSTP);

    // PR-2b.3t (iter 51): FCMOVcc family — eight ST(0)<=ST(i) conditional
    // moves driven by the integer-side EFLAGS lane (CF/ZF/PF).  See
    // header for the full opcode/condition table.  Dispatch is a flat
    // 8-way match on (CMD_fpu_cmov, CMDEX_FCMOV*).  All eight share the
    // same datapath: read ST(i) via the existing FETCH path, evaluate
    // the cond at op-start, and at S_RETIRE either commit a data+tag
    // copy from b_lat → ST(0) (when cond is true) or hold rf_wr_en low
    // (when cond is false).  No TOP / pop / flags / cc effects.
    wire is_fcmovb        = (exe_cmd  == `CMD_fpu_cmov) &&
                            (exe_cmdex == `CMDEX_FCMOVB);
    wire is_fcmove        = (exe_cmd  == `CMD_fpu_cmov) &&
                            (exe_cmdex == `CMDEX_FCMOVE);
    wire is_fcmovbe       = (exe_cmd  == `CMD_fpu_cmov) &&
                            (exe_cmdex == `CMDEX_FCMOVBE);
    wire is_fcmovu        = (exe_cmd  == `CMD_fpu_cmov) &&
                            (exe_cmdex == `CMDEX_FCMOVU);
    wire is_fcmovnb       = (exe_cmd  == `CMD_fpu_cmov) &&
                            (exe_cmdex == `CMDEX_FCMOVNB);
    wire is_fcmovne       = (exe_cmd  == `CMD_fpu_cmov) &&
                            (exe_cmdex == `CMDEX_FCMOVNE);
    wire is_fcmovnbe      = (exe_cmd  == `CMD_fpu_cmov) &&
                            (exe_cmdex == `CMDEX_FCMOVNBE);
    wire is_fcmovnu       = (exe_cmd  == `CMD_fpu_cmov) &&
                            (exe_cmdex == `CMDEX_FCMOVNU);
    wire is_fcmov_now     = is_fcmovb | is_fcmove | is_fcmovbe | is_fcmovu |
                            is_fcmovnb | is_fcmovne | is_fcmovnbe | is_fcmovnu;

    // PR-2b.4d (iter 55): mem-form FADD — first real consumer of the
    // iter-53 exe_mem_data lane + the iter-54 float32/float64 -> floatx80
    // converters.  Uses a NEW CMD code (CMD_fpu_arith_mem) so it gets a
    // fresh 4-bit CMDEX namespace (the existing CMD_fpu_arith one is
    // already full).  CMDEX width encodes the operand format:
    //   CMDEX_FADD_M32 (4'd0) — float32 source (D8 /0 mod!=11)
    //   CMDEX_FADD_M64 (4'd1) — float64 source (DC /0 mod!=11)
    // Destination is ST(0) for both, matching D8/DC mem-form SDM canonical.
    // No pop, no reverse — reuses the existing FADD primitive (add or sub
    // depending on operand signs) through the same use_sub_primitive mux
    // that reg-form FADD uses.  The only new logic is: (i) latch the
    // mem operand + format at op-start, (ii) drive the converters from
    // mem_data_lat, (iii) override the b operand in S_COMPUTE with the
    // converter output instead of rf_rd_data, (iv) OR the converter's
    // de/ie flags into flags_lat.
    wire is_fadd_m32      = (exe_cmd  == `CMD_fpu_arith_mem) &&
                            (exe_cmdex == `CMDEX_FADD_M32);
    wire is_fadd_m64      = (exe_cmd  == `CMD_fpu_arith_mem) &&
                            (exe_cmdex == `CMDEX_FADD_M64);
    // PR-2b.4e (iter 56): mem-form FSUB/FMUL/FDIV — non-reverse arms only.
    // Each pair shares the converter + flags-OR-lane wiring from iter 55;
    // the only new dispatch logic is the kind_now extension below (these
    // CMDEXes participate in is_arith_mem, which lights is_arith_d8, which
    // drives op_active + the existing primitive bank).
    wire is_fsub_m32      = (exe_cmd  == `CMD_fpu_arith_mem) &&
                            (exe_cmdex == `CMDEX_FSUB_M32);
    wire is_fsub_m64      = (exe_cmd  == `CMD_fpu_arith_mem) &&
                            (exe_cmdex == `CMDEX_FSUB_M64);
    wire is_fmul_m32      = (exe_cmd  == `CMD_fpu_arith_mem) &&
                            (exe_cmdex == `CMDEX_FMUL_M32);
    wire is_fmul_m64      = (exe_cmd  == `CMD_fpu_arith_mem) &&
                            (exe_cmdex == `CMDEX_FMUL_M64);
    wire is_fdiv_m32      = (exe_cmd  == `CMD_fpu_arith_mem) &&
                            (exe_cmdex == `CMDEX_FDIV_M32);
    wire is_fdiv_m64      = (exe_cmd  == `CMD_fpu_arith_mem) &&
                            (exe_cmdex == `CMDEX_FDIV_M64);
    wire is_arith_mem     = is_fadd_m32 | is_fadd_m64 |
                            is_fsub_m32 | is_fsub_m64 |
                            is_fmul_m32 | is_fmul_m64 |
                            is_fdiv_m32 | is_fdiv_m64;
    // mem_fmt: 00 = m32fp, 01 = m64fp.  All M64 CMDEXes are odd literals
    // (4'd1/3/5/7); equivalently exe_cmdex[0] selects m64 when is_arith_mem.
    wire [1:0] mem_fmt_now = is_fadd_m64 | is_fsub_m64 | is_fmul_m64 | is_fdiv_m64
                                ? 2'b01 : 2'b00;
    // Condition selection.  Each pair (B/NB, E/NE, BE/NBE, U/NU) shares
    // the same EFLAGS expression; the invert bit (set for the N-prefixed
    // mnemonics) flips the polarity.
    wire fcmov_cond_base =
        (is_fcmovb  | is_fcmovnb)  ? cflag           :
        (is_fcmove  | is_fcmovne)  ? zflag           :
        (is_fcmovbe | is_fcmovnbe) ? (cflag | zflag) :
                                     pflag;          // FCMOVU / FCMOVNU
    wire fcmov_invert_now = is_fcmovnb | is_fcmovne | is_fcmovnbe | is_fcmovnu;
    wire fcmov_taken_now  = fcmov_cond_base ^ fcmov_invert_now;

    // PR-2b.4d (iter 55): is_arith_mem joins is_arith_d8 so kind_now (default
    // KIND_ADD), reverse_now (default 0 — no reverse for FADD mem), and
    // op_active (via is_arith_st0_sti) all engage on mem-form FADD without
    // any further dispatch logic.  dst_is_sti_now stays 0 (D8/DC mem-form
    // dst is ST(0), not ST(i)).  pop_after_now stays 0 (no pop variant
    // wired yet for mem-form).
    wire is_arith_d8 = is_fadd_st0_sti  | is_fsub_st0_sti  |
                       is_fmul_st0_sti  | is_fdiv_st0_sti  |
                       is_fsubr_st0_sti | is_fdivr_st0_sti |
                       is_arith_mem;
    wire is_arith_de = is_faddp_sti_st0  | is_fmulp_sti_st0  |
                       is_fsubp_sti_st0  | is_fsubrp_sti_st0 |
                       is_fdivp_sti_st0  | is_fdivrp_sti_st0;
    wire is_arith_st0_sti = is_arith_d8 | is_arith_de;
    // Any op that uses the existing fetch / regfile-read path.  Same
    // op_active gate as is_arith_st0_sti — FXCH and FLD additionally
    // force their respective *_lat regs at op-start so the retire
    // path diverges from the normal arith data write.
    wire is_op_active     = is_arith_st0_sti | is_fxch_sti | is_fld_sti |
                            is_fst_family | is_unary_now | is_cmp_now |
                            is_ffree | is_fnop | is_fdecstp | is_fincstp |
                            is_fcmov_now;
    // Control-op predicate: ops whose result is a regfile-data move,
    // not a softfloat compute.  Used in S_COMPUTE to force flags_lat=0
    // (no exception flags) and in rf_wr_*/top_we/etc. to override the
    // arith retire path.  FXCH / FLD / FST / FSTP / FCHS / FABS / FXAM /
    // FCMOVcc share this predicate.
    wire is_control_op_now = is_fxch_sti | is_fld_sti | is_fst_family |
                             is_unary_now | is_ffree |
                             is_fnop | is_fdecstp | is_fincstp |
                             is_fcmov_now;

    // PR-2b.3d/3e: kind selector now spans both D8 and DE families.
    //   KIND_MUL  : FMUL / FMULP
    //   KIND_DIV  : FDIV / FDIVR / FDIVP / FDIVRP
    //   KIND_SUB  : FSUB / FSUBR / FSUBP / FSUBRP
    //   KIND_ADD  : FADD / FADDP (default fall-through)
    // The reverse bit (operand-swap before the primitive bank) handles
    // the non-commutative reverse forms.  Per Intel SDM Vol 2:
    //   FSUBR  ST(0),ST(i) : ST(0) <- ST(i)-ST(0)  (reverse=1)
    //   FSUBP  ST(i),ST(0) : ST(i) <- ST(i)-ST(0)  (reverse=1)
    //   FSUBRP ST(i),ST(0) : ST(i) <- ST(0)-ST(i)  (reverse=0)
    //   FDIVR  ST(0),ST(i) : ST(0) <- ST(i)/ST(0)  (reverse=1)
    //   FDIVP  ST(i),ST(0) : ST(i) <- ST(i)/ST(0)  (reverse=1)
    //   FDIVRP ST(i),ST(0) : ST(i) <- ST(0)/ST(i)  (reverse=0)
    // Note the asymmetry between FSUBR and FSUBP (likewise FDIVR/FDIVP):
    // they use OPPOSITE reverse settings, because FSUBR swaps the
    // *D8-family operand order* and FSUBP keeps the natural ST(i),ST(0)
    // pairing.  The D8 family computes "ST(0) op ST(i)" by default;
    // the DE family computes "ST(i) op ST(0)" by default.
    // PR-2b.4e (iter 56): mem-form FMUL/FDIV/FSUB join the kind_now mux so
    // S_COMPUTE selects the right primitive at the existing
    // mul_or_addsub_z / sum_pre cascade.  FADD mem-form falls through to
    // KIND_ADD (default) — matches iter-55 behaviour.  Non-reverse only;
    // FSUBR/FDIVR mem-form deferred to .4f because they need op_a/op_b
    // routing changes when is_mem_form_lat=1 + reverse_lat=1.
    wire [1:0] kind_now =
        (is_fmul_st0_sti  | is_fmulp_sti_st0  | is_fmul_m32 | is_fmul_m64)              ? KIND_MUL :
        (is_fdiv_st0_sti  | is_fdivr_st0_sti  | is_fdivp_sti_st0  | is_fdivrp_sti_st0 |
         is_fdiv_m32      | is_fdiv_m64)                                                ? KIND_DIV :
        (is_fsub_st0_sti  | is_fsubr_st0_sti  | is_fsubp_sti_st0  | is_fsubrp_sti_st0 |
         is_fsub_m32      | is_fsub_m64)                                                ? KIND_SUB :
                                                                                          KIND_ADD;
    wire reverse_now =
        // D8 family reverse forms (operand swap relative to ST(0) op ST(i)):
        is_fsubr_st0_sti | is_fdivr_st0_sti |
        // DE family forward forms (operand swap relative to ST(0) op ST(i)
        // since the default DE order is ST(i) op ST(0)):
        is_fsubp_sti_st0 | is_fdivp_sti_st0;

    // PR-2b.3e: DE-family writes the result to ST(i) and pops the stack.
    // PR-2b.3m: FST/FSTP also use the ST(i) destination lane; FSTP also
    // arms pop_after_lat so the existing S_POP cleanup runs after the
    // store.  FST keeps pop_after_lat=0 (no pop).
    // PR-2b.3r: FFREE writes to ST(i) too (tag-only Empty + b_lat data
    // preserve), so it joins dst_is_sti_now.
    wire dst_is_sti_now = is_arith_de | is_fst_family | is_ffree;
    // PR-2b.3o: FCOMP / FUCOMP arm a pop using the existing pop_after_lat
    // mechanism (one cycle in S_POP that bumps TOP and clears the old
    // ST(0) tag).  Unlike arith DE-pops, the cmp path also has cc_we
    // pulse in S_RETIRE — the two are independent.
    wire pop_after_now  = is_arith_de | is_fstp_sti | is_cmp_pop_now;

    wire op_active = exe_ready && is_op_active;

    //--------------------------------------------------------------------
    // FSM states.  Iter-23 design doc §3 used a 5-state encoding
    // (IDLE/FETCH/COMPUTE/POST/RETIRE); PR-2b.2b splits FETCH into A and
    // B so the synchronous regfile read fits without external counters.
    //--------------------------------------------------------------------
    // PR-2b.3q (iter 48): state widened from [2:0] to [3:0] to make room for
    // S_POP2 = 4'd8.  The original 3-bit encoding had all 8 slots (S_IDLE
    // through S_FXCH2) consumed; adding S_POP2 needs one more bit.  No code
    // outside this module reads `state` directly — the TB references it via
    // hierarchical paths and compares to specific values, which still work
    // under the wider encoding (Verilog promotes the narrower literal).
    localparam [3:0]
        S_IDLE    = 4'd0,
        S_FETCH_A = 4'd1,   // present rd_idx for ST(0); data lands next cycle
        S_FETCH_B = 4'd2,   // latch ST(0); present rd_idx for ST(src)
        S_COMPUTE = 4'd3,   // latch ST(src); softfloat_add_x80 is combinational
        S_POST    = 4'd4,   // exception classification placeholder (PR-2b.2c)
        S_RETIRE  = 4'd5,   // drive rf_wr_en + (for non-pop) fpu_done
        S_POP     = 4'd6,   // PR-2b.3e: clear old ST(0) tag, bump TOP, fpu_done
        S_FXCH2   = 4'd7,   // PR-2b.3k: second leg of FXCH swap — writes
                            // ST(i) := old ST(0) (data + tag).  fpu_done
                            // pulses here.  TOP unchanged.
        S_POP2    = 4'd8;   // PR-2b.3q: second leg of double-pop (FCOMPP /
                            // FUCOMPP).  Mirrors S_POP — clears the tag at
                            // ST(1) at op start (= (top_lat + 1) & 7) and
                            // bumps TOP to top_lat + 2.  fpu_done pulses
                            // here instead of S_POP for double-pop ops.

    reg [3:0]  state;

    // Latched operands + result.
    reg [79:0] a_lat;       // ST(0) at op start
    reg [79:0] b_lat;       // ST(src)
    reg [79:0] z_lat;       // softfloat_add_x80 output, registered at S_POST entry
    reg [5:0]  flags_lat;   // softfloat_add_x80 exception flags, same edge as z_lat

    // Latched control: TOP at op start (so a later push/pop can't move
    // the dst out from under us), the source stnr, the 2-bit arith
    // kind (0=ADD, 1=SUB, 2=MUL, 3=DIV) and the 1-bit reverse flag (PR-2b.3d:
    // FSUBR/FDIVR set this so the swap below picks ST(i) as the
    // minuend/dividend) so a later command pulse can't reshape the op
    // mid-flight.
    reg [2:0]  top_lat;
    reg [2:0]  src_lat;
    reg [1:0]  kind_lat;
    reg        reverse_lat;
    // PR-2b.3e: writeback destination (0=ST(0), 1=ST(src)) and pop-after
    // flag, both captured at S_IDLE→S_FETCH_A.  The pop is gated by
    // ~es_now at S_RETIRE so an unmasked exception leaves the stack
    // untouched (SDM §8.1.5 "no result is written... before [handler]").
    reg        dst_is_sti_lat;
    reg        pop_after_lat;
    // PR-2b.3q (iter 48): captures pop_twice_now at op start.  Steers the
    // S_POP → (S_POP2 or S_IDLE) transition and conceptually pairs with the
    // existing pop_after_lat: pop_after_lat gates the first pop (S_POP);
    // pop_twice_lat gates the second pop (S_POP2).  Both honour the
    // ~es_now writeback-gate at S_RETIRE — an unmasked exception suppresses
    // BOTH pops and the FSM jumps S_RETIRE → S_IDLE directly.
    reg        pop_twice_lat;
    // PR-2b.3k: FXCH latch — captured at S_IDLE→S_FETCH_A, routes the
    // S_RETIRE/S_FXCH2 path to do a two-write data+tag swap instead of
    // the normal arith data write.  Mutually exclusive with dst_is_sti_lat
    // and pop_after_lat (D9 C8+i is its own opcode family).
    reg        is_fxch_lat;
    // PR-2b.3l: FLD latch — captured at S_IDLE→S_FETCH_A.  Routes
    // S_RETIRE to write the new ST(0) slot ((top_lat - 1) & 7) with the
    // old ST(i)'s data + tag, AND pulse top_we / top_din = top_lat - 1
    // in the same cycle.  Single-cycle write.  Mutually exclusive with
    // is_fxch_lat, dst_is_sti_lat, pop_after_lat (D9 C0+i is its own
    // opcode family).
    reg        is_fld_lat;
    // PR-2b.3m: FST/FSTP latch — captured at S_IDLE→S_FETCH_A.  Covers
    // BOTH FST and FSTP; the FSTP-only pop side-effect is carried by
    // pop_after_lat (set alongside).  is_fst_lat overrides rf_wr_data
    // → a_lat (ST(0) data) and rf_wr_tag → st0_tag_lat (ST(0)'s tag).
    // Destination routing reuses dst_is_sti_lat (set at op-start).
    // Mutually exclusive with is_fxch_lat / is_fld_lat (own opcode
    // families); coexists with dst_is_sti_lat (FST/FSTP set it) and
    // (for FSTP) pop_after_lat.
    reg        is_fst_lat;
    // PR-2b.3n: unary control-op latches.  Captured at S_IDLE→S_FETCH_A.
    // FCHS/FABS override rf_wr_data with a bit-79-toggled / bit-79-cleared
    // copy of a_lat; FXAM suppresses rf_wr_en and pulses cc_we instead.
    // Mutually exclusive with all other *_lat regs (own opcode bytes
    // D9 E0 / D9 E1 / D9 E5).
    reg        is_fchs_lat;
    reg        is_fabs_lat;
    reg        is_fxam_lat;
    // PR-2b.3o: cmp-family latches.  is_cmp_lat covers all four ops and
    // is used to (a) gate rf_wr_en off (no data writeback), (b) drive
    // cc_we in S_RETIRE, (c) override flags_lat with the cmp-only IE
    // bit instead of flags_pre.  is_fucom_lat differentiates the IE
    // policy: FCOM/FCOMP set IE on any NaN; FUCOM/FUCOMP set IE only
    // on SNaN (QNaN is silent under unordered semantics).
    reg        is_cmp_lat;
    reg        is_fucom_lat;
    // PR-2b.3u (iter 52): is_cmpi_lat — captured at S_IDLE→S_FETCH_A.
    // Selects EFLAGS write-back (eflags_we/eflags_value) instead of
    // CSR cc write (cc_we/cc_din) at S_RETIRE.  The cmp classifier
    // datapath is shared; only the output routing differs.  Mutually
    // exclusive with FCOM/FUCOM/FCOMPP-family (those clear is_cmpi_lat
    // and continue to drive cc_we as before).
    reg        is_cmpi_lat;
    // PR-2b.3p: is_ftst_lat — captured at S_IDLE→S_FETCH_A.  Drives the
    // cmp_b_v override that injects 80'h0 (+0.0) in place of the
    // S_COMPUTE rf_rd_data / b_lat operand so the cmp classifier
    // compares ST(0) to +0.0.
    reg        is_ftst_lat;
    // PR-2b.3r (iter 49): is_ffree_lat — captured at S_IDLE→S_FETCH_A.
    // Routes S_RETIRE to write {data=b_lat (preserves ST(i)'s data),
    // tag=2'b11 (Empty)} at abs_stsrc.  Mutually exclusive with all other
    // *_lat regs.  No TOP change, no flags.
    reg        is_ffree_lat;
    // PR-2b.3s (iter 50): three CMD_fpu_stack_ctrl ops.  All three force
    // flags_lat=0 (no exceptions) and gate rf_wr_en off at S_RETIRE
    // (no regfile write).  FDECSTP / FINCSTP additionally pulse top_we
    // at S_RETIRE with top_din = top_lat ∓ 1.  FNOP has no S_RETIRE
    // side effects at all.  Mutually exclusive with each other and with
    // is_ffree_lat / is_unary_lat / etc.
    reg        is_fnop_lat;
    reg        is_fdecstp_lat;
    reg        is_fincstp_lat;
    // PR-2b.3t (iter 51): FCMOVcc latches.  Captured at S_IDLE→S_FETCH_A.
    // is_fcmov_lat covers all eight mnemonics and gates: (a) flags_lat
    // forced 6'd0 in S_COMPUTE (no exceptions), (b) rf_wr_en at S_RETIRE
    // (off when condition was not taken), (c) rf_wr_data / rf_wr_tag
    // selection (b_lat / stsrc_tag_lat = ST(i)).  fcmov_taken_lat
    // freezes the evaluated condition at op-start so a same-cycle EFLAGS
    // change from the integer side can't reshape the move mid-flight.
    reg        is_fcmov_lat;
    reg        fcmov_taken_lat;
    // PR-2b.4d (iter 55): mem-form latches.  is_mem_form_lat routes the
    // S_COMPUTE b-operand source through the iter-54 converters instead of
    // rf_rd_data, and OR's the converter's de/ie flags into flags_lat.
    // mem_fmt_lat picks float32 (00) vs float64 (01).  mem_data_lat
    // snapshots exe_mem_data at op-start so a same-pipeline e_load on a
    // later cycle can't reshape the operand mid-flight (defence in depth;
    // execute.v's exe_fpu_mem_data latch already holds it stable while
    // fpu_busy is high, but a local copy decouples the FSM from any
    // upstream-timing surprises).
    reg        is_mem_form_lat;
    reg [1:0]  mem_fmt_lat;
    reg [63:0] mem_data_lat;

    // Latched tag-Empty observations (advisory — see header).
    reg        st0_empty_lat;
    reg        stsrc_empty_lat;

    // PR-2b.3k: full 2-bit tag captures for ST(0) and ST(src).  Sampled
    // alongside the data latches in S_FETCH_B / S_COMPUTE; consumed by
    // the FXCH writes at S_RETIRE (ST(0) ← stsrc_tag_lat) and S_FXCH2
    // (ST(i) ← st0_tag_lat).  For arith ops these regs are written but
    // unused — rf_wr_tag stays the existing constant Valid/Empty mux.
    reg [1:0]  st0_tag_lat;
    reg [1:0]  stsrc_tag_lat;

    //--------------------------------------------------------------------
    // Absolute regfile indices.
    //
    // ST(stnr) lives at physical register (TOP + stnr) & 7.  We latch TOP
    // at op start so a concurrent CSR mutation can't shift the targets.
    //--------------------------------------------------------------------
    wire [2:0] abs_st0   = top_lat;
    wire [2:0] abs_stsrc = top_lat + src_lat;     // 3-bit add wraps mod 8
    // PR-2b.3l: new ST(0) slot after a push (FLD).  TOP decrements by 1
    // before the new ST(0) is written, so the destination slot is
    // (top_lat - 1) & 7.  The 3-bit subtraction wraps mod 8 in Verilog.
    wire [2:0] abs_new_top = top_lat - 3'd1;
    // PR-2b.3q (iter 48): ST(1) slot at op start = (top_lat + 1) & 7.
    // S_POP2 writes tag=Empty to this slot to complete the FCOMPP /
    // FUCOMPP double-pop.  (S_POP already cleared the tag at abs_st0,
    // and top_din advanced TOP from top_lat to top_lat+1 over that
    // cycle.  The CSR TOP is still top_lat+1 at the start of S_POP2 —
    // we don't depend on the live TOP because the FSM holds the index
    // off the frozen top_lat.)
    wire [2:0] abs_st1   = top_lat + 3'd1;

    // For the very first read in S_FETCH_A we don't have top_lat yet — use
    // the live CSR TOP. The latch happens at S_IDLE→S_FETCH_A transition.
    wire [2:0] abs_st0_live = sw_in[13:11];

    //--------------------------------------------------------------------
    // Arith primitives — forward-declared above the FSM so the S_COMPUTE
    // arm can reference sum_pre / flags_pre without ModelSim auto-creating
    // implicit nets that then collide with the explicit `wire`
    // declarations below.  (Same pattern used for fpu_busy in PR-2b.1;
    // see execute.v:305-311 and PR-2b.2b Gotcha #9 in HANDOFF.md.)
    //
    // PR-2b.3a/b/c: four primitives in parallel (combinational) — the mux
    // between them is decided by kind_lat at S_COMPUTE.
    //--------------------------------------------------------------------
    wire [79:0] sum_pre;       // final z presented to the FSM
    wire [5:0]  flags_pre;     // final flags presented to the FSM
    wire [79:0] add_z;
    wire [5:0]  add_flags;
    wire [79:0] sub_z;
    wire [5:0]  sub_flags;
    wire [79:0] mul_z;
    wire [5:0]  mul_flags;
    wire [79:0] div_z;
    wire [5:0]  div_flags;

    // PR-2b.3e: es_now / unmasked_flags forward-declared here because the
    // FSM's S_RETIRE→S_POP transition rule reads es_now (gating the pop
    // on ~es_now to honour SDM §8.1.5).  Without the forward declaration
    // ModelSim creates an implicit net at the always-block reference
    // site and then errors on the explicit wire decl in the outputs
    // block below.  Same pattern as fpu_busy in PR-2b.1 (Gotcha #9 in
    // HANDOFF.md, CLAUDE.md).
    wire [5:0] unmasked_flags;
    wire       es_now;

    // PR-2b.3o: forward-declare cmp_ie_now — the FSM's S_COMPUTE arm reads
    // it to assemble flags_lat for cmp ops, but the cmp classifier block
    // is further down the file.  Without this decl ModelSim auto-creates
    // an implicit net at the always-block reference (vlog-2730) and then
    // errors on the explicit `wire` decl below (vlog-2388).  Same pattern
    // as fpu_busy / sum_pre / fpu_exec_exc_flags_set forward-decls.
    wire       cmp_ie_now;

    // PR-2b.4d (iter 55): forward-declare mem-form converter outputs.
    // The S_COMPUTE arm above reads mem_z / mem_de_flag / mem_ie_flag to
    // override the b operand + OR converter flags into flags_lat; the
    // converter instances + the mux wires are declared lower in the
    // primitives section.  Without these forward decls ModelSim auto-
    // creates implicit nets at the always-block reference (vlog-2730)
    // and then errors on the explicit `wire` decl later (vlog-2388) —
    // same trap as cmp_ie_now / sum_pre / fpu_busy.
    wire [79:0] mem_z;
    wire        mem_de_flag;
    wire        mem_ie_flag;

    //--------------------------------------------------------------------
    // FSM transitions
    //--------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n || exe_reset) begin
            state           <= S_IDLE;
            a_lat           <= 80'd0;
            b_lat           <= 80'd0;
            z_lat           <= 80'd0;
            flags_lat       <= 6'd0;
            top_lat         <= 3'd0;
            src_lat         <= 3'd0;
            kind_lat        <= 2'b00;
            reverse_lat     <= 1'b0;
            dst_is_sti_lat  <= 1'b0;
            pop_after_lat   <= 1'b0;
            pop_twice_lat   <= 1'b0;
            is_fxch_lat     <= 1'b0;
            is_fld_lat      <= 1'b0;
            is_fst_lat      <= 1'b0;
            is_fchs_lat     <= 1'b0;
            is_fabs_lat     <= 1'b0;
            is_fxam_lat     <= 1'b0;
            is_cmp_lat      <= 1'b0;
            is_fucom_lat    <= 1'b0;
            is_cmpi_lat     <= 1'b0;
            is_ftst_lat     <= 1'b0;
            is_ffree_lat    <= 1'b0;
            is_fnop_lat     <= 1'b0;
            is_fdecstp_lat  <= 1'b0;
            is_fincstp_lat  <= 1'b0;
            is_fcmov_lat    <= 1'b0;
            fcmov_taken_lat <= 1'b0;
            is_mem_form_lat <= 1'b0;
            mem_fmt_lat     <= 2'b00;
            mem_data_lat    <= 64'd0;
            st0_empty_lat   <= 1'b0;
            stsrc_empty_lat <= 1'b0;
            st0_tag_lat     <= 2'b00;
            stsrc_tag_lat   <= 2'b00;
        end else begin
            case (state)
                S_IDLE: begin
                    if (op_active) begin
                        state          <= S_FETCH_A;
                        top_lat        <= sw_in[13:11];
                        src_lat        <= exe_modregrm_rm_3b;
                        kind_lat       <= kind_now;
                        reverse_lat    <= reverse_now;
                        dst_is_sti_lat <= dst_is_sti_now;
                        pop_after_lat  <= pop_after_now;
                        pop_twice_lat  <= pop_twice_now;
                        is_fxch_lat    <= is_fxch_sti;
                        is_fld_lat     <= is_fld_sti;
                        is_fst_lat     <= is_fst_family;
                        is_fchs_lat    <= is_fchs;
                        is_fabs_lat    <= is_fabs;
                        is_fxam_lat    <= is_fxam;
                        is_cmp_lat     <= is_cmp_now;
                        is_fucom_lat   <= is_cmp_unord_now;
                        is_cmpi_lat    <= is_cmpi_now;
                        is_ftst_lat    <= is_ftst;
                        is_ffree_lat   <= is_ffree;
                        is_fnop_lat    <= is_fnop;
                        is_fdecstp_lat <= is_fdecstp;
                        is_fincstp_lat <= is_fincstp;
                        is_fcmov_lat    <= is_fcmov_now;
                        fcmov_taken_lat <= fcmov_taken_now;
                        is_mem_form_lat <= is_arith_mem;
                        mem_fmt_lat     <= mem_fmt_now;
                        mem_data_lat    <= exe_mem_data;
                    end
                end

                // S_FETCH_A: rf_rd_idx is driving abs_st0_live combinationally
                // (see assign below).  Regfile clocks the read on this rising
                // edge; ST(0) data is available next cycle.
                S_FETCH_A: begin
                    state <= S_FETCH_B;
                end

                // S_FETCH_B: ST(0) result is on rf_rd_data — latch it.  Switch
                // rd_idx to abs_stsrc so ST(src) data is ready next cycle.
                S_FETCH_B: begin
                    a_lat         <= rf_rd_data;
                    st0_empty_lat <= (rf_rd_tag == 2'b11);
                    st0_tag_lat   <= rf_rd_tag;
                    state         <= S_COMPUTE;
                end

                // S_COMPUTE: ST(src) result is on rf_rd_data — latch it.
                // softfloat_add_x80 is purely combinational so its z /
                // flags outputs for (a_lat, rf_rd_data) are already valid;
                // register them.  For control ops (FXCH / FLD) the arith
                // outputs are computed but ignored; flags_lat is forced
                // 6'b0 so the writeback-gate / #MF / CSR OR-lane stay
                // quiet through retirement.
                S_COMPUTE: begin
                    // PR-2b.4d (iter 55): for mem-form the b operand is
                    // mem_z (converted) not rf_rd_data — rf_rd_data still
                    // reflects an unrelated ST(stnr) read since FETCH_B
                    // drove abs_stsrc regardless, but mem-form discards it.
                    b_lat           <= is_mem_form_lat ? mem_z : rf_rd_data;
                    stsrc_empty_lat <= (rf_rd_tag == 2'b11);
                    stsrc_tag_lat   <= rf_rd_tag;
                    z_lat           <= sum_pre;
                    // PR-2b.4d (iter 55): mem-form OR's the converter's
                    // de/ie flags into the arith primitive's flags_pre so
                    // SNaN-input loads raise IE and denormal-input loads
                    // raise DE.  Bit positions match cw[5:0] / sw[5:0]:
                    //   flags_lat[0] = IE
                    //   flags_lat[1] = DE
                    // Higher bits (ZE/OE/UE/PE) come solely from flags_pre.
                    flags_lat       <= (is_fxch_lat | is_fld_lat | is_fst_lat |
                                        is_fchs_lat | is_fabs_lat | is_fxam_lat |
                                        is_ffree_lat | is_fnop_lat |
                                        is_fdecstp_lat | is_fincstp_lat |
                                        is_fcmov_lat) ? 6'd0 :
                                       is_cmp_lat ? {5'd0, cmp_ie_now} :
                                       is_mem_form_lat ?
                                           (flags_pre | {4'd0, mem_de_flag, mem_ie_flag}) :
                                                    flags_pre;
                    state           <= S_POST;
                end

                // S_POST: PR-2b.2c places exception-flag computation here.
                // All the actual signal generation is combinational off
                // flags_lat (see "Outputs" block below), so this state is
                // a one-cycle bubble where downstream sees the SW delta
                // settle and S_RETIRE pulses the we's.
                S_POST: begin
                    state <= S_RETIRE;
                end

                // S_RETIRE: 1-cycle pulse of rf_wr_en.  fpu_done pulses here
                // only when no pop follows OR an unmasked exception suppressed
                // the writeback (in which case the pop is also suppressed).
                // PR-2b.3e: if a pop is armed and we DIDN'T trap, transition
                // into S_POP for the tag-clear / TOP++ second-cycle write.
                S_RETIRE: begin
                    if (is_fxch_lat)
                        state <= S_FXCH2;
                    else if (pop_after_lat && ~es_now)
                        state <= S_POP;
                    else
                        state <= S_IDLE;
                end

                // S_POP (PR-2b.3e): tag-only writeback for the old ST(0)
                // (marks the post-pop position Empty) and a top_we pulse
                // that bumps TOP to (top_lat + 1).  fpu_done pulses here
                // for single-pop ops; for double-pop ops (FCOMPP / FUCOMPP)
                // we instead transition into S_POP2 to clear the second
                // tag and bump TOP again.
                S_POP: begin
                    state <= pop_twice_lat ? S_POP2 : S_IDLE;
                end

                // S_FXCH2 (PR-2b.3k): second leg of the FXCH swap.  Writes
                // ST(i) := a_lat (old ST(0) data) with tag = st0_tag_lat.
                // fpu_done pulses here; TOP unchanged.
                S_FXCH2: begin
                    state <= S_IDLE;
                end

                // S_POP2 (PR-2b.3q): second leg of the FCOMPP / FUCOMPP
                // double-pop.  Tag-only write of Empty to abs_st1, with
                // top_din = top_lat + 2 driving the final TOP advance.
                // fpu_done pulses here.
                S_POP2: begin
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    //--------------------------------------------------------------------
    // Combinational arith primitives.  All four run in parallel — the
    // mux below picks one set of outputs.  In S_COMPUTE, `a_lat` has
    // been latched but `b_lat` is still on the rd_data bus, so we mux b
    // accordingly.  In S_POST both are latched.  sum_pre/flags_pre are
    // registered at S_COMPUTE→S_POST into z_lat/flags_lat so they stay
    // stable through retirement.
    //
    // Primitive selection (PR-2b.3c/d):
    //   kind_lat == DIV  → div (sign + special-case handling internal)
    //   kind_lat == MUL  → mul (sign computed inside mul as a.sign^b.sign)
    //   else add/sub dispatch:
    //     use_sub_primitive = (a.sign XOR b.sign) XOR kind_lat[0]
    //     kind_lat == ADD : same-sign uses add, diff-sign uses sub
    //     kind_lat == SUB : same-sign uses sub, diff-sign uses add
    //   For sub, z_sign_in = a.sign — the primitive flips internally if
    //   |b| > |a|.
    //
    // PR-2b.3d: FSUBR / FDIVR use the existing SUB / DIV primitives with
    // operands swapped.  The swap is applied here, at the boundary
    // between arith_a/arith_b and the primitive inputs (op_a/op_b), so
    // every downstream wire (use_sub_primitive, z_sign_in, etc.) sees a
    // single normalised view: op_a is always the effective minuend /
    // dividend.  Add and mul are commutative so the swap is a harmless
    // no-op for them — but applying it uniformly keeps the dispatch
    // logic single-track.
    //--------------------------------------------------------------------
    // PR-2b.4d (iter 55): converter instances feeding the mem-form arith
    // lane.  Both run combinationally off mem_data_lat — only the one
    // selected by mem_fmt_lat is consumed via the b_source mux below.
    // mem_de_flag / mem_ie_flag fan into flags_lat at S_COMPUTE only when
    // is_mem_form_lat is set, so reg-form ops see exactly the same
    // flags_pre they did before this iter.
    wire [79:0] f32_to_x80_z;
    wire        f32_to_x80_de;
    wire        f32_to_x80_ie;
    float32_to_floatx80 u_f32_to_x80 (
        .a  (mem_data_lat[31:0]),
        .z  (f32_to_x80_z),
        .de (f32_to_x80_de),
        .ie (f32_to_x80_ie)
    );
    wire [79:0] f64_to_x80_z;
    wire        f64_to_x80_de;
    wire        f64_to_x80_ie;
    float64_to_floatx80 u_f64_to_x80 (
        .a  (mem_data_lat),
        .z  (f64_to_x80_z),
        .de (f64_to_x80_de),
        .ie (f64_to_x80_ie)
    );
    // mem_z / mem_de_flag / mem_ie_flag are forward-declared near the FSM's
    // forward-decl block (cmp_ie_now / sum_pre / etc) so the S_COMPUTE
    // always-block can read them before this mux.  Same Gotcha #9 pattern.
    assign mem_z       = mem_fmt_lat[0] ? f64_to_x80_z  : f32_to_x80_z;
    assign mem_de_flag = mem_fmt_lat[0] ? f64_to_x80_de : f32_to_x80_de;
    assign mem_ie_flag = mem_fmt_lat[0] ? f64_to_x80_ie : f32_to_x80_ie;

    wire [79:0] arith_a = a_lat;
    // PR-2b.4d (iter 55): for mem-form, b is the converted mem operand
    // (mem_z) instead of rf_rd_data / b_lat.  In S_COMPUTE b is sourced
    // from the converter; in later states it's the registered b_lat copy
    // (which we update in S_COMPUTE — see the b_lat write below).  For
    // reg-form, this mux collapses to the original
    // `(state == S_COMPUTE) ? rf_rd_data : b_lat` expression.
    wire [79:0] arith_b = is_mem_form_lat
                              ? ((state == S_COMPUTE) ? mem_z : b_lat)
                              : ((state == S_COMPUTE) ? rf_rd_data : b_lat);
    wire [79:0] op_a = reverse_lat ? arith_b : arith_a;
    wire [79:0] op_b = reverse_lat ? arith_a : arith_b;
    // sum_pre / flags_pre are forward-declared above the FSM.

    softfloat_add_x80 u_add (
        .a     (op_a),
        .b     (op_b),
        .z     (add_z),
        .flags (add_flags)
    );

    softfloat_sub_x80 u_sub (
        .a          (op_a),
        .b          (op_b),
        .z_sign_in  (op_a[79]),
        .z          (sub_z),
        .flags      (sub_flags)
    );

    softfloat_mul_x80 u_mul (
        .a     (op_a),
        .b     (op_b),
        .z     (mul_z),
        .flags (mul_flags)
    );

    softfloat_div_x80 u_div (
        .a     (op_a),
        .b     (op_b),
        .z     (div_z),
        .flags (div_flags)
    );

    wire use_sub_primitive = (op_a[79] ^ op_b[79]) ^ kind_lat[0];
    wire [79:0] addsub_z     = use_sub_primitive ? sub_z     : add_z;
    wire [5:0]  addsub_flags = use_sub_primitive ? sub_flags : add_flags;
    wire [79:0] mul_or_addsub_z     = (kind_lat == KIND_MUL) ? mul_z     : addsub_z;
    wire [5:0]  mul_or_addsub_flags = (kind_lat == KIND_MUL) ? mul_flags : addsub_flags;

    assign sum_pre   = (kind_lat == KIND_DIV) ? div_z     : mul_or_addsub_z;
    assign flags_pre = (kind_lat == KIND_DIV) ? div_flags : mul_or_addsub_flags;

    //--------------------------------------------------------------------
    // Outputs
    //--------------------------------------------------------------------
    assign fpu_busy = (state != S_IDLE);
    // PR-2b.3e: fpu_done pulses at the FSM's terminal state.  For non-pop
    // ops, that's S_RETIRE (one cycle, then back to IDLE).  For pop ops
    // that didn't trap, it's S_POP (after the tag-clear / TOP++).  For
    // pop ops that DID trap (es_now=1 at S_RETIRE), the pop is skipped
    // and S_RETIRE is again terminal — handled by gating on the same
    // condition the S_RETIRE→state transition uses.
    // PR-2b.3k: FXCH is also two-cycle: S_RETIRE writes ST(0):=old ST(i),
    // then S_FXCH2 writes ST(i):=old ST(0) and fpu_done pulses there.
    // PR-2b.3q (iter 48): for double-pop ops fpu_done fires at S_POP2,
    // not S_POP (the single S_POP cycle is just the first tag-clear /
    // TOP++; the op isn't retired until the second tag-clear has also
    // landed).  The ~pop_twice_lat gate on the S_POP arm prevents
    // double-fire; the S_POP2 arm covers FCOMPP / FUCOMPP exclusively.
    assign fpu_done = (state == S_POP2) ||
                      ((state == S_POP) && ~pop_twice_lat) ||
                      (state == S_FXCH2) ||
                      ((state == S_RETIRE) && !is_fxch_lat
                                           && !(pop_after_lat && ~es_now));

    //--------------------------------------------------------------------
    // PR-2b.2d: exc_flags_set OR-lane into the external fpu_csr.
    //
    //   unmasked_flags : bits in flags_lat that are NOT masked by cw[5:0]
    //   es_now         : summary bit (logical OR of unmasked_flags)
    //
    // exc_flags_set is asserted ONLY during S_RETIRE; the CSR's
    // `exc_flags <= exc_flags | exc_flags_set` then fires on the same
    // edge, leaving the new bits set in the CSR from the next cycle on.
    // ES inside the CSR is derived combinationally from the post-edge
    // exc_flags & ~cw, so we don't need to drive it here.
    //--------------------------------------------------------------------
    assign unmasked_flags = flags_lat & ~cw[5:0];
    assign es_now         = |unmasked_flags;

    assign exc_flags_set = (state == S_RETIRE) ? flags_lat : 6'd0;

    // PR-2b.3e: TOP mutation lives here.  Pop ops bump TOP by 1 in
    // S_POP (cycle AFTER S_RETIRE); non-pop arith ops leave TOP alone.
    // PR-2b.3l: FLD push decrements TOP by 1 in S_RETIRE (same cycle as
    // the data write to abs_new_top).  Mutual exclusion: is_fld_lat and
    // S_POP can't both be true (FLD doesn't enter S_POP since
    // pop_after_lat=0 when is_fld_sti=1).
    // PR-2b.3q (iter 48): top_din now also drives top_lat+2 in S_POP2 to
    // finalise the double-pop.  top_we pulses on BOTH S_POP and S_POP2
    // for double-pop ops — fpu_csr advances TOP on each pulse, so over
    // two consecutive cycles it sees top_lat+1 then top_lat+2.
    // PR-2b.3s (iter 50): FDECSTP / FINCSTP pulse top_we at S_RETIRE with
    // top_din = top_lat ∓ 1.  Mutual exclusion with is_fld_lat (different
    // CMD families).  3-bit add/sub wraps mod 8 in Verilog so no extra
    // masking is needed.
    assign top_din              = (state == S_POP)  ? (top_lat + 3'd1) :
                                  (state == S_POP2) ? (top_lat + 3'd2) :
                                  is_fld_lat        ? abs_new_top      :
                                  is_fdecstp_lat    ? (top_lat - 3'd1) :
                                  is_fincstp_lat    ? (top_lat + 3'd1) :
                                                      top_lat;          // unused otherwise
    assign top_we               = (state == S_POP) ||
                                  (state == S_POP2) ||
                                  ((state == S_RETIRE) && (is_fld_lat |
                                                           is_fdecstp_lat |
                                                           is_fincstp_lat));

    // #MF (vector 16): fires on any UNMASKED exception during retire.
    assign exe_trigger_mf_fault = (state == S_RETIRE) && es_now;

    // Regfile write:
    //   S_RETIRE  : data write of z_lat with Valid tag, gated by ~es_now.
    //               Destination is ST(i) for pop ops, ST(0) otherwise.
    //               PR-2b.3k FXCH override: writes ST(0) := b_lat (the
    //               original ST(i) data) with tag = stsrc_tag_lat.
    //   S_POP     : tag-only conceptual write — wr_data is don't-care;
    //               wr_tag = Empty marks the post-pop slot vacant.  The
    //               write is unconditional within the state (the FSM
    //               already gated entry on ~es_now).
    //   S_FXCH2   : PR-2b.3k second leg of the swap.  Writes ST(i) :=
    //               a_lat (the original ST(0) data) with tag = st0_tag_lat.
    //               TOP unchanged.  rf_wr_en unconditional within state.
    // PR-2b.3c writeback-gate is preserved for S_RETIRE; PR-2b.3e adds
    // the S_POP cleanup; PR-2b.3k adds the S_FXCH2 second write; PR-2b.3l
    // adds the FLD push (single S_RETIRE write to abs_new_top with
    // simultaneous top_we pulse below).  Note: FXCH / FLD never trap
    // (flags_lat forced 6'b0 in S_COMPUTE so es_now=0 at S_RETIRE) so
    // the ~es_now gate is naturally satisfied.
    // PR-2b.3q (iter 48): S_POP2 writes the second pop's Empty tag to ST(1)
    // at op start = (top_lat + 1) & 7 (i.e. abs_st1).
    assign rf_wr_idx  = (state == S_POP)    ? abs_st0     :
                        (state == S_POP2)   ? abs_st1     :
                        (state == S_FXCH2)  ? abs_stsrc   :
                        is_fxch_lat         ? abs_st0     :
                        is_fld_lat          ? abs_new_top :   // FLD push dest
                        dst_is_sti_lat      ? abs_stsrc   :   // arith-DE / FST / FSTP
                                              abs_st0;
    // PR-2b.3n: FCHS / FABS unary-result encodings.  Both preserve ST(0)'s
    // exponent and fraction; only bit 79 (sign) changes.  FCHS toggles it;
    // FABS clears it.  Computed combinationally from a_lat (which has the
    // ST(0) operand at op start — same source the FXAM classifier uses).
    wire [79:0] fchs_result = { ~a_lat[79], a_lat[78:0] };
    wire [79:0] fabs_result = {  1'b0,      a_lat[78:0] };

    assign rf_wr_data = (state == S_FXCH2) ? a_lat :
                        is_fxch_lat        ? b_lat :
                        is_fld_lat         ? b_lat :          // old ST(i) data
                        is_fst_lat         ? a_lat :          // FST/FSTP: ST(0) data
                        is_fchs_lat        ? fchs_result :    // FCHS: ~bit79 of ST(0)
                        is_fabs_lat        ? fabs_result :    // FABS: clear bit79 of ST(0)
                        is_ffree_lat       ? b_lat :          // PR-2b.3r FFREE: preserve ST(i) data
                        is_fcmov_lat       ? b_lat :          // PR-2b.3t FCMOV taken: ST(0) <- ST(i)
                                             z_lat;
    assign rf_wr_tag  = (state == S_POP)    ? 2'b11         :  // Empty
                        (state == S_POP2)   ? 2'b11         :  // PR-2b.3q: Empty (second pop)
                        (state == S_FXCH2)  ? st0_tag_lat   :  // FXCH tag swap
                        is_fxch_lat         ? stsrc_tag_lat :  // first FXCH write
                        is_fld_lat          ? stsrc_tag_lat :  // copy ST(i) tag
                        is_fst_lat          ? st0_tag_lat   :  // FST/FSTP: copy ST(0) tag
                        (is_fchs_lat | is_fabs_lat) ? st0_tag_lat :  // FCHS/FABS: preserve ST(0) tag
                        is_ffree_lat        ? 2'b11         :  // PR-2b.3r FFREE: Empty
                        is_fcmov_lat        ? stsrc_tag_lat :  // PR-2b.3t FCMOV taken: copy ST(i) tag
                                              2'b00;           // Valid (arith)
    // PR-2b.3n: FXAM suppresses the regfile write (no data change to ST(0));
    // it only pulses cc_we.  Other ops in S_RETIRE write as before; pop
    // (S_POP) and FXCH-second-leg (S_FXCH2) still pulse unconditionally.
    // PR-2b.3o: cmp ops also suppress the S_RETIRE data write (they only
    // pulse cc_we).  The S_POP cleanup that FCOMP/FUCOMP arm via
    // pop_after_lat still runs unconditionally within S_POP.
    // PR-2b.3s (iter 50): FNOP / FDECSTP / FINCSTP also suppress the
    // regfile write at S_RETIRE — they're either pure FSM ticks (FNOP)
    // or pure TOP mutations (FDECSTP/FINCSTP).
    // PR-2b.3t (iter 51): FCMOVcc gates rf_wr_en on the captured condition —
    // a not-taken move is a no-op (no data / tag / flags change), so the
    // S_RETIRE write is suppressed.  When taken, rf_wr_en fires exactly
    // like a normal arith retire: writes b_lat (ST(i) data) + stsrc_tag_lat
    // to abs_st0.  Mutually exclusive with all other *_lat regs, so the
    // existing ~is_fxam_lat / ~is_cmp_lat / etc. masks stay quiet for FCMOV.
    assign rf_wr_en   = ((state == S_RETIRE) && ~es_now && ~is_fxam_lat && ~is_cmp_lat
                                            && ~is_fnop_lat && ~is_fdecstp_lat && ~is_fincstp_lat
                                            && (~is_fcmov_lat | fcmov_taken_lat)) ||
                        (state == S_POP) ||
                        (state == S_POP2) ||    // PR-2b.3q: second tag-Empty write
                        (state == S_FXCH2);

    //--------------------------------------------------------------------
    // PR-2b.3n: FXAM classification on a_lat.  Intel SDM Vol 1 §8.3.5 /
    // Bochs i387_t::FXAM.  C1 always carries ST(0)'s sign bit (bit 79).
    // C3/C2/C0 encode the class:
    //
    //   Class        C3 C2 C0
    //   Unsupported   0  0  0    (pseudo-Inf, pseudo-NaN, unnormal)
    //   NaN           0  0  1    (exp=0x7FFF, J=1, low_frac != 0)
    //   Normal        0  1  0    (exp in (0, 0x7FFF), J=1)
    //   Infinity      0  1  1    (exp=0x7FFF, J=1, low_frac == 0)
    //   Zero          1  0  0    (exp=0, J=0, low_frac == 0)
    //   Empty         1  0  1    (tag == 2'b11)
    //   Denormal      1  1  0    (exp=0, (J | low_frac) != 0; J=1 case is
    //                             "pseudo-denormal", folded in per Bochs)
    //
    // The classifier reads st0_tag_lat (latched at S_FETCH_B from the
    // regfile read) and a_lat (latched at S_FETCH_B from the same edge).
    //--------------------------------------------------------------------
    wire [14:0] fxam_exp        = a_lat[78:64];
    wire        fxam_j          = a_lat[63];
    wire        fxam_low_frac_z = (a_lat[62:0] == 63'h0);
    wire        fxam_sign       = a_lat[79];

    wire        fxam_exp_zero   = (fxam_exp == 15'h0000);
    wire        fxam_exp_max    = (fxam_exp == 15'h7FFF);

    wire        fxam_is_empty   = (st0_tag_lat == 2'b11);
    wire        fxam_is_zero    = ~fxam_is_empty &  fxam_exp_zero & ~fxam_j &  fxam_low_frac_z;
    wire        fxam_is_denorm  = ~fxam_is_empty &  fxam_exp_zero & (fxam_j | ~fxam_low_frac_z);
    wire        fxam_is_inf     = ~fxam_is_empty &  fxam_exp_max  &  fxam_j &  fxam_low_frac_z;
    wire        fxam_is_nan     = ~fxam_is_empty &  fxam_exp_max  &  fxam_j & ~fxam_low_frac_z;
    wire        fxam_is_normal  = ~fxam_is_empty & ~fxam_exp_zero & ~fxam_exp_max & fxam_j;
    // Unsupported = everything else (exp=0x7FFF with J=0, or exp in
    // (0, 0x7FFF) with J=0).  No explicit wire — falls through as the
    // mux's default.

    // {C3, C2, C1, C0}.  C1 is always ST(0)'s sign.
    wire [3:0] fxam_cc = fxam_is_empty   ? {1'b1, 1'b0, fxam_sign, 1'b1} :
                         fxam_is_zero    ? {1'b1, 1'b0, fxam_sign, 1'b0} :
                         fxam_is_denorm  ? {1'b1, 1'b1, fxam_sign, 1'b0} :
                         fxam_is_inf     ? {1'b0, 1'b1, fxam_sign, 1'b1} :
                         fxam_is_nan     ? {1'b0, 1'b0, fxam_sign, 1'b1} :
                         fxam_is_normal  ? {1'b0, 1'b1, fxam_sign, 1'b0} :
                                           {1'b0, 1'b0, fxam_sign, 1'b0}; // Unsupported

    //--------------------------------------------------------------------
    // PR-2b.3o: comparison classifier — drives cc_we / cc_din for the
    // FCOM/FCOMP/FUCOM/FUCOMP family.  Mirrors FXAM's classifier structure
    // but on two operands.  cmp_b crosses the same S_COMPUTE→S_POST
    // boundary as arith_b: rf_rd_data while still in S_COMPUTE, b_lat
    // afterward — so flags_lat captured at S_COMPUTE→S_POST sees the
    // pre-latch operand and the cc_din evaluated at S_RETIRE sees the
    // post-latch operand; both views agree.
    //
    // Sign-aware magnitude compare on bits [78:0] (exp + significand
    // including the J-bit), then sign overlay.  ±0 are forced equal.
    //
    // {C3, C2, C1=0, C0} per Intel SDM Vol 1 §8.3.6:
    //   ST(0) > ST(i): 0 0 0
    //   ST(0) < ST(i): 0 0 1
    //   ST(0) = ST(i): 1 0 0
    //   Unordered:     1 1 1   (any NaN operand)
    // C1 = 0 (no stack overflow for these ops; SF would set it).
    //--------------------------------------------------------------------
    wire [79:0] cmp_a_v = a_lat;
    // PR-2b.3p: FTST overrides cmp_b with literal +0.0 so the cmp classifier
    // emits FCOM-style {C3,C2,C1=0,C0} on a single-operand ST(0) classify.
    // The FETCH path still reads ST(rm) but the data is ignored once
    // is_ftst_lat is set at S_IDLE→S_FETCH_A.
    wire [79:0] cmp_b_v = is_ftst_lat ? 80'h0 :
                          (state == S_COMPUTE) ? rf_rd_data : b_lat;

    wire        cmp_a_sign = cmp_a_v[79];
    wire        cmp_b_sign = cmp_b_v[79];
    wire [78:0] cmp_a_mag  = cmp_a_v[78:0];
    wire [78:0] cmp_b_mag  = cmp_b_v[78:0];

    wire [14:0] cmp_a_exp  = cmp_a_v[78:64];
    wire [14:0] cmp_b_exp  = cmp_b_v[78:64];
    wire        cmp_a_j    = cmp_a_v[63];
    wire        cmp_b_j    = cmp_b_v[63];
    wire        cmp_a_lfz  = (cmp_a_v[62:0] == 63'h0);
    wire        cmp_b_lfz  = (cmp_b_v[62:0] == 63'h0);

    wire cmp_a_exp_max  = (cmp_a_exp == 15'h7FFF);
    wire cmp_b_exp_max  = (cmp_b_exp == 15'h7FFF);
    wire cmp_a_exp_zero = (cmp_a_exp == 15'h0000);
    wire cmp_b_exp_zero = (cmp_b_exp == 15'h0000);

    wire cmp_a_is_nan  = cmp_a_exp_max  & cmp_a_j & ~cmp_a_lfz;
    wire cmp_b_is_nan  = cmp_b_exp_max  & cmp_b_j & ~cmp_b_lfz;
    // SNaN: bit 62 (high bit of the fraction below the J-bit) clear; QNaN
    // sets it.  Per Intel SDM Vol 1 §4.8.3.4 / IA-32 floatx80 conventions.
    wire cmp_a_is_snan = cmp_a_is_nan & ~cmp_a_v[62];
    wire cmp_b_is_snan = cmp_b_is_nan & ~cmp_b_v[62];
    wire cmp_a_is_zero = cmp_a_exp_zero & ~cmp_a_j & cmp_a_lfz;
    wire cmp_b_is_zero = cmp_b_exp_zero & ~cmp_b_j & cmp_b_lfz;

    wire cmp_any_nan   = cmp_a_is_nan  | cmp_b_is_nan;
    wire cmp_any_snan  = cmp_a_is_snan | cmp_b_is_snan;
    wire cmp_both_zero = cmp_a_is_zero & cmp_b_is_zero;

    wire mag_a_gt_b = (cmp_a_mag >  cmp_b_mag);
    wire mag_a_eq_b = (cmp_a_mag == cmp_b_mag);

    // Sign-aware equality: both zero short-circuits; otherwise signs and
    // magnitudes must match.
    wire cmp_equal = cmp_both_zero |
                     ((cmp_a_sign == cmp_b_sign) & mag_a_eq_b);

    // ST(0) < ST(i):
    //   both signs 0:  mag(a) <  mag(b)
    //   both signs 1:  mag(a) >  mag(b)  (more-negative magnitude = smaller value)
    //   a<0, b>=0   :  a < b              (both-zero already covered above)
    wire cmp_a_lt_b = ~cmp_equal & (
            (~cmp_a_sign & ~cmp_b_sign & ~mag_a_gt_b & ~mag_a_eq_b) |
            ( cmp_a_sign &  cmp_b_sign &  mag_a_gt_b)               |
            ( cmp_a_sign & ~cmp_b_sign)
        );

    wire cmp_unordered = cmp_any_nan;

    // {C3, C2, C1, C0}.  C1 always 0 (no stack overflow).
    wire [3:0] cmp_cc =
        cmp_unordered ? 4'b1101 :    // Unordered:      C3=1, C2=1, C1=0, C0=1
        cmp_equal     ? 4'b1000 :    // ST(0) = ST(i):  C3=1
        cmp_a_lt_b    ? 4'b0001 :    // ST(0) < ST(i):  C0=1
                        4'b0000;     // ST(0) > ST(i):  all zero

    // IE policy: FCOM/FCOMP raise on any NaN; FUCOM/FUCOMP raise only on
    // SNaN (QNaN is silent — that's what "unordered" buys you semantically).
    // cmp_ie_now is forward-declared near the FSM (Gotcha #9); driven here.
    assign cmp_ie_now = is_fucom_lat ? cmp_any_snan : cmp_any_nan;

    assign cc_din = is_cmp_lat ? cmp_cc : fxam_cc;
    // PR-2b.3u (iter 52): FCOMI family does NOT pulse cc_we — it writes
    // integer EFLAGS instead.  The SDM-mandated "clear C1 on FCOMI"
    // partial-write to the CSR is deferred (the CSR module would need
    // per-bit cc write-enables; for now C0/C1/C2/C3 stay at their prior
    // values — benign for the current unit TB, which does not assert
    // CSR cc preservation across an FCOMI).  is_cmp_lat & ~is_cmpi_lat
    // keeps FCOM/FCOMP/FUCOM/FUCOMP/FCOMPP/FUCOMPP/FTST writing cc as
    // before; is_fxam_lat is independent and remains gating.
    assign cc_we  = (state == S_RETIRE) && (is_fxam_lat | (is_cmp_lat & ~is_cmpi_lat));

    //--------------------------------------------------------------------
    // PR-2b.3u (iter 52): integer EFLAGS write-back lane.  Pulsed in
    // S_RETIRE when is_cmpi_lat is set and no unmasked exception
    // trapped.  Mapping of cmp_cc → {ZF, PF, CF}:
    //   greater    cc=0000 → eflags_value = 3'b000  (ZF=0, PF=0, CF=0)
    //   less       cc=0001 → eflags_value = 3'b001  (ZF=0, PF=0, CF=1)
    //   equal      cc=1000 → eflags_value = 3'b100  (ZF=1, PF=0, CF=0)
    //   unordered  cc=1101 → eflags_value = 3'b111  (ZF=1, PF=1, CF=1)
    // Equivalent extraction: ZF=cmp_cc[3], PF=cmp_cc[2], CF=cmp_cc[0].
    // OF / SF / AF are explicitly unmodified per Intel SDM Vol 1 §8.3.6.4
    // (and are not driven on this lane — the consuming integer mux
    // must preserve them).
    //--------------------------------------------------------------------
    assign eflags_value = {cmp_cc[3], cmp_cc[2], cmp_cc[0]};
    assign eflags_we    = (state == S_RETIRE) && is_cmpi_lat && ~es_now;

    // Read port — index changes per FSM substate.
    //   S_FETCH_A: present abs_st0 (live, since top_lat is being captured
    //              on this same edge).
    //   S_FETCH_B: present abs_stsrc.
    //   S_COMPUTE+: don't care; default to abs_st0_live.
    assign rf_rd_idx = (state == S_FETCH_A) ? abs_st0_live :
                       (state == S_FETCH_B) ? abs_stsrc    :
                                              abs_st0_live;

    //--------------------------------------------------------------------
    // synthesis translate_off
    // Suppress unused-wire warnings on inputs the iter-24 FADD path
    // doesn't yet read.  PR-2b.2c (SW/#MF), PR-2b.4 (mem-form), and
    // PR-2b.6 (pop) progressively consume these.
    // cw[5:0] is read by the exception-masking logic above; cw[15:6]
    // (RC, PC, etc.) is not yet consumed by this narrow contract.
    // PR-2b.4d (iter 55): exe_mem_data removed — now latched into
    // mem_data_lat at S_IDLE->S_FETCH_A and consumed by the converters.
    // exe_is_mem_form / exe_mem_fmt / exe_mem_data_valid stay suppressed
    // because is_mem_form_lat and mem_fmt_lat are derived internally from
    // the CMD code (CMD_fpu_arith_mem) + CMDEX width.  Later sub-iters
    // expanding the mem-form set (FSUB / FMUL / FDIV mem) will keep this
    // pattern; the external ports become relevant only if/when a decoder
    // lane drives them (deferred to PR-2b.5+ if needed at all).
    wire _unused_ok = &{ 1'b0,
                         exe_modregrm_reg_3b,
                         exe_is_mem_form,
                         exe_pop_after,
                         exe_mem_fmt,
                         exe_mem_data_valid,
                         cw[15:6],
                         st0_empty_lat,
                         stsrc_empty_lat,
                         1'b0 };
    // synthesis translate_on

endmodule
