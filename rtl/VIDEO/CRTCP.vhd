LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.VIDEO_TIMING_pkg.all;

entity CRTCP is
port(
	IORQn		:in std_logic;
	WRn			:in std_logic;
	ADR			:in std_logic_vector(7 downto 0);
	WDAT		:in std_logic_vector(7 downto 0);
	PALEN		:in	std_logic	:='1';
	
	TRAM_ADR	:out std_logic_vector(11 downto 0);
	TRAM_DAT	:in std_logic_vector(8 downto 0);
	
	GRAMADR		:out std_logic_vector(13 downto 0);
	GRAMRD		:out std_logic;
	GRAMWAIT	:in std_logic;
	GRAMDAT0	:in std_logic_vector(7 downto 0);
	GRAMDAT1	:in std_logic_vector(7 downto 0);
	GRAMDAT2	:in std_logic_vector(7 downto 0);
	
	ROUT		:out std_logic_vector(2 downto 0);
	GOUT		:out std_logic_vector(2 downto 0);
	BOUT		:out std_logic_vector(2 downto 0);
	VIDEN		:out std_logic;
	
	HSYNC		:out std_logic;
	VSYNC		:out std_logic;
	
	HMODE		:in std_logic;		-- 1:80chars 0:40chars
	VMODE		:in std_logic;		-- 1:25lines 0:20lines
	PMODE		:in std_logic;		-- 1:512 colors 0:8 colors
	TXTMODE		:in std_logic	:='0';

	GRAPHEN		:in std_logic;
	LOWRES		:in std_logic;
	GCOLOR		:in std_logic;
	MONOEN		:in std_logic_vector(2 downto 0);
	TXTEN		:in std_logic;
	CRTCEN		:in std_logic;
	REVERSE		:in std_logic;

	CURL		:in std_logic_vector(4 downto 0);
	CURC		:in std_logic_vector(6 downto 0);
	CURE		:in std_logic;
	CURM		:in std_logic;
	CBLINK		:in std_logic;

	VRTC		:out std_logic;
	HRTC		:out std_logic;
	CURVMODE	:out std_logic;		-- VMODE the text screen draws the frame with
	
	FRAMWADR	:in std_logic_Vector(12 downto 0);
	FRAMWDAT	:in std_logic_vector(7 downto 0);
	FRAMWR	:in std_logic;
	FRAM8WR	:in std_logic	:='0';	-- 8x8 font, at FRAMWADR(10 downto 0)

	gclk		:out std_logic;
	CE3			:out std_logic;
	cpuclk		:in std_logic;
	cpuce		:in std_logic := '1';
	clk			:in std_logic;
	rstn		:in std_logic;

	--24kHz or 15kHz timing: lines and blanking from the CRTC parameters
	VT24		:in std_logic	:='0';
	VT15		:in std_logic	:='0';
	CTYPE		:in std_logic_vector(1 downto 0)	:="11";	-- cursor (24kHz, 15kHz): 1x whole row, x1 blink
	SETL		:in std_logic_vector(5 downto 0)	:=(others=>'0');
	SETR		:in std_logic_vector(4 downto 0)	:=(others=>'0');
	SETV		:in std_logic_vector(2 downto 0)	:=(others=>'0');
	SETOK		:in std_logic	:='0';
	TSET		:out std_logic_vector(17 downto 0)	-- rows, height, first request line, for TRAMCONV
);
end CRTCP;

architecture MAIN of CRTCP is
component VTIMING is
generic(
	DOTPU	:integer	:=8;
	HWIDTH	:integer	:=800;
	VWIDTH	:integer	:=525;
	HVIS	:integer	:=640;
	VVIS	:integer	:=400;
	CPD		:integer	:=3;		--clocks per dot
	HFP		:integer	:=3;
	HSY		:integer	:=12;
	VFP		:integer	:=51;
	VSY		:integer	:=2
);	
port(
	VT24	:in std_logic	:='0';
	VT15	:in std_logic	:='0';
	VEND24	:in integer range 0 to VWMAX-1	:=VWMAX-1;

	VCOUNT	:out integer range 0 to VWMAX-1;
	HUCOUNT	:out integer range 0 to HUWMAX-1;
	UCOUNT	:out integer range 0 to DOTPU-1;
	
	HCOMP	:out std_logic;
	VCOMP	:out std_logic;
	
	clk2	:out std_logic;
	clk3	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;
	CE3		:out std_logic
);
end component;

