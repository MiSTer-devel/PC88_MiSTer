library ieee,work;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;

entity ssmult is
generic(
	awidth	:integer	:=16;
	bwidth	:integer	:=16
);
port(
	ain		:in std_logic_vector(awidth-1 downto 0);
	bin		:in std_logic_vector(bwidth-1 downto 0);
	qout	:out std_logic_vector(awidth+bwidth-1 downto 0);
	
	clk		:in std_logic
);
end ssmult;

architecture rtl of ssmult is
signal	qsub	:std_logic_vector(awidth+bwidth-1 downto 0);
begin
	qsub<=ain * bin;
	process(clk)begin
		if(clk' event and clk='1')then
			qout<=qsub;
		end if;
	end process;
end rtl;

