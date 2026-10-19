-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Wait states on CPU reads of the kanji ROM ports (E8h, E9h, ECh, EDh), as
--measured on a real FH: 2 at 8MHz, none at 4MHz, more than on other I/O
--reads. The core reads the ROM from SDRAM; the SDRAM wait is counted in the
--same samples, so the access takes the larger of the two.
--In an I/O cycle the first ce_f sample falls in the automatic wait state the
--Z80 adds after T1, where the CPU does not look at WAIT_n, so 3 samples give
--2 more than other I/O reads.
--Once a sample has passed without a wait, no wait is raised again in that
--cycle, even if the CPU speed changes.
entity KNJWAIT is
port(
	SEL		:in std_logic;	-- kanji ROM read strobe is out
	CPUMD	:in std_logic;	-- '1' at 8MHz

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end KNJWAIT;

architecture rtl of KNJWAIT is
signal	num		:integer range 0 to 3;	-- samples to hold WAIT_n low in this cycle
signal	cnt		:integer range 0 to 3;	-- samples taken in this cycle
signal	done	:std_logic;	-- the CPU has passed the wait in this cycle
begin
	num<=	3 when CPUMD='1' else
			0;

	process(clk,rstn)begin
		if(rstn='0')then
			cnt<=0;
			done<='0';
		elsif(clk' event and clk='1')then
			if(SEL='0')then
				cnt<=0;
				done<='0';
			elsif(ce_f='1')then
				if(cnt<num and done='0')then
					cnt<=cnt+1;
				else
					done<='1';
				end if;
			end if;
		end if;
	end process;

	WAITn<='0' when SEL='1' and done='0' and cnt<num else '1';

end rtl;
