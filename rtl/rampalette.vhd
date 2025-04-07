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

	CRTCEN	:in std_logic;
	GCOLOR	:in std_logic;
	X_BIT	:in std_logic;

	sclk		:in std_logic;
	gclk		:in std_logic;
	rstn	:in std_logic
);
end rampalette;

architecture MAIN of rampalette is
subtype PALDATUM is std_logic_vector(2 downto 0);
type PALDAT_T is array(0 to 9) of PALDATUM;
signal	PAL_R,PAL_B,PAL_G	:PALDAT_T;

signal	IOWRn	:std_logic;
signal	ipalno	:integer range 0 to 7;
signal	lastpal	:std_logic_vector(2 downto 0);
signal	lastno	:integer range 0 to 7;
signal	g_bit	:std_logic;
signal	mode	:std_logic_vector(4 downto 0);

begin

	IOWRn<=IORQn or WRn;
	
	process(sclk,rstn)
	variable inum	:integer range 0 to 8;
	variable vnum	:std_logic_vector(7 downto 0);
	begin
		if(rstn='0')then
			lastpal<="000";
			PAL_R(9)<="000";	-- Don't reset by BASIC ROM
			PAL_B(9)<="000";
			PAL_G(9)<="000";
		elsif(sclk' event and sclk='1')then
			if(IOWRn='0')then
				if(ADR>=x"54" and ADR<=x"5b")then
					vnum:=ADR-x"54";
					if(WDAT(7)='0')then
						inum:=conv_integer(vnum(2 downto 0));
						lastpal<=vnum(2 downto 0);
					else
						inum:=8;
					end if;
					if(PMODE='0')then
						PAL_R(inum)<=(others=>WDAT(1));
						PAL_B(inum)<=(others=>WDAT(0));
						PAL_G(inum)<=(others=>WDAT(2));
					elsif(WDAT(6)='0')then
						PAL_R(inum)<=WDAT(5 downto 3);
						PAL_B(inum)<=WDAT(2 downto 0);
					elsif(WDAT(6)='1')then
						PAL_G(inum)<=WDAT(2 downto 0);
					end if;
				elsif(ADR=x"52" and PMODE='0')then
					PAL_R(9)<=(others=>WDAT(5));
					PAL_B(9)<=(others=>WDAT(4));
					PAL_G(9)<=(others=>WDAT(6));
				end if;
			end if;
		end if;
	end process;
	
	ipalno<=conv_integer(DOTIN);
	lastno<=conv_integer(lastpal);
	g_bit <='0' when ipalno=0 else '1';
	mode  <=PMODE & GCOLOR & X_BIT & g_bit & CRTCEN;
	process(gclk)begin
		if(gclk' event and gclk='1')then
			case(mode)is
				when "00000"|"00001" =>
					-- D-pal, Mono-CG, no T-bit, no G-bit: BG COLOR (Digital)
					ROUT<=PAL_R(9);
					GOUT<=PAL_G(9);
					BOUT<=PAL_B(9);
				when "10000"|"10001" =>
					-- A-pal, Mono-CG, no T-bit, no G-bit: BG COLOR (Analog)
					ROUT<=PAL_R(8);
					GOUT<=PAL_G(8);
					BOUT<=PAL_B(8);
				when "00010" =>
					-- D-pal, Mono-CG, G-bit on, CRTC off: white color
					ROUT<=(others=>'1');
					GOUT<=(others=>'1');
					BOUT<=(others=>'1');
				when "10010" =>
					-- A-pal, Mono-CG, G-bit on, CRTC off: G-bit colored in the last palette
					ROUT<=PAL_R(lastno);
					GOUT<=PAL_G(lastno);
					BOUT<=PAL_B(lastno);
				when "01101"|"01111"|"11101"|"11111" =>
					-- Color-CG, T-bit on: T-bit colored in digital palettes
					ROUT<=(others=>DOTIN(1));
					GOUT<=(others=>DOTIN(2));
					BOUT<=(others=>DOTIN(0));
				when others =>
					ROUT<=PAL_R(ipalno);
					GOUT<=PAL_G(ipalno);
					BOUT<=PAL_B(ipalno);
			end case;
		end if;
	end process;
	
end MAIN;