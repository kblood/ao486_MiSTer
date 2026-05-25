// floatx80_zero_handle.v
//
// PR-2b.3h: shared signed-zero classifier used by add / mul / div arith
// primitives (the sub primitive's existing `result_zero` cancellation
// path already handles all zero cases it can see, so sub does NOT need
// this module).  Companion to floatx80_nan_handle.v (iter 35) and
// floatx80_inf_handle.v (iter 36).
//
// Why a classifier-only module:
//   Like Inf rules, signed-zero rules are PER-OP — FADD same-sign
//   preserves the shared sign; FMUL / FDIV apply sign-XOR; FSUB diff-
//   sign goes to the ADD primitive where the dispatcher already routes
//   the sign correctly.  Sharing the classifier (single source for the
//   IEEE +/-0 encoding definition) gives one place to look for "is this
//   operand a zero?", and each primitive open-codes its own per-op
//   propagator using the classifier outputs.
//
// IEEE +/-0 encoding (Intel SDM Vol 1 §4.8.3.1):
//   bit 79      : sign (0 = +0, 1 = -0)
//   bit 78:64   : biased exponent (all zeros)
//   bit 63      : explicit J-bit (zero for +/-0)
//   bit 62:0    : fraction (all zeros)
//   Total: zero is encoded when exp == 0 AND fraction-including-J == 0.
//
//   Note this differs from NaN (exp == 7FFF AND fraction[62:0] != 0)
//   and from Inf (exp == 7FFF AND fraction[62:0] == 0) — the three
//   classifiers form a mutually exclusive partition of the "special"
//   encodings.  Denormals (exp == 0 AND fraction != 0) get their own
//   future classifier when PR-2b.3i lands.
//
// Reference: Bochs floatx80_class() at softfloat-specialize.cc returns
// `float_zero` for this case.

`timescale 1ns / 1ps

module floatx80_zero_handle (
    input  wire [79:0] a,
    input  wire [79:0] b,

    output wire        is_zero_a,
    output wire        is_zero_b,
    output wire        is_any_zero
);

    assign is_zero_a   = (a[78:64] == 15'd0) && (a[63:0] == 64'd0);
    assign is_zero_b   = (b[78:64] == 15'd0) && (b[63:0] == 64'd0);
    assign is_any_zero = is_zero_a | is_zero_b;

endmodule
