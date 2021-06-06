LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity OPNAADPCM is
port(
	RST		:in std_logic;
	SPOFF	:in std_logic;
	REPEAT	:in std_logic;
	MEMSEL	:in std_logic;
	REC		:in std_logic;
	START	:in std_logic;
	MEMTYPE	:in std_logic_vector(1 downto 0);
	DA_ADn	:in std_logic;
	SAMPLE	:in std_logic;
	chL,chR:in std_logic;
	STARTADDR	:in std_logic_vector(15 downto 0);
	STARTADDRWR	:in std_logic;
	STOPADDR	:in std_logic_vector(15 downto 0);
	PRESCALE	:in std_logic_vector(10 downto 0);
	WRDATA	:in std_logic_vector(7 downto 0);
	DATWR	:in std_logic;
	RDDATA	:out std_logic_vector(7 downto 0);
	DATRD	:in std_logic;
	DELTA_N	:in std_logic_vector(15 downto 0);
	LEVEL	:in std_logic_vector(7 downto 0);
	LIMITADDR:in std_logic_vector(15 downto 0);
	PCMWDAT	:in std_logic_vector(7 downto 0);
	PCMWR	:in std_logic;
	PCMRDAT	:out std_logic_vector(7 downto 0);
	FLAGRES	:in std_logic;
	
	RAMADDR	:out std_logic_vector(17 downto 0);
	RAMRD	:out std_logic;
	RAMWR	:out std_logic;
	RAMRDAT	:in std_logic_vector(7 downto 0);
	RAMWDAT	:out std_logic_vector(7 downto 0);
	RAMWAIT	:in std_logic;
	
	EOS		:out std_logic;
	BRDY	:out std_logic;
	BUSY	:out std_logic;
	
	sndL	:out std_logic_vector(15 downto 0);
	sndR	:out std_logic_vector(15 downto 0);
	
	sft		:in std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
);
end OPNAADPCM;

architecture rtl of OPNAADPCM is
signal	CURADDR	:std_logic_vector(17 downto 0);
signal	CURL_Un		:std_logic;
signal	CURSTOP	:std_logic;
signal	ADDRINCCPU	:std_logic;
signal	ADDRINCPCM	:std_logic;
signal	ADDRREPEAT	:std_logic;
signal	ADPCMDAT	:std_logic_vector(3 downto 0);
signal	ADPCMWR		:std_logic;
signal	ADPCMINIT	:std_logic;
signal	adpcmsft	:std_logic;
signal	adpcmcarry	:std_logic;
signal	adpcmcount	:std_logic_vector(15 downto 0);
signal	adpcmsnd	:std_logic_vector(15 downto 0);
signal	setBRDY		:std_logic;
signal	calcbusy	:std_logic;
signal	adpcmsig	:std_logic_vector(15 downto 0);
signal	adpcmlev	:std_logic_vector(23 downto 0);
signal	adpcmint	:std_logic_vector(7 downto 0);
signal	playstate	:std_logic;
signal	mulwr		:std_logic;
signal	playsft	:std_logic;

type cpustate_t is (
	cs_IDLE,
	cs_READ,
	cs_WRWAIT,
	cs_WRITE
);
signal	cpustate	:cpustate_t;

type pcmstate_T is(
	ps_IDLE,
	ps_PLAY,
	ps_REC
);
signal	pcmstate	:pcmstate_t;

