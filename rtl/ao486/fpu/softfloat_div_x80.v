// softfloat_div_x80.v
//
// PR-2b.3c: pure combinational softfloatx80_div primitive — fourth member
// of the arith family after softfloat_add_x80 (PR-2b.2a),
// softfloat_sub_x80 (PR-2b.3a), and softfloat_mul_x80 (PR-2b.3b).
//
// Scope (intentionally narrow, mirrors the add/sub/mul cut):
//   - Normal-normal operands, PLUS the b=0 special case (zero divisor).
//     Caller may pass a=normal+b=zero; we set ZE and produce signed Inf.
//     Caller may pass a=zero+b=zero; we set IE (invalid).  All other
//     special cases (NaN, Inf, denormal) deferred to PR-2b.3e.
//   - Round-to-nearest-even only (CW.RC == 00, FNINIT default).
//   - Extended precision only (no FPU.PC short-circuit).
//
// Algorithm (Bochs divFloatx80Sigs, sim/testfloat/softfloat/softfloat.cc:3317
// — must match BIT-EXACTLY because the round step is sensitive to the
// 128 bits of quotient that emerge from a 128/64 long divide):
//
//   zSign = aSign ^ bSign
//   zExp  = aExp - bExp + 0x3FFE
//   rem1_init = 0
//   if (aSig >= bSig) {
//       // 128-bit shift right by 1: aSig >>= 1, rem1_init gets the
//       // shifted-out bit as its MSB (NOT shift64RightJamming — the
//       // lost bit must keep its full numeric weight in the 128-bit
//       // numerator below).
//       rem1_init = (aSig & 1) << 63
//       aSig     >>= 1
//       ++zExp
//   }
//   // First quotient: 64 bits, plus 64-bit remainder for the second pass.
//   zSig0     = (aSig:rem1_init) / bSig
//   rem_after = (aSig:rem1_init) % bSig    // < bSig, so < 2^64
//   // Second quotient: 64 more bits feeding the rounder's round/sticky.
//   zSig1_raw = (rem_after << 64) / bSig
//   sticky    = ((rem_after << 64) % bSig) != 0
//   zSig1     = zSig1_raw | sticky    // (Bochs |= sticky into LSB)
//   z = roundAndPackFloatx80(RTNE, zSign, zExp, zSig0, zSig1)
//
// The earlier (iter-31 first cut) version used a single 129-bit divide
// with shift64RightJamming.  That lost up to 1 ULP whenever aSig LSB was
// already 1 (jam can only SET the LSB, not increment it) — caught by the
// "max_sig/1" curated vector where exact result needs ...FFFFFFFFFFFFFFFF
// but the 1-shot path produced ...FFFFFFFFFFFFFFFE.
//
// Implementation note on the divider:
//   This module uses Verilog's native `/` and `%` on 128-bit operands.
//   ModelSim handles it combinationally.  For FPGA synthesis the two
//   128/64 divides would each map to an iterative restoring divider; the
//   FSM's S_COMPUTE→S_POST currently allows only 1 cycle, so synthesis
//   prep would need to expand S_COMPUTE into ~64-128 cycles.  Sim-only
//   for now.
//
// Output:
//   z — final result (sign | exp | sig)
//   flags[5:0] — bit layout matches softfloat_add_x80:
//     flags[5] = PE — round_bit | sticky was nonzero
//     flags[4] = UE — TODO: zExp_final <= 0 → tiny.  Deferred.
//     flags[3] = OE — zExp_final >= 0x7FFF → saturated.
//     flags[2] = ZE — b is exactly zero (and a is not zero).  Result is
//                    signed Inf with the algebraic z_sign.  Caller's
//                    FSM masks the writeback when CW.ZE is unmasked
//                    (the PR-2b.3c writeback-gate).
//     flags[1] = DE — never raised (caller guarantees no denormals).
//     flags[0] = IE — raised on the 0/0 case (invalid operation).
//
// Validation: sim/testfloat/gen_div_vectors generates (a, b, expected_z)
// tuples via the vendored Bochs oracle; sim/modelsim/execute_fpu_tb.v
// (PR-2b.3c phase) drives them through this module by issuing
// CMDEX_FDIV_ST0_STi and compares writeback.

