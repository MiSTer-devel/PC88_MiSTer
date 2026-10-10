-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--Slows the main CPU down while STR is high by dropping some of its clock
--enables. A real FH in V1S runs about 4.94 times slower at 4MHz (5.02 at
--8MHz) while graphic VRAM is selected for direct access and the graphic
--screen is being displayed, and about 6.85 times (7.30 at 8MHz) in 24kHz
--timing. Part of it is a wait on every bus cycle (BUSWAIT); K gives the
--rest, as fitted to 16 loops measured on a real FH.
--Only the original ce_r/ce_f ticks are passed or dropped, and the passed ones
--always alternate ce_r, ce_f, ce_r, ... so every user of the enables sees a
--slower CPU clock. While STR is low all of them pass.
--The pass decision is registered one tick ahead, so the enable path only
--gains one AND.
--Every user of cpuce_r/cpuce_f gets the slowed enables. Do not use them as a
--time base for anything that must keep real time.
entity GVSTRETCH is
port(
	ce_r_in	:in std_logic;
	ce_f_in	:in std_logic;
	STR		:in std_logic;	-- '1' to slow down
	FAST	:in std_logic;	-- '1' at 8MHz

	ce_r	:out std_logic;
	ce_f	:out std_logic;

	clk		:in std_logic;
	rstn	:in std_logic;

	T24		:in std_logic	-- '1' in 24kHz timing
);
end GVSTRETCH;

architecture rtl of GVSTRETCH is
-- ratio K/N: 260/1024 = 1/3.938 at 4MHz, 295/1024 = 1/3.471 at 8MHz,
-- 188/1024 = 1/5.447 and 202/1024 = 1/5.069 in 24kHz timing
constant N		:integer := 1024;
signal	K		:integer range 0 to 511;
signal	acc		:integer range 0 to 2047;
signal	expf	:std_logic;	-- next tick to pass is ce_f
signal	known	:std_logic;	-- expf is valid (cleared by reset)
signal	strd	:std_logic;	-- STR used for the registered decision
signal	pass_r	:std_logic;
signal	pass_f	:std_logic;
signal	acc_nx	:integer range 0 to 2047;
signal	expf_nx	:std_logic;
signal	known_nx	:std_logic;
signal	sum		:integer range 0 to 2303;
begin
	K<=	202 when FAST='1' and T24='1' else
		295 when FAST='1' else
		188 when T24='1' else
		260;

	-- state after this edge
	process(ce_r_in,ce_f_in,pass_r,pass_f,strd,acc,expf,known,K)
	variable p	:std_logic;
	begin
		acc_nx<=acc;
		expf_nx<=expf;
		known_nx<=known;
		if(ce_r_in='1' or ce_f_in='1')then
			if(ce_r_in='1')then
				p:=pass_r;
			else
				p:=pass_f;
			end if;
			if(p='1')then
				expf_nx<=ce_r_in;
				known_nx<='1';
				if(strd='1' and acc+K>=N)then
					acc_nx<=acc+K-N;
				else
					acc_nx<=0;
				end if;
			elsif(strd='1' and acc<N)then
				acc_nx<=acc+K;
			end if;
		end if;
	end process;

	sum<=acc_nx+K;

	process(clk,rstn)begin
		if(rstn='0')then
			acc<=0;
			expf<='0';
			known<='0';
			strd<='0';
			pass_r<='1';
			pass_f<='1';
		elsif(clk' event and clk='1')then
			acc<=acc_nx;
			expf<=expf_nx;
			known<=known_nx;
			strd<=STR;
			if(known_nx='0')then
				pass_r<='1';
				pass_f<='1';
			elsif(STR='0' or sum>=N)then
				pass_r<=not expf_nx;
				pass_f<=expf_nx;
			else
				pass_r<='0';
				pass_f<='0';
			end if;
		end if;
	end process;

	ce_r<=ce_r_in and pass_r;
	ce_f<=ce_f_in and pass_f;

end rtl;
