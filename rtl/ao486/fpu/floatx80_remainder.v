// floatx80_remainder.v
//
// PR-2b.5r (iter 134): FPREM (D9 F8, round-to-zero quotient) / FPREM1
// (D9 F5, round-to-nearest-even quotient) primitive.  Computes
// ST(0) mod ST(1) per Bochs do_fprem (cpu/fpu/fprem.cc:48) — see
// research/design_fprem.md for the full derivation.
//
// PR-2b.5s (iter 136, Slice 2): faithful special-operand handling.  The
// Slice-1 blanket QNaN+IE stub is replaced by the Bochs do_fprem cascade
// (priority order):
//   1. NaN (a or b)        -> propagateFloatx80NaN; IE iff an SNaN input.
//   2. a = Inf             -> QNaN indefinite + IE  (invalid operation).
//   3. b = Inf (a finite)  -> result = a (no IE); DE iff a is denormal.
//   4. b = 0   (a finite)  -> QNaN indefinite + IE  (invalid operation).
//   5. a = 0   (b nonzero) -> result = a (no flags).
//   6. else                -> normal/denormal reduction kernel; DE iff
//                             either operand is denormal.
// Denormal operands are normalized through floatx80_normalize so the
// kernel computes the IEEE-correct remainder; the resulting (possibly
// subnormal) value is encoded by floatx80_norm_round_pack, whose
// subnormal branch carries the UE/PE semantics.
//
// PR-2b.5x (iter 145, synth-unblock Slice 3): rewritten pure-comb -> CLOCKED.
// The native 128/64 `/`+`%` divides (the standing synth-blocker) are replaced
// by the iter-142 seq_divider_128_64 (ONE pass — the incomplete path needs only
// the remainder, the kernel path needs quotient+remainder, and those paths are
// mutually exclusive).  clk/rst/start/done handshake added; operands frozen into
// a_reg/b_reg/rnd_reg on `start` so the surrounding normalize/special/correction/
// pack fabric (all still combinational) sees stable inputs across the ~64-cycle
// divide.  Internal FSM: R_IDLE (latch on start) -> R_START (pulse div_start iff
// a divide is needed; else done immediately for the special/passthru/expDiff<=0
// paths) -> R_WAIT (capture quotient/remainder on div_done) -> done.  seq_divider
// precondition num[127:64] < den holds for BOTH the incomplete and kernel
// numerators (a_sig_n shifted left by < 64 vs a J-bit-set b_sig_n).
//
// Validated standalone vs a frozen combinational oracle
// (sim/modelsim/floatx80_remainder_comb_ref.v) — see Slice 3a.

