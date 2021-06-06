LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CALCOPNAADPCM is
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
end CALCOPNAADPCM;

architecture rtl of CALCOPNAADPCM is
signal	PCMDAT:std_logic_vector(3 downto 0);
signal	Xn		:std_logic_vector(16 downto 0);
signal	Delta	:std_logic_vector(14 downto 0);
signal	f		:std_logic_vector(7 downto 0);
signal	LPLUS	:std_logic_vector(3 downto 0);
signal	X2		:std_logic_vector(19 downto 0);
signal	Delta2	:std_logic_vector(23 downto 0);
signal	X2begin	:std_logic;
signal	X2done	:std_logic;
signal	Xdelta	:std_logic_vector(16 downto 0);
signal	lXdelta	:std_logic_vector(16 downto 0);
signal	D2begin	:std_logic;
signal	D2done	:std_logic;
signal	INTbegin	:std_logic;
signal	INTdone	:std_logic;
signal	XINT		:std_logic_vector(16 downto 0);
signal	XINTw		:std_logic_vector(17+intwidth downto 0);
signal	SIG		:std_logic;
signal	lSIG		:std_logic;
signal	CARRYb	:std_logic;

type state_t is (
	st_IDLE,
	st_X2,
	st_INT,
	st_Delta2
);
signal	state	:state_t;

--component MULTI
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

component susmult
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

begin

	f<=	x"99"	when PCMDAT(2 downto 0)="111" else
		x"80"	when PCMDAT(2 downto 0)="110" else
		x"66"	when PCMDAT(2 downto 0)="101" else
		x"4d"	when PCMDAT(2 downto 0)="100" else
		x"39";
		
	LPLUS<=PCMDAT(2 downto 0)&'1';

--	X2mul	:multi generic map(16,4)port map('0' & Delta,LPLUS,X2begin,X2,X2done,clk,rstn);
--	D2mul	:multi generic map(16,8)port map('0' & Delta,f,D2begin,Delta2,D2done,clk,rstn);
--	INTmul:multi generic map(18,intwidth) port map('0' & Xdelta,INTDAT,INTbegin,XINTw,INTdone,clk,rstn);
	X2mul	:susmult generic map(16,4)port map('0'&Delta,LPLUS,X2,clk);
	D2mul	:susmult generic map(16,8)port map('0'&Delta,f,Delta2,clk);
	INTmul:susmult generic map(18,intwidth) port map('0'&Xdelta,INTDAT,XINTw,clk);
	process(clk,rstn)begin
		if(rstn='0')then
			X2done<='0';
			D2done<='0';
			INTdone<='0';
		elsif(clk' event and clk='1')then
			X2done<=X2begin;
			D2done<=D2begin;
			INTdone<=INTbegin;
		end if;
	end process;

	XINT<=XINTw(16+intwidth downto intwidth);
	
	process(clk,rstn)
	variable Xntmp	:std_logic_vector(17 downto 0);
	variable INITpend	:std_logic;
	begin
		if(rstn='0')then
			Xn<=(others=>'0');
			Delta<="000000001111111";
			state<=st_IDLE;
			X2begin<='0';
			D2begin<='0';
			INITPEND:='0';
			INTbegin<='0';
			Xdelta<=(others=>'0');
			lXdelta<=(others=>'0');
			OUTDAT<=(others=>'0');
			CARRYb<='0';
			SIG<='0';
			lSIG<='0';
		elsif(clk' event and clk='1')then
			X2begin<='0';
			D2begin<='0';
			INTbegin<='0';
			if(INIT='1')then
				INITPEND:='1';
			end if;
			case state is
			when st_IDLE =>
				if(INITPEND='1')then
					INITPEND:='0';
					Xn<=(others=>'0');
					Delta<="000000001111111";
					Xdelta<=(others=>'0');
					lSIG<='0';
					state<=st_IDLE;
				elsif(WR='1')then
					CARRYb<=CARRY;
					if(CARRY='1')then
						lXdelta<=Xdelta;
						PCMDAT<=INDAT;
						state<=st_X2;
						X2begin<='1';
					else
						state<=st_INT;
						INTbegin<='1';
					end if;
				end if;
			when st_X2 =>
				if(X2done='1')then
					Xdelta<=X2(18 downto 2);
					state<=st_Delta2;
					D2begin<='1';
					lSIG<=SIG;
					SIG<=PCMDAT(3);
				end if;
			when st_Delta2 =>
				if(D2done='1')then
					if(   Delta2<"000000000010000000000000")then
						Delta<="000000001111111";
					elsif(Delta2>"000110000000000000000000")then
						Delta<="110000000000000";
					else
						Delta<=Delta2(20 downto 6);
					end if;
					INTbegin<='1';
					state<=st_INT;
				end if;
			when st_INT =>
				if(INTdone='1')then
					Xntmp:=Xn(16) & Xn;
					if(CARRY='1')then
						if(lSIG='0')then
							Xntmp:=Xntmp+lXdelta;
						else
							Xntmp:=Xntmp-lXdelta;
						end if;
						if(Xntmp(17)/=Xntmp(16))then
							Xntmp(16):=Xntmp(17);
							Xntmp(15 downto 0):=(others=>not Xntmp(17));
						end if;
						Xn<=Xntmp(16 downto 0);
					end if;
					if(SIG='0')then
						Xntmp:=Xntmp+XINT;
					else
						Xntmp:=Xntmp-XINT;
					end if;
					if(Xntmp(17)/=Xntmp(16))then
						Xntmp(16):=Xntmp(17);
						Xntmp(15 downto 0):=(others=>not Xntmp(17));
					end if;
					OUTDAT<=Xntmp(16 downto 1);
					state<=st_IDLE;
				end if;
			when others =>
				state<=st_IDLE;
			end case;
		end if;
	end process;
	BUSY<=	'1' when WR='1' else
			'0' when state=st_IDLE else
			'1';
end rtl;
