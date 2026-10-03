LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.VIDEO_TIMING_pkg.all;

entity TRAMCONV is
generic(
	--V1S: clk21m cycles the bus is held per text row, at 4MHz and 8MHz
	V1SHOLD4	:integer	:=3766;
	V1SHOLD8	:integer	:=3325;
	--Same, for rows taken while the CPU is slowed down by GVSTR
	V1SHOLD4S	:integer	:=2356;
	V1SHOLD8S	:integer	:=2742
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
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end TRAMCONV;

architecture MAIN of TRAMCONV is
constant LINECHARS	:integer	:=80;
constant MAXLINES	:integer	:=25;
signal	STXTADR	:std_logic_vector(15 downto 0);
signal	SATRADR	:std_logic_vector(15 downto 0);
signal	CTXTADR	:std_logic_vector(15 downto 0);
signal	CATRADR	:std_logic_vector(15 downto 0);
signal	SDSTADR	:std_logic_vector(11 downto 0);
signal	CDSTADR	:std_logic_vector(11 downto 0);
signal	ATRCNT	:integer range 0 to 19;
signal	CURATR	:std_logic_vector(8 downto 0);
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
--canceled. A line is 640 clocks (31kHz), 806 clocks (24kHz) or 1252 clocks (15kHz).
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
--TSET, taken when TSr2 and TSr3 agree. Until then (a few clocks after reset, before
--any CAPLINE), the 24kHz 25-line set.
constant TSDEF	:std_logic_vector(17 downto 0)	:=conv_std_logic_vector(ROWSDEF24,5) & conv_std_logic_vector(CHRLDEF24,5) & conv_std_logic_vector(VRETDEF24-CHRLDEF24,8);
signal	TSr,TSr2,TSr3,TSok	:std_logic_vector(17 downto 0);
signal	capSTR		:std_logic;	-- GVSTR when the bus was taken for this row
signal	holdcnt		:integer range 0 to 65535;
signal	HOLDING		:std_logic;
signal	SINCEBND	:integer range 0 to 3;
signal	BLKADR		:integer range 0 to BLANKEND;

component cdc_sync2
port(
	d		:in std_logic;
	q		:out std_logic;

	clk		:in std_logic
);
end component;

--BUSACKn and MRAM_WAIT cross from the rclk domain into clk21m.
--Sample the asynchronous inputs once before the FSM uses them.
signal	MRAM_WAITr	:std_logic;
signal	BUSACKnr	:std_logic;

--Sample the remaining cross-domain inputs before use by the FSM.
signal	VRETr,HRETr	:std_logic;
signal	TEXTENr		:std_logic;
--TXTLINES from the CPU clock, taken when TXLr2 and TXLr3 agree.
signal	TXLr,TXLr2,TXLr3	:std_logic_vector(5 downto 0);

--Keep the CDC sampling registers from being duplicated or retimed.
attribute preserve : boolean;
attribute dont_replicate : boolean;
attribute dont_retime : boolean;
attribute preserve of MRAM_WAITr, BUSACKnr, VRETr, HRETr, TEXTENr, TXLr, TSr : signal is true;
attribute dont_replicate of MRAM_WAITr, BUSACKnr, VRETr, HRETr, TEXTENr, TXLr, TSr : signal is true;
attribute dont_retime of MRAM_WAITr, BUSACKnr, VRETr, HRETr, TEXTENr, TXLr, TSr : signal is true;

begin

	RDDAT<=MRAM_DAT when rTMODE='1' else TRAM_DAT;
	TRAM_ADR<=RDADR(11 downto 0);
	MRAM_ADR<=RDADR;
	iATTRLEN<=conv_integer(ATTRLEN);
	LINEADD<=x"0052" + (x"00" & "00" & ATTRLEN & "0") when SPCHR='0' else x"0050";
	LINES<=conv_integer(TXTLINES);

	VMS	:cdc_sync2 port map(VMODE,VMODEs,clk);
	GSS	:cdc_sync2 port map(GVSTR,GVSTRs,clk);
	V24S	:cdc_sync2 port map(VT24,VT24s,clk);
	
	process(clk,rstn)
	variable iNXTATR	:integer range 0 to 255;
	variable iCOUNTER	:integer range 0 to 80;
	variable iATTRCUL	:integer range 0 to 80;
	begin
		if(rstn='0')then
			STATE<=ST_IDLE;
			STXTADR<=(others=>'0');
			SATRADR<=x"0050";
			CTXTADR<=(others=>'0');
			CATRADR<=x"0050";
			ATRCNT<=0;
			CURATR<="000000111";
			CHARCNT<=0;
			SDSTADR<=(others=>'0');
			CDSTADR<=(others=>'0');
			LINECNT<=0;
			lVRET<='1';
			lHRET<='1';
			rTVRMODE<='0';
			rTMODE<='0';
			-- rCOLOR<='0';
			BUSREQn<='1';
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
			BLKADR<=0;
			SINCEBND<=3;
		elsif(clk' event and clk='1')then
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
			if(waitcount>0)then
				waitcount<=waitcount-1;
			else
				--Only true in cycles where the state below does nothing, so the two
				--assignments to STATE cannot collide.
				if(STATE=ST_GETBUS and BUSACKnr='1')then
					if(stuckcnt=STUCKMAX)then
						stuckcnt<=0;
						STATE<=ST_RELBUS;
						if(capV1S='1')then
							--V1S: drop the row, but step to the next one as ST_SETATR2 does.
							if(SMODE='1' and LINESKIP='0')then
								LINESKIP<='1';
							else
								CTXTADR<=STXTADR+LINEADD;
								STXTADR<=STXTADR+LINEADD;
								CATRADR<=SATRADR+LINEADD;
								SATRADR<=SATRADR+LINEADD;
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
					if(capV1S='1')then
						if(BNDPEND='1')then
							--New frame: the same restart as on VRET below.
							STXTADR<=TADR_TOP;
							SATRADR<=TADR_TOP+x"0050";
							CTXTADR<=TADR_TOP;
							CATRADR<=TADR_TOP+x"0050";
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
							CURATR<="000000111";
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
						elsif(CAPD='1' and capTEXTEN='1' and LINECNT<REQ)then
							--Start of a row: as on HRET below.
							CHARCNT<=0;
							ATRCNT<=0;
							LINECNT<=LINECNT+1;
							if(rTMODE='1')then
								STATE<=ST_GETBUS;
								BUSREQn<='0';
							elsif(rTVRMODE='1')then
								STATE<=ST_IDLE;
							else
								STATE<=ST_RDTXT;
							end if;
							for iCOUNTER in 0 to 79 loop
								fATTR(iCOUNTER)<='0';
							end loop;
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
						STXTADR<=TADR_TOP;
						SATRADR<=TADR_TOP+x"0050";
						SDSTADR<=(others=>'0');
						CTXTADR<=TADR_TOP;
						CATRADR<=TADR_TOP+x"0050";
						SDSTADR<=(others=>'0');
						CDSTADR<=(others=>'0');
						rTVRMODE<=TVRMODE;
						rTMODE<=TMODE;
						-- rCOLOR<=COLOR;
						TVRAM_ADR<=(others=>'0');
						LINECNT<=0;
						CURATR<="000000111";
						LINESKIP<='0';
					elsif(lHRET='1' and HRETr='0' and TEXTENr='1')then
						CHARCNT<=0;
						ATRCNT<=0;
						if(LINECNT<MAXLINES)then
	--					if(LINECNT<LINES-1)then
							LINECNT<=LINECNT+1;
							if(rTMODE='1')then
								STATE<=ST_GETBUS;
								BUSREQn<='0';
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
						STATE<=ST_RDTXT;
						BUS_USE<='1';
						HOLDING<='1';
						capSTR<=GVSTRs;
					end if;
				when ST_RDTXT =>
					MRAM_RDn<='0';
					RDADR<=CTXTADR;
					STATE<=ST_RDTXT1;
					if(rTMODE='1')then
						--One cycle more, to pay back the cycle spent registering MRAM_WAIT.
						waitcount<=3;
					end if;
				when ST_RDTXT1 =>
					if(rTMODE='0' or MRAM_WAITr='0')then
						MRAM_RDn<='1';
						TVRAM_ADR<=CDSTADR;
						if (LINESKIP='1')then
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
						CTXTADR<=CTXTADR+1;
						STATE<=ST_RDTXT;
						CHARCNT<=CHARCNT+1;
					else
						CDSTADR<=SDSTADR+"001";
						CHARCNT<=0;
						if (LINESKIP='1')then
							STATE<=ST_SKIPATR;
						elsif (SPCHR='1')then
							STATE<=ST_NOATTR;
						else
							STATE<=ST_RDATR;
						end if;
					end if;
				when ST_NOATTR =>
					CURATR<='0' & x"07";
					STATE<=ST_SETATR;
				when ST_SKIPATR =>
					CURATR<='0' & x"80";
					STATE<=ST_SETATR;
				when ST_RDATR =>
					MRAM_RDn<='0';
					RDADR<=CATRADR;
					STATE<=ST_RDATR1;
					if(rTMODE='1')then
						--One cycle more, to pay back the cycle spent registering MRAM_WAIT.
						waitcount<=3;
					end if;
				when ST_RDATR1 =>
					if(rTMODE='0' or MRAM_WAITr='0')then
						case(RDDAT(6 downto 4))is
							when o"0"|o"1"|o"2"|o"3"|o"4" =>
								iATTRCUL:=conv_integer(RDDAT);
								fATTR(iATTRCUL)<='1';
							when others =>
								iATTRCUL:=80;
						end case;
						MRAM_RDn<='1';
						if (ATRCNT=iATTRLEN)then
							CATRADR<=SATRADR+1;
							ATRCNT<=0;
							if (fATTR(0)='1' or iATTRCUL=0)then
								STATE<=ST_RDATR2;
							else
								STATE<=ST_SETATR;
							end if;
						else
							CATRADR<=CATRADR+2;
							ATRCNT<=ATRCNT+1;
							STATE<=ST_RDATR;
						end if;
					end if;
				when ST_RDATR2 =>
					RDADR<=CATRADR;
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
						CATRADR<=CATRADR+2;
						ATRCNT<=ATRCNT+1;
						MRAM_RDn<='1';
						STATE<=ST_SETATR;
					end if;
				when ST_SETATR =>
					TVRAM_ADR<=CDSTADR;
					TVRAM_WDAT<=CURATR;
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
							CTXTADR<=STXTADR;
							CATRADR<=SATRADR;
							LINESKIP<='1';
						else
							CTXTADR<=STXTADR+LINEADD;
							STXTADR<=STXTADR+LINEADD;
							CATRADR<=SATRADR+LINEADD;
							SATRADR<=SATRADR+LINEADD;
							LINESKIP<='0';
						end if;
						CDSTADR<=SDSTADR+x"0a0";
						SDSTADR<=SDSTADR+x"0a0";
						CHARCNT<=0;
						ATRCNT<=0;
						if(capV1S='1' and rTMODE='1')then
							STATE<=ST_HOLD;
						else
							STATE<=ST_RELBUS;
						end if;
					end if;
				when ST_HOLD =>
					--V1S: keep the bus for the hold length, shorter for a row taken
					--while the CPU is slowed down.
					if((capCPUMD='0' and capSTR='0' and holdcnt>=V1SHOLD4-2) or (capCPUMD='1' and capSTR='0' and holdcnt>=V1SHOLD8-2) or
					   (capCPUMD='0' and capSTR='1' and holdcnt>=V1SHOLD4S-2) or (capCPUMD='1' and capSTR='1' and holdcnt>=V1SHOLD8S-2))then
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
					BUSREQn<='1';
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
			pVRET<=VRETr;
			pHRET<=HRETr;
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
				BNDPEND<='1';
				CAPD<='0';
				BLANKD<='0';
				BLANKR<='0';
				SINCEBND<=0;
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
					elsif(CAPD='1' and RASTER+1=REQLINE and REQ<capROWS)then
						REQ<=REQ+1;
						REQLINE<=REQLINE+capCHRL;
					end if;
				end if;
			end if;
		end if;
	end process;
end MAIN;
						
			
				
					