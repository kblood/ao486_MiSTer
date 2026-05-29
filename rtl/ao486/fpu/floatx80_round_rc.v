// floatx80_round_rc.v
//
// PR-2b.5y (iter 150): shared rounding-control + precision-control rounder.
// Implements the FULL Bochs SoftFloatRoundAndPackFloatx80
// (tools/upstream_bochs/.../cpu/fpu/softfloat-round-pack.cc:568-721) for ALL
// rounding-control modes (CW.RC = CW[11:10]) and ALL precision modes
// (CW.PC = CW[9:8]) — a generalization of the iter-138 RNE-only
// floatx80_round_pc.v.
//
// rc:  2'b00 nearest-even | 2'b01 down(-inf) | 2'b10 up(+inf) | 2'b11 to-zero.
//      The x87 CW[11:10] encoding equals the Bochs float_round_* enum
//      (nearest_even=0, down=1, up=2, to_zero=3), so it maps straight through.
// precision: 2'b00 single(32) | 2'b10 double(64) | else (11/01) extended(80).
//
// Each softfloat_{add,sub,mul,div}_x80 primitive computes a pre-round triple
// (z_sig0_pre, z_sig1_pre, z_exp_pre) — a 64-bit significand (J-bit at [63]),
// a 64-bit extra/sticky word, and a signed biased exponent.  This helper
// rounds that triple ONCE at the precision point selected by `precision`, in
// the direction selected by `rc`:
//   - precision == 64/32: round within zSig0 at bit 11 / bit 40 (PC<80 branch).
//   - precision == 80:    round at the zSig0/zSig1 boundary (precision80 branch).
// Rounding once at the target point (not round-to-80-then-renarrow) is what
// makes the result bit-exact to Bochs.
//
// Flags: owns ONLY {PE, UE, OE}.  IE/DE/ZE are operand-class flags the calling
// primitive's NaN/Inf/Zero/denormal cascade already produces; the caller ORs
// its DE-from-denormal-input in and lets NaN/Inf/Zero overrides sit on top.
//
// Masked-exception semantics (FNINIT default; matches the rest of the FPU):
//   OE -> for round-to-zero / round-away-from-Inf modes, saturate to the max
//         FINITE value {sign, 0x7FFE, ~roundMask}; otherwise signed Inf
//         {sign, 0x7FFF, 0x8000_..._0000}.  Always + PE.
//   UE -> subnormal encoding + UE (when tiny AND inexact) + PE.
//
// The caller routes the normal-arith arm here whenever (rc != nearest) OR
// PC<80; the default (nearest, PC=80) keeps its validated inline path
// byte-identical (zero regression).  See research/design_rounding_control.md.

