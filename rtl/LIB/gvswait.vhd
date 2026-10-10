-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Adds wait states to CPU reads and writes of graphic VRAM selected for direct
--access (5Ch-5Eh) in V1S and N, as measured on a real FH.
--While GVSTRETCH slows the CPU down (STR high), it waits 5.6 slowed states at
--8MHz (6,5,6,5,6, one step per access) and 1 at 4MHz (3 in 31kHz timing),
--on top of the BUSWAIT on every bus cycle, fitted to GVRAM read loops on a
--real FH. Otherwise it waits 2 states at 8MHz and none at 4MHz.
--Only ce_f samples where no other wait holds the CPU are counted, so these
--waits add to the others. Once the CPU has seen WAIT_n high in an access, the
--wait stays off until the access ends, even if STR, FAST or en changes.
entity GVSWAIT is
port(
	SEL		:in std_logic;	-- GVRAM read or write strobe is out
	OTHERWAIT	:in std_logic;	-- '1' while any other wait holds the CPU
	FAST	:in std_logic;	-- '1' at 8MHz
	STR		:in std_logic;	-- '1' while GVSTRETCH slows the CPU down
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic;

	VT24	:in std_logic	-- '1' in 24kHz or 15kHz timing
);
end GVSWAIT;

architecture rtl of GVSWAIT is
signal	k		:integer range 0 to 4;	-- access number, mod 5
signal	cnt		:integer range 0 to 7;	-- waits taken in this access
signal	target	:integer range 0 to 7;
signal	lsel	:std_logic;
signal	done	:std_logic;	-- the CPU has passed the wait in this access
begin
	target<=	5 when FAST='1' and STR='1' and (k=1 or k=3) else
				6 when FAST='1' and STR='1' else
				2 when FAST='1' else
				1 when STR='1' and VT24='1' else
				3 when STR='1' else
				0;

	process(clk,rstn)begin
		if(rstn='0')then
			k<=0;
			cnt<=0;
			lsel<='0';
			done<='0';
		elsif(clk' event and clk='1')then
			lsel<=SEL;
			if(SEL='0')then
				cnt<=0;
				done<='0';
				if(lsel='1' and en='1')then
					if(k=4)then
						k<=0;
					else
						k<=k+1;
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
