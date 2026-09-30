-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Adds one wait state to every opcode fetch (M1 with MREQ).
--WAITn is low for one ce_f sample, the first one in the fetch where no other
--wait holds the CPU, so this wait adds to an SDRAM wait.
entity M1WAIT is
port(
	M1n		:in std_logic;
	MREQn	:in std_logic;
	OTHERWAIT	:in std_logic;	-- '1' while any other wait holds the CPU
	en		:in std_logic;

	WAITn	:out std_logic;

	clk		:in std_logic;
	ce_f	:in std_logic;
	rstn	:in std_logic
);
end M1WAIT;

architecture rtl of M1WAIT is
signal	sel		:std_logic;	-- opcode fetch, whatever en is
signal	done	:std_logic;	-- the wait has been taken in this fetch
begin
	sel<='1' when M1n='0' and MREQn='0' else '0';

	process(clk,rstn)begin
		if(rstn='0')then
			done<='0';
		elsif(clk' event and clk='1')then
			if(sel='0')then
				done<='0';
			elsif(ce_f='1' and OTHERWAIT='0')then
				done<='1';
			end if;
		end if;
	end process;

	WAITn<='0' when sel='1' and done='0' and OTHERWAIT='0' and en='1' else '1';

end rtl;
