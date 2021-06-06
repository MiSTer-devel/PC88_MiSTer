LIBRARY	IEEE,work;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE IEEE.STD_LOGIC_ARITH.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	USE	WORK.addressmap_pkg.ALL;
	
entity PC88MiSTer is
generic(
	SYSCLK		:integer	:=20000;		--kHz
	VIDCLK		:integer	:=75000;		--kHz
	RAMCLK		:integer	:=75000;		--kHz
	USE_OPNA		:integer	:=1;
	RAMAWIDTH	:integer	:=24;
	RAMCAWIDTH	:integer	:=9	
);
port(
	clk21m		:in std_logic;
	rclk			:in std_logic;
	emuclk		:in std_logic;
	plllocked	:in std_logic;

	sysrtc	:in std_logic_vector(64 downto 0);
	
	LOADER_ADR	:in std_logic_vector(18 downto 0);
	LOADER_WDAT	:in std_logic_vector(7 downto 0);
	LOADER_OE	:in std_logic;
	LOADER_WR	:in std_logic;
	LOADER_ACK	:out std_logic;
	LOADER_DONE	:in std_logic;
	
	-- SD-RAM ports
	pMemCke     : out std_logic;                        -- SD-RAM Clock enable
	pMemCs_n    : out std_logic;                        -- SD-RAM Chip select
	pMemRas_n   : out std_logic;                        -- SD-RAM Row/RAS
	pMemCas_n   : out std_logic;                        -- SD-RAM /CAS
	pMemWe_n    : out std_logic;                        -- SD-RAM /WE
	pMemUdq     : out std_logic;                        -- SD-RAM UDQM
	pMemLdq     : out std_logic;                        -- SD-RAM LDQM
	pMemBa1     : out std_logic;                        -- SD-RAM Bank select address 1
	pMemBa0     : out std_logic;                        -- SD-RAM Bank select address 0
	pMemAdr     : out std_logic_vector(12 downto 0);    -- SD-RAM Address
	pMemDat     : inout std_logic_vector(15 downto 0);  -- SD-RAM Data

	-- PS/2 keyboard ports
	pPs2Clkin	: in std_logic;
	pPs2Clkout	: out std_logic;
	pPs2Datin 	: in std_logic;
	pPs2Datout	: out std_logic;
	pPmsClkin	: in std_logic;
	pPmsClkout	: out std_logic;
	pPmsDatin	: in std_logic;
	pPmsDatout	: out std_logic;

	-- Joystick ports (Port_A, Port_B)
	pJoyA		: inout std_logic_vector( 5 downto 0);
	pJoyB		: inout std_logic_vector( 5 downto 0);
	pStrA		: out std_logic;
	pStrB		: out std_logic;
	
	--MiSTer port
	mist_mounted	:in std_logic_vector(3 downto 0);	--SRAM & HDD & FDD1 &FDD0
	mist_readonly	:in std_logic_vector(3 downto 0);
	mist_imgsize	:in std_logic_vector(63 downto 0);

	mist_lba		:out std_logic_vector(31 downto 0);
	mist_rd			:out std_logic_vector(3 downto 0);
	mist_wr			:out std_logic_vector(3 downto 0);
	mist_ack		:in std_logic_vector(3 downto 0);

	mist_buffaddr	:in std_logic_vector(8 downto 0);
	mist_buffdout	:in std_logic_vector(7 downto 0);
	mist_buffdin	:out std_logic_vector(7 downto 0);
	mist_buffwr		:in std_logic;
	

	-- FDD ports
	pFd_sync		:in std_logic_vector(1 downto 0);

    -- DIP switch, Lamp ports
	pDip        : in std_logic_vector( 9 downto 0);
	pLed        : out std_logic;
	pPsw		: in std_logic_vector(1 downto 0);
	pMonDbus	:out std_logic_vector(7 downto 0);

   -- Video, Audio/CMT ports
	pVideoR		: out std_logic_vector(7 downto 0);
	pVideoG		: out std_logic_vector(7 downto 0);
	pVideoB		: out std_logic_vector(7 downto 0);
	pVideoHS		: out std_logic;
	pVideoVS		: out std_logic;
	pVideoHB        :out std_logic;
	pVideoVB        :out std_logic;
	pVideoEn	: out std_logic;
	pVideoClk	: out std_logic;
	pSndL			: out std_logic_vector(15 downto 0);
	pSndR			: out std_logic_vector(15 downto 0);
	
	-- COM(RS-232C) port
	pCOM_TxD	:out std_logic;
	pCOM_RxD	:in std_logic;
	pCOM_CTS	:in std_logic;
	pCOM_RTS	:out std_logic;
	
	rstn		:in std_logic
);
end PC88MiSTer;

architecture MAIN of PC88MiSTer is
component SDRAMCde0cvDEMU2
	generic(
		CAWIDTH			:integer	:=10;
		AWIDTH			:integer	:=25;
		CLKMHZ			:integer	:=82;			--MHz
		REFCYC			:integer	:=64000/8192	--usec
	);
	port(
		-- SDRAM PORTS
		PMEMCKE			: OUT	STD_LOGIC;							-- SD-RAM CLOCK ENABLE
		PMEMCS_N		: OUT	STD_LOGIC;							-- SD-RAM CHIP SELECT
		PMEMRAS_N		: OUT	STD_LOGIC;							-- SD-RAM ROW/RAS
		PMEMCAS_N		: OUT	STD_LOGIC;							-- SD-RAM /CAS
		PMEMWE_N		: OUT	STD_LOGIC;							-- SD-RAM /WE
		PMEMUDQ			: OUT	STD_LOGIC;							-- SD-RAM UDQM
		PMEMLDQ			: OUT	STD_LOGIC;							-- SD-RAM LDQM
		PMEMBA1			: OUT	STD_LOGIC;							-- SD-RAM BANK SELECT ADDRESS 1
		PMEMBA0			: OUT	STD_LOGIC;							-- SD-RAM BANK SELECT ADDRESS 0
		PMEMADR			: OUT	STD_LOGIC_VECTOR( 12 DOWNTO 0 );	-- SD-RAM ADDRESS
		PMEMDAT			: INOUT	STD_LOGIC_VECTOR( 15 DOWNTO 0 );	-- SD-RAM DATA

		CPUADR			:in std_logic_vector(AWIDTH-1 downto 0);
		CPURDAT			:out std_logic_vector(7 downto 0);
		CPUWDAT			:in std_logic_vector(7 downto 0);
		CPUWR			:in std_logic;
		CPURD			:in std_logic;
		CPUWAIT			:out std_logic;
		CPUCLK			:out std_logic;
		CPURSTn			:out std_logic;
		MRAMDAT			:out std_logic_vector(7 downto 0);
		
		SUBADR			:in std_logic_vector(AWIDTH-1 downto 0);
		SUBRDAT			:out std_logic_vector(7 downto 0);
		SUBWDAT			:in std_logic_vector(7 downto 0);
		SUBWR			:in std_logic;
		SUBRD			:in std_logic;
		SUBWAIT			:out std_logic;
		SUBCLK			:out std_logic;

		ALURD0			:out std_logic_vector(7 downto 0);
		ALURD1			:out std_logic_vector(7 downto 0);
		ALURD2			:out std_logic_vector(7 downto 0);
		VRAMRSEL		:in integer range 0 to 3;
		
		ALUCWD			:out std_logic_vector(7 downto 0);
		ALUWD0			:in std_logic_vector(7 downto 0);
		ALUWD1			:in std_logic_vector(7 downto 0);
		ALUWD2			:in std_logic_vector(7 downto 0);
		VRAMWE			:in std_logic_vector(3 downto 0);
		
		VIDADR			:in std_logic_vector(AWIDTH-1 downto 0);
		VIDDAT0			:out std_logic_vector(7 downto 0);
		VIDDAT1			:out std_logic_vector(7 downto 0);
		VIDDAT2			:out std_logic_vector(7 downto 0);
		VIDRD			:in std_logic;
		VIDWAIT			:out std_logic;
		
		FDEADR			:in std_logic_vector(AWIDTH-1 downto 0)	:=(others=>'0');
		FDERD				:in std_logic								:='0';
		FDEWR				:in std_logic								:='0';
		FDERDAT			:out std_logic_Vector(15 downto 0);
		FDEWDAT			:in std_logic_vector(15 downto 0)	:=(others=>'0');
		FDEWAIT			:out std_logic;
		
		FECADR			:in std_logic_vector(AWIDTH-1 downto 0)	:=(others=>'0');
		FECRD				:in std_logic								:='0';
		FECWR				:in std_logic								:='0';
		FECRDAT			:out std_logic_vector(15 downto 0);
		FECWDAT			:in std_logic_vector(15 downto 0)	:=(others=>'0');
		FECWAIT			:out std_logic;
		
		SNDADR			:in std_logic_vector(AWIDTH-1 downto 0);
		SNDRD			:in std_logic;
		SNDWR			:in std_logic;
		SNDRDAT			:out std_logic_vector(7 downto 0);
		SNDWDAT			:in std_logic_vector(7 downto 0);
		SNDWAIT			:out std_logic;
		SNDH_Ln			:in std_logic;
				
		monout			:out std_logic_vector(7 downto 0);
		
		CLOCKM			:in std_logic;
		
		memclk			:in std_logic;
		rstn			:in std_logic
	);
end component;

