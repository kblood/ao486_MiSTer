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
//          via a 64-bit priority encoder, and packs the result.
//
// floatx80 layout (matches float32_to_floatx80.v): {sign[79], exp[78:64] biased
// by 16383, sig[63:0] with the J-bit at [63]}.  A zero input yields +0 = 80'h0.

module int_to_floatx80 (
    input  wire [63:0] a,
    input  wire [1:0]  width,    // 0=m16, 1=m32, 2=m64
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

    // 64-bit priority encoder: index (0..63) of the most-significant set bit.
    reg [6:0] msb;
    integer   i;
    always @(*) begin
        msb = 7'd0;
        for (i = 0; i < 64; i = i + 1)
            if (mag[i]) msb = i[6:0];
    end

    // Normalize the leading 1 up to bit 63.  shift in [0,63] for mag != 0.
    wire [5:0]  shift = 6'd63 - msb[5:0];
    wire [63:0] sig   = mag << shift;            // sig[63] == 1 when mag != 0
    // Unbiased exponent == msb; bias by 16383.
    wire [14:0] exp   = 15'd16383 + {8'd0, msb};

    assign z = is_zero ? 80'h0 : {sign, exp, sig};

endmodule
