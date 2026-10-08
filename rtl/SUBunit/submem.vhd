-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

-- Memory of the disk sub CPU, in block RAM instead of SDRAM, so that the sub CPU
-- no longer takes the second SDRAM window from the main CPU.
-- ROM: 8KB at 0000h-1FFFh (reads only), written by the ROM loader.
-- RAM: 16KB at 4000h-7FFFh. Other addresses read FFh and writes are lost,
-- as on a real FH. ADR is the address from mmapsub (ADDR_SUBROM or ADDR_SUBRAM
-- on top of the CPU address).
-- The RAM starts with the contents a real FH has at power on and is not cleared
-- by any reset. The loader writes arrive while the sub CPU is held in reset, so
-- nothing here is held by a reset.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.addressmap_pkg.all;

entity SUBMEM is
	generic(
		AWIDTH	:integer	:=25
	);
	port(
		ADR		:in std_logic_vector(AWIDTH-1 downto 0);
		WR		:in std_logic;
		WDAT	:in std_logic_vector(7 downto 0);
		RDAT	:out std_logic_vector(7 downto 0);

		LDADR	:in std_logic_vector(12 downto 0);
		LDDAT	:in std_logic_vector(7 downto 0);
		LDWR	:in std_logic;

		clk		:in std_logic
	);
end SUBMEM;

architecture RTL of SUBMEM is
	type ROM_T is array(0 to 8191) of std_logic_vector(7 downto 0);
	type RAM_T is array(0 to 16383) of std_logic_vector(7 downto 0);

	-- FH power-on contents: alternating 00h/FFh, the value at even addresses
	-- set per 2KB from 4000h (5800h-67FFh is one 4KB block), odd addresses
	-- the opposite.
	function ram_init return RAM_T is
		type EVEN_T is array(0 to 7) of std_logic_vector(7 downto 0);
		constant EVEN	:EVEN_T :=(x"00",x"FF",x"00",x"FF",x"FF",x"00",x"FF",x"00");
		variable m		:RAM_T;
	begin
		for i in 0 to 16383 loop
			if((i mod 2)=0)then
				m(i):=EVEN(i/2048);
			else
				m(i):=not EVEN(i/2048);
			end if;
		end loop;
		return m;
	end function;

	signal	rom		:ROM_T := (others=>(others=>'1'));
	signal	ram		:RAM_T := ram_init;
	signal	romra	:integer range 0 to 8191 := 0;
	signal	ramra	:integer range 0 to 16383 := 0;
	signal	isrom	:std_logic;
	signal	isram	:std_logic;
	signal	selrom	:std_logic := '0';
	signal	selram	:std_logic := '0';
begin

	isrom<='1' when ADR(AWIDTH-1 downto 13)=ADDR_SUBROM(AWIDTH-1 downto 13) else '0';
	isram<='1' when ADR(AWIDTH-1 downto 16)=ADDR_SUBRAM(AWIDTH-1 downto 16) and ADR(15 downto 14)="01" else '0';

	process(clk)begin
		if(clk'event and clk='1')then
			if(LDWR='1')then
				rom(conv_integer(LDADR))<=LDDAT;
			end if;
			romra<=conv_integer(ADR(12 downto 0));
		end if;
	end process;

	process(clk)begin
		if(clk'event and clk='1')then
			if(WR='1' and isram='1')then
				ram(conv_integer(ADR(13 downto 0)))<=WDAT;
			end if;
			ramra<=conv_integer(ADR(13 downto 0));
		end if;
	end process;

	process(clk)begin
		if(clk'event and clk='1')then
			selrom<=isrom;
			selram<=isram;
		end if;
	end process;

	RDAT<=	rom(romra) when selrom='1' else
			ram(ramra) when selram='1' else
			x"FF";

end RTL;
