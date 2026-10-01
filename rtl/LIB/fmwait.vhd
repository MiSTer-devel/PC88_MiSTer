-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Adds one wait state to an IN or OUT while SEL is high. T80a_ce samples
--WAIT_n on ce_f and only honors it in T2. With IOWait=1 the first ce_f
--sample that sees the access is in the extended T1, so WAIT_n is pulled low
--for the second one only. Holding it low longer would also stall the strobe
--release in T3. The count follows the access itself, not SEL or en, so a
--change of either in the middle of an access cannot move the wait into T3.
entity FMWAIT is
port(
	SEL		:in std_logic;
	IORQn	:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end FMWAIT;

architecture rtl of FMWAIT is
signal	acc		:std_logic;	-- an IN or OUT, whatever the port
signal	count	:integer range 0 to 2;
begin
	acc<='1' when IORQn='0' and (RDn='0' or WRn='0') else '0';

	process(clk,rstn)begin
		if(rstn='0')then
			count<=0;
		elsif(clk' event and clk='1')then
			if(acc='0')then
				count<=0;
			elsif(ce_f='1' and count<2)then
				count<=count+1;
			end if;
		end if;
	end process;

	WAITn<='0' when acc='1' and count=1 and SEL='1' and en='1' else '1';

end rtl;
