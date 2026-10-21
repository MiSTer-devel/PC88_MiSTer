-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--Holds CPU writes to graphic VRAM back while they wait for a free slot.
--On a real FH at 8MHz in 24kHz timing, writes that follow each other closely
--while the screen is drawn wait longer than single writes: PUSH to graphic
--VRAM takes about 26 states on the FH, 22.4 in the core without this.
--This is not the circuit of the FH. It is a model that gives the measured
--waits: up to 3 writes are held, the oldest one goes out when it is at least
--MINAGE states old and a slot comes, and a write that finds all 3 places
--taken waits until one is free.
--A slot comes in the horizontal or vertical retrace, and while the screen is
--drawn at random, PHIT in 256 per state (an LFSR).
--QWAIT is high while a write waits for a free place. GVWAIT adds its own
--wait after that.
entity GVWQ is
port(
	SEL		:in std_logic;	-- GVRAM read or write strobe is out
	WRn		:in std_logic;
	en		:in std_logic;	-- 24kHz timing, V1H or V2, 8MHz, graphic screen on

	QWAIT	:out std_logic;

	HRTC	:in std_logic;
	VRTC	:in std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end GVWQ;

architecture rtl of GVWQ is
constant DEPTH	:integer	:=3;
constant PHIT	:integer	:=18;
constant MINAGE	:integer	:=6;
constant SEED	:std_logic_vector(15 downto 0)	:=x"ace1";
constant TAPS	:std_logic_vector(15 downto 0)	:=x"b400";
type age_t is array(0 to DEPTH-1) of integer range 0 to 8;
signal	cnt		:integer range 0 to DEPTH;	-- writes held
signal	age		:age_t;	-- states since each held write came, oldest first
signal	pushed	:std_logic;	-- this write is held already
signal	lfsr	:std_logic_vector(15 downto 0);
signal	nlfsr	:std_logic_vector(15 downto 0);
signal	wr		:std_logic;

function step8(s:std_logic_vector(15 downto 0)) return std_logic_vector is
variable v	:std_logic_vector(15 downto 0);
begin
	v:=s;
	for i in 0 to 7 loop
		if(v(0)='1')then
			v:=('0' & v(15 downto 1)) xor TAPS;
		else
			v:='0' & v(15 downto 1);
		end if;
	end loop;
	return v;
end function;

begin
	wr<='1' when SEL='1' and WRn='0' else '0';
	nlfsr<=step8(lfsr);
	QWAIT<='1' when en='1' and wr='1' and pushed='0' and cnt=DEPTH else '0';

	process(clk,rstn)
	variable n	:integer range 0 to DEPTH;
	variable a	:age_t;
	begin
		if(rstn='0')then
			cnt<=0;
			age<=(others=>0);
			pushed<='0';
			lfsr<=SEED;
		elsif(clk' event and clk='1')then
			if(SEL='0')then
				pushed<='0';
			end if;
			if(ce_f='1')then
				lfsr<=nlfsr;
				if(en='0')then
					cnt<=0;
					age<=(others=>0);
				else
					n:=cnt;
					a:=age;
					for i in 0 to DEPTH-1 loop
						if(i<n and a(i)<8)then
							a(i):=a(i)+1;
						end if;
					end loop;
					if(n>0 and a(0)>=MINAGE and (HRTC='1' or VRTC='1' or unsigned(nlfsr(7 downto 0))<PHIT))then
						for i in 0 to DEPTH-2 loop
							a(i):=a(i+1);
						end loop;
						a(DEPTH-1):=0;
						n:=n-1;
					end if;
					if(wr='1' and pushed='0' and n<DEPTH)then
						a(n):=0;
						n:=n+1;
						pushed<='1';
					end if;
					cnt<=n;
					age<=a;
				end if;
			end if;
		end if;
	end process;

end rtl;
