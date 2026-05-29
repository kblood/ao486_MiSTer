// PR-2b.5w (iter 141): floatx80 -> signed integer converter for FIST/FISTP.
// Combinational.  Mirrors Bochs floatx80_to_int16/int32/int64 + roundAndPackInt
// for the cases the AO486 FPU can produce.
//
// floatx80: {sign[79], exp[78:64] bias 16383, sig[63:0] with the EXPLICIT
// integer bit at sig[63]}.  value = (-1)^sign * sig * 2^(E-63), E = exp-16383.
// The units bit (weight 2^0) sits at sig position (63-E); bits below it are
// fractional.  We round |value| to an integer per RC, range-check against the
// signed destination width, and on out-of-range / NaN / Inf / unsupported
// raise IE (#IA) and return the integer-indefinite encoding for that width.
//
// width: 0 = m16 (16-bit), 1 = m32 (32-bit), 2 = m64 (64-bit).
// rc[1:0] = x87 CW[11:10]: 00 nearest-even, 01 down, 10 up, 11 truncate.
//
// Flags raised (only these two — matching Bochs floatx80_to_int*):
//   ie : invalid (#IA) on NaN / Inf / unsupported encoding / out-of-range.
//        On IE the value flags are thrown away (pe forced 0) and z = indefinite.
//   pe : precision (inexact) when an in-range result drops fractional bits.
// NOTE: FIST does NOT raise DE on a denormal source (Bochs doesn't); a denormal
// is simply a tiny value that rounds to 0 (or +/-1 directionally) with PE.
//
// The indefinite encodings (low `width` bytes are what the store writes):
//   m16 0x8000, m32 0x80000000, m64 0x8000000000000000.
// The most-negative representable value (-2^15 / -2^31 / -2^63) shares the
// indefinite bit pattern but is a VALID result (ie=0) — distinguished by the
// SW IE flag, exactly as on real x87.

module floatx80_to_int (
    input  wire [79:0] a,
    input  wire [1:0]  rc,
    input  wire [1:0]  width,   // 0=m16, 1=m32, 2=m64
    output wire [63:0] z,
    output wire        ie,      // invalid (#IA)
    output wire        pe       // precision (inexact)
);

    wire        sgn = a[79];
    wire [14:0] exp = a[78:64];
    wire [63:0] sig = a[63:0];

    wire is_special = (exp == 15'h7FFF) ||             // NaN / Inf
                      ((exp != 15'd0) && (sig[63] == 1'b0)); // unnormal / pseudo
    wire is_zero    = (exp == 15'd0) && (sig == 64'd0);

    // unbiased exponent of sig[63]
    wire signed [16:0] E = $signed({2'b00, exp}) - 17'sd16383;

    localparam RC_NEAR = 2'b00;
    localparam RC_DOWN = 2'b01;   // toward -inf
    localparam RC_UP   = 2'b10;   // toward +inf
    localparam RC_ZERO = 2'b11;   // truncate toward zero

    // ---- truncated magnitude + guard/sticky -------------------------
    reg  [63:0] int_part;   // truncated-toward-zero magnitude (< 2^63 unless E==63)
    reg         guard;      // the 0.5-weight bit
    reg         sticky;     // any bit strictly below guard
    reg         big_ovf;    // |value| >= 2^64 -> overflow every width
    reg  [6:0]  sh;
    always @(*) begin
        int_part = 64'd0; guard = 1'b0; sticky = 1'b0; big_ovf = 1'b0; sh = 7'd0;
        if (E >= 17'sd64) begin
            big_ovf = 1'b1;                         // magnitude doesn't fit 64 bits
        end else if (E >= 17'sd0) begin             // shift = 63-E in [0,63]
            sh = 7'd63 - E[6:0];
            int_part = sig >> sh;
            if (sh != 7'd0) begin
                guard  = sig[sh - 7'd1];
                sticky = (sh >= 7'd2) ? |(sig & ((64'd1 << (sh - 7'd1)) - 64'd1)) : 1'b0;
            end
        end else if (E == -17'sd1) begin            // |value| in [0.5,1)
            guard  = sig[63];
            sticky = |sig[62:0];
        end else begin                              // |value| < 0.5 (incl. denormals)
            sticky = |sig;
        end
    end

    wire frac_nz = guard | sticky;
    wire parity  = int_part[0];

    // round-up decision: add 1 to the magnitude?
    wire round_up =
        (rc == RC_NEAR) ? (guard & (sticky | parity)) :
        (rc == RC_ZERO) ? 1'b0                        :
        (rc == RC_DOWN) ? ( sgn & frac_nz)            :  // neg rounds away from 0
      /*(rc == RC_UP)*/   (~sgn & frac_nz);              // pos rounds away from 0

    wire [64:0] mag = {1'b0, int_part} + {64'd0, round_up};

    // ---- range check by destination width ---------------------------
    wire [64:0] pos_max = (width == 2'd0) ? 65'h0000000000007FFF :
                          (width == 2'd1) ? 65'h000000007FFFFFFF :
                                            65'h7FFFFFFFFFFFFFFF;
    wire [64:0] neg_mag = (width == 2'd0) ? 65'h0000000000008000 :
                          (width == 2'd1) ? 65'h0000000080000000 :
                                            65'h8000000000000000;
    wire ovf_range = sgn ? (mag > neg_mag) : (mag > pos_max);

    wire [63:0] indef = (width == 2'd0) ? 64'h0000000000008000 :
                        (width == 2'd1) ? 64'h0000000080000000 :
                                          64'h8000000000000000;

    wire [63:0] signed_val = sgn ? (~mag[63:0] + 64'd1) : mag[63:0];
    wire        overflow   = is_special | big_ovf | ovf_range;

    assign z  = is_special ? indef :
                is_zero     ? 64'd0 :
                overflow    ? indef : signed_val;
    assign ie = (is_special | (~is_zero & overflow));
    assign pe = (~is_special & ~is_zero & ~overflow) ? frac_nz : 1'b0;

endmodule
