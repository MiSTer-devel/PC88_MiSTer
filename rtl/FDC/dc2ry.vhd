LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity dc2ry is
generic(
	delay	:integer	:=100
);
port(
	USEL	:in std_logic_vector(1 downto 0);
	BUSY	:in std_logic;
	DSKCHGn	:in std_logic;
	RDBITn	:in std_logic;
	INDEXn	:in std_logic;
	
	READYn	:out std_logic;
	READYv	:out std_logic_vector(3 downto 0);
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end dc2ry;

architecture rtl of dc2ry is
signal	lUSEL	:std_logic_vector(1 downto 0);
signal	lDCn	:std_logic_vector(3 downto 0);
signal	dcount	:integer range 0 to delay-1;
signal	rdy		:std_logic_vector(3 downto 0);
signal	beat	:std_logic;
signal	lBusy	:std_logic_vector(3 downto 0);
begin

	READYn<=not rdy(0) when USEL="00" else
			not rdy(1) when USEL="01" else
			not rdy(2) when USEL="10" else
			not rdy(3) when USEL="11" else
			'1';
	beat<=(not RDBITn) or (not INDEXn);
	
	READYV<=rdy;
	
	process(clk,rstn)begin
		if(rstn='0')then
			lDCn<=(others=>'0');
			dcount<=delay-1;
			rdy<=(others=>'0');
			lUSEL<=(others=>'0');
			lBusy<="0000";
		elsif(clk' event and clk='1')then
			lBusy<=lBusy(2 downto 0)&BUSY;
			if(USEL/=USEL)then
				dcount<=delay-1;
			elsif(dcount>0)then
				dcount<=dcount-1;
			elsif(lBusy="1111" and BUSY='1')then
				case USEL is
				when "00" =>
					lDCn(0)<=DSKCHGn;
					if(DSKCHGn='1')then
						rdy(0)<='1';
					elsif(lDCn(0)='1' and DSKCHGn='0')then
						rdy(0)<='0';
					elsif(beat='1')then
						rdy(0)<='1';
					end if;
				when "01" =>
					lDCn(1)<=DSKCHGn;
					if(DSKCHGn='1')then
						rdy(1)<='1';
					elsif(lDCn(1)='1' and DSKCHGn='0')then
						rdy(1)<='0';
					elsif(beat='1')then
						rdy(1)<='1';
					end if;
				when "10" =>
					lDCn(2)<=DSKCHGn;
					if(DSKCHGn='1')then
						rdy(2)<='1';
					elsif(lDCn(2)='1' and DSKCHGn='0')then
						rdy(2)<='0';
					elsif(beat='1')then
						rdy(2)<='1';
					end if;
				when "11" =>
					lDCn(3)<=DSKCHGn;
					if(DSKCHGn='1')then
						rdy(3)<='1';
					elsif(lDCn(3)='1' and DSKCHGn='0')then
						rdy(3)<='0';
					elsif(beat='1')then
						rdy(3)<='1';
					end if;
				when others =>
				end case;
			end if;
		end if;
	end process;
end rtl;
