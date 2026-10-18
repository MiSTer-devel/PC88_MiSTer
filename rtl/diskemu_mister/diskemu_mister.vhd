LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity diskemu_mister is
generic(
	fclkfreq		:integer	:=30000;
	sclkfreq		:integer	:=10000;
	fdwait	:integer	:=10
);
port(

--SASI
	sasi_din	:in std_logic_vector(7 downto 0)	:=(others=>'0');
	sasi_dout:out std_logic_vector(7 downto 0);
	sasi_sel	:in std_logic						:='0';
	sasi_bsy	:out std_logic;
	sasi_req	:out std_logic;
	sasi_ack	:in std_logic						:='0';
	sasi_io	:out std_logic;
	sasi_cd	:out std_logic;
	sasi_msg	:out std_logic;
	sasi_rst	:in std_logic						:='0';

--FDD
	fdc_useln	:in std_logic_vector(1 downto 0)	:=(others=>'1');
	fdc_motorn	:in std_logic_vector(1 downto 0)	:=(others=>'1');
	fdc_readyn	:out std_logic;
	fdc_wrenn	:in std_logic						:='1';
	fdc_wrbitn	:in std_logic						:='1';
	fdc_rdbitn	:out std_logic;
	fdc_stepn	:in std_logic						:='1';
	fdc_sdirn	:in std_logic						:='1';
	fdc_track0n	:out std_logic;
	fdc_indexn	:out std_logic;
	fdc_siden	:in std_logic						:='1';
	fdc_wprotn	:out std_logic;
	fdc_eject	:in std_logic_vector(1 downto 0)	:=(others=>'0');
	fdc_indisk	:out std_logic_vector(1 downto 0)	:=(others=>'0');
	fdc_trackwid:in std_logic						:='1';	--1:2HD/2DD 0:2D
	fdc_dencity	:in std_logic						:='1';	--1:2HD 0:2DD/2D
	fdc_rpm		:in std_logic						:='0';	--1:360rpm 0:300rpm
	fdc_mfm		:in std_logic						:='1';
	
--FD emulator
	fde_tracklen:out std_logic_vector(13 downto 0);
	fde_ramaddr	:out std_logic_vector(22 downto 0);
	fde_ramrdat	:in std_logic_vector(15 downto 0);
	fde_ramwdat	:out std_logic_vector(15 downto 0);
	fde_ramwr	:out std_logic;
	fde_ramwait	:in std_logic;
	fec_ramaddrh :out std_logic_vector(14 downto 0);
	fec_ramaddrl :in std_logic_vector(7 downto 0);
	fec_ramwe	:in std_logic;
	fec_ramrdat	:out std_logic_vector(15 downto 0);
	fec_ramwdat	:in std_logic_vector(15 downto 0);
	fec_ramrd	:out std_logic;
	fec_ramwr	:out std_logic;
	fec_rambusy	:in std_logic;

	fec_fdsync	:in std_logic_Vector(1 downto 0);
--SRAM
	sram_cs		:in std_logic						:='0';
	sram_addr	:in std_logic_vector(12 downto 0)	:=(others=>'0');
	sram_rdat	:out std_logic_vector(15 downto 0);
	sram_wdat	:in std_logic_vector(15 downto 0)	:=(others=>'0');
	sram_rd		:in std_logic						:='0';
	sram_wr		:in std_logic_vector(1 downto 0)	:="00";
	sram_wp		:in std_logic						:='0';
	
	sram_ld		:in std_logic;
	sram_st		:in std_logic;

--MiSTer diskimage
	mist_mounted	:in std_logic_vector(3 downto 0);	--SRAM & HDD & FDD1 &FDD0
	mist_readonly	:in std_logic_vector(3 downto 0);
	mist_imgsize	:in std_logic_vector(63 downto 0);

	mist_lba		:out std_logic_vector(31 downto 0);
	mist_rd		:out std_logic_vector(3 downto 0);
	mist_wr		:out std_logic_vector(3 downto 0);
	mist_ack		:in std_logic_vector(3 downto 0);

	mist_buffaddr	:in std_logic_vector(8 downto 0);
	mist_buffdout	:in std_logic_vector(7 downto 0);
	mist_buffdin	:out std_logic_vector(7 downto 0);
	mist_buffwr		:in std_logic;
	
--common
	initdone	:out std_logic;
	busy		:out std_logic;
	fclk		:in std_logic;
	sclk		:in std_logic;
	rclk		:in std_logic;
	rstn		:in std_logic
);
end diskemu_mister;

architecture rtl of diskemu_mister is

type emustate_t is (
	es_IDLE,
	es_fload0,
	es_fload1,
	es_fsave0,
	es_fsave1,
	es_sasi,
	es_sload,
	es_ssave
);
signal	emustate	:emustate_t;

type fdstate_t is (
	fs_idle,
	fs_loadtbl0,
	fs_loadtbl1,
	fs_loadmode,
	fs_loadshead,
	fs_loadsheadw,
	fs_loadsectorsl,
	fs_loadsectorsh,
	fs_psinit,
	fs_psden,
	fs_pslenl,
	fs_pslenh,
	fs_psadd,
	fs_pschk,
	fs_gap0,
	fs_syncp,
	fs_am0,
	fs_am1,
	fs_gap1,
	fs_synci,
	fs_iam0,
	fs_iam1,
	fs_iam2,
	fs_C,
	fs_H,
	fs_R,
	fs_N,
	fs_crci0,
	fs_crci1,
	fs_ssizel,
	fs_ssizeh,
	fs_gap2,
	fs_syncd,
	fs_dam0,
	fs_dam1,
	fs_dam2,
	fs_dat,
	fs_crcd0,
	fs_crcd1,
	fs_gap3,
	fs_gap4,
	fs_nxtsector,
	fs_nxttrack,
	fs_scantrack,
	fs_scaniam,
	fs_crciam0,
	fs_crciam1,
	fs_crciam2,
	fs_stC,
	fs_stH,
	fs_stR,
	fs_stN,
	fs_chkicrch,
	fs_chkicrcl,
	fs_stmod,
	fs_stsectsizel,
	fs_stsectsizeh,
	fs_scandam,
	fs_crcdam0,
	fs_crcdam1,
	fs_crcdam2,
	fs_stdat,
	fs_chkdatcrc,
	fs_ststatus,
	fs_svmode,
	fs_svsize,
	fs_allot,
	fs_allotchk,
	fs_reloc,
	fs_phscan,
	fs_phclrw,
	fs_phnext,
	fs_relocw,
	fs_putgo,
	fs_savenexttrack,
	fs_ovs0,
	fs_ovs1,
	fs_ovs2,
	fs_ovm0,
	fs_ovm1,
	fs_ovm2,
	fs_ovm3,
	fs_ovm4,
	fs_ovm5,
	fs_ovm6,
	fs_ovm6s,
	fs_ovm7,
	fs_ovi0,
	fs_ovi1s,
	fs_ovi1,
	fs_ovi2,
	fs_ovi3,
	fs_ovi4,
	fs_ovi5,
	fs_ovn0,
	fs_ovn1,
	fs_ovres,
	fs_pl0,
	fs_plh0,
	fs_plh1,
	fs_plh2,
	fs_plh3,
	fs_plh4,
	fs_plh5,
	fs_plh6,
	fs_plh7,
	fs_plf0,
	fs_plf1,
	fs_plf2,
	fs_plf2b,
	fs_plf3,
	fs_pls0,
	fs_pls1,
	fs_plf6,
	fs_plr0,
	fs_plr1,
	fs_plr2,
	fs_plf8,
	fs_plend,
	fs_plfill,
	fs_saveend
);
signal	fdstate	:fdstate_t;

constant allzero	:std_logic_vector(63 downto 0)	:=(others=>'0');

signal	storef0	:std_logic;
signal	storef1	:std_logic;
signal	fddone	:std_logic;
signal	sasidone :std_logic;
signal	sramdone :std_logic;
signal	proc_begin	:std_logic;

signal	lba_fdd	:std_logic_vector(31 downto 0);

signal	fec_curaddr	:std_logic_vector(31 downto 0);

constant bit_fd0	:integer	:=0;
constant bit_fd1	:integer	:=1;
constant bit_sasi	:integer	:=2;
constant bit_sram	:integer	:=3;

signal	wrprot	:std_logic_vector(1 downto 0);
signal	diskmode0	:std_logic_vector(1 downto 0);
signal	diskmode1	:std_logic_vector(1 downto 0);
signal	diskmode		:std_logic_vector(1 downto 0);
signal	ddmode			:std_logic;
signal	dstep0,dstep1	:std_logic;		-- 1: 2D image in the drive
-- signal	fde_wrmode	:std_logic_vector(7 downto 0);
signal	fde_modeset	:std_logic_vector(1 downto 0);

-- signal	fde_wrote	:std_logic_vector(3 downto 0);

signal	tblramwr	:std_logic;
signal	tblramsel	:std_logic;

signal	tbladdr	:std_logic_vector(7 downto 0);
signal	haddr	:std_logic_vector(31 downto 0);

signal	sectwr		:std_logic;

signal	sbufaddr	:std_logic_vector(8 downto 0);
signal	sbufwr		:std_logic;

signal	trackno	:std_logic_vector(7 downto 0);
signal	track_curaddr	:std_logic_vector(13 downto 0);
signal	tracklen	:std_logic_vector(31 downto 0);
signal	tracks		:std_logic_Vector(7 downto 0);

signal	img_curaddr	:std_logic_vector(31 downto 0);
signal	img_unit	:std_logic;
signal	img_addr	:std_logic_vector(31 downto 0);
signal	img_rd		:std_logic;
signal	img_wr		:std_logic;
signal	img_sync		:std_logic;
signal	img_busy	:std_logic;
signal	img_rddat	:std_logic_vector(7 downto 0);
signal	img_wrdat	:std_logic_vector(7 downto 0);

signal	cur_lba		:std_logic_vector(31 downto 0);
signal	cur_unit	:std_logic;

signal	trackaddr	:std_logic_vector(22 downto 0);
signal	trackwrdat	:std_logic_vector(15 downto 0);
signal	trackrddat	:std_logic_vector(15 downto 0);
signal	trackwr		:std_logic;
signal	trackrd		:std_logic;
signal	tracksync	:std_logic;
signal	trackbusy	:std_logic;
signal	curfbhaddr	:std_logic_vector(14 downto 0);
signal	fdsectwr		:std_logic;

signal	bytecount	:integer range 0 to 2047;
signal	mfm		:std_logic;
-- signal	mfm0		:std_logic;
-- signal	mfm1		:std_logic;
-- signal	mfm0m		:std_logic;
-- signal	mfm1m		:std_logic;
signal	numsect	:std_logic_vector(15 downto 0);
signal	sectcount:std_logic_vector(15 downto 0);
signal	cursecthead	:std_logic_vector(31 downto 0);
signal	nxtsecthead	:std_logic_vector(31 downto 0);
signal	disksize	:std_logic_vector(31 downto 0);
signal	disksize0	:std_logic_vector(31 downto 0);
signal	newlen	:std_logic_vector(31 downto 0);
signal	bound	:std_logic_vector(31 downto 0);
signal	idcnt	:integer range 0 to 4;
signal	allotidx	:std_logic_vector(7 downto 0);
signal	wbyte	:integer range 0 to 7;
signal	sizechg	:std_logic;
signal	phdone	:std_logic;
signal	fsize0	:std_logic_vector(31 downto 0);
signal	fsize1	:std_logic_vector(31 downto 0);
signal	scanlim	:std_logic_vector(31 downto 0);
signal	tracklenm	:std_logic_vector(31 downto 0);
signal	curfsize	:std_logic_vector(31 downto 0);
signal	svmount	:std_logic;
signal	relok	:std_logic;
signal	relfit	:std_logic;
signal	sectlen	:std_logic_vector(15 downto 0);
--a long sector followed by sectors is laid out as on the real disk; the sectors behind it
--are placed where their ID marks appear inside its data, and the track keeps the normal turn
signal	ovl		:std_logic;	-- this track has such a long sector
signal	ovlseen	:std_logic;	-- a sector of 6144 bytes or more was seen in this track
--a sector of 4096 to 6143 bytes with a data CRC error is also taken as a long sector when sectors follow it,
--but only if the IDs of all of them are found in its data and no sector with a good CRC would be cut
--by the next one; otherwise the track is laid out as before
signal	ovlsmall	:std_logic;	-- the long sector is such a sector (less than 6144 bytes)
signal	fcnt	:integer range 0 to 64;	-- number of the d88 sectors behind it whose ID was found
signal	ovlkeep	:std_logic;	-- an earlier long sector of this track kept the no-write-back mark
signal	ovlcopy	:std_logic;	-- copying the long sector's data
signal	ovlimg	:std_logic_vector(31 downto 0);	-- image address of the long sector's data
signal	ovlstart	:std_logic_vector(13 downto 0);	-- track address of its first data byte
signal	ovllen	:std_logic_vector(15 downto 0);	-- size of the long sector's data
--IDs found in the long sector's data (prescan) and where the d88 sectors behind it go
--the tables are block RAMs, read one entry at a time (the read data comes 2 clocks after the address)
type ovtram_t is array(0 to 31) of std_logic_vector(45 downto 0);	-- C H R N & position of an ID found
type ovfpram_t is array(0 to 63) of std_logic_vector(14 downto 0);	-- placed & position of a d88 sector behind
type ovfhram_t is array(0 to 63) of std_logic_vector(31 downto 0);	-- image address of its header
signal	tram	:ovtram_t;
signal	fpram	:ovfpram_t;
signal	fhram	:ovfhram_t;
--tracks with a long sector, per drive and track: not written back (the image keeps the long sector as it is)
type ovlram_t is array(0 to 511) of std_logic;
signal	ovlram	:ovlram_t:=(others=>'0');
signal	ovl_we	:std_logic;
signal	ovl_wd	:std_logic;
signal	ovl_q	:std_logic;
--the FDC's current track of each drive is such a track: writes to it are refused as write-protected.
--The marks of both sides of both drives at their head positions are looked up in turn, so a change of
--drive or side selects the right one at once (SENSE DRIVE STATUS takes ST3 one clock after it)
signal	ddm	:std_logic_vector(1 downto 0);	-- 2DD/2HD image in the drive (one track per head step)
signal	fdtrk1,fdtrk2	:std_logic_vector(9 downto 0);
type headpos_t is array(0 to 1) of std_logic_vector(6 downto 0);
signal	headpos	:headpos_t:=(others=>(others=>'1'));	-- head position of each drive, as last selected
signal	wpsel,wpselq	:std_logic_vector(1 downto 0):="00";	-- drive & side looked up now / one clock ago
signal	wpval	:std_logic;
signal	wpq		:std_logic;
signal	ovlwpb	:std_logic_vector(3 downto 0):=(others=>'0');	-- index drive & side
signal	ovlwp	:std_logic_vector(1 downto 0);	-- of the side selected now, per drive
signal	t_we,fp_we,fh_we	:std_logic;
signal	t_wa,t_ra	:std_logic_vector(4 downto 0);
signal	fp_wa,fp_ra,fh_wa,fh_ra	:std_logic_vector(5 downto 0);
signal	t_wd,t_q	:std_logic_vector(45 downto 0);
signal	fp_wd,fp_q	:std_logic_vector(14 downto 0);
signal	fh_wd,fh_q	:std_logic_vector(31 downto 0);
signal	prevok	:std_logic;
signal	prevpos	:std_logic_vector(13 downto 0);
signal	ovacc	:std_logic_vector(27 downto 0);
signal	tn		:integer range 0 to 32;
signal	fn		:integer range 0 to 64;
signal	fany	:std_logic;
signal	sr		:std_logic_vector(63 downto 0);
signal	sbyte	:std_logic_vector(7 downto 0);
signal	sbit	:integer range 0 to 7;
signal	soff	:std_logic_vector(15 downto 0);
signal	mj,mk,mq	:integer range 0 to 64;
signal	mhead	:std_logic_vector(31 downto 0);
signal	mchrn	:std_logic_vector(31 downto 0);
signal	mlen	:std_logic_vector(7 downto 0);
signal	mlen16	:std_logic_vector(15 downto 0);	-- size of the d88 sector being matched
signal	mst		:std_logic_vector(7 downto 0);	-- its d88 status
signal	pgood	:std_logic;	-- the sector matched last is built with a good data CRC (its d88 status is not b0)
signal	pend	:std_logic_vector(16 downto 0);	-- where its data and CRC end if built at its ID
signal	ovlbad	:std_logic;	-- a sector with a good CRC would be cut by the next one
signal	minstep	:std_logic_vector(13 downto 0);
signal	ilo,ihi	:integer range 0 to 64;
signal	ilopos	:std_logic_vector(13 downto 0);
signal	inum	:std_logic_vector(13 downto 0);
signal	iq		:std_logic_vector(13 downto 0);
signal	ifill	:std_logic_vector(13 downto 0);
signal	bj		:integer range 0 to 64;
signal	bpos	:std_logic_vector(13 downto 0);	-- where the next d88 sector behind goes
signal	bcapn	:std_logic_vector(13 downto 0);	-- where the one after it goes
signal	bcap	:std_logic_vector(13 downto 0);	-- end of the sector being built
--a track with no sector of 4096 bytes or more that does not fit even in the long track in order: sectors with a
--data CRC error may hold the ID marks of the sectors written over them on the real disk, as the FDC read them.
--The track is planned first and each sector's ID goes where its marks are recorded, the same idea as for the long
--sector above (rules 1 to 3 below, where the sectors are placed)
signal	ovmode	:std_logic;	-- this track is built at the planned places
signal	psov	:std_logic;	-- a sector of 6144 bytes or more is in the track (laid out as above)
signal	ps4k	:std_logic;	-- a sector of 4096 to 6143 bytes is in the track
signal	pssum2	:std_logic_vector(17 downto 0);	-- length of the track built in order with GAP3 26
type plmark_t is array(0 to 63) of std_logic_vector(51 downto 0);	-- marks found: sector & place in its data & C H R N
type plsect_t is array(0 to 63) of std_logic_vector(55 downto 0);	-- C H R N & size & status of each sector
type plpos_t is array(0 to 63) of std_logic_vector(22 downto 0);	-- ID position & placed in a parent & parent & rule
type plhead_t is array(0 to 63) of std_logic_vector(31 downto 0);	-- image address of its header
signal	ctram	:plmark_t;
signal	csiram	:plsect_t;
signal	cspram	:plpos_t;
signal	cfhram	:plhead_t;
signal	ct_we,csi_we,csp_we,cfh_we	:std_logic;
signal	ct_wa,ct_ra,csi_wa,csi_ra,csp_wa,csp_ra,cfh_wa,cfh_ra	:std_logic_vector(5 downto 0);
signal	ct_wd,ct_q	:std_logic_vector(51 downto 0);
signal	csi_wd,csi_q	:std_logic_vector(55 downto 0);
signal	csp_wd,csp_q	:std_logic_vector(22 downto 0);
signal	cfh_wd,cfh_q	:std_logic_vector(31 downto 0);
signal	ctn		:integer range 0 to 64;	-- marks in the table
signal	pn		:integer range 0 to 64;	-- sectors in the track
signal	pj,pi,pk	:integer range 0 to 64;
signal	ptstart	:integer range 0 to 64;	-- first mark of sector pj
signal	phead	:std_logic_vector(31 downto 0);
signal	pchrn	:std_logic_vector(31 downto 0);	-- C H R N of sector pj
signal	ichrn	:std_logic_vector(31 downto 0);	-- the same of sector pi
signal	plen	:std_logic_vector(15 downto 0);
signal	pst		:std_logic_vector(7 downto 0);
signal	ppos,pnxt,ipos,plast	:std_logic_vector(15 downto 0);
signal	pset,pfound,pany	:std_logic;
signal	ppar,mpar	:std_logic_vector(5 downto 0);
signal	mrel	:std_logic_vector(13 downto 0);
signal	phow	:std_logic_vector(1 downto 0);
signal	csr		:std_logic_vector(55 downto 0);	-- the 7 bytes before
signal	csoff	:std_logic_vector(15 downto 0);
-- GAP3: standard format values when the whole track fits in one revolution, else 26/13 as before
signal	usestd	:std_logic;
signal	gap3sel	:integer range 0 to 127;
signal	pscnt	:std_logic_vector(15 downto 0);
signal	psaddr	:std_logic_vector(31 downto 0);
signal	pslen	:std_logic_vector(15 downto 0);
signal	pssum	:std_logic_vector(17 downto 0);
signal	pslimit	:std_logic_vector(17 downto 0);
function stdgap(len :std_logic_vector(15 downto 0)) return integer is
begin
	if(len<=x"0080")then		-- 0 is written as 128
		return 26;
	elsif(len<=x"0100")then
		return 54;
	elsif(len<=x"0200")then
		return 80;
	else
		return 116;
	end if;
