-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;

--Decides on clk21m when the RAM is filled (RAMFILL on rclk) and when the CPUs may
--leave reset, from the RAM type in the OSD (OSDTYPE, on clk21m: hps_io runs on
--clk_sys, the same clock).
--
--The fill command carries the RAM type through cdc_hs (start/busy/done here, the
--value held there until the transfer ends). It is sent when the boot ROM download
--is over (LDONE), and again only while the CPUs are in reset (CPURSTN='0') and the
--OSD type differs from the type of the last fill: a reset after the type was
--changed is taken as a power on. A changed type without a reset does nothing.
--
--The fill is taken as done only after the command was acknowledged and then
--FILLDONE (crossed with cdc_sync2) was seen low and high again, so it does not rest
--on which of the two crossings arrives first. A fill takes 16 ms or more, so the
--low level is not missed.
--
--RELOK is high while the fill is done and the OSD type is the type of the fill;
--the CPU reset is released on it (and held released until the next reset, by the
--caller). OSD value "11" is not a type and counts as the type of the last fill.
--
--No reset: the state is kept over the OSD reset and a PLL relock, as RAMFILL keeps
--its own. A command lost to a PLL relock (cdc_hs is reset by it) is sent again.
entity RAMTYPECTL is
port(
	OSDTYPE	:in std_logic_vector(1 downto 0);
	LDONE	:in std_logic;	-- boot ROM download over
	CPURSTN	:in std_logic;	-- CPU reset (clk21m)
	FILLDONE	:in std_logic;	-- RAMFILL done, crossed to clk21m

	START	:out std_logic;	-- cdc_hs a_start
	CTYPE	:out std_logic_vector(1 downto 0);	-- cdc_hs a_data
	BUSY	:in std_logic;	-- cdc_hs a_busy
	ACKD	:in std_logic;	-- cdc_hs a_done

	RELOK	:out std_logic;

	clk		:in std_logic
);
end RAMTYPECTL;

architecture rtl of RAMTYPECTL is
type state_t is (C_IDLE,C_SEND,C_ACK,C_LOW,C_HIGH,C_OK);
signal	state	:state_t := C_IDLE;
signal	ltype	:std_logic_vector(1 downto 0) := "00";
signal	tsel	:std_logic_vector(1 downto 0);
signal	start_i	:std_logic := '0';

begin
	tsel<=ltype when OSDTYPE="11" else OSDTYPE;

	process(clk)begin
		if(clk' event and clk='1')then
			case state is
			when C_IDLE =>
				if(LDONE='1')then
					ltype<=tsel;
					start_i<='1';
					state<=C_SEND;
				end if;
			when C_SEND =>
				--a_start is held until a_busy rises.
				if(BUSY='1')then
					start_i<='0';
					state<=C_ACK;
				end if;
			when C_ACK =>
				if(ACKD='1')then
					state<=C_LOW;
				elsif(BUSY='0')then
					--The transfer was lost to a PLL relock (cdc_hs reset): send it again.
					start_i<='1';
					state<=C_SEND;
				end if;
			when C_LOW =>
				if(FILLDONE='0')then
					state<=C_HIGH;
				end if;
			when C_HIGH =>
				if(FILLDONE='1')then
					state<=C_OK;
				end if;
			when C_OK =>
				if(CPURSTN='0' and tsel/=ltype and BUSY='0')then
					ltype<=tsel;
					start_i<='1';
					state<=C_SEND;
				end if;
			when others =>
				state<=C_IDLE;
			end case;
		end if;
	end process;

	START<=start_i;
	CTYPE<=ltype;
	--Not registered: the release (caller) and a new command (C_OK above) are decided
	--on the same clock from the same values, so they never both happen.
	RELOK<='1' when state=C_OK and tsel=ltype else '0';

end rtl;
