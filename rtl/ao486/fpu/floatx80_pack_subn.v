// floatx80_pack_subn.v
//
// PR-2b.3i (cut 3, iter 41): subnormal-result packer.  Pure combinational
// helper invoked by each softfloat_{add,sub,mul,div}_x80 primitive when
// the post-arith exponent is non-positive on a non-zero result (the
// existing ue_now detector).
//
// Algorithm (Bochs roundAndPackFloatx80 precision80 subnormal arm at
// sim/testfloat/softfloat/softfloat-round-pack.cc:677-702):
//
//   shift_count = 1 - z_exp_pre              // signed; 1..many
//   {zSig0, zSig1} = shift64ExtraRightJamming({sig_hi, sig_lo}, shift_count)
//   round_bit = zSig1[63]; sticky = |zSig1[62:0]; ulp_low = zSig0[0]
//   round_up  = round_bit & (sticky | ulp_low)            // RTNE
//   zSig0    += round_up
//   if (zSig0[63])    // rounded up to min-normal (0x8000_..._0000)
//       exp_out = 1
//   else
//       exp_out = 0
//   z_subn = {sign, exp_out, zSig0}
//
// Notes
// -----
// * Pre-rnd-carry input.  The caller passes the UNROUNDED (sig_hi, sig_lo)
//   from BEFORE its own round step — the existing normal-path round step
//   would have lost precision at the wrong bit position (the post-shift
//   LSB is further LEFT for subnormal results).  The helper re-rounds on
//   the post-shift sig pair so the dropped bits are at the right place.
//
// * Bochs's `isTiny` underflow-mask check is NOT replicated here — our
//   caller raises UE unconditionally when z_exp_final <= 0 on a non-zero
//   result.  The corner case where rounding bumps an exact-half-way back
//   to min-normal without raising UE (Bochs's `zSig0 < 0xFFFF...FFFF`
//   sub-condition) is rare and the conservative-UE behaviour matches what
//   real x87 stacks have shipped (Bochs trap-on-rounding-boundary is a
//   strict-IEEE refinement; software handlers that mask UE see no
//   observable difference, software that unmasks UE traps slightly more
//   often than Bochs would — closer to the IEEE intent).
//
// * Shift count clamped to [0, 128].  Anything past 128 collapses to a
//   sticky-only result (round_bit = 0, sticky from the jam-OR) which
//   matches IEEE-754's flush-to-zero-with-PE intent for catastrophically
//   tiny products.
//
// * For shift_count = 0 (helper called with z_exp_pre = 1; defensive only)
//   the result is the unshifted sig_hi rounded with the unshifted sig_lo —
//   identical to the existing normal-round path.  The caller's cascade
//   won't pick z_subn in this case (ue_now requires z_exp_final <= 0).

`timescale 1ns / 1ps

module floatx80_pack_subn (
    input  wire               sign,
    input  wire signed [16:0] z_exp_pre,    // pre-rnd-carry exp; <= 0 triggers subnormal pack
    input  wire        [63:0] sig_hi,        // unrounded sig hi (J-bit at [63] for shift_count=0)
    input  wire        [63:0] sig_lo,        // unrounded sig lo (round + sticky territory)

    output wire        [79:0] z_subn,
    output wire               pe_subn        // round_bit | sticky from the re-round step
);

    //--------------------------------------------------------------------
    // shift_count = 1 - z_exp_pre, clamped to [0, 128].
    //--------------------------------------------------------------------
    wire signed [16:0] sc_signed = $signed(17'sd1) - z_exp_pre;
    wire        [7:0]  shift_count =
        (sc_signed >= $signed(17'sd128)) ? 8'd128 :
        (sc_signed <= $signed(17'sd0))   ? 8'd0   :
        sc_signed[7:0];

    //--------------------------------------------------------------------
    // shift64ExtraRightJamming({sig_hi, sig_lo}, shift_count, &zSig0, &zSig1).
    //
    // Construct the 128-bit combined sig, shift right by `shift_count`, and
    // OR every bit that fell off the bottom into zSig1's LSB (the "jam").
    //--------------------------------------------------------------------
    wire [127:0] combined = {sig_hi, sig_lo};
    // verilator lint_off WIDTH
    wire [127:0] shifted  = combined >> shift_count;
    wire [127:0] mask     = (128'd1 << shift_count) - 128'd1;
    // verilator lint_on WIDTH
    wire         lost_nonzero = |(combined & mask);

    wire [63:0]  zSig0_post     = shifted[127:64];
    wire [63:0]  zSig1_post_pre = shifted[63:0];
    wire [63:0]  zSig1_post     = {zSig1_post_pre[63:1],
                                   zSig1_post_pre[0] | lost_nonzero};

    //--------------------------------------------------------------------
    // Round to nearest even on the post-shift sig pair.
    //--------------------------------------------------------------------
    wire round_bit = zSig1_post[63];
    wire sticky    = |zSig1_post[62:0];
    wire ulp_low   = zSig0_post[0];
    wire round_up  = round_bit & (sticky | ulp_low);

    //--------------------------------------------------------------------
    // Increment.  For shift_count >= 1, zSig0_post[63] is guaranteed 0
    // (the J-bit got shifted into zSig1_post[63] or lower), so adding 1
    // can at most produce bit 63 = 1 — the min-normal encoding.
    //--------------------------------------------------------------------
    wire [63:0]  zSig0_rnd = zSig0_post + {63'd0, round_up};

    // If the round bumped zSig0 back into the min-normal range
    // (bit 63 = 1), encode exp = 1 per Bochs; else true subnormal (exp = 0).
    wire [14:0]  exp_out   = zSig0_rnd[63] ? 15'd1 : 15'd0;

    assign z_subn  = {sign, exp_out, zSig0_rnd};
    assign pe_subn = round_bit | sticky;

endmodule
