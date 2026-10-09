//============================================================================
//  PC8801SR - cassette (CMT) recording status to the OSD
//
//  Copyright (C) 2026 Yoshiaki Okuyama
//  SPDX-License-Identifier: GPL-2.0-or-later
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
// cmt_ev - sends recording status messages (ev_code from cmt_wblk) to the OSD info line
//
// The host polls info only once every 100 ms, so a message sent sooner after the
// previous one replaces it unseen. Messages are queued here and sent one at a time
// with a gap between them. The queue holds four; when it is full the newest is
// dropped, so the reason a recording stopped is not pushed out.
//
// hps_io latches info on the rising edge of info_req, so a one-clock pulse is enough;
// info is set on the same clock.
//
// The OSD "Tape Record" item stays On after recording ends on its own, so these
// messages are the only way the user learns that it stopped. A queued stop reason is
// kept; an event that arrives while the queue is full and the gap is running is lost.
//
module cmt_ev #(
	// minimum gap between two messages: 2^23 clocks at 20 MHz is about 0.42 s
	parameter int GAP_BITS = 23,
	// index (1-based) of the first recording message in the CONF_STR "I," list
	parameter [7:0] INFO_BASE = 8'd1
) (
	input             clk,
	input             rst_n,

	input             ev_req,
	input       [3:0] ev_code,

	output reg        info_req,
	output reg  [7:0] info
);

reg  [3:0] q [0:3];
reg  [1:0] wp = 0, rp = 0;
reg  [2:0] cnt = 0;                     // queued messages, 0 to 4
reg [GAP_BITS-1:0] gap = 0;

wire empty = (cnt == 0);
wire full  = (cnt == 3'd4);

always @(posedge clk) begin
	info_req <= 1'b0;
	if (!rst_n) begin
		wp <= 0; rp <= 0; cnt <= 0; gap <= 0; info <= 0;
	end else begin
		if (gap != 0) gap <= gap - 1'd1;

		// a push and a pop can land on the same clock, so the count is updated once
		case ({(ev_req && !full), (gap == 0 && !empty)})
		2'b10: begin q[wp] <= ev_code; wp <= wp + 1'd1; cnt <= cnt + 1'd1; end
		2'b01: begin
			info     <= INFO_BASE + {4'd0, q[rp]};
			info_req <= 1'b1;
			rp       <= rp + 1'd1;
			cnt      <= cnt - 1'd1;
			gap      <= {GAP_BITS{1'b1}};
		end
		2'b11: begin
			q[wp]    <= ev_code; wp <= wp + 1'd1;
			info     <= INFO_BASE + {4'd0, q[rp]};
			info_req <= 1'b1;
			rp       <= rp + 1'd1;
			gap      <= {GAP_BITS{1'b1}};
			// one in, one out: the count does not change
		end
		default: ;
		endcase
	end
end

endmodule
