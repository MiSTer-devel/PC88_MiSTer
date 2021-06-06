LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
USE	IEEE.STD_LOGIC_ARITH.ALL;

entity rampalette is
port(
	IORQn	:in std_logic;
	WRn		:in std_logic;
	ADR		:in std_logic_vector(7 downto 0);
	WDAT	:in std_logic_vector(7 downto 0);
	
	PMODE	:in std_logic;
	
	DOTIN	:in std_logic_vector(2 downto 0);
	ROUT	:out std_logic_vector(2 downto 0);
	GOUT	:out std_logic_vector(2 downto 0);
	BOUT	:out std_logic_vector(2 downto 0);
	
	sclk		:in std_logic;
	gclk		:in std_logic;
	rstn	:in std_logic
);
end rampalette;

architecture MAIN of rampalette is
subtype PALDATUM is std_logic_vector(2 downto 0);
type PALDAT_T is array(0 to 7) of PALDATUM;
signal	PAL_R,PAL_B,PAL_G	:PALDAT_T;

signal	IOWRn	:std_logic;
signal	ipalno	:integer range 0 to 7;

begin

	IOWRn<=IORQn or WRn;
	
	process(sclk,rstn)
	variable inum	:integer range 0 to 7;
	variable vnum	:std_logic_vector(7 downto 0);
	begin
		if(rstn='0')then
		elsif(sclk' event and sclk='1')then
			if(IOWRn='0')then
				if(ADR>=x"54" and ADR<=x"5b")then
					vnum:=ADR-x"54";
					inum:=conv_integer(vnum(2 downto 0));
					if(PMODE='0')then
						PAL_R(inum)<=(others=>WDAT(1));
						PAL_B(inum)<=(others=>WDAT(0));
						PAL_G(inum)<=(others=>WDAT(2));
					elsif(WDAT(7 downto 6)="00")then
						PAL_R(inum)<=WDAT(5 downto 3);
						PAL_B(inum)<=WDAT(2 downto 0);
					elsif(WDAT(7 downto 6)="01")then
						PAL_G(inum)<=WDAT(2 downto 0);
					end if;
				end if;
			end if;
		end if;
	end process;
	
	ipalno<=conv_integer(DOTIN);
	process(gclk)begin
		if(gclk' event and gclk='1')then
			ROUT<=PAL_R(ipalno);
			GOUT<=PAL_G(ipalno);
			BOUT<=PAL_B(ipalno);
		end if;
	end process;
	
end MAIN;