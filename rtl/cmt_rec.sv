//============================================================================
//  PC8801SR - cassette (CMT) recording chain
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
// cmt_rec - the recording chain in one place: 8251 TxD -> bytes -> .t88 container ->
// SD blocks
//
// Kept out of the top level so that a Verilator testbench can run the whole chain.
//
// This module also shares the tape's SD port between playback (cmt_play) and recording.
// cmt_deck keeps the two from running at the same time, but that alone does not stop the
// owner from changing in the middle of a transfer, and cmt_file would then wait forever
// for an ack that never comes. Ownership therefore moves only between transfers, the same
// approach cmt_arb takes between disk and tape.
//
module cmt_rec #(
	// clocks per tick (1/4800 s) at 20 MHz; the top level overrides it
	parameter int TICK_CLK  = 4166,
	parameter int PAY_MAX   = 512,
	parameter int GAP_BYTES = 4,
	// idle clocks after which buffered data is flushed to the card (about 1 s at 20 MHz)
	parameter int FLUSH_CLK = 20000000
) (
	input             clk,
	input             rst_n,

	// from the 8251; same frame format and rate as cmt_serial
	input             txd,          // the 8251's TxD
	input      [15:0] div,
	input       [3:0] data_bits,
	input             parity_en,
	input             parity_odd,

	// transport (cmt_deck) and OSD
	input             rec_run,      // motor on and recording
	input             rec_active,   // a recording session is open
	input             rec_enable,   // OSD switch; independent of the motor
	input             speed_1200,
	// the 8251 mode can be recorded; cmt_wblk does the refusing
	input             mode_ok,

	// mount
	input             mounted,
	input      [63:0] img_size,
	input             img_ro,

	// SD requests from playback, merged here
	input      [31:0] play_lba,
	input             play_rd,
	output            play_ack,

	// SD, to the cmt_arb arbiter
	output     [31:0] sd_lba,
	output            sd_rd,
	output            sd_wr,
	input             sd_ack,
	input       [8:0] sd_buff_addr,
	input       [7:0] sd_buff_dout,
	input             sd_buff_wr,
	output      [7:0] sd_buff_din,

	// reason codes for the OSD
	output            ev_req,
	output      [3:0] ev_code,

	// a byte is being captured; like cmt_serial's busy, it keeps the USART on the tape rate
	// (instead of falling back to the RS-232C rate) when the motor stops mid-frame
	output            cap_busy
);

// -- 8251 TxD -> bytes
wire [7:0] cap_byte;
wire       cap_valid;
/* verilator lint_off UNUSEDSIGNAL */
// Bytes with framing errors are recorded as they are: a real tape carries noise too, and
// filtering here would make the image differ from what the machine actually wrote.
wire       cap_ferr, cap_perr;
/* verilator lint_on UNUSEDSIGNAL */

cmt_capture u_cap (
	.clk(clk), .rst_n(rst_n),
	.run(rec_run),
	.div(div), .data_bits(data_bits),
	.parity_en(parity_en), .parity_odd(parity_odd),
	.rxd(txd),
	.dout(cap_byte), .dout_valid(cap_valid),
	.frame_err(cap_ferr), .parity_err(cap_perr),
	.busy(cap_busy)
);

// -- bytes -> .t88 container
wire [7:0] t88_byte;
wire       t88_valid, t88_done, t88_ovr, t88_idle;
wire       w_stop, w_dack, w_recon;

cmt_t88w #(.TICK_CLK(TICK_CLK), .PAY_MAX(PAY_MAX), .GAP_BYTES(GAP_BYTES)) u_t88w (
	.clk(clk), .rst_n(rst_n),
	// only while cmt_wblk is writing the body, not the whole session (see cmt_t88w)
	.active(w_recon),
	.speed_1200(speed_1200),
	// silence is counted only while the tape is moving
	.run(rec_run),
	// a capture in progress must not be cut as a gap, or it shows up as an overrun
	.cap_busy(cap_busy),
	.stop(w_stop),
	.din(cap_byte), .din_valid(cap_valid),
	.dout(t88_byte), .dout_valid(t88_valid), .dout_ack(w_dack),
	.done(t88_done), .overrun(t88_ovr), .idle(t88_idle)
);

