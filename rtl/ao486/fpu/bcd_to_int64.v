// PR-2b.5z (iter 151): packed-BCD -> unsigned 64-bit magnitude for FBLD (DF /4).
// Combinational.  Mirrors the Bochs FBLD_PACKED_BCD digit loop:
//   val = Sum_{n=0..17} digit[n] * 10^n
// The 80-bit packed-BCD memory operand is 18 magnitude digits (nibbles) plus a
// sign byte.  This module consumes ONLY the 72-bit magnitude field (18 nibbles,
// little-endian: nibble n = the 10^n digit); the sign bit is applied by the
// caller before int_to_floatx80 (FBLD = int64_to_floatx80(signed val), exact —
// no IE/DE/ZE/OE/UE/PE since 18 decimal digits < 10^18 < 2^60 always fit the
// 64-bit significand).  Invalid (>9) nibbles are NOT validated — x87 hardware
// produces an undefined-but-deterministic result for non-BCD input; this matches
// by simply weighting each nibble as-is, same as the Bochs reference loop.
//
// bcd[71:0] : 18 packed nibbles; bcd[4n +: 4] = the 10^n decimal digit.
// val[63:0] : the unsigned binary magnitude (< 10^18, so the top ~4 bits are 0).

module bcd_to_int64 (
    input  wire [71:0] bcd,
    output wire [63:0] val
);

    reg [63:0] acc;
    reg [63:0] scale;
    integer    n;
    always @(*) begin
        acc   = 64'd0;
        scale = 64'd1;
        for (n = 0; n < 18; n = n + 1) begin
            acc   = acc + (bcd[4*n +: 4] * scale);
            scale = scale * 64'd10;
        end
    end

    assign val = acc;

endmodule
