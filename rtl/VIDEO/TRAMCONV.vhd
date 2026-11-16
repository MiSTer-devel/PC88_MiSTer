LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.VIDEO_TIMING_pkg.all;

entity TRAMCONV is
generic(
	--V1S: steps (ce, 20MHz) the bus is held per text row, at 4MHz and 8MHz
	V1SHOLD4	:integer	:=3766;
	V1SHOLD8	:integer	:=3325;
	--Same, for rows taken while the CPU is slowed down by GVSTR
	V1SHOLD4S	:integer	:=2356;
	V1SHOLD8S	:integer	:=2742;
	--24kHz and 15kHz timing: the same per row, and per row while slowed down
	V1SHOLD4N	:integer	:=3606;
	V1SHOLD8N	:integer	:=3146;
	V1SHOLD4S24	:integer	:=2680;
	V1SHOLD8S24	:integer	:=2778;
	V1SHOLD4S15	:integer	:=2266;
	V1SHOLD8S15	:integer	:=2598;
	--8MHz: a row taken while the CPU is slowed down is followed by up to SHNUM
	--short holds, SHPERIOD steps apart from the row request plus 0 to
	--2**SHJITBITS-1 steps; each ends SHDW steps after its own request, or 2 steps
	--after the grant if that is later (the CPU runs on until its M cycle ends)
	SHNUM		:integer	:=24;
	SHPERIOD	:integer	:=340;
	SHJITBITS	:integer	:=9;
	SHDW15		:integer	:=77;
	SHDW24		:integer	:=93;
	SHDW31		:integer	:=82;
	--8MHz: a row taken while the CPU is not slowed down is held M1GAIN/16 steps
	--longer for each M1 above M1BASE among the last 128 CPU bus cycles
	M1BASE		:integer	:=60;
	M1GAIN		:integer	:=35
);
port(
	TVRMODE		:in std_logic;
	TMODE		:in std_logic;
	SMODE		:in std_logic;
	COLOR		:in std_logic;
	ATTRCOLOR	:in std_logic;
	SPCHR		:in std_logic;
	TEXTEN		:in std_logic;
	ATTRLEN		:in std_logic_vector(4 downto 0);
	TXTLINES	:in std_logic_vector(5 downto 0);
	
	V1S			:in std_logic	:='0';	-- 1:V1S mode
	VMODE		:in std_logic	:='1';	-- text row height (rclk) 1:16 rasters 0:20
	CPUMD		:in std_logic	:='0';	-- 0:4MHz 1:8MHz
	GVSTR		:in std_logic	:='0';	-- 1:the CPU is slowed down (rclk)
	VT24		:in std_logic	:='0';	-- 1:24kHz or 15kHz timing (rclk)
	VT15		:in std_logic	:='0';	-- 1:15kHz timing (rclk)
	TSET		:in std_logic_vector(17 downto 0)	:=(others=>'0');	-- 24kHz, 15kHz: rows, height, first request line (rclk)
	
	TADR_TOP	:in std_logic_vector(15 downto 0);

	TRAM_ADR	:out std_logic_vector(11 downto 0);
	TRAM_DAT	:in std_logic_vector(7 downto 0);
	
	MRAM_ADR	:out std_logic_vector(15 downto 0);
	MRAM_DAT	:in std_logic_vector(7 downto 0);
	MRAM_RDn	:out std_logic;
	MRAM_WAIT	:in std_logic;
	BUS_USE		:out std_logic;
	
	BUSREQn		:out std_logic;
	BUSACKn		:in std_logic;
	

	TVRAM_ADR	:out std_logic_vector(11 downto 0);
	TVRAM_WDAT	:out std_logic_vector(8 downto 0);	-- bit 8 of an attribute: over line
	TVRAM_WR	:out std_logic;
	
	VRET		:in std_logic;
	HRET		:in std_logic;
	DONE		:out std_logic;
	DMAREQ		:out std_logic_vector(1 downto 0);	-- counts where a FH starts the DMA of a text row (TDMAREGS)
	DMALEN		:out std_logic_vector(7 downto 0);	-- bytes in that row
	--TDMAREGS: where the next row transfer starts, bytes to TC, the autoload values, and
	--whether the rows can follow the 8257 (taken for row 0 of the next frame)
	DMNXA		:in std_logic_vector(15 downto 0)	:=(others=>'0');
	DMNXR		:in std_logic_vector(14 downto 0)	:=(others=>'0');
	DMRLA		:in std_logic_vector(15 downto 0)	:=(others=>'0');
	DMRLR		:in std_logic_vector(14 downto 0)	:=(others=>'0');
	DMOK		:in std_logic	:='0';
	DMWE		:in std_logic_vector(1 downto 0)	:="00";	-- CPU writes to 64h, 65h (TDMAREGS)
	DMCF		:in std_logic	:='0';	-- channel 2 can be followed (DMOK without the timing)
	DMPD		:in std_logic	:='0';	-- a row request has not started yet
	-- The row just moved took bytes DMSPM on from DMSPA (an address written while it moved, TDMAREGS):
	-- DMSPL toggles at the end of such a row
	DMSPL		:in std_logic	:='0';
	DMSPM		:in std_logic_vector(7 downto 0)	:=(others=>'0');
	DMSPA		:in std_logic_vector(15 downto 0)	:=(others=>'0');
	DMRSA		:in std_logic_vector(15 downto 0)	:=(others=>'0');
	
	CPUBUS		:in std_logic	:='0';	-- a CPU bus cycle (BUSSEL)
	CPUM1n		:in std_logic	:='1';
	CRTRST		:in std_logic	:='0';	-- toggles on each CRTC RESET command (CRTCREGS)
	clk			:in std_logic;
	ce			:in std_logic	:='1';	-- one step: 4 times in 15 rclk clocks (20MHz)
	rstn		:in std_logic
);
end TRAMCONV;

architecture MAIN of TRAMCONV is
constant LINECHARS	:integer	:=80;
constant MAXLINES	:integer	:=25;
--The start of the row being read. Its text is read from byte CHARCNT of the row, its
--attributes from byte AOFF (from 80 on).
signal	STXTADR	:std_logic_vector(15 downto 0);
signal	AOFF	:std_logic_vector(15 downto 0);
signal	SDSTADR	:std_logic_vector(11 downto 0);
signal	CDSTADR	:std_logic_vector(11 downto 0);
signal	ATRCNT	:integer range 0 to 19;
signal	CURATR	:std_logic_vector(8 downto 0);
--The attribute at the end of the last row, without the over and under lines: a
--frame starts with it, as a real PC-8801FH does not reset the attribute at the
--start of a frame (Valis II demo). The CRTC RESET command sets it to white.
signal	ATRCARRY	:std_logic_vector(8 downto 0);
signal	rCRTRST		:std_logic;
--A RESET came in this frame: rows ending before the next frame start leave ATRCARRY white.
signal	RSTP		:std_logic;
--A repeated row or a row without attributes writes FIXVAL and leaves CURATR.
signal	FIXATR		:std_logic;
signal	FIXVAL		:std_logic_vector(8 downto 0);
signal	NXTATR	:std_logic_vector(7 downto 0);
signal	CHARCNT	:integer range 0 to LINECHARS-1;
signal	LINECNT	:integer range 0 to MAXLINES;
type STATE_T is(ST_IDLE,ST_GETBUS,ST_RDTXT,ST_RDTXT1,ST_WRTXT,ST_RDATR,ST_RDATR1,ST_RDATR2,ST_RDATR3,ST_SETATR,ST_SETATR1,ST_SETATR2,ST_RELBUS,ST_WAITREL,ST_SKIPATR,ST_NOATTR,ST_HOLD,ST_BLANK,ST_BLANK1,ST_BLANK2);
signal	STATE	:STATE_T;
--signal	STATE	:integer range 0 to 12;
--	constant ST_IDLE	:integer	:=0;
--	constant ST_GETBUS	:integer	:=1;
--	constant ST_RDTXT	:integer	:=2;
--	constant ST_RDTXT1	:integer	:=3;
--	constant ST_WRTXT	:integer	:=4;
--	constant ST_RDATR	:integer	:=5;
--	constant ST_RDATR1	:integer	:=6;
--	constant ST_RDATR2	:integer	:=7;
--	constant ST_RDATR3	:integer	:=8;
--	constant ST_SETATR	:integer	:=9;
--	constant ST_SETATR1	:integer	:=10;
--	constant ST_SETATR2	:integer	:=11;
--	constant ST_RELBUS	:integer	:=12;
signal	lVRET,lHRET	:std_logic;
signal	rTVRMODE	:std_logic;
signal	rTMODE		:std_logic;
-- signal	rCOLOR		:std_logic;
signal	COL			:std_logic_vector(7 downto 0);
signal	RDDAT		:std_logic_vector(7 downto 0);
signal	RDADR		:std_logic_vector(15 downto 0);
signal	waitcount	:integer range 0 to 5;
signal	iATTRLEN	:integer range 0 to 31;
signal	LINEADD		:std_logic_vector(15 downto 0);
signal	LINESKIP	:std_logic;
signal	fATTR		:std_logic_vector(79 downto 0);
signal	LINES		:integer range 0 to MAXLINES;

