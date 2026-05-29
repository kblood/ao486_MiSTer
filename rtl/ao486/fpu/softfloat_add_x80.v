// softfloat_add_x80.v
//
// PR-2b.2a: pure combinational softfloatx80_add primitive — the first
// arithmetic op of the FPU project.
//
// Scope (intentionally narrow for this first cut):
//   - Same-sign add path only. Opposite-sign (sub) is a separate module.
//   - Normal-normal operands. Caller guarantees neither operand is
//     NaN / Inf / Zero / Denormal / unsupported encoding (a_exp and b_exp
//     in [0x0001, 0x7FFE], both have explicit integer bit = 1).
//   - Round-to-nearest-even only (CW.RC == 00, the FNINIT default).
//   - Extended precision only (no FPU.PC short-circuit).
//
// PR-2b.2c additions:
//   - `flags[5:0]` output exposes the IEEE-754 exception bits the
//     primitive's contract can raise.  Bit positions match Intel SDM
//     Vol 1 §8.1.3 / fpu_csr.v's CW.x M masks:
//       flags[0] = IE (Invalid)    — never raised here (no NaN/Inf input)
//       flags[1] = DE (Denormal)   — never raised here (caller guarantees
//                                    normal-normal)
//       flags[2] = ZE (Zero)       — only FDIV
//       flags[3] = OE (Overflow)   — z_exp_final saturates to 7FFF
//       flags[4] = UE (Underflow)  — impossible from sum of two normals
//       flags[5] = PE (Precision)  — round_bit | sticky was nonzero
//     Only PE and OE can fire in this narrow contract.  Note the
//     overflow→+Inf encoding fix is deferred — when OE fires, z still
//     carries the saturated 7FFF normal encoding (caller treats as +Inf
//     equivalent).  PR-2b.2c only emits the flag; the encoding fix is
//     out of scope (none of the existing 1000 oracle vectors trigger OE).
//
// Bit layout (Intel SDM Vol 1 §8.1.2):
//   z[79]    = sign
//   z[78:64] = biased exponent (bias 0x3FFF)
//   z[63]    = explicit J-bit (always 1 for normals)
//   z[62:0]  = fraction
//
// Reference: addFloatx80Sigs() at sim/testfloat/softfloat/softfloat.cc:3041
// plus shift64ExtraRightJamming() at softfloat-macros.h:130.
//
// Validation: sim/testfloat/gen_add_vectors generates a hex file of
// (a, b, expected_z) tuples by calling the vendored Bochs softfloat;
// sim/modelsim/softfloat_add_x80_tb.v drives them through this module
// and counts mismatches.

