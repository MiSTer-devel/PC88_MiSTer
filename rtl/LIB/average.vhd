LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_SIGNED.ALL;
	use ieee.std_logic_arith.all;

entity average is
generic(
	datwidth	:integer	:=16
);
port(
	INA		:in std_logic_vector(datwidth-1 downto 0);
	INB		:in std_logic_vector(datwidth-1 downto 0);
	
	OUTQ	:out std_logic_vector(datwidth-1 downto 0)
);
end average;

architecture rtl of average is
begin
	process(INA,INB)
	variable WA,WB,SUM	:std_logic_vector(datwidth downto 0);
	begin
		WA:=INA(datwidth-1)&INA;
		WB:=INB(datwidth-1)&INB;
		SUM:=WA+WB;
		outq<=sum(datwidth downto 1);
	end process;
end rtl;

	