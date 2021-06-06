LIBRARY	IEEE,WORK;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	USE	WORK.addressmap_pkg.ALL;

ENTITY SDRAMCde0cvDEMU2 IS
	generic(
		CAWIDTH			:integer	:=10;
		AWIDTH			:integer	:=25;
		CLKMHZ			:integer	:=82;			--MHz
		REFCYC			:integer	:=64000/8192	--usec
	);
	port(
		-- SDRAM PORTS
		PMEMCKE			: OUT	STD_LOGIC;							-- SD-RAM CLOCK ENABLE
		PMEMCS_N			: OUT	STD_LOGIC;							-- SD-RAM CHIP SELECT
		PMEMRAS_N		: OUT	STD_LOGIC;							-- SD-RAM ROW/RAS
		PMEMCAS_N		: OUT	STD_LOGIC;							-- SD-RAM /CAS
		PMEMWE_N			: OUT	STD_LOGIC;							-- SD-RAM /WE
		PMEMUDQ			: OUT	STD_LOGIC;							-- SD-RAM UDQM
		PMEMLDQ			: OUT	STD_LOGIC;							-- SD-RAM LDQM
		PMEMBA1			: OUT	STD_LOGIC;							-- SD-RAM BANK SELECT ADDRESS 1
		PMEMBA0			: OUT	STD_LOGIC;							-- SD-RAM BANK SELECT ADDRESS 0
		PMEMADR			: OUT	STD_LOGIC_VECTOR( 12 DOWNTO 0 );	-- SD-RAM ADDRESS
		PMEMDAT			: INOUT	STD_LOGIC_VECTOR( 15 DOWNTO 0 );	-- SD-RAM DATA

		CPUADR			:in std_logic_vector(AWIDTH-1 downto 0);
		CPURDAT			:out std_logic_vector(7 downto 0);
		CPUWDAT			:in std_logic_vector(7 downto 0);
		CPUWR				:in std_logic;
		CPURD				:in std_logic;
		CPUWAIT			:out std_logic;
		CPUCLK			:out std_logic;
		CPURSTn			:out std_logic;
		MRAMDAT			:out std_logic_vector(7 downto 0);
		
		SUBADR			:in std_logic_vector(AWIDTH-1 downto 0);
		SUBRDAT			:out std_logic_vector(7 downto 0);
		SUBWDAT			:in std_logic_vector(7 downto 0);
		SUBWR				:in std_logic;
		SUBRD				:in std_logic;
		SUBWAIT			:out std_logic;
		SUBCLK			:out std_logic;

		ALURD0			:out std_logic_vector(7 downto 0);
		ALURD1			:out std_logic_vector(7 downto 0);
		ALURD2			:out std_logic_vector(7 downto 0);
		VRAMRSEL			:in integer range 0 to 3;
		
		ALUCWD			:out std_logic_vector(7 downto 0);
		ALUWD0			:in std_logic_vector(7 downto 0);
		ALUWD1			:in std_logic_vector(7 downto 0);
		ALUWD2			:in std_logic_vector(7 downto 0);
		VRAMWE			:in std_logic_vector(3 downto 0);
		
		VIDADR			:in std_logic_vector(AWIDTH-1 downto 0);
		VIDDAT0			:out std_logic_vector(7 downto 0);
		VIDDAT1			:out std_logic_vector(7 downto 0);
		VIDDAT2			:out std_logic_vector(7 downto 0);
		VIDRD				:in std_logic;
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
		SNDRD				:in std_logic;
		SNDWR				:in std_logic;
		SNDRDAT			:out std_logic_vector(7 downto 0);
		SNDWDAT			:in std_logic_vector(7 downto 0);
		SNDWAIT			:out std_logic;
		SNDH_Ln			:in std_logic;
		
		monout			:out std_logic_vector(7 downto 0);
		
		CLOCKM			:in std_logic;
		
		memclk			:in std_logic;
		rstn				:in std_logic
	);
end SDRAMCde0cvDEMU2;

architecture MAIN of SDRAMCde0cvDEMU2 is
type state_t is (
	ST_REFRSH,
	ST_READ,
	ST_WRITE,
	ST_VREAD,
	ST_VWRITE,
	ST_INITPALL,
	ST_INITREF,
	ST_INITMRS,
	ST_VIDREAD,
	ST_SUBREAD,
	ST_SUBWRITE,
	ST_FDEREAD,
	ST_FDEWRITE,
	ST_FECREAD,
	ST_FECWRITE,
	ST_SNDREAD,
	ST_SNDWRITE
);
signal	STATE,lSTATE	:state_t;


--	signal	STATE,lSTATE	:integer range 0 to 10;
--	constant ST_REFRSH	:integer	:=0;
--	constant ST_READ	:integer	:=1;
--	constant ST_WRITE	:integer	:=2;
--	constant ST_VREAD	:integer	:=3;
--	constant ST_VWRITE	:integer	:=4;
--	constant ST_INITPALL:integer	:=5;
--	constant ST_INITREF	:integer	:=6;
--	constant ST_INITMRS	:integer	:=7;
--	constant ST_VIDREAD	:integer	:=8;
--	constant ST_SUBREAD	:integer	:=9;
--	constant ST_SUBWRITE:integer	:=10;
constant INITR_TIMES	:integer	:=20;
signal	INITR_COUNT	:integer range 0 to INITR_TIMES;
constant INITTIMERCNT:integer	:=1000;
signal	INITTIMER	:integer range 0 to INITTIMERCNT;
constant clockwtime	:integer	:=50000;	--usec
--constant clockwtime	:integer	:=2;	--usec
constant cwaitcnt	:integer	:=clockwtime*86;	--clocks
signal	CLOCKWAIT	:integer range 0 to cwaitcnt;
signal	clkcount	:integer range 0 to 20;
signal	pCPUWR,pCPURD		:std_logic;
signal	pCPUADR			:std_logic_vector(AWIDTH-1 downto 0);
constant allzero	:std_logic_vector(12 downto 0)	:=(others=>'0');

