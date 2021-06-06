LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	use ieee.std_logic_arith.all;

entity OPN is
generic(
	res		:integer	:=16
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
	
--	monout	:out std_logic_vector(15 downto 0);
	op0out	:out std_logic_vector(15 downto 0);
	op1out	:out std_logic_vector(15 downto 0);
	op2out	:out std_logic_vector(15 downto 0);
	op3out	:out std_logic_vector(15 downto 0);

	clk		:in std_logic;
	cpuclk	:in std_logic;
	sft		:in std_logic;
	rstn	:in std_logic
);
end OPN;

architecture rtl of OPN is

component OPNFM
generic(
	res		:integer	:=16
);
port(
	CPU_RADR	:in std_logic_vector(7 downto 0);
	CPU_RWR		:in std_logic;
	CPU_WDAT	:in std_logic_vector(7 downto 0);
	KEY1		:in std_logic_vector(3 downto 0);
	KEY2		:in std_logic_vector(3 downto 0);
	KEY3		:in std_logic_vector(3 downto 0);
	C3M			:in std_logic_vector(1 downto 0);
	
	fmsft	:in std_logic;
	
	sndL	:out std_logic_vector(res-1 downto 0);
	sndR	:out std_logic_vector(res-1 downto 0);

	INITDONE:in std_logic;
	clk		:in std_logic;
	sft		:in std_logic;
	rstn	:in std_logic
);
end component;

