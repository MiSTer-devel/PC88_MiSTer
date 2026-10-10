-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--Fills the RAM as a real machine has it at power on, once per fill command.
--SDRAM keeps its contents over a core reload, so without this the RAM of the
--previous run was still there. A real machine keeps its RAM over its reset
--button and loses it only at power off. The command comes from the clk21m
--side (RAMTYPECTL) when the boot ROM download is over, and again only at a
--reset after the RAM type in the OSD was changed.
--
--RAM type (TYPE, taken from the command):
--  "00" Fx: main RAM and sub CPU RAM as measured on a real FH, no extended RAM.
--  "01" Mx: main RAM, sub CPU RAM and 4 banks of extended RAM as measured on a real MA.
--  "10" 512KB: as Mx with 16 banks of extended RAM (banks 4-15 continue the MA tables).
--  The ADPCM RAM is filled with the MA values for every type (only the MA was measured).
--
--Ranges, in order:
--  main RAM 0000h-FFFFh: 0000h-BFFFh at ADDR_BACKRAM+address. C000h-FFFFh share the
--    graphic VRAM words (memorymaps.vhd): the upper byte of the second word at
--    ADDR_GVRAM+address(13:0)*2, written alone with VRAMWE "1000".
--  extended RAM (Mx, 512KB): bank n offset a at ADDR_EXTRAM+n*8000h+a.
--  ADPCM RAM: 256KB at ADDR_ADPCM.
--  sub CPU RAM 4000h-7FFFh: block RAM, one byte per clock on SWR (no wait).
--ADR is the offset from ADDR_BACKRAM.
--
--FH main RAM: 00 00 FF FF FF FF 00 00 repeating.
--FH sub CPU RAM: alternating 00h/FFh, the value at even addresses set per 2KB.
--MA (main, extended and sub CPU RAM): runs of 16 bytes that swap every 64 bytes,
--  with a phase per 256-byte page: the value is LO when (a4 xor a6 xor phase)=1.
--  Main and extended RAM: HI 00h, LO FFh. 32KB tables T0 (main 0000h-7FFFh, banks
--  0, 2, ...) and T1 (main 8000h-FFFFh, banks 1, 3, ...).
--  Sub CPU RAM: HI F0h, LO 0Fh, except two pages with HI FFh, LO 00h.
--MA ADPCM RAM: 64 bytes of 99h and 64 bytes of 66h repeating.
--
--S_WAIT: wait for the first command. S_START: wait until the SDRAM port is free.
--S_FILL: SDRAM ranges, one byte at a time. S_SUB: sub CPU RAM. S_DONE: DONE high
--until the next command. A PLL relock (rstn) during a fill starts the fill over
--with the same type; in S_WAIT and S_DONE it does nothing.
--
--A SDRAM write is held until RAM_WAIT has gone high and low again: the SDRAM port
--takes a write only on a rise of its strobe and raises its wait some clocks
--later. The strobe is then kept low for one clock before the next write.
entity RAMFILL is
port(
	CMD		:in std_logic;	-- fill command (one clock)
	CTYPE	:in std_logic_vector(1 downto 0);	-- RAM type of the command
	RAM_WAIT	:in std_logic;

	ADR		:out std_logic_vector(21 downto 0);
	WDAT	:out std_logic_vector(7 downto 0);
	WR		:out std_logic;
	OE		:out std_logic;

	SADR	:out std_logic_vector(13 downto 0);	-- sub CPU RAM, from 4000h
	SWDAT	:out std_logic_vector(7 downto 0);
	SWR		:out std_logic;

	DONE	:out std_logic;
	RTYPE	:out std_logic_vector(1 downto 0);	-- type of the last command

	clk		:in std_logic;
	rstn	:in std_logic
);
end RAMFILL;

architecture rtl of RAMFILL is
--Phase per page (left = page 0), 1 = the page starts with LO.
constant T0	:std_logic_vector(0 to 127):=
	"0101010000001010010101000010101001010000001010100101000000101010" &
	"1010101111110101101010111101010110101111110101011010111111010101";
constant T1	:std_logic_vector(0 to 127):=
	"1010101111110101101010111111010110101011110101011010111111010101" &
	"0101010000001010010101000000101001010100001010100101000000101010";
--Sub CPU RAM 4000h-7FFFh. Pages 5000h and 7F00h were not measured (boot sector,
--sub ROM work area) and take phase 0 like 5100h and 7E00h.
constant SUBPH	:std_logic_vector(0 to 63):=
	"0000001100000011" & "0000011100000111" & "1111110011111100" & "1111100011111000";
constant SUBLO	:std_logic_vector(0 to 63):=	-- pages with HI FFh, LO 00h (4D00h, 6D00h)
	"0000000000000100" & "0000000000000000" & "0000000000000100" & "0000000000000000";
type EVEN_T is array(0 to 7) of std_logic_vector(7 downto 0);
constant FHSUB	:EVEN_T :=(x"00",x"FF",x"00",x"FF",x"FF",x"00",x"FF",x"00");

