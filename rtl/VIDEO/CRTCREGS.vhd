LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CRTCREGS is
generic(
	DATADR	:std_logic_vector(7 downto 0)	:=x"50";
	CMDADR	:std_logic_vector(7 downto 0)	:=x"51"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	WRn		:in std_logic;
	RDn		:in std_logic;
	DATIN	:in std_logic_vector(7 downto 0);
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;

	CURL	:out std_logic_vector(4 downto 0);
	CURC	:out std_logic_vector(6 downto 0);
	CURE	:out std_logic;
	CURM	:out std_logic;
	CBLINK	:out std_logic;
	VMODE	:out std_logic;
	CRTCen	:out std_logic;
	DMAMODE	:out std_logic;
	H		:out std_logic_vector(6 downto 0);	--Horizontal characters
	B		:out std_logic_vector(1 downto 0);	--Cursor blink
	L		:out std_logic_vector(5 downto 0);	--Vertical Characters
	S		:out std_logic;						--??
	C		:out std_logic_vector(1 downto 0);	--??
	R		:out std_logic_vector(4 downto 0);	--Character height
	V		:out std_logic_vector(2 downto 0);	--Vertical porch
	Z		:out std_logic_vector(4 downto 0);	--Horizontal porch
	AT1		:out std_logic;						--??
	AT0		:out std_logic;						--Color
	SC		:out std_logic;						--??
	ATTR	:out std_logic_vector(4 downto 0);	--Attribute length
	
	mon0	:out std_logic_vector(7 downto 0);
	mon1	:out std_logic_vector(7 downto 0);
	mon2	:out std_logic_vector(7 downto 0);
	mon3	:out std_logic_vector(7 downto 0);
	mon4	:out std_logic_vector(7 downto 0);

	clk		:in std_logic;
	rstn	:in std_logic
);
end CRTCREGS;

architecture MAIN of CRTCREGS is
signal	CURCMD	:std_logic_vector(7 downto 0);
signal	DATNUM	:integer range 0 to 7;
signal	IOWRn	:std_logic;
signal	lWRn	:std_logic;
begin
	IOWRn<=IORQn or WRn;
	process(clk,rstn)begin
		if(rstn='0')then
			CURL<=(others=>'0');
			CURC<=(others=>'0');
			CURE<='0';
			CURM<='0';
			CBLINK<='0';
			CURCMD<=(others=>'0');
			DATNUM<=0;
			CRTCen<='0';
			DMAMODE<='0';
			mon0<=x"00";
			mon1<=x"00";
			mon2<=x"00";
			mon3<=x"00";
			mon4<=x"00";
		elsif(clk' event and clk='0')then
			if(IOWRn='0' and lWRn='1')then
				case ADR is
				when CMDADR =>
					CURCMD<=DATIN;
					DATNUM<=0;
					DMAMODE<='0';
					case DATIN is
					when x"00" =>	--CRTC reset
						CURL<=(others=>'0');
						CURC<=(others=>'0');
						CURE<='0';
						CURM<='0';
						CBLINK<='0';
						CRTCen<='0';
					when x"20" =>	--Start display
						CRTCen<='1';
					when x"43" =>	--Interrupt Enable
					when x"80" =>	--cursor off
						CURE<='0';
					when x"81" =>	--cursor on
						CURE<='1';
					when others =>
					end case;
				when DATADR=>
					case CURCMD is
					when x"00" =>
						case DATNUM is
						when 0 =>
							DMAMODE<=DATIN(7);
							H<=DATIN(6 downto 0);
							mon0<=DATIN;
						when 1 =>
							B<=DATIN(7 downto 6);
							L<=DATIN(5 downto 0);
							if(DATIN(5 downto 0)="010011")then	--x"93":20 Lines
								VMODE<='0';
							elsif(DATIN(5 downto 0)="011000")then	--x"98":25 Lines
								VMODE<='1';
							end if;
							mon1<=DATIN;
						when 2 =>
							S<=DATIN(7);
							C<=DATIN(6 downto 5);
							R<=DATIN(4 downto 0);
							mon2<=DATIN;
						when 3 =>
							V<=DATIN(7 downto 5);
							Z<=DATIN(4 downto 0);
							mon3<=DATIN;
						when 4 =>
							AT1<=DATIN(7);
							AT0<=DATIN(6);
							SC<=DATIN(5);
							ATTR<=DATIN(4 downto 0);
							mon4<=DATIN;
						when others=>
						end case;
					when x"80" =>
						case DATNUM is
						when 0 =>
							CURC<=DATIN(6 downto 0);
						when 1 =>
							CURL<=DATIN(4 downto 0);
						when others =>
						end case;
					when x"81" =>
						case DATNUM is
						when 0 =>
							CURC<=DATIN(6 downto 0);
						when 1 =>
							CURL<=DATIN(4 downto 0);
						when others =>
						end case;
					when others =>
					end case;
					if(DATNUM<7)then
						DATNUM<=DATNUM+1;
					end if;
				when others =>
				end case;
			end if;
			lWRn<=IOWRn;
		end if;
	end process;
	
	DATOUT<=CURCMD;
	DATOE<='1' when ADR=CMDADR and IORQn='0' and RDn='0' else '0';
	
end MAIN;
