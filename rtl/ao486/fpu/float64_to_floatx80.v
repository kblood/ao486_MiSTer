// PR-2b.4c (iter 54): double-precision (m64fp) → floatx80 converter.
//
// Pure-combinational port of Bochs softfloat
// `sim/testfloat/softfloat/softfloat.cc:float64_to_floatx80`
// (lines 2693-2711 of the vendored copy).  Mirrors the layout of
// `float32_to_floatx80.v` from PR-2b.4b; same rules, different bit widths.
//
// IEEE 754 double: {sign[63], exp[62:52], frac[51:0]}, bias 1023, J-bit implicit.
// IEEE 754 extended: {sign[79], exp[78:64], frac[63:0]}, bias 16383, J-bit at frac[63].
//
// Conversion rules (Bochs):
//   * NaN/Inf (aExp==0x7FF):
//       aSig==0 → ±Inf; aSig!=0 → NaN (SNaN-vs-QNaN preserved via aSig[51]).
//   * Zero: {sign, 15'd0, 64'd0}.
//   * Denormal: normalize inline (clz52 + shift); biased x80 exp =
//       (1 - shift) + 0x3C00 (bias 1023 → 16383, delta 0x3C00=15360).  All
//       f64 denormals fit comfortably inside x80 normal range — exp ∈
//       [-1074,-1023] maps to x80 biased [0x3BCD..0x3C00].  DE flag emitted.
//   * Normal: biased x80 exp = aExp + 0x3C00; sig = (J||aSig) << 11
//       (positions J at bit 63, payload at bits 62..11, low 11 zero).
//
// `de` is asserted on denormal input; `ie` is asserted on SNaN input.  Both
// match Bochs `commonNaNToFloatx80` semantics (SNaN silenced to QNaN +
// invalid raised).  Caller's execute_fpu ORs them into flags_lat at
// S_COMPUTE (PR-2b.4d+).

module float64_to_floatx80 (
    input  wire [63:0] a,
    output wire [79:0] z,
    output wire        de,
    output wire        ie
);

    wire         aSign   = a[63];
    wire [10:0]  aExp_in = a[62:52];
    wire [51:0]  aSig_in = a[51:0];

    wire is_inf_or_nan = (aExp_in == 11'h7FF);
    wire is_nan        = is_inf_or_nan && (aSig_in != 52'd0);
    wire is_snan       = is_nan && (aSig_in[51] == 1'b0);
    wire is_zero       = (aExp_in == 11'd0) && (aSig_in == 52'd0);
    wire is_subn       = (aExp_in == 11'd0) && (aSig_in != 52'd0);

    // ---- denormal normalize via 6-stage barrel-style clz52 --------------
    // For a denormal, aSig != 0 so a leading 1 always exists in [51:0].
    // The 6-stage cascade folds the leading-zero count without writing out
    // a 52-way casez (which would inflate the source by 50+ lines without
    // changing the synth output materially).
    wire [51:0] s_in = aSig_in;
    // Stage 1: top 32 zero? shift left 32.
    wire [51:0] s1 = (s_in[51:20] == 32'd0) ? (s_in << 32) : s_in;
    wire [5:0]  c1 = (s_in[51:20] == 32'd0) ? 6'd32       : 6'd0;
    // Stage 2: top 16 of s1 zero (look at s1[51:36])? shift 16.
    wire [51:0] s2 = (s1[51:36] == 16'd0) ? (s1 << 16) : s1;
    wire [5:0]  c2 = (s1[51:36] == 16'd0) ? c1 + 6'd16 : c1;
    // Stage 3: top 8 of s2 zero?  shift 8.
    wire [51:0] s3 = (s2[51:44] == 8'd0) ? (s2 << 8) : s2;
    wire [5:0]  c3 = (s2[51:44] == 8'd0) ? c2 + 6'd8 : c2;
    // Stage 4: top 4 of s3 zero?  shift 4.
    wire [51:0] s4 = (s3[51:48] == 4'd0) ? (s3 << 4) : s3;
    wire [5:0]  c4 = (s3[51:48] == 4'd0) ? c3 + 6'd4 : c3;
    // Stage 5: top 2 of s4 zero?  shift 2.
    wire [51:0] s5 = (s4[51:50] == 2'd0) ? (s4 << 2) : s4;
    wire [5:0]  c5 = (s4[51:50] == 2'd0) ? c4 + 6'd2 : c4;
    // Stage 6: bit 51 zero?  shift 1.
    wire [51:0] s6 = (s5[51] == 1'b0) ? (s5 << 1) : s5;
    wire [5:0]  c6 = (s5[51] == 1'b0) ? c5 + 6'd1 : c5;
    // After stage 6: s6[51] == 1, c6 == count of leading zeros of original s_in (in 52-bit field).

    wire [5:0]  clz52     = c6;
    // After (clz52+1) left-shifts, the original leading 1 lands at position
    // 52 (J-bit slot, conceptually); the 52-bit fraction we keep is
    // aSig_in << (clz52 + 1), low 52 bits.  s6 has the leading 1 at bit 51
    // already; one more shift left makes the post-J fraction.
    wire [51:0] aSig_norm = s6 << 1;
    // aExp after normalize (signed): 1 - (clz52+1) = -clz52.  Range [-51..0].
    wire signed [15:0] aExp_subn = -{{10{1'b0}}, clz52};

    // ---- biased x80 exp pick --------------------------------------------
    wire signed [15:0] aExp_pre = is_subn ? aExp_subn
                                : {{5{1'b0}}, aExp_in};
    wire        [15:0] exp_sum  = aExp_pre + 16'h3C00;  // bias 1023 → 16383
    wire        [14:0] exp_out  = is_zero       ? 15'h0000
                                : is_inf_or_nan ? 15'h7FFF
                                :                 exp_sum[14:0];

    // ---- sig pick -------------------------------------------------------
    // J-bit + 52-bit post-J fraction + 11 zero bits = 64-bit x80 sig.
    // Zero forces all-zero.  NaN's QNaN-bit (frac[51]) is FORCED HIGH to
    // silence SNaN; ie output flags the silencing.
    wire [51:0] aSig_nan = aSig_in | 52'h8000000000000;  // set bit 51
    wire [51:0] aSig_use = is_subn ? aSig_norm
                         : is_nan  ? aSig_nan
                                   : aSig_in;
    wire [63:0] sig_out  = is_zero ? 64'd0
                                   : {1'b1, aSig_use, 11'd0};

    assign z  = {aSign, exp_out, sig_out};
    assign de = is_subn;
    assign ie = is_snan;

endmodule
