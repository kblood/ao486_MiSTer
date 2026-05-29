// floatx80_round_pc.v
//
// PR-2b.5u (iter 138): shared precision-control rounder.  Implements the
// PC<80 branch of Bochs SoftFloatRoundAndPackFloatx80 (RNE only) at
// tools/upstream_bochs/.../cpu/fpu/softfloat-round-pack.cc:577-645.
//
// Each softfloat_{add,sub,mul,div}_x80 primitive computes a pre-round triple
// (z_sig0_pre, z_sig1_pre, z_exp_pre) — a 64-bit significand (J-bit at [63]),
// a 64-bit extra/sticky word, and a signed biased exponent — and then does
// its OWN inline RNE round-at-bit-0 for the default extended (PC=80) case.
// This helper takes that SAME pre-round triple and rounds it at the reduced
// precision point selected by the control word's PC field (CW[9:8]):
//
//   PC=10  double  (64): round at bit 11, mask low 11, increment 0x400
//   PC=00  single  (32): round at bit 40, mask low 40, increment 0x8000000000
//   PC=11/01           : passthrough (extended) — caller uses its inline path,
//                        so this branch only repacks for unit-TB completeness.
//
// Rounding ONCE at the PC point (not round-to-80-then-renarrow) is what makes
// the result bit-exact to Bochs — no double-rounding.  See
// research/design_precision_control.md.
//
// Flags: this helper owns ONLY {PE, UE, OE}.  IE/DE/ZE are operand-class flags
// the calling primitive's NaN/Inf/Zero/denormal cascade already produces; the
// caller ORs its DE-from-denormal-input into these flags and lets the
// NaN/Inf/Zero overrides sit on top, exactly as it does for the PC=80 path.
//
// Masked-exception semantics (FNINIT default; matches the rest of the FPU):
//   OE -> saturate to signed Inf  {sign, 0x7FFF, 0x8000_..._0000} + PE
//   UE -> subnormal encoding + UE (when tiny AND inexact) + PE
//
// RNE only: every arith primitive is RNE-only today (CW.RC is not plumbed to
// them).  PC is implemented under the same RNE assumption — see the design doc.

