// PR-2c.26 (iter 179): UNIFIED floatx80 -> single/double NARROWING converter
// with round-to-nearest-even.  Runtime-shared replacement for
// floatx80_to_float32.v + floatx80_to_float64.v.
//
// FST/FSTP m32 and FST/FSTP m64 are mutually exclusive in any given op, so a
// single runtime-muxed instance serves both widths and reclaims the duplicated
// rounding adder + subnormal shift/round/pack datapath the two modules carried
// (the iter-179 dedupe slice).
//
// The two originals are structurally identical: classification (is_zero/inf/
// nan/snan, all keyed on xExp==0x7FFF) is BYTE-IDENTICAL across widths.  Only
// these differ, and only these are width-muxed here:
//   * drop      = #significand bits below the kept field  (40 for f32, 11 f64)
//   * bias delta= 16383 - target_bias                     (16256 / 15360)
//   * ovf field = Inf exponent field                      (255 / 2047)
//   * field widths at assemble                            (8/23  vs 11/52)
// Everything else (round point, subnormal grid, NaN-payload top bits) is
// expressed via the muxed `drop`, so ONE datapath produces both results.
//
// `a` is ST(0) (floatx80).  `is_m64` selects double (= the store-m64 lane).
// `z` carries the f32 result in [31:0] / the f64 result in [63:0].
// pe/oe/ue/ie mirror the originals (PE inexact, OE overflow->Inf, UE tiny&
// inexact masked subnormal, IE SNaN); the caller muxes z + drives is_m64.
//
// Proven bit-exact vs the two frozen originals by floatx80_to_floatN_tb.v.

module floatx80_to_floatN (
    input  wire [79:0] a,
    input  wire        is_m64,
    output wire [63:0] z,
    output wire        pe,   // precision (inexact)
    output wire        oe,   // overflow
    output wire        ue,   // underflow (tiny & inexact, masked)
    output wire        ie    // invalid (SNaN input)
);

    wire        xSign = a[79];
    wire [14:0] xExp  = a[78:64];
    wire [63:0] xSig  = a[63:0];

    // ---- classification (width-INDEPENDENT) -----------------------------
    wire is_zero = (xExp == 15'd0)    && (xSig == 64'd0);
    wire is_inf  = (xExp == 15'h7FFF) && (xSig == 64'h8000000000000000);
    wire is_nan  = (xExp == 15'h7FFF) && (xSig[62:0] != 63'd0);
    wire is_snan = is_nan && (xSig[62] == 1'b0);
    wire is_special = is_zero | is_inf | is_nan;

    // ---- width-specific constants ---------------------------------------
    wire [6:0]  drop  = is_m64 ? 7'd11 : 7'd40;   // bits below kept field
    wire [6:0]  dropm = drop - 7'd1;              // guard-bit index (10 / 39)
    wire [6:0]  kbits = 7'd64 - drop;             // kept width incl. J (53 / 24)
    wire [6:0]  fracw = kbits - 7'd1;             // stored fraction width (52/23)
    wire [63:0] mask_g = ({64{1'b1}} >> (7'd64 - dropm)); // low dropm bits = 1

    // ---- normal-path exponent rebias (signed) ---------------------------
    wire signed [16:0] e = $signed({2'b00, xExp})
                         - (is_m64 ? 17'sd15360 : 17'sd16256);

    // ---- round the top kbits (J + fracw frac) to nearest-even -----------
    wire [63:0] kept      = xSig >> drop;          // kept significand, right-aligned
    wire [63:0] xsig_g    = xSig >> dropm;
    wire        guard     = xsig_g[0];
    wire        sticky    = |(xSig & mask_g);
    wire        round_up  = guard & (sticky | kept[0]);
    wire [63:0] kept_rnd  = kept + {63'd0, round_up};
    wire [63:0] carry_vec = kept_rnd >> kbits;     // bit kbits = carry-out of J
    wire        carry     = carry_vec[0];
    wire signed [16:0] e_adj = carry ? (e + 17'sd1) : e;
    wire [63:0] frac_n    = carry ? 64'd0 : kept_rnd;  // low fracw bits used
    wire        inexact   = guard | sticky;

    // ---- normal vs overflow vs underflow (after rounding) ---------------
    wire signed [16:0] ovf_thr = is_m64 ? 17'sd2047 : 17'sd255;
    wire ovf    = !is_special && (e_adj >= ovf_thr);
    wire unf    = !is_special && (e_adj <= 17'sd0);
    wire normal = !is_special && !ovf && !unf;

    // ---- subnormal pack -------------------------------------------------
    wire signed [16:0] subn_sc_s = 17'sd1 - e;           // e <= 0 here -> >= 1
    wire [6:0]  subn_sc    = (subn_sc_s >= 17'sd63) ? 7'd63 : subn_sc_s[6:0];
    wire [63:0] subn_shift = xSig >> subn_sc;
    wire [63:0] subn_lostm = (64'd1 << subn_sc) - 64'd1;
    wire        subn_lost  = |(xSig & subn_lostm);
    wire [63:0] subn_sig   = subn_shift >> drop;
    wire [63:0] subn_g_vec = subn_shift >> dropm;
    wire        subn_guard = subn_g_vec[0];
    wire        subn_stky  = |(subn_shift & mask_g) | subn_lost;
    wire        subn_rup   = subn_guard & (subn_stky | subn_sig[0]);  // RTNE
    wire [63:0] subn_M     = subn_sig + {63'd0, subn_rup};
    wire [63:0] subn_mm    = subn_M >> fracw;            // bit fracw = min-normal
    wire        subn_minnm = subn_mm[0];
    wire        subn_inex  = subn_guard | subn_stky;
    wire [10:0] subn_exp   = subn_minnm ? 11'd1 : 11'd0;
    wire [51:0] subn_frac  = subn_M[51:0];

    // ---- NaN payload: top fracw fraction bits, QNaN-bit forced on -------
    // The QNaN bit sits at index (fracw-1) of the stored fraction == bit
    // (fracw-1) of `kept` (kept holds xSig[62:drop] in its low fracw bits).
    wire [63:0] nan_frac_full = kept | (64'd1 << (fracw - 7'd1));

    // ---- assemble (max-width regs; sliced per width at z below) ---------
    reg  [10:0] exp_full;
    reg  [51:0] frac_full;
    wire [10:0] inf_exp = is_m64 ? 11'h7FF : 11'h0FF;
    always @(*) begin
        if (is_zero) begin
            exp_full = 11'd0;          frac_full = 52'd0;
        end else if (is_inf || ovf) begin
            exp_full = inf_exp;        frac_full = 52'd0;
        end else if (is_nan) begin
            exp_full = inf_exp;        frac_full = nan_frac_full[51:0];
        end else if (unf) begin
            exp_full = subn_exp;       frac_full = subn_frac;
        end else begin
            exp_full = e_adj[10:0];    frac_full = frac_n[51:0];
        end
    end

    assign z  = is_m64 ? {xSign, exp_full[10:0], frac_full[51:0]}
                       : {32'd0, xSign, exp_full[7:0], frac_full[22:0]};
    assign pe = (normal & inexact) | ovf | (unf & subn_inex);
    assign oe = ovf;
    assign ue = unf & subn_inex;
    assign ie = is_snan;

endmodule
