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
	
	TxCn	:in std_logic;
	RxCn	:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end e8251;

architecture rtl of e8251 is
signal	BAUD	:std_logic_vector(1 downto 0);
signal	CLEN	:std_logic_vector(1 downto 0);
signal	PEN		:std_logic;
signal	PEV		:std_logic;
signal	STOP	:std_logic_vector(1 downto 0);
signal	SYNCCH1	:std_logic_vector(7 downto 0);
signal	SYNCCH2	:std_logic_vector(7 downto 0);
signal	EH		:std_logic;
signal	IR		:std_logic;
signal	RTS		:std_logic;
signal	ER		:std_logic;
signal	SBRK	:std_logic;
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
		rstn	:in std_logic		-- system reset
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
		rstn	:in std_logic	-- system reset
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
	rstn	:in std_logic
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
	rstn	:in std_logic
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
		end if;
	end process;
	
	presval<="00" when prescen<='0' else "11";
	
	rps	:sftdiv generic map(2) port map(presval,rxce,sftrxb,clk,rstn);
	tps	:sftdiv generic map(2) port map(presval,txce,sfttxb,clk,rstn);
	
	sftrx<=sftrxb and RxEN;
	sfttx<=sfttxb and TxEN;
	
	rxf	:rxframe generic map(9,6) port map(RxD,sftrx,bitwidth,datlen,rxdat,rxed,feset,'0',clk,rstn);
	txf	:txframe generic map(9,6) port map(TxD,txbusy,sfttx,bitwidth,datlen,stoplen,txdat,txwr,txbemp,clk,rstn);
	
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
					SYNCCH1<=IOWDAT;
					cmdnum<=cn_sync2;
				when cn_sync2 =>
					SYNCCH2<=IOWDAT;
					cmdnum<=cn_cmd;
				when cn_cmd =>
					TxEN<=IOWDAT(0);
					DTR<=IOWDAT(1);
					RxEN<=IOWDAT(2);
					SBRK<=IOWDAT(3);
					pereset<=IOWDAT(4);
					oereset<=IOWDAT(4);
					fereset<=IOWDAT(4);
					RTS<=IOWDAT(5);
					if(IOWDAT(6)='1')then
						cmdnum<=cn_mode;
					end if;
					EH<=IOWDAT(7);
				when others=>
				end case;
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
			if(rxed='1')then
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
		end if;
	end process;
	
	process(clk,rstn)
	variable ltxemp	:std_logic;
	begin
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
			ltxemp:=txbemp;
		end if;
	end process;

	INTn<=	'0' when RXINT='1' else
			'0' when TXINT='1' else
			'1';
			
	TxRDYb<=txbemp;
	TxEMPb<=TxRDYb and (not txbusy);
	
	RxRDY<=RxRDYb;
	TxEMP<=TxEMPb;
	TxRDY<=TxRDYb when CTSn='0' and TxEN='1' else '0';
	RTSn<=not RTS;
	DTRn<=not DTR;
	
	PEF	:g_srff port map(peset,pereset,PE,clk,rstn);
	OEF	:g_srff port map(oeset,oereset,OE,clk,rstn);
	FEF	:g_srff port map(feset,fereset,FE,clk,rstn);
	
	STATUS<= not DSRn & '0' & FE & OE & PE & TxEMPb & RxRDYb & TxRDYb;
	
	RECVDAT<=	rxdat(7 downto 0) 			when CLEN="11" else
				'0' & rxdat(6 downto 0)		when CLEN="10" else
				"00" & rxdat(5 downto 0)	when CLEN="01" else
				"000" & rxdat(4 downto 0);
	
	DATOUT<=STATUS when C_Dn='1' else RECVDAT;
	DATOE<=IORD_DAT or IORD_STA;
end rtl;
