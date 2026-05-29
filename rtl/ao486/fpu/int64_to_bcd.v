// PR-2b.5z (iter 151): unsigned magnitude -> 18-digit packed BCD for FBSTP (DF /6).
// Combinational double-dabble (shift + conditional add-3 — no dividers, so it
// synthesizes cleanly, matching the iter-142..149 synth discipline).  Mirrors
// the Bochs FBSTP_PACKED_BCD digit loop (repeated % 10 / 10) but produced by the
// equivalent shift-add-3 binary->BCD algorithm.
//
// The caller (FBSTP) first does floatx80_to_int (width=m64, honoring RC), takes
// the magnitude |z|, and range-checks it against 10^18-1; only an in-range
// magnitude reaches here, so 18 BCD digits (60 bits) always suffice.
//
// val[59:0]  : unsigned binary magnitude, guaranteed < 10^18 by the caller.
// bcd[71:0]  : 18 packed nibbles; bcd[4n +: 4] = the 10^n decimal digit.
//              The caller writes bcd[63:0] as the low qword and bcd[71:64] as the
//              two extra digits in the high word's low byte (+ sign in bit 15).

module int64_to_bcd (
    input  wire [59:0] val,
    output wire [71:0] bcd
);

    reg [71:0] d;
    integer    i, j;
    always @(*) begin
        d = 72'd0;
        for (i = 0; i < 60; i = i + 1) begin
            // add-3 to any nibble >= 5 BEFORE the shift that would carry it >=10
            for (j = 0; j < 18; j = j + 1)
                if (d[4*j +: 4] >= 4'd5)
                    d[4*j +: 4] = d[4*j +: 4] + 4'd3;
            // shift left one, bringing in the next binary bit (MSB-first)
            d = {d[70:0], val[59 - i]};
        end
    end

    assign bcd = d;

endmodule