component TEXTSCR2 is
port(
	TRAMADR	:out std_logic_vector(11 downto 0);
	TRAMDAT	:in std_logic_vector(8 downto 0);
	
	FRAMADR	:out std_logic_vector(11 downto 0);
	FRAMDAT0:in std_logic_vector( 7 downto 0);
	FRAMDAT1:in std_logic_vector( 7 downto 0);
	FRAMADR8:out std_logic_vector(10 downto 0);
	FRAMDAT8:in std_logic_vector( 7 downto 0);

	BITOUT	:out std_logic;
	FGCOLOR	:out std_logic_vector(2 downto 0);
	BGCOLOR	:out std_logic_vector(2 downto 0);
	BLINK	:out std_logic;
	
	CURL	:in std_logic_vector(4 downto 0);
	CURC	:in std_logic_vector(6 downto 0);
	CURE	:in std_logic;
	CURM	:in std_logic;
	CBLINK	:in std_logic;

	HMODE	:in std_logic;
	VMODE	:in std_logic;
	
	UCOUNT	:in integer range 0 to DOTPU-1;
	HUCOUNT	:in integer range 0 to HUWMAX-1;
	VCOUNT	:in integer range 0 to VWMAX-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;

	clk		:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1';

	CURVMODE	:out std_logic;

	VT24	:in std_logic	:='0';
	VT15	:in std_logic	:='0';
	VRET24	:in integer range 0 to VWMAX-1	:=VRETMIN24;
	CHRL24	:in integer range CHRLMIN24 to CHRLMAX24	:=CHRLDEF24
);
end component;

component GRAPHSCR
port(
	GRAMADR	:out std_logic_vector(13 downto 0);
	GRAMRD	:out std_logic;
	GRAMWAIT:in std_logic;
	GRAMDAT0:in std_logic_vector(7 downto 0);
	GRAMDAT1:in std_logic_vector(7 downto 0);
	GRAMDAT2:in std_logic_vector(7 downto 0);

	BITOUT0	:out std_logic;
	BITOUT1	:out std_logic;
	BITOUT2	:out std_logic;
	BITOUTM	:out std_logic;
	BITOUTE	:out std_logic;
	
	GRAPHEN	:in std_logic;
	LOWRES	:in std_logic;
	MONOEN		:in std_logic_vector(2 downto 0);
	
	UCOUNT	:in integer range 0 to DOTPU-1;
	HUCOUNT	:in integer range 0 to HUWMAX-1;
	VCOUNT	:in integer range 0 to VWMAX-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1';

	VT24	:in std_logic	:='0';
	VT15	:in std_logic	:='0';
	VRET24	:in integer range 0 to VWMAX-1	:=VRETMIN24
);
end component;

component synccont2
generic(
	DOTPU	:integer	:=8;
	HWIDTH	:integer	:=800;
	VWIDTH	:integer	:=525;
	HVIS	:integer	:=640;
	VVIS	:integer	:=400;
	VVIS2	:integer	:=480;
	CPD		:integer	:=3;		--clocks per dot
	HFP		:integer	:=3;
	HSY		:integer	:=12;
	VFP		:integer	:=51;
	VSY		:integer	:=2
);	
port(
	VT24	:in std_logic	:='0';
	VT15	:in std_logic	:='0';
	VRET24	:in integer range 0 to VWMAX-1	:=VRETMIN24;

	UCOUNT	:in integer range 0 to DOTPU-1;
	HUCOUNT	:in integer range 0 to HUWMAX-1;
	VCOUNT	:in integer range 0 to VWMAX-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;

	HSYNC	:out std_logic;
	VSYNC	:out std_logic;
	VISIBLE	:out std_logic;
	VIDEN		:out std_logic;
	
	HRTC	:out std_logic;
	VRTC	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1'
);
end component;

