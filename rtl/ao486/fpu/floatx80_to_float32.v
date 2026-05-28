// PR-2b.5c (iter 116): extended-precision (floatx80) -> single (m32fp)
// NARROWING converter with round-to-nearest-even.  The inverse of
// `float32_to_floatx80.v` (PR-2b.4b); used by FST/FSTP m32fp (D9 /2,/3).
//
// IEEE 754 extended: {sign[79], exp[78:64] bias 16383, sig[63:0] J@bit63}.
// IEEE 754 single  : {sign[31], exp[30:23] bias 127,  frac[22:0] J implicit}.
//
// Conversion (mirrors Bochs softfloat floatx80_to_float32 for the cases the
// AO486 FPU can actually produce):
//   * Zero (xExp==0 && xSig==0)            -> {sign, 31'd0}.
//   * Inf  (xExp==0x7FFF && xSig==0x800..0)-> {sign, 0xFF, 23'd0}.
//   * NaN  (xExp==0x7FFF && sig[62:0]!=0)  -> {sign, 0xFF, frac=sig[62:40]
//          with QNaN-bit frac[22] forced 1}.  SNaN (sig[62]==0) raises IE.
//   * Normal: rebias exp by 0x3F80 (16383->127, delta 16256); round the top
//     24 bits (J + 23 frac) of sig to nearest-even using guard=sig[39],
//     sticky=|sig[38:0].  A round that carries out of bit 23 bumps the exp.
//     inexact (guard|sticky) -> PE.
//   * Overflow (rebiased exp >= 255)       -> {sign, 0xFF, 0} (Inf) + OE+PE.
//   * Underflow (rebiased exp <= 0): TODO — FULL IEEE denormal rounding is
//     NOT yet implemented.  This path FLUSHES TO SIGNED ZERO and raises
//     UE+PE.  It is UNVERIFIED (the iter-114/116 constant smokes cannot
//     produce a sub-normal-float32 ST(0) — all 7 constants rebias to exp in
//     [0x7D..0x80], deep in normal range).  Must be completed + given
//     dedicated vectors (a tiny FPU arith result) before any workload relies
//     on denormal-magnitude FST m32 results.  See research/design_fst_m32_m64.md.
//
// Flag outputs pe/oe/ue/ie are produced for the caller's flags lane.  NOTE:
// iter-116 (phase 115a) wires the VALUE/STORE path only and forces flags_lat
// to 0 in execute_fpu (mirroring FSTP m80); plumbing these flags into SW is
// deferred to iter-117 (isolates the conversion bit-exactness from the
// SW-concat / S_RETIRE-pulse risk).  The outputs exist now so 117 is a wire-up.

module floatx80_to_float32 (
    input  wire [79:0] a,
    output wire [31:0] z,
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
    // e = xExp - (16383 - 127) = xExp - 16256 (0x3F80).
    wire signed [16:0] e = $signed({2'b00, xExp}) - 17'sd16256;

    // ---- round top 24 bits (J + 23 frac) to nearest-even ----------------
    wire [23:0] kept24   = xSig[63:40];
    wire        guard    = xSig[39];
    wire        sticky   = |xSig[38:0];
    wire        round_up = guard & (sticky | kept24[0]);
    wire [24:0] kept_rnd = {1'b0, kept24} + {24'd0, round_up};  // catch carry
    wire        carry    = kept_rnd[24];           // 0xFFFFFF + 1 = 0x1000000
    wire [22:0] frac_n   = carry ? 23'd0 : kept_rnd[22:0];
    wire signed [16:0] e_adj   = carry ? (e + 17'sd1) : e;
    wire        inexact  = guard | sticky;

    // ---- normal vs overflow vs underflow (after rounding) ---------------
    wire ovf = !is_special && (e_adj >= 17'sd255);  // 255 = Inf exp field
    wire unf = !is_special && (e_adj <= 17'sd0);     // <=0 -> denormal/zero
    wire normal = !is_special && !ovf && !unf;        // e_adj in [1..254]

    // ---- subnormal pack (iter-121): proper float32 denormal encoding -----
    // In the unf region the value is below float32 min-normal (2^-126).  Align
    // the J-aligned significand to the subnormal grid (LSB 2^-149) by right-
    // shifting by (1 - e) and re-rounding to nearest-even on the post-shift
    // sig, jamming every dropped bit into sticky.  Mirrors floatx80_pack_subn
    // (iter-41) + Bochs roundAndPackFloat32 masked arm (tiny&inexact -> UE).
    // NOTE: declared BEFORE the assemble always block — subn_exp/subn_frac are
    // used procedurally there (see [[feedback-modelsim-procedural-net-decl-order]]).
    wire signed [16:0] subn_sc_s = 17'sd1 - e;             // e <= 0 here -> >= 1
    wire [6:0]  subn_sc    = (subn_sc_s >= 17'sd63) ? 7'd63 : subn_sc_s[6:0];
    wire [63:0] subn_shift = xSig >> subn_sc;
    wire [63:0] subn_lostm = (64'd1 << subn_sc) - 64'd1;
    wire        subn_lost  = |(xSig & subn_lostm);
    wire [23:0] subn_sig24 = subn_shift[63:40];
    wire        subn_guard = subn_shift[39];
    wire        subn_stky  = (|subn_shift[38:0]) | subn_lost;
    wire        subn_rup   = subn_guard & (subn_stky | subn_sig24[0]);   // RTNE
    wire [24:0] subn_M     = {1'b0, subn_sig24} + {24'd0, subn_rup};
    wire        subn_minnm = subn_M[23];                   // rounded to min-normal
    wire        subn_inex  = subn_guard | subn_stky;
    wire [7:0]  subn_exp   = subn_minnm ? 8'd1 : 8'd0;
    wire [22:0] subn_frac  = subn_M[22:0];

    // ---- NaN payload: top 23 fraction bits, QNaN-bit forced on ----------
    wire [22:0] nan_frac = xSig[62:40] | 23'h400000;

    // ---- assemble -------------------------------------------------------
    reg  [7:0]  exp_out;
    reg  [22:0] frac_out;
    always @(*) begin
        if (is_zero) begin
            exp_out = 8'd0;        frac_out = 23'd0;
        end else if (is_inf || ovf) begin
            exp_out = 8'hFF;       frac_out = 23'd0;       // +/-Inf
        end else if (is_nan) begin
            exp_out = 8'hFF;       frac_out = nan_frac;
        end else if (unf) begin
            exp_out = subn_exp;    frac_out = subn_frac;     // denormal (iter-121)
        end else begin
            exp_out = e_adj[7:0];  frac_out = frac_n;        // normal
        end
    end

    assign z  = {xSign, exp_out, frac_out};
    // UE/PE on a narrowing store follow Bochs masked semantics: tiny AND
    // inexact (an exact subnormal raises neither).  iter-121.
    assign pe = (normal & inexact) | ovf | (unf & subn_inex);
    assign oe = ovf;
    assign ue = unf & subn_inex;
    assign ie = is_snan;

endmodule
