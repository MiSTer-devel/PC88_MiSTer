library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity TDMAREGS	is
generic(
	ADRTOP	:in std_logic_vector(7 downto 0)	:=x"64";
	ADRLEN	:in std_logic_vector(7 downto 0)	:=x"65";
	ADRCMD	:in std_logic_vector(7 downto 0)	:=x"68";
	-- clocks from the start of a text row transfer to its end (about 240us on a FH)
	DMABURST	:integer	:=18200
);
port(
	ADR		:in std_logic_vector(7 downto 0);
	IORQn	:in std_logic;
	WRn		:in std_logic;
	DAT		:in std_logic_vector(7 downto 0);
	
	TRAMTOP	:out std_logic_vector(15 downto 0);
	TRAMLEN	:out std_logic_vector(15 downto 0);
	TDMAEN	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1';

	-- Read back of the channel registers at ADRCMD-8 to ADRCMD-1 (60h-67h) and the status at ADRCMD
	RDn		:in std_logic := '1';
	RDAT	:out std_logic_vector(7 downto 0);
	ROE		:out std_logic;

	-- Counts the text row transfers started, with the length in bytes (TRAMCONV)
	DMAREQ	:in std_logic_vector(1 downto 0) := "00";
	DMALEN	:in std_logic_vector(7 downto 0) := (others=>'0');
	-- Where the next row transfer starts and the bytes left to TC, the autoload values,
	-- and whether a row can be followed (TRAMCONV takes these for row 0 of a frame)
	DMNXA	:out std_logic_vector(15 downto 0);
	DMNXR	:out std_logic_vector(14 downto 0);
	DMRLA	:out std_logic_vector(15 downto 0);
	DMRLR	:out std_logic_vector(14 downto 0);
	DMOK	:out std_logic;
	-- Counts the CPU writes to the channel 2 address and count (TRAMCONV reads the rows not moved yet again)
	DMWE	:out std_logic_vector(1 downto 0);
	-- Channel 2 runs with autoload after a write of its address (DMOK without the timing),
	-- and a row request is waiting to start
	DMCF	:out std_logic;
	DMPD	:out std_logic
);
end TDMAREGS;

