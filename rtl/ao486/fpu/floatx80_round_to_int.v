// PR-2b.5n (iter 127): FRNDINT primitive — round a floatx80 (ST(0)) to an
// integral value per the x87 rounding-control field RC = CW[11:10].
// Combinational.  Mirrors Bochs floatx80_round_to_int for the cases the
// AO486 FPU can produce.
//
// floatx80: {sign[79], exp[78:64] bias 16383, sig[63:0] with the EXPLICIT
// integer bit at sig[63]}.  value = (-1)^sign * sig * 2^(exp-16383-63).
// Let E = exp - 16383 be the unbiased exponent of sig[63].  Bit p of sig
// has weight 2^(E-63+p); the units bit (weight 2^0) sits at bit position
// shift = 63 - E, so bits [shift-1:0] are fractional.
//
//   E >= 63  : no fractional bits -> already integral, return unchanged.
//   E <  0   : |x| < 1 -> result is 0 or +/-1 per RC and the value.
//   0<=E<=62 : mask the low `shift` fractional bits and round per RC; a
//              round-up that carries out of bit 63 bumps the exponent.
//
// RC[1:0] (x87 CW[11:10]): 00 = nearest-even, 01 = down (toward -inf),
// 10 = up (toward +inf), 11 = truncate (toward zero).
//
// Flags: pe (precision/inexact) whenever the result differs from the
// input; de (denormal operand) on a denormal input (exp==0, sig!=0);
// ie (invalid) on an SNaN input (which is also QNaN-ified on output).
// OE/UE/ZE cannot arise from rounding-to-integer of a finite operand.

module floatx80_round_to_int (
    input  wire [79:0] a,
    input  wire [1:0]  rc,
    output wire [79:0] z,
    output wire        pe,   // precision (inexact)
    output wire        de,   // denormal operand
    output wire        ie    // invalid (SNaN input)
);

    wire        sign = a[79];
    wire [14:0] exp  = a[78:64];
    wire [63:0] sig  = a[63:0];

    wire is_zero   = (exp == 15'd0)    && (sig == 64'd0);
    wire is_nan    = (exp == 15'h7FFF) && (sig[62:0] != 63'd0);
    wire is_snan   = is_nan && (sig[62] == 1'b0);
    wire is_denorm = (exp == 15'd0)    && (sig != 64'd0);

    // unbiased exponent of sig[63]
    wire signed [16:0] E = $signed({2'b00, exp}) - 17'sd16383;

    localparam RC_NEAR = 2'b00;
    localparam RC_DOWN = 2'b01;   // toward -inf
    localparam RC_UP   = 2'b10;   // toward +inf
    localparam RC_ZERO = 2'b11;   // truncate toward zero

    // ---- region 0<=E<=62 : mask + round -----------------------------
    // shift = number of fractional bits = 63 - E, in [1,63] over this range.
    wire [6:0]  shift     = 7'd63 - E[6:0];               // valid for 0<=E<=62
    wire [63:0] frac_mask = (64'd1 << shift) - 64'd1;     // low `shift` bits
    wire [63:0] trunc_sig = sig & ~frac_mask;             // integer part
    wire [63:0] half_bit  = (64'd1 << (shift - 7'd1));    // 0.5-weight bit
    wire        guard     = |(sig & half_bit);
    wire        sticky    = |(sig & (half_bit - 64'd1));  // bits below guard
    wire        int_lsb   = |(sig & (64'd1 << shift));    // units bit (parity)
    wire        frac_nz   = |(sig & frac_mask);

    // round-up decision per RC: add 1 unit (1<<shift) to the magnitude?
    wire round_up_mid =
        (rc == RC_NEAR) ? (guard & (sticky | int_lsb)) :
        (rc == RC_ZERO) ? 1'b0                          :
        (rc == RC_DOWN) ? (sign  & frac_nz)             :  // neg rounds away
      /*(rc == RC_UP)*/   (~sign & frac_nz);               // pos rounds away

    wire [64:0] sum_mid   = {1'b0, trunc_sig} + ({64'd0, round_up_mid} << shift);
    wire        carry_mid = sum_mid[64];                  // 0x1..F + 1 -> 0x2..0
    wire [63:0] sig_mid   = carry_mid ? 64'h8000000000000000 : sum_mid[63:0];
    wire [14:0] exp_mid   = carry_mid ? (exp + 15'd1) : exp;

    // ---- region E<0 : |x|<1 -> 0 or +/-1 ----------------------------
    // |x| in [0.5,1) iff E == -1; exactly 0.5 iff also sig[62:0]==0.
    wire half_or_more = (E == -17'sd1);
    wire exactly_half = half_or_more & (sig[62:0] == 63'd0);
    wire round_up_lo =
        (rc == RC_NEAR) ? (half_or_more & ~exactly_half) :  // >0.5->1; ==0.5->0
        (rc == RC_ZERO) ? 1'b0                           :
        (rc == RC_DOWN) ? sign                           :  // neg -> -1
      /*(rc == RC_UP)*/   ~sign;                            // pos -> +1
    // 1.0 = exp 0x3FFF, sig 0x8000..0 ; otherwise +/-0.
    wire [79:0] z_lo = round_up_lo ? {sign, 15'h3FFF, 64'h8000000000000000}
                                   : {sign, 15'd0,     64'd0};

    // ---- assemble ---------------------------------------------------
    wire [63:0] qnan_sig = sig | 64'h4000000000000000;   // force QNaN bit 62
    reg  [79:0] z_r;
    reg         pe_r;
    always @(*) begin
        if (exp == 15'h7FFF) begin            // NaN / Inf -> pass through
            z_r  = is_snan ? {sign, exp, qnan_sig} : a;
            pe_r = 1'b0;
        end else if (is_zero) begin           // +/-0 -> unchanged
            z_r  = a;
            pe_r = 1'b0;
        end else if (E >= 17'sd63) begin      // already integral
            z_r  = a;
            pe_r = 1'b0;
        end else if (E < 17'sd0) begin        // |x| < 1
            z_r  = z_lo;
            pe_r = 1'b1;                       // nonzero -> rounding is inexact
        end else begin                        // 0<=E<=62 : mask + round
            z_r  = {sign, exp_mid, sig_mid};
            pe_r = frac_nz;
        end
    end

    assign z  = z_r;
    assign pe = pe_r;
    assign de = is_denorm;
    assign ie = is_snan;

endmodule
