// PR-2b.5d (iter 117): extended-precision (floatx80) -> double (m64fp)
// NARROWING converter with round-to-nearest-even.  The inverse of
// `float64_to_floatx80.v` (PR-2b.4b); used by FST/FSTP m64fp (DD /2,/3).
// Symmetric twin of `floatx80_to_float32.v` (iter 116) — same structure,
// wider fraction (53 kept bits) and a different bias delta.
//
// IEEE 754 extended: {sign[79], exp[78:64] bias 16383, sig[63:0] J@bit63}.
// IEEE 754 double  : {sign[63], exp[62:52] bias 1023, frac[51:0] J implicit}.
//
// Conversion (mirrors Bochs softfloat floatx80_to_float64 for the cases the
// AO486 FPU can actually produce):
//   * Zero (xExp==0 && xSig==0)            -> {sign, 63'd0}.
//   * Inf  (xExp==0x7FFF && xSig==0x800..0)-> {sign, 0x7FF, 52'd0}.
//   * NaN  (xExp==0x7FFF && sig[62:0]!=0)  -> {sign, 0x7FF, frac=sig[62:11]
//          with QNaN-bit frac[51] forced 1}.  SNaN (sig[62]==0) raises IE.
//   * Normal: rebias exp by 0x3C00 (16383->1023, delta 15360); round the top
//     53 bits (J + 52 frac) of sig to nearest-even using guard=sig[10],
//     sticky=|sig[9:0].  A round that carries out of bit 52 bumps the exp.
//     inexact (guard|sticky) -> PE.
//   * Overflow (rebiased exp >= 2047)      -> {sign, 0x7FF, 0} (Inf) + OE+PE.
//   * Underflow (rebiased exp <= 0): real IEEE denormal rounding as of
//     iter-122 (symmetric twin of the iter-121 float32 path).  Right-shift the
//     J-aligned significand onto the subnormal grid (LSB 2^-1074), re-round to
//     nearest-even with jam-into-sticky, bump to min-normal on carry.  UE/PE
//     follow Bochs masked semantics: tiny AND inexact (an exact subnormal
//     raises neither).  See research/design_fst_denormal.md and
//     [[floatx80-narrowing-converter-build]].
//
// Flag outputs pe/oe/ue/ie feed the caller's flags lane (wired into SW since
// iter-119 for the float32 twin; float64 store-flag wire-up tracked alongside).

module floatx80_to_float64 (
    input  wire [79:0] a,
    output wire [63:0] z,
    output wire        pe,   // precision (inexact)
    output wire        oe,   // overflow
    output wire        ue,   // underflow (flush-to-zero; see TODO)
    output wire        ie    // invalid (SNaN input)
);

    wire        xSign = a[79];
    wire [14:0] xExp  = a[78:64];
    wire [63:0] xSig  = a[63:0];

    wire is_zero = (xExp == 15'd0)     && (xSig == 64'd0);
    wire is_inf  = (xExp == 15'h7FFF)  && (xSig == 64'h8000000000000000);
    wire is_nan  = (xExp == 15'h7FFF)  && (xSig[62:0] != 63'd0);
    wire is_snan = is_nan && (xSig[62] == 1'b0);
    wire is_special = is_zero | is_inf | is_nan;

    // ---- normal-path exponent rebias (signed) ---------------------------
    // e = xExp - (16383 - 1023) = xExp - 15360 (0x3C00).
    wire signed [16:0] e = $signed({2'b00, xExp}) - 17'sd15360;

    // ---- round top 53 bits (J + 52 frac) to nearest-even ----------------
    wire [52:0] kept53   = xSig[63:11];
    wire        guard    = xSig[10];
    wire        sticky   = |xSig[9:0];
    wire        round_up = guard & (sticky | kept53[0]);
    wire [53:0] kept_rnd = {1'b0, kept53} + {53'd0, round_up};  // catch carry
    wire        carry    = kept_rnd[53];           // 0x1F..F + 1 = 0x20..0
    wire [51:0] frac_n   = carry ? 52'd0 : kept_rnd[51:0];
    wire signed [16:0] e_adj   = carry ? (e + 17'sd1) : e;
    wire        inexact  = guard | sticky;

    // ---- normal vs overflow vs underflow (after rounding) ---------------
    wire ovf = !is_special && (e_adj >= 17'sd2047);  // 2047 = Inf exp field
    wire unf = !is_special && (e_adj <= 17'sd0);      // <=0 -> denormal/zero
    wire normal = !is_special && !ovf && !unf;         // e_adj in [1..2046]

    // ---- subnormal pack (iter-122): proper float64 denormal encoding -----
    // Symmetric twin of the iter-121 float32 subnormal block.  In the unf
    // region the value is below float64 min-normal (2^-1022).  Align the
    // J-aligned significand to the subnormal grid (LSB 2^-1074) by right-
    // shifting by (1 - e) and re-rounding to nearest-even, jamming every
    // dropped bit into sticky.  Mirrors Bochs roundAndPackFloat64 masked arm
    // (tiny&inexact -> UE).  Declared BEFORE the assemble always block —
    // subn_exp/subn_frac are used procedurally there (decl-order rule, see
    // [[feedback-modelsim-procedural-net-decl-order]]).
    wire signed [16:0] subn_sc_s = 17'sd1 - e;            // e <= 0 here -> >= 1
    wire [6:0]  subn_sc    = (subn_sc_s >= 17'sd63) ? 7'd63 : subn_sc_s[6:0];
    wire [63:0] subn_shift = xSig >> subn_sc;
    wire [63:0] subn_lostm = (64'd1 << subn_sc) - 64'd1;
    wire        subn_lost  = |(xSig & subn_lostm);
    wire [52:0] subn_sig53 = subn_shift[63:11];
    wire        subn_guard = subn_shift[10];
    wire        subn_stky  = (|subn_shift[9:0]) | subn_lost;
    wire        subn_rup   = subn_guard & (subn_stky | subn_sig53[0]);  // RTNE
    wire [53:0] subn_M     = {1'b0, subn_sig53} + {53'd0, subn_rup};
    wire        subn_minnm = subn_M[52];                  // rounded to min-normal
    wire        subn_inex  = subn_guard | subn_stky;
    wire [10:0] subn_exp   = subn_minnm ? 11'd1 : 11'd0;
    wire [51:0] subn_frac  = subn_M[51:0];

    // ---- NaN payload: top 52 fraction bits, QNaN-bit forced on ----------
    wire [51:0] nan_frac = xSig[62:11] | 52'h8000000000000;  // bit 51

    // ---- assemble -------------------------------------------------------
    reg  [10:0] exp_out;
    reg  [51:0] frac_out;
    always @(*) begin
        if (is_zero) begin
            exp_out = 11'd0;        frac_out = 52'd0;
        end else if (is_inf || ovf) begin
            exp_out = 11'h7FF;      frac_out = 52'd0;        // +/-Inf
        end else if (is_nan) begin
            exp_out = 11'h7FF;      frac_out = nan_frac;
        end else if (unf) begin
            exp_out = subn_exp;     frac_out = subn_frac;      // denormal (iter-122)
        end else begin
            exp_out = e_adj[10:0];  frac_out = frac_n;         // normal
        end
    end

    assign z  = {xSign, exp_out, frac_out};
    // UE/PE on a narrowing store follow Bochs masked semantics: tiny AND
    // inexact (an exact subnormal raises neither).  iter-122.
    assign pe = (normal & inexact) | ovf | (unf & subn_inex);
    assign oe = ovf;
    assign ue = unf & subn_inex;
    assign ie = is_snan;

endmodule
