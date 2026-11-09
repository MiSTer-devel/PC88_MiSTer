library IEEE,work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity e8251 is
port(
	WRn		:in std_logic;
	RDn		:in std_logic;
	C_Dn	:in std_logic;
	CSn		:in std_logic;
	DATIN	:in std_logic_vector(7 downto 0);
	DATOUT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;
	INTn	:out std_logic;
	
	TXD		:out std_logic;
	RxD		:in std_logic;
	
	DSRn	:in std_logic;
	DTRn	:out std_logic;
	RTSn	:out std_logic;
	CTSn	:in std_logic;
	
	TxRDY	:out std_logic;
	TxEMP	:out std_logic;
	RxRDY	:out std_logic;
	
	--Baud rate factor from the last mode command (00/01 = x1, 10 = x16, 11 = x64).
	MODE_BAUD	:out std_logic_vector(1 downto 0);
	--The rest of the last mode command: character length, parity enable/even, stop bits.
	MODE_CLEN	:out std_logic_vector(1 downto 0);
	MODE_PEN	:out std_logic;
	MODE_PEV	:out std_logic;
	MODE_STOP	:out std_logic_vector(1 downto 0);
	
	TxCn	:in std_logic;
	RxCn	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;

	--Save and restore. While HOLD is '1' every register keeps its value whatever the
	--inputs do (the outputs that come straight from inputs still follow them); read REG
	--then, and DIRSet loads DIR back. DIR is meant to be a value read from REG. Use them
	--with rstn at '1': rstn wins over both (CMDDONE, which has no reset, aside).
	--REG(57 downto 0): CMDDONE, BAUD, CLEN, PEN, PEV, STOP, TxEN, DTR, RxEN, RTS, cmdnum(2),
	--  pereset, oereset, fereset, RxRDYb, oeset, peset, RXINT, TXINT, ltxemp, lrxcn, ltxcn,
	--  rxce, txce, lRD_DAT, lRD_STA, lWR_DAT, lWR_CMD, RD_DAT, RD_STA, WR_DAT, WR_CMD, lWDAT, IOWDAT
	--REG(60 downto 58): FE, OE, PE; (63 downto 61) and (66 downto 64): the receive and
	--transmit prescalers; (102 downto 67): the receiver; (139 downto 103): the transmitter
	HOLD	:in std_logic	:='0';
	REG		:out std_logic_vector(139 downto 0);
	DIRSet	:in std_logic	:='0';
	DIR		:in std_logic_vector(139 downto 0)	:=(others=>'0')
);
end e8251;

architecture rtl of e8251 is
signal	BAUD	:std_logic_vector(1 downto 0);
signal	CLEN	:std_logic_vector(1 downto 0);
signal	PEN		:std_logic;
signal	PEV		:std_logic;
signal	STOP	:std_logic_vector(1 downto 0);
-- signal	SYNCCH1	:std_logic_vector(7 downto 0);
-- signal	SYNCCH2	:std_logic_vector(7 downto 0);
-- signal	EH		:std_logic;
signal	IR		:std_logic;
signal	RTS		:std_logic;
signal	ER		:std_logic;
-- signal	SBRK	:std_logic;
signal	RxEN	:std_logic;
signal	DTR		:std_logic;
signal	TxEN	:std_logic;
signal	DSR		:std_logic;
signal	FE		:std_logic;
signal	OE		:std_logic;
signal	PE		:std_logic;
signal	TxEMPb	:std_logic;
signal	RxRDYb	:std_logic;
signal	TxRDYb	:std_logic;
signal	STATUS	:std_logic_vector(7 downto 0);
signal	CMDDONE	:std_logic:='0';
signal	RECVDAT	:std_logic_vector(7 downto 0);
signal	datlen	:integer range 1 to 9;
signal	stoplen	:integer range 1 to 4;
signal	bitwidth :std_logic_vector(5 downto 0);
signal	parity	:std_logic;
signal	txdat	:std_logic_vector(8 downto 0);
signal	rxdat	:std_logic_vector(8 downto 0);
signal	txwr	:std_logic;
signal	txbemp	:std_logic;
signal	txbusy	:std_logic;
signal	rxed	:std_logic;
signal	ltxcn	:std_logic_vector(1 downto 0);
signal	lrxcn	:std_logic_vector(1 downto 0);
signal	txce	:std_logic;
signal	rxce	:std_logic;
signal	sfttx	:std_logic;
signal	sftrx	:std_logic;
signal	sfttxb	:std_logic;
signal	sftrxb	:std_logic;
signal	prescen	:std_logic;
signal	presval	:std_logic_vector(1 downto 0);
signal	cmdnum	:integer range 0 to 3;
constant cn_mode	:integer	:=0;
constant cn_sync1	:integer	:=1;
constant cn_sync2	:integer	:=2;
constant cn_cmd		:integer	:=3;

