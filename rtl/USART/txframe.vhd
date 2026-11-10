library IEEE,work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity txframe	is
	generic(
		maxlen	:integer	:=8;		--max bits/frame
		maxwid	:integer	:=4			--max bit/clock
	);
	port(
		SD		:out std_logic;		-- serial data output
		DRCNT	:out std_logic;		-- driver control signal

		SFT		:in std_logic;		-- shift enable signal
		WIDTH	:in std_logic_vector(maxwid-1 downto 0);	-- 1bit width of serial
		LEN		:in integer range 1 to maxlen;		--bits/frame
		STPLEN	:in integer range 1 to 4;			--stop bit length*2
		
		DATA	:in std_logic_vector(maxlen-1 downto 0);	-- transmit data input
		WRITE	:in std_logic;		-- transmit write signal(start)
		BUFEMP	:out std_logic;		-- transmit buffer empty signal
		
		clk		:in std_logic;		-- system clock
		rstn	:in std_logic;		-- system reset

		-- Save and restore. While HOLD is '1' every register is kept; DIRSet loads DIR
		-- (a value read from REG). rstn wins over both.
		HOLD	:in std_logic	:='0';
		REG		:out std_logic_vector(2*maxlen+maxwid+12 downto 0);	-- WCNT, DRCNT, SD, BITCNT(8), SFTBUF, EXDATA, NXTBUF
		DIRSet	:in std_logic	:='0';
		DIR		:in std_logic_vector(2*maxlen+maxwid+12 downto 0)	:=(others=>'0')
	);
end txframe;

architecture rtl of txframe is
signal	SFTBUF	:std_logic_vector(MAXLEN+1 downto 0);	-- reansmit shift buffer
signal	WCNT	:std_logic_vector(MAXWID-1 downto 0);	-- 1bit width counter
signal	NXTBUF	:std_logic_vector(MAXLEN-1 downto 0);	-- transmit buffer
signal	BITCNT	:integer range 0 to MAXLEN+1;			-- bit number counter
signal	EXDATA	:std_logic;						-- transmit buffer full
signal	SDb		:std_logic;
signal	DRCNTb	:std_logic;
constant widzero	:std_logic_vector(maxwid-1 downto 0)	:=(others=>'0');
begin

	process(clk,rstn)begin
		if(rstn='0')then
			NXTBUF<=(others=>'0');
			EXDATA<='0';
			SFTBUF<=(others=>'0');
			BITCNT<=0;
			SDb<='1';
			DRCNTb<='0';
			WCNT<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(WRITE='1' and EXDATA='0')then	-- write to buffer
				NXTBUF<=DATA;
				EXDATA<='1';
			end if;

			if(SFT='1')then
				if((WCNT=widzero) or (BITCNT<STPLEN and WCNT(maxwid-1)='0' and WCNT(maxwid-2 downto 0)=WIDTH(maxwid-1 downto 1)))then
					if(BITCNT=0)then	-- shift register empty
						if(EXDATA='1')then
							SFTBUF(maxlen downto 1)<=NXTBUF;	--data
							SFTBUF(LEN+1)<='1';	-- stop
							SFTBUF(0)<='0';	-- start
							BITCNT<=LEN+STPLEN;		-- last n bit
							EXDATA<='0';	-- buffer empty
							WCNT<=WIDTH-1;
							DRCNTb<='1';		-- transmitting
							SDb<='0';		-- start bit output
						else
							DRCNTb<='0';		-- no transmitting
						end if;
					else
						SDb<=SFTBUF(1);	-- shift the register
						SFTBUF(maxlen downto 0)<=SFTBUF(maxlen+1 downto 1);
						SFTBUF(LEN)<='1';
						BITCNT<=BITCNT-1;
						WCNT<=WIDTH-1;
					end if;
				else
					WCNT<=WCNT-1;
				end if;
			end if;
			if(DIRSet='1')then
				NXTBUF<=DIR(maxlen-1 downto 0);
				EXDATA<=DIR(maxlen);
				SFTBUF<=DIR(2*maxlen+2 downto maxlen+1);
				BITCNT<=conv_integer(DIR(2*maxlen+10 downto 2*maxlen+3));
				SDb<=DIR(2*maxlen+11);
				DRCNTb<=DIR(2*maxlen+12);
				WCNT<=DIR(2*maxlen+maxwid+12 downto 2*maxlen+13);
			elsif(HOLD='1')then
				NXTBUF<=NXTBUF;
				EXDATA<=EXDATA;
				SFTBUF<=SFTBUF;
				BITCNT<=BITCNT;
				SDb<=SDb;
				DRCNTb<=DRCNTb;
				WCNT<=WCNT;
			end if;
		end if;
	end process;
	SD<=SDb;
	DRCNT<=DRCNTb;
	REG<=WCNT & DRCNTb & SDb & conv_std_logic_vector(BITCNT,8) & SFTBUF & EXDATA & NXTBUF;

	BUFEMP<=(not EXDATA) and (not WRITE);
	
end rtl;