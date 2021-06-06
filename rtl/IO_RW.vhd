LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity IO_RW is
generic(
	IOADR	:in std_logic_vector(7 downto 0)	:=x"00"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	DATIN	:in std_logic_vector(7 downto 0);
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;
	
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
end IO_RW;

architecture MAIN of IO_RW is
signal	lWRn	:std_logic_vector(1 downto 0);
signal	IOWRn	:std_logic;
signal	DATb	:std_logic_vector(7 downto 0);
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
			lWRn<="11";
			DATOUT<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(ADR=IOADR and IOWRn='0' and lWRn="10")then
				bit7<=DATIN(7);
				bit6<=DATIN(6);
				bit5<=DATIN(5);
				bit4<=DATIN(4);
				bit3<=DATIN(3);
				bit2<=DATIN(2);
				bit1<=DATIN(1);
				bit0<=DATIN(0);
				DATOUT<=DATIN;
			end if;
			lWRn<=lWRn(0) & IOWRn;
		end if;
	end process;

	DATOE<='1' when ADR=IOADR and IORQn='0' and RDn='0' else '0';
	
end MAIN;
