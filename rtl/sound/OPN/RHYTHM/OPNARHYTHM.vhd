LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity OPNARHYTHM is
port(
	ADDR	:in std_logic_vector(7 downto 0);
	WDAT	:in std_logic_vector(7 downto 0);
	WR		:in std_logic;
	
	sndL	:out std_logic_vector(15 downto 0);
	sndR	:out std_logic_vector(15 downto 0);
	
	sft		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end OPNARHYTHM;

architecture rtl of OPNARHYTHM is

constant multdelay	:integer	:=1;

signal	KEY		:std_logic_vector(5 downto 0);
signal	RTL		:std_logic_vector(5 downto 0);
signal	CHSEL0	:std_logic_vector(1 downto 0);
signal	CHSEL1	:std_logic_vector(1 downto 0);
signal	CHSEL2	:std_logic_vector(1 downto 0);
signal	CHSEL3	:std_logic_vector(1 downto 0);
signal	CHSEL4	:std_logic_vector(1 downto 0);
signal	CHSEL5	:std_logic_vector(1 downto 0);
signal	PARLEV0	:std_logic_vector(4 downto 0);
signal	PARLEV1	:std_logic_vector(4 downto 0);
signal	PARLEV2	:std_logic_vector(4 downto 0);
signal	PARLEV3	:std_logic_vector(4 downto 0);
signal	PARLEV4	:std_logic_vector(4 downto 0);
signal	PARLEV5	:std_logic_vector(4 downto 0);
signal	rhythmstate	:integer range 0 to 25;
subtype ADDR_TYPE is std_logic_vector(15 downto 0);
type ADDR_ARRAY is array (natural range <>) of ADDR_TYPE;
signal	ROMADDR	:ADDR_ARRAY(0 to 5);
subtype PCMDAT_TYPE is std_logic_vector(3 downto 0);
type PCMDAT_ARRAY is array (natural range <>) of PCMDAT_TYPE;
signal	PCMDAT,PCMDATl	:PCMDAT_ARRAY(0 to 5);
subtype SNDDAT_TYPE is std_logic_vector(15 downto 0);
type SNDDAT_ARRAY is array (natural range <>) of SNDDAT_TYPE;
signal	SNDDAT	:SNDDAT_ARRAY(0 to 5);
subtype DELTAN_TYPE is std_logic_vector(15 downto 0);
type DELTAN_ARRAY is array (natural range <>) of DELTAN_TYPE;
signal	DELTAN	:DELTAN_ARRAY(0 to 5);
subtype INTER_TYPE is std_logic_vector(7 downto 0);
type INTER_ARRAY is array (natural range <>) of INTER_TYPE;
signal	INTER	:INTER_ARRAY(0 to 5);

signal	adpcmbusy	:std_logic_vector(5 downto 0);
signal	adpcmsumbusy:std_logic;

signal	addLa,addLb,addLq	:std_logic_vector(15 downto 0);
signal	addRa,addRb,addRq	:std_logic_vector(15 downto 0);
signal	addLql,addRql	:std_logic_vector(15 downto 0);
signal	mulina,mulinb	:std_logic_vector(15 downto 0);
signal	mulq	:std_logic_vector(31 downto 0);
signal	levin	:std_logic_vector(6 downto 0);
signal	comp	:std_logic_vector(5 downto 0);
signal	pcmsft	:std_logic_vector(5 downto 0);
signal	pcmcarry	:std_logic_vector(5 downto 0);
signal	pcmwr	:std_logic_vector(5 downto 0);
signal	pcmwrx	:std_logic_vector(5 downto 0);
signal	pcmsftx	:std_logic;

component ROM_01BD
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END component;

component ROM_02SD
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END component;

component ROM_04TOP
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (13 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END component;

component ROM_08HH
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END component;

component ROM_10TOM
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END component;

component ROM_20RIM
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END component;

--component susftmul
--generic(
--	SIGNINWIDTH		:integer	:=32;
--	UNSIGNINWIDTH	:integer	:=16
--);
--port(
--	SIGNIN	:in std_logic_vector(SIGNINWIDTH-1 downto 0);
--	UNSIGNIN:in std_logic_vector(UNSIGNINWIDTH-1 downto 0);
--	
--	MULOUT	:out std_logic_vector(SIGNINWIDTH+UNSIGNINWIDTH-1 downto 0);
--	
--	clk		:in std_logic;
--	rstn	:in std_logic
--);
--end component;

component susmult is
generic(
	awidth	:integer	:=16;
	bwidth	:integer	:=16
);
port(
	ain		:in std_logic_vector(awidth-1 downto 0);
	bin		:in std_logic_vector(bwidth-1 downto 0);
	qout	:out std_logic_vector(awidth+bwidth-1 downto 0);
	
	clk		:in std_logic
);
end component;

component CALCOPNAADPCM
generic(
	intwidth	:integer	:=8
);
port(
	INIT	:in std_logic;
	INDAT	:in std_logic_vector(3 downto 0);
	INTDAT	:in std_logic_vector(intwidth-1 downto 0);
	WR		:in std_logic;
	CARRY	:in std_logic;
	
	OUTDAT	:out std_logic_vector(15 downto 0);
	BUSY	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component b7lev
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;

component addsat
generic(
	datwidth	:integer	:=16
);
port(
	INA		:in std_logic_vector(datwidth-1 downto 0);
	INB		:in std_logic_vector(datwidth-1 downto 0);
	
	OUTQ	:out std_logic_vector(datwidth-1 downto 0);
	OFLOW	:out std_logic;
	UFLOW	:out std_logic
);
end component;

component PCMTIMING
generic(
	intwidth	:integer	:=8
);
port(
	DELTA_N	:in std_logic_vector(15 downto 0);
	
	PCMWR		:out std_logic;
	CARRY		:out std_logic;
	INTER		:out std_logic_vector(intwidth-1 downto 0);

	sft		:in std_logic;
	clk		:in std_logic;
	rstn		:in std_logic
);
end component;

component delayer
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

begin

	DELTAN(0)<=x"1339";	--01BD
	DELTAN(1)<=x"50e0";	--02SD
	DELTAN(2)<=x"549a";	--04TOP
	DELTAN(3)<=x"329b";	--08HH
	DELTAN(4)<=x"25d8";	--10TOM
	DELTAN(5)<=x"2617";	--20RIM
	
	comp(0)<=	'1' when ROMADDR(0)=x"0380" else '0';
	comp(1)<=	'1' when ROMADDR(1)=x"0500" else '0';
	comp(2)<=	'1' when ROMADDR(2)=x"2e80" else '0';
	comp(3)<=	'1' when ROMADDR(3)=x"0300" else '0';
	comp(4)<=	'1' when ROMADDR(4)=x"0500" else '0';
	comp(5)<=	'1' when ROMADDR(5)=x"0100" else '0';						
	

	process(clk,rstn)begin
		if(rstn='0')then
			KEY		<=(others=>'0');
			CHSEL0	<=(others=>'0');
			CHSEL1	<=(others=>'0');
			CHSEL2	<=(others=>'0');
			CHSEL3	<=(others=>'0');
			CHSEL4	<=(others=>'0');
			CHSEL5	<=(others=>'0');
			PARLEV0	<=(others=>'0');
			PARLEV1	<=(others=>'0');
			PARLEV2	<=(others=>'0');
			PARLEV3	<=(others=>'0');
			PARLEV4	<=(others=>'0');
			PARLEV5	<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(WR='1')then
				case ADDR is
				when x"10" =>
					if(WDAT(0)='1')then
						KEY(0)<=not WDAT(7);
					end if;
					if(WDAT(1)='1')then
						KEY(1)<=not WDAT(7);
					end if;
					if(WDAT(2)='1')then
						KEY(2)<=not WDAT(7);
					end if;
					if(WDAT(3)='1')then
						KEY(3)<=not WDAT(7);
					end if;
					if(WDAT(4)='1')then
						KEY(4)<=not WDAT(7);
					end if;
					if(WDAT(5)='1')then
						KEY(5)<=not WDAT(7);
					end if;
				when x"11" =>
					RTL<=WDAT(5 downto 0);
				when x"18" =>
					CHSEL0<=WDAT(7 downto 6);
					PARLEV0<=WDAT(4 downto 0);
				when x"19" =>
					CHSEL1<=WDAT(7 downto 6);
					PARLEV1<=WDAT(4 downto 0);
				when x"1a" =>
					CHSEL2<=WDAT(7 downto 6);
					PARLEV2<=WDAT(4 downto 0);
				when x"1b" =>
					CHSEL3<=WDAT(7 downto 6);
					PARLEV3<=WDAT(4 downto 0);
				when x"1c" =>
					CHSEL4<=WDAT(7 downto 6);
					PARLEV4<=WDAT(4 downto 0);
				when x"1d" =>
					CHSEL5<=WDAT(7 downto 6);
					PARLEV5<=WDAT(4 downto 0);
				when others =>
				end case;
			end if;
			for i in 0 to 5 loop
				if(comp(i)='1')then
					KEY(i)<='0';
				end if;
			end loop;
		end if;
	end process;
	
	
	
	process(clk,rstn)
	begin
		if(rstn='0')then
			ROMADDR(0)<=(others=>'0');
			ROMADDR(1)<=(others=>'0');
			ROMADDR(2)<=(others=>'0');
			ROMADDR(3)<=(others=>'0');
			ROMADDR(4)<=(others=>'0');
			ROMADDR(5)<=(others=>'0');
			pcmsftx<='0';
		elsif(clk' event and clk='1')then
			pcmsftx<='0';
			if(sft='1')then
				pcmsftx<='1';
				for i in 0 to 5 loop
					if(KEY(i)='0')then
						ROMADDR(i)<=(others=>'0');
					elsif(pcmcarry(i)='1')then
						PCMDATl(i)<=PCMDAT(i);
						ROMADDR(i)<=ROMADDR(i)+1;
					end if;
				end loop;
			end if;
		end if;
	end process;
	
	ROM01	:ROM_01BD  port map(ROMADDR(0)( 9 downto 0),clk,PCMDAT(0));
	ROM02	:ROM_02SD  port map(ROMADDR(1)(10 downto 0),clk,PCMDAT(1));
	ROM04	:ROM_04TOP port map(ROMADDR(2)(13 downto 0),clk,PCMDAT(2));
	ROM08	:ROM_08HH  port map(ROMADDR(3)( 9 downto 0),clk,PCMDAT(3));
	ROM10	:ROM_10TOM port map(ROMADDR(4)(10 downto 0),clk,PCMDAT(4));
	ROM20	:ROM_20RIM port map(ROMADDR(5)( 7 downto 0),clk,PCMDAT(5));
	
	adpg	:for i in 0 to 5 generate
		
		pcmsft(i)<=sft when KEY(i)='1' else '0';
		
		tim	:PCMTIMING generic map(8) port map(
			DELTA_N	=>DELTAN(i),
	
			PCMWR		=>pcmwrx(i),
			CARRY		=>pcmcarry(i),
			INTER		=>INTER(i),

			sft		=>pcmsft(i),
			clk		=>clk,
			rstn		=>rstn
		);
		
		sftdelay	:delayer generic map(3) port map(pcmwrx(i),pcmwr(i),clk,rstn);

		adp	:CALCOPNAADPCM generic map(8) port map(
			INIT	=>not KEY(i),
			INDAT	=>PCMDAT(i),
			INTDAT	=>INTER(i),
			WR		=>pcmwr(i),
			CARRY	=>pcmcarry(i),
			
			OUTDAT	=>SNDDAT(i),
			BUSY	=>adpcmbusy(i),
			
			clk		=>clk,
			rstn	=>rstn
		);
	end generate;
	
	process(adpcmbusy)begin
		adpcmsumbusy<='0';
		for i in 0 to 5 loop
			if(adpcmbusy(i)='1')then
				adpcmsumbusy<='1';
			end if;
		end loop;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			rhythmstate<=0;
		elsif(clk' event and clk='1')then
			if(pcmsftx='1')then
				rhythmstate<=1;
			elsif(rhythmstate=1)then
				if(adpcmsumbusy='0')then
					rhythmstate<=2;
				end if;
			elsif(rhythmstate=25)then
				rhythmstate<=0;
			elsif(rhythmstate>0)then
				rhythmstate<=rhythmstate+1;
			end if;
		end if;
	end process;
	
	levin<=		('0' & RTL)+('0' & PARLEV0 & '1')	when rhythmstate=1 else
				('0' & RTL)+('0' & PARLEV1 & '1')	when rhythmstate=2 else
				('0' & RTL)+('0' & PARLEV2 & '1')	when rhythmstate=3 else
				('0' & RTL)+('0' & PARLEV3 & '1')	when rhythmstate=4 else
				('0' & RTL)+('0' & PARLEV4 & '1')	when rhythmstate=5 else
				('0' & RTL)+('0' & PARLEV5 & '1')	when rhythmstate=6 else
				(others=>'0');
	lev:	b7lev port map(levin,clk,mulinb);
	
	mulina<=	SNDDAT(0)	when rhythmstate=2 else
				SNDDAT(1)	when rhythmstate=3 else
				SNDDAT(2)	when rhythmstate=4 else
				SNDDAT(3)	when rhythmstate=5 else
				SNDDAT(4)	when rhythmstate=6 else
				SNDDAT(5)	when rhythmstate=7 else
				(others=>'0');
	
	mul	:susmult generic map(16,16) port map(mulina,mulinb,mulq,clk);
	
	saddL	:addsat generic map(16)port map(addLa,addLb,addLq,open,open);
	saddR	:addsat generic map(16)port map(addRa,addRb,addRq,open,open);
	process(clk,rstn)begin
		if(rstn='0')then
			addLql<=(others=>'0');
			addRql<=(others=>'0');
		elsif(clk' event and clk='1')then
			addLql<=addLq;
			addRql<=addRq;
		end if;
	end process;
	
	addLa<=	(others=>'0')	when rhythmstate=multdelay+2 else
			addLql			when rhythmstate=multdelay+3 else
			addLql			when rhythmstate=multdelay+4 else
			addLql			when rhythmstate=multdelay+5 else
			addLql			when rhythmstate=multdelay+6 else
			addLql			when rhythmstate=multdelay+7 else
			(others=>'0');

	addRa<=	(others=>'0')	when rhythmstate=multdelay+2 else
			addRql			when rhythmstate=multdelay+3 else
			addRql			when rhythmstate=multdelay+4 else
			addRql			when rhythmstate=multdelay+5 else
			addRql			when rhythmstate=multdelay+6 else
			addRql			when rhythmstate=multdelay+7 else
			(others=>'0');
			
	addLb<=	mulq(31 downto 16) when	rhythmstate=multdelay+2 and CHSEL0(1)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+3 and CHSEL1(1)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+4 and CHSEL2(1)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+5 and CHSEL3(1)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+6 and CHSEL4(1)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+7 and CHSEL5(1)='1' else
			(others=>'0');
			
	addRb<=	mulq(31 downto 16) when	rhythmstate=multdelay+2 and CHSEL0(0)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+3 and CHSEL1(0)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+4 and CHSEL2(0)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+5 and CHSEL3(0)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+6 and CHSEL4(0)='1' else
			mulq(31 downto 16) when	rhythmstate=multdelay+7 and CHSEL5(0)='1' else
			(others=>'0');
			
	process(clk,rstn)begin
		if(rstn='0')then
			sndL<=(others=>'0');
			sndR<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(rhythmstate=multdelay+7)then
				sndL<=addLq;
				sndR<=addRq;
			end if;
		end if;
	end process;

end rtl;