//============================================================================
//  PC8801SR - cassette (CMT) transport control
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

// cmt_deck - transport control for the tape paths
//
//   No data passes through here. It only decides, for each of the three paths
//   (file playback, tape input, recording), whether it runs or is stopped.
module cmt_deck (
	input        clk,
	input        rst_n,

	// from the core
	input        mton,          // port 0x30 bit 3 (motor on)
	input        cmt_sel,       // port 0x30 bit 5, inverted (1 = CMT selected)

	// from the OSD
	input        rec_enable,    // recording is switched on
	input        file_mounted,  // an image is mounted
	// Whether the image exists or is writable is not checked here; cmt_wblk owns that
	// decision and reports the reason. Checking it here too would keep rec_active low
	// and those reasons could never be reported.

	output       play_run,      // file playback runs
	output       tape_run,      // tape input runs
	output       rec_run,       // recording is captured
	output reg   rec_active     // a recording session is open (used to detect its end)
);

// Playback and recording are exclusive, so file playback does not drive the 8251's RxD
// while SAVE is captured from its TxD. Recording runs while it is enabled, CMT is
// selected and the motor is on; refusing a missing or read-only image is left to cmt_wblk.
wire want_rec  = rec_enable && cmt_sel;
wire want_play = !rec_enable && file_mounted && cmt_sel;

assign play_run = want_play && mton;
assign rec_run  = want_rec  && mton;
// Tape input runs without a mounted image.
assign tape_run = !rec_enable && cmt_sel && mton;

// A session opens on the first motor on while rec_enable is set and closes when
// rec_enable drops. It does not close on motor off: the BIOS stops the motor
// between blocks.
always @(posedge clk) begin
	if (!rst_n) rec_active <= 1'b0;
	else if (!rec_enable) rec_active <= 1'b0;
	else if (want_rec && mton) rec_active <= 1'b1;
end
endmodule