end stdgap;
function efflen(len :std_logic_vector(15 downto 0)) return std_logic_vector is
begin
	if(len=x"0000")then
		return x"0080";
	else
		return len;
	end if;
end efflen;
function sectbytes(n :std_logic_vector(7 downto 0)) return std_logic_vector is
begin
	case n is
	when x"00" => return x"00000090";
	when x"01" => return x"00000110";
	when x"02" => return x"00000210";
	when x"03" => return x"00000410";
	when x"04" => return x"00000810";
	when x"05" => return x"00001010";
	when x"06" => return x"00002010";
	when x"07" => return x"00004010";
	when others => return x"00000011";
	end case;
end sectbytes;
function byteof(v :std_logic_vector(31 downto 0); i :integer range 0 to 3) return std_logic_vector is
begin
	case i is
	when 0 => return v(7 downto 0);
	when 1 => return v(15 downto 8);
	when 2 => return v(23 downto 16);
	when others => return v(31 downto 24);
	end case;
end byteof;
signal	deleted	:std_logic;
signal	crcwrdat	:std_logic_vector(7 downto 0);
signal	crcwr		:std_logic;
signal	crcclr		:std_logic;
signal	crcdat		:std_logic_vector(15 downto 0);
signal	crcbusy		:std_logic;
signal	sectrd		:std_logic;
signal	sectstatus	:std_logic_vector(7 downto 0);
signal	sbuf_odat	:std_logic_vector(7 downto 0);

signal	fbaddr		:std_logic_vector(7 downto 0);
signal	fbwr		:std_logic;

signal	fde_track0n	:std_logic;
signal	fde_indexn	:std_logic;
signal	fde_rdbitn	:std_logic;

signal	fde_ramaddrw	:std_logic_vector(23 downto 0);
signal	fdc_usel		:std_logic_vector(1 downto 0);
signal	fdc_indiskb	:std_logic_vector(1 downto 0);
signal	fdc_motoren	:std_logic;
signal	trackwrote	:std_logic;
signal	statusaddr	:std_logic_vector(13 downto 0);

signal	sramen		:std_logic;
signal	fstore		:std_logic_vector(1 downto 0);

type sbufstate_t is (
	ss_idle,
	ss_rwrite,
	ss_rwrite2,
	ss_read,
	ss_read2,
	ss_wread,
	ss_wread2,
	ss_write,
	ss_write2,
	ss_sync,
	ss_sync2
);
signal	sbufstate	:sbufstate_t;
signal	fbufstate	:sbufstate_t;
signal	sasibufstate:sbufstate_t;

--SASI
signal	sasien		:std_logic;
signal	sasi_idsel	:std_logic_vector(7 downto 0);
signal	sasi_cap		:std_logic_vector(63 downto 0);
signal	sasi_lba		:std_logic_vector(20 downto 0);
signal	sasi_sectaddr	:std_logic_vector(7 downto 0);
signal	sasisectwr	:std_logic;
signal	sasibufwr	:std_logic;
signal	sasi_rdreq	:std_logic;
signal	sasi_wrreq	:std_logic;
signal	sasi_syncreq:std_logic;
signal	sasi_bufbusy	:std_logic;
signal	sasi_sectwrdat	:std_logic_vector(7 downto 0);
signal	sasi_sectrddat	:std_logic_vector(7 downto 0);
signal	sasi_rdreq2	:std_logic;
signal	sasi_wrreq2	:std_logic;
signal	sasi_syreq2	:std_logic;
signal	sasi_bufodat	:std_logic_vector(7 downto 0);
signal	lba_sasi		:std_logic_vector(31 downto 0);
signal	cur_slba		:std_logic_vector(31 downto 0);

--SRAM
signal	lba_sram		:std_logic_vector(31 downto 0);
signal	sram_bufwr	:std_logic;
signal	sram_bufout	:std_logic_Vector(7 downto 0);
signal	sramwr	:std_logic_vector(1 downto 0);
signal	sram_ldreq	:std_logic;
signal	sram_streq	:std_logic;

component tracktable
port(
	wraddr	:in std_logic_vector(9 downto 0);
	wrdat	:in std_logic_vector(7 downto 0);
	wr		:in std_logic;
	
	table	:in std_logic_vector(7 downto 0);
	haddr	:out std_logic_vector(31 downto 0);
	
	clk		:in std_logic
);
end component;

component CRCGENN
	generic(
		DATWIDTH :integer	:=10;
		WIDTH	:integer	:=3
	);
	port(
		POLY	:in std_logic_vector(WIDTH downto 0);
		DATA	:in std_logic_vector(DATWIDTH-1 downto 0);
		DIR		:in std_logic;
		WRITE	:in std_logic;
		BITIN	:in std_logic;
		BITWR	:in std_logic;
		CLR		:in std_logic;
		CLRDAT	:in std_logic_vector(WIDTH-1 downto 0);
		CRC		:out std_logic_vector(WIDTH-1 downto 0);
		BUSY	:out std_logic;
		DONE	:out std_logic;
		CRCZERO	:out std_logic;

		clk		:in std_logic;
		rstn	:in std_logic
	);
end component;

