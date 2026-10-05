//============================================================================
//  PC8801SR - cassette (CMT) image format detection
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
// cmt_fmt - tells a .t88 image from a .cmt one
//
// The core does not get the file extension, so the first eight bytes are compared with the
// magic strings "PC-8801 Tape Image(T88)", "PC-8001 Tape Image(T88)" and "T88-FILE".
//
module cmt_fmt (
	input             clk,
	input             rst_n,

	// mount notification (one clock; the same pulse cmt_file sees)
	input             mounted,

	// the 512 bytes the host writes in (already gated by the arbiter)
	input       [8:0] sd_buff_addr,
	input       [7:0] sd_buff_dout,
	input             sd_buff_wr,

	// high for .t88, which goes to the parser; low means .cmt, the raw byte stream
	output reg        is_t88
);

// The first eight bytes of the magic, earlier bytes in the high half.
localparam [63:0] MAGIC_8801 = 64'h50_43_2D_38_38_30_31_20;   // "PC-8801 "
localparam [63:0] MAGIC_8001 = 64'h50_43_2D_38_30_30_31_20;   // "PC-8001 "
localparam [63:0] MAGIC_T88F = 64'h54_38_38_2D_46_49_4C_45;   // "T88-FILE"

reg [63:0] head = 0;
reg        arm  = 0;      // open only over the first eight bytes after a mount

// the seven bytes so far and the byte arriving now
wire [63:0] head_now = {head[55:0], sd_buff_dout};

always @(posedge clk) begin
	if (!rst_n) begin
		is_t88 <= 1'b0; arm <= 1'b0; head <= 64'd0;
	end else if (mounted) begin
		is_t88 <= 1'b0; arm <= 1'b1; head <= 64'd0;
	end else if (arm && sd_buff_wr && (sd_buff_addr < 9'd8)) begin
		head <= head_now;
		if (sd_buff_addr == 9'd7) begin
			arm    <= 1'b0;     // close the window; later blocks are not examined
			is_t88 <= (head_now == MAGIC_8801)
			       || (head_now == MAGIC_8001)
			       || (head_now == MAGIC_T88F);
		end
	end
end
endmodule
