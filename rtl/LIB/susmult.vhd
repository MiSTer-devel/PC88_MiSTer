library ieee,work;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity susmult is
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
end susmult;
architecture rtl of susmult is
signal	bsig	:std_logic_vector(bwidth downto 0);
signal	qsub	:std_logic_vector(awidth+bwidth downto 0);
component ssmult
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
end component;
begin
	bsig<='0' & bin;
	mul	:ssmult generic map(awidth,bwidth+1)port map(ain,bsig,qsub,clk);
	qout<=qsub(awidth+bwidth-1 downto 0);
end rtl;


