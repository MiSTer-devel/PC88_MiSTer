LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity IO_RD is
generic(
	IOADR	:in std_logic_vector(7 downto 0)	:=x"00"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	RDn		:in std_logic;
	DAT		:out std_logic_vector(7 downto 0);
	OUTE	:out std_logic;
	
	bit7	:in std_logic;
	bit6	:in std_logic;
	bit5	:in std_logic;
	bit4	:in std_logic;
	bit3	:in std_logic;
	bit2	:in std_logic;
	bit1	:in std_logic;
	bit0	:in std_logic
);
end IO_RD;

architecture MAIN of IO_RD is
begin
	DAT<=bit7 & bit6 & bit5 & bit4 & bit3 & bit2 & bit1 & bit0;
	OUTE<='1' when ADR=IOADR and IORQn='0' and RDn='0' else '0';
end MAIN;
