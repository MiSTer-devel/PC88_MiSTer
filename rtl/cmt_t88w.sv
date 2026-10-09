//============================================================================
//  PC8801SR - .t88 writer
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
// cmt_t88w - turns recorded bytes into a .t88 image, one byte at a time
//
//   Takes the bytes from cmt_capture and emits a .t88 stream from the start.
//   It knows nothing about the SD card; grouping into blocks is the next stage's job.
//
//   Output: 24-byte magic, VERSION, then DATA and MARK records, then END
//   DATA sub-header: start_tick(u32) length_ticks(u32) data_len(u16) fmt(u16)
//   fmt 0x01CC is 1200 baud, 0x00CC is 600; one byte is 44 ticks (1200) or 88 (600)
//   a tick is 1/4800 s
//
//   Silences on the line are written as MARK records with their measured length.
//   SAVE leaves a carrier gap between the header block and the body, and the BIOS
//   fails to load a tape without it.
//
//   A DATA record holds at most PAY_MAX bytes. Its length field comes before the
//   body, so the body must be buffered first; a small record keeps the buffer
//   small. Readers join consecutive DATA records into one stream.
//
module cmt_t88w #(
	// Clocks per tick (1/4800 s). The top level passes CMT_SYSCLK_HZ/4800.
	parameter int TICK_CLK  = 4166,
	// Largest body of one DATA record, and the size of one buffer bank. Must be a power of 2.
	parameter int PAY_MAX   = 512,
	// A silence this long (in byte times) closes the DATA record and becomes a MARK.
	// The gap SAVE leaves is about 23 byte times at 1200 baud; 1 would split
	// records on small pauses between bytes.
	parameter int GAP_BYTES = 4
) (
	input             clk,
	input             rst_n,

	// High while cmt_wblk accepts output. Output is only produced inside this
	// window; when it drops, a partly sent record is discarded.
	input             active,
	input             speed_1200,   // sampled once at session start
	// Tape is moving (motor on). Silence is only counted while this is high,
	// since time with the motor off does not exist on the tape.
	input             run,
	// cmt_capture is in the middle of a frame. Closing a record waits for it so
	// the last byte lands in the same record.
	input             cap_busy,
	// Other end of session (image full, abort). Must be held high until the
	// session has closed, not pulsed, because closing may wait for cap_busy.
	input             stop,

	// captured bytes, from cmt_capture
	input       [7:0] din,
	input             din_valid,

	// .t88 bytes in order; a transfer happens on a clock where both valid and ack are high
	output      [7:0] dout,
	output reg        dout_valid,
	input             dout_ack,

	output reg        done,         // END has been sent
	// A record closed while both buffer banks were full. The session is closed
	// at once rather than continuing with missing data.
	output reg        overrun,
	// Not in the middle of a record. A copy cut here ends on a record boundary.
	output            idle
);

localparam int PAW = $clog2(PAY_MAX);          // body address width

