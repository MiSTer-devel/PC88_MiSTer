library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.VIDEO_TIMING_pkg.all;

entity TEXTSCR2 is
generic(
	CBLINKINT :integer	:=20;
	BLINKINT :integer	:=40
);
port(
	TRAMADR	:out std_logic_vector(TVAW-1 downto 0);
	TRAMDAT	:in std_logic_vector(8 downto 0);	-- bit 8 of an attribute: over line
	
	FRAMADR	:out std_logic_vector(11 downto 0);
	FRAMDAT0:in std_logic_vector( 7 downto 0);
	FRAMDAT1:in std_logic_vector( 7 downto 0);
	FRAMADR8:out std_logic_vector(10 downto 0);	-- 8x8 font
	FRAMDAT8:in std_logic_vector( 7 downto 0);
	
	BITOUT	:out std_logic;
	FGCOLOR	:out std_logic_vector(2 downto 0);
	BGCOLOR	:out std_logic_vector(2 downto 0);
	BLINK	:out std_logic;
	
	CURL	:in std_logic_vector(5 downto 0);
	CURC	:in std_logic_vector(6 downto 0);
	CURE	:in std_logic;
	CURM	:in std_logic;
	CBLINK	:in std_logic;
	
	HMODE	:in std_logic;
	VMODE	:in std_logic;
	
	UCOUNT	:in integer range 0 to DOTPU-1;
	HUCOUNT	:in integer range 0 to HUWMAX-1;
	VCOUNT	:in integer range 0 to VWMAX-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;

	clk		:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1';

	CURVMODE	:out std_logic;	-- VMODE taken at VCOMP: the row height being drawn

	VT24	:in std_logic	:='0';		-- 1:24kHz or 15kHz timing (lines from the CRTC)
	VT15	:in std_logic	:='0';		-- 1:15kHz timing
	VRET24	:in integer range 0 to VWMAX-1	:=VRETMIN24;	-- retrace lines in 24kHz or 15kHz timing
	CHRL24	:in integer range CHRLMIN24 to CHRLMAX24	:=CHRLDEF24;	-- character height in 24kHz or 15kHz timing
	TXT16	:in std_logic	:='1';	-- 31h bit 5: 0 blanks the text 4 lines in every 20 at 24kHz (below)
	HIVT	:in integer range 0 to HUWMAX-1	:=HIV24	-- retrace characters of a line in 24kHz or 15kHz timing
);
end TEXTSCR2;

