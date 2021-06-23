LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity rtc4990MiSTer is
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
end rtc4990MiSTer;

architecture MAIN of rtc4990MiSTer is
signal	YEH		:std_logic_vector(3 downto 0);
signal	YEL		:std_logic_vector(3 downto 0);
signal	MON		:std_logic_vector(3 downto 0);
signal	DAYH	:std_logic_vector(1 downto 0);
signal	DAYL	:std_logic_vector(3 downto 0);
signal	WDAY	:std_logic_vector(2 downto 0);
signal	HORH	:std_logic_vector(1 downto 0);
signal	HORL	:std_logic_vector(3 downto 0);
signal	MINH	:std_logic_vector(2 downto 0);
signal	MINL	:std_logic_vector(3 downto 0);
signal	SECH	:std_logic_vector(2 downto 0);
signal	SECL	:std_logic_vector(3 downto 0);

signal	YEHWD	:std_logic_vector(3 downto 0);
signal	YELWD	:std_logic_vector(3 downto 0);
signal	MONWD	:std_logic_vector(3 downto 0);
signal	DAYHWD	:std_logic_vector(1 downto 0);
signal	DAYLWD	:std_logic_vector(3 downto 0);
signal	WDAYWD	:std_logic_vector(2 downto 0);
signal	HORHWD	:std_logic_vector(1 downto 0);
signal	HORLWD	:std_logic_vector(3 downto 0);
signal	MINHWD	:std_logic_vector(2 downto 0);
signal	MINLWD	:std_logic_vector(3 downto 0);
signal	SECHWD	:std_logic_vector(2 downto 0);
signal	SECLWD	:std_logic_vector(3 downto 0);

signal	YEHID	:std_logic_vector(3 downto 0);
signal	YELID	:std_logic_vector(3 downto 0);
signal	MONID	:std_logic_vector(3 downto 0);
signal	DAYHID	:std_logic_vector(1 downto 0);
signal	DAYLID	:std_logic_vector(3 downto 0);
signal	WDAYID	:std_logic_vector(2 downto 0);
signal	HORHID	:std_logic_vector(1 downto 0);
signal	HORLID	:std_logic_vector(3 downto 0);
signal	MINHID	:std_logic_vector(2 downto 0);
signal	MINLID	:std_logic_vector(3 downto 0);
signal	SECHID	:std_logic_vector(2 downto 0);
signal	SECLID	:std_logic_vector(3 downto 0);
signal	SYSINI	:std_logic;

signal	TIMESET	:std_logic;
signal	SYS_SET	:std_logic;
signal	S_Pn	:std_logic;
signal	OUT1Hz	:std_logic;

signal	TXSFT	:std_logic_vector(51 downto 0);
signal	RXDAT	:std_logic_vector(47 downto 0);
signal	CMDSFT	:std_logic_vector(3 downto 0);
signal	SDOUT	:std_logic;
signal	sDCLK	:std_logic;
signal	lDCLK	:std_logic;
signal	sDIN	:std_logic;
signal	sSTB	:std_logic;
signal	STBe	:std_logic;
signal	fast	:std_logic;
signal	Clat	:std_logic_vector(2 downto 0);