`timescale 1ns / 1ps

module floatx80_round_pc (
    input  wire        [1:0]  precision,    // 2'b10=PC64, 2'b00=PC32, else passthrough
    input  wire               sign,
    input  wire signed [16:0] z_exp_pre,    // biased, pre-round
    input  wire        [63:0] z_sig0_pre,   // J-bit at [63]
    input  wire        [63:0] z_sig1_pre,   // extra/sticky word

    output wire        [79:0] z,
    output wire        [5:0]  flags         // {PE, UE, OE, ZE, DE, IE}
);

    localparam signed [16:0] EXP_OVF = 17'sd32766;   // 0x7FFE

    wire is_pc64      = (precision == 2'b10);
    wire is_pc32      = (precision == 2'b00);
    wire is_pc_narrow = is_pc64 | is_pc32;

    wire [63:0] roundIncrement = is_pc64 ? 64'h0000000000000400
                                         : 64'h0000008000000000;
    wire [63:0] roundMask      = is_pc64 ? 64'h00000000000007FF
                                         : 64'h000000FFFFFFFFFF;
    wire [63:0] maskPlus1      = roundMask + 64'd1;   // 0x800 / 0x10000000000

    //--------------------------------------------------------------------
    // Step 1: fold the extra word into a sticky LSB of sig0.
    //--------------------------------------------------------------------
    wire [63:0] sig0 = z_sig0_pre | {63'd0, |z_sig1_pre};

    // Increment (used by both the carry/overflow test and the normal add).
    wire [64:0] sig0_inc_full = {1'b0, sig0} + {1'b0, roundIncrement};
    wire        inc_carry     = sig0_inc_full[64];   // carried out of bit 63

    //--------------------------------------------------------------------
    // Classify exponent region (Bochs `0x7FFD <= (u32)(zExp-1)` idiom).
    //--------------------------------------------------------------------
    wire is_ovf  = (z_exp_pre > EXP_OVF) ||
                   ((z_exp_pre == EXP_OVF) && inc_carry);
    wire is_tiny = ~is_ovf && (z_exp_pre <= 17'sd0);

    //--------------------------------------------------------------------
    // NORMAL path (0 < zExp <= 0x7FFE, no overflow).
    //--------------------------------------------------------------------
    wire [63:0]        rb_norm      = sig0 & roundMask;
    wire               pe_norm      = |rb_norm;
    wire [63:0]        sig0_n_inc   = inc_carry ? 64'h8000000000000000
                                                : sig0_inc_full[63:0];
    wire signed [16:0] exp_n_inc    = inc_carry ? (z_exp_pre + 17'sd1)
                                                : z_exp_pre;
    wire               tie_norm     = ((rb_norm << 1) == maskPlus1);
    wire [63:0]        mask_n_eff   = tie_norm ? (roundMask | maskPlus1)
                                              : roundMask;
    wire [63:0]        sig0_n_final = sig0_n_inc & ~mask_n_eff;
    wire signed [16:0] exp_n_final  = (sig0_n_final == 64'd0) ? 17'sd0
                                                              : exp_n_inc;

    //--------------------------------------------------------------------
    // TINY path (zExp <= 0): shift-right-jam to subnormal, re-round at PC.
    //   shiftCount = 1 - zExp  (>= 1)
    //--------------------------------------------------------------------
    wire signed [16:0] sc_signed = 17'sd1 - z_exp_pre;
    wire        [16:0] shiftCount = sc_signed[16:0];   // always > 0 in tiny path

    // shift64RightJamming(sig0, shiftCount)
    reg  [63:0] sig0_sh;
    // verilator lint_off WIDTH
    always @* begin
        if (shiftCount == 17'd0)
            sig0_sh = sig0;
        else if (shiftCount < 17'd64)
            sig0_sh = (sig0 >> shiftCount) |
                      {63'd0, |(sig0 & ((64'd1 << shiftCount) - 64'd1))};
        else
            sig0_sh = {63'd0, |sig0};
    end
    // verilator lint_on WIDTH

    // isTiny: zExp<0, OR adding roundIncrement does NOT carry out of bit 63
    // (i.e. the value is not large enough to round up to min-normal).
    wire               isTiny    = (z_exp_pre < 17'sd0) || ~inc_carry;
    wire [63:0]        rb_tiny   = sig0_sh & roundMask;
    wire               pe_tiny   = |rb_tiny;
    wire               ue_tiny   = isTiny && pe_tiny;
    wire [63:0]        sig0_t_inc = sig0_sh + roundIncrement;
    // bit 63 set after increment => rounded up to the min-normal encoding.
    wire signed [16:0] exp_t_inc  = sig0_t_inc[63] ? 17'sd1 : 17'sd0;
    wire               tie_tiny   = ((rb_tiny << 1) == maskPlus1);
    wire [63:0]        mask_t_eff = tie_tiny ? (roundMask | maskPlus1)
                                            : roundMask;
    wire [63:0]        sig0_t_final = sig0_t_inc & ~mask_t_eff;

    //--------------------------------------------------------------------
    // Assemble the narrow-PC result + its flags.
    //--------------------------------------------------------------------
    wire [79:0] z_ovf  = {sign, 15'h7FFF, 64'h8000000000000000};
    wire [79:0] z_norm = {sign, exp_n_final[14:0], sig0_n_final};
    wire [79:0] z_tiny = {sign, exp_t_inc[14:0],   sig0_t_final};

    wire [79:0] z_narrow = is_ovf  ? z_ovf
                         : is_tiny ? z_tiny
                                   : z_norm;

    // {PE, UE, OE, ZE, DE, IE}
    wire pe_narrow = is_ovf ? 1'b1 : (is_tiny ? pe_tiny : pe_norm);
    wire ue_narrow = is_tiny ? ue_tiny : 1'b0;
    wire oe_narrow = is_ovf;
    wire [5:0] flags_narrow = {pe_narrow, ue_narrow, oe_narrow, 3'b000};

    //--------------------------------------------------------------------
    // Passthrough (PC=80) — repack unrounded; caller normally uses its own
    // inline path here, so flags are zero.
    //--------------------------------------------------------------------
    wire [79:0] z_passthru = {sign, z_exp_pre[14:0], z_sig0_pre};

    assign z     = is_pc_narrow ? z_narrow : z_passthru;
    assign flags = is_pc_narrow ? flags_narrow : 6'd0;

endmodule
