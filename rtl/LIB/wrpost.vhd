-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Lets the CPU go on after a memory write while SDRAM still does it.
--A real FH writes main memory with no wait state at 4MHz and one at 8MHz.
--The SDRAM port sees a write only at the start of T2, too late for the slot
--of that clock, so the core waited one more state on every write.
--A write with POST='1' is latched here and handed to the port, and the CPU
--does not wait for it (MEMWAIT gives the 8MHz wait).
--Any request that comes while a posted write is in progress is held, with
--WAITo high, and handed to the port after it. WAITo stays high until the
--port has taken that request and finished it. A request handed over late is
--latched like a posted write and kept up until the port takes it, so a CPU
--reset in between does not change it.
--After a posted write or a request handed over late the port strobes are
--kept low for one clock, so the port sees the rise of the next request, even
--one that rises on the same clock the port finishes. The strobe of a request
--the port has already done is not passed on again.
--Other requests go straight through, as before.
entity WRPOST is
generic(
	AWIDTH	:integer	:=25
);
port(
	RD		:in std_logic;
	WR		:in std_logic;
	POST	:in std_logic;	-- this write may be posted
	ADR		:in std_logic_vector(AWIDTH-1 downto 0);
	WDAT	:in std_logic_vector(7 downto 0);
	WE		:in std_logic_vector(3 downto 0);
	WAITo	:out std_logic;

	oRD		:out std_logic;
	oWR		:out std_logic;
	oADR	:out std_logic_vector(AWIDTH-1 downto 0);
	oWDAT	:out std_logic_vector(7 downto 0);
	oWE		:out std_logic_vector(3 downto 0);
	WAITi	:in std_logic;	-- busy from the SDRAM port

	clk		:in std_logic;
	rstn	:in std_logic
);
end WRPOST;

architecture rtl of WRPOST is
type state_t is (S_IDLE,S_PREQ,S_PRUN,S_GAP,S_FREQ,S_FRUN);
signal	STATE	:state_t;
signal	lRD,lWR	:std_logic;
signal	held	:std_logic;	-- a request came while a posted write was in progress
signal	own		:std_logic;	-- the strobe now up is one the port has already taken
signal	newreq	:std_logic;
signal	padr	:std_logic_vector(AWIDTH-1 downto 0);
signal	pdat	:std_logic_vector(7 downto 0);
signal	pwe		:std_logic_vector(3 downto 0);
signal	posting	:std_logic;
signal	late	:std_logic;	-- S_FREQ or S_FRUN
signal	frd,fwr	:std_logic;	-- the request handed over late
begin
	newreq<=(RD and not lRD) or (WR and not lWR);
	posting<='1' when STATE=S_PREQ or STATE=S_PRUN else '0';
	late<='1' when STATE=S_FREQ or STATE=S_FRUN else '0';

	process(clk,rstn)begin
		if(rstn='0')then
			STATE<=S_IDLE;
			lRD<='0';
			lWR<='0';
			held<='0';
			own<='0';
			frd<='0';
			fwr<='0';
			padr<=(others=>'0');
			pdat<=(others=>'0');
			pwe<=(others=>'0');
		elsif(clk' event and clk='1')then
			lRD<=RD;
			lWR<=WR;
			if(RD='0' and WR='0')then
				own<='0';
			end if;
			case STATE is
			when S_IDLE =>
				if(WR='1' and lWR='0' and POST='1' and WAITi='0')then
					padr<=ADR;
					pdat<=WDAT;
					pwe<=WE;
					own<='1';
					STATE<=S_PREQ;
				end if;
			when S_PREQ =>
				if(newreq='1')then
					held<='1';
				end if;
				if(WAITi='1')then
					STATE<=S_PRUN;
				end if;
			when S_PRUN =>
				if(newreq='1')then
					held<='1';
				end if;
				if(WAITi='0')then
					STATE<=S_GAP;
				end if;
			when S_GAP =>
				held<='0';
				if(WR='1' and own='0' and POST='1')then
					padr<=ADR;
					pdat<=WDAT;
					pwe<=WE;
					own<='1';
					STATE<=S_PREQ;
				elsif((RD='1' or WR='1') and own='0')then
					padr<=ADR;
					pdat<=WDAT;
					pwe<=WE;
					frd<=RD;
					fwr<=WR;
					own<='1';
					STATE<=S_FREQ;
				else
					STATE<=S_IDLE;
				end if;
			when S_FREQ =>
				if(WAITi='1')then
					STATE<=S_FRUN;
				end if;
			when S_FRUN =>
				if(WAITi='0')then
					STATE<=S_GAP;
				end if;
			end case;
		end if;
	end process;

	oRD<=	'0' when posting='1' or STATE=S_GAP else
			frd when late='1' else
			RD and not own;
	oWR<=	'1' when posting='1' else
			'0' when STATE=S_GAP else
			fwr when late='1' else
			WR and not own;
	oADR<=	padr when posting='1' or late='1' else ADR;
	oWDAT<=	pdat when posting='1' or late='1' else WDAT;
	oWE<=	pwe when posting='1' or late='1' else WE;

	WAITo<=	'1' when posting='1' and (held='1' or newreq='1') else
			'0' when posting='1' else
			'1' when STATE=S_GAP and (RD='1' or WR='1') and own='0' else
			'0' when STATE=S_GAP else
			'1' when STATE=S_FREQ or STATE=S_FRUN else
			WAITi;

end rtl;
