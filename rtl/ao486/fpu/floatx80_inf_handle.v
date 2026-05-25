// floatx80_inf_handle.v
//
// PR-2b.3g: shared Inf classifier used by all four arith primitives
// (softfloat_{add,sub,mul,div}_x80).  Companion to floatx80_nan_handle.v.
//
// Why a classifier-only module (no propagation):
//   NaN propagation is uniform across the four ops (Bochs
//   propagateFloatx80NaN runs identically regardless of opcode), so
//   floatx80_nan_handle owns the propagator.  Inf rules are PER-OP:
//     FADD: Inf+Inf same-sign → Inf; Inf-Inf goes to the sub primitive
//           via dispatcher and is invalid there.
//     FSUB: only-a Inf → Inf with z_sign_in; only-b Inf → Inf with
//           flipped z_sign_in; both Inf (same sign in this primitive's
//           contract) → QNaN_INDEFINITE + IE.
//     FMUL: 0*Inf or Inf*0 → QNaN_INDEFINITE + IE; otherwise Inf with
//           sign-XOR.
//     FDIV: Inf/Inf → QNaN_INDEFINITE + IE; Inf/finite → Inf (sign-XOR);
//           finite/Inf → ±0 (sign-XOR).  Inf path takes precedence over
//           the existing b=0 ZE special-case (Inf/0 = Inf with no ZE).
//   So this module only emits classification bits (is_inf_a, is_inf_b,
//   is_any_inf) and each primitive open-codes its own per-op rule using
//   those bits + the local QNaN_INDEFINITE constant.
//
// Inf detection: exp == 0x7FFF AND fraction[62:0] == 0.  Contrast with
// NaN: same exp but fraction[62:0] != 0.  The classifier-pair is
// mutually exclusive (an operand is either NaN or Inf or normal — never
// both NaN and Inf).
//
// Bit layout (Intel SDM Vol 1 §8.1.2):
//   a[79]    = sign
//   a[78:64] = biased exponent (15 bits; 0x7FFF = max)
//   a[63]    = explicit J-bit
//   a[62:0]  = fraction
//
// Reference: Bochs softfloat_class() at softfloat-specialize.cc; the Inf
// classification path is `expClass = floatx80_class(...)` returning
// `float_pinf` / `float_ninf`.

`timescale 1ns / 1ps

module floatx80_inf_handle (
    input  wire [79:0] a,
    input  wire [79:0] b,

    output wire        is_inf_a,
    output wire        is_inf_b,
    output wire        is_any_inf
);

    wire a_exp_max = (a[78:64] == 15'h7FFF);
    wire b_exp_max = (b[78:64] == 15'h7FFF);
    wire a_frac_z  = ~|a[62:0];
    wire b_frac_z  = ~|b[62:0];

    assign is_inf_a   = a_exp_max & a_frac_z;
    assign is_inf_b   = b_exp_max & b_frac_z;
    assign is_any_inf = is_inf_a | is_inf_b;

endmodule
