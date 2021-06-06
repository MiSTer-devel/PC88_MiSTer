LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity KBMAP is
generic(
	CLKCYC	:integer	:=20000;
	SFTCYC	:integer	:=400
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	RDn		:in std_logic;
	DAT		:out std_logic_vector(7 downto 0);
	OE		:out std_logic;

	KBCLKIN	:in std_logic;
	KBCLKOUT:out std_logic;
	KBDATIN	:in std_logic;
	KBDATOUT:out std_logic;
	
	KBDAT	:out std_logic_vector(7 downto 0);
	KBRX	:out std_logic;
	KBEN	:in std_logic	:='1';
	
	monout	:out std_logic_vector(7 downto 0);
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end KBMAP;
architecture MAIN of KBMAP is
component KBIO
	PORT
	(
		address_a		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data_a		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		wren_a		: IN STD_LOGIC  := '0';
		wren_b		: IN STD_LOGIC  := '0';
		q_a		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

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
signal	KB_COL		:std_logic;
signal	KB_PERR		:std_logic;
signal	WAITCNT		:integer range 0 to 5;
constant waitcont	:integer	:=1;
constant waitsep	:integer	:=20;
constant waitccount	:integer	:=waitcont*SFTCYC;
constant waitscount	:integer	:=waitsep*SFTCYC;
signal	WAITSFT		:integer range 0 to waitscount;
signal	CAPSen		:std_logic;
signal	KANAen		:std_logic;
signal	nCAPS0		:std_logic;
signal	nKANA0		:std_logic;
signal	lCAPSf0		:std_logic;
signal	lKANAf0		:std_logic;
	
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
	
		KBRAM	:KBIO port map(
		address_a		=>ADR(3 downto 0),
		address_b		=>WRADR,
		clock			=>clk,
		data_a			=>(others=>'0'),
		data_b			=>WRDAT,
		wren_a			=>'0',
		wren_b			=>WE,
		q_a				=>DAT,
		q_b				=>RDDAT
	);
	
	OE<=	'0' when IORQn='1' or RDn='1' else
			'0' when ADR(7 downto 4)/=x"0" else
			'0' when ADR=x"0f" else
			'1';
	
	KBSFT	:sftclk generic map(CLKCYC,SFTCYC,1) port map("1",SFT,clk,rstn);
	
	KB	:KBIF port map(
	DATIN	=>KB_TXDAT,
	DATOUT	=>KB_RXDAT,
	WRn		=>KB_WRn,
	BUSY	=>KB_BUSY,
	RXED	=>KB_RXED,
	RESET	=>KB_RESET,
	COL		=>KB_COL,
	PERR	=>KB_PERR,
	
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
			lKANAf0<='1';
			lCAPSf0<='1';
			nKANA0<='0';
			nCAPS0<='0';
			BITSEL<=(others=>'0');
			KB_TXDAT<=(others=>'0');
		elsif(clk' event and clk='1')then
			WE<='0';
			KB_WRn<='1';
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
						if(WRADR=x"e")then
							WRDAT<="01111111";
						else
							WRDAT<=(others=>'1');
						end if;
						WE<='1';
						KBSTATE<=KS_CLRRAM1;
					else
						KBSTATE<=KS_RESET;
						WAITSFT<=waitscount;
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
--							E0en<='0';
							TBLADR<=KB_RXDAT;
							WAITCNT<=2;
						end if;
					end if;
				when KS_RDTBL =>
					if(TBLDAT(7 downto 4)=x"f")then
						KBSTATE<=KS_IDLE;
					else
						WRADR<=TBLDAT(7 downto 4);
						BITSEL<=TBLDAT(2 downto 0);
						KBSTATE<=KS_RDRAM;
					end if;
				when KS_RDE0TBL =>
					if(E0TBLDAT(7 downto 4)=x"f")then
						KBSTATE<=KS_IDLE;
					else
						WRADR<=E0TBLDAT(7 downto 4);
						BITSEL<=E0TBLDAT(2 downto 0);
						KBSTATE<=KS_RDRAM;
					end if;
				when KS_RDRAM =>
					KBSTATE<=KS_WRRAM;
				when KS_WRRAM =>
					if(WRADR=x"8" and BITSEL="101")then
						if(F0en='0' and lKANAf0='1')then
							nKANA0<=KANAen;
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
						elsif(F0en='1' and nKANA0='1')then
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
						lKANAf0<=F0en;
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
