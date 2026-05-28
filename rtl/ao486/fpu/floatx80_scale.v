// PR-2b.5p (iter 130): FSCALE primitive — scale ST(0) by an integral power of
// two taken from ST(1):  z = a * 2^trunc(b).  Combinational.  Mirrors Bochs
// floatx80_scale (softfloatx80.cc) for the cases the AO486 FPU can produce.
//
// floatx80: {sign[79], exp[78:64] bias 16383, sig[63:0] with the EXPLICIT
// integer bit at sig[63]}.  Scaling a NORMAL value by an integral power of two
// is a pure add to the biased exponent — the 64-bit significand and the sign
// are unchanged, so the in-range result is EXACT (no rounding, PE stays 0).
//
//   scale = trunc(b) toward zero, taken as a signed integer:
//     |b| < 1            -> scale 0                       (return a unchanged)
//     1 <= |b| < 2^16    -> scale = sig_b >> (0x403E-Eb)  (sign of b)
//     |b| >= 2^16        -> saturate: +b overflows, -b underflows
//   res_exp = a_exp + scale (biased).  res_exp >= 0x7FFF -> Inf (OE+PE);
//   res_exp <= 0 -> tiny (UE+PE, flushed to signed zero in this cut).
//
// Special operands (priority order, per Bochs):
//   NaN (either)   : propagate, QNaN-ify, IE if any SNaN.
//   a = Inf        : b = -Inf -> invalid (IE, indefinite); else Inf passes.
//   b = +Inf       : a = 0 -> invalid (IE, indefinite); else signed Inf.
//   b = -Inf       : signed zero.
//   a = 0          : return a (0 * 2^k = 0).
//   b = 0/denormal : scale 0 -> return a (DE flagged on a denormal b).
//
// Known cut-1 gaps (not reachable from the const smokes that drive this):
//   - a denormal ST(0): flagged DE, returned unchanged (no normalize/rescale).
//   - underflow result: flushed to signed zero rather than encoded subnormal.

