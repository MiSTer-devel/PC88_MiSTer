-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Passes the SDRAM accesses of a clk21m client (FDemu, FECcont or the
--ADPCM-B RAM port) to the SDRAM controller on rclk, one at a time, with a
--two-phase handshake.
--The address, data and kind are registered here, REQ changes on the next
--clock, and they are held until ACK (brought to clk through a synchronizer)
--follows REQ. Read data is taken on that clock and held until the next read.
--WAIT is made on clk, so the client sees it at once: it is high while an
--access is in flight, and while RD or WR is high and the access that line
--asked for has not ended yet. RD and WR are two requests: a line raised
--while the other is still held after its access ended starts a new access.
--If the line falls while its access is in flight (the client gave up on
--it), that access does not count as done for the line raised again later.
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
signal	DONER	:std_logic;
signal	DONEW	:std_logic;
signal	BYREQ	:std_logic;
signal	ADRb	:std_logic_vector(AWIDTH-1 downto 0);
signal	LADR	:std_logic_vector(AWIDTH-1 downto 0);
signal	WRb		:std_logic;
signal	WDATb	:std_logic_vector(15 downto 0);
signal	RDATb	:std_logic_vector(15 downto 0);
signal	NEWRD	:std_logic;
signal	NEWWR	:std_logic;
begin
	NEWRD<=RD and not DONER;
	NEWWR<=WR and not DONEW;

	process(clk,rstn)begin
		if(rstn='0')then
			REQb<='0';
			BUSY<='0';
			PEND<='0';
			DONER<='0';
			DONEW<='0';
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
					if(WRb='1')then
						DONEW<=BYREQ;
					else
						DONER<=BYREQ;
					end if;
				end if;
			elsif(NEWRD='1' or NEWWR='1')then
				ADRb<=ADR;
				LADR<=ADR;
				WRb<=NEWWR;
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
			if(BUSY='1' and ((WRb='1' and WR='0') or (WRb='0' and RD='0')))then
				BYREQ<='0';
			end if;
			if(RD='0')then
				DONER<='0';
			end if;
			if(WR='0')then
				DONEW<='0';
			end if;
		end if;
	end process;

	WAITo<=BUSY or NEWRD or NEWWR;

	REQ<=REQb;
	REQADR<=ADRb;
	REQWR<=WRb;
	REQWDAT<=WDATb;
	RDAT<=RDATb;

end rtl;