component fontram
	PORT
	(
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

component font8ram
	port(
		clock		:in std_logic := '1';
		data		:in std_logic_vector(7 downto 0);
		rdaddress	:in std_logic_vector(10 downto 0);
		wraddress	:in std_logic_vector(10 downto 0);
		wren		:in std_logic := '0';
		q			:out std_logic_vector(7 downto 0)
	);
end component;

component palette
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
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component rampalette
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
	sce		:in std_logic := '1';
	gclk		:in std_logic;
	gce		:in std_logic := '1';
	rstn	:in std_logic
);
end component;

signal VCOUNT	:integer range 0 to VWMAX-1;
signal HUCOUNT	:integer range 0 to HUWMAX-1;
signal UCOUNT	:integer range 0 to DOTPU-1;
signal HCOMP	:std_logic;
signal VCOMP	:std_logic;
	
signal clk2		:std_logic;
signal clk3		:std_logic;
signal ce3b		:std_logic;

signal T_BIT	:std_logic;
signal X_BIT	:std_logic;
signal GM_BIT	:std_logic;
signal G0_BIT	:std_logic;
signal G1_BIT	:std_logic;
signal G2_BIT	:std_logic;
signal GE_BIT	:std_logic;
signal T_FGCOLOR:std_logic_vector(2 downto 0);
signal T_BGCOLOR:std_logic_vector(2 downto 0);
signal T_BLINK	:std_logic;

signal FRAMADR	:std_logic_vector(11 downto 0);
signal FRAMDAT	:std_logic_vector(7 downto 0);
signal FRAMADR8	:std_logic_vector(10 downto 0);
signal FRAMDAT8	:std_logic_vector(7 downto 0);
signal T_CURM	:std_logic;
signal T_CBLINK	:std_logic;
signal GRAMDAT	:std_logic_vector(7 downto 0);
signal VISIBLE	:std_logic;
signal FRAMWEN,GRAMWEN	:std_logic;

signal G0F_BIT	:std_logic;
signal G1F_BIT	:std_logic;
signal G2F_BIT	:std_logic;
signal COLNUM	:std_logic_vector(2 downto 0);
signal COLNUMN	:std_logic_vector(2 downto 0);
signal COLNUMT	:std_logic_vector(2 downto 0);
signal RED		:std_logic_vector(2 downto 0);
signal GRN		:std_logic_vector(2 downto 0);
signal BLE		:std_logic_vector(2 downto 0);

signal PAL_RED		:std_logic_vector(2 downto 0);
signal PAL_GRN		:std_logic_vector(2 downto 0);
signal PAL_BLE		:std_logic_vector(2 downto 0);

signal	VISIBLEd	:std_logic;
signal	COLNUMd	:std_logic_vector(2 downto 0);
signal	GE_BITd	:std_logic;
signal	X_BITd	:std_logic;
signal	VIDENb	:std_logic;

signal F_REVERSE :std_logic;
signal A_REVERSE :std_logic_vector(2 downto 0);

--24kHz, 15kHz: the CRTC parameters used for the frame being drawn, taken at the frame boundary
signal	aROWS	:integer range 1 to ROWSMAX24	:=ROWSDEF24;
signal	aCHRL	:integer range CHRLMIN24 to CHRLMAX24	:=CHRLDEF24;
signal	aVRET	:integer range 0 to VWMAX-1	:=VRETDEF24;
signal	aVEND	:integer range 0 to VWMAX-1	:=ROWSDEF24*CHRLDEF24+VRETDEF24-1;
signal	aREQ0	:integer range 0 to 255	:=VRETDEF24-CHRLDEF24;
signal	nROWS	:integer range 1 to 64;
signal	nCHRL	:integer range 1 to 32;
signal	nVRET	:integer range 0 to 256;
signal	pVCOMP	:std_logic;
signal	aDEF	:std_logic;	-- the clock after reset
signal	vretmin	:integer range 0 to VRETMIN24;

