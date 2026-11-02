LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.FDC_timing.all;

entity FDemu is
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
	dstep		:in std_logic_vector(3 downto 0);	-- 1: 2D image, the drive moves 2 positions per STEP
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
end FDemu;

architecture rtl of FDemu is
constant 	maxbwidth	:integer	:=4000*sysclk/1000000;
-- bit cells in 1/256 clocks, rounded (sysclk in kHz): BR_ns*sysclk*256/10^6
constant	cellf4000	:integer	:=(4000*sysclk*16+31250)/62500;
constant	cellf2000	:integer	:=(2000*sysclk*16+31250)/62500;
constant	cellf1000	:integer	:=(1000*sysclk*16+31250)/62500;
signal	TRAMRDDAT		:std_logic_vector(8 downto 0);
signal	RDMFM		:std_logic;
signal	deminit		:std_logic;
signal	dembreak	:std_logic;
signal	fmrxdat		:std_logic_vector(7 downto 0);
signal	fmrxed		:std_logic;
signal	fmmf8det	:std_logic;
signal	fmmfbdet	:std_logic;
signal	fmmfcdet	:std_logic;
signal	fmmfedet	:std_logic;
signal	fmcurwid	:integer range 0 to maxbwidth*2;
signal	mfmrxdat	:std_logic_vector(7 downto 0);
signal	mfmrxed		:std_logic;
signal	rxed		:std_logic;
signal	mfmma1det	:std_logic;
signal	mfmmc2det	:std_logic;
signal	mfmcurwid	:integer range 0 to maxbwidth;
signal	fmrxbit		:std_logic;
signal	mfmrxbit	:std_logic;

signal	fmdeminit	:std_logic;
signal	mfmdeminit	:std_logic;
signal	txdat		:std_logic_vector(7 downto 0);
signal	mcrdat		:std_logic;
signal	txwr		:std_logic;
signal	fmtxwr		:std_logic;
signal	mfmtxwr		:std_logic;
signal	fmmf8wr		:std_logic;
signal	fmmfbwr		:std_logic;
signal	fmmfcwr		:std_logic;
signal	fmmfewr		:std_logic;
signal	mfmma1wr	:std_logic;
signal	mfmmc2wr	:std_logic;
signal	fmtxemp		:std_logic;
signal	mfmtxemp	:std_logic;
signal	txemp		:std_logic;
signal	fmwrbit		:std_logic;
signal	mfmwrbit	:std_logic;
signal	txwrbit		:std_logic;
signal	txwrbitex	:std_logic;
-- signal	fmtxend		:std_logic;
-- signal	mfmtxend	:std_logic;
signal	txend		:std_logic;
signal	modsftfm		:std_logic;
signal	modsftmfm		:std_logic;
signal	modbreak	:std_logic;

signal	curpos		:std_logic_vector(13 downto 0);
signal	lcurpos		:std_logic_vector(13 downto 0);
signal	tpos		:std_logic_vector(13 downto 0);
signal	tposinc		:std_logic_vector(13 downto 0);
signal	tposnext	:std_logic_vector(13 downto 0);
signal	tposbase	:std_logic_vector(13 downto 0);
signal	tsel		:std_logic_vector(10 downto 0);
signal	ltsel		:std_logic_vector(10 downto 0);
signal	rebase		:std_logic;
signal	tposrb		:std_logic;

signal	bitlenw			:integer range 0 to maxbwidth;
signal	bitlenrf,bitlenrm	:integer range 0 to cellf4000;

signal	curtrack	:std_logic_vector(6 downto 0);
signal	dstepx		:std_logic;
signal	pastimg		:std_logic;	-- the head is past the tracks built from the image
signal	rdatx		:std_logic_vector(15 downto 0);
signal	curtrack0	:std_logic_vector(6 downto 0);
signal	curtrack1	:std_logic_vector(6 downto 0);
signal	curtrack2	:std_logic_vector(6 downto 0);
signal	curtrack3	:std_logic_vector(6 downto 0);
signal	ldstep		:std_logic_vector(3 downto 0);
signal	tracklenx	:std_logic_vector(13 downto 0);
signal	tracklen0	:std_logic_vector(13 downto 0);
signal	tracklen1	:std_logic_vector(13 downto 0);
signal	tracklen2	:std_logic_vector(13 downto 0);
signal	tracklen3	:std_logic_vector(13 downto 0);

