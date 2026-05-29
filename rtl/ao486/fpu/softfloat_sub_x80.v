// softfloat_sub_x80.v
//
// PR-2b.3a: pure combinational softfloatx80_sub primitive — the
// magnitude-subtract companion to softfloat_add_x80.  Together the two
// primitives cover floatx80_add / floatx80_sub for all sign permutations
// of the inputs (the wrapper in execute_fpu picks which one to invoke
// based on (a.sign ^ b.sign) ^ is_sub).
//
// Scope (intentionally narrow, mirrors softfloat_add_x80's cut):
//   - Magnitude-subtract path only.  Caller guarantees both operands are
//     normal-normal (exp in [0x0001, 0x7FFE], J-bit = 1) and that the
//     mathematical operation is a magnitude subtract (i.e. one of
//     same-sign FSUB or opposite-sign FADD).
//   - Round-to-nearest-even only (CW.RC == 00, the FNINIT default).
//   - Extended precision only (no FPU.PC short-circuit).
//   - No NaN / Inf / Zero / Denormal handling — caller guarantees it.
//   - Cancellation to exact zero is handled (RTNE → +0 per Bochs).
//
// Inputs:
//   z_sign_in — the proposed result sign.  For floatx80_sub of same-sign
//   operands, the caller passes a.sign; this module flips the sign if
//   |b| > |a|.
//
// Outputs:
//   z — result (sign | exp | sig).  For the cancellation-to-zero case
//        returns +0 (matches Bochs RTNE behaviour at line 3192).
//   flags[5:0] — same layout as softfloat_add_x80:
//     flags[0] = IE   — never raised here
//     flags[1] = DE   — never raised here
//     flags[2] = ZE   — never raised here (no division)
//     flags[3] = OE   — impossible (sub of two normals can only shrink)
//     flags[4] = UE   — TODO: cancellation can underflow to subnormal
//                       (the post-norm exponent can go ≤ 0); deferred
//                       until gen_sub_vectors emits cancellation seeds
//                       that exercise it.  For now the narrow oracle
//                       avoids it and we leave the bit at 0.
//     flags[5] = PE   — round_bit | sticky was nonzero
//
// Reference: subFloatx80Sigs() at sim/testfloat/softfloat/softfloat.cc:3123
// plus normalizeRoundAndPackFloatx80() at softfloat-round-pack.cc:753.
//
// Validation: sim/testfloat/gen_sub_vectors generates (a, b, expected_z)
// tuples via the vendored Bochs oracle; sim/modelsim/execute_fpu_tb.v
// (PR-2b.3a phase) drives them through this module by issuing
// CMDEX_FSUB_ST0_STi with same-sign operands and compares writeback.

