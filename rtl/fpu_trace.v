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
// DEPENDENT state corruption (same op-count 924631, different ST(0) each boot).
// Iter-255 refuted the exception/interrupt-flush-mid-FPU-op mechanism, iter-256
// showed the divergence pervades the dot-product window (born deeper than a
// 9-op ST(0) ring reaches) and refuted the FPU operand-latch timing-margin
// lead.  The leading survivor is a boot-phase MEMORY/L2 operand-DELIVERY race
// for the float32 [mem] dot-product operands.
//
// Iter-257 OPERAND-DELIVERY capture: ring the float32 mem operand DELIVERED to
// the FPU (exe_fpu_mem_data[31:0], the e_load snapshot of read_data wired to
// execute_fpu.exe_mem_data), gated to the dot-product mem ops only via
// mem_arith = (exe_cmd==CMD_fpu_arith_mem || exe_cmd==CMD_fpu_load_mem) so
// fldcw/control loads (CMD_fpu) are excluded.  The ring freezes at the same
// op-count anchor (924631).  Firmware-free: words 0..4 and 15 unchanged.  The
// iter-255 exc_init/exe_fpu_busy inputs stay wired but unused.
//   5..12: mring[0..3] float32 (lo16, hi16 pairs), newest->oldest mem op
//  13: {cap_frozen, cap_count[14:0]}        (op-count freeze confirm)
//  14: mem_cap_count[15:0]                  (mem ops ringed before freeze, sat)
//  15: MAGIC 0xFA87
//
// DECISIVE: if the SAME-indexed delivered operand VARIES boot-to-boot ->
// memory/L2 delivery race; if STABLE while ST(0) results vary -> compute race.
//
module fpu_trace
(
	input             clk,
	input             reset,

	input      [1:0]  evt,        // {transc_retire, any_retire}
	input      [31:0] fpu_eip,
	input      [31:0] fpu_info,
	input      [79:0] fpu_st0,    // current ST(0) floatx80 (unused this iter)

	input             exc_evt,    // hardware CPU exception, not timer IRQ/INT
	input      [31:0] exc_eip,
	input      [31:0] exc_info,

	input             exc_init,      // iter-255 plumbing (unused this iter)
	input             exe_fpu_busy,  // iter-255 plumbing (unused this iter)

	input      [31:0] mem_data,    // iter-257: float32 operand delivered to FPU
	input             mem_arith,   // iter-257: 1 = dot-product mem op (cmd 123/124)

	input      [3:0]  word_idx,   // mgmt_address[3:0]
	output reg [15:0] readdata
);

reg [31:0] total_ops;
reg [31:0] transc_ops;

// iter-254/257: op-count freeze anchor.
localparam [31:0] FREEZE_COUNT = 32'd924631;
reg        cap_frozen;
reg [31:0] cap_count;
reg        evt0_d1;

// iter-257: float32 mem-operand delivery ring (4-deep), captured at retire+1
// (aligned with cap_count) for ops flagged mem_arith.
reg        mem_arith_d1;
reg [31:0] mem_data_d1;
reg [31:0] mring [0:3];
reg [15:0] mem_cap_count;

always @(posedge clk) begin
	if (reset) begin
		total_ops     <= 32'd0;
		transc_ops    <= 32'd0;
		cap_frozen    <= 1'b0;
		cap_count     <= 32'd0;
		evt0_d1       <= 1'b0;
		mem_arith_d1  <= 1'b0;
		mem_data_d1   <= 32'd0;
		mring[0]      <= 32'd0; mring[1] <= 32'd0;
		mring[2]      <= 32'd0; mring[3] <= 32'd0;
		mem_cap_count <= 16'd0;
	end
	else begin
		if (evt[0]) total_ops <= total_ops + 1'b1;
		if (evt[1]) transc_ops <= transc_ops + 1'b1;

		// Snapshot the retiring op's mem-arith flag + delivered operand at the
		// retire pulse; consume one cycle later so the freeze count aligns.
		evt0_d1      <= evt[0];
		mem_arith_d1 <= evt[0] && mem_arith;
		if (evt[0]) mem_data_d1 <= mem_data;

		if (evt0_d1 && !cap_frozen) begin
			cap_count <= cap_count + 1'b1;
			if ((cap_count + 1'b1) >= FREEZE_COUNT) cap_frozen <= 1'b1;
			if (mem_arith_d1) begin
				mring[3] <= mring[2]; mring[2] <= mring[1];
				mring[1] <= mring[0]; mring[0] <= mem_data_d1;
				if (mem_cap_count != 16'hFFFF) mem_cap_count <= mem_cap_count + 1'b1;
			end
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
		4'd5:  readdata = mring[0][15:0];
		4'd6:  readdata = mring[0][31:16];
		4'd7:  readdata = mring[1][15:0];
		4'd8:  readdata = mring[1][31:16];
		4'd9:  readdata = mring[2][15:0];
		4'd10: readdata = mring[2][31:16];
		4'd11: readdata = mring[3][15:0];
		4'd12: readdata = mring[3][31:16];
		4'd13: readdata = {cap_frozen, cap_count[14:0]};
		4'd14: readdata = mem_cap_count;
		4'd15: readdata = 16'hFA87;
		default: readdata = 16'h0000;
	endcase
end

endmodule
