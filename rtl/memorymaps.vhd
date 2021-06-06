LIBRARY	IEEE,WORK;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	USE	WORK.addressmap_pkg.ALL;

entity memorymaps is
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
	
	KNJ1_ADR		:in std_logic_vector(16 downto 0);
	KNJ1_RD		:in std_logic;

	KNJ2_ADR		:in std_logic_vector(16 downto 0);
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
end memorymaps;

architecture MAIN of memorymaps is
signal	LOWSEL		:std_logic_vector(1 downto 0);
signal	ROM4SEL	:std_logic_vector(1 downto 0);
signal	VRAMSEL		:std_logic_vector(1 downto 0);
signal	TXWADR		:std_logic_vector(7 downto 0);
signal	RMODE		:std_logic;
signal	MMODE		:std_logic;
signal	IEROMn		:std_logic;
signal	TMODE		:std_logic;
signal	RAM_ADRF	:std_logic_vector(27 downto 0);
signal	ADRSEL		:integer range 0 to 4;
constant ADR_ROM	:integer	:=0;
constant ADR_RAM	:integer	:=1;
constant ADR_VRAM	:integer	:=2;
constant ADR_ERAM	:integer	:=3;
constant ADR_TRAM	:integer	:=4;
signal	TXW_BASE	:std_logic_vector(15 downto 0);
signal	TXW_OFFSET	:std_logic_vector(15 downto 0);
signal	TXW_SUM		:std_logic_vector(15 downto 0);
signal	TXW_SELV	:std_logic;
signal	IO5c		:std_logic_vector(7 downto 0);
signal	IO70		:std_logic_vector(7 downto 0);
signal	IO71		:std_logic_vector(7 downto 0);
signal	G_RAMSELb	:integer range 0 to 3;
signal	GVAM		:std_logic;
signal	GAM			:std_logic;
signal	TRAMSEL		:std_logic;
signal	TVRMODE		:std_logic;
signal	IOWRn		:std_logic;
signal	lWRn		:std_logic;
signal	TXTWINENb	:std_logic;
signal	extsel		:std_logic_vector(3 downto 0);
signal	extwe		:std_logic;
signal	extre		:std_logic;