architecture MAIN of TEXTSCR2 is
signal	CURDOT	:std_logic_vector(7 downto 0);
signal	NXTDOT0	:std_logic_vector(7 downto 0);
signal	NXTDOT1	:std_logic_vector(7 downto 0);
signal	NXTFGCLR :std_logic_vector(2 downto 0);
signal	NXTBGCLR :std_logic_vector(2 downto 0);
signal	NXTFS	:std_logic;
signal	NXTBL	:std_logic;
signal	CHAR	:std_logic_vector(7 downto 0);
signal	TRAMADRb	:std_logic_vector(TVAW-1 downto 0);
signal	DHCOMP	:std_logic;
signal	DVCOMP	:std_logic;
signal	C_LOW	:integer range 0 to ROWCAP-1;
signal	C_LIN	:integer range 0 to CHRLMAX24-1;
signal	C_LIN31	:integer range 0 to 19;
signal	LIN31Q	:std_logic_vector(9 downto 0);	-- VCOUNT-VIV, used from VIV on
type	MOD5_T is array(0 to 30) of integer range 0 to 4;
constant	MOD5	:MOD5_T:=(0,1,2,3,4,0,1,2,3,4,0,1,2,3,4,0,1,2,3,4,0,1,2,3,4,0,1,2,3,4,0);
signal	C_LIN24	:integer range 0 to CHRLMAX24-1;
signal	C_LIN2	:integer range 0 to CHRLMAX24*2-2;	-- C_LIN in the lines of a 16-line glyph
signal	LBASE	:integer range 0 to VWMAX-1;	-- 24kHz: first line of the row being drawn
signal	LDIFF	:integer range -VWMAX to VWMAX;
--24kHz, 31h bit 5 = 0: a count of 0 to 4 that is 0 at the first display line and
--steps when bit 1 of the line in the row goes from 1 to 0. While it is 4 the
--glyph is not drawn (the PC-8801FH: 4 lines in 20 when the row height is a
--multiple of 4, rows of 10 lines step 8 lines a row).
signal	B5CNT	:integer range 0 to 4;
signal	B5L1	:std_logic;
signal	B5VC	:integer range 0 to VWMAX-1;
signal	B5OFF	:std_logic;
signal	C_LINV	:std_logic_vector(4 downto 0);
signal	vivs	:integer range 0 to VWMAX-1;
signal	hivs	:integer range 0 to HUWMAX-1;
signal	C_COL	:integer range 0 to 127;
signal	iCURL	:integer range 0 to 63;
signal	iCURC	:integer range 0 to 127;
signal	CURV	:std_logic;
signal	CURF	:std_logic;
signal	CICOUNT	:integer range 0 to CBLINKINT-1;
signal	BLKF	:std_logic;
signal	BICOUNT	:integer range 0 to BLINKINT-1;
signal	CHRLINES	:integer range 0 to CHRLMAX24;
signal	CHRL31	:integer range 16 to 20;
signal	VMODEC	:std_logic;
signal	HMODEC	:std_logic;

component delayer is
generic(
	counts	:integer	:=5
);
port(
	a		:in std_logic;
	q		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1'
);
end component;

