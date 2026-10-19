-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Wait states on CPU accesses to the high-speed RAM (F000h-FFFFh, TMODE=0),
--as measured on a real FH. The core keeps it in block RAM, which never waits.
--  V1H and V2 at 8MHz: 2 on a read or an opcode fetch, 1 on a write.
--  V1H and V2 at 4MHz: 1 on an opcode fetch only.
--  V1S at 8MHz: 1 on a read, an opcode fetch or a write, the same as main RAM.
--  V1S at 4MHz and N: none here (M1WAIT gives the V1S opcode fetch its wait).
--The waits are taken on the first ce_f samples of the cycle. Other waits are
--put after these, as for SDRAM. Once a sample has passed without a wait, no
--wait is raised again in that cycle, even if the CPU speed changes.
entity TRAMWAIT is
port(
	SEL		:in std_logic;	-- high-speed RAM, read or write strobe is out
	RDn		:in std_logic;
	M1n		:in std_logic;
	CPUMD	:in std_logic;	-- '1' at 8MHz
	HS		:in std_logic;	-- V1H or V2
	V1S		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end TRAMWAIT;

architecture rtl of TRAMWAIT is
signal	num		:integer range 0 to 2;	-- waits for this cycle
signal	cnt		:integer range 0 to 2;	-- waits taken in this cycle
signal	done	:std_logic;	-- the CPU has passed the wait in this cycle
begin
	num<=	2 when HS='1' and CPUMD='1' and RDn='0' else
			1 when HS='1' and CPUMD='1' else
			1 when HS='1' and M1n='0' else
			1 when V1S='1' and CPUMD='1' else
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
