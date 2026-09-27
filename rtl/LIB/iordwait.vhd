-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Adds one wait state to an IN from port PORT. T80a_ce samples WAIT_n on
--ce_f and only honours it in T2. With IOWait=1 the first ce_f sample that
--sees the decode is in the extended T1, so WAIT_n is pulled low for the
--second one only. Holding it low longer would also stall the strobe release
--in T3. The count follows the IN itself, not en, so turning en on in the
--middle of an IN cannot move the wait into T3.
entity IORDWAIT is
generic(
	PORT_NO	:std_logic_vector(7 downto 0)
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	RDn		:in std_logic;
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end IORDWAIT;

architecture rtl of IORDWAIT is
signal	sel		:std_logic;	-- IN from PORT_NO, whatever en is
signal	count	:integer range 0 to 2;
begin
	sel<='1' when IORQn='0' and RDn='0' and ADR=PORT_NO else '0';

	process(clk,rstn)begin
		if(rstn='0')then
			count<=0;
		elsif(clk' event and clk='1')then
			if(sel='0')then
				count<=0;
			elsif(ce_f='1' and count<2)then
				count<=count+1;
			end if;
		end if;
	end process;

	WAITn<='0' when sel='1' and count=1 and en='1' else '1';

end rtl;