`timescale 1ns / 1ps

module softfloat_sub_x80 (
    input  wire [79:0] a,
    input  wire [79:0] b,
    input  wire        z_sign_in,
    input  wire [1:0]  precision,   // PR-2b.5u: PC = CW[9:8]; 11/01 = extended (inline)
    input  wire [1:0]  rc,          // PR-2b.5v: RC = CW[11:10]; 00=RNE (inline path)
    // PR-2c.1 (iter 156): rounder hoisted to shared instance in execute_fpu.v.
    output wire        pr_sign,
    output wire signed [16:0] pr_exp,
    output wire [63:0] pr_sig0,
    output wire [63:0] pr_sig1,
    input  wire [79:0] shared_round_z,
    input  wire [5:0]  shared_round_flags,
    output wire [79:0] z,
    output wire [5:0]  flags        // {PE, UE, OE, ZE, DE, IE}
);

    //--------------------------------------------------------------------
    // PR-2b.3f: NaN propagation override.  Identical to softfloat_add_x80's
    // override — when either input is NaN, emit a propagated QNaN with
    // IE if any input was SNaN.  See floatx80_nan_handle.v.
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
    // PR-2b.3g: Inf override.  Per-op cases:
    //   both Inf      : This primitive is consumed when the operation is
    //                   a MAGNITUDE SUBTRACT (FSUB same-sign or FADD
    //                   diff-sign).  In both routes, both-Inf at the
    //                   operand level is mathematically Inf-Inf, which
    //                   is INVALID — produces QNaN_INDEFINITE + IE.
    //                   (Valid same-sign Inf+Inf and diff-sign FSUB-of-
    //                   opposite-Infs both route to the ADD primitive
    //                   via the dispatcher.)
    //   only a is Inf : result is z_sign_in Inf (caller passes a.sign;
    //                   this is the correct sign for FSUB(Inf, finite)
    //                   and for FADD-diff-sign(Inf-large, finite)).
    //   only b is Inf : result is ~z_sign_in Inf — flipping because
    //                   subtracting Inf reverses the sign.  Correct for
    //                   FSUB(finite, Inf) → -sign-of-Inf and for
    //                   FADD-diff-sign(finite, -Inf) → -Inf.
    // QNaN_INDEFINITE = {1, 7FFF, C000_0000_0000_0000} (Bochs default-nan).
    //--------------------------------------------------------------------
    wire is_inf_a, is_inf_b, is_any_inf;
    floatx80_inf_handle u_inf (
        .a          (a),
        .b          (b),
        .is_inf_a   (is_inf_a),
        .is_inf_b   (is_inf_b),
        .is_any_inf (is_any_inf)
    );
    wire both_inf   = is_inf_a & is_inf_b;
    wire only_b_inf = is_inf_b & ~is_inf_a;
    wire z_sign_inf = only_b_inf ? ~z_sign_in : z_sign_in;
    wire [79:0] z_inf     = both_inf
                          ? {1'b1, 15'h7FFF, 64'hC000000000000000}
                          : {z_sign_inf, 15'h7FFF, 64'h8000000000000000};
    wire [5:0]  flags_inf = both_inf ? 6'b000001 : 6'd0;

    //--------------------------------------------------------------------
    // PR-2b.3i (cut 1, iter 38): denormal detection + DE flag.
    // OR'd into flags_normal at the bottom; doesn't affect z encoding.
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
    // PR-2b.3i (cut 2, iter 40): normalize denormal inputs so the
    // existing magnitude-subtract arith produces an IEEE-correct result.
    // Same wrapper as softfloat_add_x80; sign bits are unused here
    // because the caller's z_sign_in controls the algebraic sign.
    //--------------------------------------------------------------------
    wire               a_sign_unused;
    wire signed [16:0] a_exp_s;
    wire        [63:0] a_sig;
    floatx80_normalize u_norm_a (
        .a        (a),
        .sign_out (a_sign_unused),
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

    //--------------------------------------------------------------------
    // Pick the bigger magnitude as "big".  For different exp, the larger
    // exp wins.  For equal exp, the larger significand wins.  If both are
    // identical the result is exact zero (handled at the end).
    //--------------------------------------------------------------------
    wire        a_bigger_exp = (a_exp_s > b_exp_s);
    wire        same_exp     = (a_exp_s == b_exp_s);
    wire        a_bigger_sig = (a_sig >= b_sig);   // equality folds to "a is big"
    wire        sigs_equal   = (a_sig == b_sig);

    wire pick_a_as_big = a_bigger_exp || (same_exp && a_bigger_sig);

    wire        [63:0] sig_big    = pick_a_as_big ? a_sig : b_sig;
    wire        [63:0] sig_small  = pick_a_as_big ? b_sig : a_sig;
    wire signed [16:0] z_exp_base = pick_a_as_big ? a_exp_s : b_exp_s;

    wire signed [16:0] diff_a_b   = a_exp_s - b_exp_s;
    wire signed [16:0] diff_b_a   = b_exp_s - a_exp_s;
    wire        [14:0] count      = a_bigger_exp ? diff_a_b[14:0] :
                                    same_exp     ? 15'd0          :
                                                   diff_b_a[14:0];

    // z_sign starts as z_sign_in; flips if we ended up picking b as big.
    wire z_sign_main = z_sign_in ^ (~pick_a_as_big);

    //--------------------------------------------------------------------
    // Right-shift sig_small by `count` with jamming (same pattern as
    // softfloat_add_x80).
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
            sm_shifted = sig_small >> count[5:0];
            sm_extra   = sig_small << (6'd64 - count[5:0]);
        end
        else if (count == 15'd64) begin
            sm_shifted = 64'd0;
            sm_extra   = sig_small;
        end
        else begin
            sm_shifted = 64'd0;
            sm_extra   = {63'd0, |sig_small};
        end
    end
    // verilator lint_on WIDTH

    //--------------------------------------------------------------------
    // 128-bit subtract: {sig_big, 64'd0} - {sm_shifted, sm_extra}.
    //
    // The borrow from the low 64 bits propagates into the high 64; we let
    // Verilog's wider arithmetic handle it.  The top bit of the 129-bit
    // result is guaranteed to be 0 because |sig_big.0| > |sm_shifted.sm_extra|
    // for any non-equal pair after the magnitude pick above.
    //--------------------------------------------------------------------
    wire [127:0] sub_full = {sig_big, 64'd0} - {sm_shifted, sm_extra};
    wire [63:0]  zs0_raw  = sub_full[127:64];
    wire [63:0]  zs1_raw  = sub_full[63:0];

    //--------------------------------------------------------------------
    // Normalize: if zs0_raw is all zero, the J-bit must come from zs1_raw
    // (shift left by 64 conceptually); decrement exp by 64.  Then count
    // leading zeros of the high word and shift-left by that many bits.
    //--------------------------------------------------------------------
    wire               zero_high      = (zs0_raw == 64'd0);
    wire        [63:0] norm_in_hi     = zero_high ? zs1_raw : zs0_raw;
    wire        [63:0] norm_in_lo     = zero_high ? 64'd0   : zs1_raw;
    wire signed [16:0] z_exp_after_zh = zero_high ? (z_exp_base - 17'sd64) : z_exp_base;

    // countLeadingZeros64 of norm_in_hi.  Output 0..63 for the index of
    // the highest set bit (counted from MSB); 64 if input is all zero.
    // We iterate ascending and overwrite, so the highest set bit (i.e.
    // the LAST iteration that writes) wins.
    reg [6:0] clz;
    integer ci;
    always @* begin
        clz = 7'd64;
        for (ci = 0; ci < 64; ci = ci + 1) begin
            if (norm_in_hi[ci]) clz = 7'd63 - ci[5:0];
        end
    end

    // shortShift128Left by clz.  clz is in [0, 64); the 128-bit shift can
    // freely use clz[6:0] without masking.
    wire [127:0] concat_in  = {norm_in_hi, norm_in_lo};
    // verilator lint_off WIDTH
    wire [127:0] concat_out = concat_in << clz;
    // verilator lint_on WIDTH
    wire [63:0]  zs0_norm   = concat_out[127:64];
    wire [63:0]  zs1_norm   = concat_out[63:0];

    wire signed [16:0] z_exp_norm = z_exp_after_zh - $signed({10'd0, clz});

    //--------------------------------------------------------------------
    // Round to nearest even — same expression as softfloat_add_x80.
    //--------------------------------------------------------------------
    wire round_bit = zs1_norm[63];
    wire sticky    = |zs1_norm[62:0];
    wire ulp_low   = zs0_norm[0];
    wire round_up  = round_bit & (sticky | ulp_low);

    wire [64:0] zs0_rnd_full = {1'b0, zs0_norm} + {64'd0, round_up};
    wire        rnd_carry    = zs0_rnd_full[64];
    wire [63:0] zs0_final    = rnd_carry ? 64'h8000000000000000
                                         : zs0_rnd_full[63:0];
    wire signed [16:0] z_exp_final = rnd_carry ? (z_exp_norm + 17'sd1) : z_exp_norm;

    //--------------------------------------------------------------------
    // Cancellation-to-zero override.  When same_exp && sigs_equal, the
    // subtract is exact 0; Bochs returns packFloatx80(0, 0, 0) under RTNE
    // (the `float_round_down` arm at softfloat.cc:3192 isn't taken here).
    //--------------------------------------------------------------------
    wire result_zero = same_exp && sigs_equal;

    //--------------------------------------------------------------------
    // PR-2b.3i cut 3 (iter 41): subnormal-result encoding.  When the
    // post-cancellation exp goes non-positive on a non-zero result,
    // route through floatx80_pack_subn (shared with add/mul/div).  Feeds
    // UNROUNDED (zs0_norm, zs1_norm) and z_exp_norm — the helper does
    // its own shift + jam + re-round on the post-shift sig pair.
    //--------------------------------------------------------------------
    wire ue_now = (z_exp_final <= $signed(17'sd0)) && ~result_zero &&
                  (zs0_final != 64'd0);

    wire [79:0] z_subn;
    wire        pe_subn;
    floatx80_pack_subn u_pack_subn (
        .sign      (z_sign_main),
        .z_exp_pre (z_exp_norm),
        .sig_hi    (zs0_norm),
        .sig_lo    (zs1_norm),
        .z_subn    (z_subn),
        .pe_subn   (pe_subn)
    );

    wire        z_sign_out  = result_zero ? 1'b0  : z_sign_main;
    wire [14:0] z_exp_pack  = z_exp_final[14:0];
    wire [14:0] z_exp_out   = result_zero ? 15'd0 : z_exp_pack;
    wire [63:0] z_sig_out   = result_zero ? 64'd0 : zs0_final;

    wire [79:0] z_normal_pre = {z_sign_out, z_exp_out, z_sig_out};
    wire [79:0] z_normal    = ue_now ? z_subn : z_normal_pre;

    //--------------------------------------------------------------------
    // Flag outputs.  See header for the bit layout.  PE trips on any
    // dropped round/sticky, suppressed for the exact-zero case.  UE
    // (PR-2b.3i cut 2, iter 40) trips when the post-cancellation exp goes
    // non-positive on a non-zero result — the matching exception to the
    // FADD/FMUL OE case.  Magnitude-subtract can't produce OE so bit [3]
    // remains hard-zero.  When UE fires the PE bit tracks the helper's
    // post-shift re-round (pe_subn) instead of the original round/sticky.
    //--------------------------------------------------------------------
    wire pe_combined = ue_now ? pe_subn
                              : ((round_bit | sticky) & ~result_zero);

    wire [5:0]  flags_normal = { pe_combined,                         // [5] PE
                                 ue_now,                              // [4] UE
                                 1'b0,                                // [3] OE
                                 3'b000 };                            // [2:0] ZE/DE/IE

    // PR-2b.3i: OR DE into the normal-path flags when any input is
    // denormal.  Doesn't enter the override cascade arms.
    wire [5:0]  flags_normal_w_de = flags_normal | {4'd0, is_any_subn, 1'd0};

    //--------------------------------------------------------------------
    // PR-2b.5u (iter 139): precision-control (PC = CW[9:8]) narrowing.
    // Same shared rounder, fed the UNROUNDED (z_sign_main, z_exp_norm,
    // zs0_norm, zs1_norm) — the exact triple this primitive's inline
    // rounder and floatx80_pack_subn already consume.  Gated on
    // ~result_zero: an exact cancellation is already +0 and must keep its
    // forced-positive zero encoding (not be re-rounded by the helper).
    //--------------------------------------------------------------------
    // PR-2b.5v (iter 150): directed rounding (RC = CW[11:10]).  RC-aware
    // rounder replaces the PC helper (byte-identical for rc=00, Slice 1).
    // do_round preserves the ~result_zero gate (an exact cancellation stays
    // forced-positive +0) and ORs the directed condition into the narrow-PC
    // condition.  rc=00 & PC=80 → do_round=0 → inline z_normal (zero
    // regression).
    wire        is_pc_narrow = (precision == 2'b00) || (precision == 2'b10);
    wire        do_round     = (is_pc_narrow || (rc != 2'b00)) && ~result_zero;
    // PR-2c.1 (iter 156): export pre-rounder triple; shared rounder in execute_fpu.v.
    assign pr_sign = z_sign_main;
    assign pr_exp  = z_exp_norm;
    assign pr_sig0 = zs0_norm;
    assign pr_sig1 = zs1_norm;
    wire [79:0] z_pc     = shared_round_z;
    wire [5:0]  flags_pc = shared_round_flags;
    wire [79:0] z_normal_pc     = do_round ? z_pc : z_normal;
    wire [5:0]  flags_normal_pc = do_round
                                ? (flags_pc | {4'd0, is_any_subn, 1'd0})
                                : flags_normal_w_de;

    // Override cascade: NaN > Inf > normal(+DE if denormal input).
    assign z     = is_any_nan ? z_nan
                 : is_any_inf ? z_inf
                              : z_normal_pc;
    assign flags = is_any_nan ? flags_nan
                 : is_any_inf ? flags_inf
                              : flags_normal_pc;

endmodule