component sectram
	PORT
	(
		address_a		: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data_a		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		wren_a		: IN STD_LOGIC  := '0';
		wren_b		: IN STD_LOGIC  := '0';
		q_a		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

component fecbuf
	PORT
	(
		address_a		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock_a		: IN STD_LOGIC  := '1';
		clock_b		: IN STD_LOGIC ;
		data_a		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		wren_a		: IN STD_LOGIC  := '0';
		wren_b		: IN STD_LOGIC  := '0';
		q_a		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;

component FDemu
generic(
	sysclk		:integer	:=20000;
	fdwait		:integer	:=10
);
port(
	ramaddr	:out std_logic_vector(23 downto 0);
	ramrdat	:in std_logic_vector(15 downto 0);
	ramwdat	:out std_logic_vector(15 downto 0);
	ramwr	:out std_logic;
	ramwait	:in std_logic;

	rdfdmode	:in std_logic_vector(7 downto 0);
	curfdmode	:out std_logic_vector(7 downto 0);
	modeset		:in std_logic_vector(3 downto 0);
	dstep		:in std_logic_vector(3 downto 0);
	wrote		:out std_logic_vector(3 downto 0);
	wprot		:in std_logic_vector(3 downto 0);
	tracklen	:out std_logic_vector(13 downto 0);
	fdenable	:in std_logic_vector(3 downto 0);
	
	USEL	:in std_logic_vector(1 downto 0);
	MOTOR	:in std_logic;
	READY	:out std_logic;
	WRENn	:in std_logic;		--pin24
	WRBITn	:in std_logic;		--pin22
	WRFDMODE:in std_logic_vector(1 downto 0);
	WRMFM	:in std_logic;
	RDBITn	:out std_logic;		--pin30
	STEPn	:in std_logic;		--pin20
	SDIRn	:in std_logic;		--pin18
	track0n	:out std_logic;		--pin26
	indexn	:out std_logic;		--pin8
	siden	:in std_logic;		--pin32

	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component sasidev
port(
	IDAT		:in std_logic_vector(7 downto 0);
	ODAT		:out std_logic_vector(7 downto 0);
	SEL		:in std_logic;
	BSY		:out std_logic;
	REQ		:out std_logic;
	ACK		:in std_logic;
	IO			:out std_logic;
	CD			:out std_logic;
	MSG		:out std_logic;
	RST		:in std_logic;
	
	idsel		:in std_logic_vector(7 downto 0);
	
	id			:out std_logic_vector(2 downto 0);
	unit		:out std_logic_vector(2 downto 0);
	capacity	:in std_logic_vector(63 downto 0);
	lba		:out std_logic_vector(20 downto 0);
	rdreq		:out std_logic;
	wrreq		:out std_logic;
	syncreq	:out std_logic;
	sectaddr	:out std_logic_vector(7 downto 0);
	rddat		:in std_logic_vector(7 downto 0);
	wrdat		:out std_logic_vector(7 downto 0);
	sectbusy	:in std_logic;
	
	clk		:in std_logic;
	rstn		:in std_logic
);
end component;

component wrotecont
generic(
	sysfreq	:integer	:=20;	--kHz
	delay	:integer	:=3		--msec
);
port(
	wrgate	:in std_logic;
	usel	:in std_logic_vector(1 downto 0);
	
	busy	:out std_logic;
	save	:out std_logic_vector(1 downto 0);
	done	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component sramcont
port(
	addr	:in std_logic_vector(12 downto 0);
	rdat	:out std_logic_vector(15 downto 0);
	wdat	:in std_logic_vector(15 downto 0)	:=(others=>'0');
	wr		:in std_logic_vector(1 downto 0)	:="00";
	
	ldreq	:in std_logic;
	streq	:in std_logic;
	done	:out std_logic;

	mist_rd	:out std_logic;
	mist_wr	:out std_logic;
	mist_ack:in std_logic;
	
	mist_lba	:out std_logic_vector(31 downto 0);
	mist_addr	:in std_logic_vector(8 downto 0);
	mist_wdat	:in std_logic_vector(7 downto 0);
	mist_rdat	:out std_logic_vector(7 downto 0);
	mist_we		:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin
	relfit<='1' when disksize0<=x"00400000" and ((disksize+newlen+x"000001ff") and x"fffffe00")<=x"00400000" else '0';

	
	initdone<=rstn;
	
	wc	:wrotecont generic map(sclkfreq,3000) port map(
		wrgate	=>not fdc_wrenn,
		usel	=>not fdc_useln,
		
		busy	=>busy,
		save	=>fstore,
		done	=>fddone,
		
		clk		=>sclk,
		rstn	=>rstn
	);

	storef0<=fec_fdsync(0) or fstore(0);
	storef1<=fec_fdsync(1) or fstore(1);
	
	process(sclk,rstn)
	variable lmount	:std_logic_vector(3 downto 0);
	variable fdload	:std_logic_vector(1 downto 0);
	variable fdstore :std_logic_vector(1 downto 0);
	variable sstore	:std_logic;
	variable sload	:std_logic;
	variable sasiwpend	:std_logic;
	variable sasirpend	:std_logic;
	variable sasispend	:std_logic;
	variable newmount	:std_logic_vector(1 downto 0);
	begin
		if(rstn='0')then
			lmount:=(others=>'0');
			emustate<=es_IDLE;
			proc_begin<='0';
			fdload:=(others=>'0');
			fdstore:=(others=>'0');
			sstore:='0';
			sload:='0';
			fdc_indiskb<="00";
			sasiwpend:='0';
			sasirpend:='0';
			sasispend:='0';
			sasi_bufbusy<='0';
			sasi_rdreq2<='0';
			sasi_wrreq2<='0';
			sasi_syreq2<='0';
			sram_ldreq<='0';
			sram_streq<='0';
			sramen<='0';
			sasien<='0';
			svmount<='0';
		elsif(sclk' event and sclk='1')then
			proc_begin<='0';
			sasi_rdreq2<='0';
			sasi_wrreq2<='0';
			sasi_syreq2<='0';
			sram_ldreq<='0';
			sram_streq<='0';
			newmount:=mist_mounted(bit_fd1 downto bit_fd0) and not lmount(bit_fd1 downto bit_fd0);
			if(mist_mounted(bit_fd0)='1' and lmount(bit_fd0)='0')then
				if(mist_imgsize(63 downto 32)=x"00000000")then
					fsize0<=mist_imgsize(31 downto 0);
				else
					fsize0<=(others=>'1');
				end if;
				if(emustate=es_fsave0)then
					svmount<='1';
				end if;
				if(mist_imgsize=x"00000000")then
					fdc_indiskb(0)<='0';
				else
					fdc_indiskb(0)<='0';
					fdload(0):='1';
				end if;
			end if;
			if(mist_mounted(bit_fd1)='1' and lmount(bit_fd1)='0')then
				if(mist_imgsize(63 downto 32)=x"00000000")then
					fsize1<=mist_imgsize(31 downto 0);
				else
					fsize1<=(others=>'1');
				end if;
				if(emustate=es_fsave1)then
					svmount<='1';
				end if;
				if(mist_imgsize=x"00000000")then
					fdc_indiskb(1)<='0';
				else
					fdc_indiskb(1)<='0';
					fdload(1):='1';
				end if;
			end if;
			
			if(mist_mounted(bit_sasi)='1' and lmount(bit_sasi)='0')then
				if(mist_imgsize=x"00000000")then
					sasien<='0';
				else
					sasien<='1';
				end if;
				sasi_cap<=mist_imgsize;
			end if;
			
			if(mist_mounted(bit_sram)='1' and lmount(bit_sram)='0')then
				if(mist_imgsize=x"00000000")then
					sramen<='0';
				else
					sramen<='1';
				end if;
			end if;
			
			if(storef0='1')then
				fdstore(0):='1';
			end if;
			if(storef1='1')then
				fdstore(1):='1';
			end if;
			
			if(sram_ld='1' and sramen='1')then
				sload:='1';
			end if;
			if(sram_st='1' and sramen='1')then
				sstore:='1';
			end if;
			
			if(fdc_eject(0)='1' and fdc_indiskb(0)='1')then
				fdstore(0):='1';
				fdc_indiskb(0)<='0';
			end if;
			if(fdc_eject(1)='1' and fdc_indiskb(1)='1')then
				fdstore(1):='1';
				fdc_indiskb(1)<='0';
			end if;
			
			if(sasi_rdreq='1')then
				sasirpend:='1';
				sasi_bufbusy<='1';
			elsif(sasi_wrreq='1')then
				sasiwpend:='1';
				sasi_bufbusy<='1';
			elsif(sasi_syncreq='1')then
				sasispend:='1';
			end if;
			
			lmount:=mist_mounted;
			case emustate is
			when es_IDLE =>
				if(sasirpend='1')then
					sasirpend:='0';
					emustate<=es_sasi;
					sasi_rdreq2<='1';
				elsif(sasiwpend='1')then
					sasiwpend:='0';
					emustate<=es_sasi;
					sasi_wrreq2<='1';
				elsif(sasispend='1')then
					sasispend:='0';
					emustate<=es_sasi;
					sasi_syreq2<='1';
				elsif(fdload(0)='1')then
					emustate<=es_fload0;
					proc_begin<='1';
					fdload(0):='0';
				elsif(fdload(1)='1')then
					emustate<=es_fload1;
					proc_begin<='1';
					fdload(1):='0';
				elsif(fdstore(0)='1' and fdc_indiskb(0)='1')then
					emustate<=es_fsave0;
					proc_begin<='1';
					fdstore(0):='0';
				elsif(fdstore(1)='1' and fdc_indiskb(1)='1')then
					emustate<=es_fsave1;
					proc_begin<='1';
					fdstore(1):='0';
				elsif(sload='1')then
					emustate<=es_sload;
					sram_ldreq<='1';
					sload:='0';
				elsif(sstore='1')then
					emustate<=es_ssave;
					sram_streq<='1';
					sstore:='0';
				end if;
			when es_fload0 | es_fload1 | es_fsave0 | es_fsave1 =>
				if(fddone='1')then
					emustate<=es_IDLE;
					svmount<='0';
					case emustate is
					when es_fload0 =>
						fdc_indiskb(0)<='1';
					when es_fload1 =>
						fdc_indiskb(1)<='1';
					when es_fsave0 =>
						if(sizechg='1' and svmount='0' and newmount(0)='0')then
							fsize0<=disksize;
						end if;
					when es_fsave1 =>
						if(sizechg='1' and svmount='0' and newmount(1)='0')then
							fsize1<=disksize;
						end if;
					when others =>
					end case;
				end if;
			when es_sasi =>
				if(sasidone='1')then
					sasi_bufbusy<='0';
					emustate<=es_IDLE;
				end if;
			when es_sload | es_ssave =>
				if(sramdone='1')then
					emustate<=es_IDLE;
				end if;
			when others =>
				emustate<=es_IDLE;
			end case;
		end if;
	end process;
	
	mist_lba<=	lba_fdd when emustate=es_fload0 else
				lba_fdd when emustate=es_fload1 else
				lba_fdd when emustate=es_fsave0 else
				lba_fdd when emustate=es_fsave1 else
				lba_sasi when emustate=es_sasi else
				lba_sram when emustate=es_sload else
				lba_sram when emustate=es_ssave else
				(others=>'0');
	
	tblramsel<=	'0' when fdstate=fs_loadtbl0 else
				'1' when fdstate=fs_loadtbl1 else
				'0';
	tblramwr<=	mist_buffwr when fdstate=fs_loadtbl0 else
				mist_buffwr when fdstate=fs_loadtbl1 else
				'0';
	
	tblram	:tracktable port map(
		wraddr	=>tblramsel & mist_buffaddr,
		wrdat	=>mist_buffdout,
		wr		=>tblramwr,
		
		table	=>tbladdr,
		haddr	=>haddr,
		
		clk		=>sclk
	);
	
	fdsectwr<=	mist_buffwr when emustate=es_fload0 else
					mist_buffwr when emustate=es_fload1 else
					mist_buffwr when emustate=es_fsave0 else
					mist_buffwr when emustate=es_fsave1 else
					'0';
					
	sectbuf	:sectram port map(
		address_a		=>mist_buffaddr,
		address_b		=>sbufaddr,
		clock				=>sclk,
		data_a			=>mist_buffdout,
		data_b			=>img_wrdat,
		wren_a			=>fdsectwr,
		wren_b			=>sbufwr,
		q_a				=>sbuf_odat,
		q_b				=>img_rddat
	);
	
	sbufaddr<=	img_addr(8 downto 0);

	process(sclk,rstn)
	variable wrote	:std_logic;
	begin
		if(rstn='0')then
			sbufstate<=ss_idle;
			lba_fdd<=(others=>'0');
			mist_rd(bit_fd1 downto bit_fd0)<=(others=>'0');
			mist_wr(bit_fd1 downto bit_fd0)<=(others=>'0');
			cur_lba<=(others=>'1');
			cur_unit<='0';
			sbufwr<='0';
			wrote:='0';
		elsif(sclk' event and sclk='1')then
			sbufwr<='0';
			if(svmount='1')then
				wrote:='0';
			end if;
			case sbufstate is
			when ss_idle =>
				if(img_rd='1')then
					-- the track table is always read from the image
					if(img_addr(31 downto 9)/=cur_lba(22 downto 0) or img_unit/=cur_unit or fdstate=fs_loadtbl0 or fdstate=fs_loadtbl1)then
						if(wrote='1')then
							if(img_unit='0')then
								mist_wr(bit_fd0)<='1';
							else
								mist_wr(bit_fd1)<='1';
							end if;
							sbufstate<=ss_rwrite;
						else
							cur_lba<="000000000" & img_addr(31 downto 9);
							cur_unit<=img_unit;
							lba_fdd<="000000000" & img_addr(31 downto 9);
							if(img_unit='0')then
								mist_rd(bit_fd0)<='1';
							else
								mist_rd(bit_fd1)<='1';
							end if;
							sbufstate<=ss_read;
						end if;
					end if;
				elsif(img_wr='1')then
					if(img_addr(31 downto 9)=cur_lba(22 downto 0) and img_unit=cur_unit)then
						sbufwr<='1';
						wrote:='1';
					else
						if(wrote='1')then
							if(cur_unit='0')then
								mist_wr(bit_fd0)<='1';
							else
								mist_wr(bit_fd1)<='1';
							end if;
							sbufstate<=ss_write;
						else
							cur_lba<="000000000" & img_addr(31 downto 9);
							cur_unit<=img_unit;
							lba_fdd<="000000000" & img_addr(31 downto 9);
							if(img_unit='0')then
								mist_rd(bit_fd0)<='1';
							else
								mist_rd(bit_fd1)<='1';
							end if;
							sbufstate<=ss_wread;
						end if;
					end if;
				elsif(img_sync='1')then
					if(wrote='1')then
						if(img_unit='0')then
							mist_wr(bit_fd0)<='1';
						else
							mist_wr(bit_fd1)<='1';
						end if;
						sbufstate<=ss_sync;
					end if;
				end if;
			when ss_rwrite =>
				if(mist_ack(bit_fd1 downto bit_fd0)/="00" or svmount='1')then
					mist_wr(bit_fd1 downto bit_fd0)<="00";
					sbufstate<=ss_rwrite2;
				end if;
			when ss_rwrite2 =>
				if(mist_ack(bit_fd1 downto bit_fd0)="00")then
					wrote:='0';
					cur_lba<="000000000" & img_addr(31 downto 9);
					cur_unit<=img_unit;
					lba_fdd<="000000000" & img_addr(31 downto 9);
					if(img_unit='0')then
						mist_rd(bit_fd0)<='1';
					else
						mist_rd(bit_fd1)<='1';
					end if;
					sbufstate<=ss_read;
				end if;
			when ss_read =>
				if(mist_ack(bit_fd1 downto bit_fd0)/="00")then
					mist_rd(bit_fd1 downto bit_fd0)<="00";
					sbufstate<=ss_read2;
				end if;
			when ss_read2 =>
				if(mist_ack(bit_fd1 downto bit_fd0)="00")then
					sbufstate<=ss_idle;
				end if;
			when ss_write =>
				if(mist_ack(bit_fd1 downto bit_fd0)/="00" or svmount='1')then
					mist_wr(bit_fd1 downto bit_fd0)<="00";
					sbufstate<=ss_write2;
				end if;
			when ss_write2 =>
				if(mist_ack(bit_fd1 downto bit_fd0)="00")then
					lba_fdd<="000000000" & img_addr(31 downto 9);
					cur_lba<="000000000" & img_addr(31 downto 9);
					cur_unit<=img_unit;
					if(img_unit='0')then
						mist_rd(bit_fd0)<='1';
					else
						mist_rd(bit_fd1)<='1';
					end if;
					wrote:='0';
					sbufstate<=ss_wread;
				end if;
			when ss_wread =>
				if(mist_ack(bit_fd1 downto bit_fd0)/="00")then
					mist_rd(bit_fd1 downto bit_fd0)<="00";
					sbufstate<=ss_wread2;
				end if;
			when ss_wread2 =>
				if(mist_ack(bit_fd1 downto bit_fd0)="00")then
					sbufwr<='1';
					wrote:='1';
					sbufstate<=ss_idle;
				end if;
			when ss_sync =>
				if(mist_ack(bit_fd1 downto bit_fd0)/="00" or svmount='1')then
					mist_wr(bit_fd1 downto bit_fd0)<="00";
					sbufstate<=ss_sync2;
				end if;
			when ss_sync2 =>
				if(mist_ack(bit_fd1 downto bit_fd0)="00")then
					wrote:='0';
					sbufstate<=ss_idle;
				end if;
			when others =>
				sbufstate<=ss_idle;
			end case;
		end if;
	end process;

	img_busy<=	'1' when img_rd='1' else
				'1' when img_wr='1' else
				'0' when sbufstate=ss_idle else
				'1';

	
	process(sclk,rstn)
	variable swait	:integer range 0 to 3;
	variable ovb	:std_logic_vector(16 downto 0);
	variable csb	:std_logic_vector(63 downto 0);
	variable vpos,vcand	:std_logic_vector(15 downto 0);
	variable vhow	:std_logic_vector(1 downto 0);
	variable ambuf0,ambuf1,ambuf2,ambuf3	:std_logic_vector(9 downto 0);
	begin
		if(rstn='0')then
			fdstate<=fs_idle;
			swait:=0;
			ovl<='0';
			ovlseen<='0';
			ovlsmall<='0';
			fcnt<=0;
			ovlkeep<='0';
			ovlcopy<='0';
			fn<=0;
			bj<=0;
			bpos<=(others=>'1');
			t_we<='0';
			fp_we<='0';
			fh_we<='0';
			ovl_we<='0';
			t_ra<=(others=>'0');
			fp_ra<=(others=>'0');
			fh_ra<=(others=>'0');
			ovmode<='0';
			ct_we<='0';
			csi_we<='0';
			csp_we<='0';
			cfh_we<='0';
			ct_ra<=(others=>'0');
			csi_ra<=(others=>'0');
			csp_ra<=(others=>'0');
			cfh_ra<=(others=>'0');
			mfm<='0';
			-- mfm0<='0';
			-- mfm1<='0';
			trackno<=(others=>'0');
			track_curaddr<=(others=>'0');
			img_rd<='0';
			img_wr<='0';
			img_sync<='0';
			img_wrdat<=(others=>'0');
			trackrd<='0';
			trackwr<='0';
			tracksync<='0';
			crcclr<='0';
			crcwr<='0';
			crcwrdat<=(others=>'0');
			numsect<=(others=>'0');
			sectcount<=(others=>'0');
			fddone<='0';
			diskmode0<="00";
			diskmode1<="00";
			diskmode<="00";
			ddmode<='0';
			dstep0<='1';
			dstep1<='1';
			ambuf0:=(others=>'0');
			ambuf1:=(others=>'0');
			ambuf2:=(others=>'0');
			ambuf3:=(others=>'0');
			trackwrote<='0';
			fde_modeset<="00";
		elsif(sclk' event and sclk='1')then
			img_rd<='0';
			img_wr<='0';
			img_sync<='0';
			trackrd<='0';
			trackwr<='0';
			tracksync<='0';
			crcclr<='0';
			crcwr<='0';
			fde_modeset<="00";
			fddone<='0';
			t_we<='0';
			fp_we<='0';
			fh_we<='0';
			ovl_we<='0';
			ct_we<='0';
			csi_we<='0';
			csp_we<='0';
			cfh_we<='0';
			if(swait>0)then
				swait:=swait-1;
			else
				case fdstate is
				when fs_idle =>
					if(proc_begin='1')then
						case emustate is
						when es_fload0 | es_fsave0 =>
							img_addr<=x"00000000";
							img_unit<='0';
							img_rd<='1';
							fdstate<=fs_loadtbl0;
						when es_fload1 | es_fsave1 =>
							img_addr<=x"00000000";
							img_unit<='1';
							img_rd<='1';
							fdstate<=fs_loadtbl0;
						when others=>
						end case;
					end if;
				when fs_loadtbl0 =>
					if(img_busy='0')then
						img_addr<=x"00000200";
						trackno<=(others=>'0');
						img_rd<='1';
						fdstate<=fs_loadtbl1;
					end if;
				when fs_loadtbl1 =>
					if(img_busy='0')then
						swait:=2;
						case emustate is
						when es_fload0 | es_fload1 =>
							tbladdr<=x"06";
							fdstate<=fs_loadmode;
						when es_fsave0 | es_fsave1 =>
							tbladdr<=x"06";
							fdstate<=fs_svmode;
						when others =>
							fdstate<=fs_idle;
						end case;
						trackno<=(others=>'0');
						sectcount<=(others=>'0');
					end if;
				when fs_loadmode =>
					diskmode<=haddr(29) & '0';
					ddmode<=haddr(28) or haddr(29);
					case emustate is
					when es_fload0 | es_fsave0 =>
						wrprot(0)<=haddr(20);
						ddm(0)<=haddr(28) or haddr(29);
						diskmode0<=haddr(29) & '0';
						dstep0<=not (haddr(28) or haddr(29));
						fde_modeset(0)<='1';
					when es_fload1 | es_fsave1 =>
						wrprot(1)<=haddr(20);
						ddm(1)<=haddr(28) or haddr(29);
						diskmode1<=haddr(29) & '0';
						dstep1<=not (haddr(28) or haddr(29));
						fde_modeset(1)<='1';
					when others =>
					end case;
					tbladdr<=trackno+x"08";
					swait:=2;
					fdstate<=fs_loadshead;
				when fs_loadshead =>
					cursecthead<=haddr;
					ovmode<='0';
					ovl<='0';
					ovlseen<='0';
					ovlsmall<='0';
					fcnt<=0;
					ovlkeep<='0';
					ovl_we<='1';
					ovl_wd<='0';
					ovlcopy<='0';
					fn<=0;
					bj<=0;
					bpos<=(others=>'1');
					case emustate is
					when es_fload0 | es_fsave0 =>
						img_unit<='0';
					when es_fload1 | es_fsave1 =>
						img_unit<='1';
					when others=>
					end case;
					if(haddr=x"00000000")then				-- unformat
						track_curaddr<=(others=>'0');
						trackwrdat<=x"024e";	-- unformatted: fill with MFM so a turn takes as long as a formatted one (FM words play at half speed)
						trackwr<='1';
						fdstate<=fs_gap4;
					else
						img_addr<=haddr+x"06";
						img_rd<='1';
						fdstate<=fs_loadsheadw;
					end if;
				when fs_loadsheadw =>
					if(img_busy='0')then
						mfm<=not img_rddat(6);
						case emustate is
						-- when es_fload0 =>
							-- mfm0<=not img_rddat(6);
						-- when es_fload1 =>
							-- mfm1<=not img_rddat(6);
						when others =>
						end case;
						track_curaddr<=(others=>'0');
						if(img_rddat(6)='0')then
							bytecount<=80;
							trackwrdat<=x"024e";
						else
							bytecount<=40;
							trackwrdat<=x"00ff";
						end if;
						trackwr<='1';
						swait:=1;
						img_addr<=haddr+x"04";
						img_rd<='1';
						fdstate<=fs_loadsectorsl;
					end if;
				when fs_loadsectorsl =>
					if(img_busy='0')then
						numsect(7 downto 0)<=img_rddat;
						img_addr<=haddr+x"05";
						swait:=1;
						fdstate<=fs_loadsectorsh;
					end if;
				when fs_loadsectorsh =>
					if(img_busy='0')then
						numsect(15 downto 8)<=img_rddat;
						sectcount<=(others=>'0');
						fdstate<=fs_psinit;
					end if;
				when fs_psinit =>
					-- pre-scan the sector headers: use the standard GAP3 only if the whole track fits
					pscnt<=numsect;
					psaddr<=cursecthead;
					pssum<="00" & x"0092";		-- 146: GAP4a, sync, IAM, GAP1
					pssum2<="00" & x"0092";
					psov<='0';
					ps4k<='0';
					if(numsect=x"0000")then				-- a header with no sectors: unformatted, like haddr=0
						usestd<='0';
						track_curaddr<=(others=>'0');
						trackwrdat<=x"00ff";
						trackwr<='1';
						fdstate<=fs_gap4;
					else
						usestd<='1';
						img_addr<=cursecthead+x"06";
						img_rd<='1';
						swait:=1;
						fdstate<=fs_psden;
					end if;
				when fs_psden =>
					if(img_busy='0')then
						if(img_rddat(6)='1')then	-- FM sector in the track
							usestd<='0';
							fdstate<=fs_gap0;
						else
							img_addr<=psaddr+x"0e";
							img_rd<='1';
							swait:=1;
							fdstate<=fs_pslenl;
						end if;
					end if;
				when fs_pslenl =>
					if(img_busy='0')then
						pslen(7 downto 0)<=img_rddat;
						img_addr<=psaddr+x"0f";
						img_rd<='1';
						swait:=1;
						fdstate<=fs_pslenh;
					end if;
				when fs_pslenh =>
					if(img_busy='0')then
						pslen(15 downto 8)<=img_rddat;
						fdstate<=fs_psadd;
					end if;
				when fs_psadd =>
					-- 62 bytes of sync, marks, ID, CRCs and GAP2 per MFM sector
					pssum<=pssum+("00" & efflen(pslen))+std_logic_vector(ieee.numeric_std.to_unsigned(62+stdgap(pslen),18));
					if(pssum2<"01" & x"0000")then
						pssum2<=pssum2+("00" & efflen(pslen))+std_logic_vector(ieee.numeric_std.to_unsigned(88,18));
					end if;
					if(pslen>=x"1800")then
						psov<='1';
					elsif(pslen>=x"1000")then
						ps4k<='1';
					end if;
					psaddr<=psaddr+pslen+x"10";
					pscnt<=pscnt-1;
					fdstate<=fs_pschk;
				when fs_pschk =>
					if(pssum>pslimit)then
						usestd<='0';
					end if;
					if(pscnt=x"0000")then
						if(mfm='1' and diskmode(1)='0' and ddmode='0' and numsect<=x"0040" and psov='0' and ps4k='0'
							and pssum2>std_logic_vector(ieee.numeric_std.to_unsigned(8032,18)))then
							--in order it does not fit even in the long track (sectors behind would be lost): plan it
							fdstate<=fs_pl0;
						else
							fdstate<=fs_gap0;
						end if;
					else
						img_addr<=psaddr+x"06";
						img_rd<='1';
						swait:=1;
						fdstate<=fs_psden;
					end if;
				when fs_gap0 =>
					if(trackbusy='0')then
						if(bytecount>1)then
							bytecount<=bytecount-1;
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
							swait:=1;
						else
							if(mfm='1')then
								trackwrdat<=x"0200";
								bytecount<=12;
							else
								trackwrdat<=x"0000";
								bytecount<=6;
							end if;
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
							swait:=1;
							fdstate<=fs_syncp;
						end if;
					end if;
				when fs_syncp =>
					if(trackbusy='0')then
						if(bytecount>1)then
							bytecount<=bytecount-1;
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
							swait:=1;
						else
							if(mfm='1')then
								trackwrdat<=x"03c2";
								bytecount<=3;
								fdstate<=fs_am0;
							else
								trackwrdat<=x"01fc";
								fdstate<=fs_am1;
							end if;
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
							swait:=1;
						end if;
					end if;
				when fs_am0 =>
					if(trackbusy='0')then
						if(bytecount>1)then
							bytecount<=bytecount-1;
						else
							trackwrdat<=x"02fc";
							fdstate<=fs_am1;
						end if;
						track_curaddr<=track_curaddr+1;
						trackwr<='1';
						swait:=1;
					end if;
				when fs_am1 =>
					if(trackbusy='0')then
						if(mfm='1')then
							trackwrdat<=x"024e";
							bytecount<=50;
						else
							trackwrdat<=x"00ff";
							bytecount<=26;
						end if;
						track_curaddr<=track_curaddr+1;
						trackwr<='1';
						swait:=1;
						fdstate<=fs_gap1;
					end if;
				when fs_gap1 =>
					if(trackbusy='0')then
						if(bytecount>1)then
							bytecount<=bytecount-1;
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
							swait:=1;
						else
							if(mfm='1')then
								trackwrdat<=x"0200";
								bytecount<=12;
							else
								trackwrdat<=x"0000";
								bytecount<=6;
							end if;
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
							swait:=1;
							fdstate<=fs_synci;
						end if;
					end if;
				when fs_synci =>
					if(trackbusy='0')then
						if(bytecount>1)then
							bytecount<=bytecount-1;
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
							swait:=1;
						else
							track_curaddr<=track_curaddr+1;
							crcclr<='1';
							if(mfm='1')then
								trackwrdat<=x"03a1";
								crcwrdat<=x"a1";
								fdstate<=fs_iam0;
							else
								trackwrdat<=x"01fe";
								crcwrdat<=x"fe";
								fdstate<=fs_C;
							end if;
							trackwr<='1';
							crcwr<='1';
							img_addr<=cursecthead+x"00";
							img_rd<='1';
							swait:=1;
						end if;
					end if;
				when fs_iam0 =>
					if(trackbusy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat<=x"03a1";
						trackwr<='1';
						crcwrdat<=x"a1";
						crcwr<='1';
						swait:=1;
						fdstate<=fs_iam1;
					end if;
				when fs_iam1 =>
					if(trackbusy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat<=x"03a1";
						trackwr<='1';
						crcwrdat<=x"a1";
						crcwr<='1';
						swait:=1;
						fdstate<=fs_iam2;
					end if;
				when fs_iam2 =>
					if(trackbusy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat<=x"02fe";
						trackwr<='1';
						crcwrdat<=x"fe";
						crcwr<='1';
						swait:=1;
						fdstate<=fs_C;
					end if;
				when fs_C =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						trackwrdat(7 downto 0)<=img_rddat;
						trackwr<='1';
						crcwrdat<=img_rddat;
						crcwr<='1';
						fdstate<=fs_H;
						img_addr<=cursecthead+x"01";
						swait:=1;
					end if;
				when fs_H =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						trackwrdat(7 downto 0)<=img_rddat;
						trackwr<='1';
						crcwrdat<=img_rddat;
						crcwr<='1';
						fdstate<=fs_R;
						img_addr<=cursecthead+x"02";
						swait:=1;
					end if;
				when fs_R =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						trackwrdat(7 downto 0)<=img_rddat;
						trackwr<='1';
						crcwrdat<=img_rddat;
						crcwr<='1';
						fdstate<=fs_N;
						img_addr<=cursecthead+x"03";
						swait:=1;
					end if;
				when fs_N =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						trackwrdat(7 downto 0)<=img_rddat;
						trackwr<='1';
						crcwrdat<=img_rddat;
						crcwr<='1';
						fdstate<=fs_crci0;
						img_addr<=cursecthead+x"08";
						img_rd<='1';
						swait:=1;
					end if;
				when fs_crci0 =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						sectstatus<=img_rddat;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						if(img_rddat=x"a0")then
							trackwrdat(7 downto 0)<=not crcdat(15 downto 8);
						else
							trackwrdat(7 downto 0)<=crcdat(15 downto 8);
						end if;
						trackwr<='1';
						img_addr<=cursecthead+x"07";
						fdstate<=fs_crci1;
						swait:=1;
					end if;
				when fs_crci1 =>
					if(trackbusy='0' and img_busy='0')then
						deleted<=img_rddat(4);
						track_curaddr<=track_curaddr+1;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						if(sectstatus=x"a0")then
							trackwrdat(7 downto 0)<=not crcdat(7 downto 0);
						else
							trackwrdat(7 downto 0)<=crcdat(7 downto 0);
						end if;
						trackwr<='1';
						img_addr<=cursecthead+x"0e";
						img_rd<='1';
						fdstate<=fs_ssizel;
						swait:=1;
					end if;
				when fs_ssizel =>
					if(img_busy='0')then
						sectlen(7 downto 0)<=img_rddat;
						img_addr<=cursecthead+x"0f";
						img_rd<='1';
						fdstate<=fs_ssizeh;
					end if;
				when fs_ssizeh =>
					--wait for the track buffer too: when the ID CRC byte before it is the first word of a new 256-word block,
					--the buffer stores it only after the block move, with the address and data set here
					if(img_busy='0' and trackbusy='0')then
						sectlen(15 downto 8)<=img_rddat;
						img_addr<=cursecthead+x"10";
						img_rd<='1';
						nxtsecthead<=cursecthead+(img_rddat & sectlen(7 downto 0))+x"10";
						if(ovlseen='0' and (img_rddat & sectlen(7 downto 0))>=x"1800")then
							ovlseen<='1';
						end if;
						if(mfm='1' and diskmode(1)='0' and ddmode='0' and ovlseen='0' and ovl='0' and ((img_rddat & sectlen(7 downto 0))>=x"1800"
							or ((img_rddat & sectlen(7 downto 0))>=x"1000" and sectstatus=x"b0" and numsect>(sectcount+1)))
							and (numsect-sectcount-1)<=x"0040")then
							ovl<='1';
							if((img_rddat & sectlen(7 downto 0))>=x"1800")then
								ovlsmall<='0';
							else
								ovlsmall<='1';
							end if;
							ovlcopy<='1';
							ovlimg<=cursecthead+x"10";
							ovl_we<='1';
							ovl_wd<='1';
						end if;
						if(mfm='0')then
							gap3sel<=13;
						elsif(ovmode='1' and csp_q(1 downto 0)/="00" and csp_q(1 downto 0)/="11")then
							gap3sel<=0;	-- placed in the data of a sector before it: that data goes on after it
						elsif(usestd='1')then
							gap3sel<=stdgap(img_rddat & sectlen(7 downto 0));
						else
							gap3sel<=26;
						end if;
						track_curaddr<=track_curaddr+1;
						if(mfm='1')then
							bytecount<=22;
							trackwrdat<=x"024e";
						else
							bytecount<=11;
							trackwrdat<=x"00ff";
						end if;
						trackwr<='1';
						swait:=1;
						fdstate<=fs_gap2;
					end if;
				when fs_gap2 =>
					if(trackbusy='0')then
						track_curaddr<=track_curaddr+1;
						if(bytecount>1)then
							bytecount<=bytecount-1;
						else
							if(mfm='1')then
								bytecount<=12;
								trackwrdat<=x"0200";
							else
								bytecount<=6;
								trackwrdat<=x"0000";
							end if;
							fdstate<=fs_syncd;
							if(sectlen=x"0000")then
								sectlen<=x"0080";
							end if;
						end if;
						trackwr<='1';
						swait:=1;
					end if;
				when fs_syncd =>
					if(trackbusy='0')then
						track_curaddr<=track_curaddr+1;
						if(bytecount>1)then
							bytecount<=bytecount-1;
						else
							crcclr<='1';
							if(mfm='1')then
								trackwrdat<=x"03a1";
								crcwrdat<=x"a1";
								fdstate<=fs_dam0;
							else
								if(deleted='1')then
									trackwrdat<=x"01f8";
									crcwrdat<=x"f8";
								else
									trackwrdat<=x"01fb";
									crcwrdat<=x"fb";
								end if;
								fdstate<=fs_dat;
							end if;
							crcwr<='1';
						end if;
						trackwr<='1';
						swait:=1;
					end if;
				when fs_dam0 =>
					if(trackbusy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat<=x"03a1";
						crcwrdat<=x"a1";
						trackwr<='1';
						crcwr<='1';
						fdstate<=fs_dam1;
						swait:=1;
					end if;
				when fs_dam1 =>
					if(trackbusy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat<=x"03a1";
						crcwrdat<=x"a1";
						trackwr<='1';
						crcwr<='1';
						fdstate<=fs_dam2;
						swait:=1;
					end if;
				when fs_dam2 =>
					if(trackbusy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						if(deleted='1')then
							trackwrdat<=x"02f8";
							crcwrdat<=x"f8";
						else
							trackwrdat<=x"02fb";
							crcwrdat<=x"fb";
						end if;
						trackwr<='1';
						crcwr<='1';
						if(ovlcopy='1')then
							ovlstart<=track_curaddr+2;
							ovllen<=sectlen;
							if(numsect>(sectcount+1))then
								--prescan the long sector's data before writing it
								soff<=(others=>'0');
								sr<=(others=>'0');
								tn<=0;
								fdstate<=fs_ovs0;
							else
								fdstate<=fs_dat;
							end if;
						else
							fdstate<=fs_dat;
						end if;
						swait:=1;
					end if;
				when fs_dat =>
					if(ovmode='1' and trackbusy='0' and img_busy='0' and track_curaddr>="01111101000000")then
						--8000: a long turn reads 0 to 7999 (the buffer is filled up to 8031). The data of a sector is not cut at the end of the turn: in a normal
						--turn the rest is not read (it wraps to the start), and in a long one it reads as recorded in the d88 up to the GAP4 after the last sector
						bytecount<=0;
						csp_ra<=sectcount(5 downto 0)+1;	-- where the next sector goes
						swait:=1;
						fdstate<=fs_gap3;
					elsif(ovlcopy='1' and trackbusy='0' and img_busy='0' and bj<fn and (track_curaddr+1)>=bpos)then
						--the place of the next d88 sector behind the long sector: build it there
						track_curaddr<=bpos;
						bcap<=bcapn;
						ovlcopy<='0';
						nxtsecthead<=fh_q;
						sectcount<=numsect-std_logic_vector(ieee.numeric_std.to_unsigned(fn-bj+1,16));
						bj<=bj+1;
						img_addr<=fh_q+6;
						img_rd<='1';
						swait:=1;
						fdstate<=fs_nxtsector;
					elsif(ovl='1' and ovlcopy='0' and trackbusy='0' and img_busy='0' and (track_curaddr+1)>=bcap)then
						--its data runs into the next sector (they overlap on the disk): go on with the long sector's data
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(bj mod 64,6));
						swait:=1;
						fdstate<=fs_ovn0;
					elsif(ovlcopy='1' and trackbusy='0' and img_busy='0' and track_curaddr>="01100001101001")then
						--the long sector's data runs over its own start on the real disk: stop at the end of the turn
						trackwrdat<=x"024e";
						fdstate<=fs_gap4;
						if(track_curaddr>=tracklen)then
							--the last sector behind it did not fit in the turn: a long track, as for other tracks
							diskmode(0)<='1';
							if(img_unit='0')then
								diskmode0(0)<='1';
								fde_modeset(0)<='1';
							else
								diskmode1(0)<='1';
								fde_modeset(1)<='1';
							end if;
						end if;
					elsif(trackbusy='0' and img_busy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						trackwrdat(7 downto 0)<=img_rddat;
						crcwrdat<=img_rddat;
						trackwr<='1';
						crcwr<='1';
						if(sectlen>x"0001")then
							sectlen<=sectlen-1;
							img_addr<=img_addr+1;
							img_rd<='1';
						else
							fdstate<=fs_crcd0;
						end if;
						swait:=1;
					end if;
				when fs_crcd0 =>
					if(ovl='1' and ovlcopy='0' and trackbusy='0' and img_busy='0' and (track_curaddr+2)>=bcap)then
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(bj mod 64,6));
						swait:=1;
						fdstate<=fs_ovn0;
					elsif(trackbusy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						if(sectstatus=x"b0")then
							trackwrdat(7 downto 0)<=not crcdat(15 downto 8);
						else
							trackwrdat(7 downto 0)<=crcdat(15 downto 8);
						end if;
						trackwr<='1';
						fdstate<=fs_crcd1;
						swait:=1;
					end if;
				when fs_crcd1 =>
					if(trackbusy='0' and crcbusy='0')then
						track_curaddr<=track_curaddr+1;
						trackwrdat(15 downto 10)<=(others=>'0');
						trackwrdat(9 downto 8)<=mfm & '0';
						if(sectstatus=x"b0")then
							trackwrdat(7 downto 0)<=not crcdat(7 downto 0);
						else
							trackwrdat(7 downto 0)<=crcdat(7 downto 0);
						end if;
						trackwr<='1';
						if(ovl='1' and ovlcopy='0')then
							fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(bj mod 64,6));
							fdstate<=fs_ovn0;
						else
							fdstate<=fs_gap3;
							bytecount<=gap3sel;
							csp_ra<=sectcount(5 downto 0)+1;	-- where the next sector goes (planned track)
						end if;
						swait:=1;
					end if;
				when fs_gap3 =>
					if(trackbusy='0')then
						track_curaddr<=track_curaddr+1;
						if(bytecount>0)then
							bytecount<=bytecount-1;
							if(mfm='1')then
								trackwrdat<=x"024e";
							else
								trackwrdat<=x"00ff";
							end if;
							trackwr<='1';
						else
							if(numsect=(sectcount+1))then
								if(mfm='1')then
									trackwrdat<=x"024e";
								else
									trackwrdat<=x"00ff";
								end if;
								trackwr<='1';
								fdstate<=fs_gap4;
								if(ovmode='1' and (track_curaddr+1)<"01100001101010")then
									--the rest of the track after it is GAP, from the end of the turn at least
									track_curaddr<="01100001101010";	-- 6250
								elsif(track_curaddr>tracklen)then
									diskmode(0)<='1';
									if(img_unit='0')then
										diskmode0(0)<='1';
										fde_modeset(0)<='1';
									else
										diskmode1(0)<='1';
										fde_modeset(1)<='1';
									end if;
								end if;
							else
								if(ovmode='1')then
									track_curaddr<=csp_q(22 downto 9)-12;	-- the sync before its planned ID
								end if;
								img_addr<=nxtsecthead+6;
								img_rd<='1';
								fdstate<=fs_nxtsector;
							end if;
						end if;
					end if;
				when fs_gap4 =>
					if(trackbusy='0')then
						if(track_curaddr<(diskmode(1) & "1111101000000"))then	-- '0'/'1' & x"1F40" -- D=8032, H=16624
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
						else
							if(trackno<tracks)then
								trackno<=trackno+1;
								tbladdr<=trackno+x"09";
								swait:=2;
								fdstate<=fs_nxttrack;
							else
								tracksync<='1';
								fddone<='1';
								fdstate<=fs_IDLE;
							end if;
						end if;
					end if;
				when fs_nxtsector =>
					if(img_busy='0')then
						sectcount<=sectcount+1;
						cursecthead<=nxtsecthead;
						mfm<=not img_rddat(6);	-- FM/MFM can be mixed in a track, so reconfigure it here.
						if(img_rddat(6)='0')then
							trackwrdat<=x"0200";
							bytecount<=12;
						else
							trackwrdat<=x"0000";
							bytecount<=6;
						end if;
						trackwr<='1';
						swait:=1;
						fdstate<=fs_synci;
					end if;
				when fs_ovs0 =>
					--prescan: read the long sector's data up to the end of the turn as a bit stream
					if(soff>=ovllen or (ovlstart+soff(13 downto 0))>"01100001101001")then
						mhead<=nxtsecthead;
						mj<=0;
						mk<=0;
						fn<=conv_integer(numsect-sectcount-1);
						fany<='0';
						fcnt<=0;
						pgood<='0';
						ovlbad<='0';
						fdstate<=fs_ovm0;
					else
						img_addr<=ovlimg+(x"0000" & soff);
						img_rd<='1';
						swait:=1;
						fdstate<=fs_ovs1;
					end if;
				when fs_ovs1 =>
					if(img_busy='0')then
						sbyte<=img_rddat;
						sbit<=7;
						fdstate<=fs_ovs2;
					end if;
				when fs_ovs2 =>
					sr<=sr(62 downto 0) & sbyte(sbit);
					if(sr(62 downto 31)=x"A1A1A1FE" and tn<32)then
						--A1 A1 A1 FE C H R N ends with this bit: its first A1 starts 63 bits back
						ovb:=(soff(13 downto 0) & "000")+std_logic_vector(ieee.numeric_std.to_unsigned(7-sbit,17))-60;
						t_wa<=std_logic_vector(ieee.numeric_std.to_unsigned(tn,5));
						t_wd<=sr(30 downto 0) & sbyte(sbit) & (ovlstart+ovb(16 downto 3)-12);
						t_we<='1';
						tn<=tn+1;
					end if;
					if(sbit=0)then
						soff<=soff+1;
						fdstate<=fs_ovs0;
					else
						sbit<=sbit-1;
					end if;
				when fs_ovm0 =>
					--match the d88 sectors behind it with the IDs found, in order
					if(mj>=fn)then
						fdstate<=fs_ovi0;
					else
						fh_wa<=std_logic_vector(ieee.numeric_std.to_unsigned(mj mod 64,6));
						fh_wd<=mhead;
						fh_we<='1';
						img_addr<=mhead;
						img_rd<='1';
						swait:=1;
						fdstate<=fs_ovm1;
					end if;
				when fs_ovm1 =>
					if(img_busy='0')then
						mchrn(31 downto 24)<=img_rddat; img_addr<=mhead+1; img_rd<='1'; swait:=1; fdstate<=fs_ovm2;
					end if;
				when fs_ovm2 =>
					if(img_busy='0')then
						mchrn(23 downto 16)<=img_rddat; img_addr<=mhead+2; img_rd<='1'; swait:=1; fdstate<=fs_ovm3;
					end if;
				when fs_ovm3 =>
					if(img_busy='0')then
						mchrn(15 downto 8)<=img_rddat; img_addr<=mhead+3; img_rd<='1'; swait:=1; fdstate<=fs_ovm4;
					end if;
				when fs_ovm4 =>
					if(img_busy='0')then
						mchrn(7 downto 0)<=img_rddat; img_addr<=mhead+x"0e"; img_rd<='1'; swait:=1; fdstate<=fs_ovm5;
					end if;
				when fs_ovm5 =>
					if(img_busy='0')then
						mlen<=img_rddat; img_addr<=mhead+x"0f"; img_rd<='1'; swait:=1; fdstate<=fs_ovm6;
					end if;
				when fs_ovm6 =>
					if(img_busy='0')then
						mhead<=mhead+(img_rddat & mlen)+x"10";
						mlen16<=img_rddat & mlen;
						img_addr<=mhead+x"08"; img_rd<='1'; swait:=1;
						fdstate<=fs_ovm6s;
					end if;
				when fs_ovm6s =>
					if(img_busy='0')then
						mst<=img_rddat;
						t_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(mk mod 32,5));
						mq<=mk;
						swait:=1;
						fdstate<=fs_ovm7;
					end if;
				when fs_ovm7 =>
					--the first ID found from mk on that matches; IDs passed over are not used again
					fp_wa<=std_logic_vector(ieee.numeric_std.to_unsigned(mj mod 64,6));
					if(mq<tn and t_q(45 downto 14)=mchrn)then
						fp_wd<='1' & t_q(13 downto 0); fp_we<='1'; fany<='1'; fcnt<=fcnt+1; mk<=mq+1;
						--ID, gap, data mark, data and CRC take 62 bytes more than the data;
						--one more for an ID found off the byte boundary, whose place is rounded down
						if(pgood='1' and ("000" & t_q(13 downto 0))<pend)then
							ovlbad<='1';
						end if;
						if(mst=x"b0")then
							pgood<='0';
						else
							pgood<='1';
						end if;
						pend<=("000" & t_q(13 downto 0))+('0' & efflen(mlen16))+63;
						mj<=mj+1;
						fdstate<=fs_ovm0;
					elsif((mq+1)<tn)then
						mq<=mq+1;
						t_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((mq+1) mod 32,5));
						swait:=1;
					else
						fp_wd<=(others=>'0'); fp_we<='1';
						mj<=mj+1;
						fdstate<=fs_ovm0;
					end if;
				when fs_ovi0 =>
					--the smallest distance between two neighbors found
					if(fany='0' or (ovlsmall='1' and (fcnt<fn or ovlbad='1' or (pgood='1' and pend>std_logic_vector(ieee.numeric_std.to_unsigned(6250,17))))))then
						--no ID found (or, for a long sector of less than 6144 bytes, not all of them, one would cut a good sector,
						--or the last one has a good CRC and would run past the end of the turn): lay out the track as before
						--a long sector of 6144 bytes or more is still not written back (sectors past the end of the track would be dropped from the image)
						ovl<='0';
						fn<=0;
						bj<=0;
						bpos<=(others=>'1');
						--a track with a bad-CRC sector of 4096 to 6143 bytes that holds IDs is still not written back:
						--sectors the old layout loses would be dropped from the image
						ovl_we<='1';
						--(a later long sector on the same track does not clear the mark an earlier one kept)
						ovl_wd<=ovlkeep or (not ovlsmall) or fany;
						ovlkeep<=ovlkeep or (not ovlsmall) or fany;
						ovlcopy<='0';
						img_addr<=ovlimg;
						img_rd<='1';
						sectlen<=ovllen;
						swait:=1;
						fdstate<=fs_dat;
					else
						minstep<=(others=>'1');
						ilo<=0;
						fp_ra<=(others=>'0');
						swait:=1;
						fdstate<=fs_ovi1s;
					end if;
				when fs_ovi1s =>
					prevok<=fp_q(14);
					prevpos<=fp_q(13 downto 0);
					fp_ra<="000001";
					swait:=1;
					fdstate<=fs_ovi1;
				when fs_ovi1 =>
					--fp_q is the entry ilo+1, prevok/prevpos the entry ilo
					if((ilo+1)>=fn)then
						ilo<=64;
						ihi<=0;
						fp_ra<=(others=>'0');
						swait:=1;
						fdstate<=fs_ovi2;
					else
						if(prevok='1' and fp_q(14)='1' and (fp_q(13 downto 0)-prevpos)<minstep)then
							minstep<=fp_q(13 downto 0)-prevpos;
						end if;
						prevok<=fp_q(14);
						prevpos<=fp_q(13 downto 0);
						ilo<=ilo+1;
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((ilo+2) mod 64,6));
						swait:=1;
					end if;
				when fs_ovi2 =>
					--fill the d88 sectors whose ID was not found: evenly between the found neighbors
					--fp_q is the entry ihi
					if(ihi>=fn)then
						bj<=0;
						fp_ra<=(others=>'0');
						swait:=1;
						fdstate<=fs_ovn0;
					elsif(fp_q(14)='1')then
						ilo<=ihi; ilopos<=fp_q(13 downto 0); ihi<=ihi+1;
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((ihi+1) mod 64,6));
						swait:=1;
					elsif(ilo=64)then
						ihi<=ihi+1;	-- nothing found before it: not placed
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((ihi+1) mod 64,6));
						swait:=1;
					else
						ifill<=std_logic_vector(ieee.numeric_std.to_unsigned(ihi,14));
						inum<=std_logic_vector(ieee.numeric_std.to_unsigned(ihi,14));
						fdstate<=fs_ovi3;
					end if;
				when fs_ovi3 =>
					--look for the next found one (fp_q is the entry inum)
					if(conv_integer(inum)>=fn)then
						iq<=minstep;
						ovacc<=("00000000000000" & ilopos)+minstep;
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(ihi mod 64,6));
						swait:=1;
						fdstate<=fs_ovi5;
					elsif(fp_q(14)='1')then
						--step = (fpos(next) - ilopos) / (next - ilo)
						iq<=(others=>'0');
						ifill<=fp_q(13 downto 0)-ilopos;
						inum<=inum-std_logic_vector(ieee.numeric_std.to_unsigned(ilo,14));
						fdstate<=fs_ovi4;
					else
						inum<=inum+1;
						fp_ra<=inum(5 downto 0)+1;
						swait:=1;
					end if;
				when fs_ovi4 =>
					if(ifill>=inum)then
						ifill<=ifill-inum; iq<=iq+1;
					else
						if(iq<minstep)then
							minstep<=iq;
						end if;
						ovacc<=("00000000000000" & ilopos)+iq;
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(ihi mod 64,6));
						swait:=1;
						fdstate<=fs_ovi5;
					end if;
				when fs_ovi5 =>
					--place ihi, ihi+1, ... until a found one, iq apart from ilo (ovacc = ilopos + iq*(ihi-ilo))
					if(ihi>=fn or fp_q(14)='1')then
						fdstate<=fs_ovi2;
					else
						if(ovacc<std_logic_vector(ieee.numeric_std.to_unsigned(6250,28)) and iq/="11111111111111")then
							fp_wa<=std_logic_vector(ieee.numeric_std.to_unsigned(ihi mod 64,6));
							fp_wd<='1' & ovacc(13 downto 0);
							fp_we<='1';
						end if;
						ovacc<=ovacc+iq;
						ihi<=ihi+1;
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((ihi+1) mod 64,6));
						swait:=1;
					end if;
				when fs_ovn0 =>
					--the next sector to build and where the one after it goes (fp_q is the entry bj)
					if(bj>=fn)then
						bpos<=(others=>'1');
						fdstate<=fs_ovn1;
					elsif(fp_q(14)='1')then
						bpos<=fp_q(13 downto 0);
						bcapn<=(others=>'1');	-- the last one is written whole, even past the turn
						ihi<=bj+1;
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((bj+1) mod 64,6));
						swait:=1;
						fdstate<=fs_ovn1;
					else
						bj<=bj+1;
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((bj+1) mod 64,6));
						swait:=1;
					end if;
				when fs_ovn1 =>
					--fp_q is the entry ihi
					if(bj>=fn or ihi>=fn)then
						fdstate<=fs_ovres;
					elsif(fp_q(14)='1')then
						bcapn<=fp_q(13 downto 0);
						fdstate<=fs_ovres;
					else
						ihi<=ihi+1;
						fp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((ihi+1) mod 64,6));
						swait:=1;
					end if;
				when fs_ovres =>
					--write the long sector's data from where the track is now
					if(img_busy='0')then
						ovlcopy<='1';
						mfm<='1';	-- the sector built behind it may have been FM
						img_addr<=ovlimg+(x"0000" & "00" & (track_curaddr+1-ovlstart));
						img_rd<='1';
						sectlen<=x"7FFF";
						fh_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(bj mod 64,6));	-- the header of the sector built next
						swait:=1;
						fdstate<=fs_dat;
					end if;
				when fs_pl0 =>
					--plan the track: read the headers of all its sectors into the tables
					pj<=0;
					pn<=conv_integer(numsect(6 downto 0));
					phead<=cursecthead;
					ctn<=0;
					pany<='0';
					fdstate<=fs_plh0;
				when fs_plh0 =>
					if(pj>=pn)then
						pj<=0;
						pnxt<=x"009e";	-- 158: the ID of the first sector
						plast<=(others=>'0');
						fdstate<=fs_plf0;
					else
						img_addr<=phead;
						img_rd<='1';
						swait:=1;
						fdstate<=fs_plh1;
					end if;
				when fs_plh1 =>
					if(img_busy='0')then
						pchrn(31 downto 24)<=img_rddat; img_addr<=phead+1; img_rd<='1'; swait:=1; fdstate<=fs_plh2;
					end if;
				when fs_plh2 =>
					if(img_busy='0')then
						pchrn(23 downto 16)<=img_rddat; img_addr<=phead+2; img_rd<='1'; swait:=1; fdstate<=fs_plh3;
					end if;
				when fs_plh3 =>
					if(img_busy='0')then
						pchrn(15 downto 8)<=img_rddat; img_addr<=phead+3; img_rd<='1'; swait:=1; fdstate<=fs_plh4;
					end if;
				when fs_plh4 =>
					if(img_busy='0')then
						pchrn(7 downto 0)<=img_rddat; img_addr<=phead+8; img_rd<='1'; swait:=1; fdstate<=fs_plh5;
					end if;
				when fs_plh5 =>
					if(img_busy='0')then
						pst<=img_rddat; img_addr<=phead+x"0e"; img_rd<='1'; swait:=1; fdstate<=fs_plh6;
					end if;
				when fs_plh6 =>
					if(img_busy='0')then
						plen(7 downto 0)<=img_rddat; img_addr<=phead+x"0f"; img_rd<='1'; swait:=1; fdstate<=fs_plh7;
					end if;
				when fs_plh7 =>
					if(img_busy='0')then
						csi_wa<=std_logic_vector(ieee.numeric_std.to_unsigned(pj mod 64,6));
						csi_wd<=pchrn & img_rddat & plen(7 downto 0) & pst;
						csi_we<='1';
						cfh_wa<=std_logic_vector(ieee.numeric_std.to_unsigned(pj mod 64,6));
						cfh_wd<=phead;
						cfh_we<='1';
						phead<=phead+(img_rddat & plen(7 downto 0))+x"10";
						pj<=pj+1;
						fdstate<=fs_plh0;
					end if;
				when fs_plf0 =>
					--place the sectors in d88 order
					if(pj>=pn)then
						fdstate<=fs_plend;
					else
						csi_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(pj mod 64,6));
						cfh_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(pj mod 64,6));
						swait:=1;
						fdstate<=fs_plf1;
					end if;
				when fs_plf1 =>
					pchrn<=csi_q(55 downto 24);
					plen<=csi_q(23 downto 8);
					pst<=csi_q(7 downto 0);
					phead<=cfh_q;
					pset<='0';
					pfound<='0';
					ppar<=(others=>'0');
					pk<=0;
					ct_ra<=(others=>'0');
					swait:=1;
					fdstate<=fs_plf2;
				when fs_plf2 =>
					--rule 1: its ID is recorded in the data of a sector before it: the nearest such place after the ID of the
					--sector before (as in #146, marks passed over are not used)
					if(pk>=ctn)then
						fdstate<=fs_plf3;
					elsif(ct_q(31 downto 0)=pchrn)then
						mpar<=ct_q(51 downto 46);
						mrel<=ct_q(45 downto 32);
						csp_ra<=ct_q(51 downto 46);
						swait:=1;
						fdstate<=fs_plf2b;
					else
						pk<=pk+1;
						ct_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((pk+1) mod 64,6));
						swait:=1;
					end if;
				when fs_plf2b =>
					--its first A1 is the data of the parent plus the place of the mark
					vpos:=("00" & csp_q(22 downto 9))+x"0030"+("00" & mrel);
					if(vpos>plast and (pfound='0' or vpos<ppos))then
						pfound<='1';
						ppar<=mpar;
						ppos<=vpos;
					end if;
					pk<=pk+1;
					ct_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((pk+1) mod 64,6));
					swait:=1;
					fdstate<=fs_plf2;
				when fs_plf3 =>
					if(pfound='1')then
						phow<="01";
						pset<='1';
						pany<='1';
					end if;
					--a sector with a data CRC error may hold the marks of sectors written over it: scan its data
					if(pst=x"b0")then
						ptstart<=ctn;
						csoff<=(others=>'0');
						csr<=(others=>'0');
						fdstate<=fs_pls0;
					else
						fdstate<=fs_plf8;
					end if;
				when fs_pls0 =>
					--scan its data
					if(csoff>=plen)then
						fdstate<=fs_plf6;
					else
						img_addr<=phead+x"10"+(x"0000" & csoff);
						img_rd<='1';
						swait:=1;
						fdstate<=fs_pls1;
					end if;
				when fs_pls1 =>
					if(img_busy='0')then
						csb:=csr & img_rddat;
						if(csoff>=x"0008" and ctn<64 and csb(63 downto 32)=x"A1A1A1FE")then
							--A1 A1 A1 FE C H R N ends with this byte (on the byte boundaries of the data only)
							ct_wa<=std_logic_vector(ieee.numeric_std.to_unsigned(ctn mod 64,6));
							ct_wd<=std_logic_vector(ieee.numeric_std.to_unsigned(pj mod 64,6)) & (csoff(13 downto 0)-7) & csb(31 downto 0);
							ct_we<='1';
							ctn<=ctn+1;
						end if;
						csr<=csb(55 downto 0);
						csoff<=csoff+1;
						fdstate<=fs_pls0;
					end if;
				when fs_plf6 =>
					if(pset='1')then
						fdstate<=fs_plf8;
					else
						pi<=0;
						fdstate<=fs_plr0;
					end if;
				when fs_plr0 =>
					--rule 2: its own data holds the ID of a sector before it, one turn on
					if(pi>=pj)then
						fdstate<=fs_plf8;
					else
						csi_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(pi mod 64,6));
						csp_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(pi mod 64,6));
						swait:=1;
						fdstate<=fs_plr1;
					end if;
				when fs_plr1 =>
					ichrn<=csi_q(55 downto 24);
					ipos<="00" & csp_q(22 downto 9);
					pk<=ptstart;
					ct_ra<=std_logic_vector(ieee.numeric_std.to_unsigned(ptstart mod 64,6));
					swait:=1;
					fdstate<=fs_plr2;
				when fs_plr2 =>
					if(pk>=ctn)then
						pi<=pi+1;
						fdstate<=fs_plr0;
					elsif(ct_q(31 downto 0)=ichrn)then
						--its data starts a turn before that ID less the place of the mark; not before the sector before it,
						--and in the turn
						vcand:=ipos+std_logic_vector(ieee.numeric_std.to_unsigned(6250-48,16))-("00" & ct_q(45 downto 32));
						if((("00" & ct_q(45 downto 32))<=ipos+std_logic_vector(ieee.numeric_std.to_unsigned(6250-48,16))) and vcand>=pnxt
							and vcand<=std_logic_vector(ieee.numeric_std.to_unsigned(6249-48,16)))then	-- its data starts in the turn
							ppos<=vcand;
							phow<="10";
							pset<='1';
							pany<='1';
						end if;
						fdstate<=fs_plf8;
					else
						pk<=pk+1;
						ct_ra<=std_logic_vector(ieee.numeric_std.to_unsigned((pk+1) mod 64,6));
						swait:=1;
					end if;
				when fs_plf8 =>
					--rule 3: else after the sector before it, as when laid out in order
					if(pset='1')then
						vpos:=ppos;
						vhow:=phow;
					elsif(pj=0)then
						vpos:=x"009e";
						vhow:="00";
					else
						vpos:=pnxt;
						vhow:="00";
					end if;
					if(vpos>x"1F68")then
						--past the end of the buffer: kept at 8040, so that the positions do not wrap and nothing of it is written below 8000
						vpos:=x"1F68";
					end if;
					csp_wa<=std_logic_vector(ieee.numeric_std.to_unsigned(pj mod 64,6));
					csp_wd<=vpos(13 downto 0) & pfound & ppar & vhow;
					csp_we<='1';
					pnxt<=vpos+efflen(plen)+x"0058";	-- 48 to the data, its CRC, GAP3 26 and the sync
					plast<=vpos;
					pj<=pj+1;
					fdstate<=fs_plf0;
				when fs_plend =>
					csp_ra<=(others=>'0');
					if(pany='1')then
						--some sectors are placed in others: build the track at the planned places, not written back
						ovmode<='1';
						ovl_we<='1';
						ovl_wd<='1';
						track_curaddr<=(others=>'0');
						trackwrdat<=x"024e";
						trackwr<='1';
						swait:=1;
						fdstate<=fs_plfill;
					else
						fdstate<=fs_gap0;
					end if;
				when fs_plfill =>
					--the track starts as GAP; the sectors are written over it, each at its place
					if(trackbusy='0')then
						if(track_curaddr<"01111101011111")then	-- 8031
							track_curaddr<=track_curaddr+1;
							trackwr<='1';
							swait:=1;
						else
							track_curaddr<=(others=>'0');
							bytecount<=80;
							fdstate<=fs_gap0;
						end if;
					end if;
				when fs_nxttrack =>
					if(haddr=x"00000000")then
						if(trackno<tracks)then
							ovl_we<='1';
							ovl_wd<='0';
							track_curaddr<=(others=>'0');
							trackwrdat<=x"024e";	-- unformatted: MFM, as above
							trackwr<='1';
							fdstate<=fs_gap4;
						else
							fddone<='1';
							fdstate<=fs_IDLE;
						end if;
					else
						fdstate<=fs_loadshead;
					end if;
				when fs_svmode =>		-- the drives share diskmode: use the saved drive's mode
					if(emustate=es_fsave0)then
						diskmode<=diskmode0;
					else
						diskmode<=diskmode1;
					end if;
					ddmode<=haddr(28) or haddr(29);
					tbladdr<=x"07";
					swait:=2;
					fdstate<=fs_svsize;
				when fs_svsize =>
					scanlim<=tracklen;
					disksize<=(haddr+x"000001ff") and x"fffffe00";
					disksize0<=haddr;
					if(emustate=es_fsave0)then
						curfsize<=fsize0;
						if(fsize0>=x"00000200" and fsize0<=((haddr+x"000001ff") and x"fffffe00"))then relok<='1'; else relok<='0'; end if;
					else
						curfsize<=fsize1;
						if(fsize1>=x"00000200" and fsize1<=((haddr+x"000001ff") and x"fffffe00"))then relok<='1'; else relok<='0'; end if;
					end if;
					sizechg<='0';
					phdone<='0';
					tbladdr<=x"08";
					track_curaddr<=(others=>'0');
					trackrd<='1';
					ambuf0:=(others=>'0');
					ambuf1:=(others=>'0');
					ambuf2:=(others=>'0');
					ambuf3:=(others=>'0');
					trackwrote<='0';
					newlen<=(others=>'0');
					idcnt<=0;
					swait:=2;
					fdstate<=fs_scantrack;
				when fs_scantrack =>
					if(trackbusy='0')then
						if(track_curaddr<scanlim)then
							ambuf3:=ambuf2;
							ambuf2:=ambuf1;
							ambuf1:=ambuf0;
							ambuf0:=trackrddat(9 downto 0);
							
							if(ambuf3=("11" & x"a1") and ambuf2=("11" & x"a1") and ambuf1=("11" & x"a1") and ambuf0=("10" & x"fe"))then
								idcnt<=1;
								scanlim<=tracklenm;
							elsif(ambuf0=("01" & x"fe"))then
								idcnt<=1;
							elsif(idcnt=4)then
								sectcount<=sectcount+1;
								newlen<=newlen+sectbytes(trackrddat(7 downto 0));
								idcnt<=0;
							elsif(idcnt/=0)then
								idcnt<=idcnt+1;
							end if;
							trackwrote<=trackwrote or trackrddat(10);
							track_curaddr<=track_curaddr+1;
							trackrd<='1';
							swait:=2;
						else
							track_curaddr<=(others=>'0');
							numsect<=sectcount;
							sectcount<=(others=>'0');
							cursecthead<=haddr;
							if(trackwrote='0' or ovl_q='1' or sectcount=x"0000")then
								fdstate<=fs_savenexttrack;
							elsif(haddr=x"00000000")then	-- formatted a track the image did not have
								if(relok='1' and relfit='1')then
									fdstate<=fs_reloc;
								else
									fdstate<=fs_savenexttrack;
								end if;
							else
								if(disksize0<curfsize)then
									bound<=disksize0;
								else
									bound<=curfsize;
								end if;
								allotidx<=(others=>'0');
								tbladdr<=x"08";
								swait:=2;
								fdstate<=fs_allot;
							end if;
						end if;
					end if;
				when fs_allot =>
					if(haddr>cursecthead and haddr<bound)then
						bound<=haddr;
					end if;
					if((allotidx+1)<tracks)then
						allotidx<=allotidx+1;
						tbladdr<=allotidx+x"09";
						swait:=2;
					else
						fdstate<=fs_allotchk;
					end if;
				when fs_allotchk =>
					if(bound<=cursecthead or (bound-cursecthead)<newlen)then
						if(relok='1' and relfit='1')then
							fdstate<=fs_reloc;
						else
							fdstate<=fs_savenexttrack;
						end if;
					else
						fdstate<=fs_putgo;
					end if;
				when fs_reloc =>
					if(phdone='0')then		-- first move in this save: write 0 to the entries that point past the data
						phdone<='1';
						allotidx<=(others=>'0');
						tbladdr<=x"08";
						swait:=2;
						fdstate<=fs_phscan;
					else
						cursecthead<=disksize;
						disksize<=(disksize+newlen+x"000001ff") and x"fffffe00";
						sizechg<='1';
						wbyte<=0;
						fdstate<=fs_relocw;
					end if;
				when fs_phscan =>		-- tracktable reads entries past the disk size as 0, but the image keeps them,
										-- and a moved track would land where they point
					if(haddr=x"00000000" or haddr>=curfsize)then
						wbyte<=0;
						fdstate<=fs_phclrw;
					else
						fdstate<=fs_phnext;
					end if;
				when fs_phclrw =>
					if(img_busy='0')then
						img_addr<=(x"00000" & "00" & allotidx & "00")+x"20"+wbyte;
						img_wrdat<=x"00";
						img_wr<='1';
						swait:=2;
						if(wbyte=3)then
							fdstate<=fs_phnext;
						else
							wbyte<=wbyte+1;
						end if;
					end if;
				when fs_phnext =>
					if((allotidx+1)<tracks)then
						allotidx<=allotidx+1;
						tbladdr<=allotidx+x"09";
						swait:=2;
						fdstate<=fs_phscan;
					else
						fdstate<=fs_reloc;
					end if;
				when fs_relocw =>		-- the new disk size first, then the table entry
					if(img_busy='0')then
						if(wbyte<4)then
							img_addr<=x"0000001c"+wbyte;
							img_wrdat<=byteof(disksize,wbyte);
						else
							img_addr<=(x"00000" & "00" & trackno & "00")+x"20"+(wbyte-4);
							img_wrdat<=byteof(cursecthead,wbyte-4);
						end if;
						img_wr<='1';
						swait:=2;
						if(wbyte=7)then
							fdstate<=fs_putgo;
						else
							wbyte<=wbyte+1;
						end if;
					end if;
				when fs_putgo =>
					ambuf0:=(others=>'0');
					ambuf1:=(others=>'0');
					ambuf2:=(others=>'0');
					ambuf3:=(others=>'0');
					track_curaddr<=(others=>'0');
					trackrd<='1';
					swait:=2;
					fdstate<=fs_scaniam;
				when fs_scaniam =>
					if(trackbusy='0' and crcbusy='0')then
						ambuf3:=ambuf2;
						ambuf2:=ambuf1;
						ambuf1:=ambuf0;
						ambuf0:=trackrddat(9 downto 0);
						crcclr<='1';
						if(ambuf3=("11" & x"a1") and ambuf2=("11" & x"a1") and ambuf1=("11" & x"a1") and ambuf0=("10" & x"fe"))then
							crcwrdat<=x"a1";
							crcwr<='1';
							fdstate<=fs_crciam0;
						elsif(ambuf0=("01" & x"fe"))then
							crcwrdat<=x"fe";
							crcwr<='1';
							fdstate<=fs_stC;
						end if;
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
						swait:=2;
					end if;
				when fs_crciam0 =>
					if(crcbusy='0')then
						crcwrdat<=x"a1";
						crcwr<='1';
						fdstate<=fs_crciam1;
					end if;
				when fs_crciam1 =>
					if(crcbusy='0')then
						crcwrdat<=x"a1";
						crcwr<='1';
						fdstate<=fs_crciam2;
					end if;
				when fs_crciam2 =>
					if(crcbusy='0')then
						crcwrdat<=x"fe";
						crcwr<='1';
						fdstate<=fs_stc;
					end if;
				when fs_stC =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						img_addr<=cursecthead+x"00";
						img_wrdat<=trackrddat(7 downto 0);
						img_wr<='1';
						crcwrdat<=trackrddat(7 downto 0);
						crcwr<='1';
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
						swait:=2;
						fdstate<=fs_stH;
					end if;
				when fs_stH =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						img_addr<=cursecthead+x"01";
						img_wrdat<=trackrddat(7 downto 0);
						img_wr<='1';
						crcwrdat<=trackrddat(7 downto 0);
						crcwr<='1';
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
						swait:=2;
						fdstate<=fs_stR;
					end if;
				when fs_stR =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						img_addr<=cursecthead+x"02";
						img_wrdat<=trackrddat(7 downto 0);
						img_wr<='1';
						crcwrdat<=trackrddat(7 downto 0);
						crcwr<='1';
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
						swait:=2;
						fdstate<=fs_stN;
					end if;
				when fs_stN =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						img_addr<=cursecthead+x"03";
						img_wrdat<=trackrddat(7 downto 0);
						img_wr<='1';
						crcwrdat<=trackrddat(7 downto 0);
						crcwr<='1';
						case trackrddat(7 downto 0) is
						when x"00" =>
							sectlen<=x"0080";
						when x"01" =>
							sectlen<=x"0100";
						when x"02" =>
							sectlen<=x"0200";
						when x"03" =>
							sectlen<=x"0400";
						when x"04" =>
							sectlen<=x"0800";
						when x"05" =>
							sectlen<=x"1000";
						when x"06" =>
							sectlen<=x"2000";
						when x"07" =>
							sectlen<=x"4000";
						when others =>
							sectlen<=x"0001";
						end case;
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
						swait:=2;
						fdstate<=fs_chkicrch;
					end if;
				when fs_chkicrch =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						if(trackrddat(7 downto 0)/=crcdat(15 downto 8))then
							sectstatus<=x"a0";
						else
							sectstatus<=x"00";
						end if;
						img_addr<=cursecthead+x"04";
						img_wrdat<=numsect(7 downto 0);
						img_wr<='1';
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
						swait:=2;
						fdstate<=fs_chkicrcl;
					end if;
				when fs_chkicrcl =>
					if(trackbusy='0' and img_busy='0')then
						if(trackrddat(7 downto 0)/=crcdat(7 downto 0))then
							sectstatus<=x"a0";
						end if;
						img_addr<=cursecthead+x"05";
						img_wrdat<=numsect(15 downto 8);
						img_wr<='1';
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
						swait:=2;
						fdstate<=fs_stmod;
					end if;
				when fs_stmod =>
					if(img_busy='0')then
						img_addr<=cursecthead+x"06";
						if(trackrddat(9)='1')then
							img_wrdat<=x"00";
						else
							img_wrdat<=x"40";
						end if;
						img_wr<='1';
						swait:=2;
						fdstate<=fs_stsectsizel;
					end if;
				when fs_stsectsizel =>
					if(img_busy='0')then
						img_addr<=cursecthead+x"0e";
						img_wrdat<=sectlen(7 downto 0);
						img_wr<='1';
						swait:=2;
						fdstate<=fs_stsectsizeh;
					end if;
				when fs_stsectsizeh =>
					if(img_busy='0')then
						img_addr<=cursecthead+x"0f";
						img_wrdat<=sectlen(15 downto 8);
						img_wr<='1';
						swait:=2;
						fdstate<=fs_scandam;
						ambuf0:=(others=>'0');
						ambuf1:=(others=>'0');
						ambuf2:=(others=>'0');
						ambuf3:=(others=>'0');
						crcclr<='1';
					end if;
				when fs_scandam =>
					if(trackbusy='0' and crcbusy='0')then
						ambuf3:=ambuf2;
						ambuf2:=ambuf1;
						ambuf1:=ambuf0;
						ambuf0:=trackrddat(9 downto 0);
						crcclr<='1';
						if(ambuf3=("11" & x"a1") and ambuf2=("11" & x"a1") and ambuf1=("11" & x"a1") and ambuf0=("10" & x"f8"))then
							deleted<='1';
							crcwrdat<=x"a1";
							crcwr<='1';
							fdstate<=fs_crcdam0;
						elsif(ambuf3=("11" & x"a1") and ambuf2=("11" & x"a1") and ambuf1=("11" & x"a1") and ambuf0=("10" & x"fb"))then
							deleted<='0';
							crcwrdat<=x"a1";
							crcwr<='1';
							fdstate<=fs_crcdam0;
						elsif(ambuf0=("01" & x"f8"))then
							deleted<='1';
							fdstate<=fs_stdat;
							crcwrdat<=x"f8";
							crcwr<='1';
						elsif(ambuf0=("01" & x"fb"))then
							deleted<='0';
							fdstate<=fs_stdat;
							crcwrdat<=x"fb";
							crcwr<='1';
						end if;
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
						swait:=2;
					end if;
				when fs_crcdam0 =>
					if(crcbusy='0')then
						crcwrdat<=x"a1";
						crcwr<='1';
						fdstate<=fs_crcdam1;
					end if;
				when fs_crcdam1 =>
					if(crcbusy='0')then
						crcwrdat<=x"a1";
						crcwr<='1';
						fdstate<=fs_crcdam2;
					end if;
				when fs_crcdam2 =>
					if(crcbusy='0')then
						if(deleted='1')then
							crcwrdat<=x"f8";
						else
							crcwrdat<=x"fb";
						end if;
						crcwr<='1';
						fdstate<=fs_stdat;
					end if;
				when fs_stdat =>
					if(trackbusy='0' and img_busy='0' and crcbusy='0')then
						if(sectlen>x"0000")then
							img_addr<=img_addr+1;
							img_wrdat<=trackrddat(7 downto 0);
							img_wr<='1';
							crcwrdat<=trackrddat(7 downto 0);
							crcwr<='1';
							sectlen<=sectlen-1;
						else
							nxtsecthead<=img_addr+1;
							if(deleted='1')then
								sectstatus<=x"10";
							elsif(trackrddat(7 downto 0)/=crcdat(15 downto 8))then
								sectstatus<=x"b0";
							end if;
							fdstate<=fs_chkdatcrc;
						end if;
						track_curaddr<=track_curaddr+1;
						trackrd<='1';
					end if;
				when fs_chkdatcrc =>
					if(trackbusy='0' and img_busy='0')then
						if(trackrddat(7 downto 0)/=crcdat(7 downto 0))then
							sectstatus<=x"b0";
						end if;
						img_addr<=cursecthead+x"07";
						if(deleted='1')then
							img_wrdat<=x"10";
						else
							img_wrdat<=x"00";
						end if;
						img_wr<='1';
						swait:=2;
						fdstate<=fs_ststatus;
					end if;
				when fs_ststatus =>
					if(img_busy='0')then
						img_addr<=cursecthead+x"08";
						img_wrdat<=sectstatus;
						img_wr<='1';
						
						if((sectcount+1)<numsect)then
							sectcount<=sectcount+1;
							cursecthead<=nxtsecthead;
							ambuf0:=(others=>'0');
							ambuf1:=(others=>'0');
							ambuf2:=(others=>'0');
							ambuf3:=(others=>'0');
							trackrd<='1';
							swait:=2;
							fdstate<=fs_scaniam;
						else
							fdstate<=fs_savenexttrack;
						end if;
					end if;
				when fs_savenexttrack =>
					if((trackno+1)<tracks)then
						trackno<=trackno+1;
						tbladdr<=trackno+x"09";
						ambuf0:=(others=>'0');
						ambuf1:=(others=>'0');
						ambuf2:=(others=>'0');
						ambuf3:=(others=>'0');
						trackwrote<='0';
						trackrd<='1';
						track_curaddr<=(others=>'0');
						sectcount<=(others=>'0');
						newlen<=(others=>'0');
						idcnt<=0;
						scanlim<=tracklen;
						swait:=2;
						fdstate<=fs_scantrack;
					else
						img_sync<='1';
						swait:=2;
						fdstate<=fs_saveend;
					end if;
				when fs_saveend =>
					if(img_busy='0')then
						fddone<='1';
						fdstate<=fs_idle;
					end if;
				when others =>
				end case;
			end if;
		end if;
	end process;
	
	tracklenm<=	x"0000186a" when diskmode="00" else
					x"00001b58" when diskmode="01" else
					x"000030d4" when diskmode="10" else
					x"00003a98";
	tracklen<=	x"00000c35"	when diskmode="00" and mfm='0' else
					x"00000dac" when diskmode="01" and mfm='0' else
					x"0000186a" when diskmode="10" and mfm='0' else
					x"00001d4c" when diskmode="11" and mfm='0' else
					x"0000186a" when diskmode="00" and mfm='1' else
					x"00001b58" when diskmode="01" and mfm='1' else
					x"000030d4" when diskmode="10" and mfm='1' else
					x"00003a98" when diskmode="11" and mfm='1' else
					x"00000000";
	pslimit<=	std_logic_vector(ieee.numeric_std.to_unsigned( 6250,18)) when diskmode="00" else
				std_logic_vector(ieee.numeric_std.to_unsigned( 7000,18)) when diskmode="01" else
				std_logic_vector(ieee.numeric_std.to_unsigned(10416,18)) when diskmode="10" else
				std_logic_vector(ieee.numeric_std.to_unsigned(12500,18));
	tracks<=	x"54" when ddmode='0' else
				x"a4" when ddmode='1' else
				x"00";
	
		CRCG	:CRCGENN generic map(8,16) port map(
		POLY	=>"10000100000010001",
		DATA	=>crcwrdat,
		DIR		=>'0',
		WRITE	=>crcwr,
		BITIN	=>'0',
		BITWR	=>'0',
		CLR		=>crcclr,
		CLRDAT	=>x"ffff",
		CRC		=>crcdat,
		BUSY	=>crcbusy,
		DONE	=>open,
		CRCZERO	=>open,

		clk		=>sclk,
		rstn	=>rstn
	);

	
	fec	:fecbuf port map(
		address_a		=>fbaddr,
		address_b		=>fec_ramaddrl,
		clock_a			=>sclk,
		clock_b			=>sclk,
		data_a			=>trackwrdat,
		data_b			=>fec_ramwdat,
		wren_a			=>fbwr,
		wren_b			=>fec_ramwe,
		q_a				=>trackrddat,
		q_b				=>fec_ramrdat
	);
	
	trackaddr<=	cur_unit & trackno(6 downto 1) & '0' & trackno(0) & track_curaddr when ddmode='0' else
					cur_unit & trackno & track_curaddr;

	fbaddr<=trackaddr(7 downto 0);

	process(sclk,rstn)
	variable wrote	:std_logic;
	begin
		if(rstn='0')then
			curfbhaddr<=(others=>'1');
			fbufstate<=ss_idle;
			fec_ramrd<='0';
			fec_ramwr<='0';
			fec_ramaddrh<=(others=>'0');
			fbwr<='0';
			wrote:='0';
		elsif(sclk' event and sclk='1')then
			fbwr<='0';
			case fbufstate is
			when ss_idle =>
				if(trackrd='1')then
					if(curfbhaddr/=trackaddr(22 downto 8))then
						if(wrote='1')then
							fec_ramwr<='1';
							fbufstate<=ss_rwrite;
						else
							fec_ramaddrh<=trackaddr(22 downto 8);
							curfbhaddr<=trackaddr(22 downto 8);
							fec_ramrd<='1';
							fbufstate<=ss_read;
						end if;
					end if;
				elsif(trackwr='1')then
					if(curfbhaddr=trackaddr(22 downto 8))then
						fbwr<='1';
						wrote:='1';
					else
						if(wrote='1')then
							fec_ramwr<='1';
							fbufstate<=ss_write;
						else
							fec_ramaddrh<=trackaddr(22 downto 8);
							curfbhaddr<=trackaddr(22 downto 8);
							fec_ramrd<='1';
							fbufstate<=ss_wread;
						end if;
					end if;
				elsif(tracksync='1')then
					if(wrote='1')then
						fec_ramwr<='1';
						fbufstate<=ss_sync;
					end if;
				end if;
			when ss_rwrite =>
				if(fec_rambusy='1')then
					fec_ramwr<='0';
					fbufstate<=ss_rwrite2;
				end if;
			when ss_rwrite2 =>
				if(fec_rambusy='0')then
					fec_ramaddrh<=trackaddr(22 downto 8);
					curfbhaddr<=trackaddr(22 downto 8);
					fec_ramrd<='1';
					fbufstate<=ss_read;
				end if;
			when ss_read =>
				if(fec_rambusy='1')then
					fec_ramrd<='0';
					fbufstate<=ss_read2;
				end if;
			when ss_read2 =>
				if(fec_rambusy='0')then
					fbufstate<=ss_idle;
					wrote:='0';
				end if;
			when ss_write =>
				if(fec_rambusy='1')then
					fec_ramwr<='0';
					fbufstate<=ss_write2;
				end if;
			when ss_write2 =>
				if(fec_rambusy='0')then
					fec_ramaddrh<=trackaddr(22 downto 8);
					curfbhaddr<=trackaddr(22 downto 8);
					fec_ramrd<='1';
					wrote:='0';
					fbufstate<=ss_wread;
				end if;
			when ss_wread =>
				if(fec_rambusy='1')then
					fec_ramrd<='0';
					fbufstate<=ss_wread2;
				end if;
			when ss_wread2 =>
				if(fec_rambusy='0')then
					fbwr<='1';
					wrote:='1';
					fbufstate<=ss_idle;
				end if;
			when ss_sync =>
				if(fec_rambusy='1')then
					fec_ramwr<='0';
					fbufstate<=ss_sync2;
				end if;
			when ss_sync2 =>
				if(fec_rambusy='0')then
					wrote:='0';
					fbufstate<=ss_idle;
				end if;
			when others =>
				fbufstate<=ss_idle;
			end case;
		end if;
	end process;
	
	trackbusy<=	'1' when trackrd='1' else
				'1' when trackwr='1' else
				'1' when tracksync='1' else
				'0' when fbufstate=ss_idle else
				'1';
	
	-- mfm0m<=	fdc_mfm when fdc_wrenn='0' else mfm0;
	-- mfm1m<=	fdc_mfm when fdc_wrenn='0' else mfm1;

	fdc_usel<=	"00" when fdc_useln="10" else
					"01" when fdc_useln="01" else
					"10";
	ovlwp<=ovlwpb(3) & ovlwpb(1) when fdc_siden='0' else ovlwpb(2) & ovlwpb(0);
	fdc_wprotn<=not (wrprot(0) or ovlwp(0)) when fdc_useln="10" else
					not (wrprot(1) or ovlwp(1)) when fdc_useln="01" else
					'1';
	fdc_motoren<=	not fdc_motorn(0) when fdc_useln(0)='0' else
						not fdc_motorn(1) when fdc_useln(1)='0' else
						'0';
	
	fde_ramaddr<=fde_ramaddrw(22 downto 0);
	fde	:FDemu generic map(fclkfreq,fdwait) port map(
		ramaddr		=>fde_ramaddrw,
		ramrdat		=>fde_ramrdat,
		ramwdat		=>fde_ramwdat,
		ramwr			=>fde_ramwr,
		ramwait		=>fde_ramwait,

		rdfdmode		=>"0000" & diskmode1 & diskmode0,
		-- curfdmode	=>fde_wrmode,
		modeset		=>"00" & fde_modeset,
		dstep		=>"00" & dstep1 & dstep0,
		-- wrote			=>fde_wrote,
		wprot			=>"00" & (wrprot or ovlwp),
		tracklen		=>fde_tracklen,
		fdenable		=>"00" & fdc_indiskb,
		
		USEL			=>fdc_usel,
		MOTOR			=>fdc_motoren,
		READY			=>open,
		WRENn			=>fdc_wrenn,
		WRBITn		=>fdc_wrbitn,
		WRFDMODE		=>fdc_dencity & fdc_trackwid,
		WRMFM			=>fdc_mfm,
		RDBITn		=>fde_rdbitn,
		STEPn			=>fdc_stepn,
		SDIRn			=>fdc_sdirn,
		track0n		=>fde_track0n,
		indexn		=>fde_indexn,
		siden			=>fdc_siden,

		clk			=>fclk,
		rstn			=>rstn
	);
	fdc_track0n<=	fde_track0n when fdc_useln="10" else
						fde_track0n when fdc_useln="01" else
						'1';
	fdc_indexn<=	fde_indexn	when fdc_useln="10" else
						fde_indexn	when fdc_useln="01" else
						'1';
	fdc_rdbitn<=	fde_rdbitn	when fdc_useln="10" else
						fde_rdbitn	when fdc_useln="01" else
						'1';
	
	fdc_readyn<=fdc_motorn(0) when fdc_indiskb(0)='1' and fdc_useln(0)='0' else
					fdc_motorn(1) when fdc_indiskb(1)='1' and fdc_useln(1)='0' else
					'1';
	fdc_indisk<=fdc_indiskb;
	
	sasi_idsel<=	"00000001" when sasien='1' else
						"00000000";
	
	sasi	:sasidev port map(
		IDAT	=>sasi_din,
		ODAT	=>sasi_dout,
		SEL	=>sasi_sel,
		BSY	=>sasi_bsy,
		REQ	=>sasi_req,
		ACK	=>sasi_ack,
		IO		=>sasi_io,
		CD		=>sasi_cd,
		MSG	=>sasi_msg,
		RST	=>sasi_rst,
		
		idsel	=>sasi_idsel,
		
		id		=>open,
		unit	=>open,
		capacity	=>sasi_cap,
		lba		=>sasi_lba,
		rdreq		=>sasi_rdreq,
		wrreq		=>sasi_wrreq,
		sectaddr	=>sasi_sectaddr,
		rddat		=>sasi_sectrddat,
		wrdat		=>sasi_sectwrdat,
		sectbusy	=>sasi_bufbusy,
		
		clk		=>sclk,
		rstn		=>rstn
	);
	
	sasisectwr<=	mist_buffwr when emustate=es_sasi else '0';
	
	sasibuf	:sectram port map(
		address_a		=>mist_buffaddr,
		address_b		=>sasi_lba(0) & sasi_sectaddr,
		clock				=>sclk,
		data_a			=>mist_buffdout,
		data_b			=>sasi_sectwrdat,
		wren_a			=>sasisectwr,
		wren_b			=>sasibufwr,
		q_a				=>sasi_bufodat,
		q_b				=>sasi_sectrddat
	);
	
	mist_buffdin<=	sbuf_odat		when emustate=es_fload0 else
						sbuf_odat		when emustate=es_fload1 else
						sbuf_odat		when emustate=es_fsave0 else
						sbuf_odat		when emustate=es_fsave1 else
						sasi_bufodat	when emustate=es_sasi else
						sram_bufout		when emustate=es_sload else
						sram_bufout		when emustate=es_ssave else
						(others=>'0');
						
	process(sclk,rstn)
	variable wrote	:std_logic;
	variable swait	:integer range 0 to 2;
	begin
		if(rstn='0')then
			sasibufstate<=ss_idle;
			lba_sasi<=(others=>'0');
			cur_slba<=(others=>'1');
			wrote:='0';
			mist_rd(bit_sasi)<='0';
			mist_wr(bit_sasi)<='0';
			sasibufwr<='0';
			sasidone<='0';
			swait:=0;
		elsif(sclk' event and sclk='1')then
			sasibufwr<='0';
			sasidone<='0';
			if(swait>0)then
				swait:=swait-1;
			else
				case sasibufstate is
				when ss_idle =>
					if(sasi_rdreq2='1')then
						if(sasi_lba(20 downto 1)/=cur_slba(19 downto 0))then
							if(wrote='1')then
								mist_wr(bit_sasi)<='1';
								sasibufstate<=ss_rwrite;
							else
								cur_slba<=allzero(31 downto 20) & sasi_lba(20 downto 1);
								lba_sasi<=allzero(31 downto 20) & sasi_lba(20 downto 1);
								mist_rd(bit_sasi)<='1';
								sasibufstate<=ss_read;
							end if;
						else
							sasidone<='1';
						end if;
					elsif(sasi_wrreq2='1')then
						if(sasi_lba(20 downto 1)=cur_slba(19 downto 0))then
							sasibufwr<='1';
							sasidone<='1';
						else
							if(wrote='1')then
								mist_wr(bit_sasi)<='1';
								sasibufstate<=ss_write;
							else
								cur_slba<=allzero(31 downto 20) & sasi_lba(20 downto 1);
								lba_sasi<=allzero(31 downto 20) & sasi_lba(20 downto 1);
								mist_rd(bit_sasi)<='1';
								sasibufstate<=ss_wread;
							end if;
						end if;
					elsif(sasi_syreq2='1')then
						if(wrote='1')then
							mist_wr(bit_sasi)<='1';
							sasibufstate<=ss_sync;
						else
							sasidone<='1';
						end if;
					end if;
				when ss_rwrite =>
					if(mist_ack(bit_sasi)='1')then
						mist_wr(bit_sasi)<='0';
						sasibufstate<=ss_rwrite2;
					end if;
				when ss_rwrite2 =>
					if(mist_ack(bit_sasi)='0')then
						wrote:='0';
						cur_slba<=allzero(31 downto 20) & sasi_lba(20 downto 1);
						lba_sasi<=allzero(31 downto 20) & sasi_lba(20 downto 1);
						mist_rd(bit_sasi)<='1';
						sasibufstate<=ss_read;
					end if;
				when ss_read =>
					if(mist_ack(bit_sasi)='1')then
						mist_rd(bit_sasi)<='0';
						sasibufstate<=ss_read2;
					end if;
				when ss_read2 =>
					if(mist_ack(bit_sasi)='0')then
						sasidone<='1';
						sasibufstate<=ss_idle;
					end if;
				when ss_write =>
					if(mist_ack(bit_sasi)='1')then
						mist_wr(bit_sasi)<='0';
						sasibufstate<=ss_write2;
					end if;
				when ss_write2 =>
					if(mist_ack(bit_sasi)='0')then
						cur_slba<=allzero(31 downto 20) & sasi_lba(20 downto 1);
						lba_sasi<=allzero(31 downto 20) & sasi_lba(20 downto 1);
						mist_rd(bit_sasi)<='1';
						wrote:='0';
						sasibufstate<=ss_wread;
					end if;
				when ss_wread =>
					if(mist_ack(bit_sasi)='1')then
						mist_rd(bit_sasi)<='0';
						sasibufstate<=ss_wread2;
					end if;
				when ss_wread2 =>
					if(mist_ack(bit_sasi)='0')then
						sasibufwr<='1';
						wrote:='1';
						sasidone<='1';
						sasibufstate<=ss_idle;
					end if;
				when ss_sync =>
					if(mist_ack(bit_sasi)='1')then
						mist_wr(bit_sasi)<='0';
						sasibufstate<=ss_sync2;
					end if;
				when ss_sync2 =>
					if(mist_ack(bit_sasi)='0')then
						wrote:='0';
						sasidone<='1';
						sasibufstate<=ss_idle;
					end if;
				when others =>
					sasibufstate<=ss_idle;
				end case;
			end if;
		end if;
	end process;
	
	sramwr<=	"00" when sram_wp='0' else
				"00" when sram_cs='0' else
				sram_wr;
	
	sram_bufwr<=	mist_buffwr when emustate=es_sload else
						mist_buffwr	when emustate=es_ssave else
						'0';
	
	sram	:sramcont port map(
		addr	=>sram_addr,
		rdat	=>sram_rdat,
		wdat	=>sram_wdat,
		wr		=>sramwr,
		
		ldreq		=>sram_ldreq,
		streq		=>sram_streq,
		done		=>sramdone,

		mist_rd	=>mist_rd(bit_sram),
		mist_wr	=>mist_wr(bit_sram),
		mist_ack	=>mist_ack(bit_sram),
		
		mist_lba		=>lba_sram,
		mist_addr	=>mist_buffaddr,
		mist_wdat	=>mist_buffdout,
		mist_rdat	=>sram_bufout,
		mist_we		=>sram_bufwr,
		
		clk		=>sclk,
		rstn		=>rstn
	);						
						
	--tables of the long sector layout
	process(sclk)begin
		if(sclk' event and sclk='1')then
			if(t_we='1')then
				tram(conv_integer(t_wa))<=t_wd;
			end if;
			t_q<=tram(conv_integer(t_ra));
			if(fp_we='1')then
				fpram(conv_integer(fp_wa))<=fp_wd;
			end if;
			fp_q<=fpram(conv_integer(fp_ra));
			if(fh_we='1')then
				fhram(conv_integer(fh_wa))<=fh_wd;
			end if;
			fh_q<=fhram(conv_integer(fh_ra));
			if(ct_we='1')then
				ctram(conv_integer(ct_wa))<=ct_wd;
			end if;
			ct_q<=ctram(conv_integer(ct_ra));
			if(csi_we='1')then
				csiram(conv_integer(csi_wa))<=csi_wd;
			end if;
			csi_q<=csiram(conv_integer(csi_ra));
			if(csp_we='1')then
				cspram(conv_integer(csp_wa))<=csp_wd;
			end if;
			csp_q<=cspram(conv_integer(csp_ra));
			if(cfh_we='1')then
				cfhram(conv_integer(cfh_wa))<=cfh_wd;
			end if;
			cfh_q<=cfhram(conv_integer(cfh_ra));
			if(ovl_we='1')then
				ovlram(conv_integer(img_unit & trackno))<=ovl_wd;
			end if;
			ovl_q<=ovlram(conv_integer(img_unit & trackno));
			--head position of the selected drive (fclk; it changes only on a step)
			fdtrk1<=fde_ramaddrw(23 downto 14);
			fdtrk2<=fdtrk1;
			if(fdtrk2(9)='0')then
				headpos(conv_integer(fdtrk2(8 downto 8)))<=fdtrk2(7 downto 1);
			end if;
			--look up drive & side wpsel; 2D: two head steps per track, odd positions hold no track
			wpsel<=wpsel+1;
			wpselq<=wpsel;
			if(ddm(conv_integer(wpsel(1 downto 1)))='1')then
				wpq<=ovlram(conv_integer(wpsel(1) & headpos(conv_integer(wpsel(1 downto 1))) & wpsel(0)));
				wpval<='1';
			else
				wpq<=ovlram(conv_integer(wpsel(1) & '0' & headpos(conv_integer(wpsel(1 downto 1)))(6 downto 1) & wpsel(0)));
				wpval<=not headpos(conv_integer(wpsel(1 downto 1)))(0);
			end if;
			ovlwpb(conv_integer(wpselq))<=wpq and wpval;
		end if;
	end process;

end rtl;
	

