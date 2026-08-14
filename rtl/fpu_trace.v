//
// fpu_trace - x87 activity and fault snapshot peripheral on the HPS
// management bus (UIO class 0xF7).
//
// Words 0..4 are kept compatible with the original counter-only trace:
//   0: total_ops[15:0]     1: total_ops[31:16]
//   2: transc_ops[15:0]    3: transc_ops[31:16]
//   4: MAGIC 0xFA86
//
// iter-274 FIRST-DIVERGENCE FPU-WRITEBACK RING (Codex bjiw9nu0i decisive experiment).
// ----------------------------------------------------------------------------------
// The Quake "Bad surface extents" crash is DETERMINISTIC at total_ops=924631 (transc
// 3331) every cold boot, YET the floatx80 ST0 accumulator at the crash VARIES boot to
// boot (~2%, exponent stable, whole 64-bit mantissa varies; iter-267).  The complete
// elimination ladder is NEGATIVE: logical arithmetic all precisions, exception/IRQ-flush
// (iter-255), operand-delivery (retracted iter-258), arith settle-dwell (iter-259),
// transc settle-dwell (iter-266), b_lat setup margin (iter-256/272), memory-latency
// jitter hazard (iter-271), dot-product setup-violation (iter-272), fast-corner hold
// (iter-273).  ALL internal-FPU-compute explanations are excluded => leading hypothesis
// is an EXTERNAL / CDC memory nondeterminism (DDR3 power-up content, L2 read-during-write
// coherency hole, or clk_sys<->DDR3/HPS CDC) that delivers a boot-varying operand (or an
// FST'd-then-reloaded mins/maxs) into an EARLIER dot-product step, so the error is
// INHERITED in the ST0 accumulator before the final op.
//
// This ring records the last RING_DEPTH=64 retiring FPU writebacks before the crash op.
// Per entry (32 bits): sig_res = 16-bit fold of the 64-bit ST0 RESULT mantissa, and
// sig_mem = 16-bit fold of the delivered float32 mem OPERAND (0x0000 for reg-reg ops).
// Frozen at FREEZE_COUNT, then STREAMED out two entries at a time through the fixed
// firmware CSV columns (last_fpu_eip = w5,w6 ; last_fpu_info = w7,w8) via a FREE-RUNNING
// post-freeze scan_base (cycles 0,2,..,62 every ~4.6 ms) so NO read-edge detection or
// firmware-read-pattern assumption is needed -- every CSV row self-labels its window via
// exc_count, and the offline decoder groups rows by scan_base until all 32 windows seen.
//
// 2-COLD-BOOT DECISION RULE: reconstruct chronological order from wptr_frozen, then diff
// sig_res per entry oldest->newest.  The FIRST entry whose sig_res differs between boots is
// the first corrupted result.  At THAT entry:
//   * sig_mem DIFFERS  => memory/L2/SDRAM/CDC delivered a different operand (MEMORY-side,
//                         the predicted outcome) -> chase the external/CDC path.
//   * sig_mem SAME     => same operand + (prior entry's) same accumulator input yet a
//                         different result => genuine INTERNAL nondeterminism.
//
// Built ENTIRELY here from the already-threaded fpu_st0 (SAFE regfile-read 8:1 mux),
// mem_data and mem_arith (iter-257); zero execute.v / system.v changes (word_idx stays
// [3:0]; mem_data/mem_arith were threaded-but-unused until now).
//
// iter-275 Readout (streamed; ONE 64-bit entry = ring[scan_base] per CSV row):
//   5: value32[15:0]  6: value32[31:16]  (last_fpu_eip  = {value32[31:16], value32[15:0]})
//   7: addr32[15:0]   8: addr32[31:16]   (last_fpu_info = {addr32[31:16],  addr32[15:0]})
//                                          decoder: value32=(w6<<16)|w5, addr32=(w8<<16)|w7
//   9: {wptr_frozen[7:0], scan_base[7:0]}              (exc_count low  half)
//  10: {cap_frozen, cap_count[14:0]}                   (exc_count high half; freeze confirm)
//  11..13: 0 (spare)
//  15: MAGIC 0xFA87   (TRACE_EXT_MAGIC -- REQUIRED: firmware gates w5..w10 on this)
//
module fpu_trace
(
	input             clk,
	input             reset,

	input      [1:0]  evt,        // {transc_retire, any_retire}
	input      [31:0] fpu_eip,
	input      [31:0] fpu_info,
	input      [79:0] fpu_st0,    // current ST(0) floatx80 (regfile-read mux, SAFE tap)

	input             exc_evt,    // hardware CPU exception, not timer IRQ/INT
	input      [31:0] exc_eip,
	input      [31:0] exc_info,

	input             exc_init,      // (unused this iter)
	input             exe_fpu_busy,  // (unused this iter)

	input      [31:0] mem_data,    // iter-257: delivered float32 mem operand
	input             mem_arith,   // iter-257: dot-product mem-op flag

	input      [71:0] arith_snap,  // (unused this iter)

	input      [3:0]  word_idx,   // mgmt_address[3:0]
	output reg [15:0] readdata
);

