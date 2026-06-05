//
// fpu_trace — x87 FPU activity counters, read-only debug peripheral on the
// HPS management bus (UIO class 0xF7).
//
// Purpose: let Main_MiSTer poll, over the FPGA<->HPS bridge and completely
// independent of the running guest (DOS/the game), how many x87 FPU ops the
// CPU has retired since core reset, and how many of those were transcendental
// ops (F2XM1/FYL2X/FYL2XP1/FPTAN/FPATAN/FSIN/FCOS/FSINCOS) specifically. The
// HPS drains it ~60 Hz from its poll loop and appends a /tmp CSV, so you get a
// live timeline showing whether (and when) software actually dispatches the
// FPU — answering "is FX Fighter calling the transcendentals?" on real silicon
// without any cooperation from DOS.
//
// This mirrors the CD32 akiko_bus_trace.v drain idea but is a register-snapshot
// peripheral (free-running counters) rather than an event ring: counters never
// overflow-lose data, so a slow poll just samples a clean monotonic value.
//
// Transport: the HPS issues UIO_DMA_READ (0x62) with address 0xF7xx; hps_ext
// auto-increments the low address byte each 16-bit word read, so word_idx
// (= mgmt_address[2:0]) selects the readout word:
//   0: total_ops[15:0]    1: total_ops[31:16]
//   2: transc_ops[15:0]   3: transc_ops[31:16]
//   4: MAGIC 0xFA86       (channel sanity/version — drain confirms it's live)
//   else: 0
//
// evt is sampled in the CPU clock domain at the FPU retire pulse:
//   evt[0] = fpu_done                  (any x87 op retired, 1-cycle pulse)
//   evt[1] = fpu_done & is_transc_lat  (a transcendental op retired)
//
module fpu_trace
(
	input             clk,
	input             reset,

	input      [1:0]  evt,        // {transc_retire, any_retire} — 1-cycle pulses
	input      [2:0]  word_idx,   // mgmt_address[2:0] — selects readout word
	output reg [15:0] readdata
);

reg [31:0] total_ops;
reg [31:0] transc_ops;

always @(posedge clk) begin
	if (reset) begin
		total_ops  <= 32'd0;
		transc_ops <= 32'd0;
	end
	else begin
		if (evt[0]) total_ops  <= total_ops  + 1'b1;
		if (evt[1]) transc_ops <= transc_ops + 1'b1;
	end
end

always @(*) begin
	case (word_idx)
		3'd0: readdata = total_ops[15:0];
		3'd1: readdata = total_ops[31:16];
		3'd2: readdata = transc_ops[15:0];
		3'd3: readdata = transc_ops[31:16];
		3'd4: readdata = 16'hFA86;   // magic: x87/486 channel sanity marker
		default: readdata = 16'h0000;
	endcase
end

endmodule
