// floatx80_subn_handle.v
//
// PR-2b.3i (cut 1, iter 38): shared denormal (subnormal) classifier used
// by all four arith primitives.  Companion to floatx80_nan_handle.v
// (iter 35), floatx80_inf_handle.v (iter 36), and floatx80_zero_handle.v
// (iter 37).
//
// Why a classifier-only module:
//   Per Bochs softfloatx80 (softfloatx80.cc:162/174/181-182 + softfloat-
//   round-pack.cc:537), the DE flag is raised for ANY denormal input
//   regardless of opcode, BEFORE normalization, and INDEPENDENT of the
//   DE-mask bit in the control word (the mask gates trapping, not the
//   flag bit).  So all primitives share the same one-line rule:
//     flags[1] (DE) := flags[1] | is_any_subn
//   and there's no per-op variant to factor in.  This module exposes
//   only the classifier outputs; each primitive ORs the DE bit into its
//   own flags_normal at the very end of its z/flags cascade.
//
// IEEE floatx80 denormal encoding (Intel SDM Vol 1 §4.8.3.2):
//   bit 79      : sign
//   bit 78:64   : biased exponent (all zeros)
//   bit 63      : explicit J-bit (zero for denormals)
//   bit 62:0    : fraction (NOT all zeros — that would be ±0)
//   So denormal := (exp == 0) && (fraction-including-J != 0).
//
//   This is mutually exclusive with the other three classes:
//     - zero    : exp == 0 AND frac == 0
//     - normal  : exp in [0x0001, 0x7FFE] AND J-bit == 1
//     - special : exp == 0x7FFF (NaN if frac[62:0] != 0, Inf if == 0)
//   The four classifiers (subn / zero / nan / inf) form a partition of
//   the encoding space — at most one fires per operand.
//
// Note: iter-38 ships ONLY the DE-flag generation; the actual
// normalize+compute step (which would let denormal-normal arithmetic
// produce IEEE-correct results) is deferred to iter 39+ because it
// requires extending the primitives' internal exp math from 15-bit
// unsigned to 17-bit signed (post-normalization denormal exp can be
// as low as -62).  Until iter 39 lands, denormal inputs will fall
// through each primitive's z_normal path and produce an approximation
// (the existing logic treats the missing J-bit as a zero leading bit,
// which is sometimes close, sometimes not) — but the DE flag will
// correctly fire so software exception handlers see the event.
//
// Reference:
//   Bochs floatx80_class(softfloatx80.cc:212-223): returns
//   `float_denormal` for this case.
//   Bochs float_raise(status, float_flag_denormal): called inline at
//   each op's entry point when a denormal input is detected
//   (softfloatx80.cc:162 for floatx80_add, line 174 for floatx80_sub,
//   etc.).

`timescale 1ns / 1ps

module floatx80_subn_handle (
    input  wire [79:0] a,
    input  wire [79:0] b,

    output wire        is_subn_a,
    output wire        is_subn_b,
    output wire        is_any_subn
);

    assign is_subn_a   = (a[78:64] == 15'd0) && (a[63:0] != 64'd0);
    assign is_subn_b   = (b[78:64] == 15'd0) && (b[63:0] != 64'd0);
    assign is_any_subn = is_subn_a | is_subn_b;

endmodule
