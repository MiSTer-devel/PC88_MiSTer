-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

--A copy of the key rows on the main CPU's clock, so that reading ports 00h to
--0Eh never waits.
--
--On fclk the rows are sent over one at a time, 0 to 14 and round again, each
--as the value it had on one fclk (cdc_hs). On cclk each row is written to its
--place in the copy as it arrives, and the CPU reads the copy. A key change is
--seen by the CPU one round later at most, about 9us.
--
--Sending starts once KBMAP has cleared the rows after reset (INITDONE). Until
--then the copy holds the cleared values, set again by crstn.
entity kbmirror is
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	RDn		:in std_logic;
	DAT		:out std_logic_vector(7 downto 0);
	OE		:out std_logic;

	cclk	:in std_logic;
	crstn	:in std_logic;	--released on cclk

	SCANADR	:out std_logic_vector(3 downto 0);
	SCANDAT	:in std_logic_vector(7 downto 0);
	INITDONE:in std_logic;

	fclk	:in std_logic;
	frstn	:in std_logic	--released on fclk
);
end kbmirror;

architecture rtl of kbmirror is
component cdc_hs
generic(
	AW		:integer	:=1;
	BW		:integer	:=1
);
port(
	a_start	:in std_logic;
	a_data	:in std_logic_vector(AW-1 downto 0);
	a_busy	:out std_logic;
	a_done	:out std_logic;
	a_rdata	:out std_logic_vector(BW-1 downto 0);
	a_clk	:in std_logic;
	a_rstn	:in std_logic;

	b_valid	:out std_logic;
	b_data	:out std_logic_vector(AW-1 downto 0);
	b_rdata	:in std_logic_vector(BW-1 downto 0);
	b_clk	:in std_logic;
	b_rstn	:in std_logic
);
end component;

type MIR_T is array(0 to 15) of std_logic_vector(7 downto 0);
constant MIR_CLR	:MIR_T	:=(14=>"01111111",others=>(others=>'1'));

signal	srow	:std_logic_vector(3 downto 0);
signal	sdata	:std_logic_vector(11 downto 0);
signal	sdone	:std_logic;
signal	mvalid	:std_logic;
signal	mdata	:std_logic_vector(11 downto 0);
signal	MIR		:MIR_T	:=MIR_CLR;

begin
	--fclk side
	process(fclk,frstn)begin
		if(frstn='0')then
			srow<=(others=>'0');
		elsif(fclk' event and fclk='1')then
			if(sdone='1')then
				if(srow=x"e")then
					srow<=(others=>'0');
				else
					srow<=srow+1;
				end if;
			end if;
		end if;
	end process;

	SCANADR<=srow;
	sdata<=srow & SCANDAT;

	rows	:cdc_hs generic map(12,1) port map(
		a_start	=>INITDONE,
		a_data	=>sdata,
		a_busy	=>open,
		a_done	=>sdone,
		a_rdata	=>open,
		a_clk	=>fclk,
		a_rstn	=>frstn,

		b_valid	=>mvalid,
		b_data	=>mdata,
		b_rdata	=>"0",
		b_clk	=>cclk,
		b_rstn	=>crstn
	);

	--cclk side
	process(cclk,crstn)begin
		if(crstn='0')then
			MIR<=MIR_CLR;
		elsif(cclk' event and cclk='1')then
			if(mvalid='1' and mdata(11 downto 8)/=x"f")then
				MIR(conv_integer(mdata(11 downto 8)))<=mdata(7 downto 0);
			end if;
		end if;
	end process;

	DAT<=MIR(conv_integer(ADR(3 downto 0)));

	OE<=	'0' when IORQn='1' or RDn='1' else
			'0' when ADR(7 downto 4)/=x"0" else
			'0' when ADR=x"0f" else
			'1';

end rtl;
