// floatx80_sqrt.v
//
// PR-2b.5t (iter 137): combinational FSQRT (D9 FA) primitive.  Computes
// ST(0) <- sqrt(ST(0)) per Bochs floatx80_sqrt (cpu/fpu/softfloat.cc:3405).
//
// Special-operand cascade (Bochs priority order):
//   1. NaN              -> propagateFloatx80NaN; IE iff an SNaN input.
//   2. +Inf             -> return a   (no flag).
//   3. -Inf / negative  -> QNaN indefinite + IE  (invalid operation).
//      finite (non -0)      (-Inf is handled here, BEFORE the denormal arm, so a
//                            negative denormal raises IE, not DE.)
//   4. +/-0             -> return a   (preserves the sign of zero).
//   5. +denormal        -> DE; normalize, then take the normal-path root.
//   6. +normal          -> root; PE iff the root is inexact.
//
// ROUNDING: round-to-nearest-even only (the FNINIT-default RC).  sqrt can never
// produce an exact RNE tie -- (root + 0.5)^2 = root^2 + root + 0.25 is never an
// integer, so the residual can never equal the half-way point -- hence
// round_up = (residual > root) is exact RNE with no tie-break needed.  Directed
// RC (CW[11:10]) pack is deferred, matching the FRNDINT/FPREM staging.
//
// No UE/OE/ZE: sqrt halves the exponent, so a normal/denormal positive operand
// always maps into the normal floatx80 range (sqrt of the smallest denormal,
// ~2^-8191, is still a normal); the result never overflows or underflows.
//
// Sim-only: the 128-bit integer square root below is a behavioral digit-by-digit
// (restoring) sqrt.  Like softfloat_div_x80.v / floatx80_remainder.v's native
// divide, it inherits the standing synth-blocker and must be rebuilt as an
// iterative multi-cycle datapath before any FPGA build that includes the FPU.

