//
// vid_trace — video-timing snapshot peripheral on the HPS management bus
// (UIO class 0xF8). Read-only debug, mirrors rtl/fpu_trace.v.
//
// Purpose: on the NOHDMI (scaler-less) build the only way a CRT gets a picture
// is the in-core scandoubler, and guessing at why a mode stays black has cost
// several blind rebuilds. This peripheral MEASURES the actual video timing on
// real silicon and hands it to Main_MiSTer, which logs only *unique* modes to
// /tmp/ao486_vid.csv. It snapshots TWO points in the pipe:
//
//   IN  = the ao486 video core's native timing (HSync/VSync/vga_de @ vga_ce)
//   OUT = the final analog VGA timing after the scandoubler/video_mixer
//         (VGA_HS/VGA_VS/VGA_DE @ CE_PIXEL)
//
// Comparing IN vs OUT answers the question directly: if OUT's line period is
// ~half of IN's (and OUT v_total ~double IN's), the scandoubler doubled the
// mode; if OUT==IN, sd_en never engaged. h_active/v_active give the resolution.
//
// All periods are counted in raw clk_vga (90.000 MHz) cycles, so the HPS turns
// them into kHz/Hz with a single known constant — no clock guessing. Counts
// saturate at 0xFFFF (= "no sync seen") instead of wrapping.
//
// Readout (UIO_DMA_READ 0x62 @ 0xF800; hps_ext auto-increments the low byte):
//   0: in_h_total    1: in_v_total    2: in_v_active   3: in_h_active
//   4: out_h_total   5: out_v_total   6: out_v_active   7: out_h_active
//   8: {15'b0, sd_en}                 9: MAGIC 0xFA87
//  10: in_r_or      11: in_g_or      12: in_b_or
//  13: out_r_or     14: out_g_or     15: out_b_or
//
//   h_total : clk_vga cycles between HSync rising edges  -> line rate  = 90e6/h_total
//   v_total : HSync edges (lines) between VSync edges    -> frame rate = 90e6/(h_total*v_total)
//   v_active: lines that carried active DE               -> vertical resolution
//   h_active: max active (ce&de) pixels in a line        -> horizontal resolution
//

// --- per-channel measurement, all in the clk_vga domain ----------------------
module vid_meas
(
	input             clk,
	input             ce,
	input             hs,
	input             vs,
	input             de,
	input      [7:0]  r,
	input      [7:0]  g,
	input      [7:0]  b,

	output reg [15:0] h_total,
	output reg [15:0] v_total,
	output reg [15:0] v_active,
	output reg [15:0] h_active,
	output reg [7:0]  r_or,
	output reg [7:0]  g_or,
	output reg [7:0]  b_or
);

reg        hs_d, vs_d;
reg [15:0] h_per;      // running clk cycles in current line
reg [15:0] line_act;   // running active pixels in current line
reg [15:0] v_lines;    // running lines in current frame
reg [15:0] frm_vact;   // running active-line count in current frame
reg [15:0] frm_hmax;   // running max active pixels seen this frame
reg [7:0]  frm_r_or;
reg [7:0]  frm_g_or;
reg [7:0]  frm_b_or;

wire hs_rise = hs & ~hs_d;
wire vs_rise = vs & ~vs_d;

always @(posedge clk) begin
	hs_d <= hs;
	vs_d <= vs;

	// horizontal period (every clk cycle, saturating)
	if (hs_rise) begin
		h_total <= h_per;
		h_per   <= 16'd1;
	end
	else if (h_per != 16'hFFFF) h_per <= h_per + 1'b1;

	// per-line active pixel accumulation (ce-qualified DE)
	if (hs_rise) line_act <= 16'd0;
	else if (ce & de) begin
		if (line_act != 16'hFFFF) line_act <= line_act + 1'b1;
		frm_r_or <= frm_r_or | r;
		frm_g_or <= frm_g_or | g;
		frm_b_or <= frm_b_or | b;
	end

	// at end of each line: roll line stats into the frame accumulators
	if (hs_rise) begin
		v_lines <= v_lines + 1'b1;
		if (|line_act)            frm_vact <= frm_vact + 1'b1;
		if (line_act > frm_hmax)  frm_hmax <= line_act;
	end

	// at end of each frame: latch the snapshot and clear accumulators
	if (vs_rise) begin
		v_total  <= v_lines;
		v_active <= frm_vact;
		h_active <= frm_hmax;
		r_or     <= frm_r_or;
		g_or     <= frm_g_or;
		b_or     <= frm_b_or;
		v_lines  <= 16'd0;
		frm_vact <= 16'd0;
		frm_hmax <= 16'd0;
		frm_r_or <= 8'd0;
		frm_g_or <= 8'd0;
		frm_b_or <= 8'd0;
	end
end

endmodule


module vid_trace
(
	input             clk,        // clk_vga (90.000 MHz)

	input             in_ce,
	input             in_hs,
	input             in_vs,
	input             in_de,
	input      [7:0]  in_r,
	input      [7:0]  in_g,
	input      [7:0]  in_b,

	input             out_ce,
	input             out_hs,
	input             out_vs,
	input             out_de,
	input      [7:0]  out_r,
	input      [7:0]  out_g,
	input      [7:0]  out_b,

	input             sd_en,

	input      [3:0]  word_idx,   // mgmt_address[3:0] — selects readout word
	output reg [15:0] readdata
);

wire [15:0] i_ht, i_vt, i_va, i_ha;
wire [15:0] o_ht, o_vt, o_va, o_ha;
wire [7:0] i_ro, i_go, i_bo;
wire [7:0] o_ro, o_go, o_bo;

vid_meas m_in
(
	.clk(clk), .ce(in_ce),
	.hs(in_hs), .vs(in_vs), .de(in_de),
	.r(in_r), .g(in_g), .b(in_b),
	.h_total(i_ht), .v_total(i_vt), .v_active(i_va), .h_active(i_ha),
	.r_or(i_ro), .g_or(i_go), .b_or(i_bo)
);

vid_meas m_out
(
	.clk(clk), .ce(out_ce),
	.hs(out_hs), .vs(out_vs), .de(out_de),
	.r(out_r), .g(out_g), .b(out_b),
	.h_total(o_ht), .v_total(o_vt), .v_active(o_va), .h_active(o_ha),
	.r_or(o_ro), .g_or(o_go), .b_or(o_bo)
);

always @(*) begin
	case (word_idx)
		4'd0: readdata = i_ht;
		4'd1: readdata = i_vt;
		4'd2: readdata = i_va;
		4'd3: readdata = i_ha;
		4'd4: readdata = o_ht;
		4'd5: readdata = o_vt;
		4'd6: readdata = o_va;
		4'd7: readdata = o_ha;
		4'd8: readdata = {15'b0, sd_en};
		4'd9: readdata = 16'hFA87;   // magic: video-trace channel sanity marker
		4'd10: readdata = {8'd0, i_ro};
		4'd11: readdata = {8'd0, i_go};
		4'd12: readdata = {8'd0, i_bo};
		4'd13: readdata = {8'd0, o_ro};
		4'd14: readdata = {8'd0, o_go};
		4'd15: readdata = {8'd0, o_bo};
		default: readdata = 16'h0000;
	endcase
end

endmodule
