// floatx80_nan_handle.v
//
// PR-2b.3f: shared NaN classifier + propagator used by all four arith
// primitives (softfloat_{add,sub,mul,div}_x80).  Implements the input-
// NaN path of Bochs' propagateFloatx80NaN at softfloat-specialize.cc:
//
//   * Classify each operand: floatx80_is_nan() == (exp[14:0] == 0x7FFF
//     && fraction[62:0] != 0).  Note the J-bit (a[63]) is NOT inspected —
//     pseudo-NaN/Inf with J=0 + exp=7FFF are unsupported encodings;
//     Bochs treats them as NaN for propagation purposes.
//   * SNaN vs QNaN: the QNaN bit is fraction[62] (bit 62 of the 80-bit
//     word, i.e. the MSB of the fraction field).  SNaN => bit 62 = 0;
//     QNaN => bit 62 = 1.
//   * Propagation: if both inputs are NaN, return the one with the
//     larger fraction[62:0] (lexicographic tiebreak per Bochs).  If only
//     one input is NaN, return it.  Force the QNaN bit (bit 62) to 1 on
//     the output so an SNaN input emerges as QNaN.
//   * Flags: bit 0 (IE) set if either input was SNaN.  All other flag
//     bits are 0 (the caller's normal-path flags are discarded when
//     is_any_nan is high; see the override mux in each primitive).
//
// What this module does NOT handle:
//   * Inf operands (Inf+Inf same-sign should pass through as Inf without
//     touching this module; Inf-Inf is an invalid op that produces the
//     QNaN floating-point indefinite — those are per-op cases and live
//     in the per-primitive special-case prologue, not here).
//   * 0 * Inf, 0/0, Inf/Inf — same reason as above (invalid-op QNaN
//     indefinite, op-specific).
//   * Denormal operands (the DE flag + denormal-to-normal conversion is
//     orthogonal to NaN propagation and gets its own iter).
//
// In short: this module ONLY handles input-NaN propagation.  The wrapper
// primitive selects (z_normal, flags_normal) when is_any_nan=0 and
// (z_nan, flags_nan) when is_any_nan=1.  Iter 36+ will extend the
// per-primitive prologue with Inf/Zero/Denormal logic.
//
// Bit layout (Intel SDM Vol 1 §8.1.2):
//   a[79]     = sign
//   a[78:64]  = biased exponent (15 bits)
//   a[63]     = explicit J-bit (1 for normals; ignored here)
//   a[62]     = QNaN-indicator bit (1 = QNaN, 0 = SNaN when exp=7FFF)
//   a[62:0]   = fraction field (the QNaN bit is the MSB of this field)
//
// Reference: propagateFloatx80NaN() in vendored Bochs softfloat at
// sim/testfloat/softfloat/softfloat-specialize.cc.

`timescale 1ns / 1ps

module floatx80_nan_handle (
    input  wire [79:0] a,
    input  wire [79:0] b,

    output wire        is_nan_a,
    output wire        is_nan_b,
    output wire        is_any_nan,     // top-level "use z_nan/flags_nan" gate
    output wire        is_any_snan,    // sets flags_nan[0] (IE)

    output wire [79:0] z_nan,
    output wire [5:0]  flags_nan       // only bit 0 (IE) can be set here
);

    //--------------------------------------------------------------------
    // Classifier.
    //
    // NaN = exp all-ones AND fraction[62:0] nonzero.  An exp of 7FFF
    // with a zero fraction is +/-Inf, which we deliberately do NOT
    // catch here (Inf handling is per-op and lives in the wrapper).
    //--------------------------------------------------------------------
    wire a_exp_max  = (a[78:64] == 15'h7FFF);
    wire b_exp_max  = (b[78:64] == 15'h7FFF);
    wire a_frac_nz  = |a[62:0];
    wire b_frac_nz  = |b[62:0];

    assign is_nan_a = a_exp_max & a_frac_nz;
    assign is_nan_b = b_exp_max & b_frac_nz;

    // SNaN: NaN with the QNaN-indicator (bit 62) clear.
    wire   is_snan_a = is_nan_a & ~a[62];
    wire   is_snan_b = is_nan_b & ~b[62];

    assign is_any_nan  = is_nan_a  | is_nan_b;
    assign is_any_snan = is_snan_a | is_snan_b;

    //--------------------------------------------------------------------
    // Propagation.
    //
    //   Both NaN  : pick the operand with larger fraction[62:0].
    //   Only a NaN: pick a.
    //   Only b NaN: pick b.
    //
    // The `pick_b` wire collapses these three cases.  When neither is
    // NaN, the output is irrelevant (the wrapper's override mux will
    // pick z_normal); we still drive a deterministic value (a) to keep
    // synthesis happy and avoid X-propagation in sim.
    //--------------------------------------------------------------------
    wire pick_b = (is_nan_a & is_nan_b & (b[62:0] > a[62:0]))   // both: b wins on larger fraction
                | (is_nan_b & ~is_nan_a);                       // only b NaN

    wire [79:0] chosen = pick_b ? b : a;

    // Force the QNaN bit (bit 62) to 1 — converts an SNaN input to QNaN
    // on the way out, leaves a QNaN input unchanged.
    assign z_nan = { chosen[79:63], 1'b1, chosen[61:0] };

    // Only IE can fire from this module.  PE/UE/OE/ZE/DE belong to the
    // normal-path computation, which is discarded when is_any_nan=1.
    assign flags_nan = { 5'd0, is_any_snan };

endmodule
