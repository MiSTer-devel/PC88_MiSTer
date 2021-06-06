LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity INTSUB is
port(
	IORQn	:in std_logic;
	MREQn	:in std_logic;
	RDn		:in std_logic;
	M1n		:in std_logic;
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;

	
	cpuclk	:in std_logic;
	rstn	:in std_logic
);
end INTSUB;

architecture rtl of INTSUB is
signal	M1nc	:std_logic;
begin
	
	process(cpuclk,rstn)begin
		if(rstn='0')then
			M1nc<='1';
		elsif(cpuclk' event and cpuclk='0')then
			M1nc<=M1n;
		end if;
	end process;
	
	DATOE<='1' when (M1nc='0' or M1n='0')  and IORQn='0' and RDn='1' else '0';
	DATOUT<=x"f3";	--di
		
end rtl;
						
				
				