component CALCOPNAADPCM
generic(
	intwidth	:integer	:=8
);
port(
	INIT	:in std_logic;
	INDAT	:in std_logic_vector(3 downto 0);
	INTDAT	:in std_logic_vector(intwidth-1 downto 0);
	WR		:in std_logic;
	CARRY	:in std_logic;
	
	OUTDAT	:out std_logic_vector(15 downto 0);
	BUSY	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component PCMTIMING
generic(
	intwidth	:integer	:=8
);
port(
	DELTA_N	:in std_logic_vector(15 downto 0);
	
	PCMWR		:out std_logic;
	CARRY		:out std_logic;
	INTER		:out std_logic_vector(intwidth-1 downto 0);

	sft		:in std_logic;
	clk		:in std_logic;
	rstn		:in std_logic
);
end component;

component susmult is
generic(
	awidth	:integer	:=16;
	bwidth	:integer	:=16
);
port(
	ain		:in std_logic_vector(awidth-1 downto 0);
	bin		:in std_logic_vector(bwidth-1 downto 0);
	qout	:out std_logic_vector(awidth+bwidth-1 downto 0);
	
	clk		:in std_logic
);
end component;

--component multi
--	generic(
--		Awidth	:integer	:=8;
--		Bwidth	:integer	:=8
--	);
--	port(
--		A		:in std_logic_vector(Awidth-1 downto 0);
--		B		:in std_logic_vector(Bwidth-1 downto 0);
--		write	:in std_logic;
--		
--		Q		:out std_logic_vector(Awidth+Bwidth-1 downto 0);
--		done	:out std_logic;
--		
--		clk		:in std_logic;
--		rstn	:in std_logic
--	);
--end component;

component delayer
generic(
	counts	:integer	:=5
);
port(
	a		:in std_logic;
	q		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin

	RAMADDR<=CURADDR;
	process(clk,rstn)
	variable	rdwait	:integer	range 0 to 3;
	begin
		if(rstn='0')then
			CURADDR<=(others=>'0');
			EOS<='0';
			RAMRD<='0';
			rdwait:=0;
		elsif(clk' event and clk='1')then
			if(FLAGRES='1')then
				EOS<='0';
			end if;
			if(rdwait>0)then
				if(RAMWAIT='0')then
					rdwait:=rdwait-1;
				end if;
			else
				RAMRD<='0';
				if(STARTADDRWR='1' or ADDRREPEAT='1')then
					if(MEMTYPE="00")then
						CURADDR<=STARTADDR(12 downto 0) & "00000";
					else
						CURADDR<=STARTADDR & "00";
					end if;
					if(REC='0')then
						RAMRD<='1';
						rdwait:=2;
					end if;
				elsif(ADDRINCCPU='1' or ADDRINCPCM='1')then
					CURADDR<=CURADDR+1;
					if(MEMTYPE="00")then
						if(CURADDR=(STOPADDR(12 downto 0) & "11111"))then
							EOS<='1';
						end if;
					else
						if(CURADDR=(STOPADDR & "11"))then
							EOS<='1';
						end if;
					end if;
					if(REC='0')then
						RAMRD<='1';
						rdwait:=2;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	RDDATA<=RAMRDAT;
	CURSTOP<=	'1' when CURADDR=(STOPADDR & "11") and MEMTYPE/="00" else
					'1' when CURADDR=(STOPADDR(12 downto 0) & "11111") and MEMTYPE="00" else
					'0';
	
	process(clk,rstn)
	variable	wrwait	:integer range 0 to 3;
	begin
		if(rstn='0')then
			cpustate<=cs_IDLE;
			ADDRINCCPU<='0';
			RAMWDAT<=(others=>'0');
			BRDY<='0';
			wrwait:=0;
		elsif(clk' event and clk='1')then
			ADDRINCCPU<='0';
			if(FLAGRES='1')then
				BRDY<='0';
			elsif(setBRDY='1')then
				BRDY<='1';
			end if;
			if(wrwait>0)then
				wrwait:=wrwait-1;
			else
				case cpustate is
				when cs_IDLE =>
					if(START='0')then
						BRDY<='1';
					end if;
					if(MEMSEL='1' and START='0')then
						if(DATRD='1')then
							cpustate<=cs_READ;
						elsif(DATWR='1')then
							RAMWDAT<=WRDATA;
							cpustate<=cs_WRWAIT;
						end if;
					end if;
				when cs_READ =>
					if(RAMWAIT='0')then
						ADDRINCCPU<='1';
						BRDY<='1';
						cpustate<=cs_IDLE;
					end if;
				when cs_WRWAIT =>
					if(RAMWAIT='0')then
						RAMWR<='1';
						wrwait:=2;
						cpustate<=cs_WRITE;
					end if;
				when cs_WRITE =>
					if(RAMWAIT='0')then
						RAMWR<='0';
						ADDRINCCPU<='1';
						BRDY<='1';
						cpustate<=cs_IDLE;
					end if;
				when others =>
					cpustate<=cs_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	playsft<=sft when pcmstate=ps_PLAY else '0';

	tim	:PCMTIMING generic map(8) port map(
		DELTA_N	=>DELTA_N,
		
		PCMWR		=>adpcmsft,
		CARRY		=>adpcmcarry,
		INTER		=>adpcmint,

		sft		=>playsft,
		clk		=>clk,
		rstn		=>rstn
	);
	
	wrdly	:delayer generic map(3) port map(adpcmsft,ADPCMWR,clk,rstn);
	
	process(clk,rstn)
	variable	lSTART	:std_logic;
	begin
		if(rstn='0')then
			pcmstate<=ps_IDLE;
			CURL_Un<='0';
			ADPCMDAT<=(others=>'0');
			ADDRINCPCM<='0';
			ADPCMINIT<='0';
			ADDRREPEAT<='0';
			setBRDY<='0';
			lSTART:='0';
		elsif(clk' event and clk='1')then
			ADDRINCPCM<='0';
			ADPCMINIT<='0';
			ADDRREPEAT<='0';
			setBRDY<='0';
			case pcmstate is
			when ps_IDLE =>
				if(RST='0' and START='1' and lSTART='0')then
					ADPCMINIT<='1';
					if(REC='0')then
						pcmstate<=ps_PLAY;
					else
						pcmstate<=ps_REC;
					end if;
				end if;
			when ps_PLAY =>
				if(RST='1')then
					pcmstate<=ps_IDLE;
				elsif(adpcmcarry='1' and adpcmsft='1')then
					if(MEMSEL='1')then
						if(CURL_Un='0')then
							ADPCMDAT<=RAMRDAT(7 downto 4);
						else
							ADPCMDAT<=RAMRDAT(3 downto 0);
							setBRDY<='1';
							if(CURSTOP='1')then
								ADPCMINIT<='1';
								if(REPEAT='1')then
									ADDRREPEAT<='1';
								else
									pcmstate<=ps_IDLE;
								end if;
							end if;
							ADDRINCPCM<='1';
						end if;
						CURL_Un<=not CURL_Un;
					else
						if(CURL_Un='0')then
							ADPCMDAT<=WRDATA(7 downto 4);
						else
							ADPCMDAT<=WRDATA(3 downto 0);
							setBRDY<='1';
						end if;
					end if;
				end if;
			when ps_REC =>
				pcmstate<=ps_IDLE;
			when others =>
			end case;
			lSTART:=START;
		end if;
	end process;
	
	calc	:CALCOPNAADPCM generic map(8) port map(
		INIT	=>ADPCMINIT,
		INDAT	=>ADPCMDAT,
		INTDAT	=>adpcmint,
		WR		=>ADPCMWR,
		CARRY	=>adpcmcarry,
		
		OUTDAT	=>adpcmsig,
		BUSY	=>calcbusy,
		
		clk		=>clk,
		rstn	=>rstn
	);
	
	process(clk,rstn)begin
		if(rstn='0')then
			playstate<='0';
			mulwr<='0';
		elsif(clk' event and clk='1')then
			mulwr<='0';
			if(ADPCMWR='1')then
				playstate<='1';
			elsif(playstate='1')then
				if(calcbusy='0')then
					mulwr<='1';
					playstate<='0';
				end if;
			end if;
		end if;
	end process;
					
--	lev	:multi generic map(16,8) port map(
--		A		=>adpcmsig,
--		B		=>LEVEL,
--		write	=>mulwr,
--		
--		Q		=>adpcmlev,
--		done	=>open,
--		
--		clk		=>clk,
--		rstn	=>rstn
--	);
	
	lev	:susmult generic map(16,8) port map(
	ain		=>adpcmsig,
	bin		=>level,
	qout		=>adpcmlev,
	
	clk		=>clk
);
	
	adpcmsnd<=adpcmlev(23 downto 8);
	
	BUSY<='0' when pcmstate=ps_IDLE else '1';

	sndL<=	adpcmsnd when chL='1' else (others=>'0');
	sndR<=	adpcmsnd when chR='1' else (others=>'0');

end rtl;
