// PR-2b.5v (iter 140): signed-integer -> floatx80 converter for FILD m16/m32/m64.
//
// A floatx80 carries a full 64-bit significand (explicit J-bit at sig[63]), so
// EVERY signed integer up to 64 bits is representable exactly.  The conversion
// is therefore exact: FILD raises none of IE/DE/ZE/OE/UE/PE (Intel SDM Vol 1
// 8.5 -- the integer-load has no error conditions), so this module emits no
// flag outputs.
//
// `width`: 2'd0 = m16 (sign-extend a[15:0]), 2'd1 = m32 (a[31:0]),
//          2'd2 = m64 (a[63:0]).  The memory read delivers the operand
//          right-aligned and zero-extended in a[63:0]; this module re-derives
//          the signed 64-bit value per width, takes its magnitude, normalizes
//          via the SHARED floatx80_normalize cone in execute_fpu (iter 173),
//          and packs the result.
//
// PR-2c.21 (iter 173): the local 64-iteration CLZ + 64-bit shift previously
// done inline here is the iter-171b STA wall (ShiftLeft0~XX_OTERMxxxx).  This
// module now exports its (sign, magnitude) prep to execute_fpu's existing
// floatx80_normalize u_norm_a_shared (mutex with arith ops via is_fild_lat |
// is_fbld_lat dispatch latches), saving ~150-250 ALMs and relieving the
// timing wall.  The exp-bias math:
//   floatx80_normalize returns norm_out_exp = 1 - clz (signed 17b, in [-62, 0]
//   when mag != 0), and norm_out_sig = mag << clz (J-bit at bit 63).
//   The original biased x80 exp was 16383 + msb = 16383 + (63 - clz) =
//   16446 - clz = 16445 + (1 - clz) = 16445 + norm_out_exp.
//
// floatx80 layout (matches float32_to_floatx80.v): {sign[79], exp[78:64] biased
// by 16383, sig[63:0] with the J-bit at [63]}.  A zero input yields +0 = 80'h0.

module int_to_floatx80 (
    input  wire [63:0] a,
    input  wire [1:0]  width,    // 0=m16, 1=m32, 2=m64

    // iter-173: shared floatx80_normalize plumbing.  norm_in_* drive
    // execute_fpu's u_norm_a_shared input mux when fild_norm_sel is asserted;
    // norm_out_* return the normalized triple.
    output wire        norm_in_sign,
    output wire [63:0] norm_in_mag,
    input  wire signed [16:0] norm_out_exp,
    input  wire        [63:0] norm_out_sig,

    output wire [79:0] z
);

    // Re-derive the signed 64-bit value from the active width.
    wire [63:0] v = (width == 2'd0) ? {{48{a[15]}}, a[15:0]} :
                    (width == 2'd1) ? {{32{a[31]}}, a[31:0]} :
                                      a;

    wire        sign = v[63];
    // Two's-complement magnitude.  For v = -2^63 (0x8000_..._0000) the negate
    // wraps back to 0x8000_..._0000, which is exactly 2^63 as an unsigned
    // magnitude -- the correct value, since +2^63 still fits the 64-bit sig.
    wire [63:0] mag  = sign ? (~v + 64'd1) : v;
    wire        is_zero = (mag == 64'd0);

    // Export sign + mag to execute_fpu, which feeds the SHARED u_norm_a_shared
    // with {sign, 15'd0, mag} when fild_norm_sel is high (is_fild_lat |
    // is_fbld_lat).  floatx80_normalize then detects is_subn (exp==0 && sig!=0)
    // and returns mag << clz + (1 - clz) as the normalized triple.
    assign norm_in_sign = sign;
    assign norm_in_mag  = mag;

    // Biased x80 exp = 16445 + norm_out_exp (signed-add the 17b normalized exp
    // back onto the bias-1 constant; truncate to 15b for the encoding).
    wire signed [16:0] exp_sum = $signed(17'sd16445) + norm_out_exp;
    wire        [14:0] z_exp   = exp_sum[14:0];

    assign z = is_zero ? 80'h0 : {sign, z_exp, norm_out_sig};

endmodule