signal	tparin	:std_logic_vector(7 downto 0);
signal	rparin	:std_logic_vector(8 downto 0);
signal	tparity,rparity	:std_logic;

signal	peset	:std_logic;
signal	pereset	:std_logic;
signal	oeset	:std_logic;
signal	oereset	:std_logic;
signal	feset	:std_logic;
signal	fereset	:std_logic;

signal	IORD_STA	:std_logic;
signal	IORD_DAT	:std_logic;
signal	IOWR_CMD	:std_logic;
signal	IOWR_DAT	:std_logic;
signal	lRD_DAT		:std_logic_vector(1 downto 0);
signal	lRD_STA		:std_logic_vector(1 downto 0);
signal	lWR_DAT		:std_logic_vector(1 downto 0);
signal	lWR_CMD		:std_logic_vector(1 downto 0);
signal	lWDAT		:std_logic_vector(7 downto 0);
signal	IOWDAT		:std_logic_vector(7 downto 0);
signal	RD_DAT		:std_logic;
signal	RD_STA		:std_logic;
signal	WR_DAT		:std_logic;
signal	WR_CMD		:std_logic;
signal	RXINT		:std_logic;
signal	TXINT		:std_logic;
signal	ltxemp		:std_logic;
signal	cmdnumv		:std_logic_vector(1 downto 0);

component txframe
	generic(
		maxlen	:integer	:=8;		--max bits/frame
		maxwid	:integer	:=4
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

		HOLD	:in std_logic	:='0';
		REG		:out std_logic_vector(2*maxlen+maxwid+12 downto 0);
		DIRSet	:in std_logic	:='0';
		DIR		:in std_logic_vector(2*maxlen+maxwid+12 downto 0)	:=(others=>'0')
	);
end component;

component rxframe
	generic(
		maxlen 	:integer	:=8;
		maxwid	:integer	:=4
	);
	port(
		SD		:in std_logic;	-- serial data input
		
		SFT		:in std_logic;	-- shift enable signal
		WIDTH	:in std_logic_vector(maxwid-1 downto 0);	-- 1bit width of serial
		LEN		:in integer range 1 to maxlen;
		
		DATA	:out std_logic_Vector(maxlen-1 downto 0);	--received data
		DONE	:out std_logic;	-- received

		STOPERR	:out std_logic;	-- stop error detect
		SFTRST	:in std_logic;	-- stop receive and reset
				
		clk		:in std_logic;	-- system clock
		rstn	:in std_logic;	-- system reset

		HOLD	:in std_logic	:='0';
		REG		:out std_logic_vector(2*maxlen+maxwid+11 downto 0);
		DIRSet	:in std_logic	:='0';
		DIR		:in std_logic_vector(2*maxlen+maxwid+11 downto 0)	:=(others=>'0')
	);
end component;

component sftdiv
generic(
	width	:integer	:=8
);
port(
	sel		:in std_logic_vector(width-1 downto 0);
	sftin	:in std_logic;
	
	sftout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;

	HOLD	:in std_logic	:='0';
	REG		:out std_logic_vector(width downto 0);
	DIRSet	:in std_logic	:='0';
	DIR		:in std_logic_vector(width downto 0)	:=(others=>'0')
);
end component;

component PARITYG
generic(
	WIDTH	:integer	:=8
);
port(
	DAT		:in std_logic_vector(0 to WIDTH-1);
	O_En	:in std_logic;
	
	PAR		:out std_logic
);
end component;

component g_srff
port(
	set		:in std_logic;
	reset	:in std_logic;
	
	q		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;

	HOLD	:in std_logic	:='0';
	REG		:out std_logic;
	DIRSet	:in std_logic	:='0';
	DIR		:in std_logic	:='0'
);
end component;

