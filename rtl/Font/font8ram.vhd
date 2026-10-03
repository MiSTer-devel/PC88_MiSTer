-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

-- 8x8 font, 2048 x 8, loaded from the kanji ROM in boot.rom. Read address registered,
-- as in fontram.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity font8ram is
	port(
		clock		:in std_logic := '1';
		data		:in std_logic_vector(7 downto 0);
		rdaddress	:in std_logic_vector(10 downto 0);
		wraddress	:in std_logic_vector(10 downto 0);
		wren		:in std_logic := '0';
		q			:out std_logic_vector(7 downto 0)
	);
end font8ram;

architecture RTL of font8ram is
	type MEM_T is array(0 to 2047) of std_logic_vector(7 downto 0);
	signal	mem		:MEM_T := (others=>(others=>'0'));
	signal	ra		:integer range 0 to 2047 := 0;
begin

	process(clock)begin
		if(clock'event and clock='1')then
			if(wren='1')then
				mem(conv_integer(wraddress))<=data;
			end if;
			ra<=conv_integer(rdaddress);
		end if;
	end process;

	q<=mem(ra);

end RTL;
