//============================================================================
//  PC8801SR - cassette (CMT) input
//
//  Copyright (C) 2026 Yoshiaki Okuyama
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

//
// cmt_demod - cassette FSK to the asynchronous serial line the 8251 receives
//
// A mark of 2400 Hz is a 1 and a space of 1200 Hz is a 0. A bit is a whole number of cycles
// of its tone, so one half cycle tells the two apart: about 208 us for a mark and 417 us for
// a space, split at their geometric mean. The 8251 clocks the line and does the framing.
//
// An accepted change is applied THRESH clocks after the boundary it belongs to rather than
// when it is noticed, so the line is the real one delayed by a constant.
//
module cmt_demod #(
	parameter int CLK_HZ = 20000000
)(
	input      clk,
	input      reset,

	input      level,     // squared-up tape signal from cmt_adc
	output reg rxd        // asynchronous serial line for the 8251
);

// A mark's half period is CLK_HZ/4800 (4166 clocks at 20 MHz) and a space's is CLK_HZ/2400
// (8333). They are split at 3394 Hz, the geometric mean of 2400 and 4800.
localparam int HALF_1200 = CLK_HZ / 2400;
localparam int THRESH    = CLK_HZ / 3394;   // 5893 clocks at 20 MHz
localparam int TIMEOUT   = 2 * HALF_1200;   // no edge for this long = no carrier

localparam int CW = $clog2(TIMEOUT + 1);

reg [CW-1:0] cnt;        // clocks since the last edge of `level`
reg          level_d;
reg          mark;       // tone currently being received: 1 = 2400 Hz, 0 = 1200 Hz

// a change that has been decided but is waiting to land on its bit boundary + THRESH
reg [CW-1:0] pend_cnt;
reg          pend_val;
reg          pend_act;

always @(posedge clk) begin
	if (reset) begin
		cnt      <= 0;
		level_d  <= level;
		mark     <= 1'b1;
		rxd      <= 1'b1;    // idle is mark, as it is for any UART
		pend_cnt <= 0;
		pend_val <= 1'b1;
		pend_act <= 1'b0;
	end
	else begin
		level_d <= level;

		if (pend_act) begin
			if (pend_cnt == 0) begin
				rxd      <= pend_val;
				pend_act <= 1'b0;
			end
			else pend_cnt <= pend_cnt - 1'd1;
		end

		if (level_d != level) begin
			// an edge closes a half period; short means the tone is a mark
			cnt <= 0;
			if (cnt < CW'(THRESH) && !mark) begin
				// space -> mark. The boundary was `cnt` clocks ago, so wait out the rest.
				mark     <= 1'b1;
				pend_val <= 1'b1;
				pend_cnt <= CW'(THRESH) - cnt;
				pend_act <= 1'b1;
			end
		end
		else begin
			if (cnt < CW'(TIMEOUT)) cnt <= cnt + 1'd1;

			// the half period has run too long to be a mark. It began THRESH clocks ago,
			// which is the delay every change gets, so this one lands now.
			if (cnt == CW'(THRESH) - 1'd1 && mark) begin
				mark     <= 1'b0;
				rxd      <= 1'b0;
				pend_act <= 1'b0;
			end

			// the carrier has stopped. Idle the line rather than hold a space, which the
			// 8251 would keep framing as break characters.
			if (cnt == CW'(TIMEOUT) - 1'd1) begin
				mark     <= 1'b1;
				rxd      <= 1'b1;
				pend_act <= 1'b0;
			end
		end
	end
end

endmodule
