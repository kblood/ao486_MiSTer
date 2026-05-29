// softfloat_mul_x80.v
//
// PR-2b.3b: pure combinational softfloatx80_mul primitive — third member
// of the arith family after softfloat_add_x80 (PR-2b.2a) and
// softfloat_sub_x80 (PR-2b.3a).
//
// Scope (intentionally narrow, mirrors the add/sub cut):
//   - Normal-normal operands.  Caller guarantees both have biased exp
//     in [0x0001, 0x7FFE] and J-bit (significand[63]) = 1.
//   - Round-to-nearest-even only (CW.RC == 00, FNINIT default).
//   - Extended precision only (no FPU.PC short-circuit).
//   - No NaN / Inf / Zero / Denormal handling — caller guarantees.
//
// Algorithm (Bochs mulFloatx80Sigs, sim/testfloat/softfloat/softfloat.cc:3247
// post-special-case-prologue at line ~3300):
//
//   zSign = aSign ^ bSign
//   zExp  = aExp + bExp - 0x3FFE
//   {zSig0, zSig1} = mul64To128(aSig, bSig)        // 128-bit product
//   if (zSig0[63] == 0) {                          // top bit not set yet
//       {zSig0, zSig1} <<= 1
//       zExp -= 1
//   }
//   z = roundAndPackFloatx80(RTNE, zSign, zExp, zSig0, zSig1)
//
// Range analysis (with caller's normal-normal guarantee):
//   aSig, bSig in [2^63, 2^64) so aSig * bSig in [2^126, 2^128).
//   Therefore the 128-bit product has its top bit at position 126 or 127.
//   The single conditional shift handles both cases.
//
// Output:
//   z — final result (sign | exp | sig)
//   flags[5:0] — bit layout matches softfloat_add_x80:
//     flags[5] = PE — round_bit | sticky was nonzero
//     flags[4] = UE — TODO: zExp_final <= 0 → tiny.  Deferred (gen_mul_vectors
//                    avoids inputs that underflow; will revisit when
//                    NaN/special-case work lands in PR-2b.3e).
//     flags[3] = OE — zExp_final >= 0x7FFF → saturated
//     flags[2] = ZE — never raised (no division)
//     flags[1] = DE — never raised (caller guarantees normal-normal)
//     flags[0] = IE — never raised (no NaN/Inf input)
//
// Validation: sim/testfloat/gen_mul_vectors generates (a, b, expected_z)
// tuples via the vendored Bochs oracle; sim/modelsim/execute_fpu_tb.v
// (PR-2b.3b phase) drives them through this module by issuing
// CMDEX_FMUL_ST0_STi and compares writeback.

