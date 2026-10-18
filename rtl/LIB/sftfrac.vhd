-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

-- sftgen with a fractional period: len is in 1/256 clocks. The remainder is
-- carried, so the pulses average len/256 clocks. Like sftgen, len is read only
-- when a pulse is given, and the first pulse comes on the first clock after
-- reset. When len is a multiple of 256, the pulses are those of sftgen with
-- len/256.
library IEEE,work;
use IEEE.std_logic_1164.all;

entity sftfrac is
generic(
	maxlen	:integer	:=100*256
);
port(
	len		:in integer range 0 to maxlen;
	sft		:out std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
);
end sftfrac;
architecture rtl of sftfrac is
signal	count	:integer range 0 to maxlen+256;
begin
	process(clk,rstn)begin
		if(rstn='0')then
			count<=256;
			sft<='0';
		elsif(clk' event and clk='1')then
			if(count>256)then
				count<=count-256;
				sft<='0';
			else
				sft<='1';
				if(count+len>256)then
					count<=count-256+len;
				else
					count<=256;		-- under one clock: a pulse on every clock, as sftgen
				end if;
			end if;
		end if;
	end process;
end rtl;
