LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity MTsave is
generic(
	SYS_CLK	:integer	:=20000;
	DELAY	:integer	:=4000
);
port(
	MTIN	:in std_logic;
	EN		:in std_logic;
	READY	:in std_logic;
	MTOUT	:out std_logic;
	
	SAVEON	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end MTsave;

architecture rtl of MTsave is
signal	timer	:integer range 0 to SYS_CLK*DELAY;
signal	lMTIN	:std_logic;
begin
	process(clk,rstn)begin
		if(rstn='0')then
			lMTIN<='0';
			timer<=0;
		elsif(clk' event and clk='1')then
			lMTIN<=MTIN;
			if(lMTIN='0' and MTIN='1')then
				timer<=SYS_CLK*DELAY;
			elsif(EN='1')then
				timer<=SYS_CLK*DELAY;
			elsif(READY='0')then
				timer<=SYS_CLK*DELAY;
			elsif(timer>0)then
				timer<=timer-1;
			end if;
		end if;
	end process;

	MTOUT<=	MTIN when SAVEON='0' else
			'0' when timer=0 else
			MTIN;
end rtl;
