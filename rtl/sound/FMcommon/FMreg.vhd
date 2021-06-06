LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity FMreg is
generic(
	DWIDTH	:integer	:=16
);
port(
	CH		:std_logic_vector(1 downto 0);
	SL		:std_logic_vector(1 downto 0);
	RDAT	:out std_logic_vector(DWIDTH-1 downto 0);
	WDAT	:in std_logic_vector(DWIDTH-1 downto 0);
	WR		:in std_logic;

	clk		:in std_logic
);
end FMreg;

architecture rtl of FMreg is
subtype DAT_LAT_TYPE is std_logic_vector(DWIDTH-1 downto 0); 
type DAT_LAT_ARRAY is array (natural range <>) of DAT_LAT_TYPE; 

signal	RAM	:DAT_LAT_ARRAY(0 to 15);

begin
	process(clk)
	variable tADDR	:std_logic_vector(3 downto 0);
	variable iADDR	:integer range 0 to 15;
	begin
		if(clk' event and clk='1')then
			tADDR:=CH & SL;
			iADDR:=conv_integer(tADDR);
			RDAT<=RAM(iADDR);
			if(WR='1')then
				RAM(iADDR)<=WDAT;
			end if;
		end if;
	end process;
end rtl;