type state_t is (S_WAIT,S_START,S_FILL,S_SUB,S_DONE);
type range_t is (R_MAIN,R_EXT,R_PCM);
--No asynchronous reset: whether a reset restarts depends on the state.
signal	state	:state_t := S_WAIT;
signal	rg		:range_t := R_MAIN;
signal	cnt		:unsigned(18 downto 0) := (others=>'0');
signal	scnt	:unsigned(13 downto 0) := (others=>'0');
signal	ltype	:std_logic_vector(1 downto 0) := "00";
signal	wr_i	:std_logic := '0';
signal	seen	:std_logic := '0';
signal	doner	:std_logic := '0';
signal	last	:std_logic;
signal	ph		:std_logic;
signal	sph		:std_logic;

begin
	--Last byte of the current SDRAM range.
	last<=	'1' when rg=R_MAIN and cnt(15 downto 0)=x"FFFF" else
			'1' when rg=R_EXT and ltype="01" and cnt(16 downto 0)="1" & x"FFFF" else
			'1' when rg=R_EXT and ltype/="01" and cnt=to_unsigned(16#7FFFF#,19) else
			'1' when rg=R_PCM and cnt(17 downto 0)="11" & x"FFFF" else
			'0';

	process(clk)begin
		if(clk' event and clk='1')then
			if(rstn='0')then
				if(state=S_FILL or state=S_SUB)then
					state<=S_START;
				end if;
				wr_i<='0';
				seen<='0';
			else
				case state is
				when S_WAIT | S_DONE =>
					if(CMD='1')then
						ltype<=CTYPE;
						state<=S_START;
					end if;
				when S_START =>
					if(RAM_WAIT='0')then
						state<=S_FILL;
						rg<=R_MAIN;
						cnt<=(others=>'0');
						wr_i<='1';
						seen<='0';
					end if;
				when S_FILL =>
					if(wr_i='1')then
						if(RAM_WAIT='1')then
							seen<='1';
						elsif(seen='1')then
							wr_i<='0';
							seen<='0';
							if(last='1')then
								cnt<=(others=>'0');
								if(rg=R_MAIN and ltype/="00")then
									rg<=R_EXT;
								elsif(rg=R_MAIN or rg=R_EXT)then
									rg<=R_PCM;
								else
									state<=S_SUB;
									scnt<=(others=>'0');
								end if;
							else
								cnt<=cnt+1;
							end if;
						end if;
					else
						wr_i<='1';
					end if;
				when S_SUB =>
					if(scnt=to_unsigned(16#3FFF#,14))then
						state<=S_DONE;
					else
						scnt<=scnt+1;
					end if;
				when others =>
				end case;
			end if;
			--Registered before it crosses to clk21m. Made from the state on every clock,
			--so it does not rest on the power-up level of a register that is only set.
			if(state=S_DONE)then
				doner<='1';
			else
				doner<='0';
			end if;
		end if;
	end process;

	OE<='1' when state=S_FILL else '0';
	WR<=wr_i when state=S_FILL else '0';
	ADR<=	"000" & "0100" & std_logic_vector(cnt(13 downto 0)) & '0' when rg=R_MAIN and cnt(15 downto 14)="11" else
			"000000" & std_logic_vector(cnt(15 downto 0)) when rg=R_MAIN else
			"001" & std_logic_vector(cnt(18 downto 0)) when rg=R_EXT else
			"1000" & std_logic_vector(cnt(17 downto 0));

	--Phase of the MA tables: main RAM by address bit 15, extended RAM by bank bit 0.
	ph<=	T1(to_integer(cnt(14 downto 8))) when (rg=R_MAIN and cnt(15)='1') or (rg=R_EXT and cnt(15)='1') else
			T0(to_integer(cnt(14 downto 8)));
	WDAT<=	x"FF" when rg=R_MAIN and ltype="00" and (cnt(2 downto 1)="01" or cnt(2 downto 1)="10") else
			x"00" when rg=R_MAIN and ltype="00" else
			x"99" when rg=R_PCM and cnt(6)='0' else
			x"66" when rg=R_PCM else
			x"FF" when (cnt(4) xor cnt(6) xor ph)='1' else
			x"00";

	sph<=SUBPH(to_integer(scnt(13 downto 8)));
	SADR<=std_logic_vector(scnt);
	SWR<='1' when state=S_SUB else '0';
	SWDAT<=	FHSUB(to_integer(scnt(13 downto 11))) when ltype="00" and scnt(0)='0' else
			not FHSUB(to_integer(scnt(13 downto 11))) when ltype="00" else
			x"FF" when SUBLO(to_integer(scnt(13 downto 8)))='1' and (scnt(4) xor scnt(6) xor sph)='0' else
			x"00" when SUBLO(to_integer(scnt(13 downto 8)))='1' else
			x"F0" when (scnt(4) xor scnt(6) xor sph)='0' else
			x"0F";

	DONE<=doner;
	RTYPE<=ltype;

end rtl;