begin

	IOWRn<=CPU_IORQn or CPU_WRn;
	
	process(clk,rstn)begin
		if(rstn='0')then
			RMODE<='0';
			MMODE<='0';
			IEROMn<='1';
			TMODE<='0';
			ROM4SEL<="00";
			TXWADR<=x"00";
			G_RAMSELb<=3;
			GVAM<='0';
			GAM<='0';
			extre<='0';
			extwe<='0';
			extsel<=(others=>'0');
			TVRMODE<='0';
		elsif(clk' event and clk='1')then
			if(IOWRn='0')then
				case CPU_ADR(7 downto 0) is
				when x"31" =>
					MMODE<=CPU_WDAT(1);
					RMODE<=CPU_WDAT(2);
				when x"32" =>
					ROM4SEL<=CPU_WDAT(1 downto 0);
					TMODE<=CPU_WDAT(4);
					GVAM<=CPU_WDAT(6);
					if(CPU_WDAT(6)='1')then
						G_RAMSELb<=3;
					end if;
				when x"35" =>
					GAM<=CPU_WDAT(7);
				when x"38"=>
					TVRMODE<=CPU_WDAT(0);
				when x"5c" =>
					G_RAMSELb<=0;
				when x"5d" =>
					G_RAMSELb<=1;
				when x"5e" =>
					G_RAMSELb<=2;
				when x"5f" =>
					G_RAMSELb<=3;
				when x"70" =>
					TXWADR<=CPU_WDAT;
				when x"71" =>
					IEROMn<=CPU_WDAT(0);
				when x"78" =>
					if(lWRn='1')then
						TXWADR<=TXWADR+1;
					end if;
				when x"e2" =>
					if(extram=0)then
						extre<='0';
						extwe<='0';
					else
						extre<=CPU_WDAT(0);
						extwe<=CPU_WDAT(4);
					end if;
				when x"e3" =>
					if(extram=0)then
						extsel<=(others=>'0');
					else
						extsel<=CPU_WDAT(3 downto 0);
					end if;
				when others=>
				end case;
			end if;
			lWRn<=IOWRn;
		end if;
	end process;
	
	G_EXTMODE<=GVAM;
	TXW_BASE<=TXWADR & x"00";
	TXW_OFFSET<=x"0" & "00" & CPU_ADR(9 downto 0);
	TXW_SUM<=TXW_BASE+TXW_OFFSET;
	TXW_SELV<='1' when TXW_SUM(15 downto 14)="11" else '0';
	IO70<=TXWADR;

	TXTWINENb<='1' when RMODE='0' and MMODE='0' and CPU_ADR(15 downto 10)="100000" else '0';
	TXTWINEN<=TXTWINENb;

	TRAMSEL<=	'1' when GVAM='0' and G_RAMSELb=3 else
				'1' when GVAM='1' and GAM='0' else
				'0';
	RAM_ADRF<=	
				ADDR_KANJI1(27 downto 17) & KNJ1_ADR when KNJ1_RD='1' else		--Kanji1 ROM
				ADDR_KANJI2(27 downto 17) & KNJ2_ADR when KNJ2_RD='1' else		--Kanji2 ROM
				ADDR_EXTRAM(27 downto 19) & extsel & CPU_ADR(14 downto 0) when extram/=0 and CPU_ADR(15)='0' and extre='1' and CPU_RDn='0' else	--ext ram(read)
				ADDR_EXTRAM(27 downto 19) & extsel & CPU_ADR(14 downto 0) when extram/=0 and CPU_ADR(15)='0' and extwe='1' and CPU_WRn='0' else	--ext ram(write)
				ADDR_BACKRAM(27 downto 15) & CPU_ADR(14 downto 0) when CPU_ADR(15)='0' and CPU_WRn='0' else	--write ram when rom assigned
				ADDR_GVRAM(27 downto 15) & TXW_SUM(13 downto 0) & '0' when TXTWINENb='1' and TXW_SELV='1' else	--text window(VRAM area)
				ADDR_MAINRAM(27 downto 16) & TXW_SUM when TXTWINENb='1' else		--text window
				ADDR_N88_4_0(27 downto 15) & ROM4SEL & CPU_ADR(12 downto 0) when RMODE='0' and MMODE='0' and IEROMn='0' and CPU_ADR(15 downto 13)="011" else	--4th ROM
				ADDR_N88(27 downto 16) & RMODE & CPU_ADR(14 downto 0) when CPU_ADR(15)='0' and MMODE='0' else	--N88 or N80 BASIC
				ADDR_MAINRAM(27 downto 14) & CPU_ADR(13 downto 0) when CPU_ADR(15 downto 14)="10" else	--MAIN RAM
				ADDR_GVRAM(27 downto 15) & CPU_ADR(13 downto 0) & '0' when CPU_ADR(15 downto 14)="11" else	--VRAM
				ADDR_MAINRAM(27 downto 16) & CPU_ADR;	--MAIN RAM
	
	ADRSEL<=	
				ADR_TRAM 	when TRAMSEL='1' and TMODE='0' and CPU_ADR(15 downto 12)=x"F" else
				ADR_VRAM		when CPU_ADR(15 downto 14)="11" else
				ADR_RAM		when CPU_ADR(15)='0' and extre='1' and CPU_WRn='1' else
				ADR_ROM		when MMODE='0' and CPU_ADR(15)='0' and CPU_WRn='1' else
				ADR_RAM;
	
	ALUOE<=	'1' when CPU_MREQn='0' and CPU_RDn='0' and ADRSEL=ADR_VRAM and GVAM='1' and GAM='1' else '0';

	ALUME<=	'1' when CPU_MREQn='0' and CPU_RDn='0' and ADRSEL=ADR_VRAM and GVAM='1' and GAM='0' else
			'1' when CPU_MREQn='0' and CPU_RDn='0' and ADRSEL=ADR_VRAM and GVAM='0' else --and G_RAMSELb=3 else
			'0';
	
	ALURE<=	'1' when CPU_MREQn='0' and CPU_RDn='0' and ADRSEL=ADR_VRAM and GVAM='1' and GAM='1' else
--			'1' when CPU_MREQn='0' and CPU_RDn='0' and ADRSEL=ADR_VRAM and GVAM='0' and G_RAMSELb/=3 else
			'0';
	
	GADR_MSEL<=	'1' when CPU_MREQn='0' and ADRSEL=ADR_VRAM and GVAM='0' and G_RAMSELb=3 else
				'1' when CPU_MREQn='0' and ADRSEL=ADR_VRAM and GVAM='1' and GAM='0' else
				'0';
	
	
	RAM_CE		<=not CPU_MREQn when ADRSEL=ADR_VRAM or ADRSEL=ADR_ROM or ADRSEL=ADR_RAM else '0';
	TRAM_CE		<=not CPU_MREQn when ADRSEL=ADR_TRAM and TVRMODE='0' else '0';
	TVRAM_CE	<=not CPU_MREQn when ADRSEL=ADR_TRAM and TVRMODE='1' else '0';
	
	RAM_ADR<=RAM_ADRF(addrwidth-1 downto 0);
	TRAM_ADR<=CPU_ADR(11 downto 0);
	TVRAM_ADR<=CPU_ADR(11 downto 0);
	
	G_RAMSEL<=	3 when (GVAM='1' and GAM='0') else
				3 when TXTWINENb='1' and TXW_SELV='1' else	--TXTWINDOW
				G_RAMSELb;
	
	IO5c<=	"00000001" when G_RAMSELb=0 else
			"00000010" when G_RAMSELb=1 else
			"00000100" when G_RAMSELb=2 else
			"00000000";
	
	IO71<=	"1111111" & IEROMn;
	
	process(CPU_ADR,CPU_IORQn,CPU_RDn,IO5c,IO70,IO71)begin
		if(CPU_IORQn='1' or CPU_RDn='1')then
			CPU_RDAT<=(others=>'1');
			CPU_OE<='0';
		else
			case CPU_ADR(7 downto 0) is
			when x"5c" =>
				CPU_RDAT<=IO5c;
				CPU_OE<='1';
			when x"70" =>
				CPU_RDAT<=IO70;
				CPU_OE<='1';
			when x"71" =>
				CPU_RDAT<=IO71;
				CPU_OE<='1';
			when x"e2" =>
				if(extram/=0)then
					CPU_RDAT<="111" & not extwe & "111" & not extre;
					CPU_OE<='1';
				else
					CPU_RDAT<=(others=>'1');
				end if;
			when x"e3" =>
				if(extram/=0)then
					CPU_RDAT<="0000" & extsel;
					CPU_OE<='1';
				else
					CPU_RDAT<=(others=>'1');
				end if;
			when others=>
				CPU_RDAT<=(others=>'1');
				CPU_OE<='0';
			end case;
		end if;
	end process;
			
	
end MAIN;


