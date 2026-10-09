//============================================================================
//  PC8801SR - cassette (CMT) image block writer
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
// cmt_wblk - writes the bytes from cmt_t88w to the mounted image in 512-byte blocks
//
// It knows nothing of the .t88 format (that is cmt_t88w); it only handles the SD transfer.
//
// SD handshake:
//   - sd_lba is written only when a request is issued, never on an ack edge, so a stale
//     ack from an earlier session cannot move the position of a new recording
//   - sd_ack is not "done": it rises when the host takes the request and stays high while
//     the block is transferred. sd_wr is dropped on the rising edge; the buffer is
//     released on the falling edge
//   - the next request waits until ack has been low for at least one clock
//   - capacity is checked in one place only, when a block is handed over
//   - a mount during a recording is fatal: the host swaps the image before it reports
//     the mount
// The host silently drops writes past the end of the image, so only the core can notice
// that the image is full.
//
// Format check: a mount does not tell the extension, so the first block is read and
// cmt_fmt looks at the header. A .cmt image is playback only and is refused with a
// message; recording starts at the beginning of the image and would overwrite it.
//
// Flush: a short program does not fill a 512-byte block, so nothing would reach the card
// until recording is switched off, and SAVE would print Ok for data that is lost at power
// off. When the motor has been off for FLUSH_CLK clocks, the current block is padded with
// zeros and written without advancing to the next block. The zeros read as an END tag
// (tag 0x0000), so the image is always a complete .t88. Later bytes overwrite the same
// block. The session stays open; closing it would restart from block 0.
//
module cmt_wblk #(
	parameter int FLUSH_CLK = 20000000   // about 1 s at 20 MHz
) (
	input             clk,
	input             rst_n,

	// recording session (cmt_deck.rec_active)
	input             active,
	// motor on (cmt_deck.rec_run). The flush is triggered by the motor stopping, which
	// happens at the end of each SAVE. Triggering on "no bytes" would also fire during
	// back-pressure or between records and steal bandwidth from a slow host.
	input             run,
	input             src_done,      // cmt_t88w has sent END
	// cmt_t88w is between records with dout_valid low (records may still be queued). Without it a flush
	// under back-pressure writes a copy cut in the middle of a DATA record, and a byte
	// taken on the trigger clock would be lost.
	input             src_idle,
	// cmt_t88w overran. Reported here; otherwise its finalize would look like a clean
	// end and a truncated recording would be reported as saved.
	input             src_ovr,
	// OSD record switch (unlike active, it ignores the motor); triggers the format probe
	input             rec_enable,

	// format check, from cmt_fmt
	input             is_t88,
	// the 8251 clock divisor is one this core supports (cmt_mode_ok in the top level).
	// Otherwise SAVE would write an empty .t88 and report it as saved.
	input             mode_ok,

	// mount; img_ro and img_size are only valid on the pulse, so they are latched here
	input             mounted,
	input      [63:0] img_size,
	input             img_ro,

	// bytes from cmt_t88w
	input       [7:0] din,
	input             din_valid,
	output            din_ack,
	// enable for cmt_t88w: high only while the bytes can be written out. Running it on
	// rec_active alone left a stray header that leaked into the next recording after a
	// refusal, and let it start a new session over END after the image filled up.
	output            rec_on,

	// SD, reaching the host through the cmt_arb arbiter
	output reg [31:0] sd_lba,
	output reg        sd_rd,
	output reg        sd_wr,
	input             sd_ack,
	input       [8:0] sd_buff_addr,
	output      [7:0] sd_buff_din,

	output            busy,
	// one clock when the probe starts; re-arms cmt_fmt so that one missed read does not
	// leave the image marked as .cmt for good
	output reg        probe_start,
	// tells cmt_t88w to finish (image full or aborted); every cause goes through the same finalize
	output reg        stop_src,
	// status message, one-clock pulse; the top level maps codes to text
	output reg        ev_req,
	output reg  [3:0] ev_code
);

localparam [3:0] EV_REC     = 4'd0,   // started
                 EV_SAVED   = 4'd1,   // finished writing
                 EV_OVERRUN = 4'd2,   // the host did not take a block in time
                 EV_FULL    = 4'd3,   // image is full
                 EV_REMOUNT = 4'd4,   // image changed during recording
                 EV_NOFILE  = 4'd5,   // nothing mounted
                 EV_RO      = 4'd6,   // read only
                 EV_NOTT88  = 4'd7,   // a .cmt is mounted; only .t88 can be recorded to
                 EV_SMALL   = 4'd8,   // image too small
                 EV_BAUD    = 4'd9;   // unsupported 8251 divisor (only x16)

