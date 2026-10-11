library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity TDMAREGS	is
generic(
	ADRTOP	:in std_logic_vector(7 downto 0)	:=x"64";
	ADRLEN	:in std_logic_vector(7 downto 0)	:=x"65";
	ADRCMD	:in std_logic_vector(7 downto 0)	:=x"68"
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	WRn		:in std_logic;
	DAT		:in std_logic_vector(7 downto 0);
	
	TRAMTOP	:out std_logic_vector(15 downto 0);
	TRAMLEN	:out std_logic_vector(15 downto 0);
	TDMAEN	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1';

	-- Read back of the channel registers at ADRCMD-8 to ADRCMD-1 (60h-67h)
	RDn		:in std_logic := '1';
	RDAT	:out std_logic_vector(7 downto 0);
	ROE		:out std_logic
);
end TDMAREGS;

architecture MAIN of TDMAREGS is
signal	TH_Ln	:std_logic;
signal	LH_Ln	:std_logic;
signal	IOWRn	:std_logic;
signal	lWRn	:std_logic;
-- The 8257 holds the address and count of four channels and returns them on a read.
-- One first/last flip-flop is shared by all of them: each read or write of a channel
-- register flips it, and a write to the mode register clears it.
-- A read gives the value that was written, not the address as the transfer moves it.
type	chregs_t is array(0 to 7) of std_logic_vector(15 downto 0);
signal	CHREG	:chregs_t;
signal	FL		:std_logic;
signal	CHSEL	:std_logic;
signal	CHNO	:integer range 0 to 7;
signal	IORDn	:std_logic;
signal	lRDn	:std_logic;
signal	RDCH	:std_logic;
begin
	IOWRn<=IORQn or WRn;
	IORDn<=IORQn or RDn;
	CHSEL<='1' when ADR(7 downto 4)=ADRCMD(7 downto 4) and ADR(3)='0' else '0';
	CHNO<=conv_integer(unsigned(ADR(2 downto 0)));
	RDAT<=CHREG(CHNO)(7 downto 0) when FL='0' else CHREG(CHNO)(15 downto 8);
	ROE<='1' when IORDn='0' and CHSEL='1' else '0';

	process(clk,rstn)begin
		if(rstn='0')then
			CHREG<=(others=>(others=>'0'));
			FL<='0';
			RDCH<='0';
			lRDn<='1';
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(IOWRn='0' and lWRn='1')then
				if(ADR=ADRCMD)then
					FL<='0';
				elsif(CHSEL='1')then
					if(FL='0')then
						CHREG(CHNO)(7 downto 0)<=DAT;
					else
						CHREG(CHNO)(15 downto 8)<=DAT;
					end if;
					FL<=not FL;
				end if;
			end if;
			-- Flip at the end of the read, so the byte stays put while the CPU takes it
			if(IORDn='0')then
				RDCH<=CHSEL;
			elsif(lRDn='0' and RDCH='1')then
				FL<=not FL;
				RDCH<='0';
			end if;
			lRDn<=IORDn;
		 end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			TH_Ln<='0';
			LH_Ln<='0';
			TRAMTOP<=(others=>'0');
			TRAMLEN<=(others=>'0');
			TDMAEN<='0';
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(IOWRn='0' and lWRn='1')then
				if(ADR=ADRCMD)then
					TH_Ln<='0';
					LH_Ln<='0';
					TDMAEN<=DAT(2);
				elsif(ADR=ADRTOP)then
					if(TH_Ln='0')then
						TRAMTOP(7 downto 0)<=DAT;
						TH_Ln<='1';
					else
						TRAMTOP(15 downto 8)<=DAT;
						TH_Ln<='0';
					end if;
				elsif(ADR=ADRLEN)then
					if(LH_Ln='0')then
						TRAMLEN(7 downto 0)<=DAT;
						LH_Ln<='1';
					else
						TRAMLEN(15 downto 8)<=DAT;
						LH_Ln<='0';
					end if;
				end if;
			end if;
			lWRn<=IOWRn;
		 end if;
		end if;
	end process;
end MAIN;

