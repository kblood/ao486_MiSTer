//
// fpu_trace - x87 activity and fault snapshot peripheral on the HPS
// management bus (UIO class 0xF7).
//
// Words 0..4 are kept compatible with the original counter-only trace:
//   0: total_ops[15:0]     1: total_ops[31:16]
//   2: transc_ops[15:0]    3: transc_ops[31:16]
//   4: MAGIC 0xFA86
//
// Iter-254 proved the residual Quake "Bad surface extents" crash is TIMING-
// DEPENDENT state corruption (3 cold boots: same op-count 924631, different
// LOW-mantissa ST(0) ~6.5).  Iter-255 REFUTED the exception/interrupt-flush-
// mid-FPU-op mechanism (efb_count=0 across boots) while the corruption persists,
// and showed (4-deep ring) that op #924628 was ALREADY empty and #924629/#924630
// hold the varying ~6.5 — so the corrupted dot-product value `val` lives DEEPER
// than the 4-deep ring reaches.
//
// Iter-256 DEEP LOCALIZATION ring: drop the per-entry exponent (the boot-to-boot
// divergence shows in the top-16 mantissa: 0xD262 vs 0xD1FA) and capture a
// 9-DEEP man16-only result ring, frozen at FREEZE_COUNT.  The decoder walks the
// ring oldest->newest and reports the FIRST op (deepest) whose man16 varies
// across boots = where the corruption is born.  Firmware-free: words 0..4 and 15
// unchanged so the existing Main_MiSTer drain works.  The exc_init/exe_fpu_busy
// inputs stay wired (iter-255 plumbing) but are unused this iter.
//   5..13: ring_man[0..8]  (#924631 newest .. #924623 oldest), ST0[63:48]
//  14: {cap_frozen, cap_count[14:0]}   (freeze confirmation + row id)
//  15: MAGIC 0xFA87
//
module fpu_trace
(
	input             clk,
	input             reset,

	input      [1:0]  evt,        // {transc_retire, any_retire}
	input      [31:0] fpu_eip,
	input      [31:0] fpu_info,
	input      [79:0] fpu_st0,    // current ST(0) floatx80

	input             exc_evt,    // hardware CPU exception, not timer IRQ/INT
	input      [31:0] exc_eip,
	input      [31:0] exc_info,   // {src[4:0], flags[2:0], vector[7:0], error[15:0]}

	input             exc_init,      // iter-255 plumbing (unused this iter)
	input             exe_fpu_busy,  // iter-255 plumbing (unused this iter)

	input      [3:0]  word_idx,   // mgmt_address[3:0]
	output reg [15:0] readdata
);

reg [31:0] total_ops;
reg [31:0] transc_ops;

// iter-256: op-count-triggered DEEP man16 result ring (9-deep).
localparam [31:0] FREEZE_COUNT = 32'd924631;
reg        cap_frozen;
reg [31:0] cap_count;
reg        evt0_d1;
reg [15:0] ring_man [0:8];   // ST0[63:48] = J-bit + top mantissa, newest..oldest

always @(posedge clk) begin
	if (reset) begin
		total_ops     <= 32'd0;
		transc_ops    <= 32'd0;
		cap_frozen    <= 1'b0;
		cap_count     <= 32'd0;
		evt0_d1       <= 1'b0;
		ring_man[0]   <= 16'd0; ring_man[1] <= 16'd0; ring_man[2] <= 16'd0;
		ring_man[3]   <= 16'd0; ring_man[4] <= 16'd0; ring_man[5] <= 16'd0;
		ring_man[6]   <= 16'd0; ring_man[7] <= 16'd0; ring_man[8] <= 16'd0;
	end
	else begin
		if (evt[0]) total_ops <= total_ops + 1'b1;
		if (evt[1]) transc_ops <= transc_ops + 1'b1;

		// Delay the retire pulse one cycle so the regfile NBA write of ST(0)
		// has settled before we sample fpu_st0.
		evt0_d1 <= evt[0];

		if (evt0_d1 && !cap_frozen) begin
			ring_man[8] <= ring_man[7]; ring_man[7] <= ring_man[6];
			ring_man[6] <= ring_man[5]; ring_man[5] <= ring_man[4];
			ring_man[4] <= ring_man[3]; ring_man[3] <= ring_man[2];
			ring_man[2] <= ring_man[1]; ring_man[1] <= ring_man[0];
			ring_man[0] <= fpu_st0[63:48];
			cap_count   <= cap_count + 1'b1;
			if ((cap_count + 1'b1) >= FREEZE_COUNT) cap_frozen <= 1'b1;
		end
	end
end

always @(*) begin
	case (word_idx)
		4'd0:  readdata = total_ops[15:0];
		4'd1:  readdata = total_ops[31:16];
		4'd2:  readdata = transc_ops[15:0];
		4'd3:  readdata = transc_ops[31:16];
		4'd4:  readdata = 16'hFA86;
		4'd5:  readdata = ring_man[0];
		4'd6:  readdata = ring_man[1];
		4'd7:  readdata = ring_man[2];
		4'd8:  readdata = ring_man[3];
		4'd9:  readdata = ring_man[4];
		4'd10: readdata = ring_man[5];
		4'd11: readdata = ring_man[6];
		4'd12: readdata = ring_man[7];
		4'd13: readdata = ring_man[8];
		4'd14: readdata = {cap_frozen, cap_count[14:0]};
		4'd15: readdata = 16'hFA87;
		default: readdata = 16'h0000;
	endcase
end

endmodule