constant REFINT		:integer	:=CLKMHZ*REFCYC/20;
signal	REFCNT	:integer range 0 to REFINT-1;
signal	SUBCLKb	:std_logic;
signal	CLKMb	:std_logic;

signal	CPUADRb	:std_logic_vector(AWIDTH-1 downto 0);
signal	CPUWDATb:std_logic_vector(7 downto 0);

signal SUBADRb	:std_logic_vector(AWIDTH-1 downto 0);
signal SUBWDATb	:std_logic_vector(7 downto 0);

signal	VIDADRb	:std_logic_vector(AWIDTH-1 downto 0);

signal	CPUWAITb	:std_logic;
signal	VIDWAITb	:std_logic;
signal	SUBWAITb	:std_logic;
signal	FDEWAITb	:std_logic;
signal	FECWAITb	:std_logic;
signal	SNDWAITb	:std_logic;

signal	lCPUWR,lCPURD,lSUBWR,lSUBRD :std_logic_vector(3 downto 0);
signal	lVIDRD	:std_logic_vector(1 downto 0);
signal	sFDEADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	lFDEADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	fFDEADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	lFECADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	lFDEWR	:std_logic_vector(4 downto 0);
signal	lFDERD	:std_logic_vector(4 downto 0);
signal	lFECWR	:std_logic_vector(1 downto 0);
signal	lFECRD	:std_logic_vector(1 downto 0);
signal	lSNDWR	:std_logic_vector(2 downto 0);
signal	lSNDRD	:std_logic_vector(2 downto 0);
signal	FDEADRb	:std_logic_vector(AWIDTH-1 downto 0);
signal	pFDEADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	pFECADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	FDEWDATb	:std_logic_vector(15 downto 0);
signal	sFDEWDAT	:std_logic_vector(15 downto 0);
signal	FECADRb	:std_logic_vector(AWIDTH-1 downto 0);
signal	FECWDATb	:std_logic_vector(15 downto 0);
signal	lSNDADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	SNDADRb	:std_logic_vector(AWIDTH-1 downto 0);
signal	SNDWDATb	:std_logic_vector(7 downto 0);

signal	CPUJOB	:integer range 0 to 2;
signal	SUBJOB	:integer range 0 to 2;
signal	VIDJOB	:integer range 0 to 1;
signal	FDEJOB	:integer range 0 to 2;
signal	FECJOB	:integer range 0 to 2;
signal	SNDJOB	:integer range 0 to 2;
constant JOB_NOP	:integer	:=0;
constant JOB_RD		:integer	:=1;
constant JOB_WR		:integer	:=2;

signal	SUBRDAT0	:std_logic_vector(7 downto 0);
signal	SUBRDAT1	:std_logic_vector(7 downto 0);
signal	SUBRSEL		:std_logic;

