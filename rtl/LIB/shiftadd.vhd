library IEEE,work;
use IEEE.std_logic_1164.all;
use	IEEE.std_logic_unsigned.all;

entity shiftadd is
generic(
	DATWIDTH	:integer	:=32;
	SFTWIDTH	:integer	:=10
);
port(
	DATIN		:in std_logic_vector(DATWIDTH-1 downto 0);
	ADDVALIN	:in std_logic_vector(DATWIDTH-1 downto 0);
	SFTIN		:in std_logic_vector(SFTWIDTH-1 downto 0);
	
	DATOUT		:out std_logic_vector(DATWIDTH-1 downto 0);
	ADDVALOUT	:out std_logic_vector(DATWIDTH-1 downto 0);
	SFTOUT		:out std_logic_vector(SFTWIDTH-1 downto 0);
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end shiftadd;

architecture rtl of shiftadd is
begin
	process(clk,rstn)begin
		if(rstn='0')then
			DATOUT<=(others=>'0');
			SFTOUT<=(others=>'0');
			ADDVALOUT<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(SFTIN(SFTWIDTH-1)='1')then
				DATOUT<=(DATIN(DATWIDTH-2 downto 0) & '0')+ADDVALIN;
			else
				DATOUT<=(DATIN(DATWIDTH-2 downto 0) & '0');
			end if;
			ADDVALOUT<=ADDVALIN;
			SFTOUT<=SFTIN(SFTWIDTH-2 downto 0) & '0';
		end if;
	end process;
end rtl;
