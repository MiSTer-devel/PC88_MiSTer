LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity IO_DETAC is
generic(
	IOADR	:in std_logic_vector(7 downto 0)	:=x"00"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	ACn		:in std_logic;

	det		:out std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
);
end IO_DETAC;

architecture MAIN of IO_DETAC is
signal	IOACn	:std_logic;
signal	lACn	:std_logic;
begin

	IOACn<=IORQn or ACn;

	process(clk,rstn)begin
		if(rstn='0')then
			det<='0';
		elsif(clk' event and clk='1')then
			if(ADR=IOADR and IOACn='0' and lACn='1')then
				det<='1';
			else
				det<='0';
			end if;
		lACn<=IOACn;
		end if;
	end process;
end MAIN;
