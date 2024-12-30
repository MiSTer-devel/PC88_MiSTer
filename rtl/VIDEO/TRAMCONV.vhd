LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity TRAMCONV is
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
	TVRAM_WDAT	:out std_logic_vector(7 downto 0);
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
signal	CURATR	:std_logic_vector(7 downto 0);
signal	NXTATR	:std_logic_vector(7 downto 0);
signal	CHARCNT	:integer range 0 to LINECHARS-1;
signal	LINECNT	:integer range 0 to MAXLINES;
type STATE_T is(ST_IDLE,ST_GETBUS,ST_RDTXT,ST_RDTXT1,ST_WRTXT,ST_RDATR,ST_RDATR1,ST_RDATR2,ST_RDATR3,ST_SETATR,ST_SETATR1,ST_SETATR2,ST_RELBUS,ST_SKIPATR,ST_NOATTR);
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

begin

	RDDAT<=MRAM_DAT when rTMODE='1' else TRAM_DAT;
	TRAM_ADR<=RDADR(11 downto 0);
	MRAM_ADR<=RDADR;
	iATTRLEN<=conv_integer(ATTRLEN);
	LINEADD<=x"0052" + (x"00" & "00" & ATTRLEN & "0") when SPCHR='0' else x"0050";
	LINES<=conv_integer(TXTLINES);
	
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
			CURATR<="00000111";
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
		elsif(clk' event and clk='1')then
			TVRAM_WR<='0';
			DONE<='0';
			if(waitcount>0)then
				waitcount<=waitcount-1;
			else
				case STATE is
				when ST_IDLE =>
					if(lVRET='1' and VRET='0')then
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
						CURATR<="00000111";
						LINESKIP<='0';
					elsif(lHRET='1' and HRET='0' and (TEXTEN='1' or rTMODE='0'))then
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
					if(BUSACKn='0')then
						STATE<=ST_RDTXT;
						BUS_USE<='1';
					end if;
				when ST_RDTXT =>
					MRAM_RDn<='0';
					RDADR<=CTXTADR;
					STATE<=ST_RDTXT1;
					if(rTMODE='1')then
						waitcount<=2;
					end if;
				when ST_RDTXT1 =>
					if(rTMODE='0' or MRAM_WAIT='0')then
						MRAM_RDn<='1';
						TVRAM_ADR<=CDSTADR;
						if (LINESKIP='1')then
							TVRAM_WDAT<=x"00";
						else
							TVRAM_WDAT<=RDDAT;
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
					CURATR<=x"07";
					STATE<=ST_SETATR;
				when ST_SKIPATR =>
					CURATR<=x"80";
					STATE<=ST_SETATR;
				when ST_RDATR =>
					MRAM_RDn<='0';
					RDADR<=CATRADR;
					STATE<=ST_RDATR1;
					if(rTMODE='1')then
						waitcount<=2;
					end if;
				when ST_RDATR1 =>
					if(rTMODE='0' or MRAM_WAIT='0')then
						case(RDDAT(7 downto 4))is
							when x"0"|x"1"|x"2"|x"3"|x"4" =>
								iATTRCUL:=conv_integer(RDDAT);
							when others =>
								iATTRCUL:=0;
						end case;
						fATTR(iATTRCUL)<='1';
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
						waitcount<=2;
					end if;
				when ST_RDATR3 =>
					if(rTMODE='0' or MRAM_WAIT='0')then
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
						elsif(RDDAT(3)='0')then
							CURATR(3)<=RDDAT(1);
							CURATR(4)<=RDDAT(2);
							CURATR(5)<=RDDAT(0);
							CURATR(6)<=RDDAT(5);
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
						if((fATTR(CHARCNT)='1') and (ATRCNT<iATTRLEN))then
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
						STATE<=ST_RELBUS;
					end if;
				when ST_RELBUS =>
					BUSREQn<='1';
					BUS_USE<='0';
					STATE<=ST_IDLE;
				when others=>
					STATE<=ST_RELBUS;
				end case;
				lVRET<=VRET;
				lHRET<=HRET;
			end if;
		end if;
	end process;
end MAIN;
						
			
				
					