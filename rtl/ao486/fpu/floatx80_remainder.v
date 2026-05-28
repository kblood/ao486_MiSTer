// floatx80_remainder.v
//
// PR-2b.5r (iter 134): combinational FPREM (D9 F8, round-to-zero quotient) /
// FPREM1 (D9 F5, round-to-nearest-even quotient) primitive.  Computes
// ST(0) mod ST(1) per Bochs do_fprem (cpu/fpu/fprem.cc:48) — see
// research/design_fprem.md for the full derivation.
//
// SCOPE (Slice 1): finite NORMAL operands only.  Special operands (NaN, Inf,
// b=0, denormal) are routed to a Slice-2 stub (QNaN+IE) so they can't
// X-propagate through the native divide; faithful NaN-propagate / Inf / b=0-IE
// / denormal-DE semantics are Slice 2.  The subnormal-REMAINDER UE encoding is
// likewise deferred (the helper flushes to zero) — none of the Slice-1 smoke
// vectors produce a subnormal remainder.
//
// Native-divide shortcut: estimateDiv128To64 + Bochs's correction loop together
// compute the UNIQUE floor(num/bSig) and num%bSig, so they collapse to Verilog
// native 128-bit `/` and `%`, exactly as softfloat_div_x80.v does.  Sim-only —
// inherits the standing synth-blocker (combinational 128/64 divide).

