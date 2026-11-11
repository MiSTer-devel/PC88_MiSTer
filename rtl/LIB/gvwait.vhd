-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Adds wait states to CPU reads and writes of graphic VRAM.
--A real FH waits longer while the screen is drawn than in the vertical
--retrace: 3.947 states on average at 8MHz in 24kHz timing and 3.662 in 15kHz
--timing. The count follows 4 (eight times),6 drawn and 2 (nine times),0 in
--the retrace at 8MHz, each with its own step, one step per access. At 4MHz it
--is 2 drawn and none in the retrace, as measured part by part.
--Whether an access counts as drawn or retrace is taken from VRTC when it
--starts. The same rule is used in 31kHz timing. At 8MHz an odd count can be
--lost to the SDRAM slot, so only even counts are used there.
--These counts come on top of the wait of a main RAM access (1 at 8MHz, none
--at 4MHz), and the sum is the whole wait of the access: every ce_f sample of
--the access is counted, also while another wait holds the CPU, so the access
--takes the larger of the two. On a real FH a write to graphic VRAM waits as
--long as a read, while the SDRAM of the core takes one more state on a write.
--In 24kHz timing, writes that follow each other closely wait more while the
--screen is drawn. GVWQ gives that part: while QWAIT is high, no sample is
--counted, so the write waits and the two waits add up. QWAIT can only rise
--before the first wait is taken there, as it is decided when the write
--starts. An access with no wait to take (in the retrace at 4MHz) does not
--wait for QWAIT; there every state is a slot, so the oldest write goes out
--as soon as it is minage states old.
--The opcode fetch wait of M1WAIT is the exception: those samples are not
--counted, so it still adds to these waits as before.
--Once the CPU has seen WAIT_n high in an access, the wait stays off until the
--access ends, even if FAST or en changes.
--In 15kHz timing at 4MHz the FH waits one more state (3 instead of 2) on some
--drawn accesses. The waits measured over many access intervals fit a model
--where an access waits more when it starts in an 8% window of the 8-dot text
--clock. That clock runs on its own crystal; the length that fits best is
--2.2325 CPU states (2.2313 from the nominal crystals), so ph keeps its phase
--in CPU states (29355 of 65536 a state). Only the width of the window shows
--in the waits, not where it sits, so it is put at phase 0.
--This was measured in V2; the other modes that use these waits take the same
--rule. As ph counts ce_f, it falls behind the real text clock while GVSTRETCH
--slows the CPU in V1S and N. en is low all that time, so no wait here is taken
--then; only the phase moves.
--In 24kHz timing at 4MHz the FH also waits one more state on some drawn
--accesses, by the same kind of window on its own 8-dot text clock (1.51757 CPU
--states from the nominal crystals), 16% wide. There the window opens only on
--the lines whose graphic VRAM the screen reads, and only while the line is
--drawn (HRET low): in 200-line modes that is every other line, in 400-line
--mode every line. On a real FH the extra wait in 400-line mode is twice that
--in 200-line mode, as this gives. Which line of a pair is read does not show in
--the waits, so ln just turns over at every line.
entity GVWAIT is
port(
	SEL		:in std_logic;	-- GVRAM read or write strobe is out
	M1W		:in std_logic;	-- '1' while the M1WAIT opcode fetch wait holds the CPU
	FAST	:in std_logic;	-- '1' at 8MHz
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic;

	VRTC	:in std_logic;	-- '1' in the vertical retrace
	QWAIT	:in std_logic;	-- '1' while GVWQ holds a write back
	PH15	:in std_logic;	-- '1' in 15kHz timing: take the text clock phase
	PH24	:in std_logic;	-- '1' in 24kHz timing: the same, using the 24kHz text clock
	L200	:in std_logic;	-- '1' in 200-line modes: the screen reads every other line
	HRET	:in std_logic	-- '1' in the horizontal retrace
);
end GVWAIT;