signal	fdmode0	:std_logic_vector(1 downto 0);
signal	fdmode1	:std_logic_vector(1 downto 0);
signal	fdmode2	:std_logic_vector(1 downto 0);
signal	fdmode3	:std_logic_vector(1 downto 0);
signal	selfdmode:std_logic_vector(1 downto 0);

signal	txenable	:std_logic;
signal	fdenbl0		:std_logic;
signal	fdenbl1		:std_logic;
signal	fdenbl2		:std_logic;
signal	fdenbl3		:std_logic;
signal	l1fdenable	:std_logic_vector(3 downto 0);
signal	l2fdenable	:std_logic_vector(3 downto 0);

signal	rxwr	:std_logic;
signal	GAPS	:integer	range 0 to 31;
signal	SYNCS	:integer	range 0 to 15;
signal	GAPDAT	:std_logic_vector(7 downto 0);
signal	GSDAT	:std_logic_vector(7 downto 0);
signal	GSwrite	:std_logic;
constant extcount	:integer	:=(sysclk*WR_WIDTH)/1000000;

type wrstate_t is(
	ws_idle,
	ws_ramwait,
	ws_write
);
signal	wrstate	:wrstate_t;

--after a STEP, stop the disk for stoptime and give no read data for settletime
--(the disk turns again after the stop), both in 0.1 ms from the last STEP;
--an index hole that comes round in that time is not given either;
--after the stop, each STEP holds the disk 0.08 ms more (xstop, in 0.02 ms, up to 255)
constant stoptime		:integer	:=119;
constant xstopstep	:integer	:=4;
constant xstopmax	:integer	:=255;
constant settletime	:integer	:=550;
type settle_t is array(0 to 3) of integer range 0 to settletime;
signal	settle	:settle_t;
signal	tcnt	:integer range 0 to sysclk/10-1;
signal	settlex	:integer range 0 to settletime;
type xstop_t is array(0 to 3) of integer range 0 to xstopmax;
signal	xstop	:xstop_t;
signal	xstopx	:integer range 0 to xstopmax;
signal	rotstop	:std_logic;
signal	nodata	:std_logic;
signal	idxmask	:std_logic;
signal	lidxz	:std_logic;

