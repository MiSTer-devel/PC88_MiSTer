LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cmtdem is
generic(
	cycle	:integer	:=83;
	fltlen	:integer	:=10
);
port(
	cmtsig	:in std_logic;
	
	datum	:out std_logic;
	carrier	:out std_logic;
	
	sftf	:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end cmtdem;

architecture rtl of cmtdem is
signal	cyccount	:integer range 0 to cycle*3;
signal	ldatum		:std_logic;
signal	fdatum		:std_logic;
signal	edet		:std_logic;
component DIGIFILTERS is
	generic(
		TIME	:integer	:=2;
		DEF		:std_logic	:='0'
	);
	port(
		D	:in std_logic;
		Q	:out std_logic;
		
		sft	:in std_logic;
		clk	:in std_logic;
		rstn :in std_logic
	);
end component;
begin
	fil	:digifilters generic map(fltlen,'0') port map(cmtsig,fdatum,sftf,clk,rstn);
	
	process(clk,rstn)begin
		if(rstn='0')then
			ldatum<='0';
			edet<='0';
		elsif(clk' event and clk='1')then
			if(sftf='1')then
				edet<='0';
				if(ldatum='0' and fdatum='1')then
					edet<='1';
				end if;
				ldatum<=fdatum;
			end if;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			cyccount<=0;
			datum<='1';
			carrier<='0';
		elsif(clk' event and clk='1')then
			if(sftf='1')then
				if(edet='1')then
					if(cyccount=0)then
						cyccount<=cyccount+1;
					elsif(cyccount<cycle/2)then	--noise;
						cyccount<=cyccount+1;
					elsif(cyccount<(cycle+cycle/2))then		--high freq;
						carrier<='1';
						datum<='1';
						cyccount<=1;
					elsif(cyccount<(cycle*2+cycle/2))then	--low freq;
						datum<='0';
						carrier<='1';
						cyccount<=1;
					end if;
				elsif(cyccount>(cycle*2+cycle/2))then
					carrier<='0';
					datum<='1';
				end if;
			end if;
		end if;
	end process;
end rtl;
