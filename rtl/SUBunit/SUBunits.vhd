LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.FDC_sectinfo.all;
use work.FDC_timing.all;

entity SUBunits is
generic(
	sysclk	:integer	:=21477;		--in kHz
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
	
	FD_DENn			:out std_logic;
	FD_INDEXn		:in std_logic;
	FD_DIRn			:out std_logic;
	FD_STEPn		:out std_logic;
	FD_WDATAn		:out std_logic;
	FD_WGATEn		:out std_logic;
	FD_TRK00n		:in std_logic;
	FD_WPTn			:in std_logic;
	FD_RDATAn		:in std_logic;
	FD_SIDE1n		:out std_logic;
	FD_DSKCHG		:in std_logic;
	FD_DS0			:out std_logic;
	FD_MOTOR0		:out std_logic;
	FD_DS1			:out std_logic;
	FD_MOTOR1		:out std_logic;
	FDSSEL0			:in std_logic;
	FDSSEL1			:in std_logic;
	
	MTSAVEON		:in std_logic;
	
	CPUCLK			:in std_logic;
	clk21m			:in std_logic;
	ramclk			:in std_logic;
	rstn			:in std_logic
);
end SUBunits;

architecture MAIN of SUBunits is
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

component mmapsub
generic(
	awidth	:integer	:=24
);
port(
	CPU_ADR		:in std_logic_vector(15 downto 0);
	CPU_MREQn	:in std_logic;
	CPU_WRn		:in std_logic;
	
	RAM_ADR		:out std_logic_vector(awidth-1 downto 0);
	RAM_CE		:out std_logic;
	
	
	clk			:in std_logic;
	rstn		:in std_logic
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

component IO_DETAC
generic(
	IOADR	:in std_logic_vector(7 downto 0)	:=x"00"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	ACn		:in std_logic;

	det		:out std_logic;

	clk		:in std_logic;
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

component INTSUB
port(
	IORQn	:in std_logic;
	MREQn	:in std_logic;
	RDn		:in std_logic;
	M1n		:in std_logic;
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;

	
	cpuclk	:in std_logic;
	rstn	:in std_logic
);
end component;

component FDtiming
generic(
	sysclk	:integer	:=21477		--in kHz
);
port(
	drv0sel		:in std_logic;		--0:300rpm 1:360rpm
	drv1sel		:in std_logic;
	drv0sele	:in std_logic;		--1:speed selectable
	drv1sele	:in std_logic;

	drv0hd		:in std_logic;
	drv0hdi		:in std_logic;		--IBM 1.44MB format
	drv1hd		:in std_logic;
	drv1hdi		:in std_logic;		--IBM 1.44MB format
	
	drv0hds		:out std_logic;
	drv1hds		:out std_logic;
	
	drv0int		:out integer range 0 to (BR_300_D*sysclk/1000000);
	drv1int		:out integer range 0 to (BR_300_D*sysclk/1000000);
	
	hmssft		:out std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end component;

component  FDCs
generic(
	maxtrack	:integer	:=85;
	maxbwidth	:integer	:=88;
	rdytout		:integer	:=800;
	preseek		:std_logic	:='0';
	sysclk		:integer	:=20
);
port(
	RDn		:in std_logic;
	WRn		:in std_logic;
	CSn		:in std_logic;
	A0		:in std_logic;
	WDAT	:in std_logic_vector(7 downto 0);
	RDAT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;
	DACKn	:in std_logic;
	DRQ		:out std_logic;
	TC		:in std_logic;
	INTn	:out std_logic;
	WAITIN	:in std_logic	:='0';

	WREN	:out std_logic;		--pin24
	WRBIT	:out std_logic;		--pin22
	RDBIT	:in std_logic;		--pin30
	STEP	:out std_logic;		--pin20
	SDIR	:out std_logic;		--pin18
	WPRT	:in std_logic;		--pin28
	track0	:in std_logic;		--pin26
	index	:in std_logic;		--pin8
	side	:out std_logic;		--pin32
	usel	:out std_logic_vector(1 downto 0);
	READY	:in std_logic;		--pin34
	
	int0	:in integer range 0 to maxbwidth;
	int1	:in integer range 0 to maxbwidth;
	int2	:in integer range 0 to maxbwidth;
	int3	:in integer range 0 to maxbwidth;
	
	td0		:in std_logic;
	td1		:in std_logic;
	td2		:in std_logic;
	td3		:in std_logic;
	
	hmssft	:in std_logic;		--0.5msec
	
	busy	:out std_logic;
	mfm		:out std_logic;
	
	ismode	:in std_logic	:='1';
	
	sclk	:in std_logic;
	fclk	:in std_logic;
	rstn	:in std_logic
);
end component;

component dc2ry
generic(
	delay	:integer	:=100
);
port(
	USEL	:in std_logic_vector(1 downto 0);
	BUSY	:in std_logic;
	DSKCHGn	:in std_logic;
	RDBITn	:in std_logic;
	INDEXn	:in std_logic;
	
	READYn	:out std_logic;
	READYV	:out std_logic_vector(3 downto 0);
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component MTsave
generic(
	SYS_CLK	:integer	:=20;
	DELAY	:integer	:=4000
);
port(
	MTIN	:in std_logic;
	EN		:in std_logic;
	READY	:in std_logic;
	MTOUT	:out std_logic;
	
	SAVEON	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component intchk
generic(
	interval	:integer	:=100;
	chk			:integer	:=10
);
port(
	en			:out std_logic;
	clk			:in std_logic;
	rstn		:in std_logic
);
end component;


signal	IDAT	:std_logic_vector(7 downto 0);
signal	CPUDAT	:std_logic_vector(7 downto 0);
signal	IDAT_IO12	:std_logic_vector(7 downto 0);
signal	IO12_OE		:std_logic;
signal	IDAT_PPI	:std_logic_vector(7 downto 0);
signal	PPI_OE		:std_logic;
signal	IDAT_FDC	:std_logic_vector(7 downto 0);
signal	FDC_OE		:std_logic;
signal	IDAT_INT	:std_logic_vector(7 downto 0);
signal	INT_OE		:std_logic;
signal	ADR			:std_logic_Vector(15 downto 0);
signal	MREQn		:std_logic;
signal	IORQn		:std_logic;
signal	M1n			:std_logic;
signal	RDn			:std_logic;
signal	WRn			:std_logic;
signal	RAMCE		:std_logic;
signal	INTn		:std_logic;
signal	TD1,TD0		:std_logic;
signal	RV1,RV0		:std_logic;
signal	MON1,MON0	:std_logic;
signal	TC			:std_logic;
signal	FDC_CEn		:std_logic;
signal	FD_USEL		:std_logic_vector(1 downto 0);
signal	FD_HDS		:std_logic_vector(1 downto 0);
signal	FD_hmssft	:std_logic;
signal	FD_int0		:integer range 0 to (BR_300_D*sysclk/1000000);
signal	FD_int1		:integer range 0 to (BR_300_D*sysclk/1000000);
signal	FD_READY	:std_logic;
signal	PPI_CSn		:std_logic;
signal	PSEN		:std_logic;
signal	FD_DENl		:std_logic;
signal	FDC_BUSY	:std_logic;
signal	MONEN		:std_logic;
signal	FDDEN		:std_logic;
signal	EN1,EN0		:std_logic;
signal	MON1S,MON0S	:std_logic;
signal	RDYV		:std_logic_vector(3 downto 0);

begin
	cpu:T80a generic map(0)port map(
       RESET_n		=>rstn,
        CLK_n		=>CPUCLK,
        WAIT_n		=>not RAMWAIT,
        INT_n       =>INTn,
--        INT_n       =>'1',
        NMI_n       =>'1',
        BUSRQ_n     =>'1',
        M1_n        =>M1n,
        MREQ_n      =>MREQn,
        IORQ_n      =>IORQn,
        RD_n        =>RDn,
        WR_n        =>WRn,
        RFSH_n      =>open,
        HALT_n      =>open,
        BUSAK_n     =>open,
        A           =>ADR,
        D           =>CPUDAT
	);

	mmap	:mmapsub generic map(awidth) port map(
		CPU_ADR		=>ADR,
		CPU_MREQn	=>MREQn,
		CPU_WRn		=>WRn,
	
		RAM_ADR		=>RAMADR,
		RAM_CE		=>RAMCE,
		
		clk			=>CPUCLK,
		rstn		=>rstn
	);
	
	
	CPUDAT<=	IDAT_INT	when INT_OE='1'  else
				RAMRDAT when RAMCE='1' and RDn='0' else
				IDAT_IO12	when IO12_OE='1' else
				IDAT_PPI	when PPI_OE='1' else
				IDAT_FDC	when FDC_OE='1'  else
				(others=>'Z');
	
	RAMWDAT<=CPUDAT;
	RAMWR<=RAMCE and not WRn;
	RAMRD<=RAMCE and not RDn;
	
--	IO12	:IO_RWS generic map(x"12") port map(ADR(7 downto 0),IORQn,RDn,WRn,CPUDAT,IDAT_IO12,IO12_OE,monout(7),monout(6),monout(5),monout(4),monout(3),monout(2),monout(1),monout(0),CPUCLK,rstn);
	IOf4	:IO_WRS generic map(x"f4") port map(ADR(7 downto 0),IORQn,WRn,CPUDAT,open,open,open,open,TD1,TD0,RV1,RV0,CPUCLK,rstn);
	IOf8	:IO_WRS generic map(x"f8") port map(ADR(7 downto 0),IORQn,WRn,CPUDAT,open,open,open,open,PSEN,open,MON1S,MON0S,CPUCLK,rstn);
	IOf8r	:IO_DETAC generic map(x"f8") port map(ADR(7 downto 0),IORQn,RDn,TC,CPUCLK,rstn);
	
	FDC_CEn<='0' when IORQn='0' and ADR(7 downto 1)="1111101" else '1';
	PPI_CSn<='0' when IORQn='0' and ADR(7 downto 2)="111111" else '1';
	PPI	:e8255 port map(
		CSn		=>PPI_CSn,
		RDn		=>RDn,
		WRn		=>WRn,
		ADR		=>ADR(1 downto 0),
		DATIN	=>CPUDAT,
		DATOUT	=>IDAT_PPI,
		DATOE	=>PPI_OE,
		
		PAi		=>SUBIO_PAI,
		PAo		=>SUBIO_PAO,
		PAoe		=>open,
		PBi		=>SUBIO_PBI,
		PBo		=>SUBIO_PBO,
		PBoe		=>open,
		PCHi		=>SUBIO_PCHI,
		PCHo		=>SUBIO_PCHO,
		PCHoe		=>open,
		PCLi		=>SUBIO_PCLI,
		PCLo		=>SUBIO_PCLO,
		PCLoe		=>open,
		
		clk		=>CPUCLK,
		rstn	=>rstn
	);
	
	INTC	:INTSUB port map(IORQn,MREQn,RDn,M1n,IDAT_INT,INT_OE,CPUCLK,rstn);
	
	FDT	:FDtiming generic map(sysclk) port map(
		drv0sel		=>FDSSEL0,	--0:300rpm 1:360rpm
		drv1sel		=>FDSSEL1,
		drv0sele	=>'0',
		drv1sele	=>'0',
	
		drv0hd		=>RV0,
		drv0hdi		=>'1',		--IBM 1.44MB format
		drv1hd		=>RV1,
		drv1hdi		=>'1',		--IBM 1.44MB format
		
		drv0hds		=>FD_HDS(0),
		drv1hds		=>FD_HDS(1),
		
		drv0int		=>FD_int0,
		drv1int		=>FD_int1,
		
		hmssft		=>FD_hmssft,
		
		clk			=>clk21m,
		rstn		=>rstn
	);
	
	FD	:FDCs generic map(
	maxtrack	=>85,
	maxbwidth	=>(BR_300_D*sysclk/1000000),
	sysclk		=>sysclk/1000
)
port map(
	RDn		=>RDn,
	WRn		=>WRn,
	CSn		=>FDC_CEn,
	A0		=>ADR(0),
	WDAT	=>CPUDAT,
	RDAT	=>IDAT_FDC,
	DATOE	=>FDC_OE,
	DACKn	=>'1',
	DRQ		=>open,
	TC		=>TC,
	INTn	=>INTn,

	WREN	=>FD_WGATEn,
	WRBIT	=>FD_WDATAn,
	RDBIT	=>FD_RDATAn,
	STEP	=>FD_STEPn,
	SDIR	=>FD_DIRn,
	WPRT	=>FD_WPTn,
	track0	=>FD_TRK00n,
	index	=>FD_INDEXn,
	side	=>FD_SIDE1n,
	usel	=>FD_USEL,
	READY	=>FD_READY,
	
	int0	=>FD_int0,
	int1	=>FD_int1,
	int2	=>FD_int0,
	int3	=>FD_int1,
	
	td0		=>TD0,
	td1		=>TD1,
	td2		=>'0',
	td3		=>'0',
	
	hmssft	=>FD_hmssft,
	
	busy	=>FDC_BUSY,
	mfm		=>open,

	sclk	=>CPUCLK,
	fclk	=>clk21m,
	rstn	=>rstn
);

	CHK	:intchk generic map(500*sysclk,1*sysclk)port map(MONEN,clk21m,rstn);

	FDDEN<=FDC_BUSY or MONEN;

	FD_DS0<='1' when FDDEN='0' else '0' when FD_USEL="00" else '1';
	FD_DS1<='1' when FDDEN='0' else '0' when FD_USEL="01" else '1';

	d2r	:dc2ry generic map(100) port map(
		USEL	=> FD_USEL,
		BUSY	=>FDDEN,
		DSKCHGn	=> FD_DSKCHG,
		RDBITn	=> FD_RDATAn,
		INDEXn	=> FD_INDEXn,
		
		READYn	=> FD_READY,
		READYV	=> RDYV,
		
		clk		=> clk21m,
		rstn	=> rstn
	);
	EN0<='1' when FDC_BUSY='1' and FD_USEL="00" else '0';
	EN1<='1' when FDC_BUSY='1' and FD_USEL="01" else '0';

	MTS0 :MTsave generic map(sysclk,4000) port map(MON0S,EN0,RDYV(0),MON0,MTSAVEON,clk21m,rstn);
	MTS1 :MTsave generic map(sysclk,4000) port map(MON1S,EN1,RDYV(1),MON1,MTSAVEON,clk21m,rstn);

	FD_MOTOR0<=not MON0;
	FD_MOTOR1<=not MON1;

--	FD_READY<=not FD_DSKCHG;
	FD_DENl<=not FD_HDS(0) when FD_USEL="00" else not FD_HDS(1) when FD_USEL="01" else '1';
	FD_DENn<='0' when FD_DENl='0' else 'Z';
end MAIN;