--Bound the ST_GETBUS wait so BUSREQn cannot remain asserted indefinitely. Not applied
--to the MRAM_WAIT waits, where an SDRAM read is already outstanding and cannot be
--canceled. A line is 640 steps (31kHz), 806 steps (24kHz) or 1252 steps (15kHz).
constant STUCKMAX	:integer	:=511;
signal	stuckcnt	:integer range 0 to STUCKMAX;

--After a release, BUSACKn must stay high this many cycles before the next request
--(about four cycles of the 3.95 MHz CPU clock).
constant RELQUIET	:integer	:=20;
signal	relcnt		:integer range 0 to RELQUIET;

--V1S: each text row is requested one row before it is drawn and the bus is
--held for a fixed time per row. The settings are taken once per frame, at CAPLINE.
constant BLANKEND	:integer	:=LINECHARS*2*MAXLINES-1;
signal	pVRET,pHRET	:std_logic;
signal	RASTER		:integer range 0 to VWMAX-1;
signal	BNDPEND		:std_logic;
signal	CAPD		:std_logic;
signal	BLANKD		:std_logic;
signal	BLANKR		:std_logic;	-- clearing has started in this frame
signal	capV1S		:std_logic;
signal	capTEXTEN	:std_logic;
signal	capCPUMD	:std_logic;
signal	capROWS		:integer range 0 to MAXLINES;
signal	capCHRL		:integer range CHRLMIN24 to CHRLMAX24;
signal	REQ			:integer range 0 to MAXLINES;	-- rows requested so far in this frame
signal	REQLINE		:integer range 0 to 1023;		-- raster of the next request
signal	VMODEs		:std_logic;
signal	GVSTRs		:std_logic;
signal	VT24s		:std_logic;
signal	VT15s		:std_logic;
--24kHz, 15kHz in V1S: like a real FH, the CPU is not stopped in the retrace.
--One row after the last row (XREQ), row 0 of the next frame is read ahead with
--its hold, so a CPU write to row 0 after that shows a frame later, as on a FH.
--After the retrace, row 0 is then skipped. With one row on the screen, or when
--the read-ahead did not end before the retrace, or the screen settings changed,
--row 0 is read in the retrace without the hold, and XREQ takes the hold alone.
signal	XREQ		:std_logic;	-- the request one row after the last row is due
signal	HOLDONLY	:std_logic;	-- the bus is being taken for the hold only
signal	NOHOLD		:std_logic;	-- this row is row 0: no hold after it
signal	PFROW		:std_logic;	-- this row is the read-ahead of row 0
signal	PFARM		:std_logic;	-- the read-ahead started in this frame (cleared by VRET)
signal	PFOK		:std_logic;	-- the read-ahead ended before VRET
signal	PFHOLD		:std_logic;	-- the frame start was held back: row 0 can be skipped
signal	PFRST		:std_logic;	-- the held-back frame start must be done after all
signal	PFDIRTY		:std_logic;	-- a format setting changed during the read-ahead
signal	pfROWS		:integer range 0 to MAXLINES;
signal	pfCHRL		:integer range CHRLMIN24 to CHRLMAX24;
signal	pfTEXTEN,pfVT24,pfVT15	:std_logic;
signal	pfSMODE,pfSPCHR,pfCOLOR,pfATTRCOLOR	:std_logic;
signal	pfATTRLEN	:std_logic_vector(4 downto 0);
signal	hTADR		:std_logic_vector(15 downto 0);	-- frame start values held at VRET
signal	hTVRMODE,hTMODE	:std_logic;
signal	HOLDTGT		:integer range 0 to 65535;
--TSET, taken when TSr2 and TSr3 agree. Until then (a few clocks after reset, before
--any CAPLINE), the 24kHz 25-line set.
constant TSDEF	:std_logic_vector(17 downto 0)	:=conv_std_logic_vector(ROWSDEF24,5) & conv_std_logic_vector(CHRLDEF24,5) & conv_std_logic_vector(VRETDEF24-CHRLDEF24,8);
signal	TSr,TSr2,TSr3,TSok	:std_logic_vector(17 downto 0);
signal	capSTR		:std_logic;	-- GVSTR when the bus was taken for this row
signal	holdcnt		:integer range 0 to 65535;
signal	SHACT		:std_logic;	-- short holds are due for this row
signal	SHHOLD		:std_logic;	-- this hold is a short hold
signal	shn			:integer range 0 to 255;
signal	shnext		:integer range 0 to 65535;
signal	shbase		:integer range 0 to 65535;
signal	shcnt		:integer range 0 to 65535;	-- steps since the row request
signal	shage		:integer range 0 to 65535;	-- steps since the short hold request
signal	lBUSREQ		:std_logic;
signal	BUSREQi		:std_logic;	-- BUSREQn, read back for the short holds
signal	SHDW		:integer range 0 to 65535;
signal	shlfsr		:std_logic_vector(15 downto 0);
signal	m1hist		:std_logic_vector(127 downto 0);
signal	m1cnt		:integer range 0 to 128;
signal	lCPUBUS		:std_logic;
signal	m1adj		:integer range -8192 to 8191;
--a shift register in logic, not in block RAM
attribute altera_attribute	:string;
attribute altera_attribute of m1hist	:signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
signal	HOLDING		:std_logic;
signal	SINCEBND	:integer range 0 to 3;
signal	BLKADR		:integer range 0 to BLANKEND;
--A FH moves row k while row k-1 is shown and row 0 of the next frame while the last
--row is shown. After the text DMA or the CRTC stops, it moves no row until the
--place for row 0 of the next frame.
signal	DMAT		:std_logic_vector(1 downto 0);
signal	DMAN		:std_logic_vector(7 downto 0);
signal	DMAX		:std_logic;	-- the place for row 0 of the next frame has passed
signal	DMXF		:std_logic;	-- row 0 of the next frame was moved
signal	DMA0		:std_logic;	-- row 0 of this frame was moved in the last frame
--A FH draws the rows in the order the 8257 moves them (vramtest K, fhp2, fhp3). Taken when
--row 0 of the next frame is moved: where it starts, the bytes to TC, the autoload values.
--The rows follow it only when they are 120 bytes (20 attributes), as measured on a FH.
signal	F0A,F0B		:std_logic_vector(15 downto 0);
--Byte counts to TC stop at RMAX: a frame moves at most 26 rows before they are taken again,
--and a count above 26*120+255 reads the same as any other there.
constant RMAX		:integer	:=4095;
signal	F0R,F0C		:integer range 0 to RMAX;
signal	F0OK		:std_logic;
signal	FSA,FSX		:std_logic_vector(15 downto 0);	-- start of row 0 for this frame
--This frame follows the 8257: bytes from STXTADR to TC, and where the 8257 goes on from there
signal	FOL			:std_logic;
signal	RREM		:integer range 0 to RMAX;
signal	RLA			:std_logic_vector(15 downto 0);
signal	RLR			:integer range 0 to RMAX;
signal	RDAT1		:std_logic;	-- the row after this one is a row of the screen
signal	FOLL		:std_logic;	-- FOL, and this row is 120 bytes
--A FH draws from the new address the rows the 8257 has not moved when 64h or 65h is written
--(fhp3 Q4), and draws a frame after a CRTC or DMA restart black but its last row (Q6).
signal	EPOCH		:std_logic_vector(1 downto 0);	-- counts the moves of row 0
signal	REPOCH		:std_logic_vector(1 downto 0);	-- EPOCH of the frame being read
signal	DNX			:integer range 0 to 27;	-- the next row the 8257 moves
signal	lDMWE		:std_logic_vector(1 downto 0);
signal	lDMSPL		:std_logic;	-- DMSPL as last taken with a change of DMWE
--Rows from RRK on are read from RRA. QLP: the last row of a restart frame is read
--from row 0 of the next frame (F0A), RRLA while it is read.
signal	RRP,RRLA,QLP	:std_logic;
signal	QLE			:std_logic_vector(1 downto 0);
--Row 0 waiting to be moved when 64h, 65h is written: its own mark, as more writes before
--the frame starts mark row 1 on (RSA..RSC like RRA..RRC)
signal	RSP			:std_logic;
signal	RSE			:std_logic_vector(1 downto 0);
signal	RSA,RSB		:std_logic_vector(15 downto 0);
signal	RSR,RSC		:integer range 0 to RMAX;
signal	RRE			:std_logic_vector(1 downto 0);
signal	RRK			:integer range 0 to 27;
signal	RRA,RRB		:std_logic_vector(15 downto 0);
signal	RRR,RRC		:integer range 0 to RMAX;
signal	BLKR		:std_logic;	-- this row is drawn blank (the 8257 did not move it)
--A FH switches the address in the middle of a row when 64h is written while it moves (fhp5): row SPK
--(of frame SPE) starts at SPRA and takes bytes SPMr on from SPAr (SPP, a mark of its own, as later writes
--mark the rows after it). While SPLON, the row being read takes bytes SPLMa on from SPLAa (ra, nxs).
signal	SPP,SPLON	:std_logic;
signal	SPK			:integer range 0 to 27;
signal	SPE			:std_logic_vector(1 downto 0);
signal	SPRA,SPRB	:std_logic_vector(15 downto 0);
signal	SPRR,SPRC	:integer range 0 to RMAX;
signal	SPMr,SPLMa	:std_logic_vector(7 downto 0);
signal	SPAr,SPLAa	:std_logic_vector(15 downto 0);
signal	SPOK		:std_logic;	-- a write seen now made the row just moved change over in its middle
signal	EVK			:integer range 0 to 27;	-- the row a write to 64h, 65h now takes effect from
signal	EVOK		:std_logic;	-- such a write is seen now, and the rows can follow it
--The attribute at the start of each row, without the over and under lines (CURATR has
--them clear between rows): bits 7 and 5..0
type ATRK_T is array(0 to MAXLINES-1) of std_logic_vector(6 downto 0);
signal	ATRK		:ATRK_T;
signal	RDOFS		:std_logic_vector(15 downto 0);	-- the byte of the row read now (text or attribute)
signal	RDA			:std_logic_vector(15 downto 0);	-- its address
--The address of byte o of a row that starts at s: past TC (rm bytes on) it comes from where the
--8257 reloads (rla), and in a row that changes over to another address at byte sm, from sa
function ra(s,o :std_logic_vector(15 downto 0); rm :integer; rla :std_logic_vector(15 downto 0); fol :std_logic;
	spl :std_logic; sm :std_logic_vector(7 downto 0); sa :std_logic_vector(15 downto 0)) return std_logic_vector is
