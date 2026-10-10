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
	ce_r	:in std_logic;		-- the cycles where the old CPU clock rose / fell
	ce_f	:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic;
	rstnc	:in std_logic		-- reset for the cpuclk side, released on cpuclk
);
end INTCONTS;

architecture MAIN of INTCONTS is
signal	lINTbn	:std_logic_vector(7 downto 0);
signal	INTbn	:std_logic_vector(7 downto 0);
signal	INTcn	:std_logic_vector(7 downto 0);
signal	INTln	:std_logic_vector(7 downto 0);
-- signal	INTmn	:std_logic_vector(7 downto 0);
-- signal	VECoe	:std_logic;
-- signal	lM1n	:std_logic;
signal	INTing	:integer range 0 to 4;
signal	SEND	:std_logic;
signal	INTmsk	:std_logic_vector(7 downto 0);
signal	INTlmsk	:std_logic_vector(7 downto 0);
signal	INTlev	:std_logic_vector(3 downto 0);
signal	IOWRn	:std_logic;
signal	lIOWRn	:std_logic_vector(1 downto 0);
signal	M1nb	:std_logic;
-- signal	RDnb	:std_logic;
signal	M1nc	:std_logic;
-- signal	VECOEc	:std_logic;
signal	INTRQ	:std_logic_vector(7 downto 0);
signal	INTRQm	:std_logic_vector(7 downto 0);
signal	INTCLR	:std_logic;
signal	INTCLRN	:integer range 0 to 7;
signal	INTdisCLR	:std_logic;		-- INT DIS FF clear req
signal	LEVwr	:std_logic;		-- a widening write to CNTADR waits for the strobe to end
signal	LEVdat	:std_logic_vector(3 downto 0);
signal	LEVin	:std_logic;		-- inside a write to CNTADR
signal	LEVimm	:std_logic;		-- that write narrows the level: apply it at once

function levmask(lev :std_logic_vector(3 downto 0)) return std_logic_vector is
begin
	case lev is
	when x"7" => return "01111111";
	when x"6" => return "00111111";
	when x"5" => return "00011111";
	when x"4" => return "00001111";
	when x"3" => return "00000111";
	when x"2" => return "00000011";
	when x"1" => return "00000001";
	when x"0" => return "00000000";
	when others => return "11111111";
	end case;
end levmask;

begin

	INTlmsk<=levmask(INTlev);

	process(clk,rstn)begin
		if(rstn='0')then
			INTbn<=(others=>'1');
			M1nb<='1';
			-- RDnb<='1';
		elsif(clk' event and clk='1')then
			INTbn<=INT7n & INT6n & INT5n & INT4n & INT3n & INT2n & INT1n & INT0n ;
			M1nb<=M1n;
			-- RDnb<=RDn;
		end if;
	end process;

		process(clk,rstn)begin
		if(rstn='0')then
			INTRQ<=(others=>'0');
		elsif(clk' event and clk='1')then
			for i in 0 to 7 loop
				if(INTbn(i)='0' and lINTbn(i)='1')then
					INTRQ(i)<='1';
				elsif(INTCLRN=i and INTCLR='1')then
					INTRQ(i)<='0';
				end if;
			end loop;
			lINTbn<=INTbn;
		end if;
	end process;
	
	-- INTmn<=INTbn or (not INTmsk);

	IOWRn<=IORQn or WRn;
	
	process(cpuclk,rstnc)
	variable imm	:std_logic;
	begin
		if(rstnc='0')then
			INTmsk<=(others=>'1');
			INTlev<=(others=>'0');
			INTdisCLR<='0';
			LEVwr<='0';
			LEVdat<=(others=>'0');
			LEVin<='0';
			LEVimm<='0';
		elsif(cpuclk' event and cpuclk='1')then
		 if(ce_r='1')then
			INTdisCLR<='0';
			-- A write that narrows the level takes effect during the write. Any
			-- other write takes effect when the write ends, as on a real
			-- PC-8801: an interrupt it lets through is taken one instruction
			-- after the OUT, not at its end.
			if(IOWRn='1')then
				LEVin<='0';
				if(LEVwr='1')then
					INTlev<=LEVdat;
					INTdisCLR<='1';
					LEVwr<='0';
				end if;
			end if;
			if(IOWRn='0')then
				case ADR is
				when CNTADR =>
					LEVin<='1';
					imm:=LEVimm;
					if(LEVin='0')then
						if((levmask(DATIN(3 downto 0)) and not INTlmsk)=x"00" and levmask(DATIN(3 downto 0))/=INTlmsk)then
							imm:='1';
						else
							imm:='0';
						end if;
						LEVimm<=imm;
					end if;
					if(imm='1')then
						INTlev<=DATIN(3 downto 0);
						INTdisCLR<='1';
					else
						LEVdat<=DATIN(3 downto 0);
						LEVwr<='1';
					end if;
				when MSKADR =>
					INTmsk(0)<=DATIN(2);
					INTmsk(1)<=DATIN(1);
					INTmsk(2)<=DATIN(0);
				when others =>
				end case;
			end if;
		 end if;
		end if;
	end process;
	
	INTRQm<=INTRQ and INTlmsk and INTmsk;
	
	process(clk,rstn)
	variable INTen	:std_logic;
	variable INTx	:integer range 0 to 7;
	begin
		if(rstn='0')then
			-- VECoe<='0';
			-- lM1n<='1';
			INTn<='1';
			INTing<=0;
			DATOUT<=(others=>'1');
			INTCLRN<=0;
			INTCLR<='0';
			SEND<='0';
		elsif(clk' event and clk='1')then
			-- INTCLR<='0';
			if(INTing/=3)then
				INTCLR<='0';
				INTen:='0';
				if(INTing/=4)then
					for i in 7 downto 0 loop
						if(INTRQm(i)='1')then
							INTen:='1';
							INTx:=i;
						end if;
					end loop;
				end if;
				if(INTen='0')then
					if(INTdisCLR='1')then
						INTing<=0;
					end if;
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
					INTCLRN<=INTx;
					-- VECOE<='1';
					if(M1nb='0')then
						INTing<=3;
					end if;
				when 3 =>
					if(M1nb='1' and M1nc='1')then
						if(SEND='0')then
							INTing<=1;
						elsif(IORQn='1')then -- Holds DATOUT until sampled by CPU
							INTn<='1';
							INTing<=4;
							-- VECOE<='0';
							-- INTCLRN<=INTx;
							INTCLR<='1';
							SEND<='0';
						end if;
					elsif(IORQn='0')then
						SEND<='1';
					end if;
				when others=>
				end case;
			end if;
		end if;
	end process;
	
	process(cpuclk,rstnc)begin
		if(rstnc='0')then
			M1nc<='1';
			-- VECOEc<='0';
		elsif(cpuclk' event and cpuclk='1')then
		 if(ce_f='1')then
			M1nc<=M1n;
			-- VECOEc<=VECOE;
		 end if;
		end if;
	end process;
	
	DATOE<=	'1' when (M1nc='0' or M1n='0')  and IORQn='0' and RDn='1' else
			'1' when RFRSHn='0' else
			'0';
--	DATOE<='1' when VECOEc='1' and M1nc='0' and RDn='1' and NOTREAD='0' else '0';
--	DATOE<='1' when VECOEc='1' and M1nc='0' and RDn='1' else '0';
--	DATOE<='1' when M1nc='0' and RDn='1' else '0';
		
end MAIN;
						
				
				