component fmmod
port(
	txdat	:in std_logic_vector(7 downto 0);
	txwr	:in std_logic;
	txmf8	:in std_logic;
	txmfb	:in std_logic;
	txmfc	:in std_logic;
	txmfe	:in std_logic;
	break	:in std_logic;
	
	txemp	:out std_logic;
	txend	:out std_logic;
	
	bitout	:out std_logic;
	writeen	:out std_logic;
	
	sft		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component mfmmod
port(
	txdat	:in std_logic_vector(7 downto 0);
	txwr	:in std_logic;
	txma1	:in std_logic;
	txmc2	:in std_logic;
	break	:in std_logic;
	
	txemp	:out std_logic;
	txend	:out std_logic;
	
	bitout	:out std_logic;
	writeen	:out std_logic;
	
	sft		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component fmdem
generic(
	bwidth	:integer	:=22
);
port(
	bitlen	:in integer range 0 to bwidth;
	
	datin	:in std_logic;
	
	init	:in std_logic;
	break	:in std_logic;
	
	RXDAT	:out std_logic_vector(7 downto 0);
	RXED	:out std_logic;
	DetMF8	:out std_logic;
	DetMFB	:out std_logic;
	DetMFC	:out std_logic;
	DetMFE	:out std_logic;
	
	curlen	:out integer range 0 to bwidth*2;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component mfmdem
generic(
	bwidth	:integer	:=22
);
port(
	bitlen	:in integer range 0 to bwidth;
	
	datin	:in std_logic;
	
	init	:in std_logic;
	break	:in std_logic;
	
	RXDAT	:out std_logic_vector(7 downto 0);
	RXED	:out std_logic;
	DetMA1	:out std_logic;
	DetMC2	:out std_logic;
	
	curlen	:out integer range 0 to bwidth*2;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component sftfrac
generic(
	maxlen	:integer	:=100*256
);
port(
	len		:in integer range 0 to maxlen;
	sft		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component signext
generic(
	extmax	:integer	:=10
);
port(
	len		:in integer range 0 to extmax;
	signin	:in std_logic;
	
	signout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component mkgapsync
port(
	GAPS	:in integer	range 0 to 31;
	SYNCS	:in integer	range 0 to 15;
	
	GAPDAT	:in std_logic_vector(7 downto 0);
	
	WRENn		:in std_logic;
	
	MKEN		:out std_logic;
	MKDAT		:out std_logic_vector(7 downto 0);
	MK			:out std_logic;
	MKDONE		:in std_logic	:='1';
	
	clk		:in std_logic;
	rstn		:in std_logic
);
end component;

begin
	process(clk,rstn)begin
		if(rstn='0')then
			fdmode0<="00";
			fdmode1<="00";
			fdmode2<="00";
			fdmode3<="00";
		elsif(clk' event and clk='1')then
			if(modeset(0)='1')then
				fdmode0<=rdfdmode(1 downto 0);
			end if;
			if(modeset(1)='1')then
				fdmode1<=rdfdmode(3 downto 2);
			end if;
			if(modeset(2)='1')then
				fdmode2<=rdfdmode(5 downto 4);
			end if;
			if(modeset(3)='1')then
				fdmode3<=rdfdmode(7 downto 6);
			end if;
			if(rxed='1')then
				case USEL is
				when "00" =>
					fdmode0(1)<=WRFDMODE(1);
				when "01" =>
					fdmode1(1)<=WRFDMODE(1);
				when "10" =>
					fdmode2(1)<=WRFDMODE(1);
				when "11" =>
					fdmode3(1)<=WRFDMODE(1);
				when others =>
				end case;
			end if;
		end if;
	end process;
	process(clk,rstn)begin
		if(rstn='0')then
			fdenbl0<='0';
			fdenbl1<='0';
			fdenbl2<='0';
			fdenbl3<='0';
		elsif(clk' event and clk='1')then
			l1fdenable<=fdenable;
			case USEL is
			when "00" =>
				fdenbl0<=l1fdenable(0);
			when "01" =>
				fdenbl1<=l1fdenable(1);
			when "10" =>
				fdenbl2<=l1fdenable(2);
			when "11" =>
				fdenbl3<=l1fdenable(3);
			when others =>
			end case;
		end if;	
	end process;
	
	selfdmode<=	fdmode0	when USEL="00" else
					fdmode1	when USEL="01" else
					fdmode2	when USEL="10" else
					fdmode3	when USEL="11" else
					"00";
	curfdmode<=fdmode3 & fdmode2 & fdmode1 & fdmode0;
	txenable<= fdenbl0 when USEL="00" else
					fdenbl1	when USEL="01" else
					fdenbl2	when USEL="10" else
					fdenbl3	when USEL="11" else
					'0';

				
	bitlenw<=	4000*sysclk/1000000	when WRFDMODE(1)='0' else 2000*sysclk/1000000;
				
	tracklen0<=	conv_std_logic_vector( 6250,14) when fdmode0="00" else
				conv_std_logic_vector( 8000,14) when fdmode0="01" else
				conv_std_logic_vector(10416,14) when fdmode0="10" else
				conv_std_logic_vector(12500,14) when fdmode0="11" else
				(others=>'0');
	tracklen1<=	conv_std_logic_vector( 6250,14) when fdmode1="00" else
				conv_std_logic_vector( 8000,14) when fdmode1="01" else
				conv_std_logic_vector(10416,14) when fdmode1="10" else
				conv_std_logic_vector(12500,14) when fdmode1="11" else
				(others=>'0');
	tracklen2<=	conv_std_logic_vector( 6250,14) when fdmode2="00" else
				conv_std_logic_vector( 8000,14) when fdmode2="01" else
				conv_std_logic_vector(10416,14) when fdmode2="10" else
				conv_std_logic_vector(12500,14) when fdmode2="11" else
				(others=>'0');
	tracklen3<=	conv_std_logic_vector( 6250,14) when fdmode3="00" else
				conv_std_logic_vector( 8000,14) when fdmode3="01" else
				conv_std_logic_vector(10416,14) when fdmode3="10" else
				conv_std_logic_vector(12500,14) when fdmode3="11" else
				(others=>'0');
	tracklenx<=	tracklen0	when USEL="00" else
				tracklen1	when USEL="01" else
				tracklen2	when USEL="10" else
				tracklen3	when USEL="11" else
				(others=>'0');
	tracklen<=tracklenx;

	process(clk,rstn)begin
		if(rstn='0')then
			txwr<='0';
		elsif(clk' event and clk='1')then
			txwr<='0';
			--the disk keeps turning while the motor is off, as on a FH
			--(the read data and the index are given only while the motor is on)
			if(rotstop='0')then
				if(WRENn='1' and txemp='1' and txenable='1')then
					txwr<='1';
				end if;
			end if;
		end if;
	end process;
	
	--one turn is counted in time, not in words: an FM word takes the time of 2 MFM words
	--when another drive, side or track is selected or the image is replaced, restart the time from the word position, as the position was kept in words before;
	--the first word after it counts as MFM (its density may still be that of the word before), so that the turn never ends early
	tsel<=USEL & curtrack & siden & txenable;
	tposrb<='1' when tsel/=ltsel or rebase='1' else '0';
	tposinc<=	"00000000000001" when tposrb='1' else
				"00000000000001" when txwr='1' and RDMFM='1' else
				"00000000000001" when txwr='0' and WRMFM='1' else
				"00000000000010";
	tposbase<=curpos when tposrb='1' else tpos;
	tposnext<=tposbase+tposinc;

	process(clk,rstn)begin
		if(rstn='0')then
			curpos<=(others=>'0');
			tpos<=(others=>'0');
			ltsel<=(others=>'0');
			rebase<='0';
		elsif(clk' event and clk='1')then
			ltsel<=tsel;
			if(tsel/=ltsel)then
				rebase<='1';
			end if;
			if(txwr='1' or (WRENn='0' and rxed='1'))then
				if(tsel=ltsel)then
					rebase<='0';
				end if;
				if(tposnext>=tracklenx)then
					curpos<=(others=>'0');
					tpos<=(others=>'0');
				else
					curpos<=curpos+1;
					tpos<=tposnext;
				end if;
			elsif(tsel/=ltsel)then
				tpos<=curpos;
			end if;
		end if;
	end process;
				
	
	--past the tracks built from the image (2D: cylinder 42 on, others: cylinder 82 on) nothing was written to the RAM:
	--play an unformatted MFM track there, as for an unformatted track in the image, not what is left in the RAM
	dstepx<=	dstep(0) when USEL="00" else
				dstep(1) when USEL="01" else
				dstep(2) when USEL="10" else
				dstep(3);
	pastimg<=	'1' when dstepx='1' and curtrack>="1010100" else
				'1' when dstepx='0' and curtrack>="1010010" else
				'0';
	rdatx<=x"024e" when pastimg='1' else ramrdat;
	txdat<=rdatx(7 downto 0);
	mcrdat<=rdatx(8);
	RDMFM<=rdatx(9);
	
	fmtxwr<=	'0' when RDMFM='1' else
				'0' when mcrdat='1' else
				txwr;
	fmmf8wr<=	'0' when RDMFM='1' else
				'0' when mcrdat='0' else
				'1' when txdat=x"f8" and txwr='1' else
				'0';
	
	fmmfbwr<=	'0' when RDMFM='1' else
				'0' when mcrdat='0' else
				'1' when txdat=x"fb" and txwr='1' else
				'0';
	
	fmmfcwr<=	'0' when RDMFM='1' else
				'0' when mcrdat='0' else
				'1' when txdat=x"fc" and txwr='1' else
				'0';

	fmmfewr<=	'0' when RDMFM='1' else
				'0' when mcrdat='0' else
				'1' when txdat=x"fe" and txwr='1' else
				'0';
	
	mfmtxwr<=	'0' when RDMFM='0' else
				'0' when mcrdat='1' else
				txwr;
				
	mfmma1wr<=	'0' when RDMFM='0' else
				'0' when mcrdat='0' else
				'1' when txdat=x"a1" and txwr='1' else
				'0';
			
	mfmmc2wr<=	'0' when RDMFM='0' else
				'0' when mcrdat='0' else
				'1' when txdat=x"c2" and txwr='1' else
				'0';
			
	indexn<='0' when curpos="00000000000000" and MOTOR='1' and ((lidxz='0' and nodata='0') or (lidxz='1' and idxmask='0')) else '1';
	
	-- the read data is clocked by fractional bit cells, so the rotation and the
	-- data rate follow sysclk exactly
	bitlenrf<=	cellf4000	when selfdmode(1)='0' else cellf2000;
	bitlenrm<=	cellf2000	when selfdmode(1)='0' else cellf1000;
	wsftfm	:sftfrac generic map(cellf4000) port map(bitlenrf,modsftfm,clk,rstn);
	wsftmfm	:sftfrac generic map(cellf4000) port map(bitlenrm,modsftmfm,clk,rstn);
	
	fmtx	:fmmod port map(
		txdat	=>txdat,
		txwr	=>fmtxwr,
		txmf8	=>fmmf8wr,
		txmfb	=>fmmfbwr,
		txmfc	=>fmmfcwr,
		txmfe	=>fmmfewr,
		break	=>'0',
		
		txemp	=>fmtxemp,
		-- txend	=>fmtxend,
		
		bitout	=>fmwrbit,
		writeen	=>open,
		
		sft		=>modsftfm,
		clk		=>clk,
		rstn	=>rstn
	);
	
	mfmtx	:mfmmod port map(
		txdat	=>txdat,
		txwr	=>mfmtxwr,
		txma1	=>mfmma1wr,
		txmc2	=>mfmmc2wr,
		break	=>'0',
		
		txemp	=>mfmtxemp,
		-- txend	=>mfmtxend,
		
		bitout	=>mfmwrbit,
		writeen	=>open,
		
		sft		=>modsftmfm,
		clk		=>clk,
		rstn	=>rstn
	);
	txemp<=fmtxemp and mfmtxemp;
	txwrbit<=fmwrbit or mfmwrbit;
	wdatext	:signext generic map(extcount) port map(extcount,txwrbit,txwrbitex,clk,rstn);
	
	RDBITn<='1' when nodata='1' or MOTOR='0' else not txwrbitex;
	
	fmrxbit<=not WRBITn when WRMFM='0' and WRENn='0' else '0';
	mfmrxbit<=not WRBITn when WRMFM='1' and WRENn='0' else '0';
	
	-- Start the receivers again at each write as well: the density can change after the
	-- motor has started, and they take the bit length only here.
	process(clk,rstn)
	variable lREADY	:std_logic;
	variable lWRENn	:std_logic;
	begin
		if(rstn='0')then
			lREADY:='0';
			lWRENn:='1';
			fmdeminit<='0';
			mfmdeminit<='0';
		elsif(clk' event and clk='1')then
			fmdeminit<='0';
			mfmdeminit<='0';
			if((MOTOR='1' and lREADY='0') or (WRENn='0' and lWRENn='1'))then
				if(WRMFM='0')then
					fmdeminit<='1';
				else
					mfmdeminit<='1';
				end if;
			end if;
			lREADY:=MOTOR;
			lWRENn:=WRENn;
		end if;
	end process;
	
	fmrx	:fmdem generic map(maxbwidth) port map(
		bitlen	=>bitlenw,
		
		datin	=>fmrxbit,
		
		init	=>fmdeminit,
		break	=>WRENn,
		
		RXDAT	=>fmrxdat,
		RXED	=>fmrxed,
		DetMF8	=>fmmf8det,
		DetMFB	=>fmmfbdet,
		DetMFC	=>fmmfcdet,
		DetMFE	=>fmmfedet,
		
		curlen	=>open,
		
		clk		=>clk,
		rstn	=>rstn
	);

	mfmrx	:mfmdem generic map(maxbwidth/2)port map(
		bitlen	=>bitlenw/2,
		
		datin	=>mfmrxbit,
		
		init	=>mfmdeminit,
		break	=>WRENn,
		
		RXDAT	=>mfmrxdat,
		RXED	=>mfmrxed,
		DetMA1	=>mfmma1det,
		DetMC2	=>mfmmc2det,
		
		curlen	=>open,
		
		clk		=>clk,
		rstn	=>rstn
	);
	
	GAPS<=	4 when WRMFM='0' else 8;
	SYNCS<=	6 when WRMFM='0' else 12;
	GAPDAT<=x"ff" when WRMFM='0' else x"4e";
	
	GS	:mkgapsync port map(
		GAPS	=>GAPS,
		SYNCS	=>SYNCS,
		
		GAPDAT	=>GAPDAT,
		
		WRENn	=>WRENn,
		
		MKEN	=>open,
		MKDAT	=>GSDAT,
		MK		=>GSwrite,
		MKDONE	=>rxed,
		
		clk		=>clk,
		rstn	=>rstn
	);
	
	
	process(clk,rstn)
	variable mwait		:integer range 0 to 3;
	begin
		if(rstn='0')then
			ramwr<='0';
			rxed<='0';
			mwait:=0;
			wrstate<=ws_idle;
		elsif(clk' event and clk='1')then
			rxed<='0';
			case wrstate is
			when ws_idle =>
			if(rxwr='1')then
					if(ramwait='0')then
				ramwr<='1';
				mwait:=3;
						wrstate<=ws_write;
					else
						wrstate<=ws_ramwait;
					end if;
				end if;
			when ws_ramwait =>
				if(ramwait='0')then
					ramwr<='1';
					mwait:=3;
					wrstate<=ws_write;
				end if;
			when ws_write =>
				if(mwait>0)then
					mwait:=mwait-1;
				elsif(ramwait='0')then
					ramwr<='0';
					rxed<='1';
					wrstate<=ws_idle;
			end if;
			when others =>
				wrstate<=ws_idle;
			end case;
		end if;
	end process;
			
	
	process(clk,rstn)
	begin
		if(rstn='0')then
			ramwdat<=(others=>'0');
			rxwr<='0';
			wrote<=(others=>'0');
		elsif(clk' event and clk='1')then
			rxwr<='0';
			wrote<=(others=>'0');
			if(wprot(conv_integer(USEL))='0')then
				if(WRMFM='0')then
					if(fmmf8det='1' or fmmfbdet='1' or fmmfcdet='1' or fmmfedet='1' or fmrxed='1' or GSwrite='1')then
						if(fmmf8det='1' or fmmfbdet='1' or fmmfcdet='1' or fmmfedet='1')then
							ramwdat<=x"05" & fmrxdat;
						elsif(fmrxed='1')then
							ramwdat<=x"04" & fmrxdat;
						end if;
						if(GSwrite='1')then
							ramwdat<=x"04" & GSDAT;
						end if;
						rxwr<='1';
						wrote(conv_integer(USEL))<='1';
					end if;
				else
					if(mfmma1det='1' or mfmmc2det='1' or mfmrxed='1' or GSwrite='1')then
						if(mfmma1det='1' or mfmmc2det='1')then
							ramwdat<=x"07" & mfmrxdat;
						elsif(mfmrxed='1')then
							ramwdat<=x"06" & mfmrxdat;
						end if;
						if(GSwrite='1')then
							ramwdat<=x"06" & GSDAT;
						end if;
						rxwr<='1';
						wrote(conv_integer(USEL))<='1';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	-- A 2D image is laid out on every other position (diskemu_mister trackaddr), so on a 2D image
	-- the drive moves 2 positions per STEP, as a real 2D/2HD drive does for 2D media.
	process(clk,rstn)
	variable lSTEPn		:std_logic;
	variable stp		:std_logic;
	function nexttrack(cur :std_logic_vector(6 downto 0); two,chg,st,inward :std_logic) return std_logic_vector is
	variable v	:std_logic_vector(6 downto 0);
	begin
		v:=cur;
		if(chg='1')then	-- image type changed: keep the cylinder the FDC counts
			if(two='1')then
				if(v>"0111111")then
					v:="1111110";
				else
					v:=v(5 downto 0) & '0';
				end if;
			else
				v:='0' & v(6 downto 1);
			end if;
		end if;
		if(st='1')then
			if(inward='1')then
				if(two='0')then
					v:=v+1;
				elsif(v>"1111100")then
					v:="1111110";
				else
					v:=v+2;
				end if;
			else
				if(two='0')then
					if(v>0)then
						v:=v-1;
					end if;
				elsif(v>1)then
					v:=v-2;
				else
					v:=(others=>'0');
				end if;
			end if;
		end if;
		return v;
	end function;
	begin
		if(rstn='0')then
			--Start on track 0. From 127 a RECALIBRATE, which gives up after 77 steps, would
			--not reach track 0, while a real head is never that far out.
			curtrack0<=(others=>'0');
			curtrack1<=(others=>'0');
			curtrack2<=(others=>'0');
			curtrack3<=(others=>'0');
			ldstep<=(others=>'0');
			lSTEPn:='1';
		elsif(clk' event and clk='1')then
			if(lSTEPn='1' and STEPn='0')then
				stp:='1';
			else
				stp:='0';
			end if;
			if(USEL="00")then
				curtrack0<=nexttrack(curtrack0,dstep(0),dstep(0) xor ldstep(0),stp,not SDIRn);
			else
				curtrack0<=nexttrack(curtrack0,dstep(0),dstep(0) xor ldstep(0),'0',not SDIRn);
			end if;
			if(USEL="01")then
				curtrack1<=nexttrack(curtrack1,dstep(1),dstep(1) xor ldstep(1),stp,not SDIRn);
			else
				curtrack1<=nexttrack(curtrack1,dstep(1),dstep(1) xor ldstep(1),'0',not SDIRn);
			end if;
			if(USEL="10")then
				curtrack2<=nexttrack(curtrack2,dstep(2),dstep(2) xor ldstep(2),stp,not SDIRn);
			else
				curtrack2<=nexttrack(curtrack2,dstep(2),dstep(2) xor ldstep(2),'0',not SDIRn);
			end if;
			if(USEL="11")then
				curtrack3<=nexttrack(curtrack3,dstep(3),dstep(3) xor ldstep(3),stp,not SDIRn);
			else
				curtrack3<=nexttrack(curtrack3,dstep(3),dstep(3) xor ldstep(3),'0',not SDIRn);
			end if;
			ldstep<=dstep;
			lSTEPn:=STEPn;
		end if;
	end process;
	
	process(clk,rstn)
	variable lSTEPn		:std_logic;
	begin
		if(rstn='0')then
			settle<=(others=>0);
			xstop<=(others=>0);
			tcnt<=0;
			lSTEPn:='1';
		elsif(clk' event and clk='1')then
			if(tcnt=sysclk/10-1)then
				tcnt<=0;
			else
				tcnt<=tcnt+1;
			end if;
			for i in 0 to 3 loop
				if(lSTEPn='1' and STEPn='0' and conv_integer(USEL)=i)then
					settle(i)<=settletime;
				elsif(tcnt=sysclk/10-1 and settle(i)/=0)then
					settle(i)<=settle(i)-1;
				end if;
				--0.02 ms ticks at five places of tcnt; the stop ends at sysclk/10-1, so the first tick is 0.02 ms after it
				if(lSTEPn='1' and STEPn='0' and conv_integer(USEL)=i)then
					if(xstop(i)>xstopmax-xstopstep)then
						xstop(i)<=xstopmax;
					else
						xstop(i)<=xstop(i)+xstopstep;
					end if;
				elsif((tcnt=sysclk/50 or tcnt=sysclk*2/50 or tcnt=sysclk*3/50 or tcnt=sysclk*4/50 or tcnt=sysclk/10-1)
					and xstop(i)/=0 and settle(i)<=settletime-stoptime)then
					xstop(i)<=xstop(i)-1;
				end if;
			end loop;
			lSTEPn:=STEPn;
		end if;
	end process;
	settlex<=settle(conv_integer(USEL));
	xstopx<=xstop(conv_integer(USEL));
	rotstop<='1' when settlex>settletime-stoptime or xstopx/=0 else '0';
	nodata<='1' when settlex/=0 else '0';
	
	--decided when the disk turns to the index, so only the rotation makes index edges;
	--an index the motor has hidden stays hidden until the disk turns past it
	process(clk,rstn)
	begin
		if(rstn='0')then
			idxmask<='0';
			lidxz<='1';
		elsif(clk' event and clk='1')then
			if(curpos="00000000000000" and lidxz='0')then
				idxmask<=nodata or not MOTOR;
			elsif(curpos="00000000000000" and MOTOR='0')then
				idxmask<='1';
			end if;
			if(curpos="00000000000000")then
				lidxz<='1';
			else
				lidxz<='0';
			end if;
		end if;
	end process;
	
	track0n<='0' when curtrack0="0000000" and USEL="00" else
				'0' when curtrack1="0000000" and USEL="01" else
				'0' when curtrack2="0000000" and USEL="10" else
				'0' when curtrack3="0000000" and USEL="11" else
				'1';
	curtrack<=	curtrack0	when USEL="00" else
				curtrack1	when USEL="01" else
				curtrack2	when USEL="10" else
				curtrack3	when USEL="11" else
				(others=>'1');
	ramaddr<=USEL & curtrack & not siden & curpos;
	
end rtl;