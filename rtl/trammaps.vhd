LIBRARY	IEEE,WORK;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	USE	WORK.addressmap_pkg.ALL;

entity trammaps is
generic(
	awidth	:integer	:=25
);
port(
	VADR		:in std_logic_vector(15 downto 0);
	
	RAM_ADR		:out std_logic_vector(awidth-1 downto 0)
);
end trammaps;

architecture rtl of trammaps is
begin
	RAM_ADR<=
		ADDR_GVRAM(awidth-1 downto 15) & VADR(13 downto 0) & '0' when VADR(15 downto 14)="11" else
		ADDR_BACKRAM(awidth-1 downto 16) & VADR;

end rtl;


