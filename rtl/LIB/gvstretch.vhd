-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--Slows the main CPU down while STR is high by dropping some of its clock
--enables. A real FH in V1S runs about 4.94 times slower at 4MHz (5.02 at
--8MHz) while graphic VRAM is selected for direct access and the graphic
--screen is being displayed, and about 6.85 times (7.30 at 8MHz) in 24kHz
--timing. At 4MHz part of it is a wait on every bus cycle (BUSWAIT) and K
--gives the rest, as fitted to 16 loops measured on a real FH. At 8MHz K gives
--the slowdown a FH shows with the CRTC and the text DMA stopped; the text row
--transfers (TRAMCONV) and the GVRAM waits (GVSWAIT) add the rest. In 24kHz
--timing at 8MHz a FH also slows I/O cycles more than memory cycles (about
--7.8 times per T against 7.2), so K is smaller while IOC is high.
--At 8MHz a FH charges the 5th and 6th T of a 5T or 6T M1 cycle (RET cc,
--INC rr and the like) differently from other T-states, mostly less, so K is
--set separately in them. At 4MHz BUSWAIT adds nothing in those T-states, so
--K is set separately there too. In 24kHz timing at 8MHz a FH also charges a
--memory read that directly follows another memory read (the 2nd operand byte
--of LD BC,nn or JP nn) more than one that follows an M1, so K is smaller in
--such a read (rre, made from MRD and MCYC of the CPU). The values were fitted
--to a FH for each timing and text DMA state; why the FH charges them
--differently is not known.
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

	T24		:in std_logic;	-- '1' in 24kHz timing
	IOC		:in std_logic;	-- '1' in an I/O read or write cycle (IORQ_n low)
	T5		:in std_logic;	-- '1' in the 5th T of a 5T or 6T M1
	T6		:in std_logic;	-- '1' in the 6th T of a 6T M1
	TXA		:in std_logic;	-- '1' while the text DMA runs (CRTC and DMAC started)
	MRD		:in std_logic;	-- '1' in a memory read cycle other than an M1
	MCYC	:in std_logic_vector(2 downto 0)	-- the M cycle of the CPU
);
end GVSTRETCH;

architecture rtl of GVSTRETCH is
-- ratio K/N: 260/1024 = 1/3.938 at 4MHz, 204/1024 = 1/5.020 at 8MHz,
-- 188/1024 = 1/5.447 and 143/1024 = 1/7.161 in 24kHz timing (121/1024 =
-- 1/8.463 in I/O cycles and 123/1024 = 1/8.325 with the text DMA, 128/1024 =
-- 1/8.000 without it, in a read right after a read at 8MHz)
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
signal	mcyc_d	:std_logic_vector(2 downto 0);
signal	seen_rd	:std_logic;	-- MRD was high in this M cycle (kept while the bus is released)
signal	prev_rd	:std_logic;	-- the M cycle before was a memory read other than an M1
signal	rre		:std_logic;	-- this cycle is a memory read right after another one
begin
	--a memory read right after a memory read, with no M1 between
	process(clk)begin
		if(clk' event and clk='1')then
			mcyc_d<=MCYC;
			if(MCYC/=mcyc_d)then
				prev_rd<=seen_rd;
				seen_rd<=MRD;
			elsif(MRD='1')then
				seen_rd<='1';
			end if;
		end if;
	end process;
	rre<='1' when MRD='1' and prev_rd='1' else '0';

	--K one clock late (keeps FAST, T24 and the CPU strobes out of the pass path)
	process(clk)begin
		if(clk' event and clk='1')then
			--8MHz M1 5th/6th T: 24kHz with and without the text DMA, then 15kHz.
			if(FAST='1' and T24='1' and T5='1' and TXA='1')then
				K<=165;
			elsif(FAST='1' and T24='1' and T6='1' and TXA='1')then
				K<=160;
			elsif(FAST='1' and T24='1' and T5='1')then
				K<=149;
			elsif(FAST='1' and T24='1' and T6='1')then
				K<=154;
			elsif(FAST='1' and T5='1' and TXA='1')then
				K<=242;
			elsif(FAST='1' and T6='1' and TXA='1')then
				K<=196;
			elsif(FAST='1' and T5='1')then
				K<=216;
			elsif(FAST='1' and T6='1')then
				K<=211;
			--8MHz memory read right after a memory read: 24kHz with and without
			--the text DMA, then 15kHz.
			elsif(FAST='1' and T24='1' and rre='1' and TXA='1')then
				K<=123;
			elsif(FAST='1' and T24='1' and rre='1')then
				K<=128;
			elsif(FAST='1' and rre='1')then
				K<=206;
			elsif(FAST='1' and T24='1' and IOC='1')then
				K<=121;
			elsif(FAST='1' and T24='1')then
				K<=143;
			elsif(FAST='1')then
				K<=204;
			--4MHz M1 5th/6th T: 24kHz with and without the text DMA, then 15kHz.
			elsif(FAST='0' and T24='1' and (T5='1' or T6='1') and TXA='1')then
				K<=163;
			elsif(FAST='0' and T24='1' and T5='1')then
				K<=131;
			elsif(FAST='0' and T24='1' and T6='1')then
				K<=119;
			elsif(FAST='0' and T5='1' and TXA='1')then
				K<=496;
			elsif(FAST='0' and T6='1' and TXA='1')then
				K<=163;
			elsif(FAST='0' and T5='1')then
				K<=317;
			elsif(FAST='0' and T6='1')then
				K<=162;
			elsif(T24='1')then
				K<=188;
			else
				K<=260;
			end if;
		end if;
	end process;

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
