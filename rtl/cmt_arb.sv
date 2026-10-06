//============================================================================
//  PC8801SR - SD arbiter between the disk and the cassette
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
// cmt_arb - lets only one of the disk and the cassette use the shared SD signals at a time
//
// The disk side (rtl/diskemu_mister) takes the shared write strobes without looking at its
// own sd_ack, so only one side may have a request out. A side owns the port from the grant
// until both its request and the acknowledgement have fallen. When both request, the side
// that did not go last is granted.
//
module cmt_arb (
	input        clk,
	input        rst_n,

	// the disk side (existing VHDL), slots 0 to 3
	input  [3:0] dsk_rd,
	input  [3:0] dsk_wr,
	output [3:0] dsk_ack,

	// the cassette side, slot 4
	input        tap_rd,
	input        tap_wr,
	output       tap_ack,
	input [31:0] tap_lba,          // held here while a tape transfer is drained
	output [31:0] host_lba,

	// the host side, hps_io
	output [4:0] host_rd,
	output [4:0] host_wr,
	input  [4:0] host_ack,

	// so the shared write strobes reach only the current owner
	output       own_disk,
	output       own_tape
);

// OWN_DRAIN: a tape transfer was out when reset came; its response is taken and dropped.
localparam OWN_NONE = 2'd0, OWN_DISK = 2'd1, OWN_TAPE = 2'd2, OWN_DRAIN = 2'd3;

reg [1:0] owner = OWN_NONE;
reg       last_was_disk = 1'b0;   // alternation, so neither side starves

// A transfer has been handed to the host and its response has not ended yet.
reg       sent  = 1'b0;
reg       ack_d = 1'b0;   // whether a response was asserted a clock ago, to see it leave
// The request and address being drained are held until the host responds.
reg [4:0] drain_rd = 5'b0, drain_wr = 5'b0;
reg [31:0] drain_lba = 32'd0;

wire dsk_req = |dsk_rd | |dsk_wr;
wire tap_req = tap_rd | tap_wr;

wire dsk_acked = |host_ack[3:0];
wire tap_acked = host_ack[4];

// Only the owner's request reaches the host.
assign host_rd = (owner == OWN_DISK)  ? {1'b0, dsk_rd} :
                 (owner == OWN_TAPE)  ? {tap_rd, 4'b0} :
                 (owner == OWN_DRAIN) ? drain_rd : 5'b0;
assign host_wr = (owner == OWN_DISK)  ? {1'b0, dsk_wr} :
                 (owner == OWN_TAPE)  ? {tap_wr, 4'b0} :
                 (owner == OWN_DRAIN) ? drain_wr : 5'b0;

// While draining, the response goes to neither side.
assign dsk_ack = (owner == OWN_DISK) ? host_ack[3:0] : 4'b0;
assign tap_ack = (owner == OWN_TAPE) ? host_ack[4]   : 1'b0;

assign host_lba = (owner == OWN_DRAIN) ? drain_lba : tap_lba;

assign own_disk = (owner == OWN_DISK);
assign own_tape = (owner == OWN_TAPE);

wire req_out = (|host_rd) | (|host_wr);

// A requester holds its request until the acknowledgement rises.

always @(posedge clk) begin
	ack_d <= (|host_ack);
	if (req_out || (|host_ack)) sent <= 1'b1;
	else if (ack_d)             sent <= 1'b0;

	if (!rst_n) begin
		// A tape transfer is drained. A disk transfer is left to finish, because the
		// disk side is not reset by the OSD reset.
		if (owner == OWN_TAPE) begin
			owner     <= OWN_DRAIN;
			drain_rd  <= host_rd;
			drain_wr  <= host_wr;
			drain_lba <= tap_lba;
		end else if (owner == OWN_DISK) begin
		end else if (!sent) begin
			owner <= OWN_NONE;
			last_was_disk <= 1'b0;
			drain_rd <= 5'b0;
			drain_wr <= 5'b0;
		end
	end else begin
		case (owner)
		OWN_NONE: begin
			if (dsk_req && tap_req) begin
				if (last_was_disk) begin owner <= OWN_TAPE; last_was_disk <= 1'b0; end
				else               begin owner <= OWN_DISK; last_was_disk <= 1'b1; end
			end
			else if (dsk_req) begin owner <= OWN_DISK; last_was_disk <= 1'b1; end
			else if (tap_req) begin owner <= OWN_TAPE; last_was_disk <= 1'b0; end
		end
		OWN_DISK:
			if (!dsk_req && !dsk_acked) owner <= OWN_NONE;
		OWN_TAPE:
			if (!tap_req && !tap_acked) owner <= OWN_NONE;
		OWN_DRAIN: begin
			if (|host_ack) begin drain_rd <= 5'b0; drain_wr <= 5'b0; end
			if (!sent) owner <= OWN_NONE;
		end
		default: owner <= OWN_NONE;
		endcase
	end
end
endmodule
