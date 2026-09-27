LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity clktx is
generic(
	same	:boolean	:=false		-- fclk and sclk are the same clock and ce is '1'
);
port(
	txin	:in std_logic;
	txout	:out std_logic;
	
	fclk	:in std_logic;
	sclk	:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1';	-- enable for the sclk side
	rstns	:in std_logic			-- reset for the sclk side, released on sclk
);
end clktx;

architecture rtl of clktx is
signal	txpend	:std_logic;
signal	txdone	:std_logic;
--signal	stxpend	:std_logic;
begin
	two :if not same generate
	process(fclk,rstn)begin
		if(rstn='0')then
			txpend<='0';
		elsif(fclk' event and fclk='1')then
			if(txin='1')then
				txpend<='1';
			elsif(txdone='1')then
				txpend<='0';
			end if;
		end if;
	end process;
	
	process(sclk,rstns)begin
		if(rstns='0')then
			txdone<='0';
			txout<='0';
--			stxpend<='0';
		elsif(sclk' event and sclk='1')then
		 if(ce='1')then
			txout<='0';
--			stxpend<=txpend;
--			if(stxpend='1')then
			if(txpend='1')then
				txout<='1';
				txdone<='1';
--			elsif(stxpend='0')then
			elsif(txpend='0')then
				txdone<='0';
			end if;
		 end if;
		end if;
	end process;
	end generate;

	--On one clock txin is already a one-clock pulse. Pass it on a clock later;
	--the form above would stretch it to two clocks. fclk and rstn are not used.
	one :if same generate
	process(sclk,rstns)begin
		if(rstns='0')then
			txout<='0';
		elsif(sclk' event and sclk='1')then
			txout<=txin;
		end if;
	end process;
	end generate;
end rtl;				
			