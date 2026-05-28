// PR-2b.5q (iter 131): FXTRACT primitive — split a floatx80 (ST(0)) into its
// unbiased exponent and its significand.  Combinational.  Mirrors Bochs
// floatx80_extract / Intel SDM FXTRACT for the cases the AO486 FPU produces.
//
// FXTRACT semantics: ST(0) = significand * 2^exponent, significand in [1,2).
//   sig_z = the significand: same sign + fraction as ST(0), exponent forced to
//           0x3FFF (true exponent 0) -> a value in [1,2).  Becomes the new ST(0).
//   exp_z = the true (unbiased) exponent e = (a_exp - 0x3FFF), expressed as a
//           floatx80.  Becomes ST(1) after the push.
//
// The exponent-to-float build is an int->floatx80 conversion: for a normal a,
// |e| <= 16382 fits in 14 bits; normalize by the leading-one position p so the
// MSB lands at bit 63, biased exp = 0x3FFF + p, sign = (e < 0).  e == 0 -> +0.0.
//
// Specials (per Bochs / Intel):
//   a NaN  : both outputs = QNaN (IE on SNaN).
//   a Inf  : sig = +/-Inf (sign of a); exp = +Inf.  No exception.
//   a zero : sig = +/-0 (sign of a); exp = -Inf; ZE raised.
//   a denormal : DE raised (cut-1 stub — significand NOT renormalized; not
//                reachable from the const smokes that drive this).
//
// Flags: {PE,UE,OE} never set by FXTRACT.  ze on zero source, de on denormal
// source, ie on SNaN source (+QNaN-ify).

module floatx80_extract (
    input  wire [79:0] a,
    output wire [79:0] sig_z,   // significand -> new ST(0)
    output wire [79:0] exp_z,   // unbiased exponent as floatx80 -> ST(1)
    output wire        ze,      // zero-divide (source == 0)
    output wire        de,      // denormal operand
    output wire        ie       // invalid (SNaN source)
);

    localparam [63:0] INF_SIG = 64'h8000000000000000;

    wire        a_sign = a[79];
    wire [14:0] a_exp  = a[78:64];
    wire [63:0] a_sig  = a[63:0];
    wire [62:0] a_frac = a[62:0];

    wire a_is_zero = (a_exp == 15'd0)    && (a_sig  == 64'd0);
    wire a_is_den  = (a_exp == 15'd0)    && (a_sig  != 64'd0);
    wire a_is_inf  = (a_exp == 15'h7FFF) && (a_frac == 63'd0);
    wire a_is_nan  = (a_exp == 15'h7FFF) && (a_frac != 63'd0);
    wire a_is_snan = a_is_nan && (a[62] == 1'b0);
    wire [63:0] a_qnan = a_sig | 64'h4000000000000000;

    // unbiased exponent e = a_exp - 0x3FFF (signed); |e| <= 16382 -> 14 bits.
    wire signed [15:0] e_signed = $signed({1'b0, a_exp}) - 16'sh3FFF;
    wire        e_neg = e_signed[15];
    wire [13:0] mag   = e_neg ? (~e_signed[13:0] + 14'd1) : e_signed[13:0];

    // leading-one position p of mag[13:0]
    wire [3:0] p = mag[13] ? 4'd13 : mag[12] ? 4'd12 : mag[11] ? 4'd11 :
                   mag[10] ? 4'd10 : mag[9]  ? 4'd9  : mag[8]  ? 4'd8  :
                   mag[7]  ? 4'd7  : mag[6]  ? 4'd6  : mag[5]  ? 4'd5  :
                   mag[4]  ? 4'd4  : mag[3]  ? 4'd3  : mag[2]  ? 4'd2  :
                   mag[1]  ? 4'd1  : 4'd0;
    wire [14:0] exp_e = 15'h3FFF + {11'd0, p};
    wire [63:0] mag64 = {50'd0, mag};
    wire [5:0]  shamt = 6'd63 - {2'd0, p};
    wire [63:0] sig_e = mag64 << shamt;            // left-justify: MSB -> bit 63

    // exponent-as-floatx80 (e == 0 -> +0.0)
    wire [79:0] exp_norm = (mag == 14'd0) ? 80'd0 : {e_neg, exp_e, sig_e};

    reg [79:0] sig_r, exp_r;
    reg        ze_r, de_r, ie_r;
    always @(*) begin
        sig_r = {a_sign, 15'h3FFF, a_sig};   // significand in [1,2)
        exp_r = exp_norm;
        ze_r = 1'b0; de_r = 1'b0; ie_r = 1'b0;

        if (a_is_nan) begin
            ie_r  = a_is_snan;
            sig_r = {a_sign, 15'h7FFF, a_qnan};
            exp_r = {a_sign, 15'h7FFF, a_qnan};
        end else if (a_is_inf) begin
            sig_r = {a_sign, 15'h7FFF, INF_SIG};   // +/-Inf significand
            exp_r = {1'b0,   15'h7FFF, INF_SIG};   // +Inf exponent
        end else if (a_is_zero) begin
            sig_r = {a_sign, 79'd0};               // +/-0 significand
            exp_r = {1'b1,   15'h7FFF, INF_SIG};   // -Inf exponent
            ze_r  = 1'b1;
        end else if (a_is_den) begin
            de_r  = 1'b1;                           // cut-1 stub (no renormalize)
        end
    end

    assign sig_z = sig_r;
    assign exp_z = exp_r;
    assign ze    = ze_r;
    assign de    = de_r;
    assign ie    = ie_r;

endmodule