begin

	datlen<=5	when CLEN="00" and PEN='0' else
			6	when CLEN="01" and PEN='0' else
			7	when CLEN="10" and PEN='0' else
			8	when CLEN="11" and PEN='0' else
			6	when CLEN="00" and PEN='1' else
			7	when CLEN="01" and PEN='1' else
			8	when CLEN="10" and PEN='1' else
			9	when CLEN="11" and PEN='1' else
			8;
	stoplen<=	1	when STOP="00" else
				2	when STOP="01" else
				3	when STOP="10" else
				4	when STOP="11" else
				3;
	bitwidth<=	"000001" when BAUD="00" else
				"000001" when BAUD="01" else
				"010000" when BAUD="10" else
				"000000" when BAUD="11" else
				"000001";
				
	prescen<=	'1' when BAUD="11" else '0';
	
	MODE_BAUD<=BAUD;
	MODE_CLEN<=CLEN;
	MODE_PEN<=PEN;
	MODE_PEV<=PEV;
	MODE_STOP<=STOP;
	
	process(clk,rstn)begin
		if(rstn='0')then
			lrxcn<=(others=>'1');
			ltxcn<=(others=>'1');
			rxce<='0';
			txce<='0';
		elsif(clk' event and clk='1')then
			rxce<='0';
			txce<='0';
			if(lrxcn(1)='0' and lrxcn(0)='1')then
				rxce<='1';
			end if;
			if(ltxcn(1)='0' and ltxcn(0)='1')then
				txce<='1';
			end if;
			lrxcn<=lrxcn(0) & RxCn;
			ltxcn<=ltxcn(0) & TxCn;
			if(DIRSet='1')then
				txce<=DIR(28);
				rxce<=DIR(29);
				ltxcn<=DIR(31 downto 30);
				lrxcn<=DIR(33 downto 32);
			elsif(HOLD='1')then
				txce<=txce;
				rxce<=rxce;
				ltxcn<=ltxcn;
				lrxcn<=lrxcn;
			end if;
		end if;
	end process;
	
	presval<="00" when prescen<='0' else "11";
	
	rps	:sftdiv generic map(2) port map(presval,rxce,sftrxb,clk,rstn,HOLD,REG(63 downto 61),DIRSet,DIR(63 downto 61));
	tps	:sftdiv generic map(2) port map(presval,txce,sfttxb,clk,rstn,HOLD,REG(66 downto 64),DIRSet,DIR(66 downto 64));
	
	sftrx<=sftrxb and RxEN;
	sfttx<=sfttxb and TxEN;
	
	rxf	:rxframe generic map(9,6) port map(RxD,sftrx,bitwidth,datlen,rxdat,rxed,feset,'0',clk,rstn,HOLD,REG(102 downto 67),DIRSet,DIR(102 downto 67));
	txf	:txframe generic map(9,6) port map(TxD,txbusy,sfttx,bitwidth,datlen,stoplen,txdat,txwr,txbemp,clk,rstn,HOLD,REG(139 downto 103),DIRSet,DIR(139 downto 103));
	
	IORD_DAT<='1' when CSn='0' and RDn='0' and C_Dn='0' else '0';
	IORD_STA<='1' when CSn='0' and RDn='0' and C_Dn='1' else '0';
	IOWR_DAT<='1' when CSn='0' and WRn='0' and C_Dn='0' else '0';
	IOWR_CMD<='1' when CSn='0' and WRn='0' and C_Dn='1' else '0';
	
	tparin<=IOWDAT 						when CLEN="11" else
			'0' & IOWDAT(6 downto 0)	when CLEN="10" else
			"00" & IOWDAT(5 downto 0)	when CLEN="01" else
			"000" & IOWDAT(4 downto 0);
	
	rparin<=rxdat 						when CLEN="11" else
			'0' & RXDAT(7 downto 0)		when CLEN="10" else
			"00" & RXDAT(6 downto 0)	when CLEN="01" else
			"000" & RXDAT(5 downto 0);
	
	tpar :parityg generic map(8) port map(tparin,not PEV,tparity);
	rpar :parityg generic map(9) port map(rparin,not PEV,rparity);
	
	process(clk,rstn)begin
		if(rstn='0')then
			lRD_DAT<=(others=>'0');
			lRD_STA<=(others=>'0');
			lWR_DAT<=(others=>'0');
			lWR_CMD<=(others=>'0');
			RD_DAT<='0';
			RD_STA<='0';
			WR_DAT<='0';
			WR_CMD<='0';
			lWDAT<=(others=>'0');
			IOWDAT<=(others=>'0');
		elsif(clk' event and clk='1')then
			RD_DAT<='0';
			RD_STA<='0';
			WR_DAT<='0';
			WR_CMD<='0';
			if(lRD_DAT="10")then
				RD_DAT<='1';
			end if;
			if(lRD_STA="10")then
				RD_STA<='1';
			end if;
			if(lWR_DAT="10")then
				WR_DAT<='1';
			end if;
			if(lWR_CMD="10")then
				WR_CMD<='1';
			end if;
			if(lWR_DAT(0)='1' or lWR_CMD(0)='1')then
				IOWDAT<=lWDAT;
			end if;
			lRD_DAT<=lRD_DAT(0) & IORD_DAT;
			lRD_STA<=lRD_STA(0) & IORD_STA;
			lWR_DAT<=lWR_DAT(0) & IOWR_DAT;
			lWR_CMD<=lWR_CMD(0) & IOWR_CMD;
			lWDAT<=DATIN;
			if(DIRSet='1')then
				IOWDAT<=DIR(7 downto 0);
				lWDAT<=DIR(15 downto 8);
				WR_CMD<=DIR(16);
				WR_DAT<=DIR(17);
				RD_STA<=DIR(18);
				RD_DAT<=DIR(19);
				lWR_CMD<=DIR(21 downto 20);
				lWR_DAT<=DIR(23 downto 22);
				lRD_STA<=DIR(25 downto 24);
				lRD_DAT<=DIR(27 downto 26);
			elsif(HOLD='1')then
				IOWDAT<=IOWDAT;
				lWDAT<=lWDAT;
				WR_CMD<=WR_CMD;
				WR_DAT<=WR_DAT;
				RD_STA<=RD_STA;
				RD_DAT<=RD_DAT;
				lWR_CMD<=lWR_CMD;
				lWR_DAT<=lWR_DAT;
				lRD_STA<=lRD_STA;
				lRD_DAT<=lRD_DAT;
			end if;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			cmdnum<=cn_mode;
			pereset<='0';
			oereset<='0';
			fereset<='0';
		elsif(clk' event and clk='1')then
			pereset<='0';
			oereset<='0';
			fereset<='0';
			if(WR_CMD='1')then
				case cmdnum is
				when cn_mode =>
					BAUD<=IOWDAT(1 downto 0);
					CLEN<=IOWDAT(3 downto 2);
					PEN<=IOWDAT(4);
					PEV<=IOWDAT(5);
					STOP<=IOWDAT(7 downto 6);
					if(IOWDAT(1 downto 0)="00")then
						cmdnum<=cn_sync1;
					else
						cmdnum<=cn_cmd;
					end if;
				when cn_sync1 =>
					-- SYNCCH1<=IOWDAT;
					cmdnum<=cn_sync2;
				when cn_sync2 =>
					-- SYNCCH2<=IOWDAT;
					cmdnum<=cn_cmd;
				when cn_cmd =>
					TxEN<=IOWDAT(0);
					DTR<=IOWDAT(1);
					RxEN<=IOWDAT(2);
					-- SBRK<=IOWDAT(3);
					pereset<=IOWDAT(4);
					oereset<=IOWDAT(4);
					fereset<=IOWDAT(4);
					RTS<=IOWDAT(5);
					if(IOWDAT(6)='1')then
						cmdnum<=cn_mode;
					end if;
					-- EH<=IOWDAT(7);
				when others=>
				end case;
			end if;
			if(DIRSet='1')then
				fereset<=DIR(40);
				oereset<=DIR(41);
				pereset<=DIR(42);
				cmdnum<=conv_integer(DIR(44 downto 43));
				RTS<=DIR(45);
				RxEN<=DIR(46);
				DTR<=DIR(47);
				TxEN<=DIR(48);
				STOP<=DIR(50 downto 49);
				PEV<=DIR(51);
				PEN<=DIR(52);
				CLEN<=DIR(54 downto 53);
				BAUD<=DIR(56 downto 55);
			elsif(HOLD='1')then
				fereset<=fereset;
				oereset<=oereset;
				pereset<=pereset;
				cmdnum<=cmdnum;
				RTS<=RTS;
				RxEN<=RxEN;
				DTR<=DTR;
				TxEN<=TxEN;
				STOP<=STOP;
				PEV<=PEV;
				PEN<=PEN;
				CLEN<=CLEN;
				BAUD<=BAUD;
			end if;
		end if;
	end process;

	txdat<=	tparity & IOWDAT 					when CLEN="11" else
			'0' & tparity & IOWDAT(6 downto 0)	when CLEN="10" else
			"00" & tparity & IOWDAT(5 downto 0)	when CLEN="01" else
			"000" & tparity & IOWDAT(4 downto 0);

	txwr<=WR_DAT and TxEN;

	process(clk,rstn)begin
		if(rstn='0')then
			RxRDYb<='0';
			oeset<='0';
			peset<='0';
			RXINT<='0';
		elsif(clk' event and clk='1')then
			oeset<='0';
			peset<='0';
			--RxEnable off holds RxRDY reset (8251A data sheet), so a character that was fully
			--received before the receiver was disabled is not presented once it is enabled again.
			if(RxEN='0')then
				RxRDYb<='0';
				RXINT<='0';
			elsif(rxed='1')then
				RXINT<='1';
				if(RxRDYb='1')then
					oeset<='1';
				end if;
				if(PEN='1' and rparity='1')then
					peset<='1';
				end if;
				RxRDYb<='1';
			elsif(RD_DAT='1')then
				RxRDYb<='0';
				RXINT<='0';
			elsif(RD_STA='1')then
				RXINT<='0';
			elsif(WR_CMD='1')then
				RXINT<='0';
			end if;
			if(DIRSet='1')then
				RXINT<=DIR(36);
				peset<=DIR(37);
				oeset<=DIR(38);
				RxRDYb<=DIR(39);
			elsif(HOLD='1')then
				RXINT<=RXINT;
				peset<=peset;
				oeset<=oeset;
				RxRDYb<=RxRDYb;
			end if;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			TXINT<='0';
		elsif(clk' event and clk='1')then
			if(ltxemp='0' and txbemp='1')then
				TXINT<='1';
			elsif(WR_DAT='1')then
				TXINT<='0';
			elsif(RD_STA='1')then
				TXINT<='0';
			elsif(WR_CMD='1')then
				TXINT<='0';
			end if;
			ltxemp<=txbemp;
			if(DIRSet='1')then
				ltxemp<=DIR(34);
				TXINT<=DIR(35);
			elsif(HOLD='1')then
				ltxemp<=ltxemp;
				TXINT<=TXINT;
			end if;
		end if;
	end process;

	INTn<=	'0' when RXINT='1' else
			'0' when TXINT='1' else
			'1';
			
	TxRDYb<=txbemp;
	TxEMPb<=TxRDYb and (not txbusy);
	
	--Gated as well, so RxRDY is low from the clock the receiver is disabled (a character
	--completing on that same clock would otherwise show for one clock).
	RxRDY<=RxRDYb and RxEN;
	TxEMP<=TxEMPb;
	TxRDY<=TxRDYb when CTSn='0' and TxEN='1' else '0';
	RTSn<=not RTS;
	DTRn<=not DTR;
	
	PEF	:g_srff port map(peset,pereset,PE,clk,rstn,HOLD,REG(58),DIRSet,DIR(58));
	OEF	:g_srff port map(oeset,oereset,OE,clk,rstn,HOLD,REG(59),DIRSet,DIR(59));
	FEF	:g_srff port map(feset,fereset,FE,clk,rstn,HOLD,REG(60),DIRSet,DIR(60));
	
	--A PC-8801FH reads the status as 00h from power-on until the first command is
	--written; a reset of the CPU does not bring that back.
	process(clk)begin
		if(clk' event and clk='1')then
			if(WR_CMD='1' and cmdnum=cn_cmd)then
				CMDDONE<='1';
			end if;
			if(DIRSet='1')then
				CMDDONE<=DIR(57);
			elsif(HOLD='1')then
				CMDDONE<=CMDDONE;
			end if;
		end if;
	end process;

	STATUS<= (not DSRn & '0' & FE & OE & PE & TxEMPb & (RxRDYb and RxEN) & TxRDYb) when CMDDONE='1' else (others=>'0');
	
	RECVDAT<=	rxdat(7 downto 0) 			when CLEN="11" else
				'0' & rxdat(6 downto 0)		when CLEN="10" else
				"00" & rxdat(5 downto 0)	when CLEN="01" else
				"000" & rxdat(4 downto 0);
	
	DATOUT<=STATUS when C_Dn='1' else RECVDAT;
	DATOE<=IORD_DAT or IORD_STA;

	cmdnumv<=conv_std_logic_vector(cmdnum,2);
	REG(57 downto 0)<=CMDDONE & BAUD & CLEN & PEN & PEV & STOP & TxEN & DTR & RxEN & RTS & cmdnumv &
		pereset & oereset & fereset & RxRDYb & oeset & peset & RXINT & TXINT & ltxemp & lrxcn & ltxcn &
		rxce & txce & lRD_DAT & lRD_STA & lWR_DAT & lWR_CMD & RD_DAT & RD_STA & WR_DAT & WR_CMD & lWDAT & IOWDAT;
end rtl;
