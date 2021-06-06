LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity IO_WRS is
generic(
	IOADR	:in std_logic_vector(7 downto 0)	:=x"00"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	WRn		:in std_logic;
	DAT		:in std_logic_vector(7 downto 0);
	
	bit7	:out std_logic;
	bit6	:out std_logic;
	bit5	:out std_logic;
	bit4	:out std_logic;
	bit3	:out std_logic;
	bit2	:out std_logic;
	bit1	:out std_logic;
	bit0	:out std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
);
end IO_WRS;

architecture MAIN of IO_WRS is
signal	IOWRn	:std_logic;
signal	lWRn	:std_logic;
begin

	IOWRn<=IORQn or WRn;

	process(clk,rstn)begin
		if(rstn='0')then
			bit7<='0';
			bit6<='0';
			bit5<='0';
			bit4<='0';
			bit3<='0';
			bit2<='0';
			bit1<='0';
			bit0<='0';
		elsif(clk' event and clk='1')then
			if(ADR=IOADR and IOWRn='0' and lWRn='1')then
				bit7<=DAT(7);
				bit6<=DAT(6);
				bit5<=DAT(5);
				bit4<=DAT(4);
				bit3<=DAT(3);
				bit2<=DAT(2);
				bit1<=DAT(1);
				bit0<=DAT(0);
			end if;
		lWRn<=IOWRn;
		end if;
	end process;
end MAIN;