component noisegen
port(
	sft		:in std_logic;
	noise	:out std_logic;
	
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

signal	PSG_TUNN,PSG_TUN0,PSG_TUN1,PSG_TUN2
					:std_logic_vector(11 downto 0);
signal	PSG_TUNC	:std_logic_vector(11 downto 0);
signal	PSG_TENn	:std_logic_vector(2 downto 0);
signal	PSG_NENn	:std_logic_vector(2 downto 0);
signal	PSG_PDIR	:std_logic_vector(1 downto 0);
signal	PSG_AMP0,PSG_AMP1,PSG_AMP2
					:std_logic_vector(4 downto 0);
signal	PSG_AMPC	:std_logic_vector(4 downto 0);
signal	PSG_EPER	:std_logic_vector(15 downto 0);
signal	PSG_ESHAPE	:std_logic_vector(3 downto 0);
signal	PSG_PA		:std_logic_vector(7 downto 0);
signal	PSG_PB		:std_logic_vector(7 downto 0);

signal	CPU_RADR	:std_logic_vector(7 downto 0);
signal	CPU_WDAT	:std_logic_vector(7 downto 0);
signal	INT_RADR	:std_logic_vector(7 downto 0);
signal	INT_RDAT	:std_logic_vector(7 downto 0);
signal	CPU_RWR		:std_logic;

signal	STATUS		:std_logic_vector(7 downto 0);
signal	BUSY		:std_logic;
signal	FLAG		:std_logic_vector(1 downto 0);
signal	REGO		:std_logic_vector(7 downto 0);
signal	TARST,TBRST	:std_logic;
signal	TAEN,TBEN	:std_logic;
signal	TALD,TBLD	:std_logic;
signal	TARDAT,TACOUNT		:std_logic_vector(9 downto 0);
signal	TBRDAT,TBCOUNT		:std_logic_vector(7 downto 0);

constant fslength	:integer	:=198;
signal	fscount		:integer range 0 to fslength-1;

constant pslength	:integer	:=44;
signal	pscount		:integer range 0 to pslength-1;

signal	fmsnd		:std_logic_vector(15 downto 0);

signal	channel		:std_logic_vector(1 downto 0);
signal	slot		:std_logic_vector(1 downto 0);

type FMSTATE_t is (
	FS_IDLE,
	FS_TIMER
);

signal	FMSTATE	:FMSTATE_t;
signal	fmsft	:std_logic;
signal	psgsft	:std_logic;

signal	TBPS	:integer range 0 to 15;

signal	Key1,Key2,Key3	:std_logic_vector(3 downto 0);

signal	C3M		:std_logic_vector(1 downto 0);
signal	intbgn,intend	:std_logic;
		
signal	psgch	:integer range 0 to 3;
signal	psglog	:std_logic_vector(2 downto 0);
signal	noiselog	:std_logic;
signal	noisesft	:std_logic;
signal	psgcountn,psgcount0,psgcount1,psgcount2,psgcountc,psgcountwd	:std_logic_vector(11 downto 0);
constant psgczero	:std_logic_vector(11 downto 0)	:=(others=>'0');
signal	psgcountwr	:std_logic;
signal	psgenvcount	:std_logic_vector(15 downto 0);
type PSGST_t is (
	PST_IDLE,
	PST_NF,
	PST_NN,
	PST_C0F,
	PST_C0L,
	PST_C1F,
	PST_C1L,
	PST_C2F,
	PST_C2L,
	PST_MIX
);
signal	PSGST	:PSGST_t;

signal	PSG_LEV	:std_logic_vector(3 downto 0);
signal	PSG_VAL	:std_logic_vector(15 downto 0);

type PENV_t is (
	PEM_NOP,
	PEM_INC,
	PEM_DEC
);
signal	PENVM		:PENV_t;
signal	lPSGON		:std_logic;
signal	PENV_LEV	:std_logic_vector(3 downto 0);
signal	psg_sgn0,psg_sgn1,psg_sgn2	:std_logic_vector(15 downto 0);
signal	psg_sgn01,psg_sgn012		:std_logic_vector(15 downto 0);
signal	psg_smix	:std_logic_vector(15 downto 0);
signal	sndmix		:std_logic_vector(15 downto 0);
begin
	STATUS<=BUSY & "00000" & FLAG;
	
	process(clk,rstn)begin
		if(rstn='0')then
			fmsft<='0';
			fscount<=fslength-1;
		elsif(clk' event and clk='1')then
			if(sft='1')then
				fmsft<='0';
				if(fscount>0)then
					fscount<=fscount-1;
				else
					fmsft<='1';
					fscount<=fslength-1;
				end if;
			end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			psgsft<='0';
			pscount<=pslength-1;
		elsif(clk' event and clk='1')then
			if(sft='1')then
				psgsft<='0';
				if(pscount>0)then
					pscount<=pscount-1;
				else
					psgsft<='1';
					pscount<=pslength-1;
				end if;
			end if;
		end if;
	end process;

	process(cpuclk,rstn)begin
		if(rstn='0')then
			CPU_RADR<=(others=>'0');
			BUSY<='1';
			PSG_TUN0<=(others=>'0');
			PSG_TUN1<=(others=>'0');
			PSG_TUN2<=(others=>'0');
			PSG_TUNN<=(others=>'0');
			PSG_TENn<=(others=>'0');
			PSG_NENn<=(others=>'0');
			PSG_PDIR<=(others=>'0');
			PSG_AMP0<=(others=>'0');
			PSG_AMP1<=(others=>'0');
			PSG_AMP2<=(others=>'0');
			PSG_EPER<=(others=>'0');
			PSG_ESHAPE<=(others=>'0');
			PSG_PA<=(others=>'0');
			PSG_PB<=(others=>'0');
			CPU_RWR<='0';
			TARST<='0';
			TBRST<='0';
			TARDAT<=(others=>'0');
			TBRDAT<=(others=>'0');
			Key1<=(others=>'0');
			Key2<=(others=>'0');
			Key3<=(others=>'0');
			CPU_WDAT<=(others=>'0');
		elsif(cpuclk' event and cpuclk='1')then
			CPU_RWR<='0';
			TARST<='0';
			TBRST<='0';
			if(BUSY='1')then
				if(CPU_RADR/=x"ff")then
					CPU_RADR<=CPU_RADR+x"01";
					CPU_RWR<='1';
				else
					CPU_RADR<=(others=>'0');
					BUSY<='0';
				end if;
			else
				if(CSn='0' and WRn='0')then
					if(ADR0='0')then
						CPU_RADR<=DIN;
					else
						CPU_RWR<='1';
						CPU_WDAT<=DIN;
						case CPU_RADR is
						when x"00" =>
							PSG_TUN0(7 downto 0)<=DIN;
						when x"01" =>
							PSG_TUN0(11 downto 8)<=DIN(3 downto 0);
						when x"02" =>
							PSG_TUN1(7 downto 0)<=DIN;
						when x"03" =>
							PSG_TUN1(11 downto 8)<=DIN(3 downto 0);
						when x"04" =>
							PSG_TUN2(7 downto 0)<=DIN;
						when x"05" =>
							PSG_TUN2(11 downto 8)<=DIN(3 downto 0);
						when x"06" =>
							PSG_TUNN<="0000000" & DIN(4 downto 0);
						when x"07" =>
							PSG_TENn<=DIN(2 downto 0);
							PSG_NENn<=DIN(5 downto 3);
							PSG_PDIR<=DIN(7 downto 6);
						when x"08" =>
							PSG_AMP0<=DIN(4 downto 0);
						when x"09" =>
							PSG_AMP1<=DIN(4 downto 0);
						when x"0a" =>
							PSG_AMP2<=DIN(4 downto 0);
						when x"0b" =>
							PSG_EPER(7 downto 0)<=DIN;
						when x"0c" =>
							PSG_EPER(15 downto 8)<=DIN;
						when x"0d" =>
							PSG_ESHAPE<=DIN(3 downto 0);
						when x"0e" =>
							PSG_PA<=DIN;
						when x"0f" =>
							PSG_PB<=DIN;
						when x"24" =>
							TARDAT(9 downto 2)<=DIN;
						when x"25" =>
							TARDAT(1 downto 0)<=DIN(1 downto 0);
						when x"26" =>
							TBRDAT<=DIN;
						when x"27"=>
							TALD<=DIN(0);
							TBLD<=DIN(1);
							TAEN<=DIN(2);
							TBEN<=DIN(3);
							TARST<=DIN(4);
							TBRST<=DIN(5);
							C3M<=DIN(7 downto 6);
						when x"28" =>
							case DIN(1 downto 0) is
							when "00" =>
								Key1<=DIN(7 downto 4);
							when "01" =>
								Key2<=DIN(7 downto 4);
							when "10" =>
								Key3<=DIN(7 downto 4);
							when others =>
							end case;
						when others=>
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
	

	REGO<=
			PSG_TUN0(7 downto 0)			when CPU_RADR=x"00" else
			x"0" & PSG_TUN0(11 downto 8)	when CPU_RADR=x"01" else
			PSG_TUN1(7 downto 0)			when CPU_RADR=x"02" else
			x"0" & PSG_TUN1(11 downto 8)	when CPU_RADR=x"03" else
			PSG_TUN2(7 downto 0)			when CPU_RADR=x"04" else
			x"0" & PSG_TUN2(11 downto 8)	when CPU_RADR=x"05" else
			"000" & PSG_TUNN(4 downto 0)	when CPU_RADR=x"06" else
			PSG_PDIR & PSG_NENn & PSG_TENn	when CPU_RADR=x"07" else
			"000" & PSG_AMP0				when CPU_RADR=x"08" else
			"000" & PSG_AMP1				when CPU_RADR=x"09" else
			"000" & PSG_AMP2				when CPU_RADR=x"0a" else
			PSG_EPER(7 downto 0)			when CPU_RADR=x"0b" else
			PSG_EPER(15 downto 8)			when CPU_RADR=x"0c" else
			x"0" & PSG_ESHAPE				when CPU_RADR=x"0d" else
			PAIN							when CPU_RADR=x"0e" else
			PBIN							when CPU_RADR=x"0f" else
			STATUS;

	DOUT<=STATUS when ADR0='0' else REGO;

	DOE<='1' when CSn='0' and RDn='0' else '0';
	
	PAOUT<=PSG_PA;
	PBOUT<=PSG_PB;
	PAOE<=PSG_PDIR(0);
	PBOE<=PSG_PDIR(1);

	process(clk,rstn)begin
		if(rstn='0')then
			FMSTATE<=FS_IDLE;
			intbgn<='0';
		elsif(clk' event and clk='1')then
			if(BUSY='0' and sft='1')then
				intbgn<='0';
				case FMSTATE is
				when FS_IDLE =>
					if(fmsft='1')then
						FMSTATE<=FS_TIMER;
						intbgn<='1';
					end if;
				when FS_TIMER =>
					if(intend='1')then
						FMSTATE<=FS_IDLE;
					end if;
				when others=>
					FMSTATE<=FS_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	process(clk,rstn)
	begin
		if(rstn='0')then
			TBPS<=0;
			intend<='0';
			TACOUNT<=(others=>'0');
			TBCOUNT<=(others=>'0');
			FLAG<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(BUSY='0' and sft='1')then
				intend<='0';
				if(TARST='1')then
					FLAG(0)<='0';
				end if;
				if(TBRST='1')then
					FLAG(1)<='0';
				end if;
				intend<='0';
				case FMSTATE is
				when FS_TIMER =>
					if(intbgn='1')then
						if(TALD='0')then
							TACOUNT<=TARDAT;
						else
							if(TACOUNT="1111111111")then
								if(TAEN='1')then
									FLAG(0)<='1';
								end if;
								TACOUNT<=TARDAT;
							else
								TACOUNT<=TACOUNT+"0000000001";
							end if;
						end if;
						
						if(TBPS/=0)then
							TBPS<=TBPS-1;
						else
							TBPS<=15;
							if(TBLD='0')then
								TBCOUNT<=TBRDAT;
							else
								if(TBCOUNT=x"ff")then
									if(TBEN='1')then
										FLAG(1)<='1';
									end if;
									TBCOUNT<=TBRDAT;
								else
									TBCOUNT<=TBCOUNT+x"01";
								end if;
							end if;
						end if;
						intend<='1';
					end if;
				when others =>
				end case;
			end if;
		end if;
	end process;
	
	INTn<=not(FLAG(1) or FLAG(0)) ;

	FM	:OPNFM generic map(res)	port map(
		CPU_RADR	=>CPU_RADR,
		CPU_RWR		=>CPU_RWR,
		CPU_WDAT	=>CPU_WDAT,
		KEY1		=>key1,
		KEY2		=>key2,
		KEY3		=>key3,
		C3M			=>C3M,
		
		fmsft	=>fmsft,
		
		sndL	=>fmsnd,
		sndR	=>open,

		INITDONE=>not BUSY,
		clk		=>clk,
		sft		=>sft,
		rstn	=>rstn
	);

	
	process(clk,rstn)begin
		if(rstn='0')then
			psgcount0<=(others=>'0');
			psgcount1<=(others=>'0');
			psgcount2<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(psgcountwr='1')then
				case psgch is
				when 0 =>
					psgcount0<=psgcountwd;
				when 1 =>
					psgcount1<=psgcountwd;
				when 2 =>
					psgcount2<=psgcountwd;
				when others =>
					psgcountn<=psgcountwd;
				end case;
			end if;
		end if;
	end process;
	
	process(PSGST)begin
		case PSGST is
		when PST_C0F | PST_C0L =>
			psgch<=0;
		when PST_C1F | PST_C1L =>
			psgch<=1;
		when PST_C2F | PST_C2L =>
			psgch<=2;
		when others =>
			psgch<=3;
		end case;
	end process;
	
	psgcountc<=	psgcount0 when psgch=0 else
				psgcount1 when psgch=1 else
				psgcount2 when psgch=2 else
				psgcountn;

	PSG_TUNC<=	PSG_TUN0 when psgch=0 else
				PSG_TUN1 when psgch=1 else
				PSG_TUN2 when psgch=2 else
				PSG_TUNN;
				
	PSG_AMPC<=	PSG_AMP0 when psgch=0 else
				PSG_AMP1 when psgch=1 else
				PSG_AMP2 when psgch=2 else
				(others=>'0');
	
	PSG_VAL<=	x"7fff" when PSG_LEV=x"f" else
				x"5a81" when PSG_LEV=x"e" else
				x"3fff" when PSG_LEV=x"d" else
				x"2d40" when PSG_LEV=x"c" else
				x"1fff" when PSG_LEV=x"b" else
				x"16a0" when PSG_LEV=x"a" else
				x"0fff" when PSG_LEV=x"9" else
				x"0b50" when PSG_LEV=x"8" else
				x"07ff" when PSG_LEV=x"7" else
				x"05a8" when PSG_LEV=x"6" else
				x"03ff" when PSG_LEV=x"5" else
				x"02d4" when PSG_LEV=x"4" else
				x"01ff" when PSG_LEV=x"3" else
				x"016a" when PSG_LEV=x"2" else
				x"00ff" when PSG_LEV=x"1" else
				x"0000";

--PSG pulse control	
	process(clk,rstn)
	variable vsign	:std_logic_vector(15 downto 0);
	begin
		if(rstn='0')then
			PSGST<=PST_IDLE;
			psgcountwr<='0';
			psgcountwd<=(others=>'0');
			psg_sgn0<=(others=>'0');
			psg_sgn1<=(others=>'0');
			psg_sgn2<=(others=>'0');
			psglog<=(others=>'0');
			noisesft<='0';
		elsif(clk' event and clk='1')then
			noisesft<='0';
			if(sft='1')then
				psgcountwr<='0';
				case PSGST is
				when PST_IDLE =>
					if(psgsft='1')then
						PSGST<=PST_NF;
					end if;
				when PST_NF | PST_C0F | PST_C1F | PST_C2F =>
					if(psgcountc=psgczero)then
						psgcountwd<=PSG_TUNC;
						if(PSG_TUNC/=psgczero)then
							if(PSGST=PST_NF)then
								noisesft<='1';
							else
								psglog(psgch)<=not psglog(psgch);
							end if;
						end if;
					else
						psgcountwd<=psgcountc-x"001";
					end if;
					psgcountwr<='1';
					case PSGST is
					when PST_NF =>
						PSGST<=PST_NN;
					when PST_C0F =>
						PSGST<=PST_C0L;
					when PST_C1F =>
						PSGST<=PST_C1L;
					when PST_C2F =>
						PSGST<=PST_C2L;
					when others =>
						PSGST<=PST_IDLE;
					end case;
				when PST_NN =>
					PSGST<=PST_C0F;
				when PST_C0L =>
					if(PSG_TENn(0)='1')then
						vsign:=(others=>'0');
					elsif(psglog(0)='1')then
						vsign:='1' & not PSG_VAL(15 downto 1);
					else
						vsign:='0' & PSG_VAL(15 downto 1);
					end if;
					if(PSG_NENn(0)='0')then
						if(noiselog='1')then
							vsign:=vsign+('1' & not (PSG_VAL(15 downto 1)));
						else
							vsign:=vsign+('0' & PSG_VAL(15 downto 1));
						end if;
					end if;
					psg_sgn0<=vsign;
					PSGST<=PST_C1F;
				when PST_C1L =>
					if(PSG_TENn(1)='1')then
						vsign:=(others=>'0');
					elsif(psglog(1)='1')then
						vsign:='1' & not PSG_VAL(15 downto 1);
					else
						vsign:='0' & PSG_VAL(15 downto 1);
					end if;
					if(PSG_NENn(1)='0')then
						if(noiselog='1')then
							vsign:=vsign+('1' & not (PSG_VAL(15 downto 1)));
						else
							vsign:=vsign+('0' & PSG_VAL(15 downto 1));
						end if;
					end if;
					psg_sgn1<=vsign;
					PSGST<=PST_C2F;
				when PST_C2L =>
					if(PSG_TENn(2)='1')then
						vsign:=(others=>'0');
					elsif(psglog(2)='1')then
						vsign:='1' & not PSG_VAL(15 downto 1);
					else
						vsign:='0' & PSG_VAL(15 downto 1);
					end if;
					if(PSG_NENn(2)='0')then
						if(noiselog='1')then
							vsign:=vsign+('1' & not (PSG_VAL(15 downto 1)));
						else
							vsign:=vsign+('0' & PSG_VAL(15 downto 1));
						end if;
					end if;
					psg_sgn2<=vsign;
					PSGST<=PST_MIX;
				when PST_MIX =>
					psg_smix<=psg_sgn012;
					PSGST<=PST_IDLE;
				when others =>
					PSGST<=PST_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	psgadd12	:addsat generic map(16) port map(psg_sgn0,psg_sgn1,psg_sgn01,open,open);
	psgadd123	:addsat generic map(16) port map(psg_sgn01,psg_sgn2,psg_sgn012,open,open);

	NG	:noisegen port map(noisesft,noiselog,clk,rstn);

	PSG_LEV<=PENV_LEV when PSG_AMPC(4)='1' else PSG_AMPC(3 downto 0);

--PSG envelope control
	process(clk,rstn)	
	variable PSGON	:std_logic;
	begin
		if(rstn='0')then
			lPSGON<='0';
			PENV_LEV<=x"0";
			psgenvcount<=(others=>'0');
			PENVM<=PEM_NOP;
		elsif(clk' event and clk='1')then
			if(sft='1')then
				PSGON:=PSG_AMP0(4) or PSG_AMP1(4) or PSG_AMP2(4);
				lPSGON<=PSGON;
				if(PSGON='1' and lPSGON='0')then
					if(PSG_ESHAPE(2)='0')then
						PENV_LEV<=x"f";
						PENVM<=PEM_DEC;
					else
						PENV_LEV<=x"0";
						PENVM<=PEM_INC;
					end if;
					psgenvcount<=(others=>'0');
				elsif(psgsft='1')then
					if(psgenvcount>x"0000")then
						psgenvcount<=psgenvcount-x"0001";
					else
						psgenvcount<=PSG_EPER;
						case PSG_ESHAPE is
						when x"0" | x"1" | x"2" | x"3" =>
							if(PENV_LEV>x"0")then
								PENV_LEV<=PENV_LEV-x"1";
							else
								PENV_LEV<=x"0";
								PENVM<=PEM_NOP;
							end if;
						when x"4" | x"5" | x"6" | x"7" =>
							if(PENVM=PEM_INC)then
								if(PENV_LEV=x"f")then
									PENV_LEV<=x"0";
									PENVM<=PEM_NOP;
								else
									PENV_LEV<=PENV_LEV+x"1";
								end if;
							else
								PENV_LEV<=x"0";
							end if;
						when x"8" =>
							if(PENV_LEV>x"0")then
								PENV_LEV<=PENV_LEV-x"1";
							else
								PENV_LEV<=x"f";
							end if;
						when x"9" =>
							if(PENVM=PEM_DEC)then
								if(PENV_LEV>x"0")then
									PENV_LEV<=PENV_LEV-x"1";
								else
									PENVM<=PEM_NOP;
									PENV_LEV<=x"0";
								end if;
							else
								PENV_LEV<=x"0";
							end if;
						when x"a" | x"e" =>
							if(PENVM=PEM_DEC)then
								if(PENV_LEV>x"0")then
									PENV_LEV<=PENV_LEV-x"1";
								else
									PENV_LEV<=x"1";
									PENVM<=PEM_INC;
								end if;
							else
								if(PENV_LEV<x"f")then
									PENV_LEV<=PENV_LEV+x"1";
								else
									PENV_LEV<=x"e";
									PENVM<=PEM_DEC;
								end if;
							end if;
						when x"b" =>
							if(PENVM=PEM_DEC)then
								if(PENV_LEV>x"0")then
									PENV_LEV<=PENV_LEV-x"1";
								else
									PENV_LEV<=x"f";
									PENVM<=PEM_NOP;
								end if;
							else
								PENV_LEV<=x"f";
							end if;
						when x"c" =>
							if(PENV_LEV<x"f")then
								PENV_LEV<=PENV_LEV+x"1";
							else
								PENV_LEV<=x"0";
							end if;
						when x"d" =>
							if(PENVM=PEM_INC)then
								if(PENV_LEV<x"f")then
									PENV_LEV<=PENV_LEV+x"1";
								else
									PENV_LEV<=x"f";
									PENVM<=PEM_NOP;
								end if;
							else
								PENV_LEV<=x"f";
							end if;
						when x"f" =>
							if(PENVM=PEM_INC)then
								if(PENV_LEV<x"f")then
									PENV_LEV<=PENV_LEV+x"1";
								else
									PENV_LEV<=x"0";
									PENVM<=PEM_NOP;
								end if;
							else
								PENV_LEV<=x"0";
							end if;
						when others =>
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	smix	:addsat generic map(16) port map(fmsnd,psg_smix,sndmix,open,open);

	snd<=sndmix(15 downto 16-res);
	
--	monout<=thita;
	
end rtl;
