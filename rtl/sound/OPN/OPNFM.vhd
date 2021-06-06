LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	use ieee.std_logic_arith.all;
	use work.envelope_pkg.all;

entity OPNFM is
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
end OPNFM;

architecture rtl of OPNFM is
component OPNREG is
port(
	RDADDR	:in std_logic_vector(7 downto 0);
	RDDAT	:out std_logic_vector(7 downto 0);
	WRADDR	:in std_logic_vector(7 downto 0);
	WRDAT	:in std_logic_vector(7 downto 0);
	WR		:in std_logic;
	
	clk		:in std_logic
);
end component;

component sintbl
port(
	addr	:in std_logic_vector(15 downto 0);
	
	dat		:out std_logic_vector(15 downto 0);

	clk		:in std_logic
);
end component;

component TLtbl
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;

component muls16xu16
port(
	ins		:in std_logic_vector(15 downto 0);
	inu		:in std_logic_vector(15 downto 0);
	
	q		:out std_logic_vector(15 downto 0);
	
	clk		:in std_logic
);
end component;

component  FMreg
generic(
	DWIDTH	:integer	:=16
);
port(
	CH		:std_logic_vector(1 downto 0);
	SL		:std_logic_vector(1 downto 0);
	RDAT	:out std_logic_vector(DWIDTH-1 downto 0);
	WDAT	:in std_logic_vector(DWIDTH-1 downto 0);
	WR		:in std_logic;

	clk		:in std_logic
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

component envcont
generic(
	totalwidth	:integer	:=20
);
port(
	KEY		:in std_logic;
	AR		:in std_logic_vector(4 downto 0);
	DR		:in std_logic_vector(4 downto 0);
	SLlevel	:in std_logic_vector(15 downto 0);
	RR		:in std_logic_vector(3 downto 0);
	SR		:in std_logic_vector(4 downto 0);
	
	CURSTATE	:in envstate_t;
	NXTSTATE	:out envstate_t;
	
	CURLEVEL	:in std_logic_vector(totalwidth-1 downto 0);
	NXTLEVEL	:out std_logic_vector(totalwidth-1 downto 0)
);

end component;

signal	INT_RADR	:std_logic_vector(7 downto 0);
signal	INT_RDAT	:std_logic_vector(7 downto 0);

constant fslength	:integer	:=198;
signal	fscount		:integer range 0 to fslength-1;

constant pslength	:integer	:=44;
signal	pscount		:integer range 0 to pslength-1;

signal	thitard,thitawd
					:std_logic_vector(15 downto 0);
signal	thitawr			:std_logic;
signal	elevrd,elevwd	:std_logic_vector(19 downto 0);
signal	elevwr			:std_logic;
signal	fbsrc1,fbsrc2,fbsrc3
					:std_logic_vector(15 downto 0);
signal	toutxa,toutxb,toutxc,toutxd,
		toutc		:std_logic_vector(15 downto 0);

signal	Lcout1,Lcout2,Lcout3,Rcout1,Rcout2,Rcout3
					:std_logic_vector(15 downto 0);
signal	Lcout01,Lcout23,Lcout123,Rcout01,Rcout23,Rcout123
					:std_logic_vector(15 downto 0);
signal	fm_smixL		:std_logic_vector(15 downto 0);
signal	fm_smixR		:std_logic_vector(15 downto 0);

signal	channel		:std_logic_vector(1 downto 0);
signal	slot		:std_logic_vector(1 downto 0);

type FMSTATE_t is (
	FS_IDLE,
	FS_C1Oa,
	FS_C1Ob,
	FS_C1Oc,
	FS_C1Od,
	FS_C2Oa,
	FS_C2Ob,
	FS_C2Oc,
	FS_C2Od,
	FS_C3Oa,
	FS_C3Ob,
	FS_C3Oc,
	FS_C3Od,
	FS_MIX
);
signal	FMSTATE	:FMSTATE_t;
signal	psgsft	:std_logic;
signal	intbgn	:std_logic;
signal	intend	:std_logic;
signal	thita	:std_logic_vector(15 downto 0);
signal	sinthita:std_logic_vector(15 downto 0);

type INTST_t is(
	IS_IDLE,
	IS_INIT,
	IS_READF2,
	IS_READF1,
	IS_READALGFB,
	IS_SETDETMUL,
	IS_READLFOSEN,
	IS_READDETMUL,
	IS_CALCTHITA,
	IS_READTL,
	IS_READKSAR,
	IS_READDR,
	IS_READSR,
	IS_READSLRR,
	IS_CALCENVW,
	IS_CALCENV,
	IS_CALCTL,
	IS_CMIX
);
signal	INTST	:INTST_t;
signal	TBPS	:integer range 0 to 15;

signal	keyc	:std_logic;

--frequency parameter
signal	C3mode	:std_logic_vector(1 downto 0);
signal	Algo	:std_logic_vector(2 downto 0);
signal	FdBck	:std_logic_vector(2 downto 0);
signal	Blk		:std_logic_vector(2 downto 0);
signal	Fnum	:std_logic_vector(10 downto 0);
signal	Note	:std_logic_vector(1 downto 0);
signal	Mult	:std_logic_vector(3 downto 0);
signal	Detune	:std_logic_vector(2 downto 0);
signal	SFnum	:std_logic_vector(15 downto 0);
signal	MSFnum	:std_logic_vector(15 downto 0);
signal	FBsrc	:std_logic_vector(15 downto 0);
signal	addfb	:std_logic_vector(15 downto 0);
signal	addfbm	:std_logic_vector(4 downto 0);
signal	add13,add23,add24,add234,add1234	:std_logic_vector(15 downto 0);

--enverope parameter
signal	AR		:std_logic_vector(4 downto 0);
signal	KS		:std_logic_vector(1 downto 0);
signal	DR		:std_logic_vector(4 downto 0);
signal	SLlevel	:std_logic_vector(15 downto 0);
signal	RR		:std_logic_vector(3 downto 0);
signal	SR		:std_logic_vector(4 downto 0);
signal	TL		:std_logic_vector(6 downto 0);
signal	EVAL	:std_logic_vector(6 downto 0);
signal	TLlevel	:std_logic_vector(15 downto 0);
signal	envcalc	:std_logic;
signal	envsin	:std_logic_vector(15 downto 0);
signal	TLVAL	:std_logic_vector(15 downto 0);
signal	senL,senR	:std_logic;

signal	envst_1a,envst_1b,envst_1c,envst_1d,
		envst_2a,envst_2b,envst_2c,envst_2d,
		envst_3a,envst_3b,envst_3c,envst_3d,
		cenvst,nenvst	:envstate_t;
		

begin

	reg	:OPNREG port map(
		RDADDR	=>INT_RADR,
		RDDAT	=>INT_RDAT,
		WRADDR	=>CPU_RADR,
		WRDAT	=>CPU_WDAT,
		WR		=>CPU_RWR,
		clk		=>clk
	);
	
	process(clk,rstn)begin
		if(rstn='0')then
			FMSTATE<=FS_IDLE;
			C3mode<=(others=>'0');
			intbgn<='0';
		elsif(clk' event and clk='1')then
			if(INITDONE='1' and sft='1')then
				intbgn<='0';
				case FMSTATE is
				when FS_IDLE =>
					if(fmsft='1')then
						FMSTATE<=FS_C1Oa;
						intbgn<='1';
						C3mode<=C3M;
					end if;
				when FS_C1Oa =>
					if(intend='1')then
						FMSTATE<=FS_C1Ob;
						INTBGN<='1';
					end if;
				when FS_C1Ob =>
					if(intend='1')then
						FMSTATE<=FS_C1Oc;
						INTBGN<='1';
					end if;
				when FS_C1Oc =>
					if(intend='1')then
						FMSTATE<=FS_C1Od;
						INTBGN<='1';
					end if;
				when FS_C1Od =>
					if(intend='1')then
						FMSTATE<=FS_C2Oa;
						INTBGN<='1';
					end if;
				when FS_C2Oa =>
					if(intend='1')then
						FMSTATE<=FS_C2Ob;
						INTBGN<='1';
					end if;
				when FS_C2Ob =>
					if(intend='1')then
						FMSTATE<=FS_C2Oc;
						INTBGN<='1';
					end if;
				when FS_C2Oc =>
					if(intend='1')then
						FMSTATE<=FS_C2Od;
						INTBGN<='1';
					end if;
				when FS_C2Od =>
					if(intend='1')then
						FMSTATE<=FS_C3Oa;
						INTBGN<='1';
					end if;
				when FS_C3Oa =>
					if(intend='1')then
						FMSTATE<=FS_C3Ob;
						INTBGN<='1';
					end if;
				when FS_C3Ob =>
					if(intend='1')then
						FMSTATE<=FS_C3Oc;
						INTBGN<='1';
					end if;
				when FS_C3Oc =>
					if(intend='1')then
						FMSTATE<=FS_C3Od;
						INTBGN<='1';
					end if;
				when FS_C3Od =>
					if(intend='1')then
						FMSTATE<=FS_MIX;
						INTBGN<='1';
					end if;
				when FS_MIX =>
					if(intend='1')then
						FMSTATE<=FS_IDLE;
					end if;
				when others=>
					FMSTATE<=FS_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	process(FMSTATE)begin
		case FMSTATE is
		when FS_C1Oa | FS_C1Ob | FS_C1Oc | FS_C1Od =>
			channel<="00";
		when FS_C2Oa | FS_C2Ob | FS_C2Oc | FS_C2Od =>
			channel<="01";
		when FS_C3Oa | FS_C3Ob | FS_C3Oc | FS_C3Od =>
			channel<="10";
		when others =>
			channel<="11";
		end case;
		case FMSTATE is
		when FS_C1Oa | FS_C2Oa | FS_C3Oa =>
			slot<="00";
		when FS_C1Ob | FS_C2Ob | FS_C3Ob =>
			slot<="01";
		when FS_C1Oc | FS_C2Oc | FS_C3Oc =>
			slot<="10";
		when FS_C1Od | FS_C2Od | FS_C3Od =>
			slot<="11";
		when others =>
			slot<="00";
		end case;
	end process;
	
	thitareg	:FMreg generic map(16) port map(channel,slot,thitard,thitawd,thitawr,clk);
	elevreg		:FMreg generic map(20) port map(channel,slot,elevrd,elevwd,elevwr,clk);
	
	process(clk,rstn)
	variable vthita	:std_logic_vector(15 downto 0);
	variable addthita:std_logic_vector(15 downto 0);
	variable coutc	:std_logic_vector(15 downto 0);
	variable xtoutxa,xtoutxb,xtoutxc,xtoutxd	:std_logic_vector(15 downto 0);
	begin
		if(rstn='0')then
			INT_RADR<=(others=>'0');
			INTST<=IS_IDLE;
			TBPS<=0;
			intend<='0';
			envst_1a<=es_OFF;
			envst_1b<=es_OFF;
			envst_1c<=es_OFF;
			envst_1d<=es_OFF;
			envst_2a<=es_OFF;
			envst_2b<=es_OFF;
			envst_2c<=es_OFF;
			envst_2d<=es_OFF;
			envst_3a<=es_OFF;
			envst_3b<=es_OFF;
			envst_3c<=es_OFF;
			envst_3d<=es_OFF;
			envcalc<='0';
			thitawd<=(others=>'0');
			thitawr<='0';
			elevwr<='0';
			fbsrc1<=(others=>'0');
			fbsrc2<=(others=>'0');
			fbsrc3<=(others=>'0');
			TL<=(others=>'0');
			TLlevel<=(others=>'0');
			SLlevel<=(others=>'0');
			senL<='0';
			senR<='0';
		elsif(clk' event and clk='1')then
			if(INITDONE='1' and sft='1')then
				thitawr<='0';
				elevwr<='0';
				intend<='0';
				envcalc<='0';
				intend<='0';
				case FMSTATE is
				when FS_C1Oa | FS_C1Ob | FS_C1Oc | FS_C1Od |
					 FS_C2Oa | FS_C2Ob | FS_C2Oc | FS_C2Od |
					 FS_C3Oa | FS_C3Ob | FS_C3Oc | FS_C3Od =>
					if(intbgn='1')then
						INTST<=IS_INIT;
					else
						case INTST is
						when IS_INIT =>
							if(slot="00" or ((C3mode="01" or C3mode="10") and (channel="10")))then
								case FMSTATE is
								when FS_C1Oa =>
									INT_RADR<=x"a4";
								when FS_C2Oa =>
									INT_RADR<=x"a5";
								when FS_C3Oa =>
									INT_RADR<=x"a6";
								when FS_C3Ob =>
									INT_RADR<=x"ae";
								when FS_C3Oc =>
									INT_RADR<=x"ac";
								when FS_C3Od =>
									INT_RADR<=x"a6";
								when others =>
									INT_RADR<=x"00";
								end case;
								INTST<=IS_READF2;
							else
								INTST<=IS_SETDETMUL;
							end if;
						when IS_READF2 =>
							Blk<=INT_RDAT(5 downto 3);
							Fnum(10 downto 8)<=INT_RDAT(2 downto 0);
							INT_RADR<=INT_RADR-x"04";
							INTST<=IS_READF1;
						when IS_READF1 =>
							Fnum(7 downto 0)<=INT_RDAT;
							INTST<=IS_READALGFB;
							case FMSTATE is
							when FS_C1Oa =>
								INT_RADR<=x"b0";
							when FS_C2Oa =>
								INT_RADR<=x"b1";
							when FS_C3Oa =>
								INT_RADR<=x"b2";
							when others =>
								INTST<=IS_SETDETMUL;
							end case;
						when IS_READALGFB =>
							Algo<=INT_RDAT(2 downto 0);
							FdBck<=INT_RDAT(5 downto 3);
							INT_RADR<=INT_RADR+x"04";
							INTST<=IS_READLFOSEN;
						when IS_READLFOSEN =>
							senL<=INT_RDAT(7);
							senR<=INT_RDAT(6);
							INTST<=IS_SETDETMUL;
						when IS_SETDETMUL =>
							case FMSTATE is
							when FS_C1Oa =>
								INT_RADR<=x"30";
							when FS_C1Ob =>
								INT_RADR<=x"38";
							when FS_C1Oc =>
								INT_RADR<=x"34";
							when FS_C1Od =>
								INT_RADR<=x"3c";
							when FS_C2Oa =>
								INT_RADR<=x"31";
							when FS_C2Ob =>
								INT_RADR<=x"39";
							when FS_C2Oc =>
								INT_RADR<=x"35";
							when FS_C2Od =>
								INT_RADR<=x"3d";
							when FS_C3Oa =>
								INT_RADR<=x"32";
							when FS_C3Ob =>
								INT_RADR<=x"3a";
							when FS_C3Oc =>
								INT_RADR<=x"36";
							when FS_C3Od =>
								INT_RADR<=x"3e";
							when others =>
							end case;
							INTST<=IS_READDETMUL;
						when IS_READDETMUL =>
							Detune<=INT_RDAT(6 downto 4);
							Mult<=INT_RDAT(3 downto 0);
							INTST<=IS_CALCTHITA;
						when IS_CALCTHITA =>	--with set AR
--							xtoutxa:=toutxa(14 downto 0) & '0';
--							xtoutxb:=toutxb(14 downto 0) & '0';
--							xtoutxc:=toutxc(14 downto 0) & '0';
							xtoutxa:=toutxa(11 downto 0) & "0000";
							xtoutxb:=toutxb(11 downto 0) & "0000";
							xtoutxc:=toutxc(11 downto 0) & "0000";
							vthita:=thitard+MSFnum;
							case slot is
							when "00" =>
								addthita:=addfb;
							when "01" =>
								case Algo is
								when "000" | "011" | "100" | "101" | "110"=>
									addthita:=xtoutxa;
								when others =>
									addthita:=(others=>'0');
								end case;
							when "10" =>
								case Algo is
								when "000" | "010" =>
									addthita:=xtoutxb;
								when "001" =>
									addthita:=xtoutxa+xtoutxb;
								when "101" =>
									addthita:=xtoutxa;
								when others =>
									addthita:=(others=>'0');
								end case;
							when "11" =>
								case Algo is
								when "000" | "001" | "100" =>
									addthita:=xtoutxc;
								when "010" =>
									addthita:=xtoutxa+xtoutxc;
								when "011" =>
									addthita:=xtoutxb+xtoutxc;
								when "101" =>
									addthita:=xtoutxa;
								when others =>
									addthita:=(others=>'0');
								end case;
							when others =>
								addthita:=(others=>'0');
							end case;
							if(keyc='0' and cenvst=es_OFF)then
								vthita:=(others=>'0');
							end if;
							thitawd<=vthita;
							thitawr<='1';
							thita<=vthita+addthita;
							INT_RADR<=INT_RADR+x"10";
							INTST<=IS_READTL;
						when IS_READTL =>
							TL<=INT_RDAT(6 downto 0);
							INT_RADR<=INT_RADR+x"10";
							INTST<=IS_READKSAR;
						when IS_READKSAR =>
							TLlevel<=TLval;
							KS<=INT_RDAT(7 downto 6);
							AR<=INT_RDAT(4 downto 0);
							INT_RADR<=INT_RADR+x"10";
							INTST<=IS_READDR;
						when IS_READDR =>
							DR<=INT_RDAT(4 downto 0);
							INT_RADR<=INT_RADR+x"10";
							INTST<=IS_READSR;
						when IS_READSR =>
							SR<=INT_RDAT(4 downto 0);
							INT_RADR<=INT_RADR+x"10";
							INTST<=IS_READSLRR;
						when IS_READSLRR =>
							TL<='0' & INT_RDAT(7 downto 4) & "00";
							RR<=INT_RDAT(3 downto 0);
							envcalc<='1';
							INTST<=IS_CALCENVW;
						when IS_CALCENVW =>
							SLlevel<=TLval;
							INTST<=IS_CALCENV;
						when IS_CALCENV =>
							elevwr<='1';
							case FMSTATE is
							when FS_C1Oa =>
								envst_1a<=nenvst;
							when FS_C1Ob =>
								envst_1b<=nenvst;
							when FS_C1Oc =>
								envst_1c<=nenvst;
							when FS_C1Od =>
								envst_1d<=nenvst;
							when FS_C2Oa =>
								envst_2a<=nenvst;
							when FS_C2Ob =>
								envst_2b<=nenvst;
							when FS_C2Oc =>
								envst_2c<=nenvst;
							when FS_C2Od =>
								envst_2d<=nenvst;
							when FS_C3Oa =>
								envst_3a<=nenvst;
							when FS_C3Ob =>
								envst_3b<=nenvst;
							when FS_C3Oc =>
								envst_3c<=nenvst;
							when FS_C3Od =>
								envst_3d<=nenvst;
							when others =>
							end case;
							INTST<=IS_CALCTL;
						when IS_CALCTL =>
							case slot is
							when "00" =>
								toutxa<=toutc;
								case channel is
								when "00" =>
									fbsrc1<=toutc;
								when "01" =>
									fbsrc2<=toutc;
								when "10" =>
									fbsrc3<=toutc;
								when others =>
								end case;
							when "01" =>
								toutxb<=toutc;
							when "10" =>
								toutxc<=toutc;
							when "11" =>
								toutxd<=toutc;
							when others =>
							end case;
							case slot is
							when "11" =>
								INTST<=IS_CMIX;
							when others =>
								INTST<=IS_IDLE;
								intend<='1';
							end case;
						when IS_CMIX =>
							case Algo is
							when "000" | "001" | "010" | "011" =>
								coutc:= toutxd;
							when "100" =>
								coutc:=add24;
							when "101" | "110" =>
								coutc:=add234;
							when "111" =>
								coutc:=add1234;
							when others=>
							end case;
							case FMSTATE is
							when FS_C1Od =>
								if(senL='1')then
									Lcout1<=coutc;
								else
									Lcout1<=(others=>'0');
								end if;
								if(senR='1')then
									Rcout1<=coutc;
								else
									Rcout1<=(others=>'0');
								end if;
							when FS_C2Od =>
								if(senL='1')then
									Lcout2<=coutc;
								else
									Lcout2<=(others=>'0');
								end if;
								if(senR='1')then
									Rcout2<=coutc;
								else
									Rcout2<=(others=>'0');
								end if;
							when FS_C3Od =>
								if(senL='1')then
									Lcout3<=coutc;
								else
									Lcout3<=(others=>'0');
								end if;
								if(senR='1')then
									Rcout3<=coutc;
								else
									Rcout3<=(others=>'0');
								end if;
							when others =>
							end case;
							INTST<=IS_IDLE;
							intend<='1';
						when others =>
							INTST<=IS_IDLE;
						end case;
					end if;
				when FS_MIX =>
					fm_smixL<=Lcout123;
					fm_smixR<=Rcout123;
					intend<='1';
				when others =>
					INTST<=IS_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	addr13	:addsat generic map(16) port map(toutxa,toutxc,add13,open,open);
	addr23	:addsat generic map(16) port map(toutxb,toutxc,add23,open,open);
	addr24	:addsat generic map(16) port map(toutxb,toutxd,add24,open,open);
	addr234	:addsat generic map(16) port map(add23,toutxd,add234,open,open);
	addr1234	:addsat generic map(16) port map(add13,add24,add1234,open,open);
	
	Lcadd01	:addsat generic map(16) port map(x"0000",Lcout1,Lcout01,open,open);
	Lcadd23	:addsat generic map(16) port map(Lcout2,Lcout3,Lcout23,open,open);
	Ldadd123	:addsat	generic map(16) port map(Lcout01,Lcout23,Lcout123,open,open);
	Rcadd01	:addsat generic map(16) port map(x"0000",Rcout1,Rcout01,open,open);
	Rcadd23	:addsat generic map(16) port map(Rcout2,Rcout3,Rcout23,open,open);
	Rdadd123	:addsat	generic map(16) port map(Rcout01,Rcout23,Rcout123,open,open);
	
	SFnum<=	"000" & Fnum & "00"					when Blk="111" else
				"0000" & Fnum & '0' 					when Blk="110" else
				"00000" & Fnum(10 downto 0)		when Blk="101" else
				"000000" & Fnum(10 downto 1)		when Blk="100" else
				"0000000" & Fnum(10 downto 2)		when Blk="011" else
				"00000000" & Fnum(10 downto 3) 	when Blk="010" else
				"000000000" & Fnum(10 downto 4) 	when Blk="001" else
				"0000000000" & Fnum(10 downto 5);
	
	process(SFnum,Mult)
	variable SUM	:std_logic_vector(15 downto 0);
	begin
		if(Mult=x"0")then
			SUM:='0' & SFnum(15 downto 1);
		else
			SUM:=(others=>'0');
			if(Mult(0)='1')then
				SUM:=SUM+SFnum;
			end if;
			if(Mult(1)='1')then
				SUM:=SUM+(SFnum(14 downto 0) & '0');
			end if;
			if(Mult(2)='1')then
				SUM:=SUM+(SFnum(13 downto 0) & "00");
			end if;
			if(Mult(3)='1')then
				SUM:=SUM+(SFnum(12 downto 0) & "000");
			end if;
		end if;
		MSFnum<=SUM;
	end process;
	
	FBsrc<=	fbsrc1 when channel="00" else
				fbsrc2 when channel="01" else
				fbsrc3 when channel="10" else
				(others=>'0');
--	FBsrc<=	toutxa;
	
	addfbm<=(others=>FBsrc(15));
	addfb<=	addfbm(3 downto 0) & FBsrc(15 downto 4)		when FdBck="001" else
				addfbm(2 downto 0) & FBsrc(15 downto 3)		when FdBck="010" else
				addfbm(1 downto 0) & FBsrc(15 downto 2)		when FdBck="011" else
				addfbm(0) & FBsrc(15 downto 1)					when FdBck="100" else
				FBsrc														when FdBck="101" else
				FBsrc(14 downto 0) & '0'							when FdBck="110" else
				FBsrc(13 downto 0) & "00"							when FdBck="111" else
				(others=>'0');

	
	cenvst<=envst_1a	when FMSTATE=FS_C1Oa else
			envst_1b	when FMSTATE=FS_C1Ob else
			envst_1c	when FMSTATE=FS_C1Oc else
			envst_1d	when FMSTATE=FS_C1Od else
			envst_2a	when FMSTATE=FS_C2Oa else
			envst_2b	when FMSTATE=FS_C2Ob else
			envst_2c	when FMSTATE=FS_C2Oc else
			envst_2d	when FMSTATE=FS_C2Od else
			envst_3a	when FMSTATE=FS_C3Oa else
			envst_3b	when FMSTATE=FS_C3Ob else
			envst_3c	when FMSTATE=FS_C3Oc else
			envst_3d	when FMSTATE=FS_C3Od else
			es_OFF;
			
	keyc<=	key1(0)	when FMSTATE=FS_C1Oa else
			key1(1)	when FMSTATE=FS_C1Ob else
			key1(2)	when FMSTATE=FS_C1Oc else
			key1(3)	when FMSTATE=FS_C1Od else
			key2(0)	when FMSTATE=FS_C2Oa else
			key2(1)	when FMSTATE=FS_C2Ob else
			key2(2)	when FMSTATE=FS_C2Oc else
			key2(3)	when FMSTATE=FS_C2Od else
			key3(0)	when FMSTATE=FS_C3Oa else
			key3(1)	when FMSTATE=FS_C3Ob else
			key3(2)	when FMSTATE=FS_C3Oc else
			key3(3)	when FMSTATE=FS_C3Od else
			'0';
	
--	SLEV<=	x"ffff" when SL=x"0" else
--			x"b503" when SL=x"1" else
--			x"7fff" when SL=x"2" else
--			x"5a81" when SL=x"3" else
--			x"3fff" when SL=x"4" else
--			x"2d41" when SL=x"5" else
--			x"1fff" when SL=x"6" else
--			x"169f" when SL=x"7" else
--			x"0fff" when SL=x"8" else
--			x"0b4f" when SL=x"9" else
--			x"07ff" when SL=x"a" else
--			x"05a7" when SL=x"b" else
--			x"03ff" when SL=x"c" else
--			x"02d3" when SL=x"d" else
--			x"01ff" when SL=x"e" else
--			x"0001" when SL=x"f" else
--			x"0000";
			
	sint	:sintbl port map(thita,sinthita,clk);
	
	env	:envcont generic map(20) port map(
		KEY		=>keyc,
		AR		=>AR,
		DR		=>DR,
		SLlevel	=>SLlevel,
		RR		=>RR,
		SR		=>SR,
		
		CURSTATE	=>cenvst,
		NXTSTATE	=>nenvst,
		
		CURLEVEL	=>elevrd,
		NXTLEVEL	=>elevwd
	);
	
	TLC	:TLtbl port map(TL,clk,TLval);
	envm	:muls16xu16 port map(sinthita,TLlevel,envsin,clk);
	tlm	:muls16xu16 port map(envsin,elevwd(19 downto 4),toutc,clk);
	
	sndL<=fm_smixL;
	sndR<=fm_smixR;
	
end rtl;
	