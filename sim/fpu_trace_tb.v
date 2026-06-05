// Unit TB for rtl/fpu_trace.v — proves the counters increment on evt pulses
// and the word-indexed readout returns the right bytes (Verilator --binary).
`timescale 1ns/1ps
module fpu_trace_tb;
	reg         clk = 0;
	reg         reset = 1;
	reg  [1:0]  evt = 2'b00;
	reg  [2:0]  word_idx = 3'd0;
	wire [15:0] readdata;

	integer errors = 0;

	fpu_trace dut(
		.clk(clk), .reset(reset), .evt(evt),
		.word_idx(word_idx), .readdata(readdata)
	);

	always #5 clk = ~clk;

	task pulse(input [1:0] e);
		begin
			@(negedge clk); evt = e;
			@(negedge clk); evt = 2'b00;
		end
	endtask

	reg [15:0] rdval;
	task rd(input [2:0] idx);
		begin
			word_idx = idx;
			#1 rdval = readdata;   // combinational settle
		end
	endtask

	task chk(input [127:0] name, input [31:0] got, input [31:0] exp);
		begin
			if (got !== exp) begin
				$display("FAIL %0s: got %0d (0x%08x) exp %0d (0x%08x)", name, got, got, exp, exp);
				errors = errors + 1;
			end else begin
				$display("ok   %0s = %0d (0x%08x)", name, got, got);
			end
		end
	endtask

	reg [31:0] total, transc;

	initial begin
		@(negedge clk); reset = 1;
		@(negedge clk); reset = 0;

		// 5 plain FPU retires, 3 of which are transcendental.
		pulse(2'b01); // any only
		pulse(2'b01);
		pulse(2'b11); // any + transc
		pulse(2'b11);
		pulse(2'b01);
		pulse(2'b11);
		// total evt[0] pulses = 6 ; evt[1] pulses = 3

		@(negedge clk);
		rd(3'd0); total[15:0]  = rdval;
		rd(3'd1); total[31:16] = rdval;
		rd(3'd2); transc[15:0]  = rdval;
		rd(3'd3); transc[31:16] = rdval;
		chk("total_ops",  total,  32'd6);
		chk("transc_ops", transc, 32'd3);
		rd(3'd4); chk("magic",    {16'd0, rdval}, 32'h0000FA86);
		rd(3'd5); chk("oob_word", {16'd0, rdval}, 32'h00000000);

		// reset clears
		@(negedge clk); reset = 1;
		@(negedge clk); reset = 0;
		@(negedge clk);
		rd(3'd0); total[15:0]  = rdval;
		rd(3'd1); total[31:16] = rdval;
		chk("total_after_reset",  total, 32'd0);
		rd(3'd2); transc[15:0]  = rdval;
		rd(3'd3); transc[31:16] = rdval;
		chk("transc_after_reset", transc, 32'd0);

		if (errors == 0) $display("ALL PASS");
		else             $display("FAILURES: %0d", errors);
		$finish;
	end
endmodule
