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
	rstn	:in std_logic
);
end TDMAREGS;

architecture MAIN of TDMAREGS is
signal	TH_Ln	:std_logic;
signal	LH_Ln	:std_logic;
signal	IOWRn	:std_logic;
signal	lWRn	:std_logic;
begin
	IOWRn<=IORQn or WRn;
	process(clk,rstn)begin
		if(rstn='0')then
			TH_Ln<='0';
			LH_Ln<='0';
			TRAMTOP<=(others=>'0');
			TRAMLEN<=(others=>'0');
			TDMAEN<='0';
		elsif(clk' event and clk='1')then
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
	end process;
end MAIN;