component rtcbody
generic(
	clkfreq	:integer	:=21477270
);
port(
	YERHIN	:in std_logic_vector(3 downto 0);
	YERHWR	:in std_logic;
	YERLIN	:in std_logic_vector(3 downto 0);
	YERLWR	:in std_logic;
	MONIN	:in std_logic_vector(3 downto 0);
	MONWR	:in std_logic;
	DAYHIN	:in std_logic_vector(1 downto 0);
	DAYHWR	:in std_logic;
	DAYLIN	:in std_logic_vector(3 downto 0);
	DAYLWR	:in std_logic;
	WDAYIN	:in std_logic_vector(2 downto 0);
	WDAYWR	:in std_logic;
	HORHIN	:in std_logic_vector(1 downto 0);
	HORHWR	:in std_logic;
	HORLIN	:in std_logic_vector(3 downto 0);
	HORLWR	:in std_logic;
	MINHIN	:in std_logic_vector(2 downto 0);
	MINHWR	:in std_logic;
	MINLIN	:in std_logic_vector(3 downto 0);
	MINLWR	:in std_logic;
	SECHIN	:in std_logic_vector(2 downto 0);
	SECHWR	:in std_logic;
	SECLIN	:in std_logic_vector(3 downto 0);
	SECLWR	:in std_logic;
	SECZERO	:in std_logic;
	
	YERHOUT	:out std_logic_vector(3 downto 0);
	YERLOUT	:out std_logic_vector(3 downto 0);
	MONOUT	:out std_logic_vector(3 downto 0);
	DAYHOUT	:out std_logic_vector(1 downto 0);
	DAYLOUT	:out std_logic_vector(3 downto 0);
	WDAYOUT	:out std_logic_vector(2 downto 0);
	HORHOUT	:out std_logic_vector(1 downto 0);
	HORLOUT	:out std_logic_vector(3 downto 0);
	MINHOUT	:out std_logic_vector(2 downto 0);
	MINLOUT	:out std_logic_vector(3 downto 0);
	SECHOUT	:out std_logic_vector(2 downto 0);
	SECLOUT	:out std_logic_vector(3 downto 0);

	OUT1Hz	:out std_logic;
	
	fast	:in std_logic;

 	sclk	:in std_logic;
	rstn	:in std_logic
);
end component;