localparam S_IDLE = 3'd0, S_PRB_REQ = 3'd1, S_PRB_WAIT = 3'd2,
           S_REC  = 3'd3, S_PAD     = 3'd4, S_DRAIN    = 3'd5,
           S_ZPAD = 3'd6;   // fills the next block with zeros (END straddles blocks)

// two 512-byte buffers: one is filled while the other is written out
reg [7:0] mem [0:1023];

reg [2:0]  st = S_IDLE;
reg        wface = 0, sface = 0, pend_face = 0;
reg [8:0]  wptr  = 0;
reg [31:0] face_i = 0;      // index of the next block to hand over; capacity is checked on it
// flush state
reg [31:0] idle_c    = 0;   // clocks with the motor off
reg [8:0]  keep_ptr  = 0;   // write position before padding, restored afterwards
reg        flushing  = 0;   // padding for a flush
reg        flush_send = 0;  // this write is a flush: face_i does not advance
// A flush write is in flight. It blocks a new flush and the second stage, but bytes are
// still taken into the buffer: take does not look at it, and must not, or a slow host
// makes cmt_t88w overrun.
reg        flush_busy = 0;
// Bytes have arrived since the last flush. Using wptr != 0 instead would skip the flush
// right after a block fills (no END, so old data reads as a continuation) and rewrite
// the same block every second when nothing changed. With wptr == 0 the flush writes an
// all-zero block, which puts END there.
reg        dirty = 0;
// END is 4 bytes. With fewer than 4 left in the block, the next block is zeroed too
// so that END spans the boundary.
reg        flush2 = 0;      // second stage: zero the next block
reg        flush_next = 0;  // this write goes to face_i + 1
reg [8:0]  zptr = 0;        // fill position for the zero block
reg        send_pend = 0, send_busy = 0, ack_d = 0;
reg        last_face = 0;   // the last partial block has not been handed over yet

reg [31:0] blocks = 0;      // image size in blocks
reg        ro     = 1;      // do not start until something writable is mounted
reg        have   = 0;      // something is mounted
reg        probed = 0;      // the first block has been read
reg        reason_done = 0; // the reason for this stop has been reported
reg        act_d = 0;
// A start is held as a request rather than taken as an edge. If recording is switched on
// on the same clock as the motor (as when booting from a .mgl), the probe branch wins and
// the edge would be lost, so recording would silently not start.
reg        start_pend = 0;

// Blocks kept in reserve. After stop, cmt_t88w may still send a partly sent DATA (528),
// a buffered block (511), a last DATA (528), MARK (12) and END (4): about 1583 bytes,
// over three blocks. Too small a reserve drops the block holding END.
// Revisit if PAY_MAX in cmt_t88w.sv changes.
localparam [31:0] RESERVE = 32'd4;
// smallest image accepted; must be larger than RESERVE
localparam [31:0] MIN_BLOCKS = 32'd8;

reg [7:0] dout_r;
assign sd_buff_din = dout_r;
assign busy = (st != S_IDLE);

// The buffer is released on the falling edge of ack. Release is evaluated first, so that
// a release and the other buffer filling on the same clock do not look like an overrun.
wire release_now = ack_d & ~sd_ack;
wire busy_now    = send_busy & ~release_now;
// The next request waits until ack has been low for a clock. In practice ~send_busy and
// ~sd_wr already block it; the ack terms are kept in case the block size or rate changes.
wire can_issue = send_pend & ~send_busy & ~sd_wr & ~sd_ack & ~ack_d;

wire in_rec = (st == S_REC);
// Keep rec_on high during a flush too. Dropping it for the S_PAD detour made cmt_t88w
// think the session had ended and restart it. Back-pressure is applied through take.
wire in_flush = flushing | flush_busy | (st == S_ZPAD) | flush2;
assign rec_on  = in_rec | in_flush;

