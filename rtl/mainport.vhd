-- Copyright (C) 2026 Yoshiaki Okuyama
-- SPDX-License-Identifier: GPL-2.0-or-later

LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;

--The main CPU's port to the devices on clk21m. The CPU side runs on cclk.
--
--The 8251 (ports 20h and 21h) and the sound chips (the accesses FMSEL marks)
--go through it. An access is taken once and served on fclk from the held
--address and data (cdc_busport). The CPU waits on a read until the data has
--come over, and never on a write unless the previous access is still being
--served.
--
--The 8251 acts at the end of the access it sees (e8251). It is given an
--access one fclk long, on the fclk where the read data is taken, so that it
--reads the status or the received byte, and clears RxRDY, at most three fclk
--after the data the CPU gets was taken.
--
--SB2C (the Sound Board II setting: 0 expansion, 1 onboard) is held with the
--address, so the access goes to the chip chosen when it was taken. The internal
--OPN gets a write one fclk long. The board OPNA gets its select until FM_CEN
--has come twice, as its ADPCM-B RAM port only looks on FM_CEN and takes the
--data on the next one; the port stays busy until then, so the held address and
--data do not change.
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
	FMSEL	:in std_logic	:='0';	--the access is to the sound chips
	SB2C	:in std_logic	:='0';	--Sound Board II setting: 0 expansion, 1 onboard (steady while IORQn is low)

	cclk	:in std_logic;
	crstn	:in std_logic;	--released on cclk

	COM_CSn	:out std_logic;
	COM_RDn	:out std_logic;
	COM_WRn	:out std_logic;
	COM_C_Dn:out std_logic;
	COM_WDAT:out std_logic_vector(7 downto 0);
	COM_RDAT:in std_logic_vector(7 downto 0);

	FM_WDAT	:out std_logic_vector(7 downto 0);
	FM_CEN	:in std_logic	:='0';	--the board OPNA's clock enable
	FM1_WRn	:out std_logic;			--internal OPN (cs_n and wr_n)
	FM1_ADR	:out std_logic;
	FM1_RDAT:in std_logic_vector(7 downto 0)	:=(others=>'1');
	FM2_CSn	:out std_logic;			--board OPNA
	FM2_WRn	:out std_logic;
	FM2_RDn	:out std_logic;
	FM2_ADR	:out std_logic_vector(1 downto 0);
	FM2_RDAT:in std_logic_vector(7 downto 0)	:=(others=>'1');

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
signal	cadr		:std_logic_vector(8 downto 0);
signal	f_adr		:std_logic_vector(8 downto 0);
signal	f_wdat		:std_logic_vector(7 downto 0);
signal	f_rd		:std_logic;
signal	f_sel		:std_logic;
signal	f_rdat		:std_logic_vector(7 downto 0);
signal	f_com		:std_logic;
signal	f_fm1		:std_logic;
signal	f_fm2		:std_logic;
signal	fm2_act		:std_logic;
signal	fm2_lvl		:std_logic;
signal	fm2_cen1	:std_logic;

begin
	slow<=	'1' when IORQn='0' and M1n='1' and ADR(7 downto 1)="0010000" else	--20h,21h
			'1' when IORQn='0' and M1n='1' and FMSEL='1' else
			'0';
	acc_rd<=slow and not RDn;
	acc_wr<=slow and not WRn;
	cadr<=SB2C & ADR;

	port0	:cdc_busport generic map(9,8,false,true,true) port map(
		acc_rd	=>acc_rd,
		acc_wr	=>acc_wr,
		adr		=>cadr,
		wdat	=>WDAT,
		rdat	=>RDAT,
		waitn	=>WAITn,
		taken	=>open,
		hadr	=>open,

		cclk	=>cclk,
		crstn	=>crstn,

		f_adr	=>f_adr,
		f_wdat	=>f_wdat,
		f_rd	=>f_rd,
		f_act	=>open,
		f_sel	=>f_sel,
		f_rdat	=>f_rdat,
		f_busy	=>fm2_lvl,

		fclk	=>fclk,
		frstn	=>frstn
	);

	OE<=acc_rd;

	f_com<='1' when f_adr(7 downto 1)="0010000" else '0';
	COM_CSn<=not(f_sel and f_com);
	COM_RDn<=not f_rd;
	COM_WRn<=f_rd;
	COM_C_Dn<=f_adr(0);
	COM_WDAT<=f_wdat;

	--Expansion: 44h,45h the internal OPN (46h,47h read FFh), A8h,A9h,ACh,ADh the board OPNA.
	--Onboard: 44h-47h the board OPNA.
	f_fm1<='1' when f_adr(8)='0' and f_adr(7 downto 1)="0100010" else '0';
	f_fm2<=	'1' when f_adr(8)='1' and f_adr(7 downto 2)="010001" else
			'1' when f_adr(8)='0' and f_adr(7 downto 3)&f_adr(1)="101010" else
			'0';

	FM_WDAT<=f_wdat;
	FM1_WRn<=not(f_sel and f_fm1 and not f_rd);
	FM1_ADR<=f_adr(0);

	process(fclk,frstn)begin
		if(frstn='0')then
			fm2_lvl<='0';
			fm2_cen1<='0';
		elsif(fclk' event and fclk='1')then
			if(f_sel='1' and f_fm2='1')then
				fm2_lvl<='1';
				fm2_cen1<=FM_CEN;
			elsif(fm2_lvl='1' and FM_CEN='1')then
				if(fm2_cen1='1')then
					fm2_lvl<='0';
				end if;
				fm2_cen1<='1';
			end if;
		end if;
	end process;

	fm2_act<=(f_sel and f_fm2) or fm2_lvl;
	FM2_CSn<=not fm2_act;
	FM2_WRn<=not(fm2_act and not f_rd);
	FM2_RDn<=not(fm2_act and f_rd);
	FM2_ADR<=f_adr(2)&f_adr(0) when f_adr(8)='0' else f_adr(1 downto 0);

	f_rdat<=COM_RDAT when f_com='1' else
			FM1_RDAT when f_fm1='1' else
			FM2_RDAT when f_fm2='1' else
			(others=>'1');

end rtl;