// 24-byte magic (23 characters + NUL); the leftmost character is in the high bits.
localparam [191:0] MAGIC = {"PC-8801 Tape Image(T88)", 8'h00};

localparam S_OFF = 3'd0, S_MAGIC = 3'd1, S_TAG = 3'd2, S_PAY = 3'd3,
           S_WAIT = 3'd4, S_DONE = 3'd5;

// Header buffer: the magic (24) and record headers (up to 16) share it.
reg  [7:0] tbuf [0:23];
reg  [4:0] tlen  = 0;
reg  [4:0] eidx  = 0;

// Body buffer, two banks: one is filled while the other is sent.
// Write and read are in separate always blocks with a registered read so the
// buffer is inferred as block RAM. The read latency is hidden by addressing
// the body while the 16-byte DATA header is being sent.
reg  [7:0]   pay [0:2*PAY_MAX-1];
reg          pay_we = 0;
reg  [PAW:0] pay_wa = 0;
reg  [7:0]   pay_wd = 0;
reg  [7:0]   pay_q  = 0;
reg          wbank = 0;
reg  [PAW:0] wcnt  = 0;

reg          ebank = 0;
reg  [PAW:0] elen  = 0;
reg  [PAW:0] eptr  = 0;

// Ticks. Here a tick is TICK_CLK clocks while cmt_t88 uses TICK_CLK + 1; the
// 0.02% difference is ignored since only wait lengths are played back.
reg [31:0] tdiv = 0;
wire       tick = (tdiv == TICK_CLK - 1);

// Silence since the last byte, in ticks. Saturates at 22 bits (about 14.5 minutes),
// far longer than any pause a program leaves.
reg [21:0] idle_t = 0;
// Current position in the image, in ticks, counted in output order.
reg [31:0] pos_t = 0;

// Speed sampled at session start.
reg        spd_l = 1'b1;
// Ticks per byte: 44 (1200) or 88 (600).
wire [7:0] tpb = spd_l ? 8'd44 : 8'd88;
// Silence threshold in ticks.
wire [21:0] gap_th = 22'(GAP_BYTES) * 22'(tpb);

// Pending records
reg          sess      = 0;   // session is open
reg          gap_open  = 0;   // currently inside a silence
reg          need_ver  = 0;   // VERSION not sent yet
// no byte received yet, so nothing has been written
reg          need_magic = 0;
reg          data_pend = 0;
reg          dp_bank   = 0;
reg  [PAW:0] dp_len    = 0;
reg          mark_pend = 0;
// The pending MARK comes before the pending DATA. Needed when output is stalled
// and a gap and a following body are both queued, so they leave in order.
reg          mark_first = 0;
reg  [21:0]  mp_ticks  = 0;
reg          end_pend  = 0;

reg [2:0] st = S_OFF;

// Read address: the current byte, or the next one on the clock it is taken.
wire [PAW:0] rd_sel = (st == S_PAY && dout_valid && dout_ack) ? eptr + 1'd1 : eptr;

always @(posedge clk) if (pay_we) pay[pay_wa] <= pay_wd;
always @(posedge clk) pay_q <= pay[{ebank, rd_sel[PAW-1:0]}];

assign dout = (st == S_PAY) ? pay_q : tbuf[eidx];

// the current output byte is taken
wire adv = dout_valid & dout_ack;

// A body bank is being sent (including its header). Used to catch the fill
// side wrapping onto that bank while output is stalled.
wire emit_pay = (st == S_PAY) || (st == S_TAG && elen != 0);
// S_WAIT and S_OFF lie between records; pending records have not started yet.
assign idle = (st == S_WAIT) || (st == S_OFF);

// length_ticks of a DATA record; at most 512 * 88, fits in 16 bits.
wire [31:0] dlen_t = 32'(dp_len) * 32'(tpb);

integer i;

always @(posedge clk) begin
	// Order matters: (1) the fill side sets what to queue, (2) the output side
	// takes, (3) the two are reconciled into the *_pend flags.
	reg          data_set,  mark_set;
	reg          set_bank;
	reg  [PAW:0] set_len;
	reg  [21:0]  set_ticks;
	reg          data_take, mark_take;
	// a byte was received on this clock
	reg          took;

	took = 1'b0;
	data_set = 1'b0; mark_set = 1'b0;
	set_bank = wbank; set_len = wcnt; set_ticks = idle_t;
	data_take = 1'b0; mark_take = 1'b0;

	pay_we <= 1'b0;

	if (!rst_n) begin
		st <= S_OFF; sess <= 0; gap_open <= 0; need_ver <= 0; need_magic <= 0;
		data_pend <= 0; mark_pend <= 0; mark_first <= 0; end_pend <= 0;
		dout_valid <= 0; done <= 0; overrun <= 0;
		wbank <= 0; wcnt <= 0; idle_t <= 0; pos_t <= 0; tdiv <= 0;
	end else begin
		tdiv <= tick ? 32'd0 : tdiv + 32'd1;

		// (1) fill side
		if (sess && din_valid) begin
			// a silence over the threshold becomes a MARK of the measured length
			if (gap_open) begin
				mark_set  = 1'b1;
				set_ticks = idle_t;
				gap_open <= 1'b0;
			end
			pay_we <= 1'b1; pay_wa <= {wbank, wcnt[PAW-1:0]}; pay_wd <= din;
			took = 1'b1;
			// start writing on the first byte (see session start below)
			if (need_magic) begin
				need_magic <= 1'b0;
				for (i = 0; i < 24; i = i + 1) tbuf[i] <= MAGIC[191 - 8*i -: 8];
				tlen <= 5'd24;
				eidx <= 5'd0;
				elen <= 0;
				st   <= S_MAGIC;
				dout_valid <= 1'b1;
			end
			idle_t  <= 0;
			// a full bank is closed and filling moves to the other one, with no MARK
			if (wcnt + 1'd1 >= PAY_MAX[PAW:0]) begin
				data_set = 1'b1;
				set_bank = wbank;
				set_len  = PAY_MAX[PAW:0];
				wbank   <= ~wbank;
				wcnt    <= 0;
			end else wcnt <= wcnt + 1'd1;
		// Silence before the first byte is counted too: the tape is moving, and
		// real .t88 images start with a carrier rather than DATA.
		end else if (sess && run && tick) begin
			if (!(&idle_t)) idle_t <= idle_t + 1'd1;
			// close DATA when the threshold is crossed; keep counting even if the
			// bank is empty
			if (!gap_open && (idle_t + 1'd1) >= gap_th) begin
				gap_open <= 1'b1;
				if (wcnt != 0) begin
					data_set = 1'b1;
					set_bank = wbank;
					set_len  = wcnt;
					wbank   <= ~wbank;
					wcnt    <= 0;
				end
			end
		end

		// While the motor is off, close the bank being filled so it can be written
		// out; silence is not counted then, so the threshold would never close it.
		// Waits for cap_busy so the last byte of the frame is included, and counts
		// a byte received on this clock.
		if (sess && !run && !cap_busy && (wcnt != 0 || took) && !data_set) begin
			data_set = 1'b1;
			set_bank = wbank;
			set_len  = took ? (wcnt + 1'd1) : wcnt;
			wbank   <= ~wbank;
			wcnt    <= 0;
		end

		// End of session (recording off, image full, overrun). All causes take
		// the same path. It waits for cap_busy so the last byte is not lost,
		// except on overrun, where waiting would lose more.
		if (sess && (!active || stop || overrun) && (!cap_busy || overrun)) begin
			sess <= 1'b0;
			// close the remaining body, including a byte received on this clock
			if (took || wcnt != 0) begin
				data_set = 1'b1;
				set_bank = wbank;
				set_len  = took ? (wcnt + 1'd1) : wcnt;
				wcnt    <= 0;
			end
			// A session that received no byte closes without writing anything,
			// but still raises done so cmt_wblk can finish.
			if (need_magic && !took) begin
				need_magic <= 1'b0;
				done       <= 1'b1;
				st         <= S_DONE;
			end
			// Drop a pending MARK only if no body follows it: neither one closed
			// here nor one already queued behind it.
			if (!(data_set || (mark_first && data_pend))) mark_pend <= 1'b0;
			if (!need_magic || took) end_pend <= 1'b1;
		end

		// (2) output side
		case (st)
		S_OFF:  ;                       // do not touch dout_valid here (see above)
		S_DONE: ;

		S_MAGIC, S_TAG: begin
			if (adv) begin
				if (eidx + 1'd1 >= tlen) begin
					if (st == S_TAG && elen != 0) begin
						st   <= S_PAY;          // a DATA header is followed by its body
					end else begin
						dout_valid <= 1'b0;
						st <= S_WAIT;
					end
				end else eidx <= eidx + 1'd1;
			end
		end

		S_PAY: begin
			if (adv) begin
				if (eptr + 1'd1 >= elen) begin
					dout_valid <= 1'b0;
					st <= S_WAIT;
				end else eptr <= eptr + 1'd1;
			end
		end

		S_WAIT: begin
			// Pick the next record. Priority is VERSION, DATA, MARK, END, except
			// that a MARK queued before the pending DATA goes first.
			if (need_ver) begin
				need_ver <= 1'b0;
				tbuf[0] <= 8'h01; tbuf[1] <= 8'h00;   // tag = VERSION
				tbuf[2] <= 8'h02; tbuf[3] <= 8'h00;   // len = 2
				tbuf[4] <= 8'h00; tbuf[5] <= 8'h01;   // 0x0100
				tlen <= 5'd6; eidx <= 0; elen <= 0;
				dout_valid <= 1'b1; st <= S_TAG;
			end else if (data_pend && !(mark_pend && mark_first)) begin
				// DATA: 16-byte header (tag, len, 12-byte sub-header); len is 12 + body
				tbuf[0]  <= 8'h01; tbuf[1] <= 8'h01;                      // tag = DATA
				tbuf[2]  <= 8'(32'(dp_len) + 12);
				tbuf[3]  <= 8'((32'(dp_len) + 12) >> 8);
				tbuf[4]  <= pos_t[7:0];    tbuf[5]  <= pos_t[15:8];       // start_tick
				tbuf[6]  <= pos_t[23:16];  tbuf[7]  <= pos_t[31:24];
				tbuf[8]  <= dlen_t[7:0];   tbuf[9]  <= dlen_t[15:8];      // length_ticks
				tbuf[10] <= dlen_t[23:16]; tbuf[11] <= dlen_t[31:24];
				tbuf[12] <= 8'(dp_len);    tbuf[13] <= 8'(32'(dp_len) >> 8);   // data_len
				tbuf[14] <= 8'hCC;                                         // fmt
				tbuf[15] <= spd_l ? 8'h01 : 8'h00;
				tlen  <= 5'd16; eidx <= 0;
				// eptr is reset here, not when the body starts, so the registered
				// read has the first body byte ready after the header.
				ebank <= dp_bank; elen <= dp_len; eptr <= 0;
				pos_t <= pos_t + dlen_t;
				data_take = 1'b1;
				dout_valid <= 1'b1; st <= S_TAG;
			end else if (mark_pend) begin
				// MARK: tag, len, start_tick, length_ticks
				tbuf[0] <= 8'h03; tbuf[1] <= 8'h01;   // tag = MARK
				tbuf[2] <= 8'h08; tbuf[3] <= 8'h00;   // len = 8
				tbuf[4] <= pos_t[7:0];    tbuf[5]  <= pos_t[15:8];
				tbuf[6] <= pos_t[23:16];  tbuf[7]  <= pos_t[31:24];
				tbuf[8] <= mp_ticks[7:0]; tbuf[9]  <= mp_ticks[15:8];
				tbuf[10] <= {2'b0, mp_ticks[21:16]}; tbuf[11] <= 8'h00;
				tlen <= 5'd12; eidx <= 0; elen <= 0;
				pos_t <= pos_t + {10'd0, mp_ticks};
				mark_take = 1'b1;
				dout_valid <= 1'b1; st <= S_TAG;
			end else if (end_pend) begin
				tbuf[0] <= 8'h00; tbuf[1] <= 8'h00;   // tag = END
				tbuf[2] <= 8'h00; tbuf[3] <= 8'h00;   // len = 0
				tlen <= 5'd4; eidx <= 0; elen <= 0;
				end_pend <= 1'b0;
				dout_valid <= 1'b1; st <= S_TAG;
			end else if (!sess && !end_pend) begin
				// END has been sent
				done <= 1'b1;
				st   <= S_DONE;
			end
		end

		default: begin st <= S_OFF; dout_valid <= 1'b0; end
		endcase

		// (3) reconcile; queueing and taking may happen on the same clock
		if (data_set) begin
			// Overrun when a closed bank cannot be queued, or when the fill side
			// would wrap onto the bank that is being sent or is about to be sent.
			// With only two banks, the next bank to fill is the other one from the
			// bank just closed. The last term is conservative and may flag a case
			// that would not have corrupted data.
			if ((data_pend && !data_take)
			 || (emit_pay  && (ebank   != set_bank))
			 || (data_take && (dp_bank != set_bank)))
				overrun <= 1'b1;
			// Never overwrite a queued bank; drop the newer one instead, so the
			// image stays a contiguous run from the start and only loses its tail.
			if (!data_pend || data_take) begin
				data_pend <= 1'b1; dp_bank <= set_bank; dp_len <= set_len;
			end
		end else if (data_take) data_pend <= 1'b0;

		if (mark_set) begin
			if (mark_pend && !mark_take) overrun <= 1'b1;
			mark_pend <= 1'b1; mp_ticks <= set_ticks;
			// with no body waiting, this gap comes first
			mark_first <= !(data_pend && !data_take);
		end else if (mark_take) begin
			mark_pend <= 1'b0; mark_first <= 1'b0;
		// Once the body queued before the gap is taken, the gap comes first.
		// While mark_first is set S_WAIT does not take DATA, so any data_take here
		// is the body ahead of the gap.
		end else if (data_take && mark_pend) begin
			mark_first <= 1'b1;
		end

		// done and overrun stay high only while the window is open, so the
		// next session does not see the previous result.
		if (!active) begin done <= 1'b0; overrun <= 1'b0; end

		// The window closed, so a partly sent record will never be received.
		// Discard it, or it would appear at the start of the next image.
		if (!active && !sess && st != S_OFF && st != S_DONE) begin
			st         <= S_OFF;
			dout_valid <= 1'b0;
			data_pend  <= 1'b0;
			mark_pend  <= 1'b0;
			mark_first <= 1'b0;
			end_pend   <= 1'b0;
		end

		// Session start. Placed last so its st and dout_valid win.
		// !stop prevents a restart right after END while the window is still
		// open after the image filled up.
		if (active && !stop && !sess && !data_pend && !mark_pend && !end_pend) begin
			sess     <= 1'b1;
			spd_l    <= speed_1200;
			gap_open <= 1'b0;
			wbank    <= 1'b0;
			wcnt     <= 0;
			idle_t   <= 0;
			pos_t    <= 0;
			done     <= 1'b0;
			overrun  <= 1'b0;
			need_ver <= 1'b1;
			// Nothing is written until the first byte arrives. The motor also runs
			// for LOAD, which sends nothing on TxD; writing a header at once would
			// overwrite a saved image with an empty one.
			need_magic <= 1'b1;
			st   <= S_OFF;
			dout_valid <= 1'b0;
		end
	end
end

endmodule