// The other buffer is free. sd_ack is not checked: during S_REC it is only high for our
// own write, and send_busy is set then.
wire face_free = ~send_pend & ~busy_now;
// Back-pressure: the byte that closes a buffer waits until the other one is free.
// A DATA record is 528 bytes and a block 512, so a full record moves 16 bytes further
// into the block each time, and about once in 32 such records one record holds two block
// boundaries 512 clocks apart (MARK and short records shift the phase); the host cannot
// be expected to answer that fast.
// cmt_t88w can buffer two blocks of payload (about 9 s at 1200 baud), so waiting is safe;
// overrun is detected there.
// Bytes are still taken during a flush write. The flushed block is only a snapshot and
// is rewritten later, since face_i does not advance. This assumes the next SAVE does not
// start within the flush write; a real SAVE sends about 2 s of carrier first.
wire take = in_rec & ((wptr != 9'd511) | face_free);
assign din_ack = take;

// write port (recording) and read port (host) in separate blocks to infer a dual-port RAM
reg        mem_we;
reg [9:0]  mem_wa;
reg [7:0]  mem_wd;
always @(posedge clk) if (mem_we) mem[mem_wa] <= mem_wd;
always @(posedge clk) dout_r <= mem[{sface, sd_buff_addr}];

always @(posedge clk) begin
	reg [3:0] refuse;
	reg       ok;

	ev_req      <= 1'b0;
	probe_start <= 1'b0;
	mem_we      <= 1'b0;
	ack_d  <= sd_ack;
	act_d  <= active;

	if (!rst_n) begin
		// sd_lba and sface are kept. sd_wr and send_busy are cleared: on reset cmt_arb drains
		// a request it has already granted to completion but does not pass its ack back, and
		// drops one it has not granted; either way no ack comes here, and send_busy would
		// block recording for good. Reset also forgets the mounted image (have, ro), so the
		// image has to be selected again before recording.
		st <= S_IDLE; sd_rd <= 0; sd_wr <= 0; send_pend <= 0; send_busy <= 0;
		start_pend <= 0; probe_start <= 0;
		stop_src <= 0; last_face <= 0; probed <= 0; have <= 0; ro <= 1;
		wface <= 0; wptr <= 0; face_i <= 0;
		idle_c <= 0; keep_ptr <= 0; flushing <= 0; flush_send <= 0; flush_busy <= 0; dirty <= 0; flush2 <= 0; flush_next <= 0; zptr <= 0;
		reason_done <= 0;
	end else begin
		// hold the start request; drop it when recording is switched off
		if (active && !act_d) start_pend <= 1'b1;
		else if (!active)     start_pend <= 1'b0;

		// cmt_t88w runs on rec_on, so switching recording off reaches it only through
		// stop_src. Checked over the whole flush as well, or switching off then would leave
		// the session open. stop_src is held until S_IDLE.
		if (!active && act_d && (st == S_REC || in_flush)) stop_src <= 1'b1;

		// Probe again at the start of each session (when SAVE is typed). On boot the record
		// switch comes on before the mount, and a probe tied only to the mount could miss.
		// Bytes that arrive during the probe are dropped. The 512-byte read itself takes tens
		// of microseconds against 9 ms per byte at 1200 baud; waiting for the host (or for a
		// disk transfer ahead of it in cmt_arb) is not bounded, but SAVE sends about two
		// seconds of carrier before the first byte. A much slower host would need the
		// capture window widened to cover the probe.
		if (active && !act_d) probed <= 1'b0;

		// SD handshake, the same for reads and writes
		if (~ack_d & sd_ack) begin sd_wr <= 1'b0; sd_rd <= 1'b0; end
		if (release_now) send_busy <= 1'b0;
		// flush write finished
		if (flush_busy && !send_pend && !send_busy && !sd_wr) flush_busy <= 1'b0;

		// Second flush stage, started as soon as the first one is written so the file never
		// shows the next block as a continuation. Not on the clock a buffer fills, or the
		// buffer just handed over would be zeroed; S_REC drops flush2 in that case.
		if (flush2 && st == S_REC && !flush_busy && !send_pend && !send_busy && !sd_wr
		 && !(din_valid && take && wptr == 9'd511)) begin
			flush2 <= 1'b0;
			zptr   <= 0;
			st     <= S_ZPAD;         // zero the unused buffer, then write it
		end

		// mount; fatal during a recording, since later bytes would go to another file.
		// A request already issued cannot be withdrawn; only new ones are stopped.
		if (mounted) begin
			// cancel a pending start; the user restarts with Off then On
			start_pend <= 1'b0;
			// clear the flush flags so rec_on drops and the next session does not reuse
			// the block; a write in flight still completes
			flushing   <= 1'b0;
			flush_send <= 1'b0;
			flush_busy <= 1'b0;
			flush2      <= 1'b0;
			flush_next  <= 1'b0;
			have   <= (img_size != 0);
			// rounded down (playback rounds up): a partial last block is not written to
			blocks <= img_size[40:9];
			ro     <= img_ro;
			probed <= 1'b0;
			// report a start request canceled by the mount
			if (st == S_IDLE && start_pend) begin
				ev_req  <= 1'b1;
				ev_code <= EV_REMOUNT;
			end
			if (st != S_IDLE) begin
				st        <= S_IDLE;
				last_face <= 1'b0;
				send_pend <= 1'b0;
				stop_src  <= 1'b1;
				ev_req    <= 1'b1;
				ev_code   <= EV_REMOUNT;
				reason_done <= 1'b1;
				// A request in flight is not withdrawn: the host may already have taken it
				// without acking. Withdrawing it lets cmt_arb release ownership, and the
				// late 512 bytes would be written into the disk sector buffer.
			end
		end else begin
			// issue a request; the block index and sd_lba change only here
			if (can_issue) begin
				send_pend <= 1'b0;
				sd_wr     <= 1'b1;
				send_busy <= 1'b1;
				sface     <= pend_face;
				// the second flush stage goes to the next block (END straddles)
				sd_lba    <= flush_next ? (face_i + 32'd1) : face_i;
				// a flush write does not advance face_i, so the same block is rewritten
				if (flush_send) begin flush_send <= 1'b0; flush_next <= 1'b0; end
				else            face_i     <= face_i + 1'd1;
				// The single capacity check. A flush rewrites the same block and uses no
				// capacity, so it is excluded.
				if (!flush_send && st == S_REC && (face_i + 1'd1 + RESERVE) >= blocks) begin
					stop_src <= 1'b1;
					if (!reason_done) begin
						ev_req <= 1'b1; ev_code <= EV_FULL; reason_done <= 1'b1;
					end
				end
			end

			case (st)
			// idle; also starts the format probe
			S_IDLE: begin
				stop_src <= 1'b0;
				// recording switched on with an image mounted: read the first block
				if (rec_enable && have && !probed && !send_busy && !sd_ack && !ack_d)
					st <= S_PRB_REQ;
				// Session start, after the probe branch. The probe can be held off by a write
				// still in flight, so the start waits for it (probed), unless nothing is
				// mounted. active is checked too: start_pend is cleared non-blocking, and
				// entering S_REC on the clock the switch goes off would lose the stop edge.
				else if (start_pend && active && (probed || !have)) begin
					start_pend <= 1'b0;
					ok = 1'b1; refuse = EV_NOFILE;
					if (!have)                    begin ok = 1'b0; refuse = EV_NOFILE; end
					else if (ro)                  begin ok = 1'b0; refuse = EV_RO;     end
					else if (blocks < MIN_BLOCKS) begin ok = 1'b0; refuse = EV_SMALL;  end
					else if (!is_t88)             begin ok = 1'b0; refuse = EV_NOTT88; end
					else if (!mode_ok)            begin ok = 1'b0; refuse = EV_BAUD;   end
					ev_req <= 1'b1;
					if (ok) begin
						// clear dirty from the previous session, or a session with no bytes
						// would flush a zero block over the start of the image
						dirty     <= 1'b0;
						idle_c    <= 0;
						// reset the position so a second session does not append to the first
						face_i    <= 0;
						wptr      <= 0;
						last_face <= 1'b0;
						reason_done <= 1'b0;
						// Drop only a block not yet handed over. A request in flight is left
						// to the handshake; can_issue keeps the order.
						send_pend <= 1'b0;
						// do not start in the buffer the host may still be reading
						wface   <= (send_busy | sd_ack) ? ~sface : 1'b0;
						ev_code <= EV_REC;
						st      <= S_REC;
					end else begin
						ev_code  <= refuse;
						stop_src <= 1'b1;      // let cmt_t88w close without running
					end
				end
			end

			// read the first block; cmt_fmt takes the data
			S_PRB_REQ: begin
				// Wait for a read in flight to finish. After a remount during a probe, the old
				// reply would otherwise decide the format of the new image.
				if (!sd_rd && !sd_ack && !ack_d) begin
					sd_lba      <= 32'd0;
					sd_rd       <= 1'b1;
					// re-arm the format check just before the read
					probe_start <= 1'b1;
					st          <= S_PRB_WAIT;
				end
			end
			S_PRB_WAIT: begin
				if (!sd_rd && !sd_ack) begin
					probed <= 1'b1;
					st     <= S_IDLE;
				end
			end

			// recording
			S_REC: begin
				// only when take is high; otherwise the held byte would land in the buffer
				// the host is reading
				if (din_valid && take) begin
					dirty  <= 1'b1;
					mem_we <= 1'b1;
					mem_wa <= {wface, wptr};
					mem_wd <= din;
					if (wptr == 9'd511) begin
						// face_free is true here (take guarantees it)
						wptr      <= 0;
						send_pend <= 1'b1;
						pend_face <= wface;
						wface     <= ~wface;
						// face_i advances with this block, so a pending second stage would
						// land two blocks ahead; drop it, the next flush redoes it
						flush2    <= 1'b0;
					end else wptr <= wptr + 1'd1;
				end
				// an overrun in cmt_t88w is reported like one here
				if (src_ovr && !reason_done) begin
					stop_src <= 1'b1;
					ev_req   <= 1'b1; ev_code <= EV_OVERRUN; reason_done <= 1'b1;
				end
				// flush after the motor has been off for FLUSH_CLK clocks
				if (run) idle_c <= 0;
				else if (idle_c != FLUSH_CLK[31:0]) idle_c <= idle_c + 32'd1;
				// only once cmt_t88w is idle (see src_idle) and the SD side is clear
				else if (dirty && src_idle && !flush_busy && !send_pend && !send_busy && !sd_wr) begin
					keep_ptr    <= wptr;
					flushing    <= 1'b1;
					// whether END needs the next block is decided after padding (keep_ptr)
					st          <= S_PAD;
				end
				// cmt_t88w has sent END: pad the partial block and write it
				if (src_done) begin
					if (wptr != 0) st <= S_PAD;
					else begin last_face <= 1'b0; st <= S_DRAIN; end
				end
			end

			// Zero the next block. END is tag (2) + len (2); with fewer than 4 bytes left in
			// the block it spans into the next one. face_i does not advance, so later bytes
			// overwrite the zeros. (Closing the block and advancing instead would leave the
			// trailing zeros read as END, hiding anything recorded after it.)
			S_ZPAD: begin
				mem_we <= 1'b1;
				mem_wa <= {~wface, zptr};
				mem_wd <= 8'h00;
				if (zptr == 9'd511) begin
					zptr       <= 0;
					flush_next <= 1'b1;   // address is face_i + 1
					flush_send <= 1'b1;   // face_i does not advance
					flush_busy <= 1'b1;
					send_pend  <= 1'b1;
					pend_face  <= ~wface;
					st         <= S_REC;
				end else zptr <= zptr + 1'd1;
			end

			// Pad the rest of a partial block with zeros. The host always writes 512 bytes,
			// so otherwise old buffer contents would end up after END in the file.
			S_PAD: begin
				mem_we <= 1'b1;
				mem_wa <= {wface, wptr};
				mem_wd <= 8'h00;
				if (wptr == 9'd511) begin
					// A flush returns to recording without advancing face_i, and restores the
					// write position so later bytes overwrite the padding.
					if (flushing) begin
						flushing   <= 1'b0;
						dirty      <= 1'b0;
						flush_send <= 1'b1;   // face_i does not advance
						flush_busy <= 1'b1;
						send_pend  <= 1'b1;
						pend_face  <= wface;  // same buffer
						wptr       <= keep_ptr;
						idle_c     <= 0;
						// END does not fit: zero the next block as well
						flush2     <= (keep_ptr > 9'd508);
						st         <= S_REC;
					end else begin
						wptr      <= 0;
						last_face <= 1'b1;
						st        <= S_DRAIN;
					end
				end else wptr <= wptr + 1'd1;
			end

			// write out what is left
			S_DRAIN: begin
				if (last_face) begin
					// wait for the previous block, so blocks are written in order
					if (!send_pend && !send_busy && !sd_wr) begin
						last_face <= 1'b0;
						if (face_i >= blocks) begin
							if (!reason_done) begin
								ev_req <= 1'b1; ev_code <= EV_FULL; reason_done <= 1'b1;
							end
						end else begin
							send_pend <= 1'b1;
							pend_face <= wface;
						end
					end
				end else if (!send_pend && !send_busy && !sd_wr) begin
					st      <= S_IDLE;
					// Clear the flush flags. Switching off during a flush write lets finalize
					// take over st before flush2 is cleared in S_REC, which would leave rec_on
					// stuck high.
					flush2     <= 1'b0;
					flush_next <= 1'b0;
					// report completion, but not for a session that wrote no blocks
					if (face_i != 0) begin
						ev_req  <= 1'b1;
						ev_code <= EV_SAVED;
					end
				end
			end

			default: st <= S_IDLE;
			endcase
		end
	end
end

endmodule
