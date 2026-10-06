//============================================================================
//  PC8801SR - cassette (CMT) byte to serial
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
// cmt_serial - bytes out as an asynchronous serial stream, into the 8251's RxD
//
// The frame (data bits, parity, stop bits) and the rate come from the 8251 mode the CPU
// wrote. div is clocks per bit minus one: (D+1) x 2 x 16 - 1 for the 8251 divisor D,
// 16639 for 1200 baud and 33311 for 600 baud at 20 MHz.
//
module cmt_serial (
	input             clk,
	input             rst_n,

	// transport control from the top level; while low the stream stops where it is
	input             run,

	input      [15:0] div,          // clocks per bit, minus one
	input       [3:0] data_bits,    // 5 to 8
	input             parity_en,
	input             parity_odd,
	input       [1:0] stop_bits,    // 1 to 3; 0 is treated as 1

	// where the bytes come from: cmt_file or cmt_t88
	input       [7:0] din,
	input             din_valid,
	// one clock when the byte is taken; din_valid and din are held until then
	output reg        din_ack,

	output reg        txd = 1'b1,

	// high while a frame is on the line, including the last stop bit
	output            busy
);

localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_TAIL = 2'd3;

assign busy = (state != S_IDLE) || stop_hold;

reg  [1:0]  state = S_IDLE;
reg  [15:0] cnt   = 0;
reg  [3:0]  idx   = 0;
reg  [7:0]  sh    = 0;
reg         par   = 0;
reg  [2:0]  tail  = 0;      // parity and stop bits still to go
reg         stop_hold = 0;  // held until the final stop bit has had its bit time

wire [2:0] stop_n = (stop_bits == 2'd0) ? 3'd1 : {1'b0, stop_bits};

wire tick = (cnt == 0);

always @(posedge clk) begin
	din_ack <= 1'b0;
	if (!rst_n) begin
		state <= S_IDLE; txd <= 1'b1; cnt <= 0; idx <= 0; tail <= 0; stop_hold <= 1'b0;
	end else if (!run && state == S_IDLE && !stop_hold) begin
		// A frame in progress is finished before stopping.
		txd <= 1'b1;
	end else begin
		if (!tick) cnt <= cnt - 1'd1;
		else begin
			cnt <= div;
			case (state)
			S_IDLE: begin
				txd <= 1'b1;
				stop_hold <= 1'b0;
				if (din_valid && run) begin
					sh      <= din;
					par     <= parity_odd;   // odd parity starts from 1
					idx     <= 0;
					txd     <= 1'b0;         // start bit
					din_ack <= 1'b1;         // taken on this clock
					state   <= S_START;
				end
			end
			S_START: begin
				txd   <= sh[0];
				par   <= par ^ sh[0];
				sh    <= {1'b0, sh[7:1]};
				idx   <= 1;
				state <= S_DATA;
			end
			S_DATA: begin
				if (idx < data_bits) begin
					txd <= sh[0];
					par <= par ^ sh[0];
					sh  <= {1'b0, sh[7:1]};
					idx <= idx + 1'd1;
				end else begin
					if (parity_en) begin
						txd   <= par;
						tail  <= stop_n;
						state <= S_TAIL;
					end else begin
						txd  <= 1'b1;             // first stop bit
						if (stop_n == 3'd1) begin state <= S_IDLE; stop_hold <= 1'b1; end
						else begin tail <= stop_n - 3'd1; state <= S_TAIL; end
					end
				end
			end
			S_TAIL: begin
				txd  <= 1'b1;
				tail <= tail - 3'd1;
				// last stop bit: stop_hold keeps busy up for its bit time
				if (tail <= 3'd1) begin state <= S_IDLE; stop_hold <= 1'b1; end
			end
			endcase
		end
	end
end

endmodule
