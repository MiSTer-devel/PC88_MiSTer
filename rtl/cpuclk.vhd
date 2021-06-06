LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CPUCLK is
generic(
	divmain	:integer	:=5;
	divmsel	:integer	:=3;
	divsub	:integer	:=10
);
port(
	clkin	:in std_logic;
	clksel	:in std_logic;
	mainout	:out std_logic;
	subout	:out std_logic;
	rstn	:in std_logic
);
end CPUCLK;
architecture MAIN of CPUCLK is
signal	maincount	:integer range 0 to divmain-1;
signal	subcount	:integer range 0 to divsub-1;
begin
	process(clkin)begin
		if(clkin' event and clkin='1')then
			if(rstn='0')then
				mainout<='0';
				subout<='0';
				maincount<=divmain-1;
				subcount<=divsub-1;
			else
				if(clksel='0')then
					if(maincount=divmain/2)then
						mainout<='1';
					elsif(maincount=0)then
						mainout<='0';
					end if;
					if(maincount>0)then
						maincount<=maincount-1;
					else
						maincount<=divmain-1;
					end if;
				else
					if(maincount=divmsel/2)then
						mainout<='1';
					elsif(maincount=0)then
						mainout<='0';
					end if;
					if(maincount>0)then
						maincount<=maincount-1;
					else
						maincount<=divmsel-1;
					end if;
				end if;
				if(subcount=divsub/2)then
					subout<='1';
				elsif(subcount=0)then
					subout<='0';
				end if;
				if(subcount>0)then
					subcount<=subcount-1;
				else
					subcount<=divsub-1;
				end if;
			end if;
		end if;
	end process;
end MAIN;