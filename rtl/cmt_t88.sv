//============================================================================
//  PC8801SR - .t88 reader
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
// cmt_t88 - reads a .t88 image and produces bytes and the waits between them
//
//   24-byte magic, then blocks of tag(u16) + len(u16) + body
//   END=0x0000 VERSION=0x0001 COMMENT=0x0010 GAP=0x0100 DATA=0x0101 SPACE=0x0102 MARK=0x0103
//   a DATA body is a 12-byte sub-header (start_tick u32, length_ticks u32, data_len u16,
//   fmt u16) followed by the data; fmt 0x01CC is 1200 baud, 0x00CC is 600
//   GAP, SPACE and MARK become waits of length_ticks; a tick is 1/4800 s
//   other tags are skipped
//
module cmt_t88 #(
	// A tick is TICK_CLK + 1 clocks.
	parameter int TICK_CLK = 4167
)(
	input             clk,
	input             rst_n,
	input             start,        // one clock: restart from the beginning

	input             run,          // motor on; a wait only counts while it is set
	input             eof,          // end of file, from cmt_file

	// bytes in, from cmt_file
	input       [7:0] fbyte,
	input             fbyte_valid,
	output reg        fbyte_ack,

	// bytes out, to cmt_serial
	output reg  [7:0] obyte,
	output reg        obyte_valid,
	input             obyte_ack,
	input             ser_busy,     // a wait does not count until the last frame has been sent

	output reg        speed_1200,   // the rate of the last DATA record seen
	output reg        carrier,      // high only while a MARK is playing
	output reg        done,         // END has been reached
	output reg        bad_tag       // a broken or truncated image
);

localparam S_HDR   = 4'd0,  S_TAG   = 4'd1,  S_LEN  = 4'd2,  S_DISP = 4'd3,
           S_SKIP  = 4'd4,  S_TIME  = 4'd5,  S_WAIT = 4'd6,  S_SUB  = 4'd7,
           S_DATA  = 4'd8,  S_TAIL  = 4'd9,  S_DONE = 4'd10, S_BAD  = 4'd11;

reg [3:0]  st = S_HDR;
reg [15:0] tag = 0, blen = 0;
reg [31:0] cnt = 0;          // bytes left, used by several states
reg [3:0]  sub = 0;          // position within a sub-header
reg [31:0] ticks = 0;        // ticks left to wait
reg [31:0] tclk = 0;         // clocks within the current tick
reg [15:0] dlen = 0;

// one byte taken from the file
wire take = fbyte_valid && fbyte_ack;