architecture rtl of GVWAIT is
signal	kd		:integer range 0 to 8;	-- access number while drawn
signal	kr		:integer range 0 to 9;	-- access number in the retrace
signal	cnt		:integer range 0 to 7;	-- waits taken in this access
signal	target	:integer range 0 to 7;
signal	base	:integer range 0 to 1;	-- the wait of a main RAM access
signal	tgtd	:integer range 0 to 7;
signal	tgtr	:integer range 0 to 7;
signal	lsel	:std_logic;
signal	done	:std_logic;	-- the CPU has passed the wait in this access
signal	lret	:std_logic;	-- VRTC taken when the access started
signal	ret		:std_logic;
constant PHSTEP	:integer:=29355;	-- 65536/2.2325 rounded down: one CPU state
constant PHW	:integer:=5243;		-- 8% of the text clock
constant PHSTEP24:integer:=43185;	-- 65536/1.51757 rounded: one CPU state in 24kHz timing
constant PHW24	:integer:=10486;	-- 16% of the 24kHz text clock
signal	step	:integer range 0 to 65535;
signal	wid		:integer range 0 to 65535;
signal	lhret	:std_logic;
signal	ln		:std_logic;	-- turns over at every line
signal	lnrd	:std_logic;	-- the screen reads graphic VRAM on this line, and it is drawn
signal	ph		:integer range 0 to 65535;
signal	phlow	:std_logic;	-- ph is in the window (registered with ph)
signal	phhit	:std_logic;
signal	lhit	:std_logic;
signal	hit		:integer range 0 to 1;
begin
	step<=PHSTEP24 when PH24='1' else PHSTEP;
	wid<=PHW24 when PH24='1' else PHW;
	lnrd<='1' when HRET='0' and (L200='0' or ln='0') else '0';
	phhit<='1' when FAST='0' and phlow='1' and (PH15='1' or (PH24='1' and lnrd='1')) else '0';
	hit<=	1 when SEL='1' and lsel='0' and phhit='1' else
			1 when SEL='1' and lsel='1' and lhit='1' else
			0;
	tgtd<=	6 when FAST='1' and kd=8 else
			4 when FAST='1' else
			2+hit;
	tgtr<=	0 when FAST='1' and kr=9 else
			2 when FAST='1' else
			0;
	ret<=VRTC when SEL='1' and lsel='0' else lret;
	target<=tgtr+base when ret='1' else tgtd+base;
	base<=1 when FAST='1' else 0;

	process(clk,rstn)
	variable nph	:integer range 0 to 65535;
	begin
		if(rstn='0')then
			kd<=0;
			kr<=0;
			cnt<=0;
			lsel<='0';
			done<='0';
			lret<='0';
			ph<=0;
			phlow<='1';	-- 0 is in the window
			lhit<='0';
			lhret<='0';
			ln<='0';
		elsif(clk' event and clk='1')then
			lsel<=SEL;
			lhret<=HRET;
			if(HRET='1' and lhret='0')then
				ln<=not ln;
			end if;
			if(ce_f='1')then
				if(ph+step>65535)then
					nph:=ph+step-65536;
				else
					nph:=ph+step;
				end if;
				ph<=nph;
				if(nph<wid)then
					phlow<='1';
				else
					phlow<='0';
				end if;
			end if;
			if(SEL='1' and lsel='0')then
				lret<=VRTC;
				lhit<=phhit;
			end if;
			if(SEL='0')then
				cnt<=0;
				done<='0';
				if(lsel='1' and en='1')then
					if(lret='0')then
						if(kd>=8)then
							kd<=0;
						else
							kd<=kd+1;
						end if;
					else
						if(kr>=9)then
							kr<=0;
						else
							kr<=kr+1;
						end if;
					end if;
				end if;
			elsif(ce_f='1' and M1W='0')then
				if(en='1' and cnt<target and done='0')then
					if(QWAIT='0')then
						cnt<=cnt+1;
					end if;
				else
					done<='1';
				end if;
			end if;
		end if;
	end process;

	WAITn<='0' when SEL='1' and en='1' and cnt<target and done='0' else '1';

end rtl;