reg [31:0] total_ops;
reg [31:0] transc_ops;

// iter-254/257/261/267/274: op-count freeze anchor = the deterministic Quake crash op.
localparam [31:0] FREEZE_COUNT = 32'd924631;
localparam integer RING_DEPTH  = 64;   // power of two; scan_base wraps 0..RING_DEPTH-1

reg        cap_frozen;
reg [31:0] cap_count;
reg        evt0_d1;

// iter-275: per-LOAD full-fidelity ring (64 bits each: {addr32[63:32], value32[31:0]}).
reg [63:0] ring [0:RING_DEPTH-1];
reg [6:0]  wptr;          // next-write slot (chronological head)
reg [6:0]  wptr_frozen;   // wptr latched at freeze = oldest valid entry

// Streaming scan pointer (free-running once frozen).  Cycles 0,2,..,RING_DEPTH-2.
// scan_div period ~0.6 s/step (2^25 / 56.25 MHz) so the HPS CSV drain (~1-10 Hz)
// samples each window monotonically with no coupon-collector coverage gaps; the whole
// 32-window ring streams out in ~19 s, captured by a single post-freeze CSV pull.
reg [6:0]  scan_base;
reg [24:0] scan_div;

// iter-274.1: the per-writeback signature {res_fold16, mem_fold16} is now produced in
// execute.v (writeback-strobed, result read from fpu_r[wr_idx], operand from
// exe_fpu_mem_data) and delivered packed on arith_snap[31:0] with a toggle on bit[32].
// evt[0]=fpu_done was the wrong strobe (sampled ST(TOP)=0 -> mostly-zero dead ring).
reg ring_tgl_d;     // last-seen arith_snap toggle, for new-entry edge detection

integer i;

always @(posedge clk) begin
	if (reset) begin
		total_ops   <= 32'd0;
		transc_ops  <= 32'd0;
		cap_frozen  <= 1'b0;
		cap_count   <= 32'd0;
		evt0_d1     <= 1'b0;
		wptr        <= 7'd0;
		wptr_frozen <= 7'd0;
		scan_base   <= 7'd0;
		scan_div    <= 25'd0;
		ring_tgl_d  <= 1'b0;
		for (i = 0; i < RING_DEPTH; i = i + 1) ring[i] <= 64'd0;
	end
	else begin
		if (evt[0]) total_ops  <= total_ops  + 1'b1;
		if (evt[1]) transc_ops <= transc_ops + 1'b1;

		evt0_d1 <= evt[0];

		// iter-275: record each dot-product LOAD into the ring until frozen.  Fed from
		// execute.v on the load toggle (arith_snap[64]); arith_snap[63:0] = {addr32, value32}.
		ring_tgl_d <= arith_snap[64];
		if ((arith_snap[64] != ring_tgl_d) && !cap_frozen) begin
			ring[wptr] <= arith_snap[63:0];
			wptr       <= (wptr == RING_DEPTH-1) ? 7'd0 : wptr + 1'b1;
		end

		if (evt0_d1 && !cap_frozen) begin
			cap_count <= cap_count + 1'b1;
			if ((cap_count + 1'b1) >= FREEZE_COUNT) begin
				cap_frozen  <= 1'b1;
				wptr_frozen <= wptr;   // freeze the oldest-entry pointer
			end
		end

		// Post-freeze: free-run the streaming window so every CSV row exposes a
		// different (self-labelled) pair of ring entries.  ~4.6 ms per step.
		if (cap_frozen) begin
			scan_div <= scan_div + 1'b1;
			if (scan_div == 25'd0)
				scan_base <= (scan_base >= RING_DEPTH-1) ? 7'd0 : scan_base + 7'd1;
		end
	end
end

// iter-275: streamed ring read: ONE 64-bit entry per window (4 words, value+addr).
wire [63:0] ringA = ring[scan_base];

always @(*) begin
	case (word_idx)
		4'd0:  readdata = total_ops[15:0];
		4'd1:  readdata = total_ops[31:16];
		4'd2:  readdata = transc_ops[15:0];
		4'd3:  readdata = transc_ops[31:16];
		4'd4:  readdata = 16'hFA86;
		4'd5:  readdata = ringA[15:0];                  // value32 low
		4'd6:  readdata = ringA[31:16];                 // value32 high
		4'd7:  readdata = ringA[47:32];                 // addr32 low
		4'd8:  readdata = ringA[63:48];                 // addr32 high
		4'd9:  readdata = {1'b0, wptr_frozen[6:0], 1'b0, scan_base[6:0]}; // self-label: [14:8]=wptr [6:0]=scan_base
		4'd10: readdata = {cap_frozen, cap_count[14:0]};
		4'd11: readdata = 16'h0000;
		4'd12: readdata = 16'h0000;
		4'd13: readdata = 16'h0000;
		4'd15: readdata = 16'hFA87;   // TRACE_EXT_MAGIC: REQUIRED for firmware ext-mode (gates w5..w10)
		default: readdata = 16'h0000;
	endcase
end

endmodule