signal	MEMCKE		:STD_LOGIC;							-- SD-RAM CLOCK ENABLE
signal	MEMCS_N		:STD_LOGIC;							-- SD-RAM CHIP SELECT
signal	MEMRAS_N	:STD_LOGIC;							-- SD-RAM ROW/RAS
signal	MEMCAS_N	:STD_LOGIC;							-- SD-RAM /CAS
signal	MEMWE_N		:STD_LOGIC;							-- SD-RAM /WE
signal	MEMUDQ		:STD_LOGIC;							-- SD-RAM UDQM
signal	MEMLDQ		:STD_LOGIC;							-- SD-RAM LDQM
signal	MEMBA1		:STD_LOGIC;							-- SD-RAM BANK SELECT ADDRESS 1
signal	MEMBA0		:STD_LOGIC;							-- SD-RAM BANK SELECT ADDRESS 0
signal	MEMADR		:STD_LOGIC_VECTOR( 12 DOWNTO 0 );	-- SD-RAM ADDRESS
signal	MEMDAT		:STD_LOGIC_VECTOR( 15 DOWNTO 0 );	-- SD-RAM DATA
signal	MEMDATOE	:STD_LOGIC;
signal	CLKSFT		:std_logic_vector(20 downto 0);
signal	SUBCSFT		:std_logic_vector(20 downto 0);
begin
	
	monout<="00000001" when STATE=ST_REFRSH else
			"00000010" when STATE=ST_READ else
			"00000100" when STATE=ST_WRITE else
			"00001000" when STATE=ST_VREAD else
			"00010000" when STATE=ST_VWRITE else
			"00100000" when STATE=ST_VIDREAD else
			"01000000" when STATE=ST_SUBREAD else
			"10000000" when STATE=ST_SUBWRITE else
			"00000000";
	
	CPUWAIT<=CPUWAITb;
	VIDWAIT<=VIDWAITb;
	SUBWAIT<=SUBWAITb;
	FDEWAIT<=FDEWAITb;
	FECWAIT<=FECWAITb;
	SNDWAIT<=SNDWAITb;
	
	process(memclk,rstn)begin
		if(rstn='0')then
			MEMCKE		<='0';
			MEMCS_N		<='1';
			MEMRAS_N	<='1';
			MEMCAS_N	<='1';
			MEMWE_N		<='1';
			MEMUDQ		<='1';
			MEMLDQ		<='1';
			MEMBA1		<='0';
			MEMBA0		<='0';
			MEMADR		<=(others=>'0');
			MEMDAT		<=(others=>'0');
			MEMDATOE	<='0';
			STATE		<=ST_INITPALL;
			lSTATE		<=ST_INITPALL;
			INITR_COUNT	<=INITR_TIMES;
			INITTIMER	<=INITTIMERCNT;
			CLOCKWAIT	<=cwaitcnt;
			clkcount	<=0;
			CPUWAITb	<='0';
			VIDWAITb	<='0';
			pCPUWR		<='0';
			pCPURD		<='0';
			pCPUADR		<=(others=>'0');
			REFCNT		<=REFINT-1;
			SUBWAITb	<='0';
			lCPUWR		<=(others=>'0');
			lCPURD		<=(others=>'0');
			lSUBWR		<=(others=>'0');
			lSUBRD		<=(others=>'0');
			lVIDRD		<=(others=>'0');
			CPUJOB		<=JOB_NOP;
			SUBJOB		<=JOB_NOP;
			VIDJOB		<=JOB_NOP;
			FDEJOB		<=JOB_NOP;
			FECJOB		<=JOB_NOP;
			SNDJOB		<=JOB_NOP;
			CPUADRb		<=(others=>'0');
			CPUWDATb	<=(others=>'0');
			SUBADRb		<=(others=>'0');
			SUBWDATb	<=(others=>'0');
			lFDEADR<=(others=>'0');
			sFDEADR<=(others=>'0');
			pFDEADR<=(others=>'0');
			FDEADRb<=(others=>'0');
			lFECADR<=(others=>'0');
			pFECADR<=(others=>'0');
			FECADRb<=(others=>'0');
			lSNDADR<=(others=>'0');
			SNDADRb<=(others=>'0');
			sFDEWDAT<=(others=>'0');
		elsif(memclk' event and memclk='1')then
--			if(lCPUWR(0)='0' and CPUWR='1')then
			if(lCPUWR="0111")then
				CPUWAITb<='1';
				CPUJOB<=JOB_WR;
				CPUADRb<=CPUADR;
				CPUWDATb<=CPUWDAT;
			end if;
--			if(lCPURD(0)='0' and CPURD='1')then
			if(lCPURD="0111")then
				CPUWAITb<='1';
				CPUJOB<=JOB_RD;
				CPUADRb<=CPUADR;
			end if;
			if(lVIDRD="01" and VIDRD='1')then
				VIDWAITb<='1';
				VIDADRb<=VIDADR;
				VIDJOB<=JOB_RD;
			end if;
--			if(lSUBWR(0)='0' and SUBWR='1')then
			if(lSUBWR="0111")then
				SUBWAITb<='1';
				SUBJOB<=JOB_WR;
				SUBADRb<=SUBADR;
				SUBWDATb<=SUBWDAT;
			end if;
--			if(lSUBRD(0)='0' and SUBRD='1')then
			if(lSUBRD="0111")then
				SUBWAITb<='1';
				SUBJOB<=JOB_RD;
				SUBADRb<=SUBADR;
			end if;
			if(sFDEADR=lFDEADR)then
				fFDEADR<=lFDEADR;
			end if;
			if(lFDEWR="11111")then
				if(pFDEADR/=fFDEADR or FDEWDATb/=sFDEWDAT)then
					FDEADRb<=fFDEADR;
					FDEWDATb<=sFDEWDAT;
					pFDEADR<=fFDEADR;
					FDEJOB<=JOB_WR;
					FDEWAITb<='1';
				end if;
			elsif(lFDERD="11111")then
				if((pFDEADR/=fFDEADR) and FDEJOB/=JOB_WR)then
					FDEADRb<=fFDEADR;
					pFDEADR<=fFDEADR;
					FDEJOB<=JOB_RD;
					FDEWDATb<=x"ffff";
					FDEWAITb<='1';
				end if;
			end if;
			if(lFECWR="11")then
				if(pFECADR/=lFECADR)then
					FECADRb<=lFECADR;
					FECWDATb<=FECWDAT;
					pFECADR<=lFECADR;
					FECJOB<=JOB_WR;
					FECWAITb<='1';
				end if;
			elsif(lFECRD="11")then
				if(pFECADR/=lFECADR)then
					FECADRb<=lFECADR;
					pFECADR<=lFECADR;
					FECJOB<=JOB_RD;
					FECWAITb<='1';
				end if;
			end if;
			if(lSNDRD="011")then
					SNDADRb<=lSNDADR;
					SNDJOB<=JOB_RD;
					SNDWAITb<='1';
			elsif(lSNDWR="011")then
					SNDADRb<=lSNDADR;
					SNDWDATb<=SNDWDAT;
					SNDJOB<=JOB_WR;
					SNDWAITb<='1';
			end if;
			if(INITTIMER>0)then
				if(INITTIMER=1)then
					MEMCKE<='1';
					CLOCKWAIT<=cwaitcnt;
				else
					MEMCKE<='0';
				end if;
				INITTIMER<=INITTIMER-1;
			elsif(CLOCKWAIT>0)then
				CLOCKWAIT<=CLOCKWAIT-1;
				clkcount<=0;
				STATE<=ST_INITPALL;
			else
				case clkcount is
				when 0 =>
					if(lSTATE=ST_VIDREAD)then
						VIDWAITb<='0';
					end if;
					case STATE is
					when ST_VWRITE | ST_VREAD | ST_READ | ST_WRITE =>
						MEMCKE		<='1';	--Bank active
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<=CPUADRb(AWIDTH-1);
						MEMBA0		<=CPUADRb(AWIDTH-2);
						MEMADR		<=CPUADRb(AWIDTH-3 downto CAWIDTH);
						MEMDATOE		<='0';
						CPUJOB<=JOB_NOP;
					when ST_SUBREAD | ST_SUBWRITE =>
						MEMCKE		<='1';	--Bank active
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<=SUBADRb(AWIDTH-1);
						MEMBA0		<=SUBADRb(AWIDTH-2);
						MEMADR		<=SUBADRb(AWIDTH-3 downto CAWIDTH);
						MEMDATOE		<='0';
						SUBJOB<=JOB_NOP;
					when ST_FDEREAD | ST_FDEWRITE =>
						MEMCKE		<='1';	--Bank active
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<=FDEADRb(AWIDTH-1);
						MEMBA0		<=FDEADRb(AWIDTH-2);
						MEMADR		<=FDEADRb(AWIDTH-3 downto CAWIDTH);
						MEMDATOE		<='0';
						FDEJOB<=JOB_NOP;
					when ST_FECREAD | ST_FECWRITE =>
						MEMCKE		<='1';	--Bank active
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<=FECADRb(AWIDTH-1);
						MEMBA0		<=FECADRb(AWIDTH-2);
						MEMADR		<=FECADRb(AWIDTH-3 downto CAWIDTH);
						MEMDATOE		<='0';
						FECJOB<=JOB_NOP;
					when ST_SNDREAD | ST_SNDWRITE =>
						MEMCKE		<='1';	--Bank active
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<=SNDADRb(AWIDTH-1);
						MEMBA0		<=SNDADRb(AWIDTH-2);
						MEMADR		<=SNDADRb(AWIDTH-3 downto CAWIDTH);
						MEMDATOE		<='0';
						SNDJOB<=JOB_NOP;
					when ST_INITMRS =>
						MEMCKE		<='1';	--Mode register set
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='0';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<="0000000100001";
						MEMDATOE		<='0';
					when ST_INITPALL =>
						MEMCKE		<='1';	--Precharge all
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'1');
						MEMDATOE		<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 2 =>
					case STATE is
					when ST_VWRITE | ST_VREAD=>
						MEMCKE		<='1';	--Read
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='0';
						MEMLDQ		<='0';
						MEMBA1		<=CPUADRb(AWIDTH-1);
						MEMBA0		<=CPUADRb(AWIDTH-2);
						MEMADR		<="000" & CPUADRb(9 downto 0);
						MEMDATOE		<='0';
					when ST_READ =>
						MEMCKE		<='1';	--Read
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='0';
						MEMBA1		<=CPUADRb(AWIDTH-1);
						MEMBA0		<=CPUADRb(AWIDTH-2);
						MEMADR		<="100" & CPUADRb(9 downto 0);
						MEMDATOE		<='0';
					when ST_WRITE =>
						MEMCKE		<='1';	--Write
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='0';
						MEMBA1		<=CPUADRb(AWIDTH-1);
						MEMBA0		<=CPUADRb(AWIDTH-2);
						MEMADR		<="100" & CPUADRb(9 downto 0);
						MEMDAT		<=x"00" & CPUWDATb;
						MEMDATOE		<='1';
					when ST_SUBREAD =>
						MEMCKE		<='1';	--Read
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='0';
						MEMBA1		<=SUBADRb(AWIDTH-1);
						MEMBA0		<=SUBADRb(AWIDTH-2);
						MEMADR		<="100" & SUBADRb(9 downto 0);
						MEMDATOE		<='0';
					when ST_SUBWRITE =>
						MEMCKE		<='1';	--Write
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='0';
						MEMBA1		<=SUBADRb(AWIDTH-1);
						MEMBA0		<=SUBADRb(AWIDTH-2);
						MEMADR		<="100" & SUBADRb(9 downto 0);
						MEMDAT		<=x"00" & SUBWDATb;
						MEMDATOE		<='1';
					when ST_FDEREAD =>
						MEMCKE		<='1';	--Read
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='0';
						MEMLDQ		<='0';
						MEMBA1		<=FDEADRb(AWIDTH-1);
						MEMBA0		<=FDEADRb(AWIDTH-2);
						MEMADR		<="000" & FDEADRb(9 downto 0);
						MEMDATOE		<='0';
					when ST_FDEWRITE =>
						MEMCKE		<='1';	--Write
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='0';
						MEMUDQ		<='0';
						MEMLDQ		<='0';
						MEMBA1		<=FDEADRb(AWIDTH-1);
						MEMBA0		<=FDEADRb(AWIDTH-2);
						MEMADR		<="000" & FDEADRb(9 downto 0);
						MEMDAT		<=FDEWDATb;
						MEMDATOE		<='1';
					when ST_FECREAD =>
						MEMCKE		<='1';	--Read
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='0';
						MEMLDQ		<='0';
						MEMBA1		<=FECADRb(AWIDTH-1);
						MEMBA0		<=FECADRb(AWIDTH-2);
						MEMADR		<="000" & FECADRb(9 downto 0);
						MEMDATOE		<='0';
					when ST_FECWRITE =>
						MEMCKE		<='1';	--Write
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='0';
						MEMUDQ		<='0';
						MEMLDQ		<='0';
						MEMBA1		<=FECADRb(AWIDTH-1);
						MEMBA0		<=FECADRb(AWIDTH-2);
						MEMADR		<="000" & FECADRb(9 downto 0);
						MEMDAT		<=FECWDATb;
						MEMDATOE		<='1';
					when ST_SNDREAD =>
						MEMCKE		<='1';	--Read
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<=not SNDH_Ln;
						MEMLDQ		<=SNDH_Ln;
						MEMBA1		<=SNDADRb(AWIDTH-1);
						MEMBA0		<=SNDADRb(AWIDTH-2);
						MEMADR		<=not SNDH_Ln & SNDH_Ln & '0' & SNDADRb(9 downto 0);
						MEMDATOE	<='0';
					when ST_SNDWRITE =>
						MEMCKE		<='1';	--Write
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='0';
						MEMUDQ		<=not SNDH_Ln;
						MEMLDQ		<=SNDH_Ln;
						MEMBA1		<=SNDADRb(AWIDTH-1);
						MEMBA0		<=SNDADRb(AWIDTH-2);
						MEMADR		<=not SNDH_Ln & SNDH_Ln & '0' & SNDADRb(9 downto 0);
						MEMDAT		<=SNDWDATb & SNDWDATb;
						MEMDATOE	<='1';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE	<='0';
					end case;
				when 3 =>
					case STATE is
					when ST_WRITE | ST_SUBWRITE |ST_FDEWRITE | ST_FECWRITE | ST_SNDWRITE =>	--write abort and all bank precharge
						MEMCKE		<='1';	--Precharge all
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'1');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
						case STATE is
						when ST_WRITE =>
							CPUWAITb<='0';
						when ST_SUBWRITE =>
							SUBWAITb<='0';
						when ST_FDEWRITE =>
							FDEWAITb<='0';
						when ST_FECWRITE =>
							FECWAITb<='0';
						when ST_SNDWRITE =>
							SNDWAITb<='0';
						when others =>
						end case;
					when ST_VWRITE | ST_VREAD =>
						MEMCKE		<='1';	--Read(cont.)
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='0';
						MEMLDQ		<='0';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'0');
						MEMDATOE		<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 4 =>
					case STATE is
					when ST_VREAD =>
						MEMCKE		<='1';	--precharge all banks
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'1');
						MEMDATOE		<='0';
					when ST_VWRITE =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					when ST_READ | ST_SUBREAD |ST_FDEREAD | ST_FECREAD | ST_SNDREAD =>
						MEMCKE		<='1';	--precharge all banks
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'1');
						MEMDATOE		<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 6 =>
					case STATE is
					when ST_READ =>
						CPUWAITb<='0';
					when ST_SUBREAD =>
						SUBWAITb<='0';
					when ST_FDEREAD =>
						FDEWAITb<='0';
					when ST_FECREAD =>
						FECWAITb<='0';
					when ST_SNDREAD =>
						SNDWAITb<='0';
					when others =>
					end case;
					
					if(STATE=ST_VWRITE)then
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDAT		<=ALUWD1 & ALUWD0;
						MEMDATOE	<='1';
					elsif(STATE=ST_REFRSH or STATE=ST_INITREF or STATE=ST_INITPALL or STATE=ST_SUBREAD or STATE=ST_SUBWRITE)then	-- refresh
