-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Four-phase handshake between two clock domains, carrying a value each way.
--
--Side A starts a transfer with a one-clock a_start while a_busy is low. a_data
--is copied into a register there and held until the transfer ends; the request
--goes up on the next clock. Side B sees the request two to three clocks later,
--takes that value to b_data and pulses b_valid. One clock after b_valid it
--takes b_rdata, and it answers on the clock after that. Side A sees the answer
--two to three clocks later, takes the value to a_rdata and pulses a_done.
--a_busy stays high until the request and the answer have both gone low again,
--so every a_start gives one b_valid and one a_done.
--
--The values cross without synchronisers. Each one is set a clock before the
--request or answer that announces it, and held until that has been seen, so
--the condition is that it reaches the other side within two of that side's
--clocks plus one clock of the sending side.
--
--a_start may also be held until a_busy rises; it is ignored while a_busy is
--high.
--
--a_rstn and b_rstn must be released on a_clk and b_clk.
entity cdc_hs is
generic(
	AW		:integer	:=1;	--width of the value from A to B
	BW		:integer	:=1		--width of the value from B to A
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
end cdc_hs;

architecture rtl of cdc_hs is
component cdc_sync2
port(
	d		:in std_logic;
	q		:out std_logic;

	clk		:in std_logic
);
end component;

signal	req,ack		:std_logic;
signal	apend		:std_logic;
signal	bget2		:std_logic;
signal	req_s,ack_s	:std_logic;
signal	req_l,ack_l	:std_logic;
signal	bget		:std_logic;
signal	a_hold		:std_logic_vector(AW-1 downto 0);
signal	b_hold		:std_logic_vector(BW-1 downto 0);
signal	a_rdatab	:std_logic_vector(BW-1 downto 0);
signal	b_datab		:std_logic_vector(AW-1 downto 0);
signal	a_doneb		:std_logic;
signal	b_validb	:std_logic;

begin
	reqs	:cdc_sync2 port map(req,req_s,b_clk);
	acks	:cdc_sync2 port map(ack,ack_s,a_clk);

	--Side A
	process(a_clk,a_rstn)begin
		if(a_rstn='0')then
			req<='0';
			apend<='0';
			ack_l<='0';
			a_doneb<='0';
		elsif(a_clk' event and a_clk='1')then
			ack_l<=ack_s;
			a_doneb<='0';
			apend<='0';
			if(req='0' and ack_s='0' and apend='0' and a_start='1')then
				apend<='1';
			end if;
			if(apend='1')then
				req<='1';
			end if;
			if(req='1' and ack_s='1' and ack_l='0')then
				a_doneb<='1';
				req<='0';
			end if;
		end if;
	end process;

	process(a_clk)begin
		if(a_clk' event and a_clk='1')then
			if(req='0' and ack_s='0' and apend='0' and a_start='1')then
				a_hold<=a_data;
			end if;
			if(req='1' and ack_s='1' and ack_l='0')then
				a_rdatab<=b_hold;
			end if;
		end if;
	end process;

	a_busy<=req or ack_s or apend;
	a_done<=a_doneb;
	a_rdata<=a_rdatab;

	--Side B
	process(b_clk,b_rstn)begin
		if(b_rstn='0')then
			ack<='0';
			req_l<='0';
			bget<='0';
			bget2<='0';
			b_validb<='0';
		elsif(b_clk' event and b_clk='1')then
			req_l<=req_s;
			b_validb<='0';
			bget<='0';
			bget2<=bget;
			if(req_s='1' and req_l='0')then
				b_validb<='1';
				bget<='1';
			end if;
			if(bget2='1')then
				ack<='1';
			elsif(req_s='0')then
				ack<='0';
			end if;
		end if;
	end process;

	process(b_clk)begin
		if(b_clk' event and b_clk='1')then
			if(req_s='1' and req_l='0')then
				b_datab<=a_hold;
			end if;
			if(bget='1')then
				b_hold<=b_rdata;
			end if;
		end if;
	end process;

	b_valid<=b_validb;
	b_data<=b_datab;

end rtl;
