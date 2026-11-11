LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity KBMAP is
generic(
	CLKCYC	:integer	:=20000;
	SFTCYC	:integer	:=400
);
port(
	SCANADR	:in std_logic_vector(3 downto 0);
	SCANDAT	:out std_logic_vector(7 downto 0);
	INITDONE:out std_logic;

	KBCLKIN	:in std_logic;
	KBCLKOUT:out std_logic;
	KBDATIN	:in std_logic;
	KBDATOUT:out std_logic;
	
	KBDAT	:out std_logic_vector(7 downto 0);
	KBRX	:out std_logic;
	KBEN	:in std_logic	:='1';
	USLAYOUT:in std_logic	:='0';
	
	monout	:out std_logic_vector(7 downto 0);
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end KBMAP;
architecture MAIN of KBMAP is
component KBIF
generic(
	SFTCYC	:integer	:=400;		--kHz
	STCLK	:integer	:=150;		--usec
	TOUT	:integer	:=150		--usec
);
port(
	DATIN	:in std_logic_vector(7 downto 0);
	DATOUT	:out std_logic_vector(7 downto 0);
	WRn		:in std_logic;
	BUSY	:out std_logic;
	RXED	:out std_logic;
	RESET	:in std_logic;
	COL		:out std_logic;
	PERR	:out std_logic;
	
	KBCLKIN	:in	std_logic;
	KBCLKOUT :out std_logic;
	KBDATIN	:in std_logic;
	KBDATOUT :out std_logic;
	
	SFT		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component SFTCLK
generic(
	SYS_CLK	:integer	:=20000;
	OUT_CLK	:integer	:=1600;
	selWIDTH :integer	:=2
);
port(
	sel		:in std_logic_vector(selWIDTH-1 downto 0);
	SFT		:out std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component KBTBLN
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

component KBTBLE0
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

signal	WRADR	:std_logic_vector(3 downto 0);
signal	RDDAT	:std_logic_vector(7 downto 0);
signal	WRDAT	:std_logic_vector(7 downto 0);
signal	WE		:std_logic;
signal	E0en	:std_logic;
signal	F0en	:std_logic;
signal	SFT		:std_logic;
signal	TBLADR	:std_logic_vector(7 downto 0);
signal	TBLDAT	:std_logic_vector(7 downto 0);
signal	E0TBLDAT:std_logic_vector(7 downto 0);
signal	BITSEL	:std_logic_vector(2 downto 0);
signal	INITDONEb	:std_logic;

--The key rows, held in registers so that a row read at any clock is the value
--before or after that clock's write. Rows 0 to 14 start as KS_CLRRAM leaves
--them; row 15 is never written.
type KBROW_T is array(0 to 15) of std_logic_vector(7 downto 0);
signal	KBROW	:KBROW_T	:=(others=>(others=>'1'));
attribute ramstyle	:string;
attribute ramstyle of KBROW	:signal is "logic";


type KBSTATE_T is (KS_IDLE,KS_CLRRAM,KS_CLRRAM1,KS_RESET,KS_RESET_BAT,KS_IDRD,KS_IDRD_ACK,KS_IDRD_LB,KS_IDRD_HB,KS_LEDS,KS_LEDW,KS_LEDB,KS_LEDS_ACK,KS_RDTBL,KS_RDE0TBL,KS_RDRAM,KS_WRRAM);
signal	KBSTATE	:KBSTATE_T;
--	signal	KBSTATE	:integer range 0 to 15;
--	constant	KS_IDLE			:integer	:=0;
--	constant	KS_CLRRAM		:integer	:=1;
--	constant	KS_CLRRAM1		:integer	:=2;
--	constant	KS_RESET		:integer	:=3;
--	constant	KS_RESET_BAT	:integer	:=4;
--	constant	KS_IDRD			:integer	:=5;
--	constant	KS_IDRD_ACK		:integer	:=6;
--	constant	KS_IDRD_LB		:integer	:=7;
--	constant	KS_IDRD_HB		:integer	:=8;
--	constant	KS_LEDS			:integer	:=9;
--	constant	KS_LEDB			:integer	:=10;
--	constant	KS_LEDS_ACK		:integer	:=11;
--	constant	KS_RDTBL		:integer	:=12;
--	constant	KS_RDE0TBL		:integer	:=13;
--	constant	KS_RDRAM		:integer	:=14;
--	constant	KS_WRRAM		:integer	:=15;

signal	KB_TXDAT	:std_logic_vector(7 downto 0);
signal	KB_RXDAT	:std_logic_vector(7 downto 0);
signal	KB_WRn		:std_logic;
signal	KB_BUSY		:std_logic;
signal	KB_RXED		:std_logic;
signal	KB_RESET	:std_logic;
-- signal	KB_COL		:std_logic;
-- signal	KB_PERR		:std_logic;
signal	WAITCNT		:integer range 0 to 5;
constant waitcont	:integer	:=1;
constant waitsep	:integer	:=20;
constant waitccount	:integer	:=waitcont*SFTCYC;
constant waitscount	:integer	:=waitsep*SFTCYC;
signal	WAITSFT		:integer range 0 to waitscount;
signal	CAPSen		:std_logic;
signal	KANAen		:std_logic;
signal	RALTH		:std_logic;	--right Alt held
signal	RALTK		:std_logic;	--right Alt was pressed as KANA (US layout), kept until it is released
signal	KSRC		:std_logic;	--the KANA cell is written for right Alt, not 13h
signal	lRALTf0		:std_logic;	--like lKANAf0, for right Alt
signal	nRALT0		:std_logic;	--like nKANA0, for right Alt
signal	nCAPS0		:std_logic;
signal	nKANA0		:std_logic;
signal	lCAPSf0		:std_logic;
signal	lKANAf0		:std_logic;

--US layout: the 14 keys whose US keycaps differ from the PC-8801 keys. Each key's
--handling is fixed when it is first pressed and kept until it is released.
constant OW_NONE	:std_logic_vector(2 downto 0)	:="000";
constant OW_NORM	:std_logic_vector(2 downto 0)	:="001";	--as before, through KBROW
constant OW_HOLD	:std_logic_vector(2 downto 0)	:="010";	--another cell, SHIFT as is
constant OW_SHCH	:std_logic_vector(2 downto 0)	:="011";	--another cell, SHIFT added or removed
constant OW_NOTH	:std_logic_vector(2 downto 0)	:="100";	--nothing (` has no PC-8801 key)
type OWN_T is array(0 to 13) of std_logic_vector(2 downto 0);
type DST_T is array(0 to 13) of std_logic_vector(6 downto 0);
signal	OWN		:OWN_T;
signal	DST		:DST_T;		--row & bit
signal	SADD	:std_logic_vector(13 downto 0);	--1: add SHIFT, 0: remove SHIFT
--The key that changes SHIFT is shown one at a time: SHIFT first, the cell TKEY later,
--the cell for at least THOLD, then the cell is taken away and SHIFT TKEY later.
constant TKEYC	:integer	:=20*CLKCYC;
constant THOLDC	:integer	:=100*CLKCYC;	--with 60 ms, the N88-BASIC prompt missed presses shorter than about 80 ms
signal	CURV	:std_logic;
signal	CURR	:std_logic;		--released, waiting for THOLD
signal	CURI	:integer range 0 to 13;
signal	CURP	:integer range 0 to 3;	--0: SHIFT only, 1: cell shown, 2: THOLD met, 3: cell taken away
signal	NXTV	:std_logic;
signal	NXTR	:std_logic;
signal	NXTI	:integer range 0 to 13;
signal	UTIM	:integer range 0 to THOLDC;

function US_IDX(sc :std_logic_vector(7 downto 0)) return integer is
begin
	case sc is
	when x"1E" => return 0;		--2 @
	when x"36" => return 1;		--6 ^
	when x"3D" => return 2;		--7 &
	when x"3E" => return 3;		--8 *
	when x"46" => return 4;		--9 (
	when x"45" => return 5;		--0 )
	when x"4E" => return 6;		--- _
	when x"55" => return 7;		--= +
	when x"54" => return 8;		--[ {
	when x"5B" => return 9;		--] }
	when x"5D" => return 10;	--\ |
	when x"4C" => return 11;	--; :
	when x"52" => return 12;	--' "
	when x"0E" => return 13;	--` ~
	when others => return 14;
	end case;
end US_IDX;

--handling & add SHIFT & row & bit, for the key without and with SHIFT
function US_ENT(i :integer; sft :std_logic) return std_logic_vector is
begin
	if(sft='0')then
		case i is
		when 7 => return OW_SHCH & '1' & x"5" & "111";	--= : SHIFT+-
		when 8 => return OW_HOLD & '0' & x"5" & "011";	--[
		when 9 => return OW_HOLD & '0' & x"5" & "101";	--]
		when 10 => return OW_HOLD & '0' & x"5" & "100";	--\ : yen
		when 12 => return OW_SHCH & '1' & x"6" & "111";	--' : SHIFT+7
		when 13 => return OW_NOTH & '0' & x"0" & "000";	--`
		when others => return OW_NORM & '0' & x"0" & "000";
		end case;
	else
		case i is
		when 0 => return OW_SHCH & '0' & x"2" & "000";	--@
		when 1 => return OW_SHCH & '0' & x"5" & "110";	--^
		when 2 => return OW_HOLD & '0' & x"6" & "110";	--& : SHIFT+6
		when 3 => return OW_HOLD & '0' & x"7" & "010";	--* : SHIFT+:
		when 4 => return OW_HOLD & '0' & x"7" & "000";	--( : SHIFT+8
		when 5 => return OW_HOLD & '0' & x"7" & "001";	--) : SHIFT+9
		when 6 => return OW_HOLD & '0' & x"7" & "111";	--_ : SHIFT+ro
		when 7 => return OW_HOLD & '0' & x"7" & "011";	--+ : SHIFT+;
		when 8 => return OW_HOLD & '0' & x"5" & "011";	--{
		when 9 => return OW_HOLD & '0' & x"5" & "101";	--}
		when 10 => return OW_HOLD & '0' & x"5" & "100";	--|
		when 11 => return OW_SHCH & '0' & x"7" & "010";	--:
		when 12 => return OW_HOLD & '0' & x"6" & "010";	--" : SHIFT+2
		when 13 => return OW_HOLD & '0' & x"5" & "110";	--~ : SHIFT+^
		when others => return OW_NORM & '0' & x"0" & "000";
		end case;
	end if;
end US_ENT;
	
begin
--	MONOUT<="00000000" when KBSTATE=KS_IDLE else
--			"00000001" when KBSTATE=KS_CLRRAM or KBSTATE=KS_CLRRAM1 else
--			"00000010" when KBSTATE=KS_RESET or KBSTATE=KS_RESET_BAT else
--			"00000100" when KBSTATE=KS_IDRD or KBSTATE=KS_IDRD_ACK else
--			"00001000" when KBSTATE=KS_IDRD_LB or KBSTATE=KS_IDRD_HB else
--			"00010000" when KBSTATE=KS_LEDS or KBSTATE=KS_LEDB else
--			"00100000" when KBSTATE=KS_LEDS_ACK else
--			"01000000" when KBSTATE=KS_RDTBL or KBSTATE=KS_RDE0TBL else
--			"10000000" when KBSTATE=KS_RDRAM or KBSTATE=KS_WRRAM else
--			"00000000";
--	monout<= KB_RXDAT;
--	monout<=TBLADR;
	monout<=TBLDAT;
--	monout<=WRDAT;
	
	process(clk)begin
		if(clk' event and clk='1')then
			if(WE='1')then
				KBROW(conv_integer(WRADR))<=WRDAT;
			end if;
		end if;
	end process;
	RDDAT<=KBROW(conv_integer(WRADR));
	--The keys added on the FH set their own cells in rows 12 to 14, and also read as
	--the older keys that do the same thing, as on the FH: both RETURNs as RETURN,
	--both SHIFTs as SHIFT, F6 to F10 as SHIFT and F1 to F5, INS as SHIFT and INS/DEL,
	--BS and DEL as INS/DEL, and the two keys in row 13 bits 0 and 1 as SPACE.
	--The FH has one CTRL. The right CTRL is held in row 14 bit 4, which software
	--still reads as 1, and either CTRL reads as CTRL.
	process(SCANADR,KBROW,OWN,DST,SADD,CURV,CURI,CURP)
	variable r	:std_logic_vector(7 downto 0);
	begin
		r:=KBROW(conv_integer(SCANADR));
		case SCANADR is
		when x"1" =>
			r(7):=r(7) and KBROW(14)(0) and KBROW(14)(1);
		when x"8" =>
			r(6):=r(6) and KBROW(14)(2) and KBROW(14)(3) and KBROW(12)(0) and KBROW(12)(1) and KBROW(12)(2)
				and KBROW(12)(3) and KBROW(12)(4) and KBROW(12)(6);
			r(7):=r(7) and KBROW(14)(4);
			r(3):=r(3) and KBROW(12)(5) and KBROW(12)(6) and KBROW(12)(7);
		when x"9" =>
			r(5 downto 1):=r(5 downto 1) and KBROW(12)(4 downto 0);
			r(6):=r(6) and KBROW(13)(0) and KBROW(13)(1);
		when x"e" =>
			r(4):='1';
		when others =>
		end case;
		--US layout: the cells of the keys held, and SHIFT for the key that changes it
		for i in 0 to 13 loop
			if(OWN(i)=OW_HOLD and DST(i)(6 downto 3)=SCANADR)then
				r(conv_integer(DST(i)(2 downto 0))):='0';
			end if;
		end loop;
		if(CURV='1')then
			if(SADD(CURI)='1')then
				if(SCANADR=x"8")then r(6):='0'; end if;
				if(SCANADR=x"e")then r(2):='0'; end if;
			else
				if(SCANADR=x"8")then r(6):='1'; end if;
				if(SCANADR=x"e")then r(3 downto 2):="11"; end if;
			end if;
			if((CURP=1 or CURP=2) and DST(CURI)(6 downto 3)=SCANADR)then
				r(conv_integer(DST(CURI)(2 downto 0))):='0';
			end if;
		end if;
		SCANDAT<=r;
	end process;
	INITDONE<=INITDONEb;
	
	KBSFT	:sftclk generic map(CLKCYC,SFTCYC,1) port map("1",SFT,clk,rstn);
	
	KB	:KBIF port map(
	DATIN	=>KB_TXDAT,
	DATOUT	=>KB_RXDAT,
	WRn		=>KB_WRn,
	BUSY	=>KB_BUSY,
	RXED	=>KB_RXED,
	RESET	=>KB_RESET,
	-- COL		=>KB_COL,
	-- PERR	=>KB_PERR,
	
	KBCLKIN	=>KBCLKIN,
	KBCLKOUT=>KBCLKOUT,
	KBDATIN	=>KBDATIN,
	KBDATOUT=>KBDATOUT,
	
	SFT		=>SFT,
	clk		=>clk,
	rstn	=>rstn
	);

	
	process(clk,rstn)
	variable iBITSEL	:integer range 0 to 7;
	variable ui		:integer range 0 to 14;
	variable ue		:std_logic_vector(10 downto 0);
	variable usp	:boolean;
	begin
		if(rstn='0')then
			KBSTATE<=KS_CLRRAM;
			WRADR<=(others=>'0');
			WRDAT<=(others=>'0');
			WE<='0';
			E0EN<='0';
			F0EN<='0';
			KB_WRn<='1';
			KB_RESET<='0';
			WAITCNT<=0;
			WAITSFT<=0;
			CAPSen<='0';
			KANAen<='0';
			RALTH<='0';
			RALTK<='0';
			KSRC<='0';
			lRALTf0<='1';
			lKANAf0<='1';
			lCAPSf0<='1';
			nKANA0<='0';
			nRALT0<='0';
			nCAPS0<='0';
			BITSEL<=(others=>'0');
			KB_TXDAT<=(others=>'0');
			INITDONEb<='0';
			OWN<=(others=>OW_NONE);
			CURV<='0';
			CURR<='0';
			CURI<=0;
			CURP<=0;
			NXTV<='0';
			NXTR<='0';
			NXTI<=0;
			UTIM<=0;
		elsif(clk' event and clk='1')then
			WE<='0';
			KB_WRn<='1';
			--The timer waits while KS_RDTBL handles a key, so that both never update
			--the US layout state in one clock.
			if(WAITCNT=0 and WAITSFT=0 and KBSTATE=KS_RDTBL)then
				null;
			elsif(CURV='1')then
				if(UTIM/=0)then
					UTIM<=UTIM-1;
				else
					case CURP is
					when 0 =>
						CURP<=1;
						UTIM<=THOLDC;
					when 1 =>
						CURP<=2;
					when 2 =>
						if(CURR='1' or NXTV='1')then
							CURP<=3;
							UTIM<=TKEYC;
						end if;
					when others =>
						if(CURR='1')then
							OWN(CURI)<=OW_NONE;
						end if;
						--the next key takes over in the same clock, so the SHIFT override never drops
						if(NXTV='1')then
							CURI<=NXTI;
							CURR<=NXTR;
							CURP<=0;
							UTIM<=TKEYC;
							NXTV<='0';
						else
							CURV<='0';
						end if;
					end case;
				end if;
			elsif(NXTV='1')then
				CURV<='1';
				CURI<=NXTI;
				CURR<=NXTR;
				CURP<=0;
				UTIM<=TKEYC;
				NXTV<='0';
			end if;
			if(WAITCNT>0)then
				WAITCNT<=WAITCNT-1;
			elsif(WAITSFT>0)then
				if(SFT='1')then
					WAITSFT<=WAITSFT-1;
				end if;
			else
				case KBSTATE is
				when KS_CLRRAM =>
					if(WRADR/=x"f")then
						WRDAT<=(others=>'1');
						WE<='1';
						KBSTATE<=KS_CLRRAM1;
					else
						KBSTATE<=KS_RESET;
						WAITSFT<=waitscount;
						INITDONEb<='1';
					end if;
				when KS_CLRRAM1 =>
					WRADR<=WRADR+1;
					KBSTATE<=KS_CLRRAM;
				when KS_RESET =>
					if(KB_BUSY='0')then
						KB_TXDAT<=x"ff";
						KB_WRn<='0';
						KBSTATE<=KS_RESET_BAT;
					end if;
				when KS_RESET_BAT =>
					if(KB_RXED='1' and KB_RXDAT=x"aa")then
						WAITSFT<=waitscount;
						KBSTATE<=KS_IDRD;
					end if;
				when KS_IDRD =>
					if(KB_BUSY='0')then
						KB_TXDAT<=x"f2";
						KB_WRn<='0';
						KBSTATE<=KS_IDRD_ACK;
					end if;
				when KS_IDRD_ACK =>
					if(KB_RXED='1' and KB_RXDAT=x"fa")then
						KBSTATE<=KS_IDRD_LB;
					end if;
				when KS_IDRD_LB =>
					if(KB_RXED='1')then
						KBSTATE<=KS_IDRD_HB;
					end if;
				when KS_IDRD_HB =>
					if(KB_RXED='1')then
						WAITSFT<=waitscount;
						KBSTATE<=KS_LEDS;
					end if;
				when KS_LEDS =>
					if(KB_BUSY='0')then
						KB_TXDAT<=x"ed";
						KB_WRn<='0';
						KBSTATE<=KS_LEDW;
						WAITSFT<=1;
					end if;
				when KS_LEDW =>
					if(KB_BUSY='0')then
						WAITSFT<=waitccount;
						KBSTATE<=KS_LEDB;
					end if;
				when KS_LEDB =>
					if(KB_BUSY='0')then
						KB_TXDAT<="00000" & CAPSen & '0' & KANAen;	--assign KANA to SCRlock
						KB_WRn<='0';
						KBSTATE<=KS_LEDS_ACK;
					end if;
				when KS_LEDS_ACK =>
					if(KB_RXED='1')then
--					monout<=KB_RXDAT;
						if(KB_RXDAT=x"fa")then
							WAITSFT<=waitscount;
							KBSTATE<=KS_IDLE;
						elsif(KB_RXDAT=x"fe")then
							WAITSFT<=waitscount;
							KBSTATE<=KS_LEDS;
						end if;
					end if;
				when KS_IDLE =>
					if(KBEN='1' and KB_RXED='1')then
						if(KB_RXDAT=x"e0")then
							E0en<='1';
						elsif(KB_RXDAT=x"f0")then
							F0en<='1';
						else
							if(E0en='1')then
								KBSTATE<=KS_RDE0TBL;
							else
								KBSTATE<=KS_RDTBL;
							end if;
							KSRC<=E0en;
--							E0en<='0';
							TBLADR<=KB_RXDAT;
							WAITCNT<=2;
						end if;
					end if;
				when KS_RDTBL =>
					ui:=US_IDX(TBLADR);
					usp:=false;
					if(ui/=14)then
						if(F0en='0')then
							if(OWN(ui)=OW_NONE)then
								if(USLAYOUT='1' and KANAen='0' and KBROW(8)(4)='1')then
									if(KBROW(14)(2)='0' or KBROW(14)(3)='0')then
										ue:=US_ENT(ui,'1');
									else
										ue:=US_ENT(ui,'0');
									end if;
								else
									ue:=OW_NORM & '0' & x"0" & "000";
								end if;
								OWN(ui)<=ue(10 downto 8);
								if(ue(10 downto 8)/=OW_NORM)then
									usp:=true;
									DST(ui)<=ue(6 downto 0);
									SADD(ui)<=ue(7);
									if(ue(10 downto 8)=OW_SHCH)then
										if(CURV='1' or NXTV='1')then
											if(NXTV='1' and NXTR='1')then
												OWN(NXTI)<=OW_NONE;
											end if;
											NXTV<='1';
											NXTR<='0';
											NXTI<=ui;
										else
											CURV<='1';
											CURR<='0';
											CURI<=ui;
											CURP<=0;
											UTIM<=TKEYC;
										end if;
									end if;
								end if;
							elsif(OWN(ui)/=OW_NORM)then
								--a repeated make: keep how the key is handled
								usp:=true;
								if(OWN(ui)=OW_SHCH)then
									if(CURV='1' and CURI=ui and CURR='1')then
										CURR<='0';
										if(CURP=3)then
											CURP<=0;
											UTIM<=TKEYC;
										end if;
									elsif(NXTV='1' and NXTI=ui)then
										NXTR<='0';
									end if;
								end if;
							end if;
						else
							if(OWN(ui)=OW_NORM)then
								OWN(ui)<=OW_NONE;
							elsif(OWN(ui)/=OW_NONE)then
								usp:=true;
								if(OWN(ui)=OW_SHCH and CURV='1' and CURI=ui)then
									CURR<='1';
								elsif(OWN(ui)=OW_SHCH and NXTV='1' and NXTI=ui)then
									NXTR<='1';
								else
									OWN(ui)<=OW_NONE;
								end if;
							end if;
						end if;
					end if;
					if(usp)then
						KBSTATE<=KS_IDLE;
						E0en<='0';
						F0en<='0';
					elsif(TBLDAT(7 downto 4)=x"f")then
						KBSTATE<=KS_IDLE;
						E0en<='0';
						F0en<='0';
					else
						WRADR<=TBLDAT(7 downto 4);
						BITSEL<=TBLDAT(2 downto 0);
						KBSTATE<=KS_RDRAM;
					end if;
				when KS_RDE0TBL =>
					--US layout: right Alt is KANA (a US keyboard has no KANA key), left Alt stays GRPH
					if(TBLADR=x"11")then
						if(F0en='0')then
							if(RALTH='0')then
								RALTK<=USLAYOUT;
							end if;
							RALTH<='1';
						else
							RALTH<='0';
							RALTK<='0';
						end if;
					end if;
					if(TBLADR=x"11" and ((F0en='0' and ((RALTH='0' and USLAYOUT='1') or (RALTH='1' and RALTK='1'))) or (F0en='1' and RALTK='1')))then
						WRADR<=x"8";
						BITSEL<="101";
						KBSTATE<=KS_RDRAM;
					elsif(E0TBLDAT(7 downto 4)=x"f")then
						KBSTATE<=KS_IDLE;
						E0en<='0';
						F0en<='0';
					else
						WRADR<=E0TBLDAT(7 downto 4);
						BITSEL<=E0TBLDAT(2 downto 0);
						KBSTATE<=KS_RDRAM;
					end if;
				when KS_RDRAM =>
					KBSTATE<=KS_WRRAM;
				when KS_WRRAM =>
					if(WRADR=x"8" and BITSEL="101")then
						if(F0en='0' and ((KSRC='0' and lKANAf0='1') or (KSRC='1' and lRALTf0='1')))then
							--each key keeps its own "turn kana off on release"; pressing one while the other
							--holds it cancels both, so two presses always toggle twice
							if(KSRC='1')then
								if(KANAen='1' and nKANA0='1')then
									nKANA0<='0';
									nRALT0<='0';
								else
									nRALT0<=KANAen;
								end if;
							else
								if(KANAen='1' and nRALT0='1')then
									nRALT0<='0';
									nKANA0<='0';
								else
									nKANA0<=KANAen;
								end if;
							end if;
							for i in 0 to 7 loop
								if(i=5)then
									WRDAT(i)<='0';
								else
									WRDAT(i)<=RDDAT(i);
								end if;
							end loop;
							KANAen<='1';
							WE<='1';
							KBSTATE<=KS_LEDS;
						elsif(F0en='1' and ((KSRC='0' and nKANA0='1') or (KSRC='1' and nRALT0='1')))then
							if(KSRC='1')then
								nRALT0<='0';
							else
								nKANA0<='0';
							end if;
							for i in 0 to 7 loop
								if(i=5)then
									WRDAT(i)<='1';
								else
									WRDAT(i)<=RDDAT(i);
								end if;
							end loop;
							KANAen<='0';
							WE<='1';
							KBSTATE<=KS_LEDS;
						else
							KBSTATE<=KS_IDLE;
						end if;
						if(KSRC='1')then
							lRALTf0<=F0en;
						else
							lKANAf0<=F0en;
						end if;
					elsif(WRADR=x"a" and BITSEL="111")then
						if(F0en='0' and lCAPSf0='1')then
							nCAPS0<=CAPSen;
							for i in 0 to 7 loop
								if(i=7)then
									WRDAT(i)<='0';
								else
									WRDAT(i)<=RDDAT(i);
								end if;
							end loop;
							CAPSen<='1';
							WE<='1';
							WAITSFT<=waitscount;
							KBSTATE<=KS_LEDS;
						elsif(F0en='1' and nCAPS0='1')then
							for i in 0 to 7 loop
								if(i=7)then
									WRDAT(i)<='1';
								else
									WRDAT(i)<=RDDAT(i);
								end if;
							end loop;
							CAPSen<='0';
							WE<='1';
							WAITSFT<=waitscount;
							KBSTATE<=KS_LEDS;
						else
							KBSTATE<=KS_IDLE;
						end if;
						lCAPSf0<=F0en;
					else
						iBITSEL:=conv_integer(BITSEL);
						for i in 0 to 7 loop
							if(i=iBITSEL)then
								if(F0en='1')then
									WRDAT(i)<='1';
								else
									WRDAT(i)<='0';
								end if;
							else
								WRDAT(i)<=RDDAT(i);
							end if;
						end loop;
						KBSTATE<=KS_IDLE;
						WE<='1';
					end if;
					E0en<='0';
					F0en<='0';
				when others =>
					KBSTATE<=KS_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	NTBL	:KBTBLN port map(TBLADR,clk,TBLDAT);
	E0TBL	:KBTBLE0 port map(TBLADR,clk,E0TBLDAT);
	
	KBDAT<=KB_RXDAT;
	KBRX<=KB_RXED when KBSTATE=KS_IDLE else '0';
	
end MAIN;
