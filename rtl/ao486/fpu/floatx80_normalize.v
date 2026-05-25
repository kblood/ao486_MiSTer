// floatx80_normalize.v
//
// PR-2b.3i (cut 2, iter 40): shared subnormal-normalize helper used by all
// four arith primitives.  Companion to floatx80_subn_handle.v (cut 1,
// iter 38) which only detected denormals and OR'd the DE flag; this cut
// actually normalizes the value so the existing normal-arithmetic path
// produces an IEEE-correct result (modulo subnormal-output encoding,
// which remains a future iter — see header notes in each primitive).
//
// Bochs reference (sim/testfloat/softfloat/softfloat.cc:172
// normalizeFloatx80Subnormal):
//
//   void normalizeFloatx80Subnormal(Bit64u aSig, Bit16s *zExpPtr,
//                                   Bit64u *zSigPtr)
//   {
//       int shiftCount = countLeadingZeros64(aSig);
//       *zSigPtr = aSig << shiftCount;
//       *zExpPtr = 1 - shiftCount;       // signed; ranges from -62..0
//   }
//
// IEEE floatx80 denormal encoding (Intel SDM Vol 1 §4.8.3.2):
//   bit 79      : sign
//   bit 78:64   : biased exponent (all zeros for denormals)
//   bit 63      : explicit J-bit (zero for denormals)
//   bit 62:0    : fraction (NOT all zeros — that would be ±0)
//
// Mathematical value of a denormal := frac × 2^(1-bias)  (where frac is
// the 64-bit value with implied binary point before the MSB).  After
// normalization, the J-bit (bit 63 of sig_out) is forced to 1 by the
// shift, and the biased exponent is reinterpreted as a signed 17-bit
// value in the range [1-63, 1-1] = [-62, 0].
//
// Pass-through rule for non-denormal inputs:
//   - Normal     (exp in [1, 0x7FFE]) : sig_out = a_sig (J-bit already 1);
//                                        exp_out = $signed({2'b00, a_exp}).
//   - Zero       (exp==0, sig==0)     : sig_out = 0, exp_out = 0.
//   - NaN / Inf  (exp==0x7FFF)        : passed through; the caller's
//                                        NaN/Inf cascade short-circuits
//                                        before the normalized values
//                                        are consumed by the normal path.
//
// Scope:
//   This module is a pure combinational helper.  Its outputs are only
//   used downstream when none of the {NaN, Inf, Zero} cascade arms in
//   the parent primitive fires (i.e. on the normal-arith path).  Inputs
//   that don't satisfy "is_subn" pass through unchanged.

`timescale 1ns / 1ps

module floatx80_normalize (
    input  wire        [79:0] a,

    output wire               sign_out,
    output wire signed [16:0] exp_out,
    output wire        [63:0] sig_out
);

    wire        a_sign = a[79];
    wire [14:0] a_exp  = a[78:64];
    wire [63:0] a_sig  = a[63:0];

    wire is_subn = (a_exp == 15'd0) && (a_sig != 64'd0);

    // countLeadingZeros64(a_sig).  Output 0..63 for the index of the
    // highest set bit (counted from MSB); 64 if input is all zero.  Same
    // ascending-overwrite pattern used by softfloat_sub_x80's clz block.
    reg [6:0] clz;
    integer ci;
    always @* begin
        clz = 7'd64;
        for (ci = 0; ci < 64; ci = ci + 1) begin
            if (a_sig[ci]) clz = 7'd63 - ci[5:0];
        end
    end

    // shortShift64Left: clz is in [0, 64) when is_subn (a_sig != 0).  Use
    // the low 6 bits to feed the 64-bit shifter.
    wire [63:0] sig_norm = a_sig << clz[5:0];

    // exp_norm = 1 - clz, in 17-bit signed.  Range: [1-63, 1-1] = [-62, 0]
    // for is_subn inputs.
    wire signed [16:0] exp_norm = $signed(17'sd1) - $signed({10'd0, clz});

    assign sign_out = a_sign;
    assign exp_out  = is_subn ? exp_norm : $signed({2'b00, a_exp});
    assign sig_out  = is_subn ? sig_norm : a_sig;

endmodule