begin
	TIM	:vtiming generic map(
	DOTPU	=>DOTPU,
	HWIDTH	=>HWIDTH,
	VWIDTH	=>VWIDTH,
	HVIS	=>HVIS,
	VVIS	=>VVIS,
	CPD		=>CPD,
	HFP		=>HFP,
	HSY		=>HSY,
	VFP		=>VFP,
	VSY		=>VSY
) port map(VT24,VT15,aVEND,VCOUNT,HUCOUNT,UCOUNT,HCOMP,VCOMP,clk2,clk3,clk,rstn,ce3b);
	TXT	:textscr2 port map(TRAM_ADR,TRAM_DAT,FRAMADR,FRAMDAT,GRAMDAT,FRAMADR8,FRAMDAT8,T_BIT,T_FGCOLOR,T_BGCOLOR,T_BLINK,CURL,CURC,CURE,T_CURM,T_CBLINK,HMODE,VMODE,UCOUNT,HUCOUNT,VCOUNT,HCOMP,VCOMP,clk,rstn,ce3b,CURVMODE,VT24,VT15,aVRET,aCHRL);
	GRP	:graphscr port map(GRAMADR,GRAMRD,GRAMWAIT,GRAMDAT0,GRAMDAT1,GRAMDAT2,G0_BIT,G1_BIT,G2_BIT,GM_BIT,GE_BIT,GRAPHEN,LOWRES,MONOEN,UCOUNT,HUCOUNT,VCOUNT,HCOMP,VCOMP,clk,rstn,ce3b,VT24,VT15,aVRET);

	--31kHz: the cursor is the bottom 4 lines, blinking. 24kHz, 15kHz: as set by the
	--CRTC (C of the RESET command).
	T_CURM<=CTYPE(1) when VT24='1' else '0';
	T_CBLINK<=CTYPE(0) when VT24='1' else '1';

	--24kHz, 15kHz: a parameter set is used from the next frame, if it is in range
	--and its first row can be requested after TRAMCONV takes it (at CAPLINE).
	--Until one is written (power on, reset), the ROM's 25-line set is used; in 15kHz
	--it is loaded on the clock after reset.
	--Taken on the clock after VCOMP rises, before the first dot of the new frame
	--is sampled (VCOMP comes 1 clock after the wrap, the next dot 3 or 4 after it).
	nROWS<=conv_integer(SETL)+1;
	nCHRL<=conv_integer(SETR)+1;
	nVRET<=(conv_integer(SETV)+1)*(conv_integer(SETR)+1);
	vretmin<=VRETMIN15 when VT15='1' else VRETMIN24;
	process(clk,rstn)begin
		if(rstn='0')then
			aROWS<=ROWSDEF24;
			aCHRL<=CHRLDEF24;
			aVRET<=VRETDEF24;
			aVEND<=ROWSDEF24*CHRLDEF24+VRETDEF24-1;
			aREQ0<=VRETDEF24-CHRLDEF24;
			pVCOMP<='0';
			aDEF<='1';
		elsif(clk' event and clk='1')then
			pVCOMP<=VCOMP;
			aDEF<='0';
			if(aDEF='1' and VT15='1')then
				aCHRL<=CHRLDEF15;
				aVRET<=VRETDEF15;
				aVEND<=ROWSDEF24*CHRLDEF15+VRETDEF15-1;
				aREQ0<=VRETDEF15-CHRLDEF15;
			elsif(VCOMP='1' and pVCOMP='0' and SETOK='1')then
				if(nROWS<=ROWSMAX24 and nCHRL>=CHRLMIN24 and nCHRL<=CHRLMAX24 and nVRET>=vretmin and nVRET-nCHRL>CAPLINE)then
					aROWS<=nROWS;
					aCHRL<=nCHRL;
					aVRET<=nVRET;
					aVEND<=nROWS*nCHRL+nVRET-1;
					aREQ0<=nVRET-nCHRL;
				end if;
			end if;
		end if;
	end process;
	TSET<=conv_std_logic_vector(aROWS,5) & conv_std_logic_vector(aCHRL,5) & conv_std_logic_vector(aREQ0,8);

	FRAMWEN<=FRAMWR when FRAMWADR(12)='0' else '0';
	GRAMWEN<=FRAMWR when FRAMWADR(12)='1' else '0';

	FNT	:fontram port map(clk,FRAMWDAT,FRAMADR,FRAMWADR(11 downto 0),FRAMWEN,FRAMDAT);
	GFNT	:fontram port map(clk,FRAMWDAT,FRAMADR,FRAMWADR(11 downto 0),GRAMWEN,GRAMDAT);
	FNT8	:font8ram port map(clk,FRAMWDAT,FRAMADR8,FRAMWADR(10 downto 0),FRAM8WR,FRAMDAT8);

	sync:synccont2 generic map(
		DOTPU	=>DOTPU,
		HWIDTH	=>HWIDTH,
		VWIDTH	=>VWIDTH,
		HVIS	=>HVIS,
		VVIS	=>VVIS,
		VVIS2	=>VVIS2,
		CPD		=>CPD,
		HFP		=>HFP,
		HSY		=>HSY,
		VFP		=>VFP,
		VSY		=>VSY
	) port map(VT24,VT15,aVRET,UCOUNT,HUCOUNT,VCOUNT,HCOMP,VCOMP,HSYNC,VSYNC,VISIBLE,VIDENb,HRTC,VRTC,clk,rstn,ce3b);
	
	F_REVERSE <= T_BGCOLOR(0) xor REVERSE;
	A_REVERSE <= (others=>F_REVERSE);

	X_BIT<='0' when TXTEN='0' else T_BIT when GCOLOR='0' else T_BIT xor F_REVERSE;
	
	G0F_BIT<='0' when GRAPHEN='0' else G0_BIT when GCOLOR='1' else T_FGCOLOR(0) and GM_BIT;
	G1F_BIT<='0' when GRAPHEN='0' else G1_BIT when GCOLOR='1' else T_FGCOLOR(1) and GM_BIT;
	G2F_BIT<='0' when GRAPHEN='0' else G2_BIT when GCOLOR='1' else T_FGCOLOR(2) and GM_BIT;
	
	COLNUMN(0)	<=T_FGCOLOR(0) when X_BIT='1' else G0F_BIT;
	COLNUMN(1)	<=T_FGCOLOR(1) when X_BIT='1' else G1F_BIT;
	COLNUMN(2)	<=T_FGCOLOR(2) when X_BIT='1' else G2F_BIT;
	
	COLNUMT(0)	<=T_FGCOLOR(0) when T_BIT='1' else T_BGCOLOR(0);
	COLNUMT(1)	<=T_FGCOLOR(1) when T_BIT='1' else T_BGCOLOR(1);
	COLNUMT(2)	<=T_FGCOLOR(2) when T_BIT='1' else T_BGCOLOR(2);
	
	COLNUM<=COLNUMT when TXTMODE='1' else COLNUMN when (GCOLOR='1' or TXTEN='0') else COLNUMN xor A_REVERSE;

	PAL	:rampalette port map(
		IORQn	=>IORQn,
		WRn		=>WRn,
		ADR		=>ADR,
		WDAT	=>WDAT,
		
		PMODE	=>PMODE,
		
		DOTIN	=>COLNUM,
		ROUT	=>PAL_RED,
		GOUT	=>PAL_GRN,
		BOUT	=>PAL_BLE,
		
		CRTCEN	=>CRTCEN,
		GCOLOR	=>GCOLOR,
		X_BIT	=>X_BIT,

		sclk		=>cpuclk,
		sce			=>cpuce,
		gclk		=>clk,
		gce			=>ce3b,
		rstn	=>rstn
	);
	
	process(clk)begin
		if(clk' event and clk='1')then
		 if(ce3b='1')then
			COLNUMd<=COLNUM;
			GE_BITd<=GE_BIT;
			X_BITd<=X_BIT;
			VIDEN<=VIDENb;
			VISIBLEd<=VISIBLE;
		 end if;
		end if;
	end process;
		
	RED<=	PAL_RED when PALEN='1' else (others=>COLNUMd(2));
	GRN<=	PAL_GRN when PALEN='1' else (others=>COLNUMd(1));
	BLE<=	PAL_BLE when PALEN='1' else (others=>COLNUMd(0));
	
	ROUT	<="000" when (VISIBLEd='0' or ((GE_BITd='0' or GRAPHEN='0') and X_BITd='0' and TXTMODE='0')) else RED;
	GOUT	<="000" when (VISIBLEd='0' or ((GE_BITd='0' or GRAPHEN='0') and X_BITd='0' and TXTMODE='0')) else GRN;
	BOUT	<="000" when (VISIBLEd='0' or ((GE_BITd='0' or GRAPHEN='0') and X_BITd='0' and TXTMODE='0')) else BLE;

	gclk<=clk3;
	CE3<=ce3b;

end MAIN;

	