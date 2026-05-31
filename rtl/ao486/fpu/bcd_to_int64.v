// PR-2b.5z (iter 151): packed-BCD -> unsigned 64-bit magnitude for FBLD (DF /4).
// Iter-168 (Slice 1): sequentialized into a clocked Horner-multiply (~80 ALUTs,
// 18-cycle latency) to reclaim ~310 ALMs.  Originally a combinational unroll of
// `Sum_{n=0..17} digit[n] * 10^n` (~394 ALUTs) -- 18 4-bit x 64-bit multiplies
// stacked behind 18 64-bit adds.  Horner form `((d17*10 + d16)*10 + ...)*10 + d0`
// replaces each multiply with a single 64-bit (val<<3)+(val<<1) per cycle and
// the iteration is per-clock instead of unrolled.  Same start/busy/done handshake
// template as int64_to_bcd / seq_divider_128_64 / seq_isqrt_128.
//
// The 80-bit packed-BCD memory operand is 18 magnitude digits (nibbles) plus a
// sign byte.  This module consumes ONLY the 72-bit magnitude field (18 nibbles,
// little-endian: nibble n = the 10^n digit); the sign bit is applied by the
// caller before int_to_floatx80 (FBLD = int64_to_floatx80(signed val), exact --
// no IE/DE/ZE/OE/UE/PE since 18 decimal digits < 10^18 < 2^60 always fit the
// 64-bit significand).  Invalid (>9) nibbles are NOT validated -- x87 hardware
// produces an undefined-but-deterministic result for non-BCD input; this matches
// by simply weighting each nibble as-is, same as the Bochs reference loop.
//
// bcd[71:0] : 18 packed nibbles; bcd[4n +: 4] = the 10^n decimal digit.
// val[63:0] : the unsigned binary magnitude (< 10^18, top ~4 bits 0).  Valid
//             at done; held until the next start.
//
// Handshake: pulse `start` (with bcd stable) -> busy goes high for 18 cycles
// -> `done` pulses 1 cycle as val latches the result; busy returns low.

module bcd_to_int64 (
    input  wire        clk,
    input  wire        rst,        // synchronous clear
    input  wire        start,      // 1-cycle pulse: latch bcd + begin
    input  wire [71:0] bcd,        // 18 packed nibbles (LSB nibble = 10^0 digit)
    output reg  [63:0] val,        // result, valid at done, held until next start
    output reg         done,       // 1-cycle pulse when val is valid
    output reg         busy
);

    reg [71:0] bcd_reg;
    reg [4:0]  cnt;                // iteration index 0..17

    // Horner step: process the (17 - cnt)'th nibble (MSB-first), so 18
    // iterations accumulate val = sum_{n} d_n * 10^n.  val*10 expands to
    // (val<<3) + (val<<1) -- one 64-bit add per cycle, no multiplier.
    wire [3:0]  digit    = bcd_reg[4*(17 - cnt) +: 4];
    wire [63:0] next_val = (val << 3) + (val << 1) + {60'd0, digit};

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            cnt  <= 5'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                bcd_reg <= bcd;
                val     <= 64'd0;
                cnt     <= 5'd0;
                busy    <= 1'b1;
            end
            else if (busy) begin
                val <= next_val;
                cnt <= cnt + 5'd1;
                if (cnt == 5'd17) begin
                    done <= 1'b1;          // val now holds the final Horner accumulator
                    busy <= 1'b0;
                end
            end
        end
    end

endmodule