`timescale 1ns / 1ps

module softfloat_mul_x80 (
    input  wire [79:0] a,
    input  wire [79:0] b,
    input  wire [1:0]  precision,   // PR-2b.5u: PC = CW[9:8]; 11/01 = extended (inline)
    input  wire [1:0]  rc,          // PR-2b.5v: RC = CW[11:10]; 00=RNE (inline path)
    output wire [79:0] z,
    output wire [5:0]  flags        // {PE, UE, OE, ZE, DE, IE}
);

    //--------------------------------------------------------------------
    // PR-2b.3f: NaN propagation override.  See floatx80_nan_handle.v.
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
    // PR-2b.3g: Inf override.  Per-op rules:
    //   0 * Inf or Inf * 0 → QNaN_INDEFINITE + IE (invalid).
    //   Inf * Inf          → Inf (sign-XOR).
    //   Inf * finite       → Inf (sign-XOR).
    //   finite * Inf       → Inf (sign-XOR).
    // Zero detection uses Intel +/-0 encoding (exp=0 AND sig=0).
    //--------------------------------------------------------------------
    wire is_inf_a, is_inf_b, is_any_inf;
    floatx80_inf_handle u_inf (
        .a          (a),
        .b          (b),
        .is_inf_a   (is_inf_a),
        .is_inf_b   (is_inf_b),
        .is_any_inf (is_any_inf)
    );
    // PR-2b.3h: shared zero classifier — replaces the iter-36 local
    // is_zero_a / is_zero_b wires.  Used by both the Inf-cascade's
    // 0*Inf check AND the new Zero override below.
    wire is_zero_a, is_zero_b, is_any_zero;
    floatx80_zero_handle u_zero (
        .a           (a),
        .b           (b),
        .is_zero_a   (is_zero_a),
        .is_zero_b   (is_zero_b),
        .is_any_zero (is_any_zero)
    );
    wire inf_times_z  = (is_inf_a & is_zero_b) | (is_inf_b & is_zero_a);
    wire [79:0] z_inf     = inf_times_z
                          ? {1'b1, 15'h7FFF, 64'hC000000000000000}
                          : {a[79] ^ b[79], 15'h7FFF, 64'h8000000000000000};
    wire [5:0]  flags_inf = inf_times_z ? 6'b000001 : 6'd0;

    //--------------------------------------------------------------------
    // PR-2b.3h: Zero override.  Any zero operand (where neither input
    // is NaN or Inf — those win via higher-priority cascade entries)
    // gives a sign-XOR'd ±0 result with no flags.  Covers:
    //   0 * finite → ±0
    //   finite * 0 → ±0
    //   0 * 0      → ±0
    // (0 * Inf and Inf * 0 already produce QNaN_INDEFINITE+IE via the
    // Inf cascade above — that fires before this one and short-circuits.)
    // Without this override the normal-path exponent math underflows
    // (z_exp_pre = exp_a + exp_b - 0x3FFE goes deeply negative when one
    // operand has exp=0) and emits a bogus encoding with non-zero exp
    // bits and zero sig bits — not a valid float.
    //--------------------------------------------------------------------
    wire [79:0] z_zero     = {a[79] ^ b[79], 79'd0};
    wire [5:0]  flags_zero = 6'd0;

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
    // existing 64x64→128 multiply produces an IEEE-correct result.
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
    wire               b_sign;
    wire signed [16:0] b_exp_s;
    wire        [63:0] b_sig;
    floatx80_normalize u_norm_b (
        .a        (b),
        .sign_out (b_sign),
        .exp_out  (b_exp_s),
        .sig_out  (b_sig)
    );

    wire        z_sign = a_sign ^ b_sign;

    //--------------------------------------------------------------------
    // Exponent: zExp = aExp + bExp - 0x3FFE.  Signed 17-bit math; with
    // post-normalize denormal exps in [-62, 0] the result exp can dip
    // deeply negative for two-denormal multiplies (matched by the
    // ue_now UE-flag detector below).
    //--------------------------------------------------------------------
    wire signed [16:0] z_exp_pre = a_exp_s + b_exp_s - $signed(17'sh03FFE);

    //--------------------------------------------------------------------
    // mul64To128: full 64x64 → 128-bit unsigned multiply.  ModelSim
    // synthesises this as a single product; the FPGA backend would map
    // it to DSP blocks (this primitive isn't on a critical path so
    // pipelining can be added later if timing demands).
    //--------------------------------------------------------------------
    wire [127:0] mul_full = a_sig * b_sig;
    wire [63:0]  mul_hi   = mul_full[127:64];
    wire [63:0]  mul_lo   = mul_full[63:0];

    //--------------------------------------------------------------------
    // Normalize: if the top bit of mul_hi is 0, the product is in
    // [2^126, 2^127) — shift left by 1 and decrement zExp so the
    // significand's MSB lands at position 127.
    //--------------------------------------------------------------------
    wire        need_norm     = ~mul_hi[63];
    wire [63:0] zs0_norm      = need_norm ? {mul_hi[62:0], mul_lo[63]}     : mul_hi;
    wire [63:0] zs1_norm      = need_norm ? {mul_lo[62:0], 1'b0}           : mul_lo;
    wire signed [16:0] z_exp_norm = need_norm ? (z_exp_pre - 17'd1) : z_exp_pre;

    //--------------------------------------------------------------------
    // Round to nearest even — same expression as add/sub.
    //--------------------------------------------------------------------
    wire round_bit = zs1_norm[63];
    wire sticky    = |zs1_norm[62:0];
    wire ulp_low   = zs0_norm[0];
    wire round_up  = round_bit & (sticky | ulp_low);

    wire [64:0] zs0_rnd_full = {1'b0, zs0_norm} + {64'd0, round_up};
    wire        rnd_carry    = zs0_rnd_full[64];
    wire [63:0] zs0_final    = rnd_carry ? 64'h8000000000000000
                                         : zs0_rnd_full[63:0];
    wire signed [16:0] z_exp_final = rnd_carry ? (z_exp_norm + 17'd1) : z_exp_norm;

    //--------------------------------------------------------------------
    // Pack: truncate the 17-bit signed exp to 15 bits.  Overflow/underflow
    // are reflected in `flags` rather than encoded specially — caller
    // sees a wrapped exp value that matches the OE/UE flag.  (The +Inf
    // encoding fix is the same TODO as softfloat_add_x80's PR-2b.2c
    // header note.)
    //--------------------------------------------------------------------
    wire [14:0] z_exp_out = z_exp_final[14:0];

    //--------------------------------------------------------------------
    // Exception flags + overflow→signed-Inf encoding fix.
    //
    // PR-2b.3j (iter 39): when OE fires, emit signed Inf encoding per
    // Bochs roundAndPackFloatx80 (RTNE).  OE always pairs with PE.
    //
    // PR-2b.3i cut 2 (iter 40): UE detection — fires when z_exp_final is
    // non-positive AND the result is non-zero (matches FADD's UE rule).
    //
    // PR-2b.3i cut 3 (iter 41): subnormal-result encoding via shared
    // floatx80_pack_subn helper.  Feeds UNROUNDED (zs0_norm, zs1_norm)
    // and z_exp_norm; helper shifts the sig right by (1 - z_exp_norm)
    // with jamming and re-rounds.
    //--------------------------------------------------------------------
    wire pe_now = round_bit | sticky;
    wire oe_now = (z_exp_final >= $signed(17'sh07FFF));
    wire ue_now = (z_exp_final <= $signed(17'sd0)) && (zs0_final != 64'd0);

    wire [79:0] z_subn;
    wire        pe_subn;
    floatx80_pack_subn u_pack_subn (
        .sign      (z_sign),
        .z_exp_pre (z_exp_norm),
        .sig_hi    (zs0_norm),
        .sig_lo    (zs1_norm),
        .z_subn    (z_subn),
        .pe_subn   (pe_subn)
    );

    wire [79:0] z_normal  = oe_now
                          ? {z_sign, 15'h7FFF, 64'h8000000000000000}
                          : ue_now
                              ? z_subn
                              : {z_sign, z_exp_out, zs0_final};

    wire        pe_combined = ue_now ? pe_subn : (pe_now | oe_now);

    wire [5:0]  flags_normal = { pe_combined,      // [5] PE (forced when OE)
                                 ue_now,           // [4] UE
                                 oe_now,           // [3] OE
                                 3'b000 };         // [2:0] ZE/DE/IE

    // PR-2b.3i: OR DE into normal-path flags when any input is denormal.
    wire [5:0]  flags_normal_w_de = flags_normal | {4'd0, is_any_subn, 1'd0};

    //--------------------------------------------------------------------
    // PR-2b.5u (iter 139): precision-control (PC = CW[9:8]) narrowing.
    // Shared rounder fed the UNROUNDED (z_sign, z_exp_norm, zs0_norm,
    // zs1_norm) — the same triple this primitive's inline rounder and
    // floatx80_pack_subn consume.  No special gate (zero handled by the
    // is_any_zero cascade arm).  PC=80 keeps z_normal byte-identical.
    //--------------------------------------------------------------------
    // PR-2b.5v (iter 150): directed rounding (RC = CW[11:10]).  RC-aware
    // rounder replaces the PC helper (byte-identical for rc=00, Slice 1).
    // No special gate (zero is a separate cascade arm).  use_rounder fires
    // for any narrow PC OR any directed mode; rc=00 & PC=80 → 0 → inline
    // z_normal (zero regression).
    wire        is_pc_narrow = (precision == 2'b00) || (precision == 2'b10);
    wire        use_rounder  = is_pc_narrow || (rc != 2'b00);
    wire [79:0] z_pc;
    wire [5:0]  flags_pc;
    floatx80_round_rc u_round_rc (
        .rc         (rc),
        .precision  (precision),
        .sign       (z_sign),
        .z_exp_pre  (z_exp_norm),
        .z_sig0_pre (zs0_norm),
        .z_sig1_pre (zs1_norm),
        .z          (z_pc),
        .flags      (flags_pc)
    );
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