begin

	DOUT<=	'1'		when OE<='0' else
			OUT1Hz	when Clat="000" else
			SDOUT	when Clat="001" else
			SDOUT	when Clat="010" else
			SDOUT	when Clat="011" else
			'0';

	process(sclk,rstn)begin
		if(rstn='0')then
			sDCLK<='0';
			sDIN<='0';
			sSTB<='0';
			STBe<='0';
		elsif(sclk' event and sclk='1')then
			sDCLK<=DCLK;
			sDIN<=DIN;
			sSTB<=STB;
			if(STB='1' and sSTB='0' and CS='1')then
				STBe<='1';
			else
				STBe<='0';
			end if;
		end if;
	end process;
	
	process(sclk,rstn)begin
		if(rstn='0')then
			Clat<=(others=>'0');
			S_Pn<='0';
		elsif(sclk' event and sclk='1')then
			if(STBe='1')then
				if(C="111")then
					Clat<=CMDSFT(2 downto 0);
					S_Pn<='1';
				else
					Clat<=C;
					S_Pn<='0';
				end if;
			end if;
		end if;
	end process;

	process(sclk,rstn)begin
		if(rstn='0')then
			TXSFT<=(others=>'0');
		elsif(sclk' event and sclk='1')then
			if(sDCLK='1' and lDCLK='0')then
				CMDSFT<=sDIN & CMDSFT(3 downto 1);
			end if;
			if(sDCLK='1' and lDCLK='0' and Clat="001" and CS='1')then
				TXSFT<=sDIN & TXSFT(51 downto 1);
			elsif(Clat="011")then
				TXSFT<=x"0" & YEH & YEL & MON & '0' & WDAY & "00" & DAYH & DAYL & "00" & HORH & HORL & '0' & MINH & MINL & '0' & SECH & SECL;
			end if;
			lDCLK<=sDCLK;
		end if;
	end process;
	
	SDOUT<=TXSFT(0);
	
	RXDAT<=TXSFT(47 downto 0) when S_Pn='1' else YEH & YEL & TXSFT(51 downto 12);
	
	YEHWD	<=RXDAT(47 downto 44) when SYSINI='0' else YEHID;
	YELWD	<=RXDAT(43 downto 40) when SYSINI='0' else YELID;
	MONWD	<=RXDAT(39 downto 36) when SYSINI='0' else MONID;
	DAYHWD	<=RXDAT(29 downto 28) when SYSINI='0' else DAYHID;
	DAYLWD	<=RXDAT(27 downto 24) when SYSINI='0' else DAYLID;
	WDAYWD	<=RXDAT(34 downto 32) when SYSINI='0' else WDAYID;
	HORHWD	<=RXDAT(21 downto 20) when SYSINI='0' else HORHID;
	HORLWD	<=RXDAT(19 downto 16) when SYSINI='0' else HORLID;
	MINHWD	<=RXDAT(14 downto 12) when SYSINI='0' else MINHID;
	MINLWD	<=RXDAT(11 downto  8) when SYSINI='0' else MINLID;
	SECHWD	<=RXDAT( 6 downto  4) when SYSINI='0' else SECHID;
	SECLWD	<=RXDAT( 3 downto  0) when SYSINI='0' else SECLID;
	
	SYS_SET<='1' when (Clat="010") else '0';
	TIMESET<=SYS_SET or SYSINI;
	fast<='0';
	
	rtc	:rtcbody generic map(clkfreq) port map(
		YERHIN	=>YEHWD,
		YERHWR	=>TIMESET,
		YERLIN	=>YELWD,
		YERLWR	=>TIMESET,
		MONIN	=>MONWD,
		MONWR	=>TIMESET,
		DAYHIN	=>DAYHWD,
		DAYHWR	=>TIMESET,
		DAYLIN	=>DAYLWD,
		DAYLWR	=>TIMESET,
		WDAYIN	=>WDAYWD,
		WDAYWR	=>TIMESET,
		HORHIN	=>HORHWD,
		HORHWR	=>TIMESET,
		HORLIN	=>HORLWD,
		HORLWR	=>TIMESET,
		MINHIN	=>MINHWD,
		MINHWR	=>TIMESET,
		MINLIN	=>MINLWD,
		MINLWR	=>TIMESET,
		SECHIN	=>SECHWD,
		SECHWR	=>TIMESET,
		SECLIN	=>SECLWD,
		SECLWR	=>TIMESET,
		SECZERO	=>TIMESET,
		
		YERHOUT	=>YEH,
		YERLOUT	=>YEL,
		MONOUT	=>MON,
		DAYHOUT	=>DAYH,
		DAYLOUT	=>DAYL,
		WDAYOUT	=>WDAY,
		HORHOUT	=>HORH,
		HORLOUT	=>HORL,
		MINHOUT	=>MINH,
		MINLOUT	=>MINL,
		SECHOUT	=>SECH,
		SECLOUT	=>SECL,

		OUT1Hz	=>OUT1Hz,
		
		fast	=>fast,

		sclk	=>sclk,
		rstn	=>rstn
	);

	SECLID<=RTCIN(3 downto 0);
	SECHID<=RTCIN(6 downto 4);
	MINLID<=RTCIN(11 downto 8);
	MINHID<=RTCIN(14 downto 12);
	HORLID<=RTCIN(19 downto 16);
	HORHID<=RTCIN(21 downto 20);
	DAYLID<=RTCIN(27 downto 24);
	DAYHID<=RTCIN(29 downto 28);
	MONID<=	RTCIN(35 downto 32) when RTCIN(36)='0' else
				RTCIN(35 downto 32)+x"a";
	
	process(RTCIN)
	variable carry	:std_logic;
	variable	tmpval	:std_logic_vector(4 downto 0);
	begin
		tmpval:=('0' & RTCIN(43 downto 40))+('0' & YEAROFF(3 downto 0));
		if(tmpval>"01010")then
			carry:='1';
			tmpval:=tmpval-"01010";
		else
			carry:='0';
		end if;
		YELID<=tmpval(3 downto 0);
		tmpval:=('0' & RTCIN(47 downto 44))+('0' & YEAROFF(7 downto 4));
		if(carry='1')then
			tmpval:=tmpval+1;
		end if;
		if(tmpval>"01010")then
			tmpval:=tmpval-"01010";
		end if;
		YEHID<=tmpval(3 downto 0);
	end process;

	WDAYID<=RTCIN(50 downto 48);

	process(sclk,rstn)
	variable state	:integer range 0 to 2;
	begin
		if(rstn='0')then
			state:=0;
			SYSINI<='0';
		elsif(sclk' event and sclk='1')then
			SYSINI<='0';
			case state is
			when 2 =>
			when 1 =>
				SYSINI<='1';
				state:=2;
			when 0 =>
				if(RTCIN(64)='1')then
					state:=1;
				end if;
			when others =>
				state:=2;
			end case;
		end if;
	end process;
	

	
end MAIN;

