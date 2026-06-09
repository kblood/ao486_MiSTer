// fpu_csr.v
//
// x87 control/status/tag word block. Intel SDM Vol 1 §8.1.3, §8.1.5, §8.1.7.
//
// Control word (16 bits, FLDCW / FNSTCW):
//   [5:0]   exception masks: IM,DM,ZM,OM,UM,PM (1 = masked)
//   [7:6]   reserved (= 2'b01 on init)
//   [9:8]   PC   (precision control: 00=24-bit, 10=53-bit, 11=64-bit)
//   [11:10] RC   (rounding control: 00=NE, 01=−∞, 10=+∞, 11=Trunc)
//   [12]    IC   (infinity control, 287-era; ignored on 387+)
//   [15:13] reserved
//   FNINIT default: 0x037F  (all exceptions masked, RC=NE, PC=64-bit)
//
// Status word (16 bits, FNSTSW / FNSTSW AX):
//   [5:0]   exception flags IE,DE,ZE,OE,UE,PE
//   [6]     SF (stack fault)
//   [7]     ES (error summary: any unmasked active exception)
//   [10:8]  C0,C1,C2
//   [13:11] TOP (top-of-stack pointer)
//   [14]    C3
//   [15]    B  (busy; on 387+ equivalent to ES)
//   FNINIT default: 0x0000
//
// Tag word (16 bits): 8 × 2-bit tag (see fpu_regfile.v).
//   FNINIT default: 0xFFFF  (all empty)
//
// This module owns the CW/SW; the tag word lives in fpu_regfile and is mirrored
// out via tag_word_in for FNSAVE assembly. Stack pointer arithmetic is exposed
// so fpu_core.v can issue push (TOP-1)/pop (TOP+1) on FLD/FSTP.

`timescale 1ns / 1ps

module fpu_csr (
    input             clk,
    input             reset,

    input             init,                  // FNINIT pulse

    // Control word access
    input             cw_we,
    input      [15:0] cw_din,
    output reg [15:0] cw,

    // Status word access
    input             sw_we,
    input      [15:0] sw_din,
    output     [15:0] sw,

    // Exception flag set / clear lanes from fpu_core
    input      [5:0]  exc_flags_set,
    input             exc_flags_clear_all,   // FNCLEX

    // Condition codes set lane
    input             cc_we,
    input      [3:0]  cc_din,                // {C3, C2, C1, C0}

    // TOP pointer
    output     [2:0]  top,
    input      [2:0]  top_din,
    input             top_we,

    // Stack fault set
    input             sf_set,

    // RC / PC for arithmetic unit
    output     [1:0]  rc,
    output     [1:0]  pc,
    output     [5:0]  exc_mask
);

    reg [5:0] exc_flags;
    reg       sf;
    reg [2:0] c_lo;     // {C2, C1, C0}
    reg       c3;
    reg [2:0] top_r;

    wire es = |(exc_flags & ~cw[5:0]);

    // SDM bit layout (MSB → LSB):
    //   [15] B (mirrors ES on 387+)
    //   [14] C3
    //   [13:11] TOP
    //   [10] C2
    //   [9]  C1
    //   [8]  C0
    //   [7]  ES (summary)
    //   [6]  SF (stack fault)
    //   [5:0] exception flags IE..PE
    // Widths: 1+1+3+1+1+1+1+1+6 = 16. (Pre-iter-28 had an extra `1'b0`
    // between C2 and C1 that made the RHS 17 bits — silently truncated by
    // Verilog and put C0/C1/C2 + TOP + C3 at the wrong positions. Fixed
    // by PR-2b.2d; see memory entry `fpu_csr_sw_concat_bug.md`.)
    assign sw = { es,
                  c3,
                  top_r,
                  c_lo[2], c_lo[1], c_lo[0],
                  es,
                  sf,
                  exc_flags };

    assign top      = top_r;
    assign rc       = cw[11:10];
    assign pc       = cw[9:8];
    assign exc_mask = cw[5:0];

    always @(posedge clk) begin
        if (reset) begin
            // Cold reset (Intel SDM Vol 1 §8.1.7, Bochs i387_t::reset()).
            cw        <= 16'h0040;
            exc_flags <= 6'b0;
            sf        <= 1'b0;
            c_lo      <= 3'b0;
            c3        <= 1'b0;
            top_r     <= 3'b0;
        end else if (init) begin
            // FNINIT (Intel SDM Vol 2A FNINIT, Bochs i387_t::init()).
            cw        <= 16'h037F;
            exc_flags <= 6'b0;
            sf        <= 1'b0;
            c_lo      <= 3'b0;
            c3        <= 1'b0;
            top_r     <= 3'b0;
        end else begin
            if (cw_we) cw <= cw_din;

            if (sw_we) begin
                // Software write to SW is rare; honour bits that can be
                // written (exception flags, CC, TOP, SF). ES/B are derived
                // and not stored.
                exc_flags <= sw_din[5:0];
                sf        <= sw_din[6];
                c_lo      <= { sw_din[10], sw_din[9], sw_din[8] };
                c3        <= sw_din[14];
                top_r     <= sw_din[13:11];
            end

            if (exc_flags_clear_all) begin
                exc_flags <= 6'b0;
                sf        <= 1'b0;
            end else if (~sw_we) begin
                // When sw_we is asserted (FLDENV / FRSTOR), the SW-write block
                // above already loaded exc_flags/sf from sw_din — don't let the
                // OR-accumulate clobber it.  sw_we and exc_flags_set never
                // co-occur (FLDENV doesn't run the execute_fpu retire), so this
                // is a no-op for every pre-PR-2c.ENV op.
                exc_flags <= exc_flags | exc_flags_set;
            end

            if (cc_we) begin
                c_lo <= { cc_din[2], cc_din[1], cc_din[0] };
                c3   <= cc_din[3];
            end

            if (sf_set) sf <= 1'b1;

            if (top_we) top_r <= top_din;
        end
    end

endmodule
