LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity beeposc	is
generic(
	beepcyc	:integer	:=10000;		--Hz
	sysclk	:integer	:=20000			--kHz
);
port(
	sndout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end beeposc;

architecture rtl of beeposc is
signal	trig	:std_logic;
signal	lev		:std_logic;
component sftgen
generic(
	maxlen	:integer	:=100
);
port(
	len		:in integer range 0 to maxlen;
	sft		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;
begin
	osc	:sftgen generic map(sysclk*500/beepcyc) port map(sysclk*500/beepcyc,trig,clk,rstn);
	process(clk,rstn)begin
		if(rstn='0')then
			lev<='0';
		elsif(clk' event and clk='1')then
			if(trig='1')then
				lev<=not lev;
			end if;
		end if;
	end process;
	sndout<=lev;
end rtl;
			