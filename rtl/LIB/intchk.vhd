library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity intchk is
generic(
	interval	:integer	:=100;
	chk			:integer	:=10
);
port(
	en			:out std_logic;
	clk			:in std_logic;
	rstn		:in std_logic
);
end intchk;

architecture rtl of intchk is
signal	timer	:integer range 0 to interval-1;
begin
	process(clk,rstn)begin
		if(rstn='0')then
			timer<=0;
			en<='0';
		elsif(clk' event and clk='1')then
			if(timer=0)then
				timer<=interval-1;
			else
				timer<=timer-1;
			end if;
			if(timer<chk)then
				en<='1';
			else
				en<='0';
			end if;
		end if;
	end process;
end rtl;