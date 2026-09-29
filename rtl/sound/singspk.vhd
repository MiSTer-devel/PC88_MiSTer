-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later
-- Speaker output of port 40h: bit 7 (the direct speaker bit used by CMD SING)
-- ORed with the 2400 Hz beep enabled by bit 5.
-- The speaker is AC coupled, so the line goes through a first-order high-pass
-- filter: a held level decays to 0 and a 50% square wave swings +-0x4000.
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity singspk is
generic(
	DIVBITS	:integer	:=9;	-- filter step every 2**DIVBITS clocks (39 kHz at 20 MHz)
	TCBITS	:integer	:=10	-- time constant 2**TCBITS steps (26 ms at 20 MHz)
);
port(
	sing	:in std_logic;
	beepen	:in std_logic;
	beep	:in std_logic;
	sndout	:out std_logic_vector(15 downto 0);

	clk		:in std_logic;
	rstn	:in std_logic
);
end singspk;

architecture rtl of singspk is
component cdc_sync2
port(
	d		:in std_logic;
	q		:out std_logic;

	clk		:in std_logic
);
end component;

constant LEVEL	:integer	:=16#7fff#;
signal	sing_s	:std_logic;
signal	beepen_s:std_logic;
signal	spk		:std_logic;
signal	div		:unsigned(DIVBITS-1 downto 0);
signal	lp		:signed(16+TCBITS downto 0);	-- low-pass state, TCBITS fraction bits
signal	x		:signed(16+TCBITS downto 0);
begin
	sings	:cdc_sync2 port map(sing,sing_s,clk);
	beepens	:cdc_sync2 port map(beepen,beepen_s,clk);

	spk<=sing_s or (beepen_s and beep);
	x<=shift_left(to_signed(LEVEL,17+TCBITS),TCBITS) when spk='1' else (others=>'0');

	process(clk,rstn)begin
		if(rstn='0')then
			div<=(others=>'0');
			lp<=(others=>'0');
		elsif(clk' event and clk='1')then
			div<=div+1;
			if(div=0)then
				lp<=lp+shift_right(x-lp,TCBITS);
			end if;
		end if;
	end process;

	sndout<=std_logic_vector(resize(shift_right(x-lp,TCBITS),16));
end rtl;
