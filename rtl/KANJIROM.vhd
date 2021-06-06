LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity KANJIROM is
	generic(
	BASEADR	:std_logic_vector(7 downto 0)	:=x"e8"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	WDAT	:in std_logic_vector(7 downto 0);
	
	KNJADR	:out std_logic_vector(16 downto 0);
	KNJRD	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end KANJIROM;
architecture MAIN of KANJIROM is
signal	IOWRn	:std_logic;
signal	IORD	:std_logic;
signal	KNJRDu	:std_logic;
signal	ADRIS	:std_logic;
begin
	
	IOWRn<=IORQn or WRn;
	
	process(clk,rstn)begin
		if(rstn='0')then
			KNJADR(16 downto 1)<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(IOWRn='0')then
				case ADR is
				when BASEADR =>
					KNJADR(8 downto 1)<=WDAT;
				when BASEADR+x"01" =>
					KNJADR(16 downto 9)<=WDAT;
				when others=>
				end case;
			end if;
		end if;
	end process;
	
	KNJADR(0)<=not ADR(0);
	
	
	ADRIS	<='1' when ADR(7 downto 1)=BASEADR(7 downto 1) else '0';
	IORD	<=not(IORQn or RDn);
	KNJRD	<=ADRIS and IORD;
--	KNJRDu<='1' when IORQn='0' and RDn='0' and ADR(7 downto 1)=BASEADR(7 downto 1) else '0';

--	process(clk,rstn)begin
--		if(rstn='0')then
--			KNJRD<='0';
--		elsif(clk' event and clk='1')then
--			KNJRD<=KNJRDu;
--		end if;
--	end process;
	
end MAIN;