`timescale 1ns / 1ps

module floatx80_sqrt (
    input  wire [79:0] a,
    output wire [79:0] z,
    output wire [5:0]  flags          // {PE, UE, OE, ZE, DE, IE}
);

    wire a_sign = a[79];

    //--------------------------------------------------------------------
    // Special-operand classifiers (shared modules, already in the arith
    // primitives' compile list).  b is tied to a -- this is a unary op and
    // the handlers only need their a-side results.
    //--------------------------------------------------------------------
    wire        is_nan_a, is_nan_b, is_any_nan, is_any_snan;
    wire [79:0] z_nan;
    wire [5:0]  flags_nan;
    floatx80_nan_handle u_nan (
        .a(a), .b(a),
        .is_nan_a(is_nan_a), .is_nan_b(is_nan_b),
        .is_any_nan(is_any_nan), .is_any_snan(is_any_snan),
        .z_nan(z_nan), .flags_nan(flags_nan)
    );

    wire is_inf_a, is_inf_b, is_any_inf;
    floatx80_inf_handle u_inf (
        .a(a), .b(a),
        .is_inf_a(is_inf_a), .is_inf_b(is_inf_b), .is_any_inf(is_any_inf)
    );

    wire is_zero_a, is_zero_b, is_any_zero;
    floatx80_zero_handle u_zero (
        .a(a), .b(a),
        .is_zero_a(is_zero_a), .is_zero_b(is_zero_b), .is_any_zero(is_any_zero)
    );

    wire is_subn_a, is_subn_b, is_any_subn;
    floatx80_subn_handle u_subn (
        .a(a), .b(a),
        .is_subn_a(is_subn_a), .is_subn_b(is_subn_b), .is_any_subn(is_any_subn)
    );

    //--------------------------------------------------------------------
    // Normalize the operand.  Pass-through for normals (exp_out = raw biased
    // exp widened to signed-17; sig_out = a_sig); a positive denormal goes
    // negative-exponent with the J-bit shifted in, so the root math below is
    // IEEE-correct.
    //--------------------------------------------------------------------
    wire               a_sign_n;
    wire signed [16:0] a_exp_n;
    wire [63:0]        a_sig_n;
    floatx80_normalize u_norm_a (.a(a), .sign_out(a_sign_n), .exp_out(a_exp_n), .sig_out(a_sig_n));

    //--------------------------------------------------------------------
    // Exponent + significand setup.
    //   diff      = aExp - bias (the value's binary exponent, point after b63).
    //   parity    = diff[0]  (LSB; selects the 63- vs 64-bit pre-shift).
    //   zexp_pre  = floor(diff/2) + bias  ((diff >>> 1) is arithmetic).
    //   M         = aSig << (63 + parity).  M lands in [2^126, 2^128) so the
    //               integer root lands in [2^63, 2^64) (J-bit set).
    //--------------------------------------------------------------------
    wire signed [16:0] diff     = a_exp_n - 17'sd16383;
    wire               parity   = diff[0];
    wire signed [16:0] zexp_pre = (diff >>> 1) + 17'sd16383;
    wire [127:0]       M        = {64'd0, a_sig_n} << (parity ? 7'd64 : 7'd63);

    //--------------------------------------------------------------------
    // Behavioral 128-bit integer square root (restoring / digit-by-digit).
    // 64 iterations: `one` walks 2^126, 2^124, ... , 2^0.  At the end res_r
    // = floor(sqrt(M)) (the 64-bit root) and op_r = M - root^2 (residual).
    //--------------------------------------------------------------------
    reg [127:0] op_r, res_r, one_r;
    integer k;
    always @* begin
        op_r  = M;
        res_r = 128'd0;
        one_r = 128'd1 << 126;
        for (k = 0; k < 64; k = k + 1) begin
            if (op_r >= res_r + one_r) begin
                op_r  = op_r - (res_r + one_r);
                res_r = (res_r >> 1) + one_r;
            end else begin
                res_r = res_r >> 1;
            end
            one_r = one_r >> 2;
        end
    end

    wire [63:0]  root  = res_r[63:0];
    wire [127:0] resid = op_r;

    //--------------------------------------------------------------------
    // Round-to-nearest-even.  inexact iff residual != 0; round up iff the
    // residual is past the half-way point (residual > root).  A round-up that
    // carries out of bit 63 (root == all ones) bumps to 2^63 with exp+1 --
    // provably impossible for M <= 2^128 - 2^64, kept as defensive logic.
    //--------------------------------------------------------------------
    wire        inexact  = (resid != 128'd0);
    wire        round_up = (resid > {64'd0, root});
    wire        carry    = (root == 64'hFFFFFFFFFFFFFFFF) & round_up;
    wire [63:0] zsig0    = carry ? 64'h8000000000000000 : (root + {63'd0, round_up});
    wire signed [16:0] zexp = carry ? (zexp_pre + 17'sd1) : zexp_pre;

    //--------------------------------------------------------------------
    // Special-operand cascade.  NaN > +Inf > negative(incl -Inf) > +/-0 >
    // (positive denormal / positive normal computed root).
    //--------------------------------------------------------------------
    wire [79:0] qnan_indef = {1'b1, 15'h7FFF, 64'hC000000000000000};

    wire spec_nan  = is_any_nan;
    wire spec_pinf = ~spec_nan & is_inf_a & ~a_sign;                  // +Inf -> a
    wire spec_neg  = ~spec_nan & ~spec_pinf & a_sign & ~is_zero_a;    // -Inf / negative finite -> IE+QNaN
    wire spec_zero = ~spec_nan & ~spec_pinf & ~spec_neg & is_zero_a;  // +/-0 -> return a (keep zero sign)
    wire is_special = spec_nan | spec_pinf | spec_neg | spec_zero;

    //--------------------------------------------------------------------
    // Output mux: special > computed positive root.  The computed root is
    // always positive (sqrt of a positive value).
    //--------------------------------------------------------------------
    assign z = spec_nan  ? z_nan
             : spec_pinf ? a
             : spec_neg  ? qnan_indef
             : spec_zero ? a
                         : {1'b0, zexp[14:0], zsig0};

    // IE: SNaN input or a negative (non-zero) operand / -Inf.
    wire ie_w = (spec_nan & is_any_snan) | spec_neg;
    // DE: a positive denormal operand on the computed path (negatives are IE).
    wire de_w = ~is_special & is_subn_a;
    // PE: inexact root on the computed path only.
    wire pe_w = ~is_special & inexact;

    assign flags = {pe_w, 1'b0, 1'b0, 1'b0, de_w, ie_w};

endmodule
