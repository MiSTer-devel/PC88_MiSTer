//============================================================================
//  PC8801SR - cassette (CMT) image reader
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
// cmt_file - reads the mounted tape image from the SD slot, a block at a time
//
// One 512-byte block lasts over four seconds at 1200 baud, so a single buffer is enough.
//
module cmt_file (
	input             clk,
	input             rst_n,

	// transport, from the top level; while low it stops and keeps its position
	input             run,

	// mount notification; img_size is only valid on the pulse, so it is latched here
	input             mounted,       // one clock
	input      [63:0] img_size,

	// SD, reaching the host through the cmt_arb arbiter
	output reg [31:0] sd_lba,
	output reg        sd_rd,
	input             sd_ack,
	input       [8:0] sd_buff_addr,
	input       [7:0] sd_buff_dout,
	input             sd_buff_wr,

	// bytes out, to cmt_serial
	output      [7:0] dout,
	output reg        dout_valid,
	input             dout_ack,      // taken, one clock

	output reg        eof,           // the end of the file has been served
	output reg        no_file,       // nothing is mounted

	// one clock when a mount or a rewind takes effect; format detection restarts on it
	output reg        mnt_apply
);

localparam S_IDLE = 3'd0, S_REQ = 3'd1, S_WAIT = 3'd2, S_SERVE = 3'd3, S_EOF = 3'd4;

reg [2:0]  state = S_IDLE;
reg [7:0]  blkbuf [0:511];   // "buf" is a SystemVerilog keyword
reg [8:0]  rptr = 0;
reg [31:0] size_blocks = 0;
reg [31:0] blk = 0;
reg [9:0]  last_len = 10'd512;     // valid length of the final block; 512 needs ten bits
// a mount that arrives during a transfer (S_WAIT), applied when the transfer closes
reg        mnt_pend = 0;
reg [63:0] mnt_size = 0;
// set by a reset with an image in: the image starts again from block 0
reg        rewind = 0;

assign dout = blkbuf[rptr];

// Block data is taken while this side's read is open; the write pulses can lag sd_ack.
always @(posedge clk) if (sd_buff_wr && state == S_WAIT) blkbuf[sd_buff_addr] <= sd_buff_dout;

always @(posedge clk) begin
	mnt_apply <= 1'b0;              // one clock, only where a mount is applied below
	if (!rst_n) begin
		state <= S_IDLE; sd_rd <= 0; dout_valid <= 0; eof <= 0; blk <= 0; rptr <= 0;
		// A reset rewinds the image. A mount deferred by a transfer is applied here.
		if (mnt_pend) begin
			size_blocks <= mnt_size[40:9] + 32'(|mnt_size[8:0]);
			last_len    <= (mnt_size[8:0] == 0) ? 10'd512 : {1'b0, mnt_size[8:0]};
			no_file     <= (mnt_size == 0);
		end
		rewind   <= mnt_pend ? (mnt_size != 0) : !no_file;
		mnt_pend <= 1'b0;
	end else begin
		if (mounted && state == S_WAIT) begin
			// The request is kept until the transfer closes; the mount is applied then.
			mnt_pend <= 1'b1;
			mnt_size <= img_size;
		end else if (mounted) begin
			size_blocks <= img_size[40:9] + 32'(|img_size[8:0]);   // rounded up
			last_len    <= (img_size[8:0] == 0) ? 10'd512 : {1'b0, img_size[8:0]};
			blk         <= 0;
			rptr        <= 0;
			eof         <= 0;
			no_file     <= (img_size == 0);
			dout_valid  <= 0;
			state       <= (img_size == 0) ? S_IDLE : S_REQ;
			rewind      <= 1'b0;
			mnt_apply   <= 1'b1;
		end else if (rewind) begin
			rewind    <= 1'b0;
			state     <= S_REQ;
			mnt_apply <= 1'b1;
		end else case (state)
		S_IDLE: ;                       // waiting for a mount
		S_REQ: begin
			if (blk >= size_blocks) state <= S_EOF;
			// a new request only after the previous acknowledgement has fallen
			else if (run && !sd_ack) begin   // no request while the transport is stopped
				sd_lba <= blk;
				sd_rd  <= 1'b1;
				state  <= S_WAIT;
			end
		end
		S_WAIT: begin
			// the transfer ends when the acknowledgement falls, as in cmt_arb
			if (sd_ack) sd_rd <= 1'b0;
			if (!sd_rd && !sd_ack) begin
				if (mnt_pend) begin
					mnt_pend    <= 1'b0;
					size_blocks <= mnt_size[40:9] + 32'(|mnt_size[8:0]);
					last_len    <= (mnt_size[8:0] == 0) ? 10'd512 : {1'b0, mnt_size[8:0]};
					blk         <= 0;
					rptr        <= 0;
					eof         <= 0;
					no_file     <= (mnt_size == 0);
					dout_valid  <= 0;
					state       <= (mnt_size == 0) ? S_IDLE : S_REQ;
					mnt_apply   <= 1'b1;
				end else begin
					rptr       <= 0;
					dout_valid <= run;
					state      <= S_SERVE;
				end
			end
		end
		S_SERVE: begin
			dout_valid <= run;          // stop offering when stopped, keeping the position
			if (dout_valid && dout_ack) begin
				// the valid length of this block; only the last one is short
				if (({1'b0, rptr} + 10'd1) >= ((blk + 32'd1 == size_blocks) ? last_len : 10'd512)) begin
					blk        <= blk + 1'd1;
					dout_valid <= 1'b0;
					state      <= S_REQ;
				end else rptr <= rptr + 1'd1;
			end
		end
		S_EOF: begin
			dout_valid <= 1'b0;
			eof        <= 1'b1;
		end
		default: state <= S_IDLE;
		endcase
	end
end
endmodule
