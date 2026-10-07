-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Adds wait states to CPU reads and writes of graphic VRAM.
--A real FH waits longer while the screen is drawn than in the vertical
--retrace: 3.947 states on average at 8MHz and 1.770 at 4MHz in 24kHz timing,
--3.662 and 1.628 in 15kHz timing. The count follows 4 (eight times),6 drawn
--and 2 (nine times),0 in the retrace at 8MHz, and 2 (ten times),1 drawn and
--1,1,0 in the retrace at 4MHz, each with its own step, one step per access.
--Whether an access counts as drawn or retrace is taken from VRTC when it
--starts. The same rule is used in 31kHz timing. At 8MHz an odd count can be
--lost to the SDRAM slot, so only even counts are used there.
--Only ce_f samples where no other wait holds the CPU are counted, so these
--waits add to the others. Once the CPU has seen WAIT_n high in an access, the
--wait stays off until the access ends, even if FAST or en changes.
entity GVWAIT is
port(
	SEL		:in std_logic;	-- GVRAM read or write strobe is out
	OTHERWAIT	:in std_logic;	-- '1' while any other wait holds the CPU
	FAST	:in std_logic;	-- '1' at 8MHz
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic;

	VRTC	:in std_logic	-- '1' in the vertical retrace
);
end GVWAIT;

architecture rtl of GVWAIT is
signal	kd		:integer range 0 to 10;	-- access number while drawn
signal	kr		:integer range 0 to 9;	-- access number in the retrace
signal	cnt		:integer range 0 to 7;	-- waits taken in this access
signal	target	:integer range 0 to 7;
signal	tgtd	:integer range 0 to 7;
signal	tgtr	:integer range 0 to 7;
signal	lsel	:std_logic;
signal	done	:std_logic;	-- the CPU has passed the wait in this access
signal	lret	:std_logic;	-- VRTC taken when the access started
signal	ret		:std_logic;
begin
	tgtd<=	6 when FAST='1' and kd=8 else
			4 when FAST='1' else
			1 when kd=10 else
			2;
	tgtr<=	0 when FAST='1' and kr=9 else
			2 when FAST='1' else
			0 when kr=2 else
			1;
	ret<=VRTC when SEL='1' and lsel='0' else lret;
	target<=tgtr when ret='1' else tgtd;

	process(clk,rstn)begin
		if(rstn='0')then
			kd<=0;
			kr<=0;
			cnt<=0;
			lsel<='0';
			done<='0';
			lret<='0';
		elsif(clk' event and clk='1')then
			lsel<=SEL;
			if(SEL='1' and lsel='0')then
				lret<=VRTC;
			end if;
			if(SEL='0')then
				cnt<=0;
				done<='0';
				if(lsel='1' and en='1')then
					if(lret='0')then
						if((FAST='1' and kd>=8) or kd=10)then
							kd<=0;
						else
							kd<=kd+1;
						end if;
					else
						if((FAST='1' and kr>=9) or (FAST='0' and kr>=2))then
							kr<=0;
						else
							kr<=kr+1;
						end if;
					end if;
				end if;
			elsif(ce_f='1' and OTHERWAIT='0')then
				if(en='1' and cnt<target and done='0')then
					cnt<=cnt+1;
				else
					done<='1';
				end if;
			end if;
		end if;
	end process;

	WAITn<='0' when SEL='1' and en='1' and OTHERWAIT='0' and cnt<target and done='0' else '1';

end rtl;