`timescale 1ns / 1ps

module floatx80_remainder (
    input  wire [79:0] a,
    input  wire [79:0] b,
    input  wire        rnd_nearest,   // 1 = FPREM1 (RTNE quotient), 0 = FPREM (RTZ)
    output wire [79:0] z,
    output wire [2:0]  quotient,      // low 3 bits of q -> {C0=q[2], C3=q[1], C1=q[0]}
    output wire        incomplete,    // -> C2 (partial reduction, expDiff >= 64)
    output wire [5:0]  flags          // {PE, UE, OE, ZE, DE, IE}
);

    wire        a_sign = a[79];
    wire [14:0] a_exp  = a[78:64];
    wire [63:0] a_sig  = a[63:0];
    wire [14:0] b_exp  = b[78:64];
    wire [63:0] b_sig  = b[63:0];

    //--------------------------------------------------------------------
    // Slice-2 deferral guard: route special operands away from the native
    // divide (prevents X-propagation).  NOT faithful semantics.
    //--------------------------------------------------------------------
    wire a_special = (a_exp == 15'h7FFF);
    wire b_special = (b_exp == 15'h7FFF);
    wire b_zero    = (b_exp == 15'h0000) && (b_sig == 64'd0);
    wire is_special = a_special | b_special | b_zero;

    wire signed [16:0] expDiff = $signed({2'b00, a_exp}) - $signed({2'b00, b_exp});

    //--------------------------------------------------------------------
    // INCOMPLETE path: expDiff >= 64.  n = (expDiff & 0x1f) | 0x20  (32..63);
    // one kernel step; q discarded (=> 0); zExp = aExp - n.
    //--------------------------------------------------------------------
    wire incomplete_w = (expDiff >= $signed(17'sd64));
    wire [5:0]  n_inc   = {1'b1, expDiff[4:0]};
    wire [127:0] num_inc = {64'd0, a_sig} << n_inc;
    wire [63:0]  rem_inc = (num_inc % {64'd0, b_sig});
    wire signed [16:0] zexp_inc = $signed({2'b00, a_exp}) - $signed({11'd0, n_inc});

    //--------------------------------------------------------------------
    // COMPLETE path: expDiff < 64.
    //   expDiff < -1 : remainder = a (b dwarfs a).
    //   expDiff ==-1 : shift aSig right 1, then treat as expDiff == 0.
    //   1..63        : native-divide kernel.
    //   == 0         : single conditional subtract.
    //--------------------------------------------------------------------
    wire passthru = (expDiff < -$signed(17'sd1));
    wire is_neg1  = (expDiff == -$signed(17'sd1));

    wire [63:0] aSig0_pre = is_neg1 ? {1'b0, a_sig[63:1]} : a_sig;
    wire [63:0] aSig1_pre = is_neg1 ? {a_sig[0], 63'd0}   : 64'd0;

    wire is_kernel = (expDiff > $signed(17'sd0)) && ~incomplete_w;   // 1..63
    wire [5:0]  ediff6 = expDiff[5:0];

    // kernel: aSig0_pre == a_sig here (the -1 pre-shift only feeds expDiff==0).
    wire [127:0] num_k   = {64'd0, a_sig} << ediff6;
    wire [127:0] q_k     = num_k / {64'd0, b_sig};
    wire [63:0]  rem_k   = (num_k % {64'd0, b_sig});

    // expDiff == 0 (incl. the -1-shifted case): one conditional subtract.
    wire        z0_sub  = (b_sig <= aSig0_pre);
    wire [63:0] z0_sig0 = z0_sub ? (aSig0_pre - b_sig) : aSig0_pre;
    wire [63:0] z0_sig1 = aSig1_pre;

    // Pre-correction complete-path significand + quotient.
    wire [63:0] cmpl_sig0 = is_kernel ? rem_k        : z0_sig0;
    wire [63:0] cmpl_sig1 = is_kernel ? 64'd0        : z0_sig1;
    wire [63:0] cmpl_q    = is_kernel ? q_k[63:0]    : (z0_sub ? 64'd1 : 64'd0);

    //--------------------------------------------------------------------
    // FPREM1 round-to-nearest-even quotient correction (rnd_nearest only).
    // Compare the 128-bit remainder to bSig/2; on rem >= b/2 maybe flip the
    // sign, ++q, and reflect the remainder (b - rem).
    //--------------------------------------------------------------------
    wire [63:0] half0 = {1'b0, b_sig[63:1]};   // shift128Right(bSig,0,1) hi
    wire [63:0] half1 = {b_sig[0], 63'd0};      //                        lo

    wire rem_lt_half = (cmpl_sig0 <  half0) ||
                       ((cmpl_sig0 == half0) && (cmpl_sig1 <  half1));
    wire rem_eq_half = (cmpl_sig0 == half0) && (cmpl_sig1 == half1);
    wire half_lt_rem = (half0 <  cmpl_sig0) ||
                       ((half0 == cmpl_sig0) && (half1 <  cmpl_sig1));

    wire do_corr   = rnd_nearest && ~rem_lt_half;                   // rem >= b/2
    wire corr_incr = do_corr && ((rem_eq_half && cmpl_q[0]) || half_lt_rem);
    wire corr_sub  = do_corr && half_lt_rem;

    wire [127:0] refl = {b_sig, 64'd0} - {cmpl_sig0, cmpl_sig1};    // sub128(b, rem)

    wire        corr_sign = a_sign ^ corr_incr;                     // aSign = !aSign
    wire [63:0] corr_sig0 = corr_sub ? refl[127:64] : cmpl_sig0;
    wire [63:0] corr_sig1 = corr_sub ? refl[63:0]   : cmpl_sig1;
    wire [63:0] corr_q    = cmpl_q + {63'd0, corr_incr};

    //--------------------------------------------------------------------
    // Final operands for normalizeRoundAndPackFloatx80.
    //--------------------------------------------------------------------
    wire        final_sign = incomplete_w ? a_sign                    : corr_sign;
    wire signed [16:0] final_exp = incomplete_w ? zexp_inc            : $signed({2'b00, b_exp});
    wire [63:0] final_sig0 = incomplete_w ? rem_inc                   : corr_sig0;
    wire [63:0] final_sig1 = incomplete_w ? 64'd0                     : corr_sig1;
    wire [63:0] final_q    = incomplete_w ? 64'd0                     : corr_q;

    wire [79:0] pack_z;
    wire        pack_pe, pack_ue;
    floatx80_norm_round_pack u_pack (
        .sign     (final_sign),
        .z_exp_in (final_exp),
        .sig0_in  (final_sig0),
        .sig1_in  (final_sig1),
        .z        (pack_z),
        .pe       (pack_pe),
        .ue       (pack_ue)
    );

    //--------------------------------------------------------------------
    // Output mux: special(stub) > passthru(=a) > packed result.
    //--------------------------------------------------------------------
    wire [79:0] qnan_indef = {1'b1, 15'h7FFF, 64'hC000000000000000};

    assign z = is_special ? qnan_indef
             : passthru   ? a
                          : pack_z;

    assign incomplete = ~is_special & ~passthru & incomplete_w;
    assign quotient   = (is_special | passthru | incomplete_w) ? 3'd0 : final_q[2:0];

    wire pe_w = ~is_special & ~passthru & pack_pe;
    wire ue_w = ~is_special & ~passthru & pack_ue;
    wire ie_w = is_special;                            // Slice-2 stub
    assign flags = {pe_w, ue_w, 1'b0, 1'b0, 1'b0, ie_w};

endmodule