// The data served is the smaller of data_len and what the block holds; the rest is skipped.
wire [31:0] blen32 = {16'd0, blen};
wire [31:0] dlen32 = {16'd0, dlen};
wire [31:0] room32 = (blen32 >= 32'd12) ? (blen32 - 32'd12) : 32'd0;
wire [31:0] use32  = (dlen32 < room32) ? dlen32 : room32;
wire [31:0] rest32 = room32 - use32;

always @(posedge clk) begin
	fbyte_ack   <= 1'b0;
	if (!rst_n || start) begin
		st <= S_HDR; cnt <= 24; sub <= 0; done <= 0; bad_tag <= 0;
		obyte_valid <= 0; carrier <= 0; speed_1200 <= 1'b1;
	end else if (eof && !fbyte_valid && (
			st == S_HDR || st == S_TAG || st == S_LEN || st == S_TIME || st == S_SUB ||
			(st == S_SKIP && cnt != 0) || (st == S_TAIL && cnt != 0) ||
			(st == S_DATA && cnt != 0 && !obyte_valid))) begin
		// the file ended while a byte was expected
		bad_tag <= 1'b1; obyte_valid <= 1'b0; st <= S_BAD;
	end else begin
		case (st)
		S_HDR: begin                       // skip the 24-byte magic
			if (fbyte_valid && !fbyte_ack) fbyte_ack <= 1'b1;
			if (take) begin
				if (cnt == 1) begin st <= S_TAG; sub <= 0; end
				cnt <= cnt - 1'd1;
			end
		end
		S_TAG: begin                       // tag, low byte then high; sub is 0 on entry
			if (fbyte_valid && !fbyte_ack) fbyte_ack <= 1'b1;
			if (take) begin
				if (sub == 0) begin tag[7:0]  <= fbyte; sub <= 1; end
				else          begin tag[15:8] <= fbyte; sub <= 0; st <= S_LEN; end
			end
		end
		S_LEN: begin
			if (fbyte_valid && !fbyte_ack) fbyte_ack <= 1'b1;
			if (take) begin
				if (sub == 0) begin blen[7:0]  <= fbyte; sub <= 1; end
				else          begin blen[15:8] <= fbyte; sub <= 0; st <= S_DISP; end
			end
		end
		S_DISP: begin
			carrier <= 1'b0;
			case (tag)
			16'h0000: begin done <= 1'b1; st <= S_DONE; end
			16'h0001, 16'h0010: begin cnt <= {16'd0, blen}; st <= S_SKIP; end   // VERSION / COMMENT
			16'h0100, 16'h0102, 16'h0103: begin                                 // GAP / SPACE / MARK
				if (blen != 16'd8) begin bad_tag <= 1'b1; st <= S_BAD; end
				else begin
					cnt <= 8; sub <= 0; ticks <= 0; st <= S_TIME;
					carrier <= (tag == 16'h0103);      // carrier only during a MARK
				end
			end
			16'h0101: begin                                                     // DATA
				if (blen < 16'd12) begin bad_tag <= 1'b1; st <= S_BAD; end
				else begin cnt <= 12; sub <= 0; st <= S_SUB; end
			end
			default: begin cnt <= {16'd0, blen}; st <= S_SKIP; end              // other tags are skipped
			endcase
		end
		S_SKIP: begin
			if (cnt == 0) begin sub <= 0; st <= S_TAG; end
			else begin
				if (fbyte_valid && !fbyte_ack) fbyte_ack <= 1'b1;
				if (take) cnt <= cnt - 1'd1;
			end
		end
		S_TIME: begin                      // eight bytes: discard four, keep length_ticks
			if (fbyte_valid && !fbyte_ack) fbyte_ack <= 1'b1;
			if (take) begin
				if (sub >= 4) ticks <= {fbyte, ticks[31:8]};   // low byte first
				sub <= sub + 1'd1;
				if (cnt == 1) begin tclk <= TICK_CLK[31:0]; st <= S_WAIT; end
				cnt <= cnt - 1'd1;
			end
		end
		S_WAIT: begin
			if (ticks == 0) begin sub <= 0; st <= S_TAG; end
			else if (!run) ;
			else if (ser_busy) ;
			else if (tclk == 0) begin tclk <= TICK_CLK[31:0]; ticks <= ticks - 1'd1; end
			else tclk <= tclk - 1'd1;
		end
		S_SUB: begin                       // the 12-byte DATA sub-header
			if (fbyte_valid && !fbyte_ack) fbyte_ack <= 1'b1;
			if (take) begin
				case (sub)
				4'd8:  dlen[7:0]  <= fbyte;
				4'd9:  dlen[15:8] <= fbyte;
				4'd11: speed_1200 <= fbyte[0];   // high byte of fmt
				default: ;
				endcase
				sub <= sub + 1'd1;
				if (cnt == 1) begin
					cnt <= use32;
					st  <= S_DATA;
				end else cnt <= cnt - 1'd1;
			end
		end
		S_DATA: begin
			if (cnt == 0) begin
				cnt <= rest32;
				st  <= S_TAIL;
			end else if (!obyte_valid) begin
				if (fbyte_valid && !fbyte_ack) fbyte_ack <= 1'b1;
				if (take) begin obyte <= fbyte; obyte_valid <= 1'b1; end
			end else if (obyte_ack) begin
				obyte_valid <= 1'b0;
				cnt <= cnt - 1'd1;
			end
		end
		S_TAIL: begin
			if (cnt == 0) begin sub <= 0; st <= S_TAG; end
			else begin
				if (fbyte_valid && !fbyte_ack) fbyte_ack <= 1'b1;
				if (take) cnt <= cnt - 1'd1;
			end
		end
		S_DONE: obyte_valid <= 1'b0;
		S_BAD:  obyte_valid <= 1'b0;
		default: st <= S_BAD;
		endcase
	end
end
endmodule
