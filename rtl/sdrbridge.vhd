-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Passes the SDRAM accesses of a clk21m client (FDemu or FECcont) to the
--SDRAM controller on rclk, one at a time, with a two-phase handshake.
--The address, data and kind are registered here, REQ changes on the next
--clock, and they are held until ACK (brought to clk through a synchronizer)
--follows REQ. Read data is taken on that clock and held until the next read.
--WAIT is made on clk, so the client sees it at once: it is high while an
--access is in flight, and while RD/WR is high and the access it asked
--for has not ended yet.
--ADRREAD: also read whenever ADR changes while WR is low (FDemu reads
--without a request).
entity sdrbridge is
generic(
	AWIDTH	:integer	:=25;
	ADRREAD	:boolean	:=false
);
port(
	ADR		:in std_logic_vector(AWIDTH-1 downto 0);
	RD		:in std_logic;
	WR		:in std_logic;
	WDAT	:in std_logic_vector(15 downto 0);
	RDAT	:out std_logic_vector(15 downto 0);
	WAITo	:out std_logic;

	REQ		:out std_logic;
	REQADR	:out std_logic_vector(AWIDTH-1 downto 0);
	REQWR	:out std_logic;
	REQWDAT	:out std_logic_vector(15 downto 0);
	ACK		:in std_logic;
	ACKRDAT	:in std_logic_vector(15 downto 0);

	clk		:in std_logic;
	rstn	:in std_logic
);
end sdrbridge;

architecture rtl of sdrbridge is
signal	REQb	:std_logic;
signal	BUSY	:std_logic;
signal	PEND	:std_logic;
signal	DONE	:std_logic;
signal	BYREQ	:std_logic;
signal	ADRb	:std_logic_vector(AWIDTH-1 downto 0);
signal	LADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	WRb		:std_logic;
signal	WDATb	:std_logic_vector(15 downto 0);
signal	RDATb	:std_logic_vector(15 downto 0);
signal	REQL	:std_logic;
begin
	REQL<=RD or WR;

	process(clk,rstn)begin
		if(rstn='0')then
			REQb<='0';
			BUSY<='0';
			PEND<='0';
			DONE<='0';
			BYREQ<='0';
			ADRb<=(others=>'0');
			LADR<=(others=>'0');
			WRb<='0';
			WDATb<=(others=>'0');
			RDATb<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(PEND='1')then
				REQb<=not REQb;
				PEND<='0';
			elsif(BUSY='1')then
				if(ACK=REQb)then
					BUSY<='0';
					if(WRb='0')then
						RDATb<=ACKRDAT;
					end if;
					DONE<=BYREQ;
				end if;
			elsif(REQL='1' and DONE='0')then
				ADRb<=ADR;
				LADR<=ADR;
				WRb<=WR;
				WDATb<=WDAT;
				BYREQ<='1';
				PEND<='1';
				BUSY<='1';
			elsif(ADRREAD and WR='0' and ADR/=LADR)then
				ADRb<=ADR;
				LADR<=ADR;
				WRb<='0';
				BYREQ<='0';
				PEND<='1';
				BUSY<='1';
			end if;
			if(REQL='0')then
				DONE<='0';
			end if;
		end if;
	end process;

	WAITo<='1' when BUSY='1' else
			'1' when REQL='1' and DONE='0' else
			'0';

	REQ<=REQb;
	REQADR<=ADRb;
	REQWR<=WRb;
	REQWDAT<=WDATb;
	RDAT<=RDATb;

end rtl;
