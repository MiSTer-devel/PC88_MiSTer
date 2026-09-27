-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;

--The sub CPU's port to the FDC when the FDC runs on its own clock (FDCs with
--oneclk). The CPU side runs on cclk with the clock enable ce (the CPU's CE_R).
--
--An access to the FDC is taken on the first ce that sees it: read or write, A0
--and the write data go into registers that are held until the next access,
--and the request goes up one cclk later. The FDC side copies those registers
--when the synchronised request rises and drives the FDC's bus from the copy.
--For a read it then takes the FDC's data and answers, and the CPU waits
--(WAITn) until the answer has brought the data over.
--
--The events that set the FDC interrupt come over a handshake and set INTn on
--the CPU side. As in FDCs, INTn is cleared at the end of an access to the data
--register, and a set on the same ce wins. TC goes the other way.
entity fdcport is
port(
	CSn		:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	A0		:in std_logic;
	WDAT	:in std_logic_vector(7 downto 0);
	RDAT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;
	WAITn	:out std_logic;
	INTn	:out std_logic;
	TC		:in std_logic;

	cclk	:in std_logic;
	ce		:in std_logic;
	crstn	:in std_logic;	--released on cclk

	fCSn	:out std_logic;
	fRDn	:out std_logic;
	fWRn	:out std_logic;
	fA0		:out std_logic;
	fWDAT	:out std_logic_vector(7 downto 0);
	fRDAT	:in std_logic_vector(7 downto 0);
	fTC		:out std_logic;
	fINTEV	:in std_logic;

	fclk	:in std_logic;
	frstn	:in std_logic	--released on fclk
);
end fdcport;

architecture rtl of fdcport is
component cdc_sync2
port(
	d		:in std_logic;
	q		:out std_logic;

	clk		:in std_logic
);
end component;

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

signal	acc_rd,acc_wr	:std_logic;
signal	lvl,req			:std_logic;
signal	hrd,ha0			:std_logic;
signal	hwd				:std_logic_vector(7 downto 0);
signal	dend			:std_logic;
signal	req_s,req_d,req_dd	:std_logic;
signal	crd,ca0			:std_logic;
signal	cwd				:std_logic_vector(7 downto 0);
signal	rget			:std_logic;
signal	rhold			:std_logic_vector(7 downto 0);
signal	ack,ack_s,ack_l	:std_logic;
signal	rdy				:std_logic;
signal	rdatb			:std_logic_vector(7 downto 0);
signal	ipend,ibusy		:std_logic;
signal	iev,iset,intb	:std_logic;
signal	tcl,tcpend,tcbusy	:std_logic;

begin
	acc_rd<='1' when CSn='0' and RDn='0' else '0';
	acc_wr<='1' when CSn='0' and WRn='0' else '0';

	--CPU side: take the access on ce and raise the request a cclk later.
	process(cclk,crstn)begin
		if(crstn='0')then
			lvl<='0';
			req<='0';
		elsif(cclk' event and cclk='1')then
			if(ce='1')then
				lvl<=acc_rd or acc_wr;
			end if;
			req<=lvl;
		end if;
	end process;

	process(cclk)begin
		if(cclk' event and cclk='1')then
			if(ce='1' and lvl='0' and (acc_rd='1' or acc_wr='1'))then
				hrd<=acc_rd;
				ha0<=A0;
				hwd<=WDAT;
			end if;
		end if;
	end process;

	--End of an access to the data register, seen on this ce.
	dend<='1' when lvl='1' and acc_rd='0' and acc_wr='0' and ha0='1' else '0';

	--FDC side: copy the access when the request is seen, then drive the bus.
	reqs	:cdc_sync2 port map(req,req_s,fclk);

	process(fclk,frstn)begin
		if(frstn='0')then
			req_d<='0';
			req_dd<='0';
			rget<='0';
			ack<='0';
		elsif(fclk' event and fclk='1')then
			req_d<=req_s;
			req_dd<=req_d;
			rget<='0';
			if(req_d='1' and req_dd='0' and crd='1')then
				rget<='1';
			end if;
			if(rget='1')then
				ack<='1';
			elsif(req_s='0')then
				ack<='0';
			end if;
		end if;
	end process;

	process(fclk)begin
		if(fclk' event and fclk='1')then
			if(req_s='1' and req_d='0')then
				crd<=hrd;
				ca0<=ha0;
				cwd<=hwd;
			end if;
			if(req_d='1' and req_dd='0' and crd='1')then
				rhold<=fRDAT;
			end if;
		end if;
	end process;

	fCSn<=not req_d;
	fRDn<=not(req_d and crd);
	fWRn<=not(req_d and not crd);
	fA0<=ca0;
	fWDAT<=cwd;

	--CPU side: the read data arrives with the answer.
	acks	:cdc_sync2 port map(ack,ack_s,cclk);

	process(cclk,crstn)begin
		if(crstn='0')then
			ack_l<='0';
			rdy<='0';
		elsif(cclk' event and cclk='1')then
			ack_l<=ack_s;
			if(acc_rd='0')then
				rdy<='0';
			elsif(ack_s='1' and ack_l='0')then
				rdy<='1';
			end if;
		end if;
	end process;

	process(cclk)begin
		if(cclk' event and cclk='1')then
			if(ack_s='1' and ack_l='0')then
				rdatb<=rhold;
			end if;
		end if;
	end process;

	RDAT<=rdatb;
	DATOE<=acc_rd;
	WAITn<='0' when acc_rd='1' and rdy='0' else '1';

	--Interrupt events: keep one pending while the handshake is busy.
	process(fclk,frstn)begin
		if(frstn='0')then
			ipend<='0';
		elsif(fclk' event and fclk='1')then
			if(ipend='1' and ibusy='0')then
				ipend<=fINTEV;
			elsif(fINTEV='1')then
				ipend<='1';
			end if;
		end if;
	end process;

	ints	:cdc_hs generic map(1,1) port map(
		a_start	=>ipend,
		a_data	=>"0",
		a_busy	=>ibusy,
		a_done	=>open,
		a_rdata	=>open,
		a_clk	=>fclk,
		a_rstn	=>frstn,

		b_valid	=>iev,
		b_data	=>open,
		b_rdata	=>"0",
		b_clk	=>cclk,
		b_rstn	=>crstn
	);

	process(cclk,crstn)begin
		if(crstn='0')then
			intb<='0';
			iset<='0';
		elsif(cclk' event and cclk='1')then
			if(ce='1')then
				if(iset='1' or iev='1')then
					intb<='1';
				elsif(dend='1')then
					intb<='0';
				end if;
				iset<='0';
			elsif(iev='1')then
				iset<='1';
			end if;
		end if;
	end process;

	INTn<=not intb;

	--TC: one handshake per rising edge, kept pending while the handshake is busy.
	process(cclk,crstn)begin
		if(crstn='0')then
			tcl<='0';
			tcpend<='0';
		elsif(cclk' event and cclk='1')then
			tcl<=TC;
			if(tcpend='1' and tcbusy='0')then
				tcpend<=TC and not tcl;
			elsif(TC='1' and tcl='0')then
				tcpend<='1';
			end if;
		end if;
	end process;

	tcs	:cdc_hs generic map(1,1) port map(
		a_start	=>tcpend,
		a_data	=>"0",
		a_busy	=>tcbusy,
		a_done	=>open,
		a_rdata	=>open,
		a_clk	=>cclk,
		a_rstn	=>crstn,

		b_valid	=>fTC,
		b_data	=>open,
		b_rdata	=>"0",
		b_clk	=>fclk,
		b_rstn	=>frstn
	);

end rtl;