architecture MAIN of TDMAREGS is
signal	IOWRn	:std_logic;
signal	lWRn	:std_logic;
-- The 8257 holds the address and count of four channels and returns them on a read.
-- One first/last flip-flop is shared by all of them: each read or write of a channel
-- register flips it, and a write to the mode register clears it.
type	chregs_t is array(0 to 7) of std_logic_vector(15 downto 0);
signal	CHREG	:chregs_t;
signal	FL		:std_logic;
signal	CHSEL	:std_logic;
signal	STSEL	:std_logic;
signal	CHNO	:integer range 0 to 7;
signal	IORDn	:std_logic;
signal	lRDn	:std_logic;
signal	RDCH	:std_logic;
signal	RDST	:std_logic;
signal	CHDAT	:std_logic_vector(15 downto 0);
-- Channel 2 as the text DMA moves it, row by row. TRAMCONV reads the rows of a frame from
-- where row 0 of that frame was moved.
signal	CA		:std_logic_vector(15 downto 0);
signal	CC		:std_logic_vector(13 downto 0);
signal	CM		:std_logic_vector(1 downto 0);
signal	MAL,MTCS,MEN2,STP	:std_logic;
signal	TC2,UPD	:std_logic;
-- The channel 2 address has been written since 68h last stopped channel 2: only then can the display follow it
signal	SYNC	:std_logic;
signal	WEC		:std_logic_vector(1 downto 0);
signal	BUSY	:std_logic;
signal	BCNT	:integer range 0 to DMABURST;
signal	BLEN	:std_logic_vector(7 downto 0);
signal	lDMAREQ	:std_logic_vector(1 downto 0);
signal	IOBUSY	:std_logic;
constant CH2A	:integer	:=conv_integer(unsigned(ADRTOP(2 downto 0)));
constant CH2C	:integer	:=conv_integer(unsigned(ADRLEN(2 downto 0)));
begin
	IOWRn<=IORQn or WRn;
	IORDn<=IORQn or RDn;
	CHSEL<='1' when ADR(7 downto 4)=ADRCMD(7 downto 4) and ADR(3)='0' else '0';
	STSEL<='1' when ADR=ADRCMD else '0';
	CHNO<=conv_integer(unsigned(ADR(2 downto 0)));
	CHDAT<=	CA			when CHNO=CH2A else
			CM & CC		when CHNO=CH2C else
			CHREG(CHNO);
	RDAT<=	"000" & UPD & '0' & TC2 & "00"	when STSEL='1' else
			CHDAT(7 downto 0)				when FL='0' else
			CHDAT(15 downto 8);
	ROE<='1' when IORDn='0' and (CHSEL='1' or STSEL='1') else '0';
	-- The text DMA takes channel 2 from the same registers, so it shares the flip-flop too
	TRAMTOP<=CHREG(conv_integer(unsigned(ADRTOP(2 downto 0))));
	TRAMLEN<=CHREG(conv_integer(unsigned(ADRLEN(2 downto 0))));
	DMNXA<=CHREG(CH2A+2) when UPD='1' else CA;
	DMNXR<=unsigned('0' & CHREG(CH2C+2)(13 downto 0))+1 when UPD='1' else unsigned('0' & CC)+1;
	DMRLA<=CHREG(CH2A+2);
	DMRLR<=unsigned('0' & CHREG(CH2C+2)(13 downto 0))+1;
	DMWE<=WEC;
	DMCF<='1' when MEN2='1' and STP='0' and MAL='1' and SYNC='1' else '0';
	DMPD<='1' when DMAREQ/=lDMAREQ else '0';
	DMOK<='1' when MEN2='1' and STP='0' and MAL='1' and SYNC='1' and BUSY='0' and DMAREQ=lDMAREQ else '0';
	IOBUSY<='1' when ((IORDn='0' or IOWRn='0') and (CHSEL='1' or STSEL='1')) or RDST='1' else '0';

	process(clk,rstn)begin
		if(rstn='0')then
			CHREG<=(others=>(others=>'0'));
			FL<='0';
			RDCH<='0';
			RDST<='0';
			lRDn<='1';
			CA<=(others=>'0');
			CC<=(others=>'0');
			CM<=(others=>'0');
			MAL<='0';
			MTCS<='0';
			MEN2<='0';
			STP<='0';
			TC2<='0';
			UPD<='0';
			SYNC<='0';
			WEC<="00";
			BUSY<='0';
			BCNT<=0;
			BLEN<=(others=>'0');
			lDMAREQ<="00";
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(IOWRn='0' and lWRn='1')then
				if(ADR=ADRCMD)then
					FL<='0';
					if(DAT(2)='0')then
						BUSY<='0';
						SYNC<='0';
					end if;
					MAL<=DAT(7);
					-- Turning autoload off clears UPDATE, so channel 2 is not reloaded from channel 3 (8257)
					if(DAT(7)='0')then
						UPD<='0';
					end if;
					MTCS<=DAT(6);
					MEN2<=DAT(2);
					STP<='0';
				elsif(CHSEL='1')then
					if(FL='0')then
						CHREG(CHNO)(7 downto 0)<=DAT;
					else
						CHREG(CHNO)(15 downto 8)<=DAT;
					end if;
					-- With autoload, a write to channel 2 also goes to channel 3
					if(CHNO=CH2A)then
						BUSY<='0';
						SYNC<='1';
						WEC<=unsigned(WEC)+1;
						if(FL='0')then
							CA(7 downto 0)<=DAT;
							if(MAL='1')then
								CHREG(CH2A+2)(7 downto 0)<=DAT;
							end if;
						else
							CA(15 downto 8)<=DAT;
							if(MAL='1')then
								CHREG(CH2A+2)(15 downto 8)<=DAT;
							end if;
						end if;
					elsif(CHNO=CH2C)then
						BUSY<='0';
						WEC<=unsigned(WEC)+1;
						if(FL='0')then
							CC(7 downto 0)<=DAT;
							if(MAL='1')then
								CHREG(CH2C+2)(7 downto 0)<=DAT;
							end if;
						else
							CC(13 downto 8)<=DAT(5 downto 0);
							CM<=DAT(7 downto 6);
							if(MAL='1')then
								CHREG(CH2C+2)(15 downto 8)<=DAT;
							end if;
						end if;
					end if;
					FL<=not FL;
				end if;
			end if;
			-- Flip at the end of the read, so the byte stays put while the CPU takes it
			if(IORDn='0')then
				RDCH<=CHSEL;
			elsif(lRDn='0' and RDCH='1')then
				FL<=not FL;
				RDCH<='0';
			end if;
			lRDn<=IORDn;
		 end if;

			-- TC2 clears when the status has been read
			if(IORDn='0' and STSEL='1')then
				RDST<='1';
			elsif(RDST='1')then
				TC2<='0';
				RDST<='0';
			end if;

			-- Channel 2 transfers, checked on every clock
			if(BUSY='0')then
				if(DMAREQ/=lDMAREQ and IOBUSY='0')then
					lDMAREQ<=unsigned(lDMAREQ)+1;
					if(MEN2='1' and STP='0')then
						-- Autoload takes channel 3 when the next block starts
						if(UPD='1')then
							CA<=CHREG(CH2A+2);
							CC<=CHREG(CH2C+2)(13 downto 0);
							CM<=CHREG(CH2C+2)(15 downto 14);
							UPD<='0';
						end if;
						BUSY<='1';
						BCNT<=DMABURST;
						BLEN<=DMALEN;
					end if;
				end if;
			elsif(BCNT/=0)then
				BCNT<=BCNT-1;
			elsif(IOBUSY='0')then
				BUSY<='0';
				if(MEN2='1' and STP='0')then
					-- TC inside the row with autoload: the rest of the row comes from channel 3 (FH)
					if(unsigned(CC)<unsigned(BLEN)-1 and MAL='1' and unsigned(CHREG(CH2C+2)(13 downto 0))>=unsigned(BLEN)-unsigned(CC)-1)then
						CA<=unsigned(CHREG(CH2A+2))+(unsigned(BLEN)-unsigned(CC)-1);
						CC<=unsigned(CHREG(CH2C+2)(13 downto 0))-(unsigned(BLEN)-unsigned(CC)-1);
						CM<=CHREG(CH2C+2)(15 downto 14);
						TC2<='1';
					elsif(unsigned(CC)<unsigned(BLEN)-1 and MAL='1' and unsigned(CHREG(CH2C+2)(13 downto 0))=unsigned(BLEN)-unsigned(CC)-2)then
						-- channel 3 runs out at the end of the row too
						CA<=unsigned(CHREG(CH2A+2))+(unsigned(BLEN)-unsigned(CC)-1);
						CC<=(others=>'1');
						CM<=CHREG(CH2C+2)(15 downto 14);
						TC2<='1';
						UPD<='1';
					elsif(unsigned(CC)<unsigned(BLEN))then
						CA<=unsigned(CA)+unsigned(CC)+1;
						CC<=(others=>'1');
						TC2<='1';
						if(MAL='1')then
							UPD<='1';
						elsif(MTCS='1')then
							STP<='1';
						end if;
					else
						CA<=unsigned(CA)+unsigned(BLEN);
						CC<=unsigned(CC)-unsigned(BLEN);
					end if;
				end if;
			end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			TDMAEN<='0';
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(IOWRn='0' and lWRn='1' and ADR=ADRCMD)then
				TDMAEN<=DAT(2);
			end if;
			lWRn<=IOWRn;
		 end if;
		end if;
	end process;
end MAIN;

