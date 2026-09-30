-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Adds wait states to CPU reads and writes of graphic VRAM.
--A real FH waits 1.5 states on average at 4MHz and 3.72 at 8MHz, so the
--count follows 1,2 at 4MHz and 4,4,4,3 at 8MHz, one step per access.
--Only ce_f samples where no other wait holds the CPU are counted, so these
--waits add to the others.
entity GVWAIT is
port(
	SEL		:in std_logic;	-- GVRAM read or write strobe is out
	OTHERWAIT	:in std_logic;	-- '1' while any other wait holds the CPU
	FAST	:in std_logic;	-- '1' at 8MHz
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end GVWAIT;

architecture rtl of GVWAIT is
signal	k		:integer range 0 to 3;	-- access number, mod 4
signal	cnt		:integer range 0 to 7;	-- waits taken in this access
signal	target	:integer range 0 to 7;
signal	lsel	:std_logic;
begin
	target<=	3 when FAST='1' and k=3 else
				4 when FAST='1' else
				2 when k=1 or k=3 else
				1;

	process(clk,rstn)begin
		if(rstn='0')then
			k<=0;
			cnt<=0;
			lsel<='0';
		elsif(clk' event and clk='1')then
			lsel<=SEL;
			if(SEL='0')then
				cnt<=0;
				if(lsel='1' and en='1')then
					if(k=3)then
						k<=0;
					else
						k<=k+1;
					end if;
				end if;
			elsif(ce_f='1' and OTHERWAIT='0' and en='1' and cnt<target)then
				cnt<=cnt+1;
			end if;
		end if;
	end process;

	WAITn<='0' when SEL='1' and en='1' and OTHERWAIT='0' and cnt<target else '1';

end rtl;
