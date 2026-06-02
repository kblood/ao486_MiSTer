// fpu_transcendental.v
//
// The x87 transcendental engine.  Time-multiplexes the SHARED floatx80 mul/add
// (combinational, settled) + the SHARED clocked divider (u_div) in execute_fpu
// over coefficient ROMs, walking the Bochs polynomial recurrences.  Owns NO
// arithmetic of its own ("Option X80", research/design_transcendentals.md §3).
//
// Implemented slices:
//   T-1 (iter 187): F2XM1  (D9 F0)  ST0 <- 2^ST0 - 1, |ST0|<=1
//   T-2 (iter 188): FYL2X  (D9 F1)  ST1 <- ST1*log2(ST0), pop
//                   FYL2XP1(D9 F9)  ST1 <- ST1*log2(ST0+1), pop
//   T-3 (iter 189): FPATAN (D9 F3)  ST1 <- atan2(ST1,ST0), pop
//   T-4 (iter 190): FSIN   (D9 FE)  ST0 <- sin(ST0)
//                   FCOS   (D9 FF)  ST0 <- cos(ST0)
// The remaining two (FPTAN/FSINCOS) still route here and take the deterministic
// PASSTHROUGH (ST0 unchanged) until T-5 lands.
//
// FSIN/FCOS argument reduction (research/design_transcendentals.md, T-4 study):
// Bochs reduces x mod pi/2 in 128-bit integer precision; we keep the Option-X80
// promise (NO new wide datapath) with a 3-part Cody-Waite pi/2 (HP0/HP1 low-32-
// zeroed, HP2 full) and a 2-chunk q split: q=round(x*2/pi) is split into
// qhi*2^32+qlo so every qchunk*HPi product (<=64 sig bits) is EXACT in a plain
// floatx80 mul.  r = x - sum(qchunk*HPi) lands in [-pi/4,pi/4]; quadrant q&3
// selects sin/cos(r) and sign.  Model (sim/transc_model/fsincos_model.py) proved
// <=2 ULP vs the exact-reduction float128 reference for |x|<2^54 (every real
// angle and far beyond).  |x|>=2^63 (expDiff>=63) is x87 out-of-range: C2=1,
// ST0 unchanged, no reduction.
//
// SHARED-ARITH PROTOCOL (execute_fpu wires arith_a/arith_b/arith_op into the
// op_a/op_b + eff_kind muxes; arith_z = mul_or_addsub_z; div_* = u_div):
//   * mul/add step: drive arith_a/arith_b, arith_op=KIND_MUL|KIND_ADD, dwell
//     WAIT settle cycles (the ~106 ns floatx80 chain, same as S_ARITHWAIT),
//     then sample arith_z.  (x-1 is an ADD with a negated operand -- the add
//     primitive routes to sub internally when signs differ -- so no SUB kind.)
//   * divide step: drive arith_a(num)/arith_b(den), arith_op=KIND_DIV, dwell
//     WAIT cycles so the shared input-normalizer settles, pulse div_start for
//     one cycle, then park until div_done and sample div_z.  arith_op stays
//     KIND_DIV through div_done so the shared rounder keeps routing pr_*_div.
//
// ACCURACY (validated in sim/transc_model/ before RTL): the floatx80 Horner of
// the Bochs poly is <= 2 ULP from the Bochs float128 reference across the whole
// normal range -- inside the +/-2 ULP x87 transcendental tolerance.  No guard
// bits needed.  (F2XM1 <=1.05 ULP, FYL2X <=2 ULP, FYL2XP1 <=1 ULP.)
//
// ALGORITHM (Bochs cpu/fpu/{f2xm1,fyl2x,poly}.cc):
//   F2XM1 : t=x*ln2 ; r=exp_arr[14] ; 14x(r=r*t; r=r+exp_arr[k-1]) ; z=r*t
//   FYL2X : reduce ST0 -> x in [sqrt2/2,sqrt2), ExpDiff = floor(log2(ST0))(+1);
//           u=(x-1)/(x+1) ; ln = u*EvalPoly(u^2,ln_arr,9) ; l2 = ln*(2/ln2) ;
//           z = ST1 * (l2 + ExpDiff)
//   FYL2XP1: |a|>=1/8 -> FYL2X(a+1,ST1).  else u=a/(a+2) ; same ln/l2 ;
//           z = ST1 * l2   (no ExpDiff -- |log2(1+a)|<1)
//   EvalPoly(y,arr,9): r=arr[8]; 8x(r=r*y; r=r+arr[k]).  OddPoly outer mul by u.
//   FPATAN: x=min(|a|,|b|)/max(|a|,|b|) ; octant: x>=3/4 -> (x-1)/(x+1)+pi/4,
//           1/4<=x<3/4 -> (x*sqrt3-1)/(x+sqrt3)+pi/6, x<1/4 -> none ;
//           atan = OddPoly(x,atan_arr,11) (+corr) ; swap(|a|<=|b|): pi/2-atan ;
//           sign: negate by aSign^bSign, then +/- pi to land atan2 in (-pi,pi].

