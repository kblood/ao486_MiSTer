// fpu_regfile.v
//
// x87 register file: 8 entries of 80-bit double-extended precision,
// addressed as a stack via the 3-bit TOP pointer in the status word.
//
// Layout per entry (Intel SDM Vol 1 §8.1.2):
//   [79:64] sign + 15-bit biased exponent (16 bits total: [79]=sign, [78:64]=exp)
//   [63]    explicit integer bit (J-bit). UNlike single/double, x87 keeps the
//           leading 1 explicit; this matters for unnormals and pseudo-denormals.
//   [62:0]  fraction
//
// Tag word: one 2-bit tag per register, encoding {Valid=00, Zero=01,
// Special=10, Empty=11}. The CPU exposes the tag word as part of FSAVE/FXSAVE.
//
// TOP pointer: bits [13:11] of the status word point to ST(0). Stack pushes
// decrement TOP; pops increment TOP.
//
// This module is intentionally a *stub* for PR-1 (F-1 in the plan):
//   - storage only; no arithmetic
//   - synchronous read/write
//   - addressed by physical register index (0..7), NOT ST(i) — the consumer
//     is responsible for adding TOP and masking to 3 bits
//
// Future ops (FLD/FST/FXCH/...) will sit in fpu_core.v and use this regfile.

`timescale 1ns / 1ps

module fpu_regfile (
    input             clk,
    input             reset,

    // physical port (raw R0..R7 indices, NOT ST(i))
    input      [2:0]  rd_idx,
    output reg [79:0] rd_data,
    output reg [1:0]  rd_tag,

    input      [2:0]  wr_idx,
    input      [79:0] wr_data,
    input      [1:0]  wr_tag,
    input             wr_en,

    // initialise on FNINIT — drives all tags to Empty (2'b11)
    input             init,

    // PR-2c.ENV (iter 212): parallel tag-word load for FLDENV / FRSTOR.  When
    // tag_word_we pulses, all 8 tags are loaded from tag_word_in (2 bits/reg,
    // physical order tag[i] = tag_word_in[2i+1:2i]) in one cycle — the inverse
    // of the tag_word readback used by FNSTENV.  Data slots are untouched.
    input             tag_word_we,
    input      [15:0] tag_word_in,

    // PR-2c.ENV (iter 215): parallel DATA load for FRSTOR.  When data_load_we
    // pulses, all 8 physical data slots are loaded from data_load_in (80 b/reg,
    // data[i] = data_load_in[80*i +: 80]) in one cycle.  Independent of (and may
    // fire same-cycle as) tag_word_we — FRSTOR loads tags from the env TW and
    // data from the ST area together.  Caller supplies data already in PHYSICAL
    // order (image ST(i) rotated to phys (TOP+i)&7).
    input             data_load_we,
    input      [639:0] data_load_in,

    // observability for FNSAVE / debug
    output     [79:0] r0, r1, r2, r3, r4, r5, r6, r7,
    output     [15:0] tag_word
);

    reg [79:0] data [0:7];
    reg [1:0]  tag  [0:7];

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            // Cold reset: regs zero, tags = Zero (2'b01) — Bochs i387_t::reset().
            for (i = 0; i < 8; i = i + 1) begin
                data[i] <= 80'd0;
                tag[i]  <= 2'b01;
            end
        end else if (init) begin
            // FNINIT: tags = Empty (2'b11), data unchanged per Bochs i387_t::init().
            for (i = 0; i < 8; i = i + 1) begin
                tag[i]  <= 2'b11;
            end
        end else begin
            // PR-2c.ENV (iter 215): tag and data loads are INDEPENDENT so FRSTOR
            // can load tags (from the env TW) and data (from the ST area) the same
            // cycle.  Normal wr_en still writes both data[wr_idx] and tag[wr_idx].
            // --- tags ---
            if (tag_word_we) begin
                // FLDENV / FRSTOR parallel tag-word restore.
                for (i = 0; i < 8; i = i + 1) begin
                    tag[i] <= tag_word_in[2*i +: 2];
                end
            end else if (wr_en) begin
                tag[wr_idx] <= wr_tag;
            end
            // --- data ---
            if (data_load_we) begin
                // FRSTOR parallel ST-data restore (physical order).
                for (i = 0; i < 8; i = i + 1) begin
                    data[i] <= data_load_in[80*i +: 80];
                end
            end else if (wr_en) begin
                data[wr_idx] <= wr_data;
            end
        end
    end

    always @(posedge clk) begin
        rd_data <= data[rd_idx];
        rd_tag  <= tag[rd_idx];
    end

    assign r0 = data[0];
    assign r1 = data[1];
    assign r2 = data[2];
    assign r3 = data[3];
    assign r4 = data[4];
    assign r5 = data[5];
    assign r6 = data[6];
    assign r7 = data[7];

    assign tag_word = { tag[7], tag[6], tag[5], tag[4],
                        tag[3], tag[2], tag[1], tag[0] };

endmodule
