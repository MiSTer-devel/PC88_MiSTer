LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PCMTIMING is
generic(
	intwidth	:integer	:=8
);
port(
	DELTA_N	:in std_logic_vector(15 downto 0);
	
	PCMWR		:out std_logic;
	CARRY		:out std_logic;
	INTER		:out std_logic_vector(intwidth-1 downto 0);

	sft		:in std_logic;
	clk		:in std_logic;
	rstn		:in std_logic
);
end PCMTIMING;

architecture rtl of PCMTIMING is
signal	adpcmcount	:std_logic_vector(15 downto 0);
begin

	process(clk,rstn)
	variable tmpcount	:std_logic_vector(16 downto 0);
	begin
		if(rstn='0')then
			adpcmcount<=(others=>'0');
			PCMWR<='0';
			CARRY<='0';
			INTER<=(others=>'0');
		elsif(clk' event and clk='1')then
			PCMWR<='0';
			if(sft='1')then
				tmpcount:=('0' & adpcmcount) + ('0' & DELTA_N);
				CARRY<=tmpcount(16);
				PCMWR<='1';
				INTER<=tmpcount(15 downto 8);
				adpcmcount<=tmpcount(15 downto 0);
			end if;
		end if;
	end process;
	
end rtl;