`timescale 1ns / 1ps

module fpu_transcendental (
    input  wire        clk,
    input  wire        rst,        // ~rst_n | exe_reset | init (mirror u_div)
    input  wire        start,      // 1-cycle pulse: latch a/b, begin op
    input  wire [3:0]  cmdex,      // CMDEX_* selecting the op
    input  wire [79:0] a,          // ST(0) operand at op start
    input  wire [79:0] b,          // ST(1) operand at op start (FYL2X/FYL2XP1)

    // Shared mul/add request/response (combinational, settled after WAIT):
    output reg  [79:0] arith_a,
    output reg  [79:0] arith_b,
    output reg  [1:0]  arith_op,       // KIND_ADD / KIND_MUL / KIND_DIV
    input  wire [79:0] arith_z,        // = mul_or_addsub_z (settled mul/add)

    // Shared clocked divider (u_div) request/response:
    output reg         div_start,      // 1-cycle pulse to launch u_div
    input  wire [79:0] div_z,
    input  wire        div_done,

    output reg         done,           // 1-cycle pulse: z/flags valid
    output reg  [79:0] z,
    output reg  [5:0]  flags,           // {PE,UE,OE,ZE,DE,IE}
    output reg         c2               // SW C2: 1 = FSIN/FCOS arg out of range
);

    // op-kind encoding -- MUST match execute_fpu.v's KIND_* localparams.
    localparam [1:0] KIND_ADD = 2'd0, KIND_MUL = 2'd2, KIND_DIV = 2'd3;

    // CMDEX selectors (research/design_transcendentals.md §5).
    localparam [3:0] CMDEX_F2XM1 = 4'd0, CMDEX_FYL2X = 4'd1, CMDEX_FPATAN = 4'd3,
                     CMDEX_FYL2XP1 = 4'd4, CMDEX_FSIN = 4'd5, CMDEX_FCOS = 4'd6;

    // Settle dwell per shared-arith op (>= ARITH_WAIT_CYCLES / sdc -setup N).
    localparam [4:0] WAIT = 5'd12;

    // ----- F2XM1 coefficient ROM: exp_arr[i] = floatx80(1/(i+1)!) -----------
    function [79:0] exp_coeff(input [3:0] i);
        case (i)
            4'd0 : exp_coeff = 80'h3fff8000000000000000; // 1/1!
            4'd1 : exp_coeff = 80'h3ffe8000000000000000; // 1/2!
            4'd2 : exp_coeff = 80'h3ffcaaaaaaaaaaaaaaab; // 1/3!
            4'd3 : exp_coeff = 80'h3ffaaaaaaaaaaaaaaaab; // 1/4!
            4'd4 : exp_coeff = 80'h3ff88888888888888889; // 1/5!
            4'd5 : exp_coeff = 80'h3ff5b60b60b60b60b60b; // 1/6!
            4'd6 : exp_coeff = 80'h3ff2d00d00d00d00d00d; // 1/7!
            4'd7 : exp_coeff = 80'h3fefd00d00d00d00d00d; // 1/8!
            4'd8 : exp_coeff = 80'h3fecb8ef1d2ab6399c7d; // 1/9!
            4'd9 : exp_coeff = 80'h3fe993f27dbbc4fae397; // 1/10!
            4'd10: exp_coeff = 80'h3fe5d7322b3faa271c7f; // 1/11!
            4'd11: exp_coeff = 80'h3fe28f76c77fc6c4bdaa; // 1/12!
            4'd12: exp_coeff = 80'h3fdeb092309d43684be5; // 1/13!
            4'd13: exp_coeff = 80'h3fdac9cba54603e4e906; // 1/14!
            4'd14: exp_coeff = 80'h3fd6d73f9f399dc0f88f; // 1/15!
            default: exp_coeff = 80'h3fff8000000000000000;
        endcase
    endfunction

    // ----- FYL2X coefficient ROM: ln_arr[i], floatx80-truncated -------------
    // OddPoly over u^2: 1, 1/3, 1/5, 1/7, ... 1/17 (indices 0..8).
    function [79:0] ln_coeff(input [3:0] i);
        case (i)
            4'd0 : ln_coeff = 80'h3fff8000000000000000; // 1
            4'd1 : ln_coeff = 80'h3ffdaaaaaaaaaaaaaaab; // 1/3
            4'd2 : ln_coeff = 80'h3ffccccccccccccccccd; // 1/5
            4'd3 : ln_coeff = 80'h3ffc9249249249249249; // 1/7
            4'd4 : ln_coeff = 80'h3ffbe38e38e38e38e38e; // 1/9
            4'd5 : ln_coeff = 80'h3ffbba2e8ba2e8ba2e8c; // 1/11
            4'd6 : ln_coeff = 80'h3ffb9d89d89d89d89d8a; // 1/13
            4'd7 : ln_coeff = 80'h3ffb8888888888888889; // 1/15
            4'd8 : ln_coeff = 80'h3ffaf0f0f0f0f0f0f0f1; // 1/17
            default: ln_coeff = 80'h3fff8000000000000000;
        endcase
    endfunction

    localparam [79:0] LN2      = 80'h3ffeb17217f7d1cf79ac; // ln2
    localparam [79:0] LN2INV2  = 80'h4000b8aa3b295c17f0bc; // 2/ln2
    localparam [79:0] ONE      = 80'h3fff8000000000000000; //  1.0
    localparam [79:0] NEG_ONE  = 80'hbfff8000000000000000; // -1.0
    localparam [79:0] NEG_HALF = 80'hbffe8000000000000000; // -0.5
    localparam [79:0] TWO      = 80'h40008000000000000000; //  2.0
    localparam [79:0] PINF     = 80'h7fff8000000000000000; // +Inf
    localparam [79:0] DEFNAN   = 80'hffffc000000000000000; // x87 indefinite QNaN
    localparam [63:0] SQRT2_HALF_SIG = 64'hb504f333f9de6484;

    // ----- FPATAN constants (floatx80-truncated from Bochs float128) --------
    localparam [79:0] PI80      = 80'h4000c90fdaa22168c235; //  pi
    localparam [79:0] PI2_80    = 80'h3fffc90fdaa22168c235; //  pi/2
    localparam [79:0] PI4_80    = 80'h3ffec90fdaa22168c235; //  pi/4
    localparam [79:0] PI6_80    = 80'h3ffe860a91c16b9b2c23; //  pi/6
    localparam [79:0] THREEPI4  = 80'h400096cbe3f9990e91a8; //  3pi/4
    localparam [79:0] SQRT3_80  = 80'h3fffddb3d742c265539e; //  sqrt(3)

    // ----- FPATAN coefficient ROM: atan_arr[i], floatx80-truncated ---------
    // OddPoly over x^2: 1, -1/3, 1/5, -1/7, ... 1/21 (indices 0..10).
    function [79:0] atan_coeff(input [3:0] i);
        case (i)
            4'd0 : atan_coeff = 80'h3fff8000000000000000; //  1
            4'd1 : atan_coeff = 80'hbffdaaaaaaaaaaaaaaab; // -1/3
            4'd2 : atan_coeff = 80'h3ffccccccccccccccccd; //  1/5
            4'd3 : atan_coeff = 80'hbffc9249249249249249; // -1/7
            4'd4 : atan_coeff = 80'h3ffbe38e38e38e38e38e; //  1/9
            4'd5 : atan_coeff = 80'hbffbba2e8ba2e8ba2e8c; // -1/11
            4'd6 : atan_coeff = 80'h3ffb9d89d89d89d89d8a; //  1/13
            4'd7 : atan_coeff = 80'hbffb8888888888888889; // -1/15
            4'd8 : atan_coeff = 80'h3ffaf0f0f0f0f0f0f0f1; //  1/17
            4'd9 : atan_coeff = 80'hbffad79435e50d79435e; // -1/19
            4'd10: atan_coeff = 80'h3ffac30c30c30c30c30c; //  1/21
            default: atan_coeff = 80'h3fff8000000000000000;
        endcase
    endfunction

    // ----- FSIN/FCOS argument-reduction constants (T-4) --------------------
    // 2/pi, and a 3-part Cody-Waite pi/2: HP0,HP1 have their low 32 significand
    // bits zeroed so qchunk*HPi (each <=32 sig bits) is EXACT; HP2 carries the
    // residual.  q = round(x*TWO_OVER_PI); r = x - q*(pi/2) in [-pi/4,pi/4].
    localparam [79:0] TWO_OVER_PI = 80'h3ffea2f9836e4e44152a; // 2/pi
    localparam [79:0] HP0 = 80'h3fffc90fdaa200000000;         // pi/2 hi   (lo32=0)
    localparam [79:0] HP1 = 80'h3fdd85a308d300000000;         // pi/2 mid  (lo32=0)
    localparam [79:0] HP2 = 80'h3fba98cc51701b839a25;         // pi/2 lo   (full)

    // ----- FSIN poly ROM: sin_arr[i] (OddPoly over r^2, outer *r) ----------
    function [79:0] sin_coeff(input [3:0] i);
        case (i)
            4'd0 : sin_coeff = 80'h3fff8000000000000000; //  1
            4'd1 : sin_coeff = 80'hbffcaaaaaaaaaaaaaaab; // -1/3!
            4'd2 : sin_coeff = 80'h3ff88888888888888889; //  1/5!
            4'd3 : sin_coeff = 80'hbff2d00d00d00d00d00d; // -1/7!
            4'd4 : sin_coeff = 80'h3fecb8ef1d2ab6399c7d; //  1/9!
            4'd5 : sin_coeff = 80'hbfe5d7322b3faa271c7f; // -1/11!
            4'd6 : sin_coeff = 80'h3fdeb092309d43684be5; //  1/13!
            4'd7 : sin_coeff = 80'hbfd6d73f9f399dc0f88f; // -1/15!
            4'd8 : sin_coeff = 80'h3fceca963b81856a5359; //  1/17!
            4'd9 : sin_coeff = 80'hbfc697a4da340a0ab926; // -1/19!
            4'd10: sin_coeff = 80'h3fbdb8dc77b6e7ab8c5f; //  1/21!
            default: sin_coeff = 80'h3fff8000000000000000;
        endcase
    endfunction

    // ----- FCOS poly ROM: cos_arr[i] (EvenPoly over r^2, no outer mul) ------
    function [79:0] cos_coeff(input [3:0] i);
        case (i)
            4'd0 : cos_coeff = 80'h3fff8000000000000000; //  1
            4'd1 : cos_coeff = 80'hbffe8000000000000000; // -1/2!
            4'd2 : cos_coeff = 80'h3ffaaaaaaaaaaaaaaaab; //  1/4!
            4'd3 : cos_coeff = 80'hbff5b60b60b60b60b60b; // -1/6!
            4'd4 : cos_coeff = 80'h3fefd00d00d00d00d00d; //  1/8!
            4'd5 : cos_coeff = 80'hbfe993f27dbbc4fae397; // -1/10!
            4'd6 : cos_coeff = 80'h3fe28f76c77fc6c4bdaa; //  1/12!
            4'd7 : cos_coeff = 80'hbfdac9cba54603e4e906; // -1/14!
            4'd8 : cos_coeff = 80'h3fd2d73f9f399dc0f88f; //  1/16!
            4'd9 : cos_coeff = 80'hbfcab413c31dcbecbbde; // -1/18!
            4'd10: cos_coeff = 80'h3fc1f2a15d201011283d; //  1/20!
            default: cos_coeff = 80'h3fff8000000000000000;
        endcase
    endfunction

    // ----- combinational helpers -------------------------------------------
    // count leading zeros of a 64-bit significand (0..63)
    function [6:0] clz64(input [63:0] v);
        integer k; reg done_f;
        begin
            clz64 = 7'd64; done_f = 1'b0;
            for (k = 63; k >= 0; k = k - 1)
                if (!done_f && v[k]) begin clz64 = 63 - k; done_f = 1'b1; end
        end
    endfunction

    // signed-int -> floatx80 (exact; |val| fits ~15 bits for ExpDiff)
    function [79:0] int_to_fx80(input signed [16:0] val);
        reg [15:0] mag; reg sgn; integer k; reg [6:0] p; reg [63:0] sig;
        begin
            if (val == 0) int_to_fx80 = 80'h0;
            else begin
                sgn = val[16];
                mag = sgn ? (~val[15:0] + 16'd1) : val[15:0];
                p = 7'd0;
                for (k = 15; k >= 0; k = k - 1)
                    if (p == 7'd0 && mag[k]) p = k[6:0];
                sig = {48'b0, mag} << (6'd63 - p);
                int_to_fx80 = {sgn, (15'd16383 + {8'b0, p}), sig};
            end
        end
    endfunction

    // floatx80 -> signed int64, round-nearest-even (T-4 q = round(x*2/pi)).
    // |q| < 2^63 by construction (caller gates expDiff < 63), so it fits.
    function signed [63:0] fx80_to_int64(input [79:0] f);
        reg s; reg [14:0] e; reg [63:0] sig;
        integer E, sh; reg [64:0] mag; reg rbit, sticky;
        begin
            s = f[79]; e = f[78:64]; sig = f[63:0];
            if (e == 15'h0) mag = 65'd0;            // zero/denormal -> 0
            else begin
                E = $signed({1'b0, e}) - 16383;     // unbiased exponent
                if (E < -1) mag = 65'd0;            // |f| < 0.5 -> 0
                else if (E >= 63) mag = {1'b0, sig};// (shouldn't happen, gated)
                else begin
                    sh  = 63 - E;                   // 1..64 fraction bits
                    mag = {1'b0, sig} >> sh;        // integer part
                    rbit   = sig[sh-1];
                    sticky = (sh >= 2) ? (|(sig & ((64'd1 << (sh-1)) - 64'd1))) : 1'b0;
                    if (rbit && (sticky || mag[0])) mag = mag + 65'd1;
                end
            end
            fx80_to_int64 = s ? -$signed(mag[63:0]) : $signed(mag[63:0]);
        end
    endfunction

    // signed int64 -> floatx80, EXACT (|v| < 2^63 so <=63 sig bits fit).
    function [79:0] int64_to_fx80(input signed [63:0] v);
        reg sgn; reg [63:0] mag; reg [6:0] lz; reg [14:0] e;
        begin
            if (v == 64'sd0) int64_to_fx80 = 80'h0;
            else begin
                sgn = v[63];
                mag = sgn ? (~v + 64'd1) : v;       // |v|
                lz  = clz64(mag);                   // 0..63
                e   = 15'd16383 + (15'd63 - {8'b0, lz});
                int64_to_fx80 = {sgn, e, (mag << lz)};
            end
        end
    endfunction

    // q split helpers: hi = q with low 32 bits cleared, lo = low 32 bits;
    // sign preserved (truncate toward zero -- NOT floor -- so |q| splits cleanly).
    function signed [63:0] q_hi_signed(input [79:0] qf);
        reg signed [63:0] qi; reg s; reg [63:0] mag, himag;
        begin
            qi = fx80_to_int64(qf);
            s = qi[63]; mag = s ? (~qi + 64'd1) : qi;
            himag = {mag[63:32], 32'b0};            // (|q|>>32)<<32
            q_hi_signed = s ? -$signed(himag) : $signed(himag);
        end
    endfunction
    function signed [63:0] q_lo_signed(input [79:0] qf);
        reg signed [63:0] qi; reg s; reg [63:0] mag, lomag;
        begin
            qi = fx80_to_int64(qf);
            s = qi[63]; mag = s ? (~qi + 64'd1) : qi;
            lomag = {32'b0, mag[31:0]};
            q_lo_signed = s ? -$signed(lomag) : $signed(lomag);
        end
    endfunction

    // ----- operand classification (off a/b directly, valid at start) --------
    wire        aSign = a[79];          wire        bSign = b[79];
    wire [14:0] aExp  = a[78:64];        wire [14:0] bExp  = b[78:64];
    wire [63:0] aSig  = a[63:0];         wire [63:0] bSig  = b[63:0];
    wire a_nan  = (aExp==15'h7FFF) &&  (|aSig[62:0]);
    wire a_inf  = (aExp==15'h7FFF) && ~(|aSig[62:0]);
    wire a_zero = (aExp==15'h0)    && ~(|aSig);
    wire a_den  = (aExp==15'h0)    &&  (|aSig);
    wire a_one  = (aExp==15'h3FFF) && ~(|aSig[62:0]); // |a|==1 (with aSign)
    wire a_snan = a_nan && ~aSig[62];
    wire b_nan  = (bExp==15'h7FFF) &&  (|bSig[62:0]);
    wire b_inf  = (bExp==15'h7FFF) && ~(|bSig[62:0]);
    wire b_zero = (bExp==15'h0)    && ~(|bSig);
    wire b_den  = (bExp==15'h0)    &&  (|bSig);
    wire b_snan = b_nan && ~bSig[62];
    wire propagate_snan = a_snan | b_snan;
    wire [79:0] prop_nan = a_nan ? {a[79],15'h7FFF,1'b1,a[62:0]}
                                 : {b[79],15'h7FFF,1'b1,b[62:0]};

    // normalize a (handle denormal) for the reduce front-end
    wire [6:0]  a_clz   = clz64(aSig);
    wire [63:0] a_nsig  = a_den ? (aSig << a_clz) : aSig;
    wire signed [16:0] a_nexp = a_den ? ($signed({2'b0,15'd1}) - $signed({10'b0,a_clz}))
                                      : $signed({2'b0,aExp});

    // ----- micro-sequencer phases ------------------------------------------
    localparam [5:0]
        P_IDLE  = 6'd0,
        E_XLN2  = 6'd1, E_LMUL = 6'd2, E_LADD = 6'd3, E_FINAL = 6'd4,  // F2XM1
        LG_XP1  = 6'd5, LG_XM1 = 6'd6, LG_DSET = 6'd7, LG_DWAIT = 6'd8,// log
        LG_U2   = 6'd9, LG_HMUL= 6'd10,LG_HADD = 6'd11,
        LG_PL   = 6'd12,LG_L2  = 6'd13,LG_EADD = 6'd14,LG_BMUL = 6'd15,
        PP_BIG  = 6'd16,PP_XP2 = 6'd17,
        P_DONE  = 6'd18,
        // FPATAN (T-3): ratio divide -> octant correction -> OddPoly -> sign
        AT_DSET = 6'd19, AT_DWAIT= 6'd20,                              // shared div
        AT_C4_XP1=6'd21, AT_C4_XM1=6'd22,                             // +pi/4 corr
        AT_C6_MUL=6'd23, AT_C6_ADD=6'd24, AT_C6_SUB=6'd25,            // +pi/6 corr
        AT_P_X2 = 6'd26, AT_P_MUL= 6'd27, AT_P_ADD= 6'd28, AT_P_OUT=6'd29, // poly
        AT_CORR = 6'd30, AT_SWAP = 6'd31, AT_SWAPW= 6'd32,            // +corr / pi/2-x
        AT_SIGN = 6'd33, AT_PIW  = 6'd34,                             // quadrant +/-pi
        // FSIN/FCOS (T-4): x*2/pi -> round/split q -> 3-part reduce -> poly -> quad
        TR_QMUL = 6'd35, TR_QF   = 6'd36,                             // q = round(x*2/pi)
        TR_RIS  = 6'd37, TR_RML  = 6'd38, TR_RSB  = 6'd39,            // r -= qchunk*HPi
        TR_X2   = 6'd40,                                              // rr = r*r
        TR_S_MUL= 6'd41, TR_S_ADD= 6'd42, TR_S_OUT= 6'd43,           // sin Horner+outer
        TR_C_MUL= 6'd44, TR_C_ADD= 6'd45,                            // cos Horner
        TR_QUAD = 6'd46;                                             // quadrant select

    reg [5:0]  phase;
    reg [4:0]  settle;
    reg [3:0]  cnt;       // Horner index
    reg [79:0] t_reg;     // F2XM1 t ; log: u^2
    reg [79:0] u_reg;     // log: u (OddPoly outer factor)
    reg [79:0] den_reg;   // log: divide denominator (x+1 or a+2)
    reg [79:0] b_reg;     // ST(1)
    reg [79:0] xred_reg;  // reduced mantissa in [sqrt2/2, sqrt2)
    reg [79:0] expd_reg;  // ExpDiff as floatx80
    reg        want_ed;   // add ExpDiff after l2 (FYL2X / FYL2XP1-big)
    reg [79:0] a_reg_hold; // ST(0) latched (FYL2XP1 small-arg divide numerator)

    // FPATAN (T-3) state
    reg [79:0] x_reg;     // running reduced value / poly argument
    reg        swap_reg;  // |a|<=|b| -> result = pi/2 - x
    reg [1:0]  add_corr;  // 0 none, 1 +pi/4, 2 +pi/6
    reg        at_step;   // 0 = ratio divide, 1 = octant-correction divide
    reg        at_zsign;  // aSign ^ bSign (negate magnitude result)
    reg        at_bsign;  // bSign (quadrant +/- pi selector)

    // FSIN/FCOS (T-4) state
    reg        want_cos_reg; // 0 = sin(ST0), 1 = cos(ST0)
    reg [1:0]  qq_reg;       // quadrant = q & 3
    reg [79:0] qhiS_reg;     // q hi chunk (mult of 2^32) as floatx80
    reg [79:0] qloF_reg;     // q lo chunk (< 2^32) as floatx80
    reg [79:0] sin_reg;      // sin(r)
    reg [79:0] cos_reg;      // cos(r)
    reg [2:0]  red_idx;      // 0..5 over (chunk,P) reduction pairs
    // reduction operand select: idx 0,2,4 -> hi chunk ; 1,3,5 -> lo chunk.
    //                           idx 0,1 -> HP0 ; 2,3 -> HP1 ; 4,5 -> HP2.
    wire [79:0] red_chunk = red_idx[0] ? qloF_reg : qhiS_reg;
    wire [79:0] red_P     = (red_idx < 3'd2) ? HP0 : (red_idx < 3'd4) ? HP1 : HP2;

    // reduce a normalized (rExp,rSig) -> xred + ExpDiff helper, used at two
    // entry points (FYL2X start from a, FYL2XP1-big from a+1).
    task do_reduce(input [14:0] rExp, input [63:0] rSig);
        reg ge; reg signed [16:0] ed; reg [14:0] eN;
        begin
            ge = (rSig >= SQRT2_HALF_SIG);
            ed = $signed({2'b0,rExp}) - 17'sd16383 + (ge ? 17'sd1 : 17'sd0);
            eN = ge ? 15'h3FFE : 15'h3FFF;
            xred_reg <= {1'b0, eN, rSig};
            expd_reg <= int_to_fx80(ed);
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            phase <= P_IDLE; done <= 1'b0; arith_op <= KIND_ADD;
            div_start <= 1'b0; settle <= 5'd0; cnt <= 4'd0; c2 <= 1'b0;
        end else begin
            done <= 1'b0; div_start <= 1'b0;
            case (phase)
                // ---------------------------------------------------------
                P_IDLE: if (start) begin
                    b_reg <= b; a_reg_hold <= a; c2 <= 1'b0;
                    if (cmdex == CMDEX_F2XM1) begin
                        // |x|<1 normal OR denormal -> poly ; else special
                        if (((aExp != 15'h0) && (aExp < 15'h3FFF)) || a_den) begin
                            arith_a <= a; arith_b <= LN2; arith_op <= KIND_MUL;
                            settle <= WAIT;
                            flags  <= a_den ? 6'b100010 : 6'b100000; // PE(+DE)
                            phase  <= E_XLN2;
                        end else begin
                            z <= (aExp==15'h7FFF) && (|a[62:0]) ? {a[79:63],1'b1,a[61:0]} :
                                 (aExp==15'h7FFF)               ? (a[79] ? NEG_ONE : a) :
                                 (a_zero)                       ? a :
                                 (a[79] && a_one)               ? NEG_HALF : a;
                            flags <= (aExp==15'h7FFF) && (|a[62:0]) ? (a[62] ? 6'd0 : 6'b000001) :
                                     ((aExp!=15'h7FFF) && (aExp>=15'h3FFF)) ? 6'b100000 : 6'd0;
                            phase <= P_DONE;
                        end
                    end
                    else if (cmdex == CMDEX_FYL2X) begin
                        // ---- FYL2X special cases (z=bsign^1 for inf/0) -----
                        if (a_nan | b_nan) begin
                            z <= prop_nan; flags <= propagate_snan ? 6'b000001 : 6'd0;
                            phase <= P_DONE;
                        end else if (a_inf) begin
                            if (aSign) begin z <= DEFNAN; flags <= 6'b000001; end
                            else if (b_zero) begin z <= DEFNAN; flags <= 6'b000001; end
                            else begin z <= {bSign, PINF[78:0]}; flags <= 6'd0; end
                            phase <= P_DONE;
                        end else if (b_inf) begin
                            if (aSign & ~a_zero)  begin z <= DEFNAN; flags <= 6'b000001; end
                            else if (aExp < 15'h3FFF) begin z <= {~bSign, PINF[78:0]}; flags <= 6'd0; end
                            else if (a_one)       begin z <= DEFNAN; flags <= 6'b000001; end
                            else begin z <= {bSign, PINF[78:0]}; flags <= 6'd0; end
                            phase <= P_DONE;
                        end else if (a_zero) begin
                            if (b_zero) begin z <= DEFNAN; flags <= 6'b000001; end
                            else begin z <= {~bSign, PINF[78:0]}; flags <= 6'b001000; end // ZE
                            phase <= P_DONE;
                        end else if (aSign) begin
                            z <= DEFNAN; flags <= 6'b000001; phase <= P_DONE;
                        end else if (a_one) begin
                            z <= {bSign, 79'd0}; flags <= 6'd0; phase <= P_DONE;
                        end else if (b_zero) begin
                            z <= {bSign, 79'd0}; flags <= 6'd0; phase <= P_DONE; // a>1 or a<1 -> +/-0
                        end else begin
                            // ---- poly path (normal a>0, normal b) ----------
                            do_reduce(a_den ? a_nexp[14:0] : aExp, a_nsig);
                            want_ed <= 1'b1;
                            flags   <= (a_den | b_zero) ? 6'b100010 : 6'b100000; // PE(+DE)
                            // issue xp1 = xred + 1 (xred ready next cycle via reg;
                            // but we need xred NOW -> recompute inline for arith)
                            arith_a <= {1'b0, (a_nsig>=SQRT2_HALF_SIG?15'h3FFE:15'h3FFF), a_nsig};
                            arith_b <= ONE; arith_op <= KIND_ADD; settle <= WAIT;
                            phase   <= LG_XP1;
                        end
                    end
                    else if (cmdex == CMDEX_FYL2XP1) begin
                        if (a_nan | b_nan) begin
                            z <= prop_nan; flags <= propagate_snan ? 6'b000001 : 6'd0;
                            phase <= P_DONE;
                        end else if (a_inf) begin
                            if (aSign) begin z <= DEFNAN; flags <= 6'b000001; end
                            else if (b_zero) begin z <= DEFNAN; flags <= 6'b000001; end
                            else begin z <= {bSign, PINF[78:0]}; flags <= 6'd0; end
                            phase <= P_DONE;
                        end else if (b_inf) begin
                            if (a_zero) begin z <= DEFNAN; flags <= 6'b000001; end
                            else begin z <= {aSign^bSign, PINF[78:0]}; flags <= 6'd0; end
                            phase <= P_DONE;
                        end else if (a_zero) begin
                            z <= {aSign^bSign, 79'd0}; flags <= 6'd0; phase <= P_DONE;
                        end else if (aSign & (aExp >= 15'h3FFF)) begin
                            z <= a; flags <= 6'b100000; phase <= P_DONE;   // a<=-1 -> a, PE
                        end else if (aExp >= 15'h3FFC) begin
                            // big arg: a1 = a + 1, then FYL2X(a1)
                            arith_a <= a; arith_b <= ONE; arith_op <= KIND_ADD;
                            settle <= WAIT; want_ed <= 1'b1;
                            flags  <= a_den ? 6'b100010 : 6'b100000;
                            phase  <= PP_BIG;
                        end else begin
                            // small arg: u = a/(a+2), no ExpDiff
                            arith_a <= a; arith_b <= TWO; arith_op <= KIND_ADD;
                            settle <= WAIT; want_ed <= 1'b0;
                            flags  <= a_den ? 6'b100010 : 6'b100000;
                            phase  <= PP_XP2;
                        end
                    end
                    else if (cmdex == CMDEX_FPATAN) begin
                        // atan2(ST1,ST0): a=ST0 (x), b=ST1 (y).  Result -> ST1, pop.
                        if (a_nan | b_nan) begin
                            z <= prop_nan; flags <= propagate_snan ? 6'b000001 : 6'd0;
                            phase <= P_DONE;
                        end else if (b_inf) begin
                            // a=Inf too -> aSign?3pi/4:pi/4 ; else pi/2  (sign bSign)
                            if (a_inf) z <= aSign ? {bSign, THREEPI4[78:0]} : {bSign, PI4_80[78:0]};
                            else       z <= {bSign, PI2_80[78:0]};
                            flags <= (a_den) ? 6'b000010 : 6'd0; phase <= P_DONE;
                        end else if (a_inf) begin
                            // aSign?pi:0  (sign bSign)
                            z <= aSign ? {bSign, PI80[78:0]} : {bSign, 79'd0};
                            flags <= (b_den) ? 6'b000010 : 6'd0; phase <= P_DONE;
                        end else if (b_zero) begin
                            // return_PI_or_ZERO: aSign?pi:0  (sign bSign)
                            z <= aSign ? {bSign, PI80[78:0]} : {bSign, 79'd0};
                            flags <= 6'd0; phase <= P_DONE;
                        end else if (a_zero) begin
                            z <= {bSign, PI2_80[78:0]}; flags <= 6'd0; phase <= P_DONE; // pi/2
                        end else begin
                            // ---- finite-normal path: ratio = min(|a|,|b|)/max ----
                            at_zsign <= aSign ^ bSign;
                            at_bsign <= bSign;
                            add_corr <= 2'd0;
                            // |a| > |b| ?
                            if ((aExp > bExp) || (aExp == bExp && aSig > bSig)) begin
                                arith_a <= {1'b0, b[78:0]}; // x = |b|/|a|, no swap
                                arith_b <= {1'b0, a[78:0]};
                                swap_reg <= 1'b0;
                            end else begin
                                arith_a <= {1'b0, a[78:0]}; // x = |a|/|b|, swap
                                arith_b <= {1'b0, b[78:0]};
                                swap_reg <= 1'b1;
                            end
                            arith_op <= KIND_DIV; settle <= WAIT; at_step <= 1'b0;
                            flags <= (a_den | b_den) ? 6'b100010 : 6'b100000; // PE(+DE)
                            phase <= AT_DSET;
                        end
                    end
                    else if (cmdex == CMDEX_FSIN || cmdex == CMDEX_FCOS) begin
                        want_cos_reg <= (cmdex == CMDEX_FCOS);
                        if (a_nan) begin
                            z <= {a[79],15'h7FFF,1'b1,a[62:0]};
                            flags <= a_snan ? 6'b000001 : 6'd0; phase <= P_DONE;
                        end else if (a_inf) begin
                            z <= DEFNAN; flags <= 6'b000001; phase <= P_DONE; // #IA
                        end else if (aExp == 15'h0) begin
                            // zero -> sin=a / cos=1 ; denormal -> same (+PE+DE)
                            z <= (cmdex == CMDEX_FCOS) ? ONE : a;
                            flags <= a_den ? 6'b100010 : 6'd0; phase <= P_DONE;
                        end else if (aExp >= 15'h403E) begin
                            // |x| >= 2^63 : x87 out-of-range -> ST0 unchanged, C2=1
                            z <= a; flags <= 6'd0; c2 <= 1'b1; phase <= P_DONE;
                        end else if (aExp < 15'h3FFE) begin
                            // |x| < 0.5 : q=0, r=x -> straight to poly (rr = x*x)
                            arith_a <= a; arith_b <= a; arith_op <= KIND_MUL;
                            settle <= WAIT; x_reg <= a; qq_reg <= 2'd0;
                            flags <= 6'b100000; phase <= TR_X2;
                        end else begin
                            // reduce: qf = x * (2/pi)
                            arith_a <= a; arith_b <= TWO_OVER_PI; arith_op <= KIND_MUL;
                            settle <= WAIT; flags <= 6'b100000; phase <= TR_QMUL;
                        end
                    end
                    else begin
                        // T-5 (FSINCOS/FPTAN) not yet implemented: passthrough ST(0)
                        z <= a; flags <= 6'd0; phase <= P_DONE;
                    end
                end

                // ---------------- F2XM1 (unchanged math) -----------------
                E_XLN2: if (settle==0) begin
                    t_reg<=arith_z; arith_a<=exp_coeff(4'd14); arith_b<=arith_z;
                    arith_op<=KIND_MUL; cnt<=4'd14; settle<=WAIT; phase<=E_LMUL;
                end else settle<=settle-5'd1;
                E_LMUL: if (settle==0) begin
                    arith_a<=arith_z; arith_b<=exp_coeff(cnt-4'd1);
                    arith_op<=KIND_ADD; settle<=WAIT; phase<=E_LADD;
                end else settle<=settle-5'd1;
                E_LADD: if (settle==0) begin
                    arith_a<=arith_z; arith_b<=t_reg; arith_op<=KIND_MUL; settle<=WAIT;
                    if (cnt==4'd1) phase<=E_FINAL;
                    else begin cnt<=cnt-4'd1; phase<=E_LMUL; end
                end else settle<=settle-5'd1;
                E_FINAL: if (settle==0) begin z<=arith_z; phase<=P_DONE; end
                         else settle<=settle-5'd1;

                // ---------------- FYL2XP1 pre-divide front-ends ----------
                PP_BIG: if (settle==0) begin
                    // a1 = arith_z ; reduce(a1) (a1>=~7/8 normal) ; issue xp1
                    do_reduce(arith_z[78:64], arith_z[63:0]);
                    arith_a<={1'b0,(arith_z[63:0]>=SQRT2_HALF_SIG?15'h3FFE:15'h3FFF),arith_z[63:0]};
                    arith_b<=ONE; arith_op<=KIND_ADD; settle<=WAIT; phase<=LG_XP1;
                end else settle<=settle-5'd1;
                PP_XP2: if (settle==0) begin
                    den_reg<=arith_z;            // a+2
                    arith_a<=a_reg_hold; arith_b<=arith_z; arith_op<=KIND_DIV;
                    settle<=WAIT; phase<=LG_DSET;
                end else settle<=settle-5'd1;

                // ---------------- shared log pipeline --------------------
                LG_XP1: if (settle==0) begin
                    den_reg<=arith_z;            // x+1
                    arith_a<=xred_reg; arith_b<=NEG_ONE; arith_op<=KIND_ADD;
                    settle<=WAIT; phase<=LG_XM1;
                end else settle<=settle-5'd1;
                LG_XM1: if (settle==0) begin
                    arith_a<=arith_z; arith_b<=den_reg; arith_op<=KIND_DIV; // u=(x-1)/(x+1)
                    settle<=WAIT; phase<=LG_DSET;
                end else settle<=settle-5'd1;
                LG_DSET: if (settle==0) begin div_start<=1'b1; phase<=LG_DWAIT; end
                         else settle<=settle-5'd1;
                LG_DWAIT: if (div_done) begin
                    u_reg<=div_z; arith_a<=div_z; arith_b<=div_z; arith_op<=KIND_MUL;
                    settle<=WAIT; phase<=LG_U2;
                end
                LG_U2: if (settle==0) begin
                    t_reg<=arith_z;              // u^2
                    arith_a<=ln_coeff(4'd8); arith_b<=arith_z; arith_op<=KIND_MUL;
                    cnt<=4'd8; settle<=WAIT; phase<=LG_HMUL;
                end else settle<=settle-5'd1;
                LG_HMUL: if (settle==0) begin
                    arith_a<=arith_z; arith_b<=ln_coeff(cnt-4'd1); arith_op<=KIND_ADD;
                    settle<=WAIT; phase<=LG_HADD;
                end else settle<=settle-5'd1;
                LG_HADD: if (settle==0) begin
                    if (cnt==4'd1) begin
                        arith_a<=u_reg; arith_b<=arith_z; arith_op<=KIND_MUL; // pl=u*even
                        settle<=WAIT; phase<=LG_PL;
                    end else begin
                        arith_a<=arith_z; arith_b<=t_reg; arith_op<=KIND_MUL;
                        cnt<=cnt-4'd1; settle<=WAIT; phase<=LG_HMUL;
                    end
                end else settle<=settle-5'd1;
                LG_PL: if (settle==0) begin
                    arith_a<=arith_z; arith_b<=LN2INV2; arith_op<=KIND_MUL; // l2=pl*(2/ln2)
                    settle<=WAIT; phase<=LG_L2;
                end else settle<=settle-5'd1;
                LG_L2: if (settle==0) begin
                    if (want_ed) begin
                        arith_a<=arith_z; arith_b<=expd_reg; arith_op<=KIND_ADD;
                        settle<=WAIT; phase<=LG_EADD;
                    end else begin
                        arith_a<=b_reg; arith_b<=arith_z; arith_op<=KIND_MUL;
                        settle<=WAIT; phase<=LG_BMUL;
                    end
                end else settle<=settle-5'd1;
                LG_EADD: if (settle==0) begin
                    arith_a<=b_reg; arith_b<=arith_z; arith_op<=KIND_MUL; // z=ST1*(l2+ed)
                    settle<=WAIT; phase<=LG_BMUL;
                end else settle<=settle-5'd1;
                LG_BMUL: if (settle==0) begin z<=arith_z; phase<=P_DONE; end
                         else settle<=settle-5'd1;

                // ---------------- FPATAN (T-3) ---------------------------
                // shared divide launch (ratio + both octant corrections)
                AT_DSET: if (settle==0) begin div_start<=1'b1; phase<=AT_DWAIT; end
                         else settle<=settle-5'd1;
                AT_DWAIT: if (div_done) begin
                    x_reg <= div_z;                         // reduced x (for poly outer)
                    if (at_step == 1'b0) begin
                        // ratio result -> tiny? octant correction? straight poly?
                        if (div_z[78:64] <= 15'h3FD7) begin
                            // |x| <= 2^-40: atan(x) ~ x, skip poly
                            phase <= AT_SWAP;
                        end else if ((div_z[78:64] > 15'h3FFE) ||
                                     (div_z[78:64]==15'h3FFE && div_z[63:0]>=64'hC000000000000000)) begin
                            // 3/4 <= x < 1: x=(x-1)/(x+1) + pi/4
                            add_corr <= 2'd1;
                            arith_a <= div_z; arith_b <= ONE; arith_op <= KIND_ADD;
                            settle <= WAIT; phase <= AT_C4_XP1;   // den = x+1 first
                        end else if (div_z[78:64] >= 15'h3FFD) begin
                            // 1/4 <= x < 3/4: x=(x*sqrt3-1)/(x+sqrt3) + pi/6
                            add_corr <= 2'd2;
                            arith_a <= div_z; arith_b <= SQRT3_80; arith_op <= KIND_MUL;
                            settle <= WAIT; phase <= AT_C6_MUL;   // t1 = x*sqrt3
                        end else begin
                            // x < 1/4: no correction -> poly directly
                            arith_a <= div_z; arith_b <= div_z; arith_op <= KIND_MUL;
                            settle <= WAIT; phase <= AT_P_X2;      // x^2
                        end
                    end else begin
                        // octant-correction divide done -> poly
                        arith_a <= div_z; arith_b <= div_z; arith_op <= KIND_MUL;
                        settle <= WAIT; phase <= AT_P_X2;
                    end
                end
                // +pi/4 correction: x = (x-1)/(x+1)
                AT_C4_XP1: if (settle==0) begin
                    den_reg <= arith_z;                     // x+1
                    arith_a <= x_reg; arith_b <= NEG_ONE; arith_op <= KIND_ADD;
                    settle <= WAIT; phase <= AT_C4_XM1;     // x-1
                end else settle<=settle-5'd1;
                AT_C4_XM1: if (settle==0) begin
                    arith_a <= arith_z; arith_b <= den_reg; arith_op <= KIND_DIV;
                    settle <= WAIT; at_step <= 1'b1; phase <= AT_DSET;
                end else settle<=settle-5'd1;
                // +pi/6 correction: x = (x*sqrt3 - 1)/(x + sqrt3)
                AT_C6_MUL: if (settle==0) begin
                    t_reg <= arith_z;                       // x*sqrt3
                    arith_a <= x_reg; arith_b <= SQRT3_80; arith_op <= KIND_ADD;
                    settle <= WAIT; phase <= AT_C6_ADD;     // x+sqrt3
                end else settle<=settle-5'd1;
                AT_C6_ADD: if (settle==0) begin
                    den_reg <= arith_z;                     // x+sqrt3
                    arith_a <= t_reg; arith_b <= NEG_ONE; arith_op <= KIND_ADD;
                    settle <= WAIT; phase <= AT_C6_SUB;     // (x*sqrt3)-1
                end else settle<=settle-5'd1;
                AT_C6_SUB: if (settle==0) begin
                    arith_a <= arith_z; arith_b <= den_reg; arith_op <= KIND_DIV;
                    settle <= WAIT; at_step <= 1'b1; phase <= AT_DSET;
                end else settle<=settle-5'd1;
                // OddPoly(x, atan_arr, 11): x * Horner(x^2, arr[10..0])
                AT_P_X2: if (settle==0) begin
                    t_reg <= arith_z;                       // x^2
                    arith_a <= atan_coeff(4'd10); arith_b <= arith_z; arith_op <= KIND_MUL;
                    cnt <= 4'd10; settle <= WAIT; phase <= AT_P_MUL;
                end else settle<=settle-5'd1;
                AT_P_MUL: if (settle==0) begin
                    arith_a <= arith_z; arith_b <= atan_coeff(cnt-4'd1); arith_op <= KIND_ADD;
                    settle <= WAIT; phase <= AT_P_ADD;
                end else settle<=settle-5'd1;
                AT_P_ADD: if (settle==0) begin
                    if (cnt==4'd1) begin
                        arith_a <= x_reg; arith_b <= arith_z; arith_op <= KIND_MUL; // outer x*
                        settle <= WAIT; phase <= AT_P_OUT;
                    end else begin
                        arith_a <= arith_z; arith_b <= t_reg; arith_op <= KIND_MUL; // *x^2
                        cnt <= cnt-4'd1; settle <= WAIT; phase <= AT_P_MUL;
                    end
                end else settle<=settle-5'd1;
                AT_P_OUT: if (settle==0) begin
                    case (add_corr)
                        2'd1: begin arith_a<=arith_z; arith_b<=PI4_80; arith_op<=KIND_ADD;
                                    settle<=WAIT; phase<=AT_CORR; end
                        2'd2: begin arith_a<=arith_z; arith_b<=PI6_80; arith_op<=KIND_ADD;
                                    settle<=WAIT; phase<=AT_CORR; end
                        default: begin x_reg<=arith_z; phase<=AT_SWAP; end
                    endcase
                end else settle<=settle-5'd1;
                AT_CORR: if (settle==0) begin x_reg<=arith_z; phase<=AT_SWAP; end
                         else settle<=settle-5'd1;
                // swap: result = pi/2 - x   (pi/2 + (-x))
                AT_SWAP: begin
                    if (swap_reg) begin
                        arith_a <= PI2_80; arith_b <= {~x_reg[79], x_reg[78:0]};
                        arith_op <= KIND_ADD; settle <= WAIT; phase <= AT_SWAPW;
                    end else phase <= AT_SIGN;
                end
                AT_SWAPW: if (settle==0) begin x_reg<=arith_z; phase<=AT_SIGN; end
                          else settle<=settle-5'd1;
                // quadrant: apply zsign, then +/- pi per bSign vs result sign
                AT_SIGN: begin
                    if (~at_bsign & at_zsign) begin
                        // result negative but b>=0 -> + pi
                        arith_a <= {at_zsign, x_reg[78:0]}; arith_b <= PI80;
                        arith_op <= KIND_ADD; settle <= WAIT; phase <= AT_PIW;
                    end else if (at_bsign & ~at_zsign) begin
                        // result positive but b<0 -> - pi
                        arith_a <= {at_zsign, x_reg[78:0]}; arith_b <= {~PI80[79],PI80[78:0]};
                        arith_op <= KIND_ADD; settle <= WAIT; phase <= AT_PIW;
                    end else begin
                        z <= {at_zsign, x_reg[78:0]}; phase <= P_DONE;
                    end
                end
                AT_PIW: if (settle==0) begin z<=arith_z; phase<=P_DONE; end
                        else settle<=settle-5'd1;

                // ---------------- FSIN/FCOS (T-4) ------------------------
                // qf = x*(2/pi) settled -> round to int q, split hi/lo, latch
                // quadrant, kick off the 3-part Cody-Waite reduction.
                TR_QMUL: if (settle==0) begin
                    qq_reg   <= fx80_to_int64(arith_z) & 64'd3;
                    qhiS_reg <= int64_to_fx80(q_hi_signed(arith_z));
                    qloF_reg <= int64_to_fx80(q_lo_signed(arith_z));
                    x_reg    <= a_reg_hold;          // r := x
                    red_idx  <= 3'd0; phase <= TR_RIS;
                end else settle<=settle-5'd1;
                // issue qchunk * HPi  (red_idx selects chunk + Pi)
                TR_RIS: begin
                    arith_a<=red_chunk; arith_b<=red_P; arith_op<=KIND_MUL;
                    settle<=WAIT; phase<=TR_RML;
                end
                // r := r + (-term)   (subtract via negated addend)
                TR_RML: if (settle==0) begin
                    arith_a<=x_reg; arith_b<={~arith_z[79],arith_z[78:0]};
                    arith_op<=KIND_ADD; settle<=WAIT; phase<=TR_RSB;
                end else settle<=settle-5'd1;
                TR_RSB: if (settle==0) begin
                    x_reg<=arith_z;
                    if (red_idx==3'd5) begin
                        // reduction done -> rr = r*r  (r = arith_z this cycle)
                        arith_a<=arith_z; arith_b<=arith_z; arith_op<=KIND_MUL;
                        settle<=WAIT; phase<=TR_X2;
                    end else begin
                        red_idx<=red_idx+3'd1; phase<=TR_RIS;
                    end
                end else settle<=settle-5'd1;
                // rr settled -> start sin Horner: acc = sin[10]*rr
                TR_X2: if (settle==0) begin
                    t_reg<=arith_z;                  // rr
                    arith_a<=sin_coeff(4'd10); arith_b<=arith_z; arith_op<=KIND_MUL;
                    cnt<=4'd10; settle<=WAIT; phase<=TR_S_MUL;
                end else settle<=settle-5'd1;
                TR_S_MUL: if (settle==0) begin
                    arith_a<=arith_z; arith_b<=sin_coeff(cnt-4'd1); arith_op<=KIND_ADD;
                    settle<=WAIT; phase<=TR_S_ADD;
                end else settle<=settle-5'd1;
                TR_S_ADD: if (settle==0) begin
                    if (cnt==4'd1) begin
                        arith_a<=arith_z; arith_b<=x_reg; arith_op<=KIND_MUL; // outer *r
                        settle<=WAIT; phase<=TR_S_OUT;
                    end else begin
                        arith_a<=arith_z; arith_b<=t_reg; arith_op<=KIND_MUL;
                        cnt<=cnt-4'd1; settle<=WAIT; phase<=TR_S_MUL;
                    end
                end else settle<=settle-5'd1;
                // sin(r) done -> start cos Horner: acc = cos[10]*rr
                TR_S_OUT: if (settle==0) begin
                    sin_reg<=arith_z;
                    arith_a<=cos_coeff(4'd10); arith_b<=t_reg; arith_op<=KIND_MUL;
                    cnt<=4'd10; settle<=WAIT; phase<=TR_C_MUL;
                end else settle<=settle-5'd1;
                TR_C_MUL: if (settle==0) begin
                    arith_a<=arith_z; arith_b<=cos_coeff(cnt-4'd1); arith_op<=KIND_ADD;
                    settle<=WAIT; phase<=TR_C_ADD;
                end else settle<=settle-5'd1;
                TR_C_ADD: if (settle==0) begin
                    if (cnt==4'd1) begin cos_reg<=arith_z; phase<=TR_QUAD; end
                    else begin
                        arith_a<=arith_z; arith_b<=t_reg; arith_op<=KIND_MUL;
                        cnt<=cnt-4'd1; settle<=WAIT; phase<=TR_C_MUL;
                    end
                end else settle<=settle-5'd1;
                // quadrant select.  FSIN: [sin,cos,-sin,-cos][qq].
                //                    FCOS: [cos,-sin,-cos,sin][qq].
                TR_QUAD: begin
                    case ({want_cos_reg, qq_reg})
                        3'b0_00: z <= sin_reg;
                        3'b0_01: z <= cos_reg;
                        3'b0_10: z <= {~sin_reg[79], sin_reg[78:0]};
                        3'b0_11: z <= {~cos_reg[79], cos_reg[78:0]};
                        3'b1_00: z <= cos_reg;
                        3'b1_01: z <= {~sin_reg[79], sin_reg[78:0]};
                        3'b1_10: z <= {~cos_reg[79], cos_reg[78:0]};
                        3'b1_11: z <= sin_reg;
                    endcase
                    phase <= P_DONE;
                end

                P_DONE: begin done<=1'b1; phase<=P_IDLE; end
                default: phase<=P_IDLE;
            endcase
        end
    end

endmodule