begin
	if(spl='1' and o>=(x"00" & sm))then
		return sa+(o-(x"00" & sm));
	elsif(fol='1' and conv_integer(o)>=rm)then
		return rla+(o-conv_std_logic_vector(rm,16));
	else
		return s+o;
	end if;
end function;
--The start of the next row, and the bytes from there to TC
function nxa(s,l :std_logic_vector(15 downto 0); rm :integer; rla :std_logic_vector(15 downto 0); fol :std_logic) return std_logic_vector is
begin
	if(fol='1' and rm<=conv_integer(l))then
		return rla+l-conv_std_logic_vector(rm,16);
	else
		return s+l;
	end if;
end function;
function nxs(s,l :std_logic_vector(15 downto 0); rm :integer; rla :std_logic_vector(15 downto 0); fol :std_logic;
	spl :std_logic; sm :std_logic_vector(7 downto 0); sa :std_logic_vector(15 downto 0)) return std_logic_vector is
begin
	if(spl='1')then
		return sa+l-(x"00" & sm);
	else
		return nxa(s,l,rm,rla,fol);
	end if;
end function;
function nxr(l :std_logic_vector(15 downto 0); rm,rlr :integer; fol :std_logic) return integer is
begin
	if(fol='1' and rm<=conv_integer(l))then
		return rlr-conv_integer(l)+rm;
	elsif(fol='1')then
		return rm-conv_integer(l);
	else
		return rm;
	end if;
end function;
function sat(x :integer) return integer is
begin
	if(x>RMAX)then
		return RMAX;
	else
		return x;
	end if;
end function;

--The inputs are taken one step before the FSM uses them. They were the
--synchronizers when TRAMCONV ran on clk21m; the FSM's step counts include them,
--so they stay now that it runs on rclk.
signal	MRAM_WAITr	:std_logic;
signal	BUSACKnr	:std_logic;
signal	VRETr,HRETr	:std_logic;
signal	TEXTENr		:std_logic;
--TXTLINES, taken when TXLr2 and TXLr3 agree.
signal	TXLr,TXLr2,TXLr3	:std_logic_vector(5 downto 0);
--VMODE, GVSTR and VT24, two steps late as before.
signal	VMODEs1,GVSTRs1,VT24s1,VT15s1	:std_logic;

