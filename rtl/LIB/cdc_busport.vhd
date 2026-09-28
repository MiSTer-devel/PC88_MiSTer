-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--A CPU port to devices on another clock. The CPU side runs on cclk.
--
--An access is taken once: read or write, address and write data go into
--registers that are held while the access is being served, and the request
--goes up one cclk later. The device side sees the request through two
--registers, takes f_rdat on the fclk where f_sel is high and answers. The CPU
--waits (waitn) on its own read until the answer has brought the data over to
--rdat. It never waits on its own write.
--
--The generics choose the form:
--
--CAPT_CE: the access is taken on the first ce that sees it. Otherwise ce is
--not used and the access is taken on the first cclk that sees it.
--
--FAST: the device side uses the held registers directly (f_adr, f_wdat and
--f_rd). f_sel is high for the fclk that ends on the clock where the request
--is first seen; f_rdat is taken and the answer goes up on that clock, and the
--CPU stops waiting on the cclk where the answer is first seen. Otherwise the
--device side copies the held registers on the clock where it first sees the
--request and drives f_adr, f_wdat and f_rd from the copy. f_act is high from
--the next fclk while the request is up, f_sel is its first fclk, the answer
--goes up one fclk after f_sel, and the CPU stops waiting one cclk after it
--sees the answer.
--
--BUSYWAIT: writes are answered too, and the request goes down when the answer
--is seen. The answer goes down when the request has gone down and f_busy is
--low; f_busy lets a device keep the port busy while it still uses the held
--address or data. An access that starts before this handshake is over waits
--until it can be taken. Otherwise only reads are answered and the request
--follows the access: it goes down one cclk after the access has ended (on ce
--with CAPT_CE), and the answer goes down when the request does.
--Without BUSYWAIT the next access can be taken as soon as the previous one
--has ended, so the held registers stay until the device side has seen the
--request only if every access lasts longer than the request takes to cross
--(two fclk, plus one cclk).
--
--The held registers must reach the device side (the copy, or with FAST the
--first registers that use them) within one fclk, and f_rdat's register must
--reach rdat within two cclk.
--
--crstn and frstn must be released on cclk and fclk.
entity cdc_busport is
generic(
	AW		:integer	:=8;
	DW		:integer	:=8;
	CAPT_CE	:boolean	:=false;
	FAST	:boolean	:=true;
	BUSYWAIT:boolean	:=true
);
port(
	acc_rd	:in std_logic;	--the CPU is reading this port (strobe low)
	acc_wr	:in std_logic;	--the CPU is writing this port (strobe low)
	adr		:in std_logic_vector(AW-1 downto 0);
	wdat	:in std_logic_vector(DW-1 downto 0);
	rdat	:out std_logic_vector(DW-1 downto 0);
	waitn	:out std_logic;
	taken	:out std_logic;							--the access has been taken
	hadr	:out std_logic_vector(AW-1 downto 0);	--held address

	cclk	:in std_logic;
	ce		:in std_logic	:='1';
	crstn	:in std_logic;

	f_adr	:out std_logic_vector(AW-1 downto 0);
	f_wdat	:out std_logic_vector(DW-1 downto 0);
	f_rd	:out std_logic;							--the access is a read
	f_act	:out std_logic;
	f_sel	:out std_logic;
	f_rdat	:in std_logic_vector(DW-1 downto 0);
	f_busy	:in std_logic	:='0';

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

function b2s(b :boolean) return std_logic is
begin
	if(b)then
		return '1';
	end if;
	return '0';
end b2s;

constant	WRACK		:std_logic	:=b2s(BUSYWAIT);

signal	acc,cen,take	:std_logic;
signal	tkn,pend,req	:std_logic;
signal	hrd				:std_logic;
signal	hadrb			:std_logic_vector(AW-1 downto 0);
signal	hwd				:std_logic_vector(DW-1 downto 0);
signal	ack_s,ack_l		:std_logic;
signal	arise,rdy		:std_logic;
signal	busy			:std_logic;
signal	rdatb			:std_logic_vector(DW-1 downto 0);

signal	req_s,req_d,req_dd	:std_logic;
signal	sel,aset,rget	:std_logic;
signal	ack				:std_logic;
signal	crd				:std_logic;
signal	cadr			:std_logic_vector(AW-1 downto 0);
signal	cwd				:std_logic_vector(DW-1 downto 0);
signal	drd				:std_logic;
signal	rhold			:std_logic_vector(DW-1 downto 0);

begin
	acc<=acc_rd or acc_wr;
	cen<=ce when CAPT_CE else '1';
	busy<=(pend or req or ack_s) when BUSYWAIT else '0';
	take<=cen and acc and not tkn and not busy;

	--CPU side: take an access once, when the port is free.
	process(cclk,crstn)begin
		if(crstn='0')then
			tkn<='0';
			pend<='0';
			req<='0';
		elsif(cclk' event and cclk='1')then
			pend<=take;
			if(cen='1')then
				if(acc='0')then
					tkn<='0';
				elsif(busy='0')then
					tkn<='1';
				end if;
			end if;
			if(not BUSYWAIT)then
				req<=tkn;
			elsif(pend='1')then
				req<='1';
			elsif(ack_s='1')then
				req<='0';
			end if;
		end if;
	end process;

	process(cclk)begin
		if(cclk' event and cclk='1')then
			if(take='1')then
				hrd<=acc_rd;
				hadrb<=adr;
				hwd<=wdat;
			end if;
		end if;
	end process;

	taken<=tkn;
	hadr<=hadrb;

	acks	:cdc_sync2 port map(ack,ack_s,cclk);

	process(cclk,crstn)begin
		if(crstn='0')then
			ack_l<='0';
			rdy<='0';
		elsif(cclk' event and cclk='1')then
			ack_l<=ack_s;
			if(acc_rd='0')then
				rdy<='0';
			elsif(arise='1' and (tkn='1' or not FAST))then
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
	waitn<=	'0' when FAST and acc_rd='1' and tkn='1' and rdy='0' and arise='0' else
			'0' when not FAST and acc_rd='1' and rdy='0' else
			'0' when acc='1' and tkn='0' and busy='1' else
			'1';

	--Device side.
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
			rget<=sel and (drd or WRACK);
			if(aset='1')then
				ack<='1';
			elsif(req_s='0' and f_busy='0')then
				ack<='0';
			end if;
		end if;
	end process;

	process(fclk)begin
		if(fclk' event and fclk='1')then
			if(req_s='1' and req_d='0')then
				crd<=hrd;
				cadr<=hadrb;
				cwd<=hwd;
			end if;
			if(sel='1' and drd='1')then
				rhold<=f_rdat;
			end if;
		end if;
	end process;

	fast_g	:if FAST generate
		sel<=req_s and not req_d;
		aset<=sel and (drd or WRACK);
		drd<=hrd;
		f_adr<=hadrb;
		f_wdat<=hwd;
		f_act<=req_s;
	end generate;

	copy_g	:if not FAST generate
		sel<=req_d and not req_dd;
		aset<=rget;
		drd<=crd;
		f_adr<=cadr;
		f_wdat<=cwd;
		f_act<=req_d;
	end generate;

	f_rd<=drd;
	f_sel<=sel;

end rtl;
