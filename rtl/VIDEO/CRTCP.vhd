LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
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
	TRAM_DAT	:in std_logic_vector(7 downto 0);
	
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

	CURL		:in std_logic_vector(4 downto 0);
	CURC		:in std_logic_vector(6 downto 0);
	CURE		:in std_logic;
	CURM		:in std_logic;
	CBLINK		:in std_logic;

	VRTC		:out std_logic;
	HRTC		:out std_logic;
	
	FRAMWADR	:in std_logic_Vector(12 downto 0);
	FRAMWDAT	:in std_logic_vector(7 downto 0);
	FRAMWR	:in std_logic;

	gclk		:out std_logic;
	cpuclk		:in std_logic;
	clk			:in std_logic;
	rstn		:in std_logic
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
	VCOUNT	:out integer range 0 to VWIDTH-1;
	HUCOUNT	:out integer range 0 to (HWIDTH/DOTPU)-1;
	UCOUNT	:out integer range 0 to DOTPU-1;
	
	HCOMP	:out std_logic;
	VCOMP	:out std_logic;
	
	clk2	:out std_logic;
	clk3	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component TEXTSCR2 is
port(
	TRAMADR	:out std_logic_vector(11 downto 0);
	TRAMDAT	:in std_logic_vector(7 downto 0);
	
	FRAMADR	:out std_logic_vector(11 downto 0);
	FRAMDAT0:in std_logic_vector( 7 downto 0);
	FRAMDAT1:in std_logic_vector( 7 downto 0);

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
	HUCOUNT	:in integer range 0 to (HWIDTH/DOTPU)-1;
	VCOUNT	:in integer range 0 to VWIDTH-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
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
	HUCOUNT	:in integer range 0 to (HWIDTH/DOTPU)-1;
	VCOUNT	:in integer range 0 to VWIDTH-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
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
	UCOUNT	:in integer range 0 to DOTPU-1;
	HUCOUNT	:in integer range 0 to (HWIDTH/DOTPU)-1;
	VCOUNT	:in integer range 0 to VWIDTH-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;

	HSYNC	:out std_logic;
	VSYNC	:out std_logic;
	VISIBLE	:out std_logic;
	VIDEN		:out std_logic;
	
	HRTC	:out std_logic;
	VRTC	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
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
	
	sclk		:in std_logic;
	gclk		:in std_logic;
	rstn	:in std_logic
);
end component;

signal VCOUNT	:integer range 0 to VWIDTH-1;
signal HUCOUNT	:integer range 0 to (HWIDTH/DOTPU)-1;
signal UCOUNT	:integer range 0 to DOTPU-1;
signal HCOMP	:std_logic;
signal VCOMP	:std_logic;
	
signal clk2		:std_logic;
signal clk3		:std_logic;

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
) port map(VCOUNT,HUCOUNT,UCOUNT,HCOMP,VCOMP,clk2,clk3,clk,rstn);
	TXT	:textscr2 port map(TRAM_ADR,TRAM_DAT,FRAMADR,FRAMDAT,GRAMDAT,T_BIT,T_FGCOLOR,T_BGCOLOR,T_BLINK,CURL,CURC,CURE,'0','1',HMODE,VMODE,UCOUNT,HUCOUNT,VCOUNT,HCOMP,VCOMP,clk3,rstn);
	GRP	:graphscr port map(GRAMADR,GRAMRD,GRAMWAIT,GRAMDAT0,GRAMDAT1,GRAMDAT2,G0_BIT,G1_BIT,G2_BIT,GM_BIT,GE_BIT,GRAPHEN,LOWRES,MONOEN,UCOUNT,HUCOUNT,VCOUNT,HCOMP,VCOMP,clk3,rstn);

	FRAMWEN<=FRAMWR when FRAMWADR(12)='0' else '0';
	GRAMWEN<=FRAMWR when FRAMWADR(12)='1' else '0';

	FNT	:fontram port map(clk,FRAMWDAT,FRAMADR,FRAMWADR(11 downto 0),FRAMWEN,FRAMDAT);
	GFNT	:fontram port map(clk,FRAMWDAT,FRAMADR,FRAMWADR(11 downto 0),GRAMWEN,GRAMDAT);

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
	) port map(UCOUNT,HUCOUNT,VCOUNT,HCOMP,VCOMP,HSYNC,VSYNC,VISIBLE,VIDENb,HRTC,VRTC,clk3,rstn);
	
	X_BIT<='0' when TXTEN='0' else T_BIT xor T_BGCOLOR(0);
	
	G0F_BIT<='0' when GRAPHEN='0' else G0_BIT when GCOLOR='1' else T_FGCOLOR(0) and GM_BIT;
	G1F_BIT<='0' when GRAPHEN='0' else G1_BIT when GCOLOR='1' else T_FGCOLOR(1) and GM_BIT;
	G2F_BIT<='0' when GRAPHEN='0' else G2_BIT when GCOLOR='1' else T_FGCOLOR(2) and GM_BIT;
	
	COLNUMN(0)	<=T_FGCOLOR(0) when X_BIT='1' else G0F_BIT;
	COLNUMN(1)	<=T_FGCOLOR(1) when X_BIT='1' else G1F_BIT;
	COLNUMN(2)	<=T_FGCOLOR(2) when X_BIT='1' else G2F_BIT;
	
	COLNUMT(0)	<=T_FGCOLOR(0) when T_BIT='1' else T_BGCOLOR(0);
	COLNUMT(1)	<=T_FGCOLOR(1) when T_BIT='1' else T_BGCOLOR(1);
	COLNUMT(2)	<=T_FGCOLOR(2) when T_BIT='1' else T_BGCOLOR(2);
	
	COLNUM<=COLNUMN when TXTMODE='0' else COLNUMT;

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
		
		sclk		=>cpuclk,
		gclk		=>clk3,
		rstn	=>rstn
	);
	
	process(clk3)begin
		if(clk3' event and clk3='1')then
			COLNUMd<=COLNUM;
			GE_BITd<=GE_BIT;
			X_BITd<=X_BIT;
			VIDEN<=VIDENb;
			VISIBLEd<=VISIBLE;
		end if;
	end process;
		
	RED<=	PAL_RED when PALEN='1' else (others=>COLNUMd(2));
	GRN<=	PAL_GRN when PALEN='1' else (others=>COLNUMd(1));
	BLE<=	PAL_BLE when PALEN='1' else (others=>COLNUMd(0));
	
	ROUT	<="000" when (VISIBLEd='0' or ((GE_BITd='0' or GRAPHEN='0') and X_BITd='0' and TXTMODE='0')) else RED;
	GOUT	<="000" when (VISIBLEd='0' or ((GE_BITd='0' or GRAPHEN='0') and X_BITd='0' and TXTMODE='0')) else GRN;
	BOUT	<="000" when (VISIBLEd='0' or ((GE_BITd='0' or GRAPHEN='0') and X_BITd='0' and TXTMODE='0')) else BLE;

	gclk<=clk3;

end MAIN;

	