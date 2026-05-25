// PR-2b.4b (iter 54): single-precision (m32fp) → floatx80 converter.
//
// Pure-combinational port of Bochs softfloat
// `sim/testfloat/softfloat/softfloat.cc:float32_to_floatx80`
// (lines 2668-2684 of the vendored copy).  Used by the FPU's
// memory-form arith path (PR-2b.4d+) to feed the existing 80-bit
// arith primitives from an m32 memory operand.
//
// IEEE 754 single: {sign[31], exp[30:23], frac[22:0]}, bias 127, J-bit implicit.
// IEEE 754 extended: {sign[79], exp[78:64], frac[63:0]}, bias 16383, J-bit at frac[63].
//
// Conversion rules (Bochs):
//   * NaN/Inf (aExp==0xFF):
//       aSig==0  → ±Inf encoded as {sign, 0x7FFF, 0x8000_0000_0000_0000}
//       aSig!=0  → NaN; matches Bochs `commonNaNToFloatx80` semantics —
//                  SNaN inputs are SILENCED (QNaN-bit forced ON at frac[62])
//                  and the converter raises IE on the new `ie` output.
//                  QNaN inputs pass through (bit 62 was already 1).
//                  Downstream `floatx80_nan_handle` then sees a QNaN and
//                  does NOT re-raise IE — single point of IE at convert.
//   * Zero (aExp==0, aSig==0):
//       result = {sign, 15'd0, 64'd0} (signed zero).
//   * Denormal (aExp==0, aSig!=0):
//       normalize inline (Bochs calls normalizeFloat32Subnormal then standard
//       pack).  Shift sig left until bit 23 is set; biased x80 exp =
//       (1 - shift) + 0x3F80.  Output is a NORMAL x80 (all f32 denormals fit
//       comfortably inside the x80 normal exponent range — exp ∈ [-149,-127]
//       maps to x80 biased [0x3F6A..0x3F80]).  DE flag emitted so the caller
//       can OR it into SW.DE per SDM §8.5.2.
//   * Normal (aExp ∈ [1..0xFE]):
//       biased x80 exp = aExp + 0x3F80 (bias 127 → 16383, delta 0x3F80=16256).
//       Sig: J-bit (1) prepended at bit 23, full 24-bit value shifted left
//       40 to put J at bit 63 of the x80 sig field.
//
// Outputs `de` and `ie` are asserted on denormal and SNaN inputs
// respectively; the caller's execute_fpu lane OR-s them into flags_lat at
// S_COMPUTE.  Only one of the two can be set on a given input (denormal and
// NaN inputs are disjoint).

module float32_to_floatx80 (
    input  wire [31:0] a,
    output wire [79:0] z,
    output wire        de,
    output wire        ie
);

    wire        aSign   = a[31];
    wire [7:0]  aExp_in = a[30:23];
    wire [22:0] aSig_in = a[22:0];

    wire is_inf_or_nan = (aExp_in == 8'hFF);
    wire is_nan        = is_inf_or_nan && (aSig_in != 23'd0);
    wire is_snan       = is_nan && (aSig_in[22] == 1'b0);
    wire is_zero       = (aExp_in == 8'd0) && (aSig_in == 23'd0);
    wire is_subn       = (aExp_in == 8'd0) && (aSig_in != 23'd0);

    // ---- denormal normalize ----------------------------------------------
    // Count leading zeros within aSig_in[22:0].  For a denormal aSig != 0 so
    // we always find a leading 1; for non-denormal inputs the result is
    // unused.  Encoded as a 23-way priority-mux (clz23 ∈ [0..22]).
    reg [4:0] clz23;
    always @(*) begin
        casez (aSig_in)
            23'b1??????????????????????: clz23 = 5'd0;
            23'b01?????????????????????: clz23 = 5'd1;
            23'b001????????????????????: clz23 = 5'd2;
            23'b0001???????????????????: clz23 = 5'd3;
            23'b00001??????????????????: clz23 = 5'd4;
            23'b000001?????????????????: clz23 = 5'd5;
            23'b0000001????????????????: clz23 = 5'd6;
            23'b00000001???????????????: clz23 = 5'd7;
            23'b000000001??????????????: clz23 = 5'd8;
            23'b0000000001?????????????: clz23 = 5'd9;
            23'b00000000001????????????: clz23 = 5'd10;
            23'b000000000001???????????: clz23 = 5'd11;
            23'b0000000000001??????????: clz23 = 5'd12;
            23'b00000000000001?????????: clz23 = 5'd13;
            23'b000000000000001????????: clz23 = 5'd14;
            23'b0000000000000001???????: clz23 = 5'd15;
            23'b00000000000000001??????: clz23 = 5'd16;
            23'b000000000000000001?????: clz23 = 5'd17;
            23'b0000000000000000001????: clz23 = 5'd18;
            23'b00000000000000000001???: clz23 = 5'd19;
            23'b000000000000000000001??: clz23 = 5'd20;
            23'b0000000000000000000001?: clz23 = 5'd21;
            23'b00000000000000000000001: clz23 = 5'd22;
            default:                     clz23 = 5'd22;  // unreachable for is_subn
        endcase
    end

    // Post-normalize aSig: shift left by (clz23 + 1) so the leading 1 lands
    // at position 23 (the J-bit slot, which we then strip).  The 23 bits we
    // keep [22:0] are the post-J fraction.
    wire [22:0] aSig_norm = aSig_in << (clz23 + 1);

    // Post-normalize aExp (signed): 1 - (clz23+1) = -clz23.  Range [-22..0].
    wire signed [15:0] aExp_subn = -{{11{1'b0}}, clz23};

    // ---- biased x80 exp pick --------------------------------------------
    // Normal path: aExp_in + 0x3F80 (= bias 127 → 16383).
    // Denormal: aExp_subn + 0x3F80.
    // Inf/NaN: forced 0x7FFF.  Zero: forced 0.
    wire signed [15:0] aExp_pre = is_subn ? aExp_subn
                                : {{8{1'b0}}, aExp_in};
    wire        [15:0] exp_sum  = aExp_pre + 16'h3F80;
    wire        [14:0] exp_out  = is_zero       ? 15'h0000
                                : is_inf_or_nan ? 15'h7FFF
                                :                 exp_sum[14:0];

    // ---- sig pick -------------------------------------------------------
    // J-bit + post-shift fraction, padded with 40 zeros on the right.
    // For zero, force all zero.
    // For Inf, aSig_in is zero so {1'b1, 0, 0} = 0x8000_0000_0000_0000 ✓.
    // For NaN, the QNaN-bit (frac[22]) is FORCED HIGH (silence SNaN); the
    //   rest of the payload passes through.  ie output flags the silencing.
    wire [22:0] aSig_nan = aSig_in | 23'h400000;  // set bit 22 (QNaN-bit)
    wire [22:0] aSig_use = is_subn ? aSig_norm
                         : is_nan  ? aSig_nan
                                   : aSig_in;
    wire [63:0] sig_out  = is_zero ? 64'd0
                                   : {1'b1, aSig_use, 40'd0};

    assign z  = {aSign, exp_out, sig_out};
    assign de = is_subn;
    assign ie = is_snan;

endmodule