`timescale 1ns / 1ps

module softfloat_add_x80 (
    input  wire [79:0] a,
    input  wire [79:0] b,
    input  wire [1:0]  precision,   // PR-2b.5u: PC = CW[9:8]; 11/01 = extended (inline)
    input  wire [1:0]  rc,          // PR-2b.5v: RC = CW[11:10]; 00=RNE (inline path)
    // PR-2c.1 (iter 156): rounder hoisted to shared instance in execute_fpu.v.
    // Pre-round triple exported to caller; rounded result fed back.  use_rounder
    // mux stays here so the inline RNE/PC80 path is unchanged (zero regression).
    output wire        pr_sign,
    output wire signed [16:0] pr_exp,
    output wire [63:0] pr_sig0,
    output wire [63:0] pr_sig1,
    input  wire [79:0] shared_round_z,
    input  wire [5:0]  shared_round_flags,
    // PR-2c.2 (iter 157): floatx80_pack_subn also hoisted to a shared instance
    // in execute_fpu.v.  It consumes the SAME pr_* triple, so no new output
    // port is needed; the subnormal result is routed back here.
    input  wire [79:0] shared_subn_z,
    input  wire        shared_subn_pe,
    output wire [79:0] z,
    output wire [5:0]  flags        // {PE, UE, OE, ZE, DE, IE}
);

    //--------------------------------------------------------------------
    // PR-2b.3f: NaN propagation override.  When either input is NaN,
    // bypass the normal-normal add path entirely and emit a propagated
    // QNaN (with IE if any input was SNaN).  See floatx80_nan_handle.v
    // for the per-Bochs propagation rule.
    //--------------------------------------------------------------------
    wire        is_any_nan;
    wire [79:0] z_nan;
    wire [5:0]  flags_nan;
    floatx80_nan_handle u_nan (
        .a           (a),
        .b           (b),
        .is_nan_a    (),
        .is_nan_b    (),
        .is_any_nan  (is_any_nan),
        .is_any_snan (),
        .z_nan       (z_nan),
        .flags_nan   (flags_nan)
    );

    //--------------------------------------------------------------------
    // PR-2b.3g: Inf override.  This primitive's contract is "same-sign
    // magnitude add" — the dispatcher guarantees a.sign == b.sign on the
    // path that actually consumes our output.  Inf cases all produce a
    // sign-of-a Inf with no flags:
    //   Inf + Inf same-sign → Inf (carries a's sign).
    //   Inf + finite        → Inf (Inf's sign == a.sign by contract).
    //   finite + Inf        → Inf (Inf's sign == a.sign by contract).
    // No invalid case can occur in this primitive (Inf-Inf opposite-sign
    // is routed to softfloat_sub_x80 by the use_sub_primitive dispatch).
    //--------------------------------------------------------------------
    wire is_inf_a, is_inf_b, is_any_inf;
    floatx80_inf_handle u_inf (
        .a          (a),
        .b          (b),
        .is_inf_a   (is_inf_a),
        .is_inf_b   (is_inf_b),
        .is_any_inf (is_any_inf)
    );
    wire [79:0] z_inf     = {a[79], 15'h7FFF, 64'h8000000000000000};
    wire [5:0]  flags_inf = 6'd0;

    //--------------------------------------------------------------------
    // PR-2b.3h: Zero override.  This primitive is consumed for FADD
    // same-sign and FSUB diff-sign — in BOTH routes the dispatcher
    // sets z_sign = a.sign so the result carries the correct algebraic
    // sign for any combination of zero / non-zero operands:
    //   only_a_zero (a=0, b!=0): result is sign-of-a applied to |b|.
    //                            FSUB(+0,-5) → {+, |5|} = +5.  ✓
    //   only_b_zero (a!=0, b=0): result is sign-of-a applied to |a| = a.
    //   both_zero               : result is {sign-of-a, 0, 0}.
    //                            FSUB(+0,-0) → {+, 0, 0} = +0.  ✓
    //                            FSUB(-0,+0) → {-, 0, 0} = -0.  ✓
    // The compact form `{a[79], is_zero_a ? b[78:0] : a[78:0]}` covers
    // all three cases — when is_zero_a the non-zero exp+sig comes from
    // b (or 0 if b is also zero); when is_zero_b but not is_zero_a the
    // non-zero exp+sig comes from a.  No flags ever raised here.
    // Without this override the normal-path would force the J-bit
    // (z_sig0_pre = {1'b1, sum_full[63:1]}) and emit a bogus tiny-
    // normal encoding for +0+0 inputs.
    //--------------------------------------------------------------------
    wire is_zero_a, is_zero_b, is_any_zero;
    floatx80_zero_handle u_zero (
        .a           (a),
        .b           (b),
        .is_zero_a   (is_zero_a),
        .is_zero_b   (is_zero_b),
        .is_any_zero (is_any_zero)
    );
    wire [79:0] z_zero     = {a[79], is_zero_a ? b[78:0] : a[78:0]};
    wire [5:0]  flags_zero = 6'd0;

    //--------------------------------------------------------------------
    // PR-2b.3i (cut 1, iter 38): denormal detection + DE flag.
    // Per Bochs softfloatx80, the DE flag fires for any denormal input
    // on the normal-arithmetic path (NaN/Inf/Zero cascades short-circuit
    // before us so they own their own flag generation).
    //--------------------------------------------------------------------
    wire is_subn_a, is_subn_b, is_any_subn;
    floatx80_subn_handle u_subn (
        .a           (a),
        .b           (b),
        .is_subn_a   (is_subn_a),
        .is_subn_b   (is_subn_b),
        .is_any_subn (is_any_subn)
    );

    //--------------------------------------------------------------------
    // PR-2b.3i (cut 2, iter 40): floatx80_normalize the operands so the
    // existing normal-path arith produces an IEEE-correct result even
    // when one or both inputs are denormal.  For normal inputs the helper
    // is a pass-through (sig unchanged, exp zero-extended to signed 17-bit).
    // For denormal inputs the helper shifts the sig left to land the J-bit
    // at bit 63 and emits a signed exp in [-62, 0].
    //
    // Downstream exp math uses *_exp_s (signed [16:0]) throughout so the
    // negative post-normalize exps and any subsequent overflow into
    // 0x07FFF are observable.
    //--------------------------------------------------------------------
    wire               a_sign;
    wire signed [16:0] a_exp_s;
    wire        [63:0] a_sig;
    floatx80_normalize u_norm_a (
        .a        (a),
        .sign_out (a_sign),
        .exp_out  (a_exp_s),
        .sig_out  (a_sig)
    );

    wire               b_sign_unused;
    wire signed [16:0] b_exp_s;
    wire        [63:0] b_sig;
    floatx80_normalize u_norm_b (
        .a        (b),
        .sign_out (b_sign_unused),
        .exp_out  (b_exp_s),
        .sig_out  (b_sig)
    );

    // Same-sign path: sign of result equals sign of either input.
    wire        z_sign = a_sign;

    //--------------------------------------------------------------------
    // Exponent compare + alignment count.
    //
    // expDiff = aExp - bExp. Pick the larger operand as "big"; the smaller
    // gets right-shifted by |expDiff|. zExp starts as the larger's exponent.
    //
    // Use signed comparisons since post-normalize denormal exps can be
    // negative (range [-62, 0]).  The count itself is always non-negative
    // and fits in 15 unsigned bits (max |diff| ≈ 16383 - (-62) = 16445).
    //--------------------------------------------------------------------
    wire               a_bigger = (a_exp_s >= b_exp_s);
    wire signed [16:0] diff_a_b = a_exp_s - b_exp_s;
    wire signed [16:0] diff_b_a = b_exp_s - a_exp_s;
    wire        [14:0] count    = a_bigger ? diff_a_b[14:0] : diff_b_a[14:0];
    wire signed [16:0] z_exp_pre_shift = a_bigger ? a_exp_s : b_exp_s;

    wire [63:0] sig_big   = a_bigger ? a_sig : b_sig;
    wire [63:0] sig_small = a_bigger ? b_sig : a_sig;

    //--------------------------------------------------------------------
    // shift64ExtraRightJamming(sig_small, 0, count, &sm_shifted, &sm_extra)
    //
    // The "extra" word captures the bits that fell off the bottom; bit 63
    // of sm_extra becomes the round bit, the rest become sticky.
    //
    // We handle count in [0, 64+] via three flat branches.  Note the
    // count==0 path is identical to the same_exp short-circuit below; we
    // still compute it so the always-block is fully covered.
    //--------------------------------------------------------------------
    reg  [63:0] sm_shifted;
    reg  [63:0] sm_extra;
    // verilator lint_off WIDTH
    always @* begin
        if (count == 15'd0) begin
            sm_shifted = sig_small;
            sm_extra   = 64'd0;
        end
        else if (count < 15'd64) begin
            // neg_count = (-count) & 63 = 64 - count (for count in [1,63])
            sm_shifted = sig_small >> count[5:0];
            sm_extra   = sig_small << (6'd64 - count[5:0]);
        end
        else if (count == 15'd64) begin
            sm_shifted = 64'd0;
            sm_extra   = sig_small;
        end
        else begin
            // count > 64: everything jams into one sticky bit.
            sm_shifted = 64'd0;
            sm_extra   = {63'd0, |sig_small};
        end
    end
    // verilator lint_on WIDTH

    //--------------------------------------------------------------------
    // 64+1-bit add (we keep the carry-out explicitly).
    //--------------------------------------------------------------------
    wire [64:0] sum_full  = {1'b0, sig_big} + {1'b0, sm_shifted};
    wire        carry_out = sum_full[64];
    wire [63:0] sum       = sum_full[63:0];

    //--------------------------------------------------------------------
    // Build pre-round (zSig0, zSig1, zExp) per the three C branches:
    //
    //   same_exp     : C unconditionally goes to shiftRight1 with zSig1=0.
    //                  After the shift+OR-MSB, zSig0 = {1, sum_full[63:1]},
    //                  zSig1 = {sum_full[0], 63'd0}, zExp = zExp_pre + 1.
    //
    //   carry_out (different exp): C goes to shiftRight1 with carry kept
    //                  logically (here we already lost it from sum but we
    //                  reinsert via OR-MSB).
    //                  zSig0 = {1, sum[63:1]},
    //                  zSig1 = {sum[0], 63'd0} | sticky from sm_extra,
    //                  zExp  = zExp_pre + 1.
    //
    //   no carry (different exp): C goes straight to roundAndPack.
    //                  zSig0 = sum, zSig1 = sm_extra, zExp = zExp_pre.
    //--------------------------------------------------------------------
    wire same_exp = (a_exp_s == b_exp_s);

    reg         [63:0] z_sig0_pre;
    reg         [63:0] z_sig1_pre;
    reg  signed [16:0] z_exp_pre;
    always @* begin
        if (same_exp) begin
            z_sig0_pre = {1'b1, sum_full[63:1]};
            z_sig1_pre = {sum_full[0], 63'd0};
            z_exp_pre  = z_exp_pre_shift + 17'sd1;
        end
        else if (carry_out) begin
            z_sig0_pre = {1'b1, sum[63:1]};
            z_sig1_pre = {sum[0], 63'd0} | {63'd0, |sm_extra};
            z_exp_pre  = z_exp_pre_shift + 17'sd1;
        end
        else begin
            z_sig0_pre = sum;
            z_sig1_pre = sm_extra;
            z_exp_pre  = z_exp_pre_shift;
        end
    end

    //--------------------------------------------------------------------
    // Round to nearest even on (z_sig0_pre, z_sig1_pre).
    //
    //   round_bit = bit just below the result LSB        = z_sig1_pre[63]
    //   sticky    = OR of all bits further down          = |z_sig1_pre[62:0]
    //   ulp_low   = result LSB (used to break exact ties) = z_sig0_pre[0]
    //
    // Round up iff round_bit && (sticky || ulp_low).
    //
    // If round_up causes z_sig0 to overflow 64 bits (only possible when
    // z_sig0_pre == all-ones; the J-bit MSB *was* 1 and adding 1 wraps to
    // zero), shift right by 1 (which restores the J-bit) and ++zExp.
    //--------------------------------------------------------------------
    wire round_bit = z_sig1_pre[63];
    wire sticky    = |z_sig1_pre[62:0];
    wire ulp_low   = z_sig0_pre[0];
    wire round_up  = round_bit & (sticky | ulp_low);

    wire [64:0] z_sig0_rounded_full = {1'b0, z_sig0_pre} + {64'd0, round_up};
    wire        rnd_carry = z_sig0_rounded_full[64];

    wire [63:0] z_sig0_final = rnd_carry ? 64'h8000000000000000
                                         : z_sig0_rounded_full[63:0];
    wire signed [16:0] z_exp_final = rnd_carry ? (z_exp_pre + 17'sd1) : z_exp_pre;

    //--------------------------------------------------------------------
    // PR-2b.3j (iter 39): overflow→signed-Inf encoding fix.  Per Bochs
    // roundAndPackFloatx80 (RTNE path at softfloat-round-pack.cc:674-675),
    // an overflowed result returns the signed Infinity encoding
    // {sign, 0x7FFF, 0x8000_..._0000} — NOT the wrapped/saturated normal
    // encoding the earlier code emitted.  OE is unconditionally paired
    // with PE (line 667: float_flag_overflow | float_flag_inexact).
    //
    // PR-2b.3i cut 2 (iter 40): UE detection — fires when z_exp_final is
    // non-positive AND the result is non-zero (the matching exception to
    // OE).
    //
    // PR-2b.3i cut 3 (iter 41): subnormal-result encoding.  When ue_now
    // fires, instantiate the shared floatx80_pack_subn helper on the
    // UNROUNDED (z_sig0_pre, z_sig1_pre) and z_exp_pre — the helper
    // shifts the sig right by (1 - z_exp_pre) with jamming, re-rounds-
    // to-nearest-even, and emits the canonical denormal encoding
    // {sign, biased_exp=0, shifted_sig} (or {sign, 1, ...} if rounding
    // bumped the result back to min-normal).
    //--------------------------------------------------------------------
    wire signed [16:0] OE_LIMIT = $signed(17'sh07FFF);
    wire        oe_now       = (z_exp_final >= OE_LIMIT);
    wire        ue_now       = (z_exp_final <= $signed(17'sd0)) &&
                               (z_sig0_final != 64'd0);

    // PR-2c.2 (iter 157): subnormal-result encoding now from the shared
    // floatx80_pack_subn in execute_fpu.v (fed the same pr_* triple).
    wire [79:0] z_subn  = shared_subn_z;
    wire        pe_subn = shared_subn_pe;

    wire [14:0] z_exp_pack   = z_exp_final[14:0];
    wire [79:0] z_normal     = oe_now
                             ? {z_sign, 15'h7FFF, 64'h8000000000000000}
                             : ue_now
                                 ? z_subn
                                 : {z_sign, z_exp_pack, z_sig0_final};

    //--------------------------------------------------------------------
    // Exception flag outputs.  See header for the bit layout.  Inexact
    // (PE) trips whenever the round step had to drop a nonzero remainder
    // OR whenever OE fires (per Bochs, OE always pairs with PE).
    // Overflow (OE) trips when the final biased exponent saturates the
    // 15-bit field.  Underflow (UE) trips when the final biased exponent
    // is non-positive on a non-zero result.  When UE fires the PE bit
    // tracks the helper's post-shift re-round (pe_subn) instead of the
    // original normal-path round/sticky.
    //--------------------------------------------------------------------
    wire        pe_combined = ue_now ? pe_subn : ((round_bit | sticky) | oe_now);
    wire [5:0]  flags_normal = { pe_combined,                    // [5] PE
                                 ue_now,                         // [4] UE
                                 oe_now,                         // [3] OE
                                 3'b000 };                       // [2:0] ZE/DE/IE

    // PR-2b.3i: OR DE into the normal-path flags when any input is
    // denormal.  Doesn't enter the override cascade arms — NaN/Inf/Zero
    // emit their own flags per Bochs semantics.
    wire [5:0]  flags_normal_w_de = flags_normal | {4'd0, is_any_subn, 1'd0};

    //--------------------------------------------------------------------
    // PR-2b.5u (iter 139): precision-control (PC = CW[9:8]) narrowing.
    // Feed the SAME pre-round triple (z_sign, z_exp_pre, z_sig0_pre,
    // z_sig1_pre) that drives the inline RNE rounder into the shared
    // floatx80_round_pc helper.  For PC=single/double it produces the
    // bit-exact narrowed result (a SINGLE rounding at the PC point — no
    // double-round).  PC=extended (11) and reserved (01) leave the inline
    // z_normal byte-identical → zero regression on the oracle suites.  The
    // helper owns PE/UE/OE; we OR in this primitive's DE-from-denormal lane.
    //--------------------------------------------------------------------
    // PR-2b.5v (iter 150): directed rounding (RC = CW[11:10]).  The RC-aware
    // rounder is a strict superset of floatx80_round_pc — Slice-1-validated
    // byte-identical for rc=00 (RNE) across PC32/PC64 — so it replaces the
    // PC helper.  use_rounder fires for ANY narrow PC, OR for ANY directed
    // mode at any PC (incl. PC=80, the primary RC case since FNINIT leaves
    // PC=extended).  rc=00 & PC=80 keeps use_rounder=0 → inline z_normal
    // stays byte-identical → zero regression on the RNE oracle suites.
    wire        is_pc_narrow = (precision == 2'b00) || (precision == 2'b10);
    wire        use_rounder  = is_pc_narrow || (rc != 2'b00);
    // PR-2c.1 (iter 156): export pre-rounder triple; the shared rounder in
    // execute_fpu.v computes the rounded result and routes it back.
    assign pr_sign = z_sign;
    assign pr_exp  = z_exp_pre;
    assign pr_sig0 = z_sig0_pre;
    assign pr_sig1 = z_sig1_pre;
    wire [79:0] z_pc     = shared_round_z;
    wire [5:0]  flags_pc = shared_round_flags;
    wire [79:0] z_normal_pc     = use_rounder ? z_pc : z_normal;
    wire [5:0]  flags_normal_pc = use_rounder
                                ? (flags_pc | {4'd0, is_any_subn, 1'd0})
                                : flags_normal_w_de;

    // Override cascade: NaN > Inf > Zero > normal(+DE if denormal input).
    assign z     = is_any_nan  ? z_nan
                 : is_any_inf  ? z_inf
                 : is_any_zero ? z_zero
                               : z_normal_pc;
    assign flags = is_any_nan  ? flags_nan
                 : is_any_inf  ? flags_inf
                 : is_any_zero ? flags_zero
                               : flags_normal_pc;

endmodule
