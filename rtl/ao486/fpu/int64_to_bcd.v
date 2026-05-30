// PR-2c.9 (iter 162): unsigned magnitude -> 18-digit packed BCD for FBSTP (DF /6).
// SEQUENTIAL double-dabble (shift + conditional add-3 — no dividers, synth-clean).
//
// The iter-151 version unrolled all 60 binary->BCD iterations COMBINATIONALLY
// (~1800 ALUTs in synthesis — by far the largest single FPU block, and for one
// of the rarest x86 ops: FBSTP store-packed-BCD).  Reworked here into a clocked
// one-iteration-per-cycle FSM (~150 ALUTs) to reclaim ~1000 ALMs for the fixed
// DE10-nano fit.  The ~60-cycle latency is irrelevant for FBSTP.  Same
// start/busy/done handshake template as seq_divider_128_64 / seq_isqrt_128.
//
// The caller (FBSTP) first does floatx80_to_int (width=m64, honoring RC), takes
// the magnitude |z|, and range-checks it against 10^18-1; only an in-range
// magnitude reaches here, so 18 BCD digits (60 bits) always suffice.
//
// val[59:0]  : unsigned binary magnitude, guaranteed < 10^18 by the caller.
// bcd[71:0]  : 18 packed nibbles; bcd[4n +: 4] = the 10^n decimal digit.
//              Valid when done=1; held until the next start.
//
// Handshake: pulse `start` (with val stable) -> busy goes high for 60 cycles
// -> `done` pulses 1 cycle as bcd latches the result; busy returns low.

module int64_to_bcd (
    input  wire        clk,
    input  wire        rst,        // synchronous clear
    input  wire        start,      // 1-cycle pulse: latch val + begin
    input  wire [59:0] val,        // unsigned magnitude < 10^18
    output reg  [71:0] bcd,        // result, valid at done, held until next start
    output reg         done,       // 1-cycle pulse when bcd is valid
    output reg         busy
);

    reg [71:0] d;
    reg [59:0] val_reg;
    reg [5:0]  cnt;     // iteration index 0..59

    // One double-dabble iteration on the current accumulator `d`:
    // add-3 to any nibble >= 5 (so the upcoming shift carries it >= 10 cleanly).
    reg [71:0] d_a3;
    integer    j;
    always @(*) begin
        d_a3 = d;
        for (j = 0; j < 18; j = j + 1)
            if (d_a3[4*j +: 4] >= 4'd5)
                d_a3[4*j +: 4] = d_a3[4*j +: 4] + 4'd3;
    end
    // then shift left one, bringing in the next binary bit (MSB-first): val[59-cnt].
    wire [71:0] next_d = {d_a3[70:0], val_reg[59 - cnt]};

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            cnt  <= 6'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                d       <= 72'd0;
                val_reg <= val;
                cnt     <= 6'd0;
                busy    <= 1'b1;
            end
            else if (busy) begin
                d   <= next_d;
                cnt <= cnt + 6'd1;
                if (cnt == 6'd59) begin
                    bcd  <= next_d;     // 60th (i=59) iteration completes the BCD
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            end
        end
    end

endmodule
