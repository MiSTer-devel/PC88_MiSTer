library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.VIDEO_TIMING_pkg.all;

entity GRAPHSCR is
port(
	GRAMADR	:out std_logic_vector(13 downto 0);
	GRAMRD	:out std_logic;
	GRAMWAIT:in std_logic;
	GRAMDAT0:in std_logic_vector(7 downto 0);
	GRAMDAT1:in std_logic_vector(7 downto 0);
	GRAMDAT2:in std_logic_vector(7 downto 0);

	BITOUT0	:out std_logic;
	BITOUT1	:out std_logic;
	BITOUT2	:out std_logic;
	BITOUTM	:out std_logic;
	BITOUTE	:out std_logic;
	
	GRAPHEN	:in std_logic;
	LOWRES	:in std_logic;
	MONOEN	:in std_logic_vector(2 downto 0);
	
	UCOUNT	:in integer range 0 to DOTPU-1;
	HUCOUNT	:in integer range 0 to (HWIDTH/DOTPU)-1;
	VCOUNT	:in integer range 0 to VWIDTH-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end GRAPHSCR;

architecture MAIN of GRAPHSCR is
component graphbuf
	PORT
	(
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

component delayer is
generic(
	counts	:integer	:=5
);
port(
	a		:in std_logic;
	q		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

signal	WDAT0	:std_logic_vector(7 downto 0);
signal	WDAT1	:std_logic_vector(7 downto 0);
signal	WDAT2	:std_logic_vector(7 downto 0);
signal	WDATE	:std_logic_vector(7 downto 0);
signal	RDAT0	:std_logic_vector(7 downto 0);
signal	RDAT1	:std_logic_vector(7 downto 0);
signal	RDAT2	:std_logic_vector(7 downto 0);
signal	RDATE	:std_logic_vector(7 downto 0);
signal	BUFWE	:std_logic;
signal	WADR	:std_logic_vector(6 downto 0);
signal	RADR	:std_logic_vector(6 downto 0);
signal	BUFSTATE	:integer range 0 to 4;
	constant BS_IDLE	:integer	:=0;
	constant BS_RWAIT	:integer	:=1;
	constant BS_READ	:integer	:=2;
	constant BS_LOFF	:integer	:=3;
	constant BS_WRITE	:integer	:=4;
signal	BUFCNT	:integer range 0 to HUVIS-1;
signal	DAT1SEL	:std_logic;
signal	LOWRESb	:std_logic;
signal	LINEEN	:std_logic;
signal	NXTDOT0	:std_logic_vector(7 downto 0);
signal	NXTDOT1	:std_logic_vector(7 downto 0);
signal	NXTDOT2	:std_logic_vector(7 downto 0);
signal	NXTDOTM	:std_logic_vector(7 downto 0);
signal	NXTDOTE	:std_logic_vector(7 downto 0);
signal	CURDOT0	:std_logic_vector(7 downto 0);
signal	CURDOT1	:std_logic_vector(7 downto 0);
signal	CURDOT2	:std_logic_vector(7 downto 0);
signal	CURDOTM	:std_logic_vector(7 downto 0);
signal	CURDOTE	:std_logic_vector(7 downto 0);
signal	DHCOMP	:std_logic;
signal	DVCOMP	:std_logic;
signal	GRAMADRb:std_logic_vector(13 downto 0);
signal	MONOFL0	:std_logic_vector(7 downto 0);
signal	MONOFL1	:std_logic_vector(7 downto 0);
signal	MONOFL2	:std_logic_vector(7 downto 0);

begin
	buf0	:graphbuf port map(clk,WDAT0,RADR,WADR,BUFWE,RDAT0);
	buf1	:graphbuf port map(clk,WDAT1,RADR,WADR,BUFWE,RDAT1);
	buf2	:graphbuf port map(clk,WDAT2,RADR,WADR,BUFWE,RDAT2);
	bufe	:graphbuf port map(clk,WDATE,RADR,WADR,BUFWE,RDATE);
	
	WDAT0<=GRAMDAT0 when LINEEN='1' else (others=>'0');
	WDAT1<=GRAMDAT1 when LINEEN='1' else (others=>'0');
	WDAT2<=GRAMDAT2 when LINEEN='1' else (others=>'0');
	WDATE<=(others=>'1') when LINEEN='1' else (others=>'0');
	
	GRAMADR<=GRAMADRb;
	
	process(clk,rstn)begin
		if(rstn='0')then
			BUFSTATE<=BS_IDLE;
			WADR<=(others=>'0');
			GRAMADRb<=(others=>'0');
			GRAMRD<='0';
			BUFWE<='0';
			BUFCNT<=0;
			DAT1SEL<='0';
			LINEEN<='1';
		elsif(clk' event and clk='1')then
			BUFWE<='0';
			case BUFSTATE is
			when BS_IDLE =>
				if(HUCOUNT=0 and UCOUNT=0)then
					if(VCOUNT=VIV)then
						GRAMADRb<=(others=>'0');
						DAT1SEL<='0';
						LOWRESb<=LOWRES;
						LINEEN<='1';
					elsif(VCOUNT=(VIV+(VVIS/2)) and LOWRESb='0')then
						GRAMADRb<=(others=>'0');
						DAT1SEL<='1';
						LINEEN<='1';
					end if;
					BUFCNT<=0;
					WADR<=(others=>'0');
					if(LOWRESb='0')then
						if(LINEEN='1')then
							BUFSTATE<=BS_RWAIT;
							GRAMRD<='1';
						else
							BUFSTATE<=BS_LOFF;
						end if;
					else
							BUFSTATE<=BS_RWAIT;
							GRAMRD<='1';
					end if;
				end if;
			when BS_RWAIT =>
				if(GRAMWAIT='1')then
					BUFSTATE<=BS_READ;
				end if;
			when BS_READ =>
				if(GRAMWAIT='0')then
					BUFWE<='1';
					BUFSTATE<=BS_WRITE;
					GRAMRD<='0';
				end if;
			when BS_LOFF =>
				BUFWE<='1';
				BUFSTATE<=BS_WRITE;
			when BS_WRITE =>
				if(LINEEN='1')then
					GRAMADRb<=GRAMADRb+1;
				end if;
				WADR<=WADR+1;
				if(BUFCNT<(HUVIS-1))then
					if(LINEEN='1')then
						BUFSTATE<=BS_RWAIT;
						GRAMRD<='1';
					else
						BUFSTATE<=BS_LOFF;
					end if;
					BUFCNT<=BUFCNT+1;
				else
					if(LOWRESb='1')then
						if(LINEEN='0')then
							LINEEN<='1';
						else
							LINEEN<='0';
						end if;
					else
						LINEEN<='1';
					end if;
					BUFSTATE<=BS_IDLE;
				end if;
			when others =>
				BUFSTATE<=BS_IDLE;
			end case;
		end if;
	end process;

	Hdelay	:delayer generic map(2) port map(HCOMP,DHCOMP,clk,rstn);
	Vdelay	:delayer generic map(4) port map(VCOMP,DVCOMP,clk,rstn);
	
	MONOFL0<=(others=>MONOEN(0));
	MONOFL1<=(others=>MONOEN(1));
	MONOFL2<=(others=>MONOEN(2));
	
	process (clk,rstn)
	variable VVISCOUNT :integer range 0 to VIV-1;
	variable VVISCV	:std_logic_vector(8 downto 0);
	variable BNXTDOT	:std_logic_vector(7 downto 0);
	begin
		if(rstn='0')then
			NXTDOT0<=(others=>'0');
			NXTDOT1<=(others=>'0');
			NXTDOT2<=(others=>'0');
			NXTDOTM<=(others=>'0');
			NXTDOTE<=(others=>'0');
			RADR<=(others=>'0');
		elsif(clk' event and clk='1')then

-- Data	section
			if(DHCOMP='1')then
				RADR<=(others=>'0');
			end if;

			if(VCOUNT>=VIV)then
				VVISCOUNT:=VCOUNT-VIV;
			else
				VVISCOUNT:=0;
			end if;
			VVISCV:=conv_std_logic_vector(VVISCOUNT,9);

			if(UCOUNT=4)then
				if(VCOUNT>=VIV and HUCOUNT>=HIV)then
					NXTDOT0<=RDAT0;
					NXTDOT1<=RDAT1;
					NXTDOT2<=RDAT2;
					NXTDOTE<=RDATE;
					if(LOWRESb='1')then
						NXTDOTM<=(MONOFL0 and RDAT0) or (MONOFL1 and RDAT1) or (MONOFL2 and RDAT2);
					elsif(DAT1SEL='1')then
						NXTDOTM<=RDAT1;
					else
						NXTDOTM<=RDAT0;
					end if;
					RADR<=RADR+1;
				else
					NXTDOT0<=(others=>'0');
					NXTDOT1<=(others=>'0');
					NXTDOT2<=(others=>'0');
					NXTDOTE<=(others=>'0');
				end if;
			end if;
		end if;
	end process;
	
-- Display driver section
	process(clk,rstn)begin
		if(rstn='0')then
			BITOUT0<='0';
			BITOUT1<='0';
			BITOUT2<='0';
			BITOUTM<='0';
			BITOUTE<='0';
			CURDOT0<=(others=>'0');
			CURDOT1<=(others=>'0');
			CURDOT2<=(others=>'0');
			CURDOTM<=(others=>'0');
			CURDOTE<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(UCOUNT=0)then
				BITOUT0<=NXTDOT0(7);
				BITOUT1<=NXTDOT1(7);
				BITOUT2<=NXTDOT2(7);
				BITOUTM<=NXTDOTM(7);
				BITOUTE<=NXTDOTE(7);
				CURDOT0<=NXTDOT0;
				CURDOT1<=NXTDOT1;
				CURDOT2<=NXTDOT2;
				CURDOTM<=NXTDOTM;
				CURDOTE<=NXTDOTE;
			else
				BITOUT0<=CURDOT0(6);
				BITOUT1<=CURDOT1(6);
				BITOUT2<=CURDOT2(6);
				BITOUTM<=CURDOTM(6);
				BITOUTE<=CURDOTE(6);
				CURDOT0<=CURDOT0(6 downto 0) & '0';
				CURDOT1<=CURDOT1(6 downto 0) & '0';
				CURDOT2<=CURDOT2(6 downto 0) & '0';
				CURDOTM<=CURDOTM(6 downto 0) & '0';
				CURDOTE<=CURDOTE(6 downto 0) & '0';
			end if;
		end if;
	end process;

end MAIN;
				