begin

	--31kHz compares the cursor row in 5 bits as before (25 rows at most)
	iCURL<=conv_integer(CURL) when VT24='1' else conv_integer(CURL(4 downto 0));
	iCURC<=conv_integer(CURC);

	Hdelay	:delayer generic map(1) port map(HCOMP,DHCOMP,clk,rstn,ce);
	Vdelay	:delayer generic map(2) port map(VCOMP,DVCOMP,clk,rstn,ce);

	vivs<=VRET24 when VT24='1' else VIV;
	hivs<=HIVT when VT24='1' else HIV;

	--no divider: a divider does not fit in a clock. Mod 20 is 4*((q/4) mod 5) + q mod 4,
	--and (q/4) mod 5 is the sum of its two nibbles mod 5, as 16 mod 5 = 1.
	LIN31Q<=conv_std_logic_vector(VCOUNT-VIV,10);
	C_LIN31<=0 when VCOUNT<VIV else
			conv_integer(LIN31Q(3 downto 0)) when VMODEC='1' else
			MOD5(conv_integer(LIN31Q(9 downto 6))+conv_integer(LIN31Q(5 downto 2)))*4+conv_integer(LIN31Q(1 downto 0));
	--24kHz: the character height is not fixed, so count from the first line of the row
	LDIFF<=VCOUNT-LBASE;
	C_LIN24<=0 when VCOUNT<vivs or LDIFF<0 else
			LDIFF when LDIFF<CHRLINES else
			LDIFF-CHRLINES when LDIFF<CHRLINES*2 else
			0;
	C_LIN<=C_LIN24 when VT24='1' else C_LIN31;
	C_LINV<=conv_std_logic_vector(C_LIN,5);
	--15kHz draws a glyph line once, 24kHz and 31kHz twice. The 8x8 font and the
	--graphic characters (4 lines a cell in 16) are read at C_LIN2, and lines from
	--16 on (the bottom of a 20-line row) are blank. 24kHz takes the line mod 16,
	--as the PC-8801FH repeats the top of the glyph in a row taller than 16 lines;
	--B5OFF blanks the lines instead.
	C_LIN2<=C_LIN*2 when VT15='1' else
			conv_integer(C_LINV(3 downto 0)) when VT24='1' else
			C_LIN;

	process(clk,rstn)begin
		if(rstn='0')then
			B5CNT<=0;
			B5L1<='0';
			B5VC<=0;
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			B5VC<=VCOUNT;
			if(VCOUNT/=B5VC)then
				if(VCOUNT<=vivs)then
					B5CNT<=0;
				elsif(B5L1='1' and C_LINV(1)='0')then
					if(B5CNT=4)then
						B5CNT<=0;
					else
						B5CNT<=B5CNT+1;
					end if;
				end if;
				B5L1<=C_LINV(1);
			end if;
		 end if;
		end if;
	end process;
	B5OFF<='1' when VT24='1' and VT15='0' and TXT16='0' and B5CNT=4 else '0';
	C_COL<=0 when HUCOUNT<hivs else HUCOUNT-hivs;

	process(clk,rstn)begin
		if(rstn='0')then
			LBASE<=0;
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(VCOUNT<vivs)then
				LBASE<=vivs;
			elsif(LDIFF<0 or LDIFF>=CHRLINES*2)then
				LBASE<=VCOUNT;	-- after reset the count starts inside the display
			elsif(LDIFF>=CHRLINES)then
				LBASE<=LBASE+CHRLINES;
			end if;
		 end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			CURF<='1';
			CICOUNT<=CBLINKINT-1;
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(VCOMP='1')then
				if(CICOUNT=0)then
					CURF<=not CURF;
					CICOUNT<=CBLINKINT-1;
				else
					CICOUNT<=CICOUNT-1;
				end if;
			end if;
		 end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			BLKF<='0';
			BICOUNT<=BLINKINT-1;
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(VCOMP='1')then
				if(BICOUNT=0)then
					BLKF<=not BLKF;
					BICOUNT<=BLINKINT-1;
				else
					BICOUNT<=BICOUNT-1;
				end if;
			end if;
		 end if;
		end if;
	end process;

	CURV<=CURE when CBLINK='0' else (CURE and CURF);

	process(clk,rstn)begin
		if(rstn='0')then
			HMODEC<='0';
			VMODEC<='0';
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(VCOMP='1')then
				HMODEC<=HMODE;
				VMODEC<=VMODE;
			end if;
		 end if;
		end if;
	end process;

	CHRL31<=16 when VMODEC='1' else 20;
	CHRLINES<=CHRL24 when VT24='1' else CHRL31;
	CURVMODE<=VMODEC;

	process (clk,rstn)
	variable BNXTDOT0	:std_logic_vector(7 downto 0);
	variable BNXTDOT1	:std_logic_vector(7 downto 0);
	begin
		if(rstn='0')then
			NXTDOT0<=(others=>'0');
			NXTDOT1<=(others=>'0');
			NXTFGCLR<=(others=>'0');
			NXTBGCLR<=(others=>'0');
			NXTFS<='0';
			NXTBL<='0';
			TRAMADRb<=(others=>'0');
			FRAMADR<=(others=>'0');
			FRAMADR8<=(others=>'0');
			C_LOW<=0;
		elsif(clk' event and clk='1')then
		 if(ce='1')then

-- Data	section
			if(DHCOMP='1')then
				if(VCOUNT>vivs)then
					if(C_LIN/=0)then
						TRAMADRb<=TRAMADRb-(HUVIS*2);
					elsif(C_LOW<ROWCAP-1)then
						C_LOW<=C_LOW+1;
					end if;
				end if;
			end if;
			if(DVCOMP='1')then
				TRAMADRb<=(others=>'0');
				C_LOW<=0;
			end if;
			
			if(UCOUNT=4)then
					FRAMADR(11 downto 4)<=TRAMDAT(7 downto 0);
					FRAMADR8(10 downto 3)<=TRAMDAT(7 downto 0);
				if(C_LIN2<16)then
					FRAMADR(3 downto 0)<=conv_std_logic_vector(C_LIN2,4);
					FRAMADR8(2 downto 0)<=conv_std_logic_vector(C_LIN2/2,3);
				else
					FRAMADR(3 downto 0)<=(others=>'0');
					FRAMADR8(2 downto 0)<=(others=>'0');
				end if;
				if(VCOUNT>=vivs and HUCOUNT>=hivs)then
					TRAMADRb<=TRAMADRb+1;
				end if;
			elsif(UCOUNT=6)then
				if(VCOUNT>=vivs and HUCOUNT>=hivs)then
					if((TRAMDAT(3)='1' and BLKF='1') or (TRAMDAT(5)='1'))then
						BNXTDOT0:=(others=>'0');
						BNXTDOT1:=(others=>'0');
					else
						if(C_LIN2<16 and B5OFF='0')then
							BNXTDOT0:=FRAMDAT8;
							BNXTDOT1:=FRAMDAT1;
						else
							BNXTDOT0:=(others=>'0');
							BNXTDOT1:=(others=>'0');
						end if;
					end if;
					--The under line is the last line of the row, the over line the first, and
					--the cursor the whole row or its last line.
					if(TRAMDAT(6)='1' and C_LIN=CHRLINES-1)then	-- under line
						BNXTDOT0:=(others=>'1');
						BNXTDOT1:=(others=>'1');
					end if;
					if(TRAMDAT(8)='1' and C_LIN=0)then	-- over line
						BNXTDOT0:=(others=>'1');
						BNXTDOT1:=(others=>'1');
					end if;
					if(CURV='1' and C_LOW=iCURL and C_COL=iCURC and (CURM='1' or C_LIN=CHRLINES-1))then
						NXTDOT0<=not BNXTDOT0;
						NXTDOT1<=not BNXTDOT1;
					else
						NXTDOT0<=BNXTDOT0;
						NXTDOT1<=BNXTDOT1;
					end if;
					NXTFGCLR<=TRAMDAT(2 downto 0);
					NXTBGCLR<=TRAMDAT(6 downto 4);
					NXTBL<=TRAMDAT(3);
					NXTFS<=TRAMDAT(7);
					TRAMADRb<=TRAMADRb+1;
				else
					NXTDOT0<=(others=>'0');
					NXTDOT1<=(others=>'0');
					NXTFGCLR<=(others=>'0');
					NXTBGCLR<=(others=>'0');
					NXTBL<='0';
					NXTFS<='0';
				end if;
			end if;
		 end if;
		end if;
	end process;

	TRAMADR<=TRAMADRb;

-- Display driver section
	process(clk,rstn)begin
		if(rstn='0')then
			BITOUT<='0';
			FGCOLOR<=(others=>'0');
			BGCOLOR<=(others=>'0');
			BLINK<='0';
			CURDOT<=(others=>'0');
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			if(HMODEC='1')then
				if(UCOUNT=0)then
					if(NXTFS='0')then
						BITOUT<=NXTDOT0(7);
						CURDOT<=NXTDOT0;
					else
						BITOUT<=NXTDOT1(7);
						CURDOT<=NXTDOT1;
					end if;
					FGCOLOR<=NXTFGCLR;
					BGCOLOR<=NXTBGCLR;
					BLINK<=NXTBL;
				else
					BITOUT<=CURDOT(6);
					CURDOT<=CURDOT(6 downto 0) & '0';
				end if;
			else
				if(UCOUNT=0 and (HUCOUNT mod 2)=1)then
					if(NXTFS='0')then
						BITOUT<=NXTDOT0(7);
						CURDOT<=NXTDOT0;
					else
						BITOUT<=NXTDOT1(7);
						CURDOT<=NXTDOT1;
					end if;
					FGCOLOR<=NXTFGCLR;
					BGCOLOR<=NXTBGCLR;
					BLINK<=NXTBL;
				elsif((UCOUNT mod 2)=0)then
					BITOUT<=CURDOT(6);
					CURDOT<=CURDOT(6 downto 0) & '0';
				end if;
			end if;
		 end if;
		end if;
	end process;


end MAIN;
					
