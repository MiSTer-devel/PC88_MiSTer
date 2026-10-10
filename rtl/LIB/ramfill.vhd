-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--Fills main RAM once after the core is loaded, as a real FH has it at power on.
--SDRAM keeps its contents over a core reload, so without this the main RAM of
--the previous run was still there. A real FH keeps main RAM over its reset
--button and loses it only at power off: the OSD reset does not come here.
--The FH value repeats every 8 bytes: 00 00 FF FF FF FF 00 00.
--
--S_WAIT: wait until the boot ROM download is over. The top sets LOADER_DONE only
--        after the last loader write is acknowledged, so the port is free then.
--S_FILL: write 0000h-FFFFh one byte at a time through the CLR port.
--        0000h-BFFFh are at ADDR_BACKRAM+address. C000h-FFFFh share the graphic
--        VRAM words (memorymaps.vhd): the upper byte of the second word at
--        ADDR_GVRAM+address(13:0)*2, written alone with VRAMWE "1000".
--S_DONE: nothing more. No reset leaves it, so a PLL relock after the fill does
--        not fill again. A relock during the fill starts over from 0000h.
--
--A write is held until RAM_WAIT has gone high and low again: the SDRAM port
--takes a write only on a rise of its strobe and raises its wait some clocks
--later. The strobe is then kept low for one clock before the next write.
entity RAMFILL is
port(
	LDONE	:in std_logic;	-- boot ROM download over (on clk)
	RAM_WAIT	:in std_logic;

	ADR		:out std_logic_vector(18 downto 0);
	WDAT	:out std_logic_vector(7 downto 0);
	WR		:out std_logic;
	OE		:out std_logic;
	DONE	:out std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
);
end RAMFILL;

architecture rtl of RAMFILL is
type state_t is (S_WAIT,S_FILL,S_DONE);
--No asynchronous reset: whether a reset goes back to S_WAIT depends on the state.
signal	state	:state_t := S_WAIT;
signal	fadr		:unsigned(15 downto 0) := (others=>'0');
signal	wr_i	:std_logic := '0';
signal	seen	:std_logic := '0';
signal	doner	:std_logic := '0';

begin
	process(clk)begin
		if(clk' event and clk='1')then
			if(rstn='0')then
				if(state/=S_DONE)then
					state<=S_WAIT;
				end if;
				wr_i<='0';
				seen<='0';
			else
				case state is
				when S_WAIT =>
					if(LDONE='1' and RAM_WAIT='0')then
						state<=S_FILL;
						fadr<=(others=>'0');
						wr_i<='1';
						seen<='0';
					end if;
				when S_FILL =>
					if(wr_i='1')then
						if(RAM_WAIT='1')then
							seen<='1';
						elsif(seen='1')then
							wr_i<='0';
							seen<='0';
							if(fadr=x"FFFF")then
								state<=S_DONE;
							else
								fadr<=fadr+1;
							end if;
						end if;
					else
						wr_i<='1';
					end if;
				when others =>
				end case;
			end if;
			--Registered before it crosses to clk21m. Made from the state on every clock,
			--so it does not rest on the power-up level of a register that is only set.
			if(state=S_DONE)then
				doner<='1';
			else
				doner<='0';
			end if;
		end if;
	end process;

	OE<='1' when state=S_FILL else '0';
	WR<=wr_i when state=S_FILL else '0';
	ADR<=	"0100" & std_logic_vector(fadr(13 downto 0)) & '0' when fadr(15 downto 14)="11" else
			"000" & std_logic_vector(fadr);
	WDAT<=	x"FF" when fadr(2 downto 1)="01" or fadr(2 downto 1)="10" else x"00";
	DONE<=doner;

end rtl;
