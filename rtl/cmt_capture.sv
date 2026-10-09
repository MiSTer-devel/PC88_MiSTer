//============================================================================
//  PC8801SR - cassette (CMT) serial to byte, for recording
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
// cmt_capture - the 8251's TxD (asynchronous serial) back into bytes, for recording
//
// This does not duplicate the 8251's receiver: the 8251 still frames RxD itself. What is
// read here is the line the 8251 transmits, and framing that line can only be done here.
// The frame format and rate are the same ones cmt_serial gets, from the same 8251 mode.
//
module cmt_capture (
	input             clk,
	input             rst_n,

	input             run,          // from cmt_deck; no new frame starts while low
	input      [15:0] div,          // clocks per bit, minus one
	input       [3:0] data_bits,
	input             parity_en,
	input             parity_odd,

	input             rxd,          // the 8251's TxD

	output reg  [7:0] dout,
	output reg        dout_valid,   // one clock
	output reg        frame_err,    // stop bit was not 1
	output reg        parity_err,

	// high while a frame is being captured. Mirrors cmt_serial's busy, so the top level
	// keeps the USART on the tape rate until the frame is through (e.g. when the motor
	// stops while recording) instead of falling back to the RS-232C rate mid-byte.
	output            busy
);

localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

reg [1:0]  state = S_IDLE;
reg [15:0] cnt   = 0;
reg [3:0]  idx   = 0;
reg [7:0]  sh    = 0;
reg        par   = 0;
reg        r1 = 1'b1, r2 = 1'b1;

// The 8251 runs on clk21m, which the top level ties to clk_sys, so rxd is already in this
// clock domain. The two-stage register is harmless and kept anyway.
always @(posedge clk) begin r1 <= rxd; r2 <= r1; end

// Busy from the falling edge, before the start bit is confirmed. Noise can raise it for a
// moment, which errs on the safe side.
assign busy = (state != S_IDLE);

always @(posedge clk) begin
	dout_valid <= 1'b0;
	if (!rst_n) begin
		state <= S_IDLE; cnt <= 0; idx <= 0; frame_err <= 0; parity_err <= 0;
	end else if (!run && state == S_IDLE) begin
		// A frame in progress is finished before stopping; dropping it would make the
		// remaining bits look like the start of a new frame when run returns.
		state <= S_IDLE;
	end else begin
		case (state)
		S_IDLE: begin
			// wait for the falling edge of a start bit
			if (r2 == 1'b0) begin
				// half a bit, to sample in the center
				cnt   <= {1'b0, div[15:1]};
				state <= S_START;
			end
		end
		S_START: begin
			if (cnt == 0) begin
				// still low at the center: a real start bit; otherwise noise
				if (r2 == 1'b0) begin
					cnt   <= div;
					idx   <= 0;
					par   <= parity_odd;
					state <= S_DATA;
				end else state <= S_IDLE;
			end else cnt <= cnt - 1'd1;
		end
		S_DATA: begin
			if (cnt == 0) begin
				cnt <= div;
				if (idx < data_bits) begin
					sh  <= {r2, sh[7:1]};
					par <= par ^ r2;
					idx <= idx + 1'd1;
				end else begin
					if (parity_en) begin
						parity_err <= (par != r2);
						state      <= S_STOP;
					end else begin
						// this sample is the first stop bit
						frame_err  <= (r2 != 1'b1);
						// fewer than 8 data bits sit at the top; shift them down
						dout       <= sh >> (8 - data_bits);
						dout_valid <= 1'b1;
						state      <= S_IDLE;
					end
				end
			end else cnt <= cnt - 1'd1;
		end
		S_STOP: begin
			if (cnt == 0) begin
				frame_err  <= (r2 != 1'b1);
				dout       <= sh >> (8 - data_bits);
				dout_valid <= 1'b1;
				state      <= S_IDLE;
			end else cnt <= cnt - 1'd1;
		end
		endcase
	end
end
endmodule