component memorymaps
generic(
	extram	:integer	:=0;
	addrwidth	:integer	:=25
);
port(
	CPU_ADR		:in std_logic_vector(15 downto 0);
	CPU_MREQn	:in std_logic;
	CPU_IORQn	:in std_logic;
	CPU_RDn		:in std_logic;
	CPU_WRn		:in std_logic;
	CPU_WDAT	:in std_logic_vector(7 downto 0);
	CPU_RDAT	:out std_logic_vector(7 downto 0);
	CPU_OE		:out std_logic;
	
	KNJ1_ADR	:in std_logic_vector(16 downto 0);
	KNJ1_RD		:in std_logic;
	
	KNJ2_ADR	:in std_logic_vector(16 downto 0);
	KNJ2_RD		:in std_logic;

	RAM_ADR		:out std_logic_vector(addrwidth-1 downto 0);
	RAM_CE		:out std_logic;
	
	TRAM_ADR	:out std_logic_vector(11 downto 0);
	TRAM_CE		:out std_logic;

	TVRAM_ADR	:out std_logic_vector(11 downto 0);
	TVRAM_CE	:out std_logic;
	
	TXTWINEN	:out std_logic;
	
	G_EXTMODE	:out std_logic;
	G_RAMSEL	:out integer range 0 to 3;
	ALUOE		:out std_logic;
	ALUME		:out std_logic;
	ALURE		:out std_logic;
	GADR_MSEL	:out std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end component;

component T80a
    generic(
        Mode : integer := 0 -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
    );
    port(
        RESET_n     : in std_logic;
        CLK_n       : in std_logic;
        WAIT_n      : in std_logic;
        INT_n       : in std_logic;
        NMI_n       : in std_logic;
        BUSRQ_n     : in std_logic;
        M1_n        : out std_logic;
        MREQ_n      : out std_logic;
        IORQ_n      : out std_logic;
        RD_n        : out std_logic;
        WR_n        : out std_logic;
        RFSH_n      : out std_logic;
        HALT_n      : out std_logic;
        BUSAK_n     : out std_logic;
        A           : out std_logic_vector(15 downto 0);
        D           : inout std_logic_vector(7 downto 0)
    );
end component;

component RAMCLR
generic(
	ADRWIDTH	:integer	:=18;
	ENDADR		:std_logic_vector(19 downto 0)	:=x"10000"
);
port(
	RAM_ADR		:out std_logic_vector(ADRWIDTH-1 downto 0);
	RAM_WDAT	:out std_logic_vector(7 downto 0);
	RAM_OE		:out std_logic;
	RAM_WR		:out std_logic;
	RAM_BUSY	:in std_logic;
	
	done		:out std_logic;

	clk			:in std_logic;
	rstn		:in std_logic
);
end component;

component TEXTRAM
	PORT
	(
		address_a		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data_a		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		wren_a		: IN STD_LOGIC  := '0';
		wren_b		: IN STD_LOGIC  := '0';
		q_a		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

component CRTCP
port(
	IORQn		:in std_logic;
	WRn			:in std_logic;
	ADR			:in std_logic_vector(7 downto 0);
	WDAT		:in std_logic_vector(7 downto 0);
	PALEN		:in std_logic	:='1';
	
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
	TXTMODE		:in std_logic;
	
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
end component;

component CRTCREGS
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
end component;

component GraphALU
port(
	CS		:in std_logic;
	RDn		:in std_logic;
	RDDAT0	:in std_logic_vector(7 downto 0);
	RDDAT1	:in std_logic_vector(7 downto 0);
	RDDAT2	:in std_logic_vector(7 downto 0);
	
	WRDAT0	:out std_logic_vector(7 downto 0);
	WRDAT1	:out std_logic_vector(7 downto 0);
	WRDAT2	:out std_logic_vector(7 downto 0);
	WEBIT	:out std_logic_vector(2 downto 0);
	
	CPUWD	:in std_logic_vector(7 downto 0);
	CPURD	:out std_logic_vector(7 downto 0);
	
	ALU0	:in std_logic_vector(1 downto 0);
	ALU1	:in std_logic_vector(1 downto 0);
	ALU2	:in std_logic_vector(1 downto 0);
	
	GDM		:in std_logic_vector(1 downto 0);
	
	PLN		:in std_logic_vector(2 downto 0);

	GVAM	:in std_logic;
	GAM		:in std_logic;
	NSEL	:in integer range 0 to 3;

	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component trammaps
generic(
	awidth	:integer	:=25
);
port(
	VADR		:in std_logic_vector(15 downto 0);
	
	RAM_ADR		:out std_logic_vector(awidth-1 downto 0)
);
end component;

component IO_RD
generic(
	IOADR	:in std_logic_vector(7 downto 0)	:=x"00"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	RDn		:in std_logic;
	DAT		:out std_logic_vector(7 downto 0);
	OUTE	:out std_logic;
	
	bit7	:in std_logic;
	bit6	:in std_logic;
	bit5	:in std_logic;
	bit4	:in std_logic;
	bit3	:in std_logic;
	bit2	:in std_logic;
	bit1	:in std_logic;
	bit0	:in std_logic
);
end component;

component IO_WRS
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
end component;

component IO_RWS
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
end component;

component IOWAIT
port(
	IORQn	:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	
	WAITn	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component TDMAREGS
generic(
	ADRTOP	:in std_logic_vector(7 downto 0)	:=x"64";
	ADRLEN	:in std_logic_vector(7 downto 0)	:=x"65";
	ADRCMD	:in std_logic_vector(7 downto 0)	:=x"68"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	WRn		:in std_logic;
	DAT		:in std_logic_vector(7 downto 0);
	
	TRAMTOP	:out std_logic_vector(15 downto 0);
	TRAMLEN	:out std_logic_vector(15 downto 0);
	TDMAEN	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component TRAMCONV
port(
	TVRMODE		:in std_logic;
	TMODE		:in std_logic;
	COLOR		:in std_logic;
	TEXTEN		:in std_logic;
	ATTRLEN		:in std_logic_vector(4 downto 0);
	
	TADR_TOP	:in std_logic_vector(15 downto 0);

	TRAM_ADR	:out std_logic_vector(11 downto 0);
	TRAM_DAT	:in std_logic_vector(7 downto 0);
	
	MRAM_ADR	:out std_logic_vector(15 downto 0);
	MRAM_DAT	:in std_logic_vector(7 downto 0);
	MRAM_RDn	:out std_logic;
	MRAM_WAIT	:in std_logic;
	BUS_USE		:out std_logic;
	
	BUSREQn		:out std_logic;
	BUSACKn		:in std_logic;
	

	TVRAM_ADR	:out std_logic_vector(11 downto 0);
	TVRAM_WDAT	:out std_logic_vector(7 downto 0);
	TVRAM_WR	:out std_logic;
	
	VRET		:in std_logic;
	HRET		:in std_logic;
	DONE		:out std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end component;

component KBMAP
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
end component;

component INTCONTS
generic(
	CNTADR	:std_logic_vector(7 downto 0)	:=x"e4";
	MSKADR	:std_logic_vector(7 downto 0)	:=x"e6"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	WRn		:in std_logic;
	RDn		:in std_logic;
	M1n		:in std_logic;
	RFRSHn	:in std_logic;
	DATIN	:in std_logic_vector(7 downto 0);
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;

	INTn	:out std_logic;
	
	INT0n	:in std_logic;
	INT1n	:in std_logic;
	INT2n	:in std_logic;
	INT3n	:in std_logic;
	INT4n	:in std_logic;
	INT5n	:in std_logic;
	INT6n	:in std_logic;
	INT7n	:in std_logic;
	
	cpuclk	:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component rtc4990MiSTer
generic(
	clkfreq	:integer	:=21477270;
	YEAROFF	:std_logic_vector(7 downto 0)	:=x"00"
);
port(
	DCLK	:in std_logic;
	DIN		:in std_logic;
	DOUT	:out std_logic;
	C		:in std_logic_vector(2 downto 0);
	CS		:in std_logic;
	STB		:in std_logic;
	OE		:in std_logic;

	RTCIN	:in std_logic_vector(64 downto 0);

 	sclk	:in std_logic;
	rstn	:in std_logic
);
end component;

component e8255
port(
	CSn		:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	ADR		:in std_logic_vector(1 downto 0);
	DATIN	:in std_logic_vector(7 downto 0);
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;
	
	PAi		:in std_logic_vector(7 downto 0);
	PAo		:out std_logic_vector(7 downto 0);
	PAoe	:out std_logic;
	PBi		:in std_logic_vector(7 downto 0);
	PBo		:out std_logic_vector(7 downto 0);
	PBoe	:out std_logic;
	PCHi	:in std_logic_vector(3 downto 0);
	PCHo	:out std_logic_vector(3 downto 0);
	PCHoe	:out std_logic;
	PCLi	:in std_logic_vector(3 downto 0);
	PCLo	:out std_logic_vector(3 downto 0);
	PCLoe	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component KANJIROM
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
end component;

component e8251
port(
	WRn		:in std_logic;
	RDn		:in std_logic;
	C_Dn	:in std_logic;
	CSn		:in std_logic;
	DATIN	:in std_logic_vector(7 downto 0);
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;
	
	TXD		:out std_logic;
	RxD		:in std_logic;
	
	DSRn	:in std_logic;
	DTRn	:out std_logic;
	RTSn	:out std_logic;
	CTSn	:in std_logic;
	
	TxRDY	:out std_logic;
	TxEMP	:out std_logic;
	RxRDY	:out std_logic;
	
	TxCn	:in std_logic;
	RxCn	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component addsat
generic(
	datwidth	:integer	:=16
);
port(
	INA		:in std_logic_vector(datwidth-1 downto 0);
	INB		:in std_logic_vector(datwidth-1 downto 0);
	
	OUTQ	:out std_logic_vector(datwidth-1 downto 0);
	OFLOW	:out std_logic;
	UFLOW	:out std_logic
);
end component;

component average
generic(
	datwidth	:integer	:=16
);
port(
	INA		:in std_logic_vector(datwidth-1 downto 0);
	INB		:in std_logic_vector(datwidth-1 downto 0);
	
	OUTQ	:out std_logic_vector(datwidth-1 downto 0)
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

component sftgen
generic(
	maxlen	:integer	:=100
);
port(
	len		:in integer range 0 to maxlen;
	sft		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component SUBunitsMiSTer
generic(
	sysclk	:integer	:=21477;		--in kHz
	memclk	:integer	:=80000;			--in kHz
	awidth	:integer	:=25
);
port(
	RAMADR			:out std_logic_vector(awidth-1 downto 0);
	RAMRDAT			:in std_logic_vector(7 downto 0);
	RAMWDAT			:out std_logic_vector(7 downto 0);
	RAMWR			:out std_logic;
	RAMRD			:out std_logic;
	RAMWAIT			:in std_logic;
	
	SUBIO_PAI		:in std_logic_vector(7 downto 0);
	SUBIO_PAO		:out std_logic_vector(7 downto 0);
	SUBIO_PBI		:in std_logic_vector(7 downto 0);
	SUBIO_PBO		:out std_logic_vector(7 downto 0);
	SUBIO_PCHI		:in std_logic_vector(3 downto 0);
	SUBIO_PCHO		:out std_logic_vector(3 downto 0);
	SUBIO_PCLI		:in std_logic_vector(3 downto 0);
	SUBIO_PCLO		:out std_logic_vector(3 downto 0);
	
	dmon0			:out std_logic_vector(7 downto 0);
	dmon1			:out std_logic_vector(7 downto 0);
	dmon2			:out std_logic_vector(7 downto 0);
	dmon3			:out std_logic_vector(7 downto 0);
	dmon4			:out std_logic_vector(7 downto 0);
	dmon5			:out std_logic_vector(7 downto 0);
	dmon6			:out std_logic_vector(7 downto 0);
	dmon7			:out std_logic_vector(7 downto 0);
	
	FD_SYNC		:in std_logic_Vector(1 downto 0);
	
	MTSAVEON		:in std_logic;
	
	mist_mounted	:in std_logic_vector(3 downto 0);	--SRAM & HDD & FDD1 &FDD0
	mist_readonly	:in std_logic_vector(3 downto 0);
	mist_imgsize	:in std_logic_vector(63 downto 0);

	mist_lba		:out std_logic_vector(31 downto 0);
	mist_rd			:out std_logic_vector(3 downto 0);
	mist_wr			:out std_logic_vector(3 downto 0);
	mist_ack		:in std_logic_vector(3 downto 0);

	mist_buffaddr	:in std_logic_vector(8 downto 0);
	mist_buffdout	:in std_logic_vector(7 downto 0);
	mist_buffdin	:out std_logic_vector(7 downto 0);
	mist_buffwr		:in std_logic;
	
	FDE_ADDR		:out std_logic_vector(22 downto 0);
	FDE_RD			:out std_logic;
	FDE_WR			:out std_logic;
	FDE_WDAT		:out std_logic_vector(15 downto 0);
	FDE_RDAT		:in std_logic_vector(15 downto 0);
	FDE_RAMWAIT		:in std_logic;
	
	FEC_ADDR		:out std_logic_vector(22 downto 0);
	FEC_RD			:out std_logic;
	FEC_WR			:out std_logic;
	FEC_WDAT		:out std_logic_vector(15 downto 0);
	FEC_RDAT		:in std_logic_vector(15 downto 0);
	FEC_RAMWAIT		:in std_logic;
	
	mondat	:out std_logic_vector(7 downto 0);
	
	EMUINITDONE		:out std_logic;
	EMUBUSY			:out std_logic;
	CPUCLK			:in std_logic;
	clk21m			:in std_logic;
	ramclk			:in std_logic;
	pclk			:in std_logic;
	vclk			:in std_logic;
	srstn			:in std_logic;
	rstn			:in std_logic
);
end component;

component  OPN
generic(
	res		:integer	:=9
);
port(
	DIN		:in std_logic_vector(7 downto 0);
	DOUT	:out std_logic_vector(7 downto 0);
	DOE		:out std_logic;
	CSn		:in std_logic;
	ADR0	:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	INTn	:out std_logic;
	
	snd		:out std_logic_vector(res-1 downto 0);
	
	PAOUT	:out std_logic_vector(7 downto 0);
	PAIN	:in std_logic_vector(7 downto 0);
	PAOE	:out std_logic;
	
	PBOUT	:out std_logic_vector(7 downto 0);
	PBIN	:in std_logic_vector(7 downto 0);
	PBOE	:out std_logic;

	clk		:in std_logic;
	cpuclk	:in std_logic;
	sft		:in std_logic;
	rstn	:in std_logic
);
end component;

component OPNA
generic(
	res		:integer	:=16
);
port(
	DIN		:in std_logic_vector(7 downto 0);
	DOUT	:out std_logic_vector(7 downto 0);
	DOE		:out std_logic;
	CSn		:in std_logic;
	ADR		:in std_logic_vector(1 downto 0);
	RDn		:in std_logic;
	WRn		:in std_logic;
	INTn	:out std_logic;
	
	sndL		:out std_logic_vector(res-1 downto 0);
	sndR		:out std_logic_vector(res-1 downto 0);
	sndPSG		:out std_logic_vector(res-1 downto 0);
	
	PAOUT	:out std_logic_vector(7 downto 0);
	PAIN	:in std_logic_vector(7 downto 0);
	PAOE	:out std_logic;
	
	PBOUT	:out std_logic_vector(7 downto 0);
	PBIN	:in std_logic_vector(7 downto 0);
	PBOE	:out std_logic;
	
	RAMADDR	:out std_logic_vector(17 downto 0);
	RAMRD	:out std_logic;
	RAMWR	:out std_logic;
	RAMRDAT	:in std_logic_vector(7 downto 0);
	RAMWDAT	:out std_logic_vector(7 downto 0);
	RAMWAIT	:in std_logic;

	clk		:in std_logic;
	cpuclk	:in std_logic;
	sft		:in std_logic;
	rstn	:in std_logic
);
end component;

component DIGIFILTER
	generic(
		TIME	:integer	:=2;
		DEF		:std_logic	:='0'
	);
	port(
		D	:in std_logic;
		Q	:out std_logic;

		clk	:in std_logic;
		rstn :in std_logic
	);
end component;

component  beeposc
generic(
	beepcyc	:integer	:=10000;		--Hz
	sysclk	:integer	:=20000			--kHz
);
port(
	sndout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component CPUCLK
generic(
	divmain	:integer	:=5;
	divsub	:integer	:=10
);
port(
	clkin	:in std_logic;
	clksel	:in std_logic;
	mainout	:out std_logic;
	subout	:out std_logic;
	rstn	:in std_logic
);
end component;

component SPI_IF
port(
	MODE	:in std_logic_vector(1 downto 0);
	WRDAT	:in std_logic_vector(7 downto 0);
	RDDAT	:out std_logic_vector(7 downto 0);
	TX		:in std_logic;
	BUSY	:out std_logic;
	
	SCLK	:out std_logic;
	SDI		:in std_logic;
	SDO		:out std_logic;
	
	SFT		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component UNCHCHATA
	generic(
		MASKTIME	:integer	:=200;	--usec
		SYS_CLK		:integer	:=20	--MHz
	);
	port(
		SRC		:in std_logic;
		DST		:out std_logic;
		
		clk		:in std_logic;
		rstn	:in std_logic
	);
end component;

component  clkdiv
generic(
	dwidth	:integer	:=8
);
port(
	div		:in std_logic_vector(dwidth-1 downto 0);
	
	cout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component HEX2SEGn
	port(
		HEX	:in std_logic_vector(3 downto 0);
		DOT	:in std_logic;
		SEG	:out std_logic_vector(7 downto 0)
	);
end component;

signal	cVer		:std_logic;
signal	cHS			:std_logic;
signal	cN			:std_logic;
signal	cBT			:std_logic;
signal	c20L		:std_logic;
signal	c40C		:std_logic;
signal	cDisk		:std_logic;

signal	SDI			:std_logic;
signal	CPUADR		:std_logic_vector(15 downto 0);
signal	RAMADR		:std_logic_vector(RAMAWIDTH-1 downto 0);
signal	RAM_WR		:std_logic;
signal	RAM_RD		:std_logic;
signal	RAM_WDAT	:std_logic_vector(7 downto 0);
signal	IDAT_RAM	:std_logic_vector(7 downto 0);
signal	CPUDAT		:std_logic_vector(7 downto 0);
signal	RD_n		:std_logic;
signal	WR_n		:std_logic;
signal	MREQ_n		:std_logic;
signal	IORQ_n		:std_logic;
signal	WAIT_n		:std_logic;
signal	INT_n		:std_logic;
signal	NMI_n		:std_logic;
signal	M1_n		:std_logic;
signal	CPU_rstn	:std_logic;
signal	CPU_clk		:std_logic;
signal	BUSRQ_n		:std_logic;
signal	BUSACK_n	:std_logic;
signal	RAM_WAIT	:std_logic;
signal	LOADER_rstn :std_logic;
signal	CLR_ADR		:std_logic_vector(18 downto 0);
signal	CLR_WDAT	:std_logic_vector(7 downto 0);
signal	CLR_WR		:std_logic;
signal	CLR_OE		:std_logic;
signal	CLR_rstn	:std_logic;
signal	gclk		:std_logic;
signal	clkcount	:integer range 0 to 5000000;
signal	slowclk		:std_logic;
signal	MAP_RADR	:std_logic_vector(RAMAWIDTH-1 downto 0);
signal	VMAP_RADR	:std_logic_vector(RAMAWIDTH-1 downto 0);
signal	IDAT_MAP	:std_logic_vector(7 downto 0);
signal	MAP_OE		:std_logic;
signal	RAM_CE		:std_logic;
signal	TRAM_ADR	:std_logic_vector(11 downto 0);
signal	TRAM_CE		:std_logic;
signal	IDAT_TRAM	:std_logic_vector(7 downto 0);
signal	TVRAM_ADR	:std_logic_vector(11 downto 0);
signal	TVRAM_CE	:std_logic;
signal	IDAT_TVRAM	:std_logic_vector(7 downto 0);
signal	CRTC_TADR	:std_logic_vector(11 downto 0);
signal	CRTC_TDAT	:std_logic_vector(7 downto 0);
signal	IDAT_CRTR	:std_logic_vector(7 downto 0);
signal	CRTR_OE		:std_logic;
signal	IDAT_KB		:std_logic_vector(7 downto 0);
signal	KB_OE		:std_logic;
signal	IDAT_ALU	:std_logic_vector(7 downto 0);
signal	ALU_OE		:std_logic;
signal	IDAT_IOR30	:std_logic_vector(7 downto 0);
signal	IOR30_OE	:std_logic;
signal	IDAT_IOR31	:std_logic_vector(7 downto 0);
signal	IOR31_OE	:std_logic;
signal	IDAT_IOR32	:std_logic_vector(7 downto 0);
signal	IOR32_OE	:std_logic;
signal	IDAT_IOR33	:std_logic_vector(7 downto 0);
signal	IOR33_OE	:std_logic;
signal	IDAT_IOR38	:std_logic_vector(7 downto 0);
signal	IOR38_OE	:std_logic;
signal	IDAT_IOR40	:std_logic_vector(7 downto 0);
signal	IOR40_OE	:std_logic;
signal	IDAT_IOR6e	:std_logic_vector(7 downto 0);
signal	IOR6e_OE	:std_logic;
signal	IDAT_IOR71	:std_logic_vector(7 downto 0);
signal	IOR71_OE	:std_logic;
signal	IDAT_PPIFD	:std_logic_vector(7 downto 0);
signal	PPIFD_OE	:std_logic;
signal	IDAT_PSG	:std_logic_vector(7 downto 0);
signal	PSG_OE		:std_logic;
signal	IDAT_COM	:std_logic_vector(7 downto 0);
signal	COM_OE		:std_logic;
signal	COM_CSn		:std_logic;
signal	IO_WAIT		:std_logic;
signal	IDAT_INTC	:std_logic_vector(7 downto 0);
signal	INTC_OE		:std_logic;
signal	HRTC		:std_logic;
signal	VRTC		:std_logic;
signal	CDI			:std_logic;
signal	CCK			:std_logic;
signal	CSTB		:std_logic;
signal	C_RTC		:std_logic_vector(2 downto 0);
signal	C_DO		:std_logic;
signal	CD0			:std_logic;
signal	TRAMTOP		:std_logic_vector(15 downto 0);
signal	TRAMLEN		:std_logic_vector(15 downto 0);
signal	TDMAEN		:std_logic;
signal	PMODE		:std_logic;
signal	TMODE		:std_logic;
signal	TVRMODE		:std_logic;
signal	TVRAM_WDAT	:std_logic_vector(7 downto 0);
signal	TVRAM_MADR	:std_logic_vector(11 downto 0);
signal	TVRAM_WE	:std_logic;
signal	ATTRLEN		:std_logic_vector(4 downto 0);
signal	TXTWINEN	:std_logic;
signal	VRTCi		:std_logic;
signal	PPIFD_CSn	:std_logic;
signal	PSG_CEn		:std_logic;

signal	TCNV_TDAT	:std_logic_vector(7 downto 0);
signal	TCNV_TADR	:std_logic_vector(11 downto 0);
signal	TCNV_RDAT	:std_logic_vector(7 downto 0);
signal	TCNV_RADR	:std_logic_vector(15 downto 0);
signal	TCNV_RDn	:std_logic;
signal	TCNV_BURQn	:std_logic;
signal	TCNV_BUSACKn:std_logic;
signal	TCNV_WADR	:std_logic_vector(11 downto 0);
signal	TCNV_WDAT	:std_logic_vector(7 downto 0);
signal	TCNV_WE		:std_logic;
signal	TCNV_BUSUSE	:std_logic;
signal	COLORn		:std_logic;
signal	ODAT_TCNV	:std_logic_vector(7 downto 0);
signal	pclk		:std_logic;

signal	CURL		:std_logic_vector(4 downto 0);
signal	CURC		:std_logic_vector(6 downto 0);
signal	CURE		:std_logic;
signal	CURM		:std_logic;
signal	CBLINK		:std_logic;
signal	TEXTDS		:std_logic;
signal	CRTCen		:std_logic;

signal	G_RAMSEL	:std_logic;
signal	ALU_RE		:std_logic;
signal	GRDAT0		:std_logic_vector(7 downto 0);
signal	GRDAT1		:std_logic_vector(7 downto 0);
signal	GRDAT2		:std_logic_vector(7 downto 0);
signal	GWDAT0		:std_logic_vector(7 downto 0);
signal	GWDAT1		:std_logic_vector(7 downto 0);
signal	GWDAT2		:std_logic_vector(7 downto 0);
signal	GWEBIT		:std_logic_vector(2 downto 0);
signal	ALU0		:std_logic_vector(1 downto 0);
signal	ALU1		:std_logic_vector(1 downto 0);
signal	ALU2		:std_logic_vector(1 downto 0);
signal	GDM			:std_logic_vector(1 downto 0);
signal	PLN			:std_logic_vector(2 downto 0);
signal	GVAM		:std_logic;
signal	NG_RAMSEL	:integer range 0 to 3;
signal	GR_RSEL		:integer range 0 to 3;
signal	GWME		:std_logic;
signal	GRAM_M_OE	:std_logic;
signal	GAM			:std_logic;
signal	ALUCWD		:std_logic_vector(7 downto 0);
signal	GxDS		:std_logic_vector(2 downto 0);

signal	KBCLKIN		:std_logic;
signal	KBCLKOUT	:std_logic;
signal	KBDATIN		:std_logic;
signal	KBDATOUT	:std_logic;

signal	RTI			:std_logic;

signal	GRAMADR		:std_logic_vector(13 downto 0);
signal	GRAMADRW		:std_logic_vector(RAMAWIDTH-1 downto 0);
signal	GRAMRD		:std_logic;
signal	GRAMWAIT	:std_logic;
signal	GRAMDAT0	:std_logic_vector(7 downto 0);
signal	GRAMDAT1	:std_logic_vector(7 downto 0);
signal	GRAMDAT2	:std_logic_vector(7 downto 0);

signal	GRAPHEN		:std_logic;
signal	L200		:std_logic;
signal	LOWRES		:std_logic;
signal	GCOLOR		:std_logic;

signal	INT0n		:std_logic;
signal	INT1n		:std_logic;
signal	INT2n		:std_logic;
signal	INT3n		:std_logic;
signal	INT4n		:std_logic;
signal	INT5n		:std_logic;
signal	INT6n		:std_logic;
signal	INT7n		:std_logic;

signal	SUBADR		:std_logic_vector(RAMAWIDTH-1 downto 0);
signal	SUBRDAT		:std_logic_vector(7 downto 0);
signal	SUBWDAT		:std_logic_vector(7 downto 0);
signal	SUBWR		:std_logic;
signal	SUBRD		:std_logic;
signal	SUBWAIT		:std_logic;
signal	SUBCLK		:std_logic;

signal	KANJI1ADR	:std_logic_vector(16 downto 0);
signal	KANJI1RD	:std_logic;

signal	KANJI2ADR	:std_logic_vector(16 downto 0);
signal	KANJI2RD	:std_logic;

signal	cpuclkb,subclkb	:std_logic;

signal	srstn		:std_logic;

signal	SUB_TXM2S	:std_logic_vector(7 downto 0);
signal	SUB_TXS2M	:std_logic_vector(7 downto 0);
signal	SUB_RXM2S	:std_logic_vector(7 downto 0);
signal	SUB_RXS2M	:std_logic_vector(7 downto 0);
signal	SUB_HTM2S	:std_logic_vector(3 downto 0);
signal	SUB_HTS2M	:std_logic_vector(3 downto 0);
signal	SUB_HRM2S	:std_logic_vector(3 downto 0);
signal	SUB_HRS2M	:std_logic_vector(3 downto 0);

signal	IORQ_np		:std_logic;
signal	MREQ_np		:std_logic;
signal	WR_np		:std_logic;
signal	RD_np		:std_logic;
signal	CPUADRp		:std_logic_vector(15 downto 0);
signal	REFRSHn		:std_logic;
signal	HMODE		:std_logic;
signal	VMODE		:std_logic;
signal	srstna	:std_logic;
signal	rstcnt	:integer range 0 to 100;
signal	CPUCT	:std_logic_vector(1 downto 0);
signal	SUBCT	:std_logic_vector(1 downto 0);
signal	COLCOUNT	:integer range 0 to 15;
signal	MONSFT		:std_logic_vector(7 downto 0);
signal	VRAMWE		:std_logic_vector(3 downto 0);

signal	pStr	:std_logic;
signal	pJoy	:std_logic_vector(5 downto 0);

signal	SEG0	:std_logic_vector(3 downto 0);
signal	SEG1	:std_logic_vector(3 downto 0);
signal	SEG2	:std_logic_vector(3 downto 0);
signal	SEG3	:std_logic_vector(3 downto 0);
signal	SEG4	:std_logic_vector(3 downto 0);
signal	SEG5	:std_logic_vector(3 downto 0);

signal RMODE,MMODE	:std_logic;
signal EROMSEL1,EROMSEL0	:std_logic;
signal	IEROM	:std_logic;
signal	TCNVDONE	:std_logic;

signal	beepsig	:std_logic;
signal	beepen	:std_logic;
signal	BEEPsnd	:std_logic_vector(15 downto 0);

signal	OPNsft		:std_logic;
signal	INTn_OPN	:std_logic;
signal	SINTM		:std_logic;

signal	TXTen		:std_logic;
signal	TenSw		:std_logic;
signal	CPUMD		:std_logic;
signal	sndPSG	:std_logic_vector(15 downto 0);
signal	monosnd	:std_logic_vector(15 downto 0);
signal	sndL,sndR	:std_logic_vector(15 downto 0);
signal	snddatL,usnddatL	:std_logic_vector(15 downto 0);
signal	snddatR,usnddatR	:std_logic_vector(15 downto 0);

signal	INT_COMRX	:std_logic;
signal	COM_clk		:std_logic;

signal	BS			:std_logic_vector(1 downto 0);
constant COM_BAUD	:integer	:=9600;
constant COM_DIV	:integer	:=(SYSCLK*1000/COM_BAUD/32)-1;
signal	COM_vDIV	:std_logic_vector(10 downto 0);
signal	MTON		:std_logic;
signal	CDS			:std_logic;

signal	MODE		:std_logic_vector(1 downto 0);
constant MOD_N		:std_logic_vector(1 downto 0)	:="00";
constant MOD_V1S	:std_logic_vector(1 downto 0)	:="01";
constant MOD_V1H	:std_logic_vector(1 downto 0)	:="10";
constant MOD_V2		:std_logic_vector(1 downto 0)	:="11";

signal	MTSAVE		:std_logic;
signal	TRAM_TDAT	:std_logic_vector(7 downto 0);
signal	CRTC_CURL	:std_logic_vector(4 downto 0);
signal	CRTC_CURC	:std_logic_vector(6 downto 0);
signal	CRTC_CURE	:std_logic;

--Font data
signal	FRAMADDR		:std_logic_vector(12 downto 0);
signal	FRAMWDAT		:std_logic_vector(7 downto 0);
signal	FRAMWR		:std_logic;

--DISK emulation
signal	EMUINITDONE	:std_logic;
signal	KBRX		:std_logic;

signal	FDE_ADDR	:std_logic_vector(22 downto 0);
signal	FDE_ADDRW	:std_logic_vector(RAMAWIDTH-1 downto 0);
signal	FDE_RD		:std_logic;
signal	FDE_WR		:std_logic;
signal	FDE_WDAT	:std_logic_vector(15 downto 0);
signal	FDE_RDAT	:std_logic_vector(15 downto 0);
signal	FDE_RAMWAIT	:std_logic;
	
signal	FEC_ADDR	:std_logic_vector(22 downto 0);
signal	FEC_ADDRW	:std_logic_vector(RAMAWIDTH-1 downto 0);
signal	FEC_RD		:std_logic;
signal	FEC_WR		:std_logic;
signal	FEC_WDAT	:std_logic_vector(15 downto 0);
signal	FEC_RDAT	:std_logic_vector(15 downto 0);
signal	FEC_RAMWAIT	:std_logic;

--OPNA
signal	PCMADDR	:std_logic_vector(17 downto 0);
signal	PCMADDRW	:std_logic_vector(RAMAWIDTH-1 downto 0);
signal	PCMRD		:std_logic;
signal	PCMWR		:std_logic;
signal	PCMRDAT	:std_logic_vector(7 downto 0);
signal	PCMWDAT	:std_logic_vector(7 downto 0);
signal	PCMRWAIT	:std_logic;

--video signal
signal	vidR3	:std_logic_vector(2 downto 0);
signal	vidG3	:std_logic_vector(2 downto 0);
signal	vidB3	:std_logic_vector(2 downto 0);
signal	vidR8	:std_logic_vector(7 downto 0);
signal	vidG8	:std_logic_vector(7 downto 0);
signal	vidB8	:std_logic_vector(7 downto 0);
signal	vidHS	:std_logic;
signal	vidVS	:std_logic;
signal	vidEN	:std_logic;
signal	VID_HRTC	:std_logic;
signal	VID_VRTC	:std_logic;
signal	hdmiclk	:std_logic;

signal	subdat	:std_logic_vector(7 downto 0);
begin

	MODE <=	pDip(1 downto 0);

	cHS	<=	'1' when MODE=MOD_V1H else
			'1' when MODE=MOD_V2 else
			'0';
	
	cVer <=	'1' when MODE=MOD_V1S else
			'1' when MODE=MOD_V1H else
			'1' when MODE=MOD_N else
			'0';
	cN <=	'0' when MODE=MOD_N else
			'1';

	cBT		<=pDip(2);
	c40C	<=pDip(4);
	c20L	<=pDip(5);
	cDisk	<=pDip(6);

	MTSAVE	<=pDip(3);

	CPUMD<=pDip(9);

	srstna<=plllocked;	--LOADER_DONE and 
	
	process(rclk,srstna)begin
		if(srstna='0')then
			rstcnt<=100;
			srstn<='0';
		elsif(rclk' event and rclk='0')then
			if(rstcnt=0)then
				srstn<='1';
			else
				rstcnt<=rstcnt-1;
			end if;
		end if;
	end process;
	
	CPU	:T80a generic map(0)
	port map(
		RESET_n	=>CPU_rstn,
		CLK_n	=>CPU_clk,
--		CLK_n	=>slowclk,
--		CLK_n	=>pPsw(0),
		WAIT_n	=>WAIT_n,
		INT_n	=>INT_n,
		NMI_n	=>NMI_n,
		BUSRQ_n	=>BUSRQ_n,
		M1_n	=>M1_n,
		MREQ_n	=>MREQ_np,
		IORQ_n	=>IORQ_np,
		RD_n	=>RD_np,
		WR_n	=>WR_np,
		RFSH_n	=>REFRSHn,
		HALT_n	=>open,
		BUSAK_n	=>BUSACK_n,
		A		=>CPUADRp,
		D		=>CPUDAT
	);

	IORQ_n	<=IORQ_np	when BUSACK_n='1' else '1';
	MREQ_n	<=MREQ_np	when BUSACK_n='1' else '1';
	RD_n	<=RD_np		when BUSACK_n='1' else '1';
	WR_n	<=WR_np		when BUSACK_n='1' else '1';
	CPUADR	<=CPUADRp	when BUSACK_n='1' else (others=>'0');
	


	VRTCi<=not VRTC;

	INT0n<=not INT_COMRX;
	INT1n<=VRTCi;
	INT2n<=RTI;
	INT3n<='1';
	INT4n<=INTn_OPN or SINTM;
	INT5n<='1';
	INT6n<='1';
	INT7n<='1';

	INT	:INTCONTS generic map(x"e4",x"e6")
	port map(
	ADR			=>CPUADR(7 downto 0),
	IORQn		=>IORQ_n,
	WRn			=>WR_n,
	RDn			=>RD_n,
	M1n			=>M1_n,
	RFRSHn		=>REFRSHn,
	DATIN		=>CPUDAT,
	DATOUT		=>IDAT_INTC,
	DATOE		=>INTC_OE,

	INTn		=>INT_n,
	
	INT0n		=>INT0n,
	INT1n		=>INT1n,
	INT2n		=>INT2n,
	INT3n		=>INT3n,
	INT4n		=>INT4n,
	INT5n		=>INT5n,
	INT6n		=>INT6n,
	INT7n		=>INT7n,
	
	cpuclk		=>CPU_clk,
	clk			=>clk21m,
	rstn		=>CPU_rstn
	);
	
	MMAP	:memorymaps generic map(1,RAMAWIDTH) port map(
	CPU_ADR		=>CPUADR,
	CPU_MREQn	=>MREQ_n,
	CPU_IORQn	=>IORQ_n,
	CPU_RDn		=>RD_n,
	CPU_WRn		=>WR_n,
	CPU_WDAT	=>CPUDAT,
	CPU_RDAT	=>IDAT_MAP,
	CPU_OE		=>MAP_OE,
	
	KNJ1_ADR	=>KANJI1ADR,
	KNJ1_RD		=>KANJI1RD,
	
	KNJ2_ADR	=>KANJI2ADR,
	KNJ2_RD		=>KANJI2RD,

	RAM_ADR		=>MAP_RADR,
	RAM_CE		=>RAM_CE,
	
	TRAM_ADR	=>TRAM_ADR,
	TRAM_CE		=>TRAM_CE,
	
	TVRAM_ADR	=>TVRAM_MADR,
	TVRAM_CE	=>TVRAM_CE,
	
	TXTWINEN	=>TXTWINEN,
	
	G_EXTMODE	=>GVAM,
	G_RAMSEL	=>NG_RAMSEL,
	ALUOE		=>ALU_OE,
	ALUME		=>GRAM_M_OE,
	ALURE		=>ALU_RE,
	GADR_MSEL	=>GWME,
	
	clk			=>CPU_clk,
	rstn		=>CPU_rstn
);



--	pLed<=TRAM_CE & TVRAM_CE & RAM_CE & IORQ_n & CPUADR(15 downto 12);
	
	RAMADR<=
			ADDR_BACKRAM(RAMAWIDTH-1 downto 19) & CLR_ADR when CLR_OE='1' else
			ADDR_N88(RAMAWIDTH-1 downto 19) & LOADER_ADR when LOADER_OE='1' else
			VMAP_RADR when TCNV_BUSUSE='1' else
			MAP_RADR;
	RAM_WDAT<=	CLR_WDAT when CLR_OE='1' else 
				LOADER_WDAT when LOADER_OE='1' else
				 CPUDAT;
	RAM_WR<=	CLR_WR when CLR_OE='1' else
				LOADER_WR when LOADER_OE='1' else
				(RAM_CE and (not WR_n));
	RAM_RD<='0' when (LOADER_OE='1' or CLR_OE='1') else
			not TCNV_RDn when TCNV_BUSUSE='1' else
			'1' when KANJI1RD='1' or KANJI2RD='1' else
			(RAM_CE and (not RD_n));
			
	NMI_n<='1';
	
	FRAMADDR<=LOADER_ADR(12 downto 0);
	FRAMWDAT<=LOADER_WDAT;
	FRAMWR<=	LOADER_WR when LOADER_OE='1' and LOADER_ADR(18 downto 13)=ADDR_FONT(18 downto 13) else '0';

	GALU	:GraphALU
port map(
	CS		=>ALU_RE,
	RDn		=>RD_n,
	RDDAT0	=>GRDAT0,
	RDDAT1	=>GRDAT1,
	RDDAT2	=>GRDAT2,
	
	WRDAT0	=>GWDAT0,
	WRDAT1	=>GWDAT1,
	WRDAT2	=>GWDAT2,
	WEBIT	=>GWEBIT,
	
	CPUWD	=>ALUCWD,
	CPURD	=>IDAT_ALU,
	
	ALU0	=>ALU0,
	ALU1	=>ALU1,
	ALU2	=>ALU2,
	
	GDM		=>GDM,
	
	PLN		=>PLN,

	GVAM	=>GVAM,
	GAM		=>GAM,
	NSEL	=>NG_RAMSEL,

	clk		=>clk21m,
	rstn	=>CPU_rstn
);
	

	CPU_clk<=cpuclkb;
	SUBCLK<=subclkb;
	
	VRAMWE<=	"1000" when CLR_OE='1' else
				"1000" when TXTWINEN='1' else
				GWME & GWEBIT;

	GR_RSEL<=	3 when TCNV_BUSUSE='1' else NG_RAMSEL;

	GRAMADRW<=ADDR_GVRAM(RAMAWIDTH-1 downto 15) & GRAMADR & '0';
	FDE_ADDRW<=ADDR_FDEMU(RAMAWIDTH-1 downto 23) & FDE_ADDR(22 downto 0);
	FEC_ADDRW<=ADDR_FDEMU(RAMAWIDTH-1 downto 23) & FEC_ADDR(22 downto 0);
	PCMADDRW<=ADDR_ADPCM(RAMAWIDTH-1 downto 18) & PCMADDR;

	RAM	:SDRAMCde0cvDEMU2 generic map(RAMCAWIDTH,RAMAWIDTH,ramclk/1000,64000/8192)
	port map(
		PMEMCKE			=>pMemCke,
		PMEMCS_N		=>pMemCs_n,
		PMEMRAS_N		=>pMemRas_n,
		PMEMCAS_N		=>pMemCas_n,
		PMEMWE_N		=>pMemWe_n,
		PMEMUDQ			=>pMemUdq,
		PMEMLDQ			=>pMemLdq,
		PMEMBA1			=>pMemBa1,
		PMEMBA0			=>pMemBa0,
		PMEMADR			=>pMemAdr,
		PMEMDAT			=>pMemDat,

		CPUADR			=>RAMADR,
		CPURDAT			=>IDAT_RAM,
		CPUWDAT			=>RAM_WDAT,
		CPUWR			=>RAM_WR,
		CPURD			=>RAM_RD,
		CPUWAIT			=>RAM_WAIT,
		CPUCLK			=>cpuclkb,
		CPURSTn			=>CLR_rstn,
		MRAMDAT			=>TCNV_RDAT,
		
		SUBADR			=>SUBADR,
		SUBRDAT			=>SUBRDAT,
		SUBWDAT			=>SUBWDAT,
		SUBWR			=>SUBWR,
		SUBRD			=>SUBRD,
		SUBWAIT			=>SUBWAIT,
		SUBCLK			=>subclkb,

		ALURD0			=>GRDAT0,
		ALURD1			=>GRDAT1,
		ALURD2			=>GRDAT2,
		VRAMRSEL		=>GR_RSEL,

		ALUCWD			=>ALUCWD,
		ALUWD0			=>GWDAT0,
		ALUWD1			=>GWDAT1,
		ALUWD2			=>GWDAT2,
		VRAMWE			=>VRAMWE,
		
		VIDADR			=>GRAMADRW,
		VIDDAT0			=>GRAMDAT0,
		VIDDAT1			=>GRAMDAT1,
		VIDDAT2			=>GRAMDAT2,
		VIDRD			=>GRAMRD,
		VIDWAIT			=>GRAMWAIT,
		
		FDEADR			=>FDE_ADDRW,
		FDERD			=>FDE_RD,
		FDEWR			=>FDE_WR,
		FDERDAT			=>FDE_RDAT,
		FDEWDAT			=>FDE_WDAT,
		FDEWAIT			=>FDE_RAMWAIT,
		
		FECADR			=>FEC_ADDRW,
		FECRD			=>FEC_RD,
		FECWR			=>FEC_WR,
		FECRDAT			=>FEC_RDAT,
		FECWDAT			=>FEC_WDAT,
		FECWAIT			=>FEC_RAMWAIT,
		
		SNDADR			=>PCMADDRW,
		SNDRD				=>PCMRD,
		SNDWR				=>PCMWR,
		SNDRDAT			=>PCMRDAT,
		SNDWDAT			=>PCMWDAT,
		SNDWAIT			=>PCMRWAIT,
		SNDH_Ln			=>'0',

		monout			=>open,
		
		CLOCKM			=>CPUMD,

		memclk			=>rclk,
		rstn			=>srstn
	);

	CLR_OE<='0';
	loader_rstn<=CLR_rstn;
	
	LOADER_ACK<=not RAM_WAIT;
	
	CPU_rstn<=rstn and LOADER_DONE and EMUINITDONE;

	TRAM	:TEXTRAM port map(
		address_a		=>TRAM_ADR,
		address_b		=>TCNV_TADR,
		clock			=>gclk,
		data_a			=>CPUDAT,
		data_b			=>(others=>'0'),
		wren_a			=>TRAM_CE and (not WR_n),
		wren_b			=>'0',
		q_a				=>IDAT_TRAM,
		q_b				=>TCNV_TDAT
	);
	

	T2V	:TRAMCONV
	port map(
	TVRMODE		=>TVRMODE,
	TMODE		=>not cHS,
	COLOR		=>not COLORn,
	TEXTEN		=>(not TEXTDS) and CRTCen and TDMAEN,
	ATTRLEN		=>ATTRLEN,
	
	TADR_TOP	=>TRAMTOP,

	TRAM_ADR	=>TCNV_TADR,
	TRAM_DAT	=>TCNV_TDAT,
	
	MRAM_ADR	=>TCNV_RADR,
	MRAM_DAT	=>TCNV_RDAT,
	MRAM_RDn	=>TCNV_RDn,
	MRAM_WAIT	=>RAM_WAIT,
	BUS_USE		=>TCNV_BUSUSE,
	
	BUSREQn		=>BUSRQ_n,
	BUSACKn		=>BUSACK_n,
	

	TVRAM_ADR	=>TCNV_WADR,
	TVRAM_WDAT	=>TCNV_WDAT,
	TVRAM_WR	=>TCNV_WE,
	
	VRET		=>VRTC,
	HRET		=>HRTC,
	DONE		=>TCNVDONE,
	
	clk			=>clk21m,
	rstn		=>srstn
);

	TVRAM_WDAT	<=CPUDAT					when TMODE='0' and TVRMODE='1' else TCNV_WDAT;
	TVRAM_ADR	<=TVRAM_MADR 				when TMODE='0' and TVRMODE='1' else TCNV_WADR;
	TVRAM_WE	<=TVRAM_CE and (not WR_n)	when TMODE='0' and TVRMODE='1' else TCNV_WE;

tmap	:trammaps generic map(RAMAWIDTH) port map(
	VADR		=>TCNV_RADR,
	
	RAM_ADR		=>VMAP_RADR
);

	TVRAM	:TEXTRAM port map(
		address_a		=>TVRAM_ADR,
		address_b		=>CRTC_TADR,
		clock			=>gclk,
		data_a			=>TVRAM_WDAT,
		data_b			=>(others=>'0'),
		wren_a			=>TVRAM_WE,
		wren_b			=>'0',
		q_a				=>IDAT_TVRAM,
		q_b				=>TRAM_TDAT
	);
	
	CREG	:CRTCREGS
generic map(
	DATADR	=>x"50",
	CMDADR	=>x"51"
)
port map(
	ADR		=>CPUADR(7 downto 0),
	IORQn	=>IORQ_n,
	WRn		=>WR_n,
	RDn		=>RD_n,
	DATIN	=>CPUDAT,
	DATOUT	=>IDAT_CRTR,
	DATOE	=>CRTR_OE,

	CURL	=>CURL,
	CURC	=>CURC,
	CURE	=>CURE,
	CURM	=>CURM,
	CBLINK	=>CBLINK,
	VMODE	=>VMODE,
	CRTCen	=>CRTCen,
	
	ATTR	=>ATTRLEN,

	clk		=>CPU_clk,
	rstn	=>CPU_rstn
);


	WAIT_n<=	not RAM_WAIT when RAM_CE='1' else
				not RAM_WAIT when KANJI1RD='1' else
				not RAM_WAIT when KANJI2RD='1' else
				IO_WAIT;

	
	process(clk21m,srstn)begin
		if(srstn='0')then
			KBCLKIN<='1';
			KBDATIN<='1';
		elsif(clk21m' event and clk21m='1')then
			KBCLKIN<=pPs2Clkin;
			KBDATIN<=pPs2Datin;

		end if;
	end process;
	
	pPs2Clkout<=KBCLKOUT;
	pPs2Datout<=KBDATOUT;

	KB	:KBMAP generic map(SYSCLK,100) port map(
	ADR		=>CPUADR(7 downto 0),
	IORQn	=>IORQ_n,
	RDn		=>RD_n,
	DAT		=>IDAT_KB,
	OE		=>KB_OE,

	KBCLKIN	=>KBCLKIN,
	KBCLKOUT=>KBCLKOUT,
	KBDATIN	=>KBDATIN,
	KBDATOUT=>KBDATOUT,

	KBDAT	=>open,
	KBRX	=>KBRX,
	KBEN	=>'1',

	monout	=>open,
	
	clk		=>clk21m,
	rstn	=>CPU_rstn
);
	
	CPUDAT<=
				IDAT_RAM	when GRAM_M_OE='1' else
				IDAT_ALU	when ALU_OE='1' else
				IDAT_RAM	when (RAM_CE='1' and RD_n='0') else
				IDAT_TRAM	when (TRAM_CE='1' and RD_n='0') else
				IDAT_TVRAM	when (TVRAM_CE='1' and RD_n='0') else
				IDAT_MAP	when MAP_OE='1' else
				IDAT_CRTR	when CRTR_OE='1' else
				IDAT_KB		when KB_OE='1' else
				IDAT_IOR30	when IOR30_OE='1' else
				IDAT_IOR31	when IOR31_OE='1' else
				IDAT_IOR32	when IOR32_OE='1' else
				IDAT_IOR33	when IOR33_OE='1' else
				IDAT_IOR38	when IOR38_OE='1' else
				IDAT_IOR40	when IOR40_OE='1' else
				IDAT_IOR6e	when IOR6e_OE='1' else
				IDAT_PPIFD	when PPIFD_OE='1' else
				IDAT_RAM	when KANJI1RD='1' else
				IDAT_RAM	when KANJI2RD='1' else
				IDAT_PSG	when PSG_OE='1' else
				IDAT_COM	when COM_OE='1' else
				IDAT_INTC	when INTC_OE='1' else
				(others=>'1') when IORQ_n='0' and RD_n='0' else
				(others=>'Z');
	
--	pMonDBus<=CPUDAT;

	IOW10	:IO_WRS generic map(x"10")port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,open,open,open,open,C_DO,C_RTC(2),C_RTC(1),C_RTC(0),CPU_clk,CPU_rstn);
	IOR30	:IO_RD generic map(x"30")port map(CPUADR(7 downto 0),IORQ_n,RD_n,IDAT_IOR30,IOR30_OE,'0','0','0','0',c20L,c40C,cBT,cN);
	IOW30	:IO_WRS generic map(x"30")port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,open,open,BS(1),BS(0),MTON,CDS,COLORn,HMODE,CPU_clk,CPU_rstn);
	IOR31	:IO_RD generic map(x"31")port map(CPUADR(7 downto 0),IORQ_n,RD_n,IDAT_IOR31,IOR31_OE,cVer,cHS,'1','1','1','0','1','1');
	IOW31	:IO_WRS generic map(x"31")port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,open,open,open,GCOLOR,GRAPHEN,RMODE,MMODE,L200,CPU_clk,CPU_rstn);
	IO32	:IO_RWS generic map(x"32")port map(CPUADR(7 downto 0),IORQ_n,RD_n,WR_n,CPUDAT,IDAT_IOR32,IOR32_OE,SINTM,open,PMODE,TMODE,open,open,EROMSEL1,EROMSEL0,CPU_clk,CPU_rstn);
	IO33	:IO_RWS generic map(x"33")port map(CPUADR(7 downto 0),IORQ_n,RD_n,WR_n,CPUDAT,IDAT_IOR33,IOR33_OE,open,open,open,open,open,open,open,open,CPU_clk,CPU_rstn);
	IOW34	:IO_WRS generic map(x"34")port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,open,ALU2(1),ALU1(1),ALU0(1),open,ALU2(0),ALU1(0),ALU0(0),CPU_clk,CPU_rstn);
	IOW35	:IO_WRS generic map(x"35")port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,GAM,open,GDM(1),GDM(0),open,PLN(2),PLN(1),PLN(0),CPU_clk,CPU_rstn);
	IO38	:IO_RWS generic map(x"38")port map(CPUADR(7 downto 0),IORQ_n,RD_n,WR_n,CPUDAT,IDAT_IOR38,IOR38_OE,open,open,open,open,open,open,open,TVRMODE,CPU_clk,CPU_rstn);
	IOR40	:IO_RD generic map(x"40")port map(CPUADR(7 downto 0),IORQ_n,RD_n,IDAT_IOR40,IOR40_OE,'0','0',VRTC,CDI,cDisk,'1','0','0');
	IOW40	:IO_WRS generic map(x"40")port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,open,pStr,beepen,open,open,CCK,CSTB,open,CPU_clk,CPU_rstn);
	IOR6e	:IO_RD generic map(x"6e")port map(CPUADR(7 downto 0),IORQ_n,RD_n,IDAT_IOR6e,IOR6e_OE,not CPUMD,'1','1','1','1','1','1','1');
	IOW53	:IO_WRS generic map(x"53")port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,open,open,open,open,GxDS(2),GxDS(1),GxDS(0),TEXTDS,CPU_clk,CPU_rstn);
	IOW71	:IO_WRS generic map(x"71")port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,open,open,open,open,open,open,open,IEROM,CPU_clk,CPU_rstn);
	TDREG	:TDMAREGS generic map(x"64",x"65",x"68") port map(CPUADR(7 downto 0),IORQ_n,WR_n,CPUDAT,TRAMTOP,TRAMLEN,TDMAEN,CPU_clk,CPU_rstn);
	pStrA<=pStr;
	pStrB<=pStr;
	
	LOWRES<=L200 or GCOLOR;
	
	PPIFD_CSn<='0' when IORQ_n='0' and CPUADR(7 downto 2)="111111" else '1';
	PPIFD	:e8255 port map(
		CSn		=>PPIFD_CSn,
		RDn		=>RD_n,
		WRn		=>WR_n,
		ADR		=>CPUADR(1 downto 0),
		DATIN	=>CPUDAT,
		DATOUT	=>IDAT_PPIFD,
		DATOE	=>PPIFD_OE,
		
		PAi		=>SUB_RXS2M,
		PAo		=>SUB_RXM2S,
		PAoe		=>open,
		PBi		=>SUB_TXS2M,
		PBo		=>SUB_TXM2S,
		PBoe		=>open,
		PCHi		=>SUB_HTS2M,
		PCHo		=>SUB_HTM2S,
		PCHoe		=>open,
		PCLi		=>SUB_HRS2M,
		PCLo		=>SUB_HRM2S,
		PCLoe		=>open,
		
		clk		=>CPU_clk,
		rstn	=>CPU_rstn
	);

	KNJ1	:KANJIROM generic map(x"e8") port map(
		ADR		=>CPUADR(7 downto 0),
		IORQn	=>IORQ_n,
		RDn		=>RD_n,
		WRn		=>WR_n,
		WDAT	=>CPUDAT,
		
		KNJADR	=>KANJI1ADR,
		KNJRD	=>KANJI1RD,
		
		clk		=>CPU_clk,
		rstn	=>CPU_rstn
	);

	KNJ2	:KANJIROM generic map(x"ec") port map(
		ADR		=>CPUADR(7 downto 0),
		IORQn	=>IORQ_n,
		RDn		=>RD_n,
		WRn		=>WR_n,
		WDAT	=>CPUDAT,
		
		KNJADR	=>KANJI2ADR,
		KNJRD	=>KANJI2RD,
		
		clk		=>CPU_clk,
		rstn	=>CPU_rstn
	);


--	IOWA	:IOWAIT port map(IORQ_n,RD_n,WR_n,IO_WAIT,cpu_clk,srstn);
	IO_WAIT	<='1';
	
	process(cpu_clk,srstn)begin
		if(srstn='0')then
			slowclk<='0';
			clkcount<=500000;
		elsif(cpu_clk' event and cpu_clk='1')then
			if(clkcount>0)then
				clkcount<=clkcount-1;
			else
				slowclk<=not slowclk;
				clkcount<=500000;
			end if;
		end if;
	end process;

	CRTC_TDAT<=	TRAM_TDAT;
	
	CRT	:CRTCP port map(
	IORQn		=>IORQ_n,
	WRn			=>WR_n,
	ADR			=>CPUADR(7 downto 0),
	WDAT		=>CPUDAT,
	PALEN		=>'1',
	
	TRAM_ADR	=>CRTC_TADR,
	TRAM_DAT	=>CRTC_TDAT,
	
	GRAMADR		=>GRAMADR,
	GRAMRD		=>GRAMRD,
	GRAMWAIT	=>GRAMWAIT,
	GRAMDAT0	=>GRAMDAT0,
	GRAMDAT1	=>GRAMDAT1,
	GRAMDAT2	=>GRAMDAT2,
	
	ROUT		=>vidR3,
	GOUT		=>vidG3,
	BOUT		=>vidB3,
	VIDEN		=>vidEN,
	
	HSYNC		=>vidHS,
	VSYNC		=>vidVS,
	
	HMODE		=>HMODE,		-- 1:80chars 0:40chars
	VMODE		=>VMODE,		-- 1:25lines 0:20lines
	PMODE		=>PMODE,		-- 1:512 colors 0:8 colors
	TXTMODE		=>'0',
	
	GRAPHEN		=>GRAPHEN,
	LOWRES		=>LOWRES,
	GCOLOR		=>GCOLOR,
	MONOEN		=>not GxDS,
	TXTEN		=>((not TEXTDS) and TXTen and CRTCen and TDMAEN),
	
	CURL		=>CRTC_CURL,
	CURC		=>CRTC_CURC,
	CURE		=>CRTC_CURE,
	CURM		=>CURM,
	CBLINK		=>CBLINK,
	
	--HRTC		=>VID_HRTC,
	--VRTC		=>VID_VRTC,
	HRTC		=>HRTC,
	VRTC		=>VRTC,
	
	FRAMWADR	=>FRAMADDR,
	FRAMWDAT	=>FRAMWDAT,
	FRAMWR	=>FRAMWR,
	
	gclk		=>gclk,
	cpuclk		=>CPU_clk,
	clk			=>rclk,
	rstn		=>CPU_rstn
	);

	vidR8<=vidR3 & vidR3 & vidR3(2 downto 1);
	vidG8<=vidG3 & vidG3 & vidG3(2 downto 1);
	vidB8<=vidB3 & vidB3 & vidB3(2 downto 1);
	
	process(gclk,rstn)begin
		if(srstn='0')then
			hdmiclk<='0';
		elsif(gclk' event and gclk='1')then
			hdmiclk<=not hdmiclk;
		end if;
	end process;
	
	pVideoR<=vidR8;
	pVideoG<=vidG8;
	pVideoB<=vidB8;
	pVideoVS<=vidVS;
	pVideoHS<=VidHS;
	pVideoEn<=vidEN;
	pVideoClk<=gclk;

	--pVideoHB<= not VID_HRTC;
	--pVideoVB<= not VID_VRTC;
	pVideoHB<= HRTC;
	pVideoVB<= VRTC;
	
	CRTC_CURL<=	CURL;
	CRTC_CURC<=	CURC;
	CRTC_CURE<=	CURE;
	
	U_RTC	:rtc4990MiSTer generic map(sysclk*1000,x"00") port map(
		DCLK	=>CCK,
		DIN		=>C_DO,
		DOUT	=>CDI,
		C		=>C_RTC,
		CS		=>'1',
		STB		=>not CSTB,
		OE		=>'1',

		RTCIN	=>sysrtc,

		sclk	=>clk21m,
		rstn	=>srstn
	);

	PCLKG	:unchchata port map(not pjoya(1),pclk,cpu_clk,srstn);
	
	TIMP600	:sftclk generic map(21477270,600,1) port map("0",RTI,clk21m,srstn);
	
	SUBU	:SUBunitsMiSTer generic map(SYSCLK,RAMCLK,RAMAWIDTH) port map(
		RAMADR			=>SUBADR,
		RAMRDAT			=>SUBRDAT,
		RAMWDAT			=>SUBWDAT,
		RAMWR			=>SUBWR,
		RAMRD			=>SUBRD,
		RAMWAIT			=>SUBWAIT,
		
		SUBIO_PAI		=>SUB_TXM2S,
		SUBIO_PAO		=>SUB_TXS2M,
		SUBIO_PBI		=>SUB_RXM2S,
		SUBIO_PBO		=>SUB_RXS2M,
		SUBIO_PCHI		=>SUB_HRM2S,
		SUBIO_PCHO		=>SUB_HRS2M,
		SUBIO_PCLI		=>SUB_HTM2S,
		SUBIO_PCLO		=>SUB_HTS2M,
		
		FD_SYNC			=>pFd_sync,
		
		MTSAVEON		=>MTSAVE,
		

	--MiSTer diskimage
		mist_mounted	=>mist_mounted,
		mist_readonly	=>mist_readonly,
		mist_imgsize	=>mist_imgsize,

		mist_lba			=>mist_lba,
		mist_rd			=>mist_rd,
		mist_wr			=>mist_wr,
		mist_ack			=>mist_ack,

		mist_buffaddr	=>mist_buffaddr,
		mist_buffdout	=>mist_buffdout,
		mist_buffdin	=>mist_buffdin,
		mist_buffwr		=>mist_buffwr,
		
		FDE_ADDR		=>FDE_ADDR,
		FDE_RD			=>FDE_RD,
		FDE_WR			=>FDE_WR,
		FDE_WDAT		=>FDE_WDAT,
		FDE_RDAT		=>FDE_RDAT,
		FDE_RAMWAIT		=>FDE_RAMWAIT,
		
		FEC_ADDR		=>FEC_ADDR,
		FEC_RD			=>FEC_RD,
		FEC_WR			=>FEC_WR,
		FEC_WDAT		=>FEC_WDAT,
		FEC_RDAT		=>FEC_RDAT,
		FEC_RAMWAIT		=>FEC_RAMWAIT,
		
		mondat	=>subdat,

		EMUINITDONE		=>EMUINITDONE,
		EMUBUSY			=>pLed,
		CPUCLK			=>SUBCLK,
		clk21m			=>clk21m,
		ramclk			=>rclk,
		pclk			=>emuclk,
		vclk			=>gclk,
		srstn			=>srstn,
		rstn			=>CPU_rstn
	);

	process(rclk)begin
		if(rclk' event and rclk='1')then
			pMonDbus<=subdat;
		end if;
	end process;
	
	
OPNS	:sftgen generic map(2) port map(2,OPNsft,clk21m,srstn);	--22.222/2=11.111MHz

	pJoy<=pJoyA and pJoyB;

	selopn	:if USE_OPNA=0 generate
		
		PSG_CEn<=IORQ_n when CPUADR(7 downto 1)="0100010" else '1';		--0x44,45

		FMS	:OPN generic map(16) port map(
			DIN		=>CPUDAT,
			DOUT	=>IDAT_PSG,
			DOE		=>PSG_OE,
			CSn		=>PSG_CEn,
			ADR0	=>CPUADR(0),
			RDn		=>RD_n,
			WRn		=>WR_n,
			INTn	=>INTn_OPN,
			
			snd		=>snddatL,
			
			PAOUT	=>open,
			PAIN	=>"1111" & pJoy(3 downto 0),
			PAOE	=>open,
			
			PBOUT	=>open,
			PBIN	=>"111111" & pJoy(5 downto 4),
			PBOE	=>open,

			clk		=>clk21m,
			cpuclk	=>cpu_clk,
			sft		=>OPNsft,
			rstn	=>CPU_rstn
		);
		
		PCMADDR	<=(others=>'0');
		PCMRD		<='0';
		PCMWR		<='0';
		PCMWDAT	<=(others=>'0');
		snddatR<=BEEPSND;
		
	end generate;
	selopna	:if USE_OPNA/=0 generate

		PSG_CEn<=IORQ_n when CPUADR(7 downto 2)="010001" else '1';		--0x44,45,46,47
	
		FMS	:OPNA generic map(16) port map(
			DIN		=>CPUDAT,
			DOUT	=>IDAT_PSG,
			DOE		=>PSG_OE,
			CSn		=>PSG_CEn,
			ADR		=>CPUADR(1 downto 0),
			RDn		=>RD_n,
			WRn		=>WR_n,
			INTn	=>INTn_OPN,
			
			sndL		=>sndL,
			sndR		=>sndR,
			sndPSG	=>sndPSG,
		
			PAOUT	=>open,
			PAIN	=>"1111" & pJoy(3 downto 0),
			PAOE	=>open,
			
			PBOUT	=>open,
			PBIN	=>"111111" & pJoy(5 downto 4),
			PBOE	=>open,

			RAMADDR	=>PCMADDR,
			RAMRD		=>PCMRD,
			RAMWR		=>PCMWR,
			RAMRDAT	=>PCMRDAT,
			RAMWDAT	=>PCMWDAT,
			RAMWAIT	=>PCMRWAIT,

			clk		=>clk21m,
			cpuclk	=>cpu_clk,
			sft		=>OPNsft,
			rstn	=>CPU_rstn
		);
		
		sndmixL	:average generic map(16) port map(sndL,monosnd,snddatL);
		sndmixR	:average generic map(16) port map(sndR,monosnd,snddatR);
	
		monos	:average generic map(16) port map(sndPSG,BEEPsnd,monosnd);
		
	end generate;
	
	pJoyA<=(others=>'Z');
	pJoyB<=(others=>'Z');
	
	beep	:beeposc generic map(2400,SYSCLK) port map(beepsig,clk21m,rstn);
	
	BEEPsnd<=	(others=>'0') when BEEPEN='0' else
					x"4000"	when beepsig='1' else
					x"c000";

	pSndL<=snddatL;
	pSndR<=snddatR;

	COM_CSn<=IORQ_n when CPUADR(7 downto 1)="0010000" else '1';	--0x20,21

	COM_vDIV<=conv_std_logic_vector(COM_DIV,11);
	COMB	:clkdiv generic map(11) port map(COM_vDIV,COM_clk,clk21m,srstn);
	
	USART	:e8251 port map(
		WRn		=>WR_n,
		RDn		=>RD_n,
		C_Dn	=>CPUADR(0),
		CSn		=>COM_CSn,
		DATIN	=>CPUDAT,
		DATOUT	=>IDAT_COM,
		DATOE	=>COM_OE,
		
		TXD		=>pCOM_TxD,
		RxD		=>pCOM_RxD,
		
		DSRn	=>'0',
		DTRn	=>open,
		RTSn	=>pCOM_RTS,
		CTSn	=>pCOM_CTS and BS(1),
		
		TxRDY	=>open,
		TxEMP	=>open,
		RxRDY	=>INT_COMRX,
		
		TxCn	=>COM_clk,
		RxCn	=>COM_clk,
		
		clk		=>clk21m,
		rstn	=>CPU_rstn
	);

	process(clk21m,srstn)begin
		if(srstn='0')then
			TXTen<='1';
			TenSW<='0';
		elsif(clk21m' event and clk21m='1')then
			if(pPsw(1)='0' and TenSW='1')then
				TXTen<=not TXTen;
			end if;
			TenSW<=pPsw(1);
		end if;
	end process;


	end MAIN;
