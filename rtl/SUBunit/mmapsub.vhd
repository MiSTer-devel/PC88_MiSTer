LIBRARY	IEEE,WORK;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	USE	WORK.addressmap_pkg.ALL;

entity mmapsub is
generic(
	awidth	:integer	:=25
);
port(
	CPU_ADR		:in std_logic_vector(15 downto 0);
	CPU_MREQn	:in std_logic;
	CPU_WRn		:in std_logic;
	
	RAM_ADR		:out std_logic_vector(awidth-1 downto 0);
	RAM_CE		:out std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end mmapsub;

architecture MAIN of mmapsub is
signal	ADRSEL		:integer range 0 to 1;
constant ADR_ROM	:integer	:=0;
constant ADR_RAM	:integer	:=1;
begin

	RAM_CE<=not CPU_MREQn;
	ADRSEL<=ADR_ROM when CPU_ADR(15 downto 13)="000" and CPU_WRn='1' else ADR_RAM;
	RAM_ADR<=ADDR_SUBROM(awidth-1 downto 13) & CPU_ADR(12 downto 0) when ADRSEL=ADR_ROM else
				ADDR_SUBRAM(awidth-1 downto 16) & CPU_ADR;
	
end MAIN;