--					if(((STATE=ST_VREAD or STATE=ST_READ or STATE=ST_WRITE)) or STATE=ST_REFRSH or STATE=ST_INITREF or STATE=ST_INITPALL)then	-- refresh
						MEMCKE		<='1';	--Auto refresh
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
						if(STATE/=ST_REFRSH and STATE/=ST_INITREF and STATE/=ST_INITPALL )then
							STATE<=ST_REFRSH;
							REFCNT<=REFINT-1;
						end if;
					elsif(SUBJOB=JOB_WR)then 
						STATE<=ST_SUBWRITE;
						MEMCKE		<='1';	--Bank active
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<=SUBADRb(AWIDTH-1);
						MEMBA0		<=SUBADRb(AWIDTH-2);
						MEMADR		<=SUBADRb(AWIDTH-3 downto CAWIDTH);
						MEMDATOE		<='0';
						SUBJOB		<=JOB_NOP;
					elsif(SUBJOB=JOB_RD)then
						STATE<=ST_SUBREAD;
						MEMCKE		<='1';	--Bank active
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<=SUBADRb(AWIDTH-1);
						MEMBA0		<=SUBADRb(AWIDTH-2);
						MEMADR		<=SUBADRb(AWIDTH-3 downto CAWIDTH);
						MEMDATOE		<='0';
						SUBJOB		<=JOB_NOP;
					elsif(STATE=ST_WRITE or STATE=ST_READ or STATE=ST_FDEREAD or STATE=ST_FDEWRITE or STATE=ST_FECREAD or STATE=ST_FECWRITE or STATE=ST_SNDREAD or STATE=ST_SNDWRITE)then
						STATE<=ST_REFRSH;
						REFCNT<=REFINT-1;
						MEMCKE		<='1';	--Auto refresh
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					else
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end if;
				when 7 =>
					if(lSTATE=ST_VREAD)then
						CPUWAITb<='0';
					end if;
					case STATE is
					when ST_VWRITE =>
						MEMCKE		<='1';	--Write
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='0';
						MEMUDQ		<=not VRAMWE(1);
						MEMLDQ		<=not VRAMWE(0);
						MEMBA1		<=CPUADRb(AWIDTH-1);
						MEMBA0		<=CPUADRb(AWIDTH-2);
						MEMADR		<=not VRAMWE(1 downto 0) & '0' & CPUADRb(9 downto 0);
						MEMDAT		<=ALUWD1 & ALUWD0;
						MEMDATOE		<='1';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 8 =>
					case STATE is
					when ST_VWRITE =>
						MEMCKE		<='1';	--Write(cont)
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<=not VRAMWE(3);
						MEMLDQ		<=not VRAMWE(2);
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<=not VRAMWE(3 downto 2);
						MEMDAT		<=CPUWDATb & ALUWD2;
						MEMDATOE		<='1';
						CPUWAITb		<='0';
					when ST_SUBREAD =>
						MEMCKE		<='1';	--Read
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='0';
						MEMBA1		<=SUBADRb(AWIDTH-1);
						MEMBA0		<=SUBADRb(AWIDTH-2);
						MEMADR		<="100" & SUBADRb(9 downto 0);
						MEMDATOE		<='0';
					when ST_SUBWRITE =>
						MEMCKE		<='1';	--Write
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='0';
						MEMBA1		<=SUBADRb(AWIDTH-1);
						MEMBA0		<=SUBADRb(AWIDTH-2);
						MEMADR		<="100" & SUBADRb(9 downto 0);
						MEMDAT		<=x"00" & SUBWDATb;
						MEMDATOE		<='1';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 9 =>
					case STATE is
					when ST_VWRITE =>
						MEMCKE		<='1';	--Precharge all
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'1');
						MEMDATOE		<='0';
					when ST_SUBWRITE =>
						MEMCKE		<='1';	--Precharge all
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'1');
						MEMDATOE		<='0';
						SUBWAITb		<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE	<='0';
					end case;
				when 10 =>
					case STATE is
					when ST_SUBREAD =>
						MEMCKE		<='1';	--precharge all banks
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'1');
						MEMDATOE		<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 13 =>
					if(STATE=ST_SUBREAD)then
						SUBWAITb<='0';
					end if;
					if(STATE/=ST_INITREF and STATE/=ST_INITMRS and STATE/=ST_INITPALL)then
						if(VIDJOB=JOB_RD)then
							STATE<=ST_VIDREAD;
							VIDJOB<=JOB_NOP;
						else
							STATE<=ST_REFRSH;
							REFCNT<=REFINT-1;
						end if;
					end if;
					MEMCKE		<='1';	--nop
					MEMCS_N		<='1';
					MEMRAS_N		<='1';
					MEMCAS_N		<='1';
					MEMWE_N		<='1';
					MEMUDQ		<='1';
					MEMLDQ		<='1';
					MEMBA1		<='0';
					MEMBA0		<='0';
					MEMADR(10 downto 0)	<=(others=>'0');
					MEMADR(12 downto 11)	<="11";
					MEMDATOE		<='0';
				when 14 =>
					case STATE is
					when ST_VIDREAD =>
						MEMCKE		<='1';	--Bank active
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<=VIDADRb(AWIDTH-1);
						MEMBA0		<=VIDADRb(AWIDTH-2);
						MEMADR		<=VIDADRb(AWIDTH-3 downto CAWIDTH);
						MEMDATOE		<='0';
					when ST_REFRSH =>
						MEMCKE		<='1';	--Auto refresh
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE	<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 16 =>
					case STATE is
					when ST_VIDREAD =>	--Read
						MEMCKE		<='1';
						MEMCS_N		<='0';
						MEMRAS_N		<='1';
						MEMCAS_N		<='0';
						MEMWE_N		<='1';
						MEMUDQ		<='0';
						MEMLDQ		<='0';
						MEMBA1		<=VIDADRb(AWIDTH-1);
						MEMBA0		<=VIDADRb(AWIDTH-2);
						MEMADR		<="000" & VIDADRb(9 downto 0);
						MEMDATOE		<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 17	=>
					case STATE is
					when ST_VIDREAD =>
						MEMCKE		<='1';	--Read(cont.)
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='0';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'0');
						MEMDATOE		<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N	<='1';
						MEMCAS_N	<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 18 =>
					case STATE is
					when ST_VIDREAD =>
						MEMCKE		<='1';	--precharge all banks
						MEMCS_N		<='0';
						MEMRAS_N		<='0';
						MEMCAS_N		<='1';
						MEMWE_N		<='0';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR		<=(others=>'1');
						MEMDATOE		<='0';
					when others =>
						MEMCKE		<='1';	--nop
						MEMCS_N		<='1';
						MEMRAS_N		<='1';
						MEMCAS_N		<='1';
						MEMWE_N		<='1';
						MEMUDQ		<='1';
						MEMLDQ		<='1';
						MEMBA1		<='0';
						MEMBA0		<='0';
						MEMADR(10 downto 0)	<=(others=>'0');
						MEMADR(12 downto 11)	<="11";
						MEMDATOE		<='0';
					end case;
				when 19 =>
					MEMCKE		<='1';	--nop
					MEMCS_N		<='1';
					MEMRAS_N		<='1';
					MEMCAS_N		<='1';
					MEMWE_N		<='1';
					MEMUDQ		<='1';
					MEMLDQ		<='1';
					MEMBA1		<='0';
					MEMBA0		<='0';
					MEMADR(10 downto 0)	<=(others=>'0');
					MEMADR(12 downto 11)	<="11";
					MEMDATOE		<='0';
				when 20 =>
					MEMCKE		<='1';	--nop
					MEMCS_N		<='1';
					MEMRAS_N		<='1';
					MEMCAS_N		<='1';
					MEMWE_N		<='1';
					MEMUDQ		<='1';
					MEMLDQ		<='1';
					MEMBA1		<='0';
					MEMBA0		<='0';
					MEMADR(10 downto 0)	<=(others=>'0');
					MEMADR(12 downto 11)	<="11";
					MEMDATOE	<='0';
					if(STATE=ST_INITPALL)then
						STATE<=ST_INITREF;
						INITR_COUNT<=INITR_TIMES;
					elsif(STATE=ST_INITREF)then
						if(INITR_COUNT>0)then
							INITR_COUNT<=INITR_COUNT-1;
						else
							STATE<=ST_INITMRS;
						end if;
					else
						if(REFCNT=0)then
							STATE<=ST_REFRSH;
							REFCNT<=REFINT-1;
						else
							if(FDEJOB=JOB_RD)then
								STATE<=ST_FDEREAD;
							elsif(FDEJOB=JOB_WR)then
								STATE<=ST_FDEWRITE;
							elsif(FECJOB=JOB_RD)then
								STATE<=ST_FECREAD;
							elsif(FECJOB=JOB_WR)then
								STATE<=ST_FECWRITE;
							elsif(SNDJOB=JOB_RD)then
								STATE<=ST_SNDREAD;
							elsif(SNDJOB=JOB_WR)then
								STATE<=ST_SNDWRITE;
							elsif(CPUADRb(AWIDTH-1 downto 15)=ADDR_GVRAM(AWIDTH-1 downto 15))then
								if(CPUJOB=JOB_RD)then
									STATE<=ST_VREAD;
								elsif(CPUJOB=JOB_WR)then
									STATE<=ST_VWRITE;
								else
									if(SUBJOB=JOB_RD)then
										STATE<=ST_SUBREAD;
									elsif(SUBJOB=JOB_WR)then
										STATE<=ST_SUBWRITE;
									else
										REFCNT<=REFINT-1;
										STATE<=ST_REFRSH;
									end if;
								end if;
							else
								if(CPUJOB=JOB_RD)then
									STATE<=ST_READ;
								elsif(CPUJOB=JOB_WR)then
									STATE<=ST_WRITE;
								else
									if(SUBJOB=JOB_RD)then
										STATE<=ST_SUBREAD;
									elsif(SUBJOB=JOB_WR)then
										STATE<=ST_SUBWRITE;
									else
										STATE<=ST_REFRSH;
										REFCNT<=REFINT-1;
									end if;
								end if;
							end if;
						end if;
						pCPURD<=CPURD;
						pCPUWR<=CPUWR;
						pCPUADR<=CPUADR;
					end if;
				when others =>
					MEMCKE		<='1';
					MEMCS_N		<='1';
					MEMRAS_N		<='1';
					MEMCAS_N		<='1';
					MEMWE_N		<='1';
					MEMUDQ		<='1';
					MEMLDQ		<='1';
					MEMBA1		<='0';
					MEMBA0		<='0';
					MEMADR(10 downto 0)	<=(others=>'0');
					MEMADR(12 downto 11)	<="11";
					MEMDATOE	<='0';
				end case;
				if(clkcount=20)then
					clkcount<=0;
				else
					clkcount<=clkcount+1;
				end if;
			end if;
			lCPUWR<=lCPUWR(2 downto 0) & CPUWR;
			lCPURD<=lCPURD(2 downto 0) & CPURD;
			lSUBWR<=lSUBWR(2 downto 0) & SUBWR;
			lSUBRD<=lSUBRD(2 downto 0) & SUBRD;
			lVIDRD<=lVIDRD(0) & VIDRD;
			lFDERD<=lFDERD(3 downto 0) & FDERD;
			lFDEWR<=lFDEWR(3 downto 0) & FDEWR;
			lFECRD<=lFECRD(0) & FECRD;
			lFECWR<=lFECWR(0) & FECWR;
			lSNDRD<=lSNDRD(1 downto 0) & SNDRD;
			lSNDWR<=lSNDWR(1 downto 0) & SNDWR;
			sFDEADR<=FDEADR;
			lFDEADR<=sFDEADR;
			lFECADR<=FECADR;
			lSNDADR<=SNDADR;
			sFDEWDAT<=FDEWDAT;
			lSTATE<=STATE;
		end if;
	end process;

	SUBRDAT<=SUBRDAT0 when SUBRSEL='0' else SUBRDAT1;
	
	process(memclk,rstn)begin
		if(rstn='0')then
			ALURD0		<=(others=>'0');
			ALURD1		<=(others=>'0');
			ALURD2		<=(others=>'0');
			CPURDAT		<=(others=>'0');
			MRAMDAT		<=(others=>'0');
			SUBRDAT0	<=(others=>'0');
			SUBRDAT1	<=(others=>'0');
			SUBRSEL		<='0';
			VIDDAT0		<=(others=>'0');
			VIDDAT1		<=(others=>'0');
			VIDDAT2		<=(others=>'0');
			FDERDAT		<=(others=>'0');
			FECRDAT		<=(others=>'0');
		elsif(memclk' event and memclk='1')then
			case clkcount is
			when 0 =>
				if(lSTATE=ST_VIDREAD)then
					VIDDAT2<=PMEMDAT(7 downto 0);
				end if;
			when 6 =>
				case STATE is
				when ST_VWRITE | ST_VREAD =>
					ALURD0<=PMEMDAT(7 downto 0);
					ALURD1<=PMEMDAT(15 downto 8);
					if(STATE=ST_VREAD)then
						if(VRAMRSEL=0)then
							CPURDAT<=PMEMDAT(7 downto 0);
						elsif(VRAMRSEL=1)then
							CPURDAT<=PMEMDAT(15 downto 8);
						end if;
					end if;
				when ST_READ =>
					CPURDAT<=PMEMDAT(7 downto 0);
					MRAMDAT<=PMEMDAT(7 downto 0);
				when ST_SUBREAD =>
					SUBRDAT0<=PMEMDAT(7 downto 0);
					SUBRSEL<='0';
				when ST_FDEREAD =>
					FDERDAT<=PMEMDAT;
				when ST_FECREAD =>
					FECRDAT<=PMEMDAT;
				when ST_SNDREAD =>
					if(SNDH_Ln='0')then
						SNDRDAT<=PMEMDAT(7 downto 0);
					else
						SNDRDAT<=PMEMDAT(15 downto 8);
					end if;
				when others =>
				end case;
			when 7 =>
				if(STATE=ST_VWRITE or lSTATE=ST_VREAD)then
					ALURD2<=PMEMDAT(7 downto 0);
				end if;
				if(lSTATE=ST_VREAD)then
					if(VRAMRSEL=2)then
						CPURDAT<=PMEMDAT(7 downto 0);
					elsif(VRAMRSEL=3)then
						CPURDAT<=PMEMDAT(15 downto 8);
					end if;
					MRAMDAT<=PMEMDAT(15 downto 8);
				end if;
			when 13 =>
				if(STATE=ST_SUBREAD)then
					SUBRDAT1<=PMEMDAT(7 downto 0);
					SUBRSEL<='1';
				end if;
			when 20 =>
				if(STATE=ST_VIDREAD)then
					VIDDAT0<=PMEMDAT(7 downto 0);
					VIDDAT1<=PMEMDAT(15 downto 8);
				end if;
			when others =>
			end case;
		end if;
	end process;

	process(memclk)begin
		if(memclk' event and memclk='1')then
			PMEMCKE		<=MEMCKE;
			PMEMCS_N		<=MEMCS_N;
			PMEMRAS_N	<=MEMRAS_N;
			PMEMCAS_N	<=MEMCAS_N;
			PMEMWE_N		<=MEMWE_N;
			PMEMUDQ		<=MEMUDQ;
			PMEMLDQ		<=MEMLDQ;
			PMEMBA1		<=MEMBA1;
			PMEMBA0		<=MEMBA0;
			PMEMADR		<=MEMADR;
			if(MEMDATOE='1')then
				PMEMDAT		<=MEMDAT;
			else
				PMEMDAT		<=(others=>'Z');
			end if;
		end if;
	end process;

	process(memclk)begin
		if(memclk' event and memclk='1')then
		if(rstn='0')then
			CPURSTn<='0';
			CLKMb<='0';
			CLKSFT<=(others=>'0');
		else
			if(STATE=ST_INITREF or STATE=ST_INITMRS or STATE=ST_INITPALL)then
				CPURSTn<='0';
			else
				CPURSTn<='1';
				if(clkcount=20)then
					CLKMb<=CLOCKM;
					if(CLOCKM='1')then
						CLKSFT<="000001111100000111111";
					else
						CLKSFT<="000001111111111000000";
					end if;
				else
					CLKSFT<=CLKSFT(19 downto 0) & CLKSFT(20);
				end if;
				if(clkcount=20)then
					SUBCSFT<="000001111100000111111";
				else
					SUBCSFT<=SUBCSFT(19 downto 0) & SUBCSFT(20);
				end if;
				
			end if;
		end if;
		end if;
	end process;
	CPUCLK<=CLKSFT(20);
	SUBCLKb<=SUBCSFT(20);
	ALUCWD<=CPUWDATb;
	SUBCLK<=SUBCLKb;
	
end MAIN;
					

						

						
						
				
			
			