`timescale 1ns / 1ps

module softfloat_div_x80 (
    // PR-2b.5x (iter 143, synth-unblock Slice 2a): clocked.  The two 128/64
    // divides now run on the iter-142 sequential restoring divider
    // (seq_divider_128_64) instead of native `/`/`%`.  start/done handshake:
    //   start : 1-cycle pulse latches operands & begins the ~131-cycle compute.
    //   done  : 1-cycle pulse the cycle z/flags are valid (they then hold).
    // add/sub/mul stay combinational; this is the only multi-cycle primitive,
    // and the only one that must expose this handshake so execute_fpu's
    // S_COMPUTE can widen into a wait state (Slice 2b).
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [79:0] a,
    input  wire [79:0] b,
    input  wire [1:0]  precision,   // PR-2b.5u: PC = CW[9:8]; 11/01 = extended (inline)
    output reg         done,
    output wire [79:0] z,
    output wire [5:0]  flags        // {PE, UE, OE, ZE, DE, IE}
);

    //--------------------------------------------------------------------
    // PR-2b.5x: operands are FROZEN into a_reg/b_reg on `start` so the whole
    // combinational fabric (normalize / special-case / round) sees stable
    // inputs across the multi-cycle compute, even after the pipeline's LIVE
    // op_b moves on.  Every classifier/normalizer below reads a_reg/b_reg
    // (NOT the live a/b ports).  Written by the compute FSM in the divide
    // section; declared here because the classifiers reference them.
    //--------------------------------------------------------------------
    reg [79:0] a_reg, b_reg;

    //--------------------------------------------------------------------
    // PR-2b.3f: NaN propagation override.  See floatx80_nan_handle.v.
    // NaN inputs short-circuit the normal-path division entirely.
    //--------------------------------------------------------------------
    wire        is_any_nan;
    wire [79:0] z_nan;
    wire [5:0]  flags_nan;
    floatx80_nan_handle u_nan (
        .a           (a_reg),
        .b           (b_reg),
        .is_nan_a    (),
        .is_nan_b    (),
        .is_any_nan  (is_any_nan),
        .is_any_snan (),
        .z_nan       (z_nan),
        .flags_nan   (flags_nan)
    );

    //--------------------------------------------------------------------
    // PR-2b.3g: Inf override.  Per-op rules:
    //   Inf / Inf    → QNaN_INDEFINITE + IE.
    //   Inf / finite → Inf (sign-XOR), no flags.  Includes Inf / 0 —
    //                  the Inf path takes precedence over the existing
    //                  b=0 ZE special-case below (Inf/0 is NOT a divide
    //                  by zero; it's a valid Inf result).
    //   finite / Inf → ±0 (sign-XOR), no flags.  Includes 0 / Inf.
    //--------------------------------------------------------------------
    wire is_inf_a, is_inf_b, is_any_inf;
    floatx80_inf_handle u_inf (
        .a          (a_reg),
        .b          (b_reg),
        .is_inf_a   (is_inf_a),
        .is_inf_b   (is_inf_b),
        .is_any_inf (is_any_inf)
    );
    wire inf_div_inf = is_inf_a & is_inf_b;
    wire [79:0] z_inf =
        inf_div_inf ? {1'b1, 15'h7FFF, 64'hC000000000000000} :   // QNaN_INDEFINITE
        is_inf_a    ? {a_reg[79] ^ b_reg[79], 15'h7FFF, 64'h8000000000000000} :  // ±Inf
                      {a_reg[79] ^ b_reg[79], 15'h0000, 64'h0000000000000000};   // ±0
    wire [5:0]  flags_inf = inf_div_inf ? 6'b000001 : 6'd0;

    //--------------------------------------------------------------------
    // PR-2b.3h: shared zero classifier — replaces the iter-31 local
    // a_is_zero / b_is_zero wires.  The existing ze_now / ie_now logic
    // in the normal-path (finite/0 → ZE+Inf, 0/0 → IE) consumes these
    // same bits; the new Zero override below covers the previously-
    // unhandled 0/finite → ±0 case.
    //--------------------------------------------------------------------
    wire is_zero_a, is_zero_b, is_any_zero;
    floatx80_zero_handle u_zero (
        .a           (a_reg),
        .b           (b_reg),
        .is_zero_a   (is_zero_a),
        .is_zero_b   (is_zero_b),
        .is_any_zero (is_any_zero)
    );
    // PARTIAL override — only the 0/finite case.  finite/0 (ZE+Inf) and
    // 0/0 (IE) remain in the normal-path's existing special-case branches
    // (z_normal already encodes them correctly); cascading those through
    // a uniform Zero override would have duplicated the logic.  Without
    // this partial override, 0/finite drove the normal divide path and
    // emitted a bogus z_exp = ~0x7FFF encoded as +Inf without ZE — see
    // iter-37 walkthrough in iteration_log.md.
    wire is_div_zero_override = is_zero_a & ~is_zero_b;
    wire [79:0] z_zero     = {a_reg[79] ^ b_reg[79], 79'd0};
    wire [5:0]  flags_zero = 6'd0;

    //--------------------------------------------------------------------
    // PR-2b.3i (cut 1, iter 38): denormal detection + DE flag.
    // OR'd into flags_normal at the bottom; doesn't affect z encoding.
    //--------------------------------------------------------------------
    wire is_subn_a, is_subn_b, is_any_subn;
    floatx80_subn_handle u_subn (
        .a           (a_reg),
        .b           (b_reg),
        .is_subn_a   (is_subn_a),
        .is_subn_b   (is_subn_b),
        .is_any_subn (is_any_subn)
    );

    //--------------------------------------------------------------------
    // PR-2b.3i (cut 2, iter 40): normalize denormal inputs so the
    // existing long-divide produces an IEEE-correct quotient when one or
    // both operands is denormal.  Note the zero special-cases (b=0 and
    // a=b=0) are decided from the RAW operands via is_zero_a / is_zero_b
    // above — those classifiers run on the unnormalized inputs, so a
    // genuine zero is NOT mistaken for a "normalized denormal".
    //--------------------------------------------------------------------
    wire               a_sign;
    wire signed [16:0] a_exp_s;
    wire        [63:0] a_sig;
    floatx80_normalize u_norm_a (
        .a        (a_reg),
        .sign_out (a_sign),
        .exp_out  (a_exp_s),
        .sig_out  (a_sig)
    );
    wire               b_sign;
    wire signed [16:0] b_exp_s;
    wire        [63:0] b_sig;
    floatx80_normalize u_norm_b (
        .a        (b_reg),
        .sign_out (b_sign),
        .exp_out  (b_exp_s),
        .sig_out  (b_sig)
    );

    wire        z_sign = a_sign ^ b_sign;

    //--------------------------------------------------------------------
    // Special-case detection.  Zero classification is now provided by
    // floatx80_zero_handle (instantiated above); use those wires.
    //--------------------------------------------------------------------
    wire a_is_zero = is_zero_a;   // PR-2b.3h alias — preserves the iter-31
    wire b_is_zero = is_zero_b;   //                  ze_now / ie_now names

    //--------------------------------------------------------------------
    // Exponent: zExp = aExp - bExp + 0x3FFE.  17-bit signed math; the
    // normalize wrapper above already widens the per-operand exps.
    //--------------------------------------------------------------------
    wire signed [16:0] z_exp_base = a_exp_s - b_exp_s + $signed(17'sh03FFE);

    //--------------------------------------------------------------------
    // Pre-divide 128-bit right-shift: if aSig >= bSig, shift the implicit
    // 128-bit value (aSig:0) right by 1 — placing the bit that falls off
    // the bottom of aSig at the TOP of the 64-bit rem1_init.  Bump zExp.
    //
    // This is `shift128Right`, NOT `shift64RightJamming`: jamming OR's the
    // lost bit into the LSB of the shifted value, which silently drops a
    // half-ULP when the LSB was already 1.  Bochs uses the 128-bit shift
    // so the lost bit retains its full numeric weight in the divider.
    //--------------------------------------------------------------------
    wire        a_ge_b      = (a_sig >= b_sig);
    wire [63:0] a_sig_eff   = a_ge_b ? {1'b0, a_sig[63:1]} : a_sig;
    wire [63:0] rem1_init   = a_ge_b ? {a_sig[0], 63'd0}   : 64'd0;
    wire signed [16:0] z_exp_pre = a_ge_b ? (z_exp_base + 17'sd1) : z_exp_base;

    //--------------------------------------------------------------------
    // PR-2b.5x (iter 143, synth-unblock Slice 2a): the two 128/64 divides
    // are now performed by a CLOCKED sequential restoring divider
    // (seq_divider_128_64, iter-142 Slice 1), one instance REUSED across two
    // passes (area-cheapest per design_synth_unblock.md):
    //   pass 1 : num128_first       / b_sig -> zSig0     (quot) + rem_after
    //   pass 2 : {rem_after,64'd0}   / b_sig -> zSig1_raw (quot) + r2 (sticky)
    // den128's high half is always 0, so seq_divider gets the 64-bit b_sig
    // directly.  The precondition num[127:64] < den holds for BOTH passes:
    //   pass1: a_sig_eff < b_sig (a_sig_eff = a_sig or a_sig>>1, b_sig>=2^63);
    //   pass2: rem_after < b_sig  (remainder of pass1).
    // Everything else (normalize/special/round) stays combinational off the
    // REGISTERED operands (a_reg/b_reg) and the REGISTERED quotients below;
    // `done` pulses the cycle z/flags are valid.
    //--------------------------------------------------------------------
    wire [127:0] num128_first = {a_sig_eff, rem1_init};

    localparam D_IDLE   = 3'd0,
               D_START1 = 3'd1,
               D_PASS1  = 3'd2,
               D_START2 = 3'd3,
               D_PASS2  = 3'd4;
    reg  [2:0]  dstate;
    reg  [63:0] zSig0_q;       // pass-1 quotient
    reg  [63:0] rem_after_q;   // pass-1 remainder (feeds pass-2 numerator)
    reg  [63:0] zSig1_raw_q;   // pass-2 quotient
    reg  [63:0] r2_q;          // pass-2 remainder (sticky source)

    wire [127:0] div_num   = (dstate == D_START1) ? num128_first
                                                  : {rem_after_q, 64'd0};
    wire [63:0]  div_den   = b_sig;
    wire         div_start = (dstate == D_START1) || (dstate == D_START2);
    wire [63:0]  div_q, div_r;
    wire         div_done;

    seq_divider_128_64 u_seqdiv (
        .clk       (clk),
        .rst       (rst),
        .start     (div_start),
        .num       (div_num),
        .den       (div_den),
        .quotient  (div_q),
        .remainder (div_r),
        .done      (div_done),
        .busy      ()
    );

    always @(posedge clk) begin
        if (rst) begin
            dstate      <= D_IDLE;
            done        <= 1'b0;
            a_reg       <= 80'd0;
            b_reg       <= 80'd0;
            zSig0_q     <= 64'd0;
            rem_after_q <= 64'd0;
            zSig1_raw_q <= 64'd0;
            r2_q        <= 64'd0;
        end else begin
            done <= 1'b0;                         // default; pulsed below
            case (dstate)
                D_IDLE: if (start) begin
                    a_reg  <= a;                 // freeze operands for the compute
                    b_reg  <= b;
                    dstate <= D_START1;
                end
                // a_reg/b_reg now settled -> num128_first valid; div_start is
                // high this cycle so the divider latches pass 1.
                D_START1: dstate <= D_PASS1;
                D_PASS1: if (div_done) begin
                    zSig0_q     <= div_q;
                    rem_after_q <= div_r;
                    dstate      <= D_START2;
                end
                // div_start high again -> divider latches pass 2.
                D_START2: dstate <= D_PASS2;
                D_PASS2: if (div_done) begin
                    zSig1_raw_q <= div_q;
                    r2_q        <= div_r;
                    done        <= 1'b1;         // z/flags combinational-valid now
                    dstate      <= D_IDLE;
                end
                default: dstate <= D_IDLE;
            endcase
        end
    end

    // Quotient/remainder aliases from the FSM-registered results.  zSig1
    // carries the next 64 mantissa bits with the second-divide sticky OR'd
    // into its LSB, matching Bochs's `zSig1 |= ((rem1 | rem2) != 0)`.
    wire [63:0]  zSig0      = zSig0_q;
    wire [63:0]  zSig1_raw  = zSig1_raw_q;
    wire         sticky_pre = |r2_q;
    wire [63:0]  zSig1      = zSig1_raw | {63'd0, sticky_pre};

    //--------------------------------------------------------------------
    // Round to nearest even (precision 80).  Round bit = zSig1[63];
    // sticky = |zSig1[62:0].  Increment when round_bit & (sticky |
    // ulp_low) where ulp_low = zSig0[0].  After increment, carry-out
    // means the mantissa rolled past 2^64 → reset to 0x8000... and
    // bump zExp.
    //--------------------------------------------------------------------
    wire        round_bit = zSig1[63];
    wire        sticky    = |zSig1[62:0];
    wire        ulp_low   = zSig0[0];
    wire        round_up  = round_bit & (sticky | ulp_low);

    wire [64:0] mant_rnd  = {1'b0, zSig0} + {64'd0, round_up};
    wire        rnd_carry = mant_rnd[64];
    wire [63:0] mant_norm = rnd_carry ? 64'h8000000000000000
                                       : mant_rnd[63:0];
    wire signed [16:0] z_exp_norm = rnd_carry ? (z_exp_pre + 17'sd1) : z_exp_pre;

    //--------------------------------------------------------------------
    // Zero-divide override: if b is exactly zero and a is non-zero,
    // force the result to signed Inf and raise ZE.  If both are zero,
    // raise IE (0/0 invalid) and leave the encoding alone (real
    // hardware would emit QNaN_INDEFINITE; deferred to PR-2b.3e along
    // with the NaN family).
    //--------------------------------------------------------------------
    wire ze_now = b_is_zero & ~a_is_zero;
    wire ie_now = a_is_zero & b_is_zero;
    // PR-2b.3j (iter 39): OE qualified by ~ze_now & ~ie_now so the
    // existing finite/0 (ZE+Inf) and 0/0 (IE) branches keep their
    // encodings — overflow only applies to the genuine "huge/tiny" case.
    wire oe_now = ~ze_now & ~ie_now & (z_exp_norm >= $signed(17'sh07FFF));
    // PR-2b.3i cut 2 (iter 40): UE detection — similarly qualified by
    // ~ze_now & ~ie_now & ~a_is_zero so the 0/finite case (which already
    // returns +0 via the is_div_zero_override cascade arm above) doesn't
    // double-count as underflow.  Fires on the genuine "tiny quotient"
    // case (e.g. small_normal / big_normal, denormal / big_normal).
    wire ue_now = ~ze_now & ~ie_now & ~a_is_zero &
                  (z_exp_norm <= $signed(17'sd0)) &
                  (mant_norm != 64'd0);

    //--------------------------------------------------------------------
    // PR-2b.3j: when OE fires, emit signed Inf encoding (matches the
    // ze_now branch's signed-Inf form, but driven by the overflow gate).
    // ze_now's signed Inf takes priority since it's a per-op-defined
    // result, not an overflow saturation; with oe_now's ~ze_now qualifier
    // they're mutually exclusive in practice.
    //
    // PR-2b.3i cut 3 (iter 41): subnormal-result encoding via shared
    // floatx80_pack_subn helper.  Feeds the UNROUNDED (zSig0, zSig1) and
    // z_exp_pre — the helper shifts/jams/re-rounds.  ze_now and ie_now
    // take precedence over ue_now (so finite/0 and 0/0 keep their
    // existing special-case encodings).
    //--------------------------------------------------------------------
    wire [79:0] z_subn;
    wire        pe_subn;
    floatx80_pack_subn u_pack_subn (
        .sign      (z_sign),
        .z_exp_pre (z_exp_pre),
        .sig_hi    (zSig0),
        .sig_lo    (zSig1),
        .z_subn    (z_subn),
        .pe_subn   (pe_subn)
    );

    wire [14:0] z_exp_normal = z_exp_norm[14:0];
    wire [14:0] z_exp_out    = (ze_now | oe_now | ie_now) ? 15'h7FFF : z_exp_normal;
    // PR-2b.4e (iter 56): 0/0 IE branch now emits canonical x87
    // QNaN_INDEFINITE (sign=1, exp=7FFF, frac=C000_...).  Closes the
    // long-standing iter-23 TODO ("real hardware would emit QNaN_INDEFINITE;
    // deferred to PR-2b.3e along with the NaN family") — the bug was latent
    // because reg-form gen_div_vectors didn't include 0/0; iter-56's
    // gen_fdiv_mem_vectors does.  Without this fix the normal-path mant_norm
    // for 0/0 is X (long-divide of 0/0 produces X bits), which propagates
    // to rf_wr_data and the regfile.  ze_now/oe_now keep their signed Inf
    // encoding; ie_now's z_sig is the QNaN_INDEFINITE-specific J-bit + QNaN
    // bit pattern.  z_sign is overridden to 1 in the final z mux below so
    // the canonical form has the negative sign per SDM Vol 1 §4.8.3.7.
    wire [63:0] z_sig_out    = ie_now              ? 64'hC000000000000000 :
                               (ze_now | oe_now)   ? 64'h8000000000000000 :
                                                     mant_norm;

    wire [79:0] z_normal_pre = {ie_now ? 1'b1 : z_sign, z_exp_out, z_sig_out};
    // Pick canonical subnormal when ue_now fires (ze_now/ie_now already
    // exclude themselves from ue_now via the ~ze_now & ~ie_now qualifiers).
    wire [79:0] z_normal     = ue_now ? z_subn : z_normal_pre;

    //--------------------------------------------------------------------
    // Exception flags.  PE forced when OE fires (Bochs OE-pairs-with-PE).
    // When UE fires the PE bit tracks the helper's post-shift re-round.
    //--------------------------------------------------------------------
    wire pe_now_base = ((round_bit | sticky) | oe_now) & ~ze_now & ~ie_now;
    wire pe_now      = ue_now ? pe_subn : pe_now_base;

    wire [5:0]  flags_normal = { pe_now,    // [5] PE
                                 ue_now,    // [4] UE
                                 oe_now,    // [3] OE
                                 ze_now,    // [2] ZE
                                 1'b0,      // [1] DE
                                 ie_now };  // [0] IE

    // PR-2b.3i: OR DE into normal-path flags when any input is denormal.
    wire [5:0]  flags_normal_w_de = flags_normal | {4'd0, is_any_subn, 1'd0};

    //--------------------------------------------------------------------
    // PR-2b.5u (iter 139): precision-control (PC = CW[9:8]) narrowing.
    // Shared rounder fed the UNROUNDED (z_sign, z_exp_pre, zSig0, zSig1)
    // — the same triple this primitive's inline rounder and
    // floatx80_pack_subn consume.  Gated on ~ze_now & ~ie_now so the
    // finite/0 (ZE→Inf) and 0/0 (IE→QNaN_INDEFINITE) special encodings are
    // preserved; the helper still covers the genuine OE/UE finite-quotient
    // cases.  PC=80 keeps z_normal byte-identical.
    //--------------------------------------------------------------------
    wire        is_pc_narrow = (precision == 2'b00) || (precision == 2'b10);
    wire        do_pc        = is_pc_narrow && ~ze_now && ~ie_now;
    wire [79:0] z_pc;
    wire [5:0]  flags_pc;
    floatx80_round_pc u_round_pc (
        .precision  (precision),
        .sign       (z_sign),
        .z_exp_pre  (z_exp_pre),
        .z_sig0_pre (zSig0),
        .z_sig1_pre (zSig1),
        .z          (z_pc),
        .flags      (flags_pc)
    );
    wire [79:0] z_normal_pc     = do_pc ? z_pc : z_normal;
    wire [5:0]  flags_normal_pc = do_pc
                                ? (flags_pc | {4'd0, is_any_subn, 1'd0})
                                : flags_normal_w_de;

    // Override cascade: NaN > Inf > Zero(partial) > normal(+DE if denormal).
    //   NaN/x          → z_nan        (beats Inf and ZE)
    //   Inf/x, x/Inf   → z_inf        (Inf/0 = Inf, not Inf+ZE)
    //   0/finite       → z_zero       (PR-2b.3h partial override)
    //   finite/0, 0/0  → z_normal     (existing ZE+Inf / IE branches)
    assign z     = is_any_nan          ? z_nan
                 : is_any_inf          ? z_inf
                 : is_div_zero_override ? z_zero
                                        : z_normal_pc;
    assign flags = is_any_nan          ? flags_nan
                 : is_any_inf          ? flags_inf
                 : is_div_zero_override ? flags_zero
                                        : flags_normal_pc;

endmodule
