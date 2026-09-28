-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--A CPU port to devices on another clock, for accesses that must not slow the
--CPU down. The CPU side runs on cclk (not on the CPU's clock enable).
--
--An access is taken on the first cclk that sees it: read or write, address
--and write data go into registers that are held until the handshake is over,
--and the request goes up one cclk later. The held address and data are meant
--to be used directly on the device side; they are stable for at least one
--cclk before the request and until the answer has come back.
--
--The device side sees the request through two registers. f_sel is high for
--the fclk that ends on the clock where the request is first seen. On that
--clock f_rdat is taken and the answer goes up, so a read answers one fclk
--after the request arrives. The answer goes down when the request has gone
--down and f_busy is low; f_busy lets a device keep the port busy while it is
--still using the held address or data.
--
--The CPU waits (waitn) on its own read until the answer arrives, and on any
--access that starts while the previous handshake is still going. It never
--waits on its own write. The data taken on the device side reaches rdat on
--the cclk where the answer is first seen.
--
--The held registers cross without synchronisers. They must reach the device
--side within one fclk, and f_rdat's register must reach rdat within two cclk.
--
--crstn and frstn must be released on cclk and fclk.
entity cdc_busport is
generic(
	AW		:integer	:=8;
	DW		:integer	:=8
);
port(
	acc_rd	:in std_logic;	--the CPU is reading this port (strobe low)
	acc_wr	:in std_logic;	--the CPU is writing this port (strobe low)
	adr		:in std_logic_vector(AW-1 downto 0);
	wdat	:in std_logic_vector(DW-1 downto 0);
	rdat	:out std_logic_vector(DW-1 downto 0);
	waitn	:out std_logic;

	cadr	:out std_logic_vector(AW-1 downto 0);	--held address, for the device side
	cwdat	:out std_logic_vector(DW-1 downto 0);	--held write data, for the device side
	crd		:out std_logic;							--held: the access is a read

	cclk	:in std_logic;
	crstn	:in std_logic;

	f_sel	:out std_logic;
	f_rdat	:in std_logic_vector(DW-1 downto 0);
	f_busy	:in std_logic := '0';

	fclk	:in std_logic;
	frstn	:in std_logic
);
end cdc_busport;

architecture rtl of cdc_busport is
component cdc_sync2
port(
	d		:in std_logic;
	q		:out std_logic;

	clk		:in std_logic
);
end component;

signal	acc				:std_logic;
signal	taken,pend,req	:std_logic;
signal	hrd				:std_logic;
signal	hadr			:std_logic_vector(AW-1 downto 0);
signal	hwd				:std_logic_vector(DW-1 downto 0);
signal	ack_s,ack_l		:std_logic;
signal	arise,rdy		:std_logic;
signal	busy			:std_logic;
signal	rdatb			:std_logic_vector(DW-1 downto 0);

signal	req_s,req_d		:std_logic;
signal	ack				:std_logic;
signal	rhold			:std_logic_vector(DW-1 downto 0);

begin
	acc<=acc_rd or acc_wr;
	busy<=pend or req or ack_s;

	--CPU side: take an access once, when the port is free.
	process(cclk,crstn)begin
		if(crstn='0')then
			taken<='0';
			pend<='0';
			req<='0';
		elsif(cclk' event and cclk='1')then
			pend<='0';
			if(acc='0')then
				taken<='0';
			elsif(taken='0' and busy='0')then
				taken<='1';
				pend<='1';
			end if;
			if(pend='1')then
				req<='1';
			elsif(ack_s='1')then
				req<='0';
			end if;
		end if;
	end process;

	process(cclk)begin
		if(cclk' event and cclk='1')then
			if(acc='1' and taken='0' and busy='0')then
				hrd<=acc_rd;
				hadr<=adr;
				hwd<=wdat;
			end if;
		end if;
	end process;

	cadr<=hadr;
	cwdat<=hwd;
	crd<=hrd;

	acks	:cdc_sync2 port map(ack,ack_s,cclk);

	process(cclk,crstn)begin
		if(crstn='0')then
			ack_l<='0';
			rdy<='0';
		elsif(cclk' event and cclk='1')then
			ack_l<=ack_s;
			if(acc_rd='0')then
				rdy<='0';
			elsif(arise='1' and taken='1')then
				rdy<='1';
			end if;
		end if;
	end process;

	arise<=ack_s and not ack_l;

	process(cclk)begin
		if(cclk' event and cclk='1')then
			if(arise='1')then
				rdatb<=rhold;
			end if;
		end if;
	end process;

	rdat<=rdatb;

	--Wait on an own read until the answer, and on any access that has not
	--been taken yet because the previous handshake is still going.
	waitn<=	'0' when acc_rd='1' and taken='1' and rdy='0' and arise='0' else
			'0' when acc='1' and taken='0' and busy='1' else
			'1';

	--Device side.
	reqs	:cdc_sync2 port map(req,req_s,fclk);

	process(fclk,frstn)begin
		if(frstn='0')then
			req_d<='0';
			ack<='0';
		elsif(fclk' event and fclk='1')then
			req_d<=req_s;
			if(req_s='1' and req_d='0')then
				ack<='1';
			elsif(req_s='0' and f_busy='0')then
				ack<='0';
			end if;
		end if;
	end process;

	process(fclk)begin
		if(fclk' event and fclk='1')then
			if(req_s='1' and req_d='0')then
				rhold<=f_rdat;
			end if;
		end if;
	end process;

	f_sel<=req_s and not req_d;

end rtl;
