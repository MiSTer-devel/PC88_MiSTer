-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Keeps the memory wait of the 8MHz CPU while GVSTRETCH slows it down.
--A real FH at 8MHz waits one state on every memory read, write and opcode
--fetch. The core gets that wait from SDRAM, which ends in real time, so it is
--lost when the CPU clock is slowed. This adds one wait state per memory cycle,
--counting ce_f samples already held by SDRAM (SDWAIT) toward it so the two
--never add up. Samples held by OTHERWAIT are not counted and not waited on.
--Once the CPU has passed the wait in a cycle, it stays off until the cycle
--ends, even if en changes.
entity MEMWAIT is
port(
	SEL		:in std_logic;	-- memory read or write strobe is out
	SDWAIT	:in std_logic;	-- '1' while SDRAM or I/O holds the CPU
	OTHERWAIT	:in std_logic;	-- '1' while the M1 wait holds the CPU
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end MEMWAIT;

architecture rtl of MEMWAIT is
signal	cnt		:integer range 0 to 1;	-- waits counted in this cycle
signal	done	:std_logic;	-- the CPU has passed the wait in this cycle
begin
	process(clk,rstn)begin
		if(rstn='0')then
			cnt<=0;
			done<='0';
		elsif(clk' event and clk='1')then
			if(SEL='0')then
				cnt<=0;
				done<='0';
			elsif(ce_f='1')then
				if(SDWAIT='1')then
					cnt<=1;
				elsif(OTHERWAIT='1')then
					null;
				elsif(en='1' and cnt=0 and done='0')then
					cnt<=1;
				else
					done<='1';
				end if;
			end if;
		end if;
	end process;

	WAITn<='0' when SEL='1' and en='1' and SDWAIT='0' and OTHERWAIT='0' and cnt=0 and done='0' else '1';

end rtl;
