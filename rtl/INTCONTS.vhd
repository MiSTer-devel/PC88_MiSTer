LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity INTCONTS	is
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
end INTCONTS;

architecture MAIN of INTCONTS is
signal	lINTbn	:std_logic_vector(7 downto 0);
signal	INTbn	:std_logic_vector(7 downto 0);
signal	INTcn	:std_logic_vector(7 downto 0);
signal	INTln	:std_logic_vector(7 downto 0);
signal	INTmn	:std_logic_vector(7 downto 0);
signal	VECoe	:std_logic;
signal	lM1n	:std_logic;
signal	INTing	:integer range 0 to 3;
signal	SEND	:std_logic;
signal	INTmsk	:std_logic_vector(7 downto 0);
signal	INTlmsk	:std_logic_vector(7 downto 0);
signal	INTlev	:std_logic_vector(3 downto 0);
signal	IOWRn	:std_logic;
signal	lIOWRn	:std_logic_vector(1 downto 0);
signal	M1nb	:std_logic;
signal	RDnb	:std_logic;
signal	M1nc	:std_logic;
signal	VECOEc	:std_logic;
signal	INTRQ	:std_logic_vector(7 downto 0);
signal	INTRQm	:std_logic_vector(7 downto 0);
signal	INTCLR	:std_logic;
signal	INTCLRN	:integer range 0 to 7;

begin

	INTlmsk<=	
				"01111111" when INTlev=x"7" else
				"00111111" when INTlev=x"6" else
				"00011111" when INTlev=x"5" else
				"00001111" when INTlev=x"4" else
				"00000111" when INTlev=x"3" else
				"00000011" when INTlev=x"2" else
				"00000001" when INTlev=x"1" else
				"00000000" when INTlev=x"0" else
				"11111111";

	process(clk,rstn)begin
		if(rstn='0')then
			INTbn<=(others=>'1');
			M1nb<='1';
			RDnb<='1';
		elsif(clk' event and clk='1')then
			INTbn<=INT7n & INT6n & INT5n & INT4n & INT3n & INT2n & INT1n & INT0n ;
			M1nb<=M1n;
			RDnb<=RDn;
		end if;
	end process;

		process(clk,rstn)begin
		if(rstn='0')then
			INTRQ<=(others=>'0');
		elsif(clk' event and clk='1')then
			for i in 0 to 7 loop
				if(INTbn(i)='0' and lINTbn(i)='1')then
					INTRQ(i)<='1';
				elsif(INTbn(i)='1')then
					INTRQ(i)<='0';
				elsif(INTCLRN=i and INTCLR='1')then
					INTRQ(i)<='0';
				end if;
			end loop;
			lINTbn<=INTbn;
		end if;
	end process;
	
	INTmn<=INTbn or (not INTmsk);

	IOWRn<=IORQn or WRn;
	
	process(cpuclk,rstn)begin
		if(rstn='0')then
			INTmsk<=(others=>'1');
			INTlev<=(others=>'0');
		elsif(cpuclk' event and cpuclk='1')then
			if(IOWRn='0')then
				case ADR is
				when CNTADR =>
					INTlev<=DATIN(3 downto 0);
				when MSKADR =>
					INTmsk(0)<=DATIN(2);
					INTmsk(1)<=DATIN(1);
					INTmsk(2)<=DATIN(0);
				when others =>
				end case;
			end if;
		end if;
	end process;
	
	INTRQm<=INTRQ and INTlmsk and INTmsk;
	
	process(clk,rstn)
	variable INTen	:std_logic;
	variable INTx	:integer range 0 to 7;
	begin
		if(rstn='0')then
			VECoe<='0';
			lM1n<='1';
			INTn<='1';
			INTing<=0;
			DATOUT<=(others=>'1');
			INTCLRN<=0;
			INTCLR<='0';
			SEND<='0';
		elsif(clk' event and clk='1')then
			INTCLR<='0';
			if(INTing/=3)then
				INTen:='0';
				for i in 7 downto 0 loop
					if(INTRQm(i)='1')then
						INTen:='1';
						INTx:=i;
					end if;
				end loop;
				if(INTen='0')then
					INTing<=0;
					INTn<='1';
				elsif(INTing=0)then
					INTing<=1;
				end if;
			end if;
			if(INTen='1')then
				case INTing is
				when 1 =>
					if(M1nb='1')then
						INTing<=2;
					end if;
				when 2 =>
					INTn<='0';
					SEND<='0';
					DATOUT(7 downto 4)<=x"0";
					DATOUT(3 downto 1)<=conv_std_logic_vector(INTx,3);
					DATOUT(0)<='0';
					VECOE<='1';
					if(M1nb='0')then
						INTing<=3;
					end if;
				when 3 =>
					if(M1nb='1' and M1nc='1')then
						if(SEND='1')then
							INTn<='1';
							INTing<=0;
							VECOE<='0';
							INTCLRN<=INTx;
							INTCLR<='1';
							SEND<='0';
						else
							INTing<=1;
						end if;
					elsif(IORQn='0')then
						SEND<='1';
					end if;
				when others=>
				end case;
			end if;
		end if;
	end process;
	
	process(cpuclk,rstn)begin
		if(rstn='0')then
			M1nc<='1';
			VECOEc<='0';
		elsif(cpuclk' event and cpuclk='0')then
			M1nc<=M1n;
			VECOEc<=VECOE;
		end if;
	end process;
	
	DATOE<=	'1' when (M1nc='0' or M1n='0')  and IORQn='0' and RDn='1' else
			'1' when RFRSHn='0' else
			'0';
--	DATOE<='1' when VECOEc='1' and M1nc='0' and RDn='1' and NOTREAD='0' else '0';
--	DATOE<='1' when VECOEc='1' and M1nc='0' and RDn='1' else '0';
--	DATOE<='1' when M1nc='0' and RDn='1' else '0';
		
end MAIN;
						
				
				