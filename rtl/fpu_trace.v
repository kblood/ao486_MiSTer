//
// fpu_trace - x87 activity and fault snapshot peripheral on the HPS
// management bus (UIO class 0xF7).
//
// Words 0..4 are kept compatible with the original counter-only trace:
//   0: total_ops[15:0]     1: total_ops[31:16]
//   2: transc_ops[15:0]    3: transc_ops[31:16]
//   4: MAGIC 0xFA86
//
// Iter-204 adds snapshot words. Iter-205 keeps this layout but changes the
// FPU EIP/info snapshot to dispatch-time data and packs last_exc_info[31:24]
// as {exc_trace_src[4:0], exc_push_error, exc_soft_int, exc_soft_int_ib}.
//
// Iter-254 repurposes words 5..14 as a 4-deep ST(0) operand-capture ring that
// FREEZES when a local capture count reaches FREEZE_COUNT (924631, the Quake
// "Bad surface extents" crash op).  Words 0..4 and 15 are UNCHANGED so the
// existing Main_MiSTer firmware drain works without modification.
//   5: ring_exp[0]  6: ring_man[0]   (most recent op, #924631)
//   7: ring_exp[1]  8: ring_man[1]
//   9: ring_exp[2] 10: ring_man[2]
//  11: ring_exp[3] 12: ring_man[3]   (oldest, #924628)
//  13: {cap_frozen, cap_count[14:0]}
//  14: ring0_eip  (low16 EIP of #924631, expect 0x719D)
//  15: MAGIC 0xFA87
//
module fpu_trace
(
	input             clk,
	input             reset,

	input      [1:0]  evt,        // {transc_retire, any_retire}
	input      [31:0] fpu_eip,
	input      [31:0] fpu_info,
	input      [79:0] fpu_st0,    // iter-254: current ST(0) floatx80

	input             exc_evt,    // hardware CPU exception, not timer IRQ/INT
	input      [31:0] exc_eip,
	input      [31:0] exc_info,   // {src[4:0], flags[2:0], vector[7:0], error[15:0]}

	input      [3:0]  word_idx,   // mgmt_address[3:0]
	output reg [15:0] readdata
);

reg [31:0] total_ops;
reg [31:0] transc_ops;
reg [31:0] exc_count;

// iter-254: op-count-triggered 4-deep ST(0) capture ring.
localparam [31:0] FREEZE_COUNT = 32'd924631;
reg        cap_frozen;
reg [31:0] cap_count;
reg        evt0_d1;
reg [31:0] eip_d1;
reg [15:0] ring_exp [0:3];   // ST0[79:64] = {sign, biased_exp[14:0]}
reg [15:0] ring_man [0:3];   // ST0[63:48] = J-bit + top mantissa
reg [15:0] ring0_eip;        // low16 EIP of the most-recent captured op

always @(posedge clk) begin
	if (reset) begin
		total_ops     <= 32'd0;
		transc_ops    <= 32'd0;
		exc_count     <= 32'd0;
		cap_frozen    <= 1'b0;
		cap_count     <= 32'd0;
		evt0_d1       <= 1'b0;
		eip_d1        <= 32'd0;
		ring_exp[0]   <= 16'd0; ring_man[0] <= 16'd0;
		ring_exp[1]   <= 16'd0; ring_man[1] <= 16'd0;
		ring_exp[2]   <= 16'd0; ring_man[2] <= 16'd0;
		ring_exp[3]   <= 16'd0; ring_man[3] <= 16'd0;
		ring0_eip     <= 16'd0;
	end
	else begin
		if (evt[0]) total_ops <= total_ops + 1'b1;
		if (evt[1]) transc_ops <= transc_ops + 1'b1;
		if (exc_evt) exc_count <= exc_count + 1'b1;

		// Delay the retire pulse one cycle so the regfile NBA write of ST(0)
		// has settled before we sample fpu_st0.  Latch the EIP at retire.
		evt0_d1 <= evt[0];
		if (evt[0]) eip_d1 <= fpu_eip;

		if (evt0_d1 && !cap_frozen) begin
			ring_exp[3] <= ring_exp[2]; ring_man[3] <= ring_man[2];
			ring_exp[2] <= ring_exp[1]; ring_man[2] <= ring_man[1];
			ring_exp[1] <= ring_exp[0]; ring_man[1] <= ring_man[0];
			ring_exp[0] <= fpu_st0[79:64]; ring_man[0] <= fpu_st0[63:48];
			ring0_eip   <= eip_d1[15:0];
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
		4'd5:  readdata = ring_exp[0];
		4'd6:  readdata = ring_man[0];
		4'd7:  readdata = ring_exp[1];
		4'd8:  readdata = ring_man[1];
		4'd9:  readdata = ring_exp[2];
		4'd10: readdata = ring_man[2];
		4'd11: readdata = ring_exp[3];
		4'd12: readdata = ring_man[3];
		4'd13: readdata = {cap_frozen, cap_count[14:0]};
		4'd14: readdata = ring0_eip;
		4'd15: readdata = 16'hFA87;
		default: readdata = 16'h0000;
	endcase
end

endmodule
