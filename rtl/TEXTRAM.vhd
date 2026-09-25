-- Text VRAM, 4096 x 8, both ports on one clock with a clock enable. Port B only reads.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity TEXTRAM is
	port(
		address_a	:in std_logic_vector(11 downto 0);
		address_b	:in std_logic_vector(11 downto 0);
		clock		:in std_logic := '1';
		data_a		:in std_logic_vector(7 downto 0);
		data_b		:in std_logic_vector(7 downto 0);
		wren_a		:in std_logic := '0';
		wren_b		:in std_logic := '0';
		q_a			:out std_logic_vector(7 downto 0);
		q_b			:out std_logic_vector(7 downto 0);
		ce			:in std_logic := '1'
	);
end TEXTRAM;

architecture RTL of TEXTRAM is
	type MEM_T is array(0 to 4095) of std_logic_vector(7 downto 0);
	signal	mem		:MEM_T := (others=>(others=>'0'));
	signal	ra_a	:integer range 0 to 4095 := 0;
	signal	ra_b	:integer range 0 to 4095 := 0;
begin

	process(clock)begin
		if(clock'event and clock='1')then
			if(ce='1')then
				if(wren_a='1')then
					mem(conv_integer(address_a))<=data_a;
				end if;
				ra_a<=conv_integer(address_a);
				ra_b<=conv_integer(address_b);
			end if;
		end if;
	end process;

	q_a<=mem(ra_a);
	q_b<=mem(ra_b);

end RTL;