module floatx80_scale (
    input  wire [79:0] a,    // ST(0) — value to scale
    input  wire [79:0] b,    // ST(1) — power-of-two exponent
    output wire [79:0] z,
    output wire        pe,   // precision (inexact) — overflow/underflow path
    output wire        ue,   // underflow
    output wire        oe,   // overflow
    output wire        de,   // denormal operand
    output wire        ie    // invalid
);

    localparam [63:0] INF_SIG = 64'h8000000000000000;        // Inf significand
    localparam [79:0] INDEF   = {1'b1, 15'h7FFF, 64'hC000000000000000}; // real indefinite QNaN

    wire        a_sign = a[79];
    wire [14:0] a_exp  = a[78:64];
    wire [63:0] a_sig  = a[63:0];
    wire [62:0] a_frac = a[62:0];

    wire        b_sign = b[79];
    wire [14:0] b_exp  = b[78:64];
    wire [63:0] b_sig  = b[63:0];
    wire [62:0] b_frac = b[62:0];

    wire a_is_zero = (a_exp == 15'd0)    && (a_sig  == 64'd0);
    wire a_is_den  = (a_exp == 15'd0)    && (a_sig  != 64'd0);
    wire a_is_inf  = (a_exp == 15'h7FFF) && (a_frac == 63'd0);
    wire a_is_nan  = (a_exp == 15'h7FFF) && (a_frac != 63'd0);
    wire a_is_snan = a_is_nan && (a[62] == 1'b0);

    wire b_is_zero = (b_exp == 15'd0)    && (b_sig  == 64'd0);
    wire b_is_den  = (b_exp == 15'd0)    && (b_sig  != 64'd0);
    wire b_is_inf  = (b_exp == 15'h7FFF) && (b_frac == 63'd0);
    wire b_is_nan  = (b_exp == 15'h7FFF) && (b_frac != 63'd0);
    wire b_is_snan = b_is_nan && (b[62] == 1'b0);
    wire b_finite  = ~b_is_nan && ~b_is_inf;

    // ---- truncate |b| toward zero into a signed power-of-two exponent ----
    // Valid only for 0x3FFF <= b_exp <= 0x400E (1 <= |b| < 2^16); shift in
    // [48,63] so b_sig >> shift yields the integer part (1..65535).
    wire        b_trunc_range = b_finite && (b_exp >= 15'h3FFF) && (b_exp <= 15'h400E);
    wire        b_huge        = b_finite && (b_exp >  15'h400E);  // |b| >= 2^16
    wire        b_small       = b_finite && (b_exp <  15'h3FFF);  // |b| < 1 (incl 0/denormal)

    wire [14:0] shift_count = 15'h403E - b_exp;          // 48..63 over the valid range
    wire [63:0] scale_mag64 = b_sig >> shift_count[5:0];
    wire [16:0] scale_mag   = scale_mag64[16:0];
    wire signed [31:0] scale_s = b_sign ? -$signed({15'd0, scale_mag})
                                        :  $signed({15'd0, scale_mag});

    // result biased exponent for the normal/in-range path
    wire signed [31:0] res_exp_s = $signed({17'd0, a_exp}) + scale_s;

    // ---- assemble --------------------------------------------------------
    wire [63:0] a_qnan = a_sig | 64'h4000000000000000;   // force QNaN bit 62
    wire [63:0] b_qnan = b_sig | 64'h4000000000000000;

    reg [79:0] z_r;
    reg        pe_r, ue_r, oe_r, de_r, ie_r;
    always @(*) begin
        z_r  = a;
        pe_r = 1'b0; ue_r = 1'b0; oe_r = 1'b0; de_r = 1'b0; ie_r = 1'b0;

        if (a_is_nan || b_is_nan) begin                  // NaN propagate
            ie_r = a_is_snan | b_is_snan;
            z_r  = a_is_nan ? {a_sign, a_exp, a_qnan}
                            : {b_sign, b_exp, b_qnan};
        end else if (a_is_inf) begin
            if (b_is_inf && b_sign) begin                // Inf * 2^-Inf -> invalid
                ie_r = 1'b1; z_r = INDEF;
            end else begin
                z_r = a;                                 // Inf scaled by finite/+Inf -> Inf
            end
        end else if (b_is_inf) begin
            if (b_sign) begin
                z_r = {a_sign, 79'd0};                   // 2^-Inf -> signed zero
            end else if (a_is_zero) begin
                ie_r = 1'b1; z_r = INDEF;                // 0 * 2^+Inf -> invalid
            end else begin
                z_r = {a_sign, 15'h7FFF, INF_SIG};       // 2^+Inf -> signed Inf
            end
        end else if (a_is_zero) begin
            z_r = a;                                     // 0 scaled by finite -> 0
        end else if (a_is_den) begin
            de_r = 1'b1; z_r = a;                        // cut-1: denormal ST(0) stub
        end else begin                                   // a finite normal, b finite
            de_r = b_is_den;                             // denormal scale operand -> DE
            if (b_huge && ~b_sign) begin                 // 2^(big +) -> overflow
                oe_r = 1'b1; pe_r = 1'b1;
                z_r  = {a_sign, 15'h7FFF, INF_SIG};
            end else if (b_huge && b_sign) begin         // 2^(big -) -> underflow
                ue_r = 1'b1; pe_r = 1'b1;
                z_r  = {a_sign, 79'd0};
            end else if (b_small) begin                  // |b| < 1 -> scale 0
                z_r = a;
            end else begin                               // b_trunc_range
                if (res_exp_s >= 32'sd32767) begin       // >= 0x7FFF -> Inf
                    oe_r = 1'b1; pe_r = 1'b1;
                    z_r  = {a_sign, 15'h7FFF, INF_SIG};
                end else if (res_exp_s <= 32'sd0) begin  // <= 0 -> tiny (flush)
                    ue_r = 1'b1; pe_r = 1'b1;
                    z_r  = {a_sign, 79'd0};
                end else begin                           // 1..0x7FFE -> exact rescale
                    z_r  = {a_sign, res_exp_s[14:0], a_sig};
                end
            end
        end
    end

    assign z  = z_r;
    assign pe = pe_r;
    assign ue = ue_r;
    assign oe = oe_r;
    assign de = de_r;
    assign ie = ie_r;

endmodule
