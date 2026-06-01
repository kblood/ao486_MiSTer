// PR-2c.25 (iter 178): UNIFIED single/double-precision -> floatx80 widening
// converter.  Runtime-shared replacement for float32_to_floatx80.v +
// float64_to_floatx80.v.
//
// FLD m32 and FLD m64 (and the FILD-fed lanes that reuse the f32/f64 path)
// are mutually exclusive in any given S_COMPUTE cycle, so one runtime-muxed
// instance serves both widths and reclaims the duplicated 23-bit CLZ priority
// mux + the second normalize/pack datapath that the two separate modules
// carried (the iter-178 dedupe slice).
//
// BIT-EXACTNESS STRATEGY ----------------------------------------------------
// The single-precision fraction (23 bits) is LEFT-JUSTIFIED into the top of a
// 52-bit field: aSig52 = {aSig23, 29'b0}.  The double-precision datapath then
// produces byte-identical results for the f32 case because:
//   * NORMAL/NaN pack:  {1'b1, aSig52, 11'b0}
//                     = {1'b1, aSig23, 29'b0, 11'b0}
//                     = {1'b1, aSig23, 40'b0}   (== the old f32 module)
//   * The QNaN-bit f64 sets at frac[51] coincides with f32's frac[22] once
//     left-justified, so SNaN silencing + the is_snan test line up exactly.
//   * The 52-bit CLZ cascade run over {aSig23, 29'b0} returns the SAME leading
//     -zero count as the old 23-way casez (the trailing 29 zeros never hold the
//     leading 1), and aSig_norm52[51:29] == (aSig23 << (clz+1))[22:0], so the
//     normalized-denormal pack also matches bit-for-bit.
// Only the special-case DETECTION (exp-all-ones value, field widths) and the
// exponent BIAS DELTA (0x3F80 for f32, 0x3C00 for f64) are width-muxed.
//
// Proven bit-exact vs the two frozen originals by floatN_to_floatx80_tb.v
// (directed special cascade for both widths + 2x random sweeps).
//
// `a` carries the raw memory operand: low 32 bits for m32, full 64 for m64.
// `is_m64` selects the active width (= execute_fpu's mem_fmt_lat[0]).
// `de` / `ie` mirror the originals (denormal / SNaN-silenced).

module floatN_to_floatx80 (
    input  wire [63:0] a,
    input  wire        is_m64,
    output wire [79:0] z,
    output wire        de,
    output wire        ie
);

    // ---- field extraction (width-muxed) ---------------------------------
    wire        aSign = is_m64 ? a[63] : a[31];

    wire [7:0]  e8  = a[30:23];
    wire [22:0] f23 = a[22:0];
    wire [10:0] e11 = a[62:52];
    wire [51:0] f52 = a[51:0];

    // ---- classification (width-muxed) -----------------------------------
    wire is_inf_or_nan = is_m64 ? (e11 == 11'h7FF) : (e8 == 8'hFF);
    wire sig_nonzero   = is_m64 ? (f52 != 52'd0)   : (f23 != 23'd0);
    wire is_nan        = is_inf_or_nan && sig_nonzero;
    wire qnan_bit      = is_m64 ? f52[51] : f23[22];
    wire is_snan       = is_nan && (qnan_bit == 1'b0);
    wire exp_zero      = is_m64 ? (e11 == 11'd0) : (e8 == 8'd0);
    wire is_zero       = exp_zero && ~sig_nonzero;
    wire is_subn       = exp_zero &&  sig_nonzero;

    // ---- 52-bit significand (f32 frac left-justified into the top) -------
    wire [51:0] aSig52 = is_m64 ? f52 : {f23, 29'd0};

    // ---- denormal normalize via the 6-stage clz52 cascade ---------------
    // Identical to float64_to_floatx80's cascade; for the f32 case the low 29
    // bits are zero so the count matches the old 23-bit CLZ exactly.
    wire [51:0] s_in = aSig52;
    wire [51:0] s1 = (s_in[51:20] == 32'd0) ? (s_in << 32) : s_in;
    wire [5:0]  c1 = (s_in[51:20] == 32'd0) ? 6'd32       : 6'd0;
    wire [51:0] s2 = (s1[51:36] == 16'd0) ? (s1 << 16) : s1;
    wire [5:0]  c2 = (s1[51:36] == 16'd0) ? c1 + 6'd16 : c1;
    wire [51:0] s3 = (s2[51:44] == 8'd0) ? (s2 << 8) : s2;
    wire [5:0]  c3 = (s2[51:44] == 8'd0) ? c2 + 6'd8 : c2;
    wire [51:0] s4 = (s3[51:48] == 4'd0) ? (s3 << 4) : s3;
    wire [5:0]  c4 = (s3[51:48] == 4'd0) ? c3 + 6'd4 : c3;
    wire [51:0] s5 = (s4[51:50] == 2'd0) ? (s4 << 2) : s4;
    wire [5:0]  c5 = (s4[51:50] == 2'd0) ? c4 + 6'd2 : c4;
    wire [51:0] s6 = (s5[51] == 1'b0) ? (s5 << 1) : s5;
    wire [5:0]  c6 = (s5[51] == 1'b0) ? c5 + 6'd1 : c5;

    wire [5:0]  clz       = c6;
    wire [51:0] aSig_norm = s6 << 1;                  // strip the J-bit slot
    wire signed [15:0] aExp_subn = -{{10{1'b0}}, clz}; // 1 - (clz+1) = -clz

    // ---- biased x80 exponent --------------------------------------------
    wire signed [15:0] aExp_normal = is_m64 ? {{5{1'b0}}, e11} : {{8{1'b0}}, e8};
    wire signed [15:0] aExp_pre    = is_subn ? aExp_subn : aExp_normal;
    wire        [15:0] bias_delta  = is_m64 ? 16'h3C00 : 16'h3F80;
    wire        [15:0] exp_sum     = aExp_pre + bias_delta;
    wire        [14:0] exp_out     = is_zero       ? 15'h0000
                                   : is_inf_or_nan ? 15'h7FFF
                                   :                 exp_sum[14:0];

    // ---- significand pick -----------------------------------------------
    wire [51:0] aSig_nan = aSig52 | 52'h8000000000000;  // set bit 51 (QNaN-bit)
    wire [51:0] aSig_use = is_subn ? aSig_norm
                         : is_nan  ? aSig_nan
                                   : aSig52;
    wire [63:0] sig_out  = is_zero ? 64'd0
                                   : {1'b1, aSig_use, 11'd0};

    assign z  = {aSign, exp_out, sig_out};
    assign de = is_subn;
    assign ie = is_snan;

endmodule
