LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity INTSUB is
port(
	IORQn	:in std_logic;
	MREQn	:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	M1n		:in std_logic;
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;

	
	cpuclk	:in std_logic;
	rstn	:in std_logic
);
end INTSUB;

architecture rtl of INTSUB is
-- High while an interrupt acknowledge cycle is in progress.
signal	inta	:std_logic;
begin
	
	process(cpuclk,rstn)begin
		if(rstn='0')then
			inta<='0';
		elsif(cpuclk' event and cpuclk='1')then
			if(IORQn='1')then
				inta<='0';
			elsif(M1n='0')then
				inta<='1';
			end if;
		end if;
	end process;
	
	-- Remember that an acknowledge has started and hold the byte until IORQ is
	-- released, rather than deriving the window from M1 and a delayed copy of it.
	-- M1 and IORQ overlap only during an acknowledge, so ordinary I/O is unaffected.
	DATOE<='1' when IORQn='0' and RDn='1' and WRn='1' and (M1n='0' or inta='1') else '0';
	DATOUT<=x"f3";	--di
		
end rtl;
						
				
				