`timescale 1ns / 1ps

module floatx80_round_rc (
    input  wire        [1:0]  rc,           // CW[11:10]
    input  wire        [1:0]  precision,    // CW[9:8]
    input  wire               sign,
    input  wire signed [16:0] z_exp_pre,    // biased, pre-round
    input  wire        [63:0] z_sig0_pre,   // J-bit at [63]
    input  wire        [63:0] z_sig1_pre,   // extra/sticky word

    output wire        [79:0] z,
    output wire        [5:0]  flags         // {PE, UE, OE, ZE, DE, IE}
);

    localparam [1:0] RC_NEAREST = 2'b00,
                     RC_DOWN    = 2'b01,
                     RC_UP      = 2'b10,
                     RC_ZERO    = 2'b11;

    localparam signed [16:0] EXP_OVF = 17'sd32766;   // 0x7FFE

    wire rne          = (rc == RC_NEAREST);
    wire is_pc64      = (precision == 2'b10);
    wire is_pc32      = (precision == 2'b00);
    wire is_pc_narrow = is_pc64 | is_pc32;

    //====================================================================
    // Shared overflow encoding.  Reached from both the PC<80 overflow
    // (Bochs `goto overflow` keeps the PC roundMask live) and the PC=80
    // overflow (roundMask forced 0 -> ~0 = all-ones).  Round-to-zero and
    // round-away-from-Inf modes return the max finite ~roundMask; the
    // round-toward-Inf cases (incl. all RNE) return signed Inf.
    //====================================================================
    wire [63:0] ovf_roundMask = is_pc_narrow ? (is_pc64 ? 64'h00000000000007FF
                                                        : 64'h000000FFFFFFFFFF)
                                             : 64'd0;
    wire ovf_to_finite = (rc == RC_ZERO)
                       || ( sign && (rc == RC_UP))
                       || (~sign && (rc == RC_DOWN));
    wire [79:0] z_ovf = ovf_to_finite ? {sign, 15'h7FFE, ~ovf_roundMask}
                                      : {sign, 15'h7FFF, 64'h8000000000000000};
    wire [5:0]  flags_ovf = 6'b101000;   // PE|OE

    //====================================================================
    // PC<80 branch (precision == 64 or 32): round within zSig0.
    //====================================================================
    wire [63:0] n_roundMask = is_pc64 ? 64'h00000000000007FF
                                      : 64'h000000FFFFFFFFFF;
    wire [63:0] n_incr_rne  = is_pc64 ? 64'h0000000000000400
                                      : 64'h0000008000000000;
    wire [63:0] n_maskPlus1 = n_roundMask + 64'd1;

    // directed roundIncrement (Bochs lines 588-599)
    reg [63:0] n_roundIncrement;
    always @* begin
        if (rne)                 n_roundIncrement = n_incr_rne;
        else if (rc == RC_ZERO)  n_roundIncrement = 64'd0;
        else begin
            n_roundIncrement = n_roundMask;
            if (sign) begin if (rc == RC_UP)   n_roundIncrement = 64'd0; end
            else      begin if (rc == RC_DOWN) n_roundIncrement = 64'd0; end
        end
    end

    wire [63:0] n_sig0          = z_sig0_pre | {63'd0, |z_sig1_pre};
    wire [63:0] n_roundBits     = n_sig0 & n_roundMask;
    wire [64:0] n_sig0_inc_full = {1'b0, n_sig0} + {1'b0, n_roundIncrement};
    wire        n_inc_carry     = n_sig0_inc_full[64];

    wire n_is_ovf  = (z_exp_pre > EXP_OVF) ||
                     ((z_exp_pre == EXP_OVF) && n_inc_carry);
    wire n_is_tiny = ~n_is_ovf && (z_exp_pre <= 17'sd0);

    // --- normal path (0 < zExp < 0x7FFE) ---
    wire               n_pe_norm   = |n_roundBits;
    wire [63:0]        n_sig0_n_inc = n_inc_carry ? 64'h8000000000000000
                                                  : n_sig0_inc_full[63:0];
    wire signed [16:0] n_exp_n_inc  = n_inc_carry ? (z_exp_pre + 17'sd1)
                                                  : z_exp_pre;
    wire               n_tie_norm   = rne && ((n_roundBits << 1) == n_maskPlus1);
    wire [63:0]        n_mask_n_eff = n_tie_norm ? (n_roundMask | n_maskPlus1)
                                                 : n_roundMask;
    wire [63:0]        n_sig0_n_fin = n_sig0_n_inc & ~n_mask_n_eff;
    wire signed [16:0] n_exp_n_fin  = (n_sig0_n_fin == 64'd0) ? 17'sd0
                                                              : n_exp_n_inc;

    // --- tiny path (zExp <= 0) ---
    wire signed [16:0] n_sc = 17'sd1 - z_exp_pre;          // shiftCount >= 1
    reg  [63:0] n_sig0_sh;
    // verilator lint_off WIDTH
    always @* begin
        if (n_sc <= 17'sd0)        n_sig0_sh = n_sig0;     // guard; sc>=1 here
        else if (n_sc < 17'sd64)
            n_sig0_sh = (n_sig0 >> n_sc) |
                        {63'd0, |(n_sig0 & ((64'd1 << n_sc) - 64'd1))};
        else
            n_sig0_sh = {63'd0, |n_sig0};
    end
    // verilator lint_on WIDTH
    wire               n_isTiny    = (z_exp_pre < 17'sd0) || ~n_inc_carry;
    wire [63:0]        n_rb_tiny   = n_sig0_sh & n_roundMask;
    wire               n_pe_tiny   = |n_rb_tiny;
    wire               n_ue_tiny   = n_isTiny && n_pe_tiny;
    wire [63:0]        n_sig0_t_inc = n_sig0_sh + n_roundIncrement;
    wire signed [16:0] n_exp_t_inc  = n_sig0_t_inc[63] ? 17'sd1 : 17'sd0;
    wire               n_tie_tiny   = rne && ((n_rb_tiny << 1) == n_maskPlus1);
    wire [63:0]        n_mask_t_eff = n_tie_tiny ? (n_roundMask | n_maskPlus1)
                                                 : n_roundMask;
    wire [63:0]        n_sig0_t_fin = n_sig0_t_inc & ~n_mask_t_eff;

    wire [79:0] n_z_norm = {sign, n_exp_n_fin[14:0], n_sig0_n_fin};
    wire [79:0] n_z_tiny = {sign, n_exp_t_inc[14:0],  n_sig0_t_fin};
    wire [79:0] n_z      = n_is_ovf  ? z_ovf
                         : n_is_tiny ? n_z_tiny
                                     : n_z_norm;
    wire        n_pe     = n_is_ovf  ? 1'b1 : (n_is_tiny ? n_pe_tiny : n_pe_norm);
    wire        n_ue     = n_is_tiny ? n_ue_tiny : 1'b0;
    wire        n_oe     = n_is_ovf;
    wire [5:0]  n_flags  = {n_pe, n_ue, n_oe, 3'b000};

    //====================================================================
    // PC=80 branch (precision80): round at the zSig0/zSig1 boundary.
    //====================================================================
    // increment = round-up-by-1-ULP decision (Bochs lines 647-658)
    reg p_increment;
    always @* begin
        if (rne) p_increment = z_sig1_pre[63];
        else if (rc == RC_ZERO) p_increment = 1'b0;
        else if (sign) p_increment = (rc == RC_DOWN) && (|z_sig1_pre);
        else           p_increment = (rc == RC_UP)   && (|z_sig1_pre);
    end

    wire p_is_ovf  = (z_exp_pre > EXP_OVF) ||
                     ((z_exp_pre == EXP_OVF) &&
                      (z_sig0_pre == 64'hFFFFFFFFFFFFFFFF) && p_increment);
    wire p_is_tiny = ~p_is_ovf && (z_exp_pre <= 17'sd0);

    // --- normal path ---
    wire               p_pe_norm    = |z_sig1_pre;
    wire [64:0]        p_sig0_inc   = {1'b0, z_sig0_pre} + {64'd0, p_increment};
    wire               p_carry_norm = p_increment && (p_sig0_inc[63:0] == 64'd0);
    // tie-to-even clear: zSig0 &= ~((zSig1<<1==0) & RNE) when incremented w/o carry
    wire               p_tie_clr    = rne && ((z_sig1_pre << 1) == 64'd0);
    wire [63:0]        p_sig0_n_pre = p_carry_norm ? 64'h8000000000000000
                                                   : p_sig0_inc[63:0];
    wire [63:0]        p_sig0_n_fin = (p_increment && ~p_carry_norm && p_tie_clr)
                                        ? (p_sig0_n_pre & ~64'd1)
                                        : p_sig0_n_pre;
    // exp: ++ on carry-out; ->0 when result is zero and not incremented
    wire signed [16:0] p_exp_n_fin  = p_carry_norm ? (z_exp_pre + 17'sd1)
                                      : (~p_increment && (z_sig0_pre == 64'd0))
                                          ? 17'sd0
                                          : z_exp_pre;

    // --- tiny path ---
    // shift64ExtraRightJamming(zSig0, zSig1, 1 - zExp) -> (sh0, sh1)
    wire signed [16:0] p_sc = 17'sd1 - z_exp_pre;          // count >= 1
    reg  [63:0] p_sh0, p_sh1;
    // verilator lint_off WIDTH
    always @* begin
        if (p_sc <= 17'sd0)        begin p_sh0 = z_sig0_pre; p_sh1 = z_sig1_pre; end
        else if (p_sc < 17'sd64)   begin
            p_sh0 = z_sig0_pre >> p_sc;
            p_sh1 = (z_sig0_pre << ((17'sd64 - p_sc) & 17'sd63)) | {63'd0, |z_sig1_pre};
        end
        else if (p_sc == 17'sd64)  begin
            p_sh0 = 64'd0;
            p_sh1 = z_sig0_pre | {63'd0, |z_sig1_pre};
        end
        else begin
            p_sh0 = 64'd0;
            p_sh1 = {63'd0, |(z_sig0_pre | z_sig1_pre)};
        end
    end
    // verilator lint_on WIDTH
    wire p_isTiny = (z_exp_pre < 17'sd0) || ~p_increment ||
                    (z_sig0_pre != 64'hFFFFFFFFFFFFFFFF);
    // recompute increment after the shift (Bochs lines 687-694)
    reg p_inc_t;
    always @* begin
        if (rne) p_inc_t = p_sh1[63];
        else if (sign) p_inc_t = (rc == RC_DOWN) && (|p_sh1);
        else           p_inc_t = (rc == RC_UP)   && (|p_sh1);
    end
    wire        p_ue_tiny   = p_isTiny && (|p_sh1);          // masked: tiny && inexact
    wire        p_pe_tiny   = |p_sh1;
    wire [64:0] p_sig0_t_inc = {1'b0, p_sh0} + {64'd0, p_inc_t};
    wire        p_tie_clr_t = rne && ((p_sh1 << 1) == 64'd0);
    wire [63:0] p_sig0_t_pre = p_sig0_t_inc[63:0];
    wire [63:0] p_sig0_t_fin = (p_inc_t && p_tie_clr_t) ? (p_sig0_t_pre & ~64'd1)
                                                        : p_sig0_t_pre;
    // (Bit64s)zSig0 < 0 after increment => rounded up to min-normal => zExp = 1
    wire signed [16:0] p_exp_t_fin = (p_inc_t && p_sig0_t_fin[63]) ? 17'sd1 : 17'sd0;

    wire [79:0] p_z_norm = {sign, p_exp_n_fin[14:0], p_sig0_n_fin};
    wire [79:0] p_z_tiny = {sign, p_exp_t_fin[14:0], p_sig0_t_fin};
    wire [79:0] p_z      = p_is_ovf  ? z_ovf
                         : p_is_tiny ? p_z_tiny
                                     : p_z_norm;
    wire        p_pe     = p_is_ovf  ? 1'b1 : (p_is_tiny ? p_pe_tiny : p_pe_norm);
    wire        p_ue     = p_is_tiny ? p_ue_tiny : 1'b0;
    wire        p_oe     = p_is_ovf;
    wire [5:0]  p_flags  = {p_pe, p_ue, p_oe, 3'b000};

    //====================================================================
    // Select branch.
    //====================================================================
    assign z     = is_pc_narrow ? n_z     : p_z;
    assign flags = is_pc_narrow ? n_flags : p_flags;

endmodule