`timescale 1ns / 1ps

module floatx80_remainder (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [79:0] a,
    input  wire [79:0] b,
    input  wire        rnd_nearest,   // 1 = FPREM1 (RTNE quotient), 0 = FPREM (RTZ)
    // iter-171a: shared input normalizers (~600 ALUTs saved).  Caller drives
    // these from execute_fpu's u_norm_a_shared / u_norm_b_shared cones
    // evaluating op_a / op_b; at the `start` edge (rem_start fires in
    // S_ARITHWAIT for FPREM) op_a == a_lat and op_b == b_lat, identical to
    // what the removed local u_norm_a/u_norm_b would have produced from
    // a_reg/b_reg.  Captured into a_*_n_reg/b_*_n_reg on `start` so the
    // ~64-cycle divide and the surrounding combinational fabric see stable
    // normalized inputs.
    input  wire        na_sign,
    input  wire signed [16:0] na_exp,
    input  wire [63:0] na_sig,
    input  wire        nb_sign,
    input  wire signed [16:0] nb_exp,
    input  wire [63:0] nb_sig,
    // iter-171b: shared seq_divider_128_64 hoisted to execute_fpu.v (single
    // instance reused by div + remainder; mutually exclusive FSM states).
    // remainder drives sd_start/sd_num/sd_den when it wants a divide; the
    // quotient/remainder/done come back via sd_q/sd_r/sd_done.
    output wire         sd_start,
    output wire [127:0] sd_num,
    output wire [63:0]  sd_den,
    input  wire [63:0]  sd_q,
    input  wire [63:0]  sd_r,
    input  wire         sd_done,
    // iter-171c: u_pack's internal floatx80_pack_subn hoisted to share
    // execute_fpu's u_pack_subn_shared via a state-keyed input mux.
    output wire         rps_in_sign,
    output wire signed [16:0] rps_in_exp_pre,
    output wire [63:0]  rps_in_sig_hi,
    output wire [63:0]  rps_in_sig_lo,
    input  wire [79:0]  rps_z_in,
    input  wire         rps_pe_in,
    output wire [79:0] z,
    output wire [2:0]  quotient,      // low 3 bits of q -> {C0=q[2], C3=q[1], C1=q[0]}
    output wire        incomplete,    // -> C2 (partial reduction, expDiff >= 64)
    output wire [5:0]  flags,         // {PE, UE, OE, ZE, DE, IE}
    output reg         done
);

    //--------------------------------------------------------------------
    // Operand freeze.  a/b/rnd_nearest are the LIVE pipeline values only
    // during the dispatch cycle; latch them on `start` so the whole
    // combinational fabric below stays stable across the ~64-cycle divide.
    //--------------------------------------------------------------------
    reg  [79:0] a_reg, b_reg;
    reg         rnd_reg;

    wire        a_sign = a_reg[79];

    //--------------------------------------------------------------------
    // Special-operand classifiers (shared modules, already in the arith
    // primitives' compile list).
    //--------------------------------------------------------------------
    wire        is_nan_a, is_nan_b, is_any_nan, is_any_snan;
    wire [79:0] z_nan;
    wire [5:0]  flags_nan;
    floatx80_nan_handle u_nan (
        .a(a_reg), .b(b_reg),
        .is_nan_a(is_nan_a), .is_nan_b(is_nan_b),
        .is_any_nan(is_any_nan), .is_any_snan(is_any_snan),
        .z_nan(z_nan), .flags_nan(flags_nan)
    );

    wire is_inf_a, is_inf_b, is_any_inf;
    floatx80_inf_handle u_inf (
        .a(a_reg), .b(b_reg),
        .is_inf_a(is_inf_a), .is_inf_b(is_inf_b), .is_any_inf(is_any_inf)
    );

    wire is_zero_a, is_zero_b, is_any_zero;
    floatx80_zero_handle u_zero (
        .a(a_reg), .b(b_reg),
        .is_zero_a(is_zero_a), .is_zero_b(is_zero_b), .is_any_zero(is_any_zero)
    );

    wire is_subn_a, is_subn_b, is_any_subn;
    floatx80_subn_handle u_subn (
        .a(a_reg), .b(b_reg),
        .is_subn_a(is_subn_a), .is_subn_b(is_subn_b), .is_any_subn(is_any_subn)
    );

    //--------------------------------------------------------------------
    // Normalized operands.  iter-171a: u_norm_a/u_norm_b removed in favor of
    // execute_fpu's shared u_norm_a_shared / u_norm_b_shared cones driven
    // through the na_*/nb_* ports.  Captured into _reg on the same `start`
    // edge that latches a_reg/b_reg so the surrounding combinational fabric
    // (expDiff, num_div, packer, special cascade) stays stable across the
    // ~64-cycle divide.
    //--------------------------------------------------------------------
    reg                a_sign_n_reg;
    reg  signed [16:0] a_exp_n_reg;
    reg         [63:0] a_sig_n_reg;
    reg                b_sign_n_reg;
    reg  signed [16:0] b_exp_n_reg;
    reg         [63:0] b_sig_n_reg;

    wire               a_sign_n = a_sign_n_reg;
    wire signed [16:0] a_exp_n  = a_exp_n_reg;
    wire        [63:0] a_sig_n  = a_sig_n_reg;
    wire               b_sign_n = b_sign_n_reg;
    wire signed [16:0] b_exp_n  = b_exp_n_reg;
    wire        [63:0] b_sig_n  = b_sig_n_reg;

    wire signed [16:0] expDiff = a_exp_n - b_exp_n;

    //--------------------------------------------------------------------
    // INCOMPLETE path: expDiff >= 64.  n = (expDiff & 0x1f) | 0x20  (32..63);
    // one kernel step; q discarded (=> 0); zExp = aExp - n.
    //--------------------------------------------------------------------
    wire incomplete_w = (expDiff >= $signed(17'sd64));
    wire [5:0]  n_inc   = {1'b1, expDiff[4:0]};
    wire [127:0] num_inc = {64'd0, a_sig_n} << n_inc;
    wire signed [16:0] zexp_inc = a_exp_n - $signed({11'd0, n_inc});

    //--------------------------------------------------------------------
    // COMPLETE path: expDiff < 64.
    //   expDiff < -1 : remainder = a (b dwarfs a).
    //   expDiff ==-1 : shift aSig right 1, then treat as expDiff == 0.
    //   1..63        : seq-divide kernel.
    //   == 0         : single conditional subtract.
    //--------------------------------------------------------------------
    wire passthru = (expDiff < -$signed(17'sd1));
    wire is_neg1  = (expDiff == -$signed(17'sd1));

    wire [63:0] aSig0_pre = is_neg1 ? {1'b0, a_sig_n[63:1]} : a_sig_n;
    wire [63:0] aSig1_pre = is_neg1 ? {a_sig_n[0], 63'd0}   : 64'd0;

    wire is_kernel = (expDiff > $signed(17'sd0)) && ~incomplete_w;   // 1..63
    wire [5:0]  ediff6 = expDiff[5:0];

    // kernel: aSig0_pre == a_sig_n here (the -1 pre-shift only feeds expDiff==0).
    wire [127:0] num_k   = {64'd0, a_sig_n} << ediff6;

    //--------------------------------------------------------------------
    // Clocked divide.  needs_div selects the incomplete vs kernel numerator;
    // den = b_sig_n (the 64-bit normalized divisor) for both.  The native
    // q_k/rem_k/rem_inc combinational divides are replaced by q_div_reg/
    // rem_div_reg captured from one seq_divider pass.  Both numerators satisfy
    // num[127:64] < den (a_sig_n shifted left by < 64 vs a J-bit-set b_sig_n).
    //--------------------------------------------------------------------
    wire is_special_pre = is_any_nan | is_inf_a
                        | (~is_inf_a & is_inf_b)            // spec_binf
                        | (~is_inf_a & ~is_inf_b & is_zero_b)
                        | (~is_inf_a & ~is_inf_b & ~is_zero_b & is_zero_a);
    wire needs_div = ~is_special_pre & ~passthru & (is_kernel | incomplete_w);
    wire [127:0] num_div = incomplete_w ? num_inc : num_k;
    wire [63:0]  den_div = b_sig_n;

    localparam R_IDLE  = 2'd0;
    localparam R_START = 2'd1;
    localparam R_WAIT  = 2'd2;

    reg  [1:0]  rstate;
    reg  [63:0] q_div_reg;     // kernel quotient (low 64; true q < 2^64 since num_hi<den)
    reg  [63:0] rem_div_reg;   // remainder (incomplete + kernel)

    // div_start is a NATURAL 1-cycle pulse (R_START lasts exactly one cycle).
    wire        div_start = (rstate == R_START) && needs_div;
    wire        div_done;
    wire [63:0] div_quotient_w;
    wire [63:0] div_remainder_w;

    always @(posedge clk) begin
        if (rst) begin
            rstate       <= R_IDLE;
            done         <= 1'b0;
            a_reg        <= 80'd0;
            b_reg        <= 80'd0;
            rnd_reg      <= 1'b0;
            q_div_reg    <= 64'd0;
            rem_div_reg  <= 64'd0;
            a_sign_n_reg <= 1'b0;
            a_exp_n_reg  <= 17'sd0;
            a_sig_n_reg  <= 64'd0;
            b_sign_n_reg <= 1'b0;
            b_exp_n_reg  <= 17'sd0;
            b_sig_n_reg  <= 64'd0;
        end else begin
            done <= 1'b0;
            case (rstate)
                R_IDLE: begin
                    if (start) begin
                        a_reg        <= a;
                        b_reg        <= b;
                        rnd_reg      <= rnd_nearest;
                        // iter-171a: capture shared-normalize cone outputs on
                        // the SAME edge that latches a/b.  After this edge the
                        // shared cones may see different op_a/op_b (next op
                        // dispatching), but our local _reg copies are frozen
                        // for the rest of the FPREM run.
                        a_sign_n_reg <= na_sign;
                        a_exp_n_reg  <= na_exp;
                        a_sig_n_reg  <= na_sig;
                        b_sign_n_reg <= nb_sign;
                        b_exp_n_reg  <= nb_exp;
                        b_sig_n_reg  <= nb_sig;
                        rstate       <= R_START;
                    end
                end
                // a_reg/b_reg settled: needs_div / num_div / den_div now valid.
                R_START: begin
                    if (needs_div) begin
                        // div_start pulses this cycle; seq_divider latches on the
                        // edge that takes us to R_WAIT.
                        rstate <= R_WAIT;
                    end else begin
                        // special / passthru / expDiff<=0: result is combinational
                        // off the registered operands, valid now.
                        done   <= 1'b1;
                        rstate <= R_IDLE;
                    end
                end
                R_WAIT: begin
                    if (div_done) begin
                        q_div_reg   <= div_quotient_w;
                        rem_div_reg <= div_remainder_w;
                        done        <= 1'b1;
                        rstate      <= R_IDLE;
                    end
                end
                default: rstate <= R_IDLE;
            endcase
        end
    end

    // iter-171b: route to/from shared seq_divider_128_64 in execute_fpu.v
    // instead of instantiating a local one (~351 ALUTs saved; paired with
    // softfloat_div_x80's identical share).  FPREM runs in S_REMWAIT; FDIV
    // runs in S_ARITHWAIT — mutually exclusive, so the top-level mux is
    // keyed off FSM state, not handshakes here.
    assign sd_start                 = div_start;
    assign sd_num                   = num_div;
    assign sd_den                   = den_div;
    assign div_quotient_w           = sd_q;
    assign div_remainder_w          = sd_r;
    assign div_done                 = sd_done;

    //--------------------------------------------------------------------
    // Combinational result fabric, keyed off the registered operands and the
    // registered quotient/remainder (q_div_reg/rem_div_reg).
    //--------------------------------------------------------------------
    // expDiff == 0 (incl. the -1-shifted case): one conditional subtract.
    wire        z0_sub  = (b_sig_n <= aSig0_pre);
    wire [63:0] z0_sig0 = z0_sub ? (aSig0_pre - b_sig_n) : aSig0_pre;
    wire [63:0] z0_sig1 = aSig1_pre;

    // Pre-correction complete-path significand + quotient.
    wire [63:0] cmpl_sig0 = is_kernel ? rem_div_reg     : z0_sig0;
    wire [63:0] cmpl_sig1 = is_kernel ? 64'd0           : z0_sig1;
    wire [63:0] cmpl_q    = is_kernel ? q_div_reg       : (z0_sub ? 64'd1 : 64'd0);

    //--------------------------------------------------------------------
    // FPREM1 round-to-nearest-even quotient correction (rnd_reg only).
    // Compare the 128-bit remainder to bSig/2; on rem >= b/2 maybe flip the
    // sign, ++q, and reflect the remainder (b - rem).
    //--------------------------------------------------------------------
    wire [63:0] half0 = {1'b0, b_sig_n[63:1]};   // shift128Right(bSig,0,1) hi
    wire [63:0] half1 = {b_sig_n[0], 63'd0};      //                        lo

    wire rem_lt_half = (cmpl_sig0 <  half0) ||
                       ((cmpl_sig0 == half0) && (cmpl_sig1 <  half1));
    wire rem_eq_half = (cmpl_sig0 == half0) && (cmpl_sig1 == half1);
    wire half_lt_rem = (half0 <  cmpl_sig0) ||
                       ((half0 == cmpl_sig0) && (half1 <  cmpl_sig1));

    wire do_corr   = rnd_reg && ~rem_lt_half;                       // rem >= b/2
    wire corr_incr = do_corr && ((rem_eq_half && cmpl_q[0]) || half_lt_rem);
    wire corr_sub  = do_corr && half_lt_rem;

    wire [127:0] refl = {b_sig_n, 64'd0} - {cmpl_sig0, cmpl_sig1};  // sub128(b, rem)

    wire        corr_sign = a_sign_n ^ corr_incr;                   // aSign = !aSign
    wire [63:0] corr_sig0 = corr_sub ? refl[127:64] : cmpl_sig0;
    wire [63:0] corr_sig1 = corr_sub ? refl[63:0]   : cmpl_sig1;
    wire [63:0] corr_q    = cmpl_q + {63'd0, corr_incr};

    //--------------------------------------------------------------------
    // Final operands for normalizeRoundAndPackFloatx80.
    //--------------------------------------------------------------------
    wire        final_sign = incomplete_w ? a_sign_n               : corr_sign;
    wire signed [16:0] final_exp = incomplete_w ? zexp_inc         : b_exp_n;
    wire [63:0] final_sig0 = incomplete_w ? rem_div_reg            : corr_sig0;
    wire [63:0] final_sig1 = incomplete_w ? 64'd0                  : corr_sig1;
    wire [63:0] final_q    = incomplete_w ? 64'd0                  : corr_q;

    wire [79:0] pack_z;
    wire        pack_pe, pack_ue;
    floatx80_norm_round_pack u_pack (
        .sign     (final_sign),
        .z_exp_in (final_exp),
        .sig0_in  (final_sig0),
        .sig1_in  (final_sig1),
        // iter-171c: route the hoisted pack_subn through ports up to
        // execute_fpu's shared u_pack_subn_shared (muxed against the
        // existing shared_pr_* triple from sub/add/mul/div).
        .subn_in_sign    (rps_in_sign),
        .subn_in_exp_pre (rps_in_exp_pre),
        .subn_in_sig_hi  (rps_in_sig_hi),
        .subn_in_sig_lo  (rps_in_sig_lo),
        .subn_z_in       (rps_z_in),
        .subn_pe_in      (rps_pe_in),
        .z        (pack_z),
        .pe       (pack_pe),
        .ue       (pack_ue)
    );

    //--------------------------------------------------------------------
    // Special-operand cascade (Bochs do_fprem priority order).  NaN beats
    // a=Inf beats b=Inf beats b=0 beats a=0 beats the reduction kernel.
    //--------------------------------------------------------------------
    wire [79:0] qnan_indef = {1'b1, 15'h7FFF, 64'hC000000000000000};

    wire spec_nan   = is_any_nan;
    wire spec_ainf  = ~spec_nan & is_inf_a;                              // a=Inf -> IE+QNaN
    wire spec_binf  = ~spec_nan & ~is_inf_a & is_inf_b;                 // b=Inf -> result=a
    wire spec_bzero = ~spec_nan & ~is_inf_a & ~is_inf_b & is_zero_b;    // b=0   -> IE+QNaN
    wire spec_azero = ~spec_nan & ~is_inf_a & ~is_inf_b & ~is_zero_b & is_zero_a; // a=0 -> result=a
    wire is_special = spec_nan | spec_ainf | spec_binf | spec_bzero | spec_azero;

    //--------------------------------------------------------------------
    // Output mux: special > passthru(=a) > packed result.
    //--------------------------------------------------------------------
    assign z = spec_nan   ? z_nan
             : spec_ainf  ? qnan_indef
             : spec_binf  ? a_reg
             : spec_bzero ? qnan_indef
             : spec_azero ? a_reg
             : passthru   ? a_reg
                          : pack_z;

    assign incomplete = ~is_special & ~passthru & incomplete_w;
    assign quotient   = (is_special | passthru | incomplete_w) ? 3'd0 : final_q[2:0];

    // IE: SNaN input, a=Inf, or b=0 (invalid operations).
    wire ie_w = (spec_nan & is_any_snan) | spec_ainf | spec_bzero;
    // DE: denormal operand on a non-invalid finite path.  b=Inf reflects
    // only a-denormal (b is Inf, not denormal); passthru/kernel reflect
    // either operand (both are finite & nonzero there).
    wire de_w = spec_binf  ? is_subn_a
              : is_special ? 1'b0
              :              is_any_subn;
    // PE/UE come from the pack stage only on the computed (non-passthru,
    // non-special) path; passthru returns an exact a.
    wire pe_w = ~is_special & ~passthru & pack_pe;
    wire ue_w = ~is_special & ~passthru & pack_ue;

    assign flags = {pe_w, ue_w, 1'b0, 1'b0, de_w, ie_w};

endmodule