// -- format detection, reusing cmt_fmt
// The detector sees only the recorder's own reads (the probe of block 0), not playback reads.
wire is_t88;
wire probe_start;
// Rearmed on every probe read, not only on mount: if the single read after mount never
// reached the detector, the image would otherwise be taken as .cmt and recording refused
// for good.
cmt_fmt u_fmt (
	.clk(clk), .rst_n(rst_n),
	.mounted(mounted | probe_start), .sd_buff_addr(sd_buff_addr),
	// Only data read while the recorder owns SD. Otherwise a block streaming for playback
	// when recording is enabled would close the detector's 8-byte window, and a valid
	// .t88 would be refused as "not a .t88 image".
	.sd_buff_dout(sd_buff_dout), .sd_buff_wr(sd_buff_wr & own_rec),
	.is_t88(is_t88)
);

// -- .t88 bytes -> SD blocks
wire [31:0] r_lba;
wire        r_rd, r_wr, r_busy;
wire        r_ack;

cmt_wblk #(.FLUSH_CLK(FLUSH_CLK)) u_wblk (
	.clk(clk), .rst_n(rst_n),
	.active(rec_active),
	.run(rec_run),   // motor; dropping it triggers the flush
	.src_done(t88_done), .src_idle(t88_idle),
	.src_ovr(t88_ovr),
	.rec_enable(rec_enable),
	.is_t88(is_t88), .mode_ok(mode_ok),
	.mounted(mounted), .img_size(img_size), .img_ro(img_ro),
	.din(t88_byte), .din_valid(t88_valid), .din_ack(w_dack),
	.rec_on(w_recon),
	.sd_lba(r_lba), .sd_rd(r_rd), .sd_wr(r_wr), .sd_ack(r_ack),
	.sd_buff_addr(sd_buff_addr), .sd_buff_din(sd_buff_din),
	.busy(r_busy),
	.probe_start(probe_start),
	.stop_src(w_stop),
	.ev_req(ev_req), .ev_code(ev_code)
);

// -- SD port owner, changed only between transfers
// Taken when the recorder has work, playback is not requesting and the previous ack has
// dropped; given back once the recorder is idle, under the same conditions.
reg own_rec = 1'b0;
always @(posedge clk) begin
	if (!rst_n) own_rec <= 1'b0;
	else if (!own_rec) begin
		if (r_busy && !play_rd && !sd_ack) own_rec <= 1'b1;
	end else begin
		if (!r_busy && !r_rd && !r_wr && !sd_ack) own_rec <= 1'b0;
	end
end

// The LBA follows whichever side issued the request, and is not cleared by reset. For a
// write it has already accepted, cmt_arb itself freezes the address on reset (drain_lba),
// so the host still writes the right sector; own_lba keeps this module's own sd_lba port
// pointing at the recorder after own_rec returns to 0. cmt_wblk keeps sd_lba across reset
// as well.
// Latched on a request that actually goes out, not on r_rd: the recorder raises r_rd for
// its probe read even when it does not own the port.
reg own_lba = 1'b0;      // 1 = recorder's LBA, 0 = playback's; not reset
always @(posedge clk) begin
	if      ( own_rec && (r_rd | r_wr)) own_lba <= 1'b1;
	else if (!own_rec && play_rd)       own_lba <= 1'b0;
end
// Switch the LBA in the same clock as the request. own_lba is registered and lags by one
// clock, so on the clock the owner changes, use the side that is requesting now.
wire req_now = own_rec ? (r_rd | r_wr) : play_rd;
assign sd_lba   = (req_now ? own_rec : own_lba) ? r_lba : play_lba;
assign sd_rd    = own_rec ? r_rd  : play_rd;
assign sd_wr    = own_rec ? r_wr  : 1'b0;
assign play_ack = own_rec ? 1'b0  : sd_ack;
assign r_ack    = own_rec ? sd_ack : 1'b0;

endmodule
