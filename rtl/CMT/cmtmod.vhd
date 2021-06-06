LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CMTMOD is
port(
	datum	:in std_logic;
	
	cmtsig	:out std_logic;
	
	sft		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end CMTMOD;

architecture rtl of CMTMOD is
signal	phase	:integer range 0 to 3;
signal	sign	:std_logic;
begin
	process(clk,rstn)begin
		if(rstn='0')then
			phase<=0;
			sign<='0';
		elsif(clk' event and clk='1')then
			if(sft='1')then
				case phase is
				when 0 =>
					cmtsig<='1';
					sign<=datum;
				when 1 =>
					if(sign='1')then
						cmtsig<='0';
					end if;
				when 2=>
					if(sign='1')then
						cmtsig<='1';
					else
						cmtsig<='0';
					end if;
				when 3 =>
					if(sign='1')then
						cmtsig<='1';
					end if;
				when others=>
				end case;
			end if;
		end if;
	end process;
end rtl;