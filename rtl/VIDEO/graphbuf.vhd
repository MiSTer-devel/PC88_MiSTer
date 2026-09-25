-- Graphics line buffer, 128 x 8, with a clock enable. Reads take two enabled clocks.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity graphbuf is
	port(
		clock		:in std_logic := '1';
		data		:in std_logic_vector(7 downto 0);
		rdaddress	:in std_logic_vector(6 downto 0);
		wraddress	:in std_logic_vector(6 downto 0);
		wren		:in std_logic := '0';
		q			:out std_logic_vector(7 downto 0);
		ce			:in std_logic := '1'
	);
end graphbuf;

architecture RTL of graphbuf is
	type MEM_T is array(0 to 127) of std_logic_vector(7 downto 0);
	signal	mem	:MEM_T := (others=>(others=>'0'));
	signal	ra	:integer range 0 to 127 := 0;
	signal	qr	:std_logic_vector(7 downto 0) := (others=>'0');
begin

	process(clock)begin
		if(clock'event and clock='1')then
			if(ce='1')then
				if(wren='1')then
					mem(conv_integer(wraddress))<=data;
				end if;
				ra<=conv_integer(rdaddress);
				qr<=mem(ra);
			end if;
		end if;
	end process;

	q<=qr;

end RTL;
