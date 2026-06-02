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
// The remaining four (FPTAN/FPATAN/FSIN/FCOS/FSINCOS) still route here and take
// the deterministic PASSTHROUGH (ST0 unchanged) until T-3..T-5 land.
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
    output reg  [5:0]  flags            // {PE,UE,OE,ZE,DE,IE}
);

    // op-kind encoding -- MUST match execute_fpu.v's KIND_* localparams.
    localparam [1:0] KIND_ADD = 2'd0, KIND_MUL = 2'd2, KIND_DIV = 2'd3;

    // CMDEX selectors (research/design_transcendentals.md §5).
    localparam [3:0] CMDEX_F2XM1 = 4'd0, CMDEX_FYL2X = 4'd1, CMDEX_FYL2XP1 = 4'd4;

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
    localparam [4:0]
        P_IDLE  = 5'd0,
        E_XLN2  = 5'd1, E_LMUL = 5'd2, E_LADD = 5'd3, E_FINAL = 5'd4,  // F2XM1
        LG_XP1  = 5'd5, LG_XM1 = 5'd6, LG_DSET = 5'd7, LG_DWAIT = 5'd8,// log
        LG_U2   = 5'd9, LG_HMUL= 5'd10,LG_HADD = 5'd11,
        LG_PL   = 5'd12,LG_L2  = 5'd13,LG_EADD = 5'd14,LG_BMUL = 5'd15,
        PP_BIG  = 5'd16,PP_XP2 = 5'd17,
        P_DONE  = 5'd18;

    reg [4:0]  phase;
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
            div_start <= 1'b0; settle <= 5'd0; cnt <= 4'd0;
        end else begin
            done <= 1'b0; div_start <= 1'b0;
            case (phase)
                // ---------------------------------------------------------
                P_IDLE: if (start) begin
                    b_reg <= b; a_reg_hold <= a;
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
                    else begin
                        // T-3..T-5 not yet implemented: passthrough ST(0)
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

                P_DONE: begin done<=1'b1; phase<=P_IDLE; end
                default: phase<=P_IDLE;
            endcase
        end
    end

endmodule