begin

	RDDAT<=MRAM_DAT when rTMODE='1' else TRAM_DAT;
	TRAM_ADR<=RDADR(11 downto 0);
	MRAM_ADR<=RDADR;
	iATTRLEN<=conv_integer(ATTRLEN);
	LINEADD<=x"0052" + (x"00" & "00" & ATTRLEN & "0") when SPCHR='0' else x"0050";
	LINES<=conv_integer(TXTLINES);

	BUSREQn<=BUSREQi;
	DMAREQ<=DMAT;
	DMALEN<=DMAN;
	FSA<=F0A when F0OK='1' else TADR_TOP;
	FSX<=F0A when F0OK='1' and DMXF='1' else TADR_TOP;
	RDAT1<='0' when capV1S='0' and LINECNT>LINES else '1';
	FOLL<=FOL when LINEADD=x"0078" else '0';
	--The byte read now: text bytes in ST_RDTXT, attribute bytes in ST_RDATR and ST_RDATR2
	RDOFS<=conv_std_logic_vector(CHARCNT,16) when STATE=ST_RDTXT else AOFF;
	RDA<=ra(STXTADR,RDOFS,RREM,RLA,FOLL,SPLON and FOLL,SPLMa,SPLAa);
	--A request still waiting when 64h, 65h is written moves its row from the new values too
	EVK<=	0		when DMPD='1' and DNX=0 else
			DNX-2	when DMPD='1' and SMODE='1' and DNX>=2 else
			DNX-1	when DMPD='1' else
			DNX;
	EVOK<='1' when DMWE/=lDMWE and TEXTENr='1' and DMCF='1' and conv_integer(DMRLR)>=120 and LINEADD=x"0078" and EVK<capROWS else '0';
	SPOK<='1' when DMWE/=lDMWE and TEXTENr='1' and DMCF='1' and conv_integer(DMRLR)>=120 and LINEADD=x"0078"
		and DMSPL/=lDMSPL and capV1S='0' and SMODE='0' and EVK>=1 and EVK<=capROWS else '0';
	--M1 among the last 128 CPU bus cycles
	process(clk,rstn)begin
		if(rstn='0')then
			m1hist<=(others=>'0');
			m1cnt<=0;
			lCPUBUS<='0';
		elsif(clk' event and clk='1')then
			lCPUBUS<=CPUBUS;
			if(CPUBUS='1' and lCPUBUS='0')then
				m1hist<=m1hist(126 downto 0) & not CPUM1n;
				if(CPUM1n='0' and m1hist(127)='0')then
					m1cnt<=m1cnt+1;
				elsif(CPUM1n='1' and m1hist(127)='1')then
					m1cnt<=m1cnt-1;
				end if;
			end if;
		end if;
	end process;
	SHDW<=	SHDW31	when VT24s='0' else
			SHDW15	when VT15s='1' else
			SHDW24;
	HOLDTGT<=	V1SHOLD4		when capCPUMD='0' and capSTR='0' and VT24s='0' else
				V1SHOLD8		when capCPUMD='1' and capSTR='0' and VT24s='0' else
				V1SHOLD4S		when capCPUMD='0' and VT24s='0' else
				V1SHOLD8S		when VT24s='0' else
				V1SHOLD4N		when capCPUMD='0' and capSTR='0' else
				V1SHOLD8N		when capSTR='0' else
				V1SHOLD4S15		when capCPUMD='0' and VT15s='1' else
				V1SHOLD8S15		when VT15s='1' else
				V1SHOLD4S24		when capCPUMD='0' else
				V1SHOLD8S24;

	process(clk)begin
		if(clk' event and clk='1')then
			if(ce='1')then
				VMODEs1<=VMODE;
				VMODEs<=VMODEs1;
				GVSTRs1<=GVSTR;
				GVSTRs<=GVSTRs1;
				VT24s1<=VT24;
				VT24s<=VT24s1;
				VT15s1<=VT15;
				VT15s<=VT15s1;
			end if;
		end if;
	end process;
	
	process(clk,rstn)
	variable iNXTATR	:integer range 0 to 255;
	variable iCOUNTER	:integer range 0 to 80;
	variable iATTRCUL	:integer range 0 to 80;
	variable iRRK		:integer range 0 to 27;
	variable evu		:boolean;	-- a row start took the write seen in this step
	variable irk		:integer range 0 to MAXLINES-1;	-- the row read again (SPK or RRK, as in ST_IDLE)
	begin
		if(rstn='0')then
			STATE<=ST_IDLE;
			STXTADR<=(others=>'0');
			AOFF<=x"0050";
			ATRCNT<=0;
			CURATR<="000000111";
			ATRCARRY<="000000111";
			rCRTRST<='0';
			RSTP<='0';
			FIXATR<='0';
			FIXVAL<=(others=>'0');
			CHARCNT<=0;
			SDSTADR<=(others=>'0');
			CDSTADR<=(others=>'0');
			LINECNT<=0;
			lVRET<='1';
			lHRET<='1';
			rTVRMODE<='0';
			rTMODE<='0';
			-- rCOLOR<='0';
			BUSREQi<='1';
			MRAM_RDn<='1';
			BUS_USE<='0';
			TVRAM_ADR<=(others=>'0');
			TVRAM_WDAT<=(others=>'0');
			TVRAM_WR<='0';
			DONE<='0';
			waitcount<=0;
			LINESKIP<='0';
			stuckcnt<=0;
			relcnt<=0;
			MRAM_WAITr<='0';
			BUSACKnr<='1';
			VRETr<='1';
			HRETr<='1';
			TEXTENr<='0';
			TXLr<=(others=>'0');
			TXLr2<=(others=>'0');
			TXLr3<=(others=>'0');
			TSr<=TSDEF;
			TSr2<=TSDEF;
			TSr3<=TSDEF;
			TSok<=TSDEF;
			pVRET<='1';
			pHRET<='1';
			RASTER<=0;
			BNDPEND<='0';
			CAPD<='0';
			BLANKD<='0';
			BLANKR<='0';
			capV1S<='0';
			capTEXTEN<='0';
			capCPUMD<='0';
			capSTR<='0';
			capROWS<=MAXLINES;
			capCHRL<=16;
			REQ<=0;
			REQLINE<=0;
			holdcnt<=0;
			HOLDING<='0';
			SHACT<='0';
			SHHOLD<='0';
			shn<=0;
			shnext<=0;
			shbase<=0;
			shcnt<=0;
			shage<=0;
			lBUSREQ<='1';
			shlfsr<=x"ACE1";
			m1adj<=0;
			BLKADR<=0;
			SINCEBND<=3;
			XREQ<='0';
			HOLDONLY<='0';
			NOHOLD<='0';
			PFROW<='0';
			PFARM<='0';
			PFOK<='0';
			PFHOLD<='0';
			PFRST<='0';
			PFDIRTY<='0';
			pfROWS<=MAXLINES;
			pfCHRL<=16;
			pfTEXTEN<='0';
			pfVT24<='0';
			pfVT15<='0';
			pfSMODE<='0';
			pfSPCHR<='0';
			pfCOLOR<='0';
			pfATTRCOLOR<='0';
			pfATTRLEN<=(others=>'0');
			hTADR<=(others=>'0');
			hTVRMODE<='0';
			hTMODE<='0';
			DMAT<="00";
			DMAN<=(others=>'0');
			DMAX<='0';
			DMXF<='0';
			DMA0<='0';
			F0A<=(others=>'0');
			F0B<=(others=>'0');
			F0R<=0;
			F0C<=0;
			F0OK<='0';
			FOL<='0';
			RREM<=0;
			RLA<=(others=>'0');
			RLR<=0;
			EPOCH<="00";
			REPOCH<="00";
			DNX<=0;
			lDMWE<="00";
			lDMSPL<='0';
			SPP<='0';
			SPLON<='0';
			SPK<=0;
			SPE<="00";
			SPRA<=(others=>'0');
			SPRB<=(others=>'0');
			SPRR<=0;
			SPRC<=0;
			SPMr<=(others=>'0');
			SPLMa<=(others=>'0');
			SPAr<=(others=>'0');
			SPLAa<=(others=>'0');
			RRP<='0';
			QLP<='0';
			QLE<="00";
			RSP<='0';
			RSE<="00";
			RSA<=(others=>'0');
			RSB<=(others=>'0');
			RSR<=0;
			RSC<=0;
			RRLA<='0';
			RRE<="00";
			RRK<=0;
			RRA<=(others=>'0');
			RRB<=(others=>'0');
			RRR<=0;
			RRC<=0;
			BLKR<='0';
		elsif(clk' event and clk='1')then
			if(ce='1')then
				MRAM_WAITr<=MRAM_WAIT;
				BUSACKnr<=BUSACKn;
				VRETr<=VRET;
				HRETr<=HRET;
				TEXTENr<=TEXTEN;
				TXLr<=TXTLINES;
				TXLr2<=TXLr;
				TXLr3<=TXLr2;
				TSr<=TSET;
				TSr2<=TSr;
				TSr3<=TSr2;
				if(TSr2=TSr3)then
					TSok<=TSr3;
				end if;
				TVRAM_WR<='0';
				DONE<='0';
				evu:=false;
				if(SPP='1' and SPE=REPOCH and SPK<LINECNT and FOL='1')then
					irk:=SPK;
				elsif(RRK<MAXLINES)then
					irk:=RRK;
				else
					irk:=0;
				end if;
				--The read-ahead row is converted with the live settings: one that changed
				--while it ran is not used.
				if(PFROW='1' and (SMODE/=pfSMODE or SPCHR/=pfSPCHR or ATTRLEN/=pfATTRLEN or COLOR/=pfCOLOR or ATTRCOLOR/=pfATTRCOLOR))then
					PFDIRTY<='1';
				end if;
				if(waitcount>0)then
					waitcount<=waitcount-1;
				else
					--Only true in cycles where the state below does nothing, so the two
					--assignments to STATE cannot collide.
					if(STATE=ST_GETBUS and BUSACKnr='1')then
						if(stuckcnt=STUCKMAX)then
							stuckcnt<=0;
							STATE<=ST_RELBUS;
							HOLDONLY<='0';
							SHHOLD<='0';
							SHACT<='0';
							PFROW<='0';
							if(capV1S='1' and HOLDONLY='0')then
								--V1S: drop the row, but step to the next one as ST_SETATR2 does.
								if(SMODE='1' and LINESKIP='0')then
									LINESKIP<='1';
								else
									STXTADR<=nxs(STXTADR,LINEADD,RREM,RLA,FOLL and RDAT1,SPLON and FOLL,SPLMa,SPLAa);
									SPLON<='0';
									RREM<=nxr(LINEADD,RREM,RLR,FOLL and RDAT1);
									LINESKIP<='0';
								end if;
								CDSTADR<=SDSTADR+x"0a0";
								SDSTADR<=SDSTADR+x"0a0";
							end if;
						else
							stuckcnt<=stuckcnt+1;
						end if;
					else
						stuckcnt<=0;
					end if;
					case STATE is
					when ST_IDLE =>
						if(PFRST='1' and BNDPEND='0')then
							--The frame start held back at VRET, with the values taken there.
							if(F0OK='1')then
								STXTADR<=F0A;
							else
								STXTADR<=hTADR;
							end if;
							FOL<=F0OK;
							RREM<=F0R;
							RLA<=F0B;
							RLR<=F0C;
							REPOCH<=EPOCH;
							SPLON<='0';
							RRLA<='0';
							if(SPE/=EPOCH)then
								SPP<='0';
							end if;
							if(RRE/=EPOCH)then
								RRP<='0';
							end if;
							if(QLE/=EPOCH)then
								QLP<='0';
							end if;
							if(RSE/=EPOCH)then
								RSP<='0';
							end if;
							SDSTADR<=(others=>'0');
							CDSTADR<=(others=>'0');
							rTVRMODE<=hTVRMODE;
							rTMODE<=hTMODE;
							TVRAM_ADR<=(others=>'0');
							--V1S was on at VRET (the frame start is held back only then): as the
							--restart there would have done.
							LINECNT<=0;
							CURATR<=ATRCARRY;
							RSTP<='0';
							LINESKIP<='0';
							PFRST<='0';
							PFHOLD<='0';
						elsif(capV1S='1')then
							if(BNDPEND='1' and PFOK='1' and PFRST='0' and V1S='1')then
								--New frame after a read-ahead: keep where it ended, start at row 0
								--and decide at row 0 whether to skip it.
								hTADR<=TADR_TOP;
								hTVRMODE<=TVRMODE;
								hTMODE<=TMODE;
								LINECNT<=0;
								PFOK<='0';
								PFHOLD<='1';
								BNDPEND<='0';
							elsif(BNDPEND='1')then
								--New frame: the same restart as on VRET below.
								PFOK<='0';
								PFHOLD<='0';
								PFRST<='0';
								STXTADR<=FSA;
								FOL<=F0OK;
								RREM<=F0R;
								RLA<=F0B;
								RLR<=F0C;
								REPOCH<=EPOCH;
								SPLON<='0';
								RRLA<='0';
								if(SPE/=EPOCH)then
									SPP<='0';
								end if;
								if(RRE/=EPOCH)then
									RRP<='0';
								end if;
								if(QLE/=EPOCH)then
									QLP<='0';
								end if;
								if(RSE/=EPOCH)then
									RSP<='0';
								end if;
								SDSTADR<=(others=>'0');
								CDSTADR<=(others=>'0');
								rTVRMODE<=TVRMODE;
								rTMODE<=TMODE;
								TVRAM_ADR<=(others=>'0');
								if(V1S='1')then
									LINECNT<=0;
								else
									--Leaving V1S: no rows until the next VRET.
									LINECNT<=MAXLINES;
								end if;
								CURATR<=ATRCARRY;
								RSTP<='0';
								LINESKIP<='0';
								BNDPEND<='0';
							elsif(CAPD='1' and BLANKD='0' and VT24s='0')then
								--Clear the rows below capROWS without the bus.
								if(capROWS=MAXLINES)then
									BLANKD<='1';
								else
									BLKADR<=capROWS*LINECHARS*2;
									STATE<=ST_BLANK;
								end if;
							elsif(CAPD='1' and capTEXTEN='1' and LINECNT<REQ and PFHOLD='1' and LINECNT=0)then
								if(VT24s='1' and VT15s=pfVT15 and TMODE=rTMODE and TVRMODE=rTVRMODE
									and SMODE=pfSMODE and SPCHR=pfSPCHR and ATTRLEN=pfATTRLEN and COLOR=pfCOLOR and ATTRCOLOR=pfATTRCOLOR
									and RSTP='0')then
									--Row 0 was read ahead (not before a RESET): skip it.
									LINECNT<=1;
									PFHOLD<='0';
									ATRCARRY<='0' & CURATR(7) & '0' & CURATR(5 downto 0);
								else
									PFRST<='1';
								end if;
							elsif(CAPD='1' and capTEXTEN='1' and LINECNT<REQ)then
								--Start of a row: as on HRET below.
								SHACT<='0';
								CHARCNT<=0;
								ATRCNT<=0;
								LINECNT<=LINECNT+1;
								BLKR<=not DMA0;
								if(EVOK='1' and EPOCH=REPOCH and EVK=LINECNT and FOL='1')then
									STXTADR<=DMNXA;
									RREM<=sat(conv_integer(DMNXR));
									RLA<=DMRLA;
									RLR<=sat(conv_integer(DMRLR));
									RRP<='0';
									evu:=true;
									SPLON<='0';
								elsif(RSP='1' and RSE=REPOCH and LINECNT=0 and FOL='1')then
									STXTADR<=RSA;
									RREM<=RSR;
									RLA<=RSB;
									RLR<=RSC;
									RSP<='0';
								elsif(RRP='1' and RRE=REPOCH and RRK=LINECNT and FOL='1')then
									STXTADR<=RRA;
									RREM<=RRR;
									RLA<=RRB;
									RLR<=RRC;
									RRP<='0';
								end if;
								if(VT24s='1' and LINECNT=0)then
									NOHOLD<='1';
								else
									NOHOLD<='0';
								end if;
								if(rTMODE='1')then
									STATE<=ST_GETBUS;
									BUSREQi<='0';
								elsif(rTVRMODE='1')then
									STATE<=ST_IDLE;
								else
									STATE<=ST_RDTXT;
								end if;
								for iCOUNTER in 0 to 79 loop
									fATTR(iCOUNTER)<='0';
								end loop;
							elsif(CAPD='1' and capTEXTEN='1' and XREQ='1' and rTMODE='1' and capROWS>=2 and VT24s='1')then
								--24kHz, 15kHz: read row 0 of the next frame ahead, as a frame start and
								--a row start.
								XREQ<='0';
								SHACT<='0';
								BLKR<='0';
								if(EVOK='1' and EVK=0 and F0OK='1' and DMXF='1')then
									--A write to 64h, 65h while row 0 waits to be moved: it comes from the new values
									STXTADR<=DMNXA;
									RREM<=sat(conv_integer(DMNXR));
									RLA<=DMRLA;
									RLR<=sat(conv_integer(DMRLR));
									RSP<='0';
									evu:=true;
								elsif(RSP='1' and RSE=EPOCH and F0OK='1' and DMXF='1')then
									STXTADR<=RSA;
									RREM<=RSR;
									RLA<=RSB;
									RLR<=RSC;
									RSP<='0';
								else
									STXTADR<=FSX;
									RREM<=F0R;
									RLA<=F0B;
									RLR<=F0C;
								end if;
								FOL<=F0OK and DMXF;
								REPOCH<=EPOCH;
								SPLON<='0';
								RRLA<='0';
								if(SPE/=EPOCH)then
									SPP<='0';
								end if;
								if(RRE/=EPOCH)then
									RRP<='0';
								end if;
								if(QLE/=EPOCH)then
									QLP<='0';
								end if;
								if(RSE/=EPOCH)then
									RSP<='0';
								end if;
								SDSTADR<=(others=>'0');
								CDSTADR<=(others=>'0');
								CURATR<=ATRCARRY;
								RSTP<='0';
								LINESKIP<='0';
								CHARCNT<=0;
								ATRCNT<=0;
								NOHOLD<='0';
								for iCOUNTER in 0 to 79 loop
									fATTR(iCOUNTER)<='0';
								end loop;
								PFROW<='1';
								PFARM<='1';
								PFDIRTY<='0';
								PFOK<='0';
								pfROWS<=capROWS;
								pfCHRL<=capCHRL;
								pfTEXTEN<=capTEXTEN;
								pfVT24<=VT24s;
								pfVT15<=VT15s;
								pfSMODE<=SMODE;
								pfSPCHR<=SPCHR;
								pfCOLOR<=COLOR;
								pfATTRCOLOR<=ATTRCOLOR;
								pfATTRLEN<=ATTRLEN;
								STATE<=ST_GETBUS;
								BUSREQi<='0';
							elsif(CAPD='1' and capTEXTEN='1' and XREQ='1' and rTMODE='1')then
								--24kHz, 15kHz with one row: the hold-only request.
								XREQ<='0';
								SHACT<='0';
								HOLDONLY<='1';
								STATE<=ST_GETBUS;
								BUSREQi<='0';
							elsif(SHACT='1' and rTMODE='1' and shcnt>=shnext)then
								--8MHz: the next short hold of this row
								if(shn>=SHNUM)then
									SHACT<='0';
								else
									shn<=shn+1;
									shbase<=shbase+SHPERIOD;
									shnext<=shbase+SHPERIOD+conv_integer(shlfsr(SHJITBITS-1 downto 0));
									HOLDONLY<='1';
									SHHOLD<='1';
									STATE<=ST_GETBUS;
									BUSREQi<='0';
								end if;
							elsif(CAPD='1' and BLANKD='0')then
								--24kHz, 15kHz: a due row request goes first (few rows and a short retrace
								--can leave no time to clear first), then the clearing continues
								--where it stopped.
								if(capROWS=MAXLINES)then
									BLANKD<='1';
								elsif(BLANKR='1')then
									STATE<=ST_BLANK;
								else
									BLKADR<=capROWS*LINECHARS*2;
									BLANKR<='1';
									STATE<=ST_BLANK;
								end if;
							end if;
						elsif(lVRET='1' and VRETr='0')then
							STXTADR<=FSA;
							SDSTADR<=(others=>'0');
							FOL<=F0OK;
							RREM<=F0R;
							RLA<=F0B;
							RLR<=F0C;
							REPOCH<=EPOCH;
							SPLON<='0';
							RRLA<='0';
							if(SPE/=EPOCH)then
								SPP<='0';
							end if;
							if(RRE/=EPOCH)then
								RRP<='0';
							end if;
							if(QLE/=EPOCH)then
								QLP<='0';
							end if;
							if(RSE/=EPOCH)then
								RSP<='0';
							end if;
							SDSTADR<=(others=>'0');
							CDSTADR<=(others=>'0');
							rTVRMODE<=TVRMODE;
							rTMODE<=TMODE;
							-- rCOLOR<=COLOR;
							TVRAM_ADR<=(others=>'0');
							LINECNT<=0;
							CURATR<=ATRCARRY;
							RSTP<='0';
							LINESKIP<='0';
						elsif(QLP='1' and QLE=REPOCH and capROWS<=LINECNT)then
							--A restart frame: its last row shows row 0 of the next frame
							LINECNT<=capROWS-1;
							if(F0OK='1')then
								STXTADR<=F0A;
							else
								STXTADR<=TADR_TOP;
							end if;
							RREM<=F0R;
							RLA<=F0B;
							RLR<=F0C;
							FOL<=F0OK;
							SDSTADR<=conv_std_logic_vector((capROWS-1)*LINECHARS*2,12);
							CDSTADR<=conv_std_logic_vector((capROWS-1)*LINECHARS*2,12);
							--the attribute the frame started with (the blank rows still decode theirs)
							CURATR<='0' & ATRK(0)(6) & '0' & ATRK(0)(5 downto 0);
							LINESKIP<='0';
							RRLA<='1';
							QLP<='0';
							--a mark for this frame's rows would only blank them again: drop it so
							--that it cannot take the place of this read
							if(RRE=REPOCH)then
								RRP<='0';
							end if;
						elsif(SPP='1' and SPE=REPOCH and SPK<LINECNT and FOL='1')then
							--Read again from row SPK, which changed over to a written address in its middle
							LINECNT<=irk;
							STXTADR<=SPRA;
							RREM<=SPRR;
							RLA<=SPRB;
							RLR<=SPRC;
							SDSTADR<=conv_std_logic_vector(irk*LINECHARS*2,12);
							CDSTADR<=conv_std_logic_vector(irk*LINECHARS*2,12);
							CURATR<='0' & ATRK(irk)(6) & '0' & ATRK(irk)(5 downto 0);
							LINESKIP<='0';
							SPP<='0';
							SPLON<='1';
							SPLMa<=SPMr;
							SPLAa<=SPAr;
						elsif(RRP='1' and RRE=REPOCH and RRK<LINECNT and FOL='1')then
							--Read again from row RRK: the rows the 8257 moves after a write to 64h or 65h
							LINECNT<=irk;
							STXTADR<=RRA;
							RREM<=RRR;
							RLA<=RRB;
							RLR<=RRC;
							SDSTADR<=conv_std_logic_vector(irk*LINECHARS*2,12);
							CDSTADR<=conv_std_logic_vector(irk*LINECHARS*2,12);
							CURATR<='0' & ATRK(irk)(6) & '0' & ATRK(irk)(5 downto 0);
							LINESKIP<='0';
							RRP<='0';
						elsif(lHRET='1' and HRETr='0' and TEXTENr='1')then
							CHARCNT<=0;
							ATRCNT<=0;
							if(LINECNT<MAXLINES)then
		--					if(LINECNT<LINES-1)then
								LINECNT<=LINECNT+1;
								ATRK(LINECNT)<=CURATR(7) & CURATR(5 downto 0);
								if(EVOK='1' and EPOCH=REPOCH and EVK=LINECNT and FOL='1')then
									--This row is moved after the write to 64h, 65h seen now: from the new values
									STXTADR<=DMNXA;
									RREM<=sat(conv_integer(DMNXR));
									RLA<=DMRLA;
									RLR<=sat(conv_integer(DMRLR));
									RRP<='0';
									evu:=true;
									SPLON<='0';
									--a mark for this row from an earlier write would read it again over the new values
									if(SPK=LINECNT)then
										SPP<='0';
									end if;
								elsif(RSP='1' and RSE=REPOCH and LINECNT=0 and FOL='1')then
									STXTADR<=RSA;
									RREM<=RSR;
									RLA<=RSB;
									RLR<=RSC;
									RSP<='0';
								elsif(SPP='1' and SPE=REPOCH and SPK=LINECNT and FOL='1')then
									--This row changed over to a written address in its middle
									STXTADR<=SPRA;
									RREM<=SPRR;
									RLA<=SPRB;
									RLR<=SPRC;
									SPP<='0';
									SPLON<='1';
									SPLMa<=SPMr;
									SPLAa<=SPAr;
								elsif(RRP='1' and RRE=REPOCH and RRK=LINECNT and FOL='1')then
									--This row is moved after an earlier write to 64h, 65h: from the values taken then
									STXTADR<=RRA;
									RREM<=RRR;
									RLA<=RRB;
									RLR<=RRC;
									RRP<='0';
								end if;
								if(DMA0='0' and RRLA='0')then
									BLKR<='1';
								else
									BLKR<='0';
								end if;
								if(rTMODE='1')then
									STATE<=ST_GETBUS;
									BUSREQi<='0';
								elsif(rTVRMODE='1')then
									STATE<=ST_IDLE;
								else
									STATE<=ST_RDTXT;
								end if;

							elsif(LINECNT=MAXLINES)then
								DONE<='1';
							end if;
							for iCOUNTER in 0 to 79 loop
								fATTR(iCOUNTER)<='0';
							end loop;
							if(LINECNT>LINES)then
								LINESKIP<='1';
							end if;
						end if;
					when ST_GETBUS =>
						if(BUSACKnr='0')then
							if(HOLDONLY='1')then
								STATE<=ST_HOLD;
								HOLDONLY<='0';
							else
								STATE<=ST_RDTXT;
							end if;
							BUS_USE<='1';
							HOLDING<='1';
							capSTR<=GVSTRs;
							if(GVSTRs='0' and capCPUMD='1')then
								--rounds toward zero
								m1adj<=((m1cnt-M1BASE)*M1GAIN)/16;
							else
								m1adj<=0;
							end if;
						end if;
					when ST_RDTXT =>
						MRAM_RDn<='0';
						RDADR<=RDA;
						STATE<=ST_RDTXT1;
						if(rTMODE='1')then
							--One cycle more, to pay back the cycle spent registering MRAM_WAIT.
							waitcount<=3;
						end if;
					when ST_RDTXT1 =>
						if(rTMODE='0' or MRAM_WAITr='0')then
							MRAM_RDn<='1';
							TVRAM_ADR<=CDSTADR;
							if (LINESKIP='1' or BLKR='1')then
								TVRAM_WDAT<='0' & x"00";
							else
								TVRAM_WDAT<='0' & RDDAT;
							end if;
							STATE<=ST_WRTXT;
						end if;
					when ST_WRTXT =>
						TVRAM_WR<='1';
						if(CHARCNT<LINECHARS-1)then
							CDSTADR<=CDSTADR+x"002";
							STATE<=ST_RDTXT;
							CHARCNT<=CHARCNT+1;
						else
							CDSTADR<=SDSTADR+"001";
							CHARCNT<=0;
							AOFF<=x"0050";
							if (LINESKIP='1')then
								STATE<=ST_SKIPATR;
							elsif (SPCHR='1')then
								STATE<=ST_NOATTR;
							else
								STATE<=ST_RDATR;
							end if;
						end if;
					when ST_NOATTR =>
						FIXATR<='1';
						FIXVAL<='0' & x"07";
						STATE<=ST_SETATR;
					when ST_SKIPATR =>
						FIXATR<='1';
						FIXVAL<='0' & x"80";
						STATE<=ST_SETATR;
					when ST_RDATR =>
						MRAM_RDn<='0';
						RDADR<=RDA;
						STATE<=ST_RDATR1;
						if(rTMODE='1')then
							--One cycle more, to pay back the cycle spent registering MRAM_WAIT.
							waitcount<=3;
						end if;
					when ST_RDATR1 =>
						if(rTMODE='0' or MRAM_WAITr='0')then
							case(RDDAT(6 downto 4))is
								when o"0"|o"1"|o"2"|o"3"|o"4" =>
									--The column is the lower 7 bits.
									iATTRCUL:=conv_integer(RDDAT(6 downto 0));
									fATTR(iATTRCUL)<='1';
								when others =>
									iATTRCUL:=80;
							end case;
							MRAM_RDn<='1';
							if (ATRCNT=iATTRLEN)then
								AOFF<=x"0051";
								ATRCNT<=0;
								if (fATTR(0)='1' or iATTRCUL=0)then
									STATE<=ST_RDATR2;
								else
									STATE<=ST_SETATR;
								end if;
							else
								AOFF<=AOFF+2;
								ATRCNT<=ATRCNT+1;
								STATE<=ST_RDATR;
							end if;
						end if;
					when ST_RDATR2 =>
						RDADR<=RDA;
						MRAM_RDn<='0';
						STATE<=ST_RDATR3;
						if(rTMODE='1')then
							--One cycle more, to pay back the cycle spent registering MRAM_WAIT.
							waitcount<=3;
						end if;
					when ST_RDATR3 =>
						if(rTMODE='0' or MRAM_WAITr='0')then
							if(COLOR='0' or ATTRCOLOR='0')then
								CURATR(0)<='1';
								CURATR(1)<='1';
								CURATR(2)<='1';
							elsif(RDDAT(3)='1')then
								CURATR(0)<=RDDAT(5);
								CURATR(1)<=RDDAT(6);
								CURATR(2)<=RDDAT(7);
							end if;
							if(ATTRCOLOR='0')then
								CURATR(3)<=RDDAT(1);
								CURATR(4)<=RDDAT(2);
								CURATR(5)<=RDDAT(0);
								CURATR(6)<=RDDAT(5);
								CURATR(7)<=RDDAT(7);
								CURATR(8)<=RDDAT(4);
							elsif(RDDAT(3)='0')then
								CURATR(3)<=RDDAT(1);
								CURATR(4)<=RDDAT(2);
								CURATR(5)<=RDDAT(0);
								CURATR(6)<=RDDAT(5);
								CURATR(8)<=RDDAT(4);
							else
								CURATR(7)<=RDDAT(4);
							end if;
							AOFF<=AOFF+2;
							ATRCNT<=ATRCNT+1;
							MRAM_RDn<='1';
							STATE<=ST_SETATR;
						end if;
					when ST_SETATR =>
						TVRAM_ADR<=CDSTADR;
						if(BLKR='1')then
							TVRAM_WDAT<='0' & x"80";
						elsif(FIXATR='1')then
							TVRAM_WDAT<=FIXVAL;
						else
							TVRAM_WDAT<=CURATR;
						end if;
						STATE<=ST_SETATR1;
					when ST_SETATR1 =>
						TVRAM_WR<='1';
						CHARCNT<=CHARCNT+1;
						STATE<=ST_SETATR2;
					when ST_SETATR2 =>
						if(CHARCNT<LINECHARS)then
							CDSTADR<=CDSTADR+x"002";
							if((fATTR(CHARCNT)='1') and (ATRCNT<iATTRLEN+1))then
								STATE<=ST_RDATR2;
							else
								STATE<=ST_SETATR;
							end if;
						else
							if(SMODE='1' and LINESKIP='0')then
								LINESKIP<='1';
							else
								STXTADR<=nxs(STXTADR,LINEADD,RREM,RLA,FOLL and RDAT1,SPLON and FOLL,SPLMa,SPLAa);
								SPLON<='0';
								RREM<=nxr(LINEADD,RREM,RLR,FOLL and RDAT1);
								LINESKIP<='0';
							end if;
							CDSTADR<=SDSTADR+x"0a0";
							SDSTADR<=SDSTADR+x"0a0";
							CHARCNT<=0;
							ATRCNT<=0;
							--The over and under lines end with the row.
							CURATR(8)<='0';
							CURATR(6)<='0';
							FIXATR<='0';
							--A row read ahead, or the last row of a restart frame, leaves it as it is.
							if(PFROW='0' and RSTP='0' and RRLA='0')then
								ATRCARRY<='0' & CURATR(7) & '0' & CURATR(5 downto 0);
							end if;
							if(PFROW='1')then
								PFROW<='0';
								--Not when VRET rises in this same step (then it did not end before VRET),
								--nor when a format setting changed while it ran.
								if((pVRET='0' and VRETr='1') or PFDIRTY='1'
									or SMODE/=pfSMODE or SPCHR/=pfSPCHR or ATTRLEN/=pfATTRLEN or COLOR/=pfCOLOR or ATTRCOLOR/=pfATTRCOLOR)then
									PFOK<='0';
								else
									PFOK<=PFARM;
								end if;
							end if;
							if(capV1S='1' and rTMODE='1' and NOHOLD='0')then
								STATE<=ST_HOLD;
							else
								STATE<=ST_RELBUS;
							end if;
						end if;
					when ST_HOLD =>
						--V1S: keep the bus for the hold length, shorter for a row taken
						--while the CPU is slowed down.
						if(SHHOLD='1')then
							if(shage>=SHDW-2)then
								SHHOLD<='0';
								STATE<=ST_RELBUS;
							end if;
						elsif(capSTR='1' and SHNUM>0 and capCPUMD='1')then
							--8MHz: the rest of the row is in short holds, none for a row
							--held past the start of the retrace
							if(BNDPEND='0')then
								SHACT<='1';
							end if;
							shn<=0;
							shbase<=SHPERIOD;
							shnext<=SHPERIOD+conv_integer(shlfsr(SHJITBITS-1 downto 0));
							STATE<=ST_RELBUS;
						elsif(holdcnt>=HOLDTGT-2+m1adj)then
							STATE<=ST_RELBUS;
						end if;
					when ST_BLANK =>
						TVRAM_ADR<=conv_std_logic_vector(BLKADR,12);
						if(BLKADR mod 2=0)then
							TVRAM_WDAT<='0' & x"00";
						else
							TVRAM_WDAT<='0' & x"80";
						end if;
						STATE<=ST_BLANK1;
					when ST_BLANK1 =>
						TVRAM_WR<='1';
						STATE<=ST_BLANK2;
					when ST_BLANK2 =>
						if(BLKADR=BLANKEND)then
							BLANKD<='1';
							STATE<=ST_IDLE;
						else
							BLKADR<=BLKADR+1;
							if(VT24s='1' and capTEXTEN='1' and LINECNT<REQ)then
								STATE<=ST_IDLE;
							else
								STATE<=ST_BLANK;
							end if;
						end if;
					when ST_RELBUS =>
						BUSREQi<='1';
						BUS_USE<='0';
						HOLDING<='0';
						relcnt<=0;
						if(rTMODE='1')then
							STATE<=ST_WAITREL;
						else
							STATE<=ST_IDLE;
						end if;
					when ST_WAITREL =>
						--Wait until the CPU has taken the bus back and can no longer grant
						--the request just withdrawn.
						if(BUSACKnr='0')then
							relcnt<=0;
						elsif(relcnt=RELQUIET)then
							STATE<=ST_IDLE;
						else
							relcnt<=relcnt+1;
						end if;
					when others=>
						STATE<=ST_RELBUS;
					end case;
					--Keep VRET/HRET edges that arrive while the bus is being released.
					if(STATE/=ST_WAITREL and (STATE/=ST_RELBUS or rTMODE='0'))then
						lVRET<=VRETr;
						lHRET<=HRETr;
					end if;
				end if;

				--V1S: count rasters and row requests.
				if(TEXTENr='0')then
					DMXF<='0';
					DMA0<='0';
					F0OK<='0';
					RRP<='0';
					QLP<='0';
					RSP<='0';
					SPP<='0';
				end if;
				pVRET<=VRETr;
				pHRET<=HRETr;
				lBUSREQ<=BUSREQi;
				shlfsr<=shlfsr(14 downto 0) & (shlfsr(15) xor shlfsr(13) xor shlfsr(12) xor shlfsr(10));
				if(lBUSREQ='1' and BUSREQi='0' and SHHOLD='0')then
					shcnt<=0;
				elsif(shcnt<65535)then
					shcnt<=shcnt+1;
				end if;
				if(SHHOLD='1')then
					if(shage<65535)then
						shage<=shage+1;
					end if;
				else
					shage<=0;
				end if;
				if(HOLDING='1')then
					if(holdcnt<65535)then
						holdcnt<=holdcnt+1;
					end if;
				else
					holdcnt<=0;
				end if;
				if(pVRET='0' and VRETr='1')then
					RASTER<=0;
					REQ<=0;
					XREQ<='0';
					PFARM<='0';
					BNDPEND<='1';
					SHACT<='0';
					CAPD<='0';
					BLANKD<='0';
					BLANKR<='0';
					SINCEBND<=0;
					DMAX<='0';
					DMXF<='0';
					DMA0<=DMXF;
					if(DMXF='0')then
						F0OK<='0';
					end if;
				else
					if(SINCEBND<3)then
						SINCEBND<=SINCEBND+1;
					end if;
					--HRET rises with VRET at raster 0; skip that edge.
					if(pHRET='0' and HRETr='1' and SINCEBND=3)then
						if(RASTER<VWMAX-1)then
							RASTER<=RASTER+1;
						end if;
						if(RASTER+1=CAPLINE)then
							capV1S<=V1S;
							capTEXTEN<=TEXTENr;
							capCPUMD<=CPUMD;
							if(TXLr2=TXLr3)then
								if(conv_integer(TXLr3)<MAXLINES)then
									capROWS<=conv_integer(TXLr3)+1;
								else
									capROWS<=MAXLINES;
								end if;
							end if;
							if(VT24s='1')then
								capROWS<=conv_integer(TSok(17 downto 13));
								capCHRL<=conv_integer(TSok(12 downto 8));
								REQLINE<=conv_integer(TSok(7 downto 0));
							elsif(VMODEs='1')then
								capCHRL<=16;
								REQLINE<=VIV-16;
							else
								capCHRL<=20;
								REQLINE<=VIV-20;
							end if;
							CAPD<='1';
							--A read-ahead taken with other screen settings is not used.
							if((PFOK='1' or PFHOLD='1') and (V1S='0' or VT24s/=pfVT24 or VT15s/=pfVT15 or TEXTENr/=pfTEXTEN
								or (VT24s='1' and (conv_integer(TSok(17 downto 13))/=pfROWS or conv_integer(TSok(12 downto 8))/=pfCHRL))))then
								PFRST<='1';
							end if;
						elsif(CAPD='1' and RASTER+1=REQLINE and REQ<capROWS)then
							REQ<=REQ+1;
							REQLINE<=REQLINE+capCHRL;
						elsif(CAPD='1' and RASTER+1=REQLINE and VT24s='1' and capV1S='1')then
							--One row after the last row: the hold-only request.
							XREQ<='1';
							REQLINE<=REQLINE+capCHRL;
						end if;
						if(CAPD='1' and RASTER+1=REQLINE and TEXTENr='1'
							and ((REQ>0 and REQ<capROWS and DMA0='1') or (REQ>=capROWS and DMAX='0'))
							and (SMODE='0' or REQ>=capROWS or (REQ mod 2)=0))then
							DMAT<=DMAT+1;
							DMAN<=LINEADD(7 downto 0);
							if(REQ>=capROWS and SMODE='1')then
								DNX<=2;
							elsif(REQ>=capROWS)then
								DNX<=1;
							elsif(SMODE='1')then
								DNX<=REQ+2;
							else
								DNX<=REQ+1;
							end if;
							if(REQ>=capROWS)then
								EPOCH<=EPOCH+1;
								--V2, a restart frame: its last row shows the row 0 moved now
								if(DMA0='0' and capV1S='0' and capROWS>=2)then
									QLP<='1';
									QLE<=REPOCH;
								end if;
								DMXF<='1';
								F0A<=DMNXA;
								F0R<=sat(conv_integer(DMNXR));
								F0B<=DMRLA;
								F0C<=sat(conv_integer(DMRLR));
								if(DMOK='1' and conv_integer(DMRLR)>=120 and LINEADD=x"0078")then
									F0OK<='1';
								else
									F0OK<='0';
								end if;
							end if;
						end if;
						if(CAPD='1' and RASTER+1=REQLINE and REQ>=capROWS)then
							DMAX<='1';
						end if;
					end if;
				end if;

				--CRTC RESET: white from now on; the next frame starts white. A row 0 read ahead
				--with the old attribute is not used: one still running or ended before the
				--retrace is dropped, and one already taken is read again at its row.
				rCRTRST<=CRTRST;
				if(CRTRST/=rCRTRST)then
					ATRCARRY<="000000111";
					CURATR<="000000111";
					RSTP<='1';
					PFDIRTY<='1';
					PFOK<='0';
					if(PFHOLD='1')then
						PFRST<='1';
					end if;
				end if;
				--A write to 64h or 65h: the rows the 8257 moves from now on come from the new values
				lDMWE<=DMWE;
				--The toggle comes with a change of DMWE, so it is taken with the first change seen
				if(DMWE/=lDMWE)then
					lDMSPL<=DMSPL;
				end if;
				--V2: the row just moved changed over to the written address in its middle (fhp5): read it
				--again from its start, the rest of it from the new address (also the last row)
				if(SPOK='1' and not evu)then
					SPP<='1';
					SPK<=EVK-1;
					SPE<=EPOCH;
					SPRA<=DMRSA;
					SPRR<=sat(conv_integer(DMNXR)+conv_integer(LINEADD));
					SPRB<=DMRLA;
					SPRC<=sat(conv_integer(DMRLR));
					SPMr<=DMSPM;
					SPAr<=DMSPA;
				end if;
				if(DMWE/=lDMWE and TEXTENr='1' and not evu)then
					iRRK:=EVK;
					if(EVOK='1' and iRRK=0 and not (capV1S='1' and PFROW='1'))then
						--row 0 of the next frame, still waiting to be moved
						RSP<='1';
						RSE<=EPOCH;
						RSA<=DMNXA;
						RSR<=sat(conv_integer(DMNXR));
						RSB<=DMRLA;
						RSC<=sat(conv_integer(DMRLR));
					elsif(EVOK='1')then
						RRP<='1';
						RRK<=iRRK;
						RRE<=EPOCH;
						RRA<=DMNXA;
						RRR<=sat(conv_integer(DMNXR));
						RRB<=DMRLA;
						RRC<=sat(conv_integer(DMRLR));
						--V1S has started reading that row (with the bus, not read again): the new values
						--take effect one row later
						if(capV1S='1' and EPOCH=REPOCH and ((PFROW='1' and iRRK=0) or (PFROW='0' and iRRK+1=LINECNT)))then
							--(S=1: the next row with text, as the blank row between moves the address on)
							if(PFROW='1' and SMODE='1')then
								RRK<=2;
							elsif(PFROW='1')then
								RRK<=1;
							elsif(SMODE='1')then
								RRK<=LINECNT+1;
							else
								RRK<=LINECNT;
							end if;
							RRA<=nxa(DMNXA,LINEADD,conv_integer(DMNXR),DMRLA,'1');
							RRR<=sat(nxr(LINEADD,conv_integer(DMNXR),conv_integer(DMRLR),'1'));
						end if;
					elsif(iRRK<capROWS)then
						--Not one to follow: the rest is drawn as before (this frame and the next, as
						--a frame may start in this same step)
						RRP<='0';
						RSP<='0';
						SPP<='0';
						FOL<='0';
						F0OK<='0';
					end if;
				end if;
				--Rows that are not 120 bytes stop following the 8257 for the rest of the frame
				--(last, so a frame start in the same step does not set it again)
				if(LINEADD/=x"0078")then
					FOL<='0';
					SPP<='0';
					SPLON<='0';
				end if;
			end if;
		end if;
	end process;
end MAIN;
						
			
				
					