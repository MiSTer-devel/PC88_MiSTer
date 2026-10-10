-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Adds wait states to every bus cycle of the main CPU while GVSTRETCH slows it
--down. A real FH in V1S with graphic VRAM selected for direct access slows
--the CPU more on loops with more bus cycles: one wait state per opcode fetch,
--memory read or write and I/O read or write at 4MHz, two at 8MHz, counted in
--the slowed clock.
--Samples held by OTHERWAIT are not counted; these waits follow them. In an I/O
--cycle the first ce_f sample falls in the automatic T1 wait, where the CPU
--does not look at WAIT_n, so it is skipped. The number of waits is taken at
--the first counted sample. Once the CPU has passed the wait in a cycle, it
--stays off until the cycle ends, even if en changes.
entity BUSWAIT is
port(
	SEL		:in std_logic;	-- memory or I/O read or write strobe is out
	IOSEL	:in std_logic;	-- the strobe is an I/O one
	OTHERWAIT	:in std_logic;	-- '1' while any other wait holds the CPU
	FAST	:in std_logic;	-- '1' at 8MHz
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end BUSWAIT;

architecture rtl of BUSWAIT is
signal	cnt		:integer range 0 to 2;	-- waits taken in this cycle
signal	ltgt	:integer range 1 to 2;	-- number of waits, taken at the first one
signal	target	:integer range 1 to 2;
signal	skip	:std_logic;	-- the I/O T1 sample has gone by
signal	done	:std_logic;	-- the CPU has passed the wait in this cycle
signal	t1		:std_logic;
begin
	target<=	ltgt when cnt/=0 else
				2 when FAST='1' else
				1;
	t1<=IOSEL and not skip;

	process(clk,rstn)begin
		if(rstn='0')then
			cnt<=0;
			ltgt<=1;
			skip<='0';
			done<='0';
		elsif(clk' event and clk='1')then
			if(SEL='0')then
				cnt<=0;
				skip<='0';
				done<='0';
			elsif(ce_f='1')then
				if(t1='1')then
					skip<='1';
				elsif(OTHERWAIT='1')then
					null;
				elsif(en='1' and cnt<target and done='0')then
					if(cnt=0)then
						ltgt<=target;
					end if;
					cnt<=cnt+1;
				else
					done<='1';
				end if;
			end if;
		end if;
	end process;

	WAITn<='0' when SEL='1' and t1='0' and en='1' and OTHERWAIT='0' and cnt<target and done='0' else '1';

end rtl;
