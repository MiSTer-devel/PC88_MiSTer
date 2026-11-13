-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--Receives a real FH/MA keyboard on the user port (SNAC).
--The keyboard sends a row when it changes, at 20800 bps: a start bit, the
--row number (4 bits) and the row's keys (8 bits, 0 = pressed), LSB first,
--then even parity and a stop bit. Like the computer, parity and stop are
--not checked. The rows are kept here and read as KBMAP's rows are; all keys
--are released while the option is off.
entity snackbd is
generic(
	SYSCLK	:integer	:=18973	--kHz
);
port(
	EN		:in std_logic;
	RXD		:in std_logic;

	SCANADR	:in std_logic_vector(3 downto 0);
	SCANDAT	:out std_logic_vector(7 downto 0);

	clk		:in std_logic;
	rstn	:in std_logic
);
end snackbd;

architecture rtl of snackbd is
constant BITCYC	:integer	:=SYSCLK*1000/20800;
constant FLTCYC	:integer	:=15;

type ROW_T is array(0 to 15) of std_logic_vector(7 downto 0);
signal	rows	:ROW_T;

signal	en_s	:std_logic;
signal	rx_s	:std_logic_vector(1 downto 0);
signal	rx		:std_logic;
signal	fcnt	:integer range 0 to FLTCYC;

type ST_T is (ST_IDLE,ST_START,ST_DATA,ST_STOP);
signal	st		:ST_T;
signal	bcnt	:integer range 0 to BITCYC;
signal	nbit	:integer range 0 to 13;
signal	sr		:std_logic_vector(12 downto 0);

begin
	--The line, taken when it has stayed the same for FLTCYC clocks.
	process(clk,rstn)begin
		if(rstn='0')then
			en_s<='0';
			rx_s<=(others=>'1');
			rx<='1';
			fcnt<=0;
		elsif(clk' event and clk='1')then
			en_s<=EN;
			rx_s<=rx_s(0) & RXD;
			if(rx_s(1)=rx)then
				fcnt<=0;
			elsif(fcnt=FLTCYC)then
				rx<=rx_s(1);
				fcnt<=0;
			else
				fcnt<=fcnt+1;
			end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			rows<=(others=>(others=>'1'));
			st<=ST_IDLE;
			bcnt<=0;
			nbit<=0;
			sr<=(others=>'1');
		elsif(clk' event and clk='1')then
			if(en_s='0')then
				rows<=(others=>(others=>'1'));
				st<=ST_STOP;
			else
				case st is
				when ST_IDLE =>
					if(rx='0')then
						bcnt<=BITCYC/2;
						st<=ST_START;
					end if;
				when ST_START =>
					if(bcnt/=0)then
						bcnt<=bcnt-1;
					elsif(rx='0')then
						bcnt<=BITCYC;
						nbit<=0;
						st<=ST_DATA;
					else
						st<=ST_IDLE;
					end if;
				when ST_DATA =>
					if(bcnt/=0)then
						bcnt<=bcnt-1;
					else
						sr<=rx & sr(12 downto 1);
						bcnt<=BITCYC;
						if(nbit=12)then
							--the parity bit is taken and dropped
							rows(to_integer(unsigned(sr(4 downto 1))))<=sr(12 downto 5);
							st<=ST_STOP;
						else
							nbit<=nbit+1;
						end if;
					end if;
				when ST_STOP =>
					--a new start only after the line is high again
					if(rx='1')then
						st<=ST_IDLE;
					end if;
				end case;
			end if;
		end if;
	end process;

	SCANDAT<=rows(to_integer(unsigned(SCANADR)));

end rtl;
