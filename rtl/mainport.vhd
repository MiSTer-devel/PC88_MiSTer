-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;

--The main CPU's port to the devices on clk21m. The CPU side runs on cclk.
--
--Only the 8251 (ports 20h and 21h) goes through it for now. An access is
--taken once and served on fclk from the held address and data
--(cdc_busport). The CPU waits on a read until the data has come over, and
--never on a write unless the previous access is still being served.
--
--The 8251 acts at the end of the access it sees (e8251). It is given an
--access one fclk long, on the fclk where the read data is taken, so that it
--reads the status or the received byte, and clears RxRDY, at most three fclk
--after the data the CPU gets was taken.
entity mainport is
port(
	IORQn	:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	M1n		:in std_logic;
	ADR		:in std_logic_vector(7 downto 0);
	WDAT	:in std_logic_vector(7 downto 0);
	RDAT	:out std_logic_vector(7 downto 0);
	OE		:out std_logic;
	WAITn	:out std_logic;

	cclk	:in std_logic;
	crstn	:in std_logic;	--released on cclk

	COM_CSn	:out std_logic;
	COM_RDn	:out std_logic;
	COM_WRn	:out std_logic;
	COM_C_Dn:out std_logic;
	COM_WDAT:out std_logic_vector(7 downto 0);
	COM_RDAT:in std_logic_vector(7 downto 0);

	fclk	:in std_logic;
	frstn	:in std_logic	--released on fclk
);
end mainport;

architecture rtl of mainport is
component cdc_busport
generic(
	AW		:integer;
	DW		:integer;
	CAPT_CE	:boolean;
	FAST	:boolean;
	BUSYWAIT:boolean
);
port(
	acc_rd	:in std_logic;
	acc_wr	:in std_logic;
	adr		:in std_logic_vector(AW-1 downto 0);
	wdat	:in std_logic_vector(DW-1 downto 0);
	rdat	:out std_logic_vector(DW-1 downto 0);
	waitn	:out std_logic;
	taken	:out std_logic;
	hadr	:out std_logic_vector(AW-1 downto 0);

	cclk	:in std_logic;
	ce		:in std_logic	:='1';
	crstn	:in std_logic;

	f_adr	:out std_logic_vector(AW-1 downto 0);
	f_wdat	:out std_logic_vector(DW-1 downto 0);
	f_rd	:out std_logic;
	f_act	:out std_logic;
	f_sel	:out std_logic;
	f_rdat	:in std_logic_vector(DW-1 downto 0);
	f_busy	:in std_logic	:='0';

	fclk	:in std_logic;
	frstn	:in std_logic
);
end component;

signal	slow		:std_logic;
signal	acc_rd		:std_logic;
signal	acc_wr		:std_logic;
signal	f_adr		:std_logic_vector(7 downto 0);
signal	f_rd		:std_logic;
signal	f_sel		:std_logic;
signal	f_rdat		:std_logic_vector(7 downto 0);
signal	f_com		:std_logic;

begin
	slow<=	'1' when IORQn='0' and M1n='1' and ADR(7 downto 1)="0010000" else	--20h,21h
			'0';
	acc_rd<=slow and not RDn;
	acc_wr<=slow and not WRn;

	port0	:cdc_busport generic map(8,8,false,true,true) port map(
		acc_rd	=>acc_rd,
		acc_wr	=>acc_wr,
		adr		=>ADR,
		wdat	=>WDAT,
		rdat	=>RDAT,
		waitn	=>WAITn,
		taken	=>open,
		hadr	=>open,

		cclk	=>cclk,
		crstn	=>crstn,

		f_adr	=>f_adr,
		f_wdat	=>COM_WDAT,
		f_rd	=>f_rd,
		f_act	=>open,
		f_sel	=>f_sel,
		f_rdat	=>f_rdat,

		fclk	=>fclk,
		frstn	=>frstn
	);

	OE<=acc_rd;

	f_com<='1' when f_adr(7 downto 1)="0010000" else '0';
	COM_CSn<=not(f_sel and f_com);
	COM_RDn<=not f_rd;
	COM_WRn<=f_rd;
	COM_C_Dn<=f_adr(0);
	f_rdat<=COM_RDAT when f_com='1' else (others=>'1');

end rtl;
