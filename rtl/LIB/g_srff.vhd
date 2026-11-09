library IEEE,work;
use IEEE.std_logic_1164.all;

entity g_srff is
port(
	set		:in std_logic;
	reset	:in std_logic;
	
	q		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;

	--Save and restore: REG is q. While HOLD is '1' it is kept; DIRSet loads DIR.
	--rstn wins over both; DIRSet wins over set and reset.
	HOLD	:in std_logic	:='0';
	REG		:out std_logic;
	DIRSet	:in std_logic	:='0';
	DIR		:in std_logic	:='0'
);
end g_srff;

architecture rtl of g_srff is
signal	qb	:std_logic;
begin
	process(clk,rstn)begin
		if(rstn='0')then
			qb<='0';
		elsif(clk' event and clk='1')then
			if(reset='1')then
				qb<='0';
			elsif(set='1')then
				qb<='1';
			end if;
			if(DIRSet='1')then
				qb<=DIR;
			elsif(HOLD='1')then
				qb<=qb;
			end if;
		end if;
	end process;
	q<=qb;
	REG<=qb;
end rtl;
