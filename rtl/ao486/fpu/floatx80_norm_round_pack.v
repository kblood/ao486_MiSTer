// floatx80_norm_round_pack.v
//
// PR-2b.5r (iter 133): the `normalizeRoundAndPackFloatx80(80, ...)` helper that
// FPREM/FPREM1 (design_fprem.md §3) needs to pack the (generally un-normalized,
// possibly-wider-than-64-bit) remainder significand into a floatx80.  No prior
// op needed this: the arith primitives pack their own results inline, and the
// existing floatx80_normalize.v only normalizes a 64-bit INPUT operand's J-bit
// (it does NOT round or pack).
//
// Bochs reference (cpu/fpu/softfloat-round-pack.cc):
//   normalizeRoundAndPackFloatx80 (line 753):
//       if (zSig0 == 0) { zSig0 = zSig1; zSig1 = 0; zExp -= 64; }
//       shiftCount = countLeadingZeros64(zSig0);
//       shortShift128Left(zSig0, zSig1, shiftCount, &zSig0, &zSig1);
//       zExp -= shiftCount;
//       return roundAndPackFloatx80(80, sign, zExp, zSig0, zSig1);
//   SoftFloatRoundAndPackFloatx80, precision80 path (line 646), RNE only:
//       increment = (s64)zSig1 < 0;              // round bit = zSig1[63]
//       if (zSig1) inexact;                      // PE
//       if (increment) {
//           zSigExact = zSig0++;
//           if (zSig0 == 0) { zExp++; zSig0 = 0x8000...; }   // carry-out
//           else zSig0 &= ~(((zSig1<<1)==0) & RNE);          // tie-to-even clear
//       } else if (zSig0 == 0) zExp = 0;
//       return packFloatx80(sign, zExp, zSig0);
//
// SCOPE (Slice 1):
//   - RNE rounding only.  FPREM's final pack always uses the CW.RC field, which
//     is round-nearest-even under the FNINIT default the smoke uses; directed
//     RC pack is deferred (same staging FRNDINT used for its RC plumbing).
//   - Normal-range + exact-zero results fully implemented and unit-TB'd.
//   - Overflow (zExp >= 0x7FFE) NOT handled: FPREM remainders satisfy |r| <= |b|
//     so the exponent never overflows -- documented assumption, not a gap.
//   - Subnormal/underflow (zExp <= 0): implemented in Slice 2 (iter 136) by
//     delegating to the shared floatx80_pack_subn helper (shift64ExtraRight-
//     Jamming(1 - zExp) + RTNE re-round + min-normal carry).  UE is raised
//     unconditionally on a non-zero subnormal result, matching the four arith
//     primitives' convention; PE comes from the re-round's round|sticky.

`timescale 1ns / 1ps

module floatx80_norm_round_pack (
    input  wire               sign,
    input  wire signed [16:0] z_exp_in,   // BIASED exponent (0x3FFF == bias of 1.0)
    input  wire        [63:0] sig0_in,    // high 64 bits of the 128-bit significand
    input  wire        [63:0] sig1_in,    // low  64 bits
    output wire        [79:0] z,
    output wire               pe,         // inexact
    output wire               ue          // underflow (subnormal path -- Slice-2 stub)
);

    wire all_zero = (sig0_in == 64'd0) && (sig1_in == 64'd0);

    //--------------------------------------------------------------------
    // normalizeRoundAndPackFloatx80 prologue: pull the significand up out
    // of the low word if the high word is empty.
    //--------------------------------------------------------------------
    wire               hi_zero = (sig0_in == 64'd0);
    wire        [63:0] p_sig0  = hi_zero ? sig1_in : sig0_in;
    wire        [63:0] p_sig1  = hi_zero ? 64'd0   : sig1_in;
    wire signed [16:0] p_exp   = hi_zero ? (z_exp_in - 17'sd64) : z_exp_in;

    // countLeadingZeros64(p_sig0).  p_sig0 != 0 here (all_zero special-cased
    // below), so clz is in [0,63].  Same ascending-overwrite pattern as
    // floatx80_normalize.v:67-74.
    reg [6:0] clz;
    integer ci;
    always @* begin
        clz = 7'd64;
        for (ci = 0; ci < 64; ci = ci + 1)
            if (p_sig0[ci]) clz = 7'd63 - ci[5:0];
    end

    // shortShift128Left({p_sig0,p_sig1}, clz) -- 128-bit left shift, no
    // edge cases for clz==0..63.  After this the J-bit (bit 127) is set.
    wire [127:0] sig128      = {p_sig0, p_sig1};
    wire [127:0] sig128_norm = sig128 << clz[5:0];
    wire [63:0]  n_sig0      = sig128_norm[127:64];
    wire [63:0]  n_sig1      = sig128_norm[63:0];
    wire signed [16:0] n_exp = p_exp - $signed({10'd0, clz});

    //--------------------------------------------------------------------
    // roundAndPackFloatx80 precision-80, round-to-nearest-even.
    //--------------------------------------------------------------------
    wire        round_bit  = n_sig1[63];
    wire        sticky     = |n_sig1[62:0];
    wire        exact_half = round_bit & ~sticky;   // (zSig1<<1)==0 && round_bit
    wire        inexact    = (n_sig1 != 64'd0);

    wire [64:0] sig0_inc = {1'b0, n_sig0} + {64'd0, round_bit};
    wire        carry    = sig0_inc[64];
    // tie-to-even: on an exact half, clear the LSB after incrementing (only on
    // the non-carry path -- a carry forces 0x8000... and skips the clear).
    wire [63:0] sig0_rne = exact_half ? (sig0_inc[63:0] & ~64'd1) : sig0_inc[63:0];
    wire [63:0] sig0_fin = carry ? 64'h8000000000000000 : sig0_rne;
    wire signed [16:0] exp_fin = carry ? (n_exp + 17'sd1) : n_exp;

    //--------------------------------------------------------------------
    // Subnormal / underflow pack (PR-2b.5s, iter 136).  Trigger on the
    // PRE-round-carry exponent: Bochs roundAndPackFloatx80 enters the
    // zExp<=0 branch on the un-incremented exponent, before the normal-path
    // carry adjustment.  Delegates to the shared floatx80_pack_subn (the
    // same helper the four arith primitives use): it does the
    // shift64ExtraRightJamming(1 - zExp) + RTNE re-round + min-normal carry.
    //--------------------------------------------------------------------
    wire subn = ~all_zero && (n_exp <= $signed(17'sd0));

    wire [79:0] z_subn;
    wire        pe_subn;
    floatx80_pack_subn u_subn_pack (
        .sign      (sign),
        .z_exp_pre (n_exp),
        .sig_hi    (n_sig0),
        .sig_lo    (n_sig1),
        .z_subn    (z_subn),
        .pe_subn   (pe_subn)
    );

    //--------------------------------------------------------------------
    // Result mux: zero > subnormal > normal.
    //--------------------------------------------------------------------
    wire [79:0] z_zero   = {sign, 79'd0};
    wire [79:0] z_normal = {sign, exp_fin[14:0], sig0_fin};

    assign z  = all_zero ? z_zero : subn ? z_subn  : z_normal;
    assign pe = all_zero ? 1'b0   : subn ? pe_subn : inexact;
    assign ue = all_zero ? 1'b0   : subn;

endmodule
