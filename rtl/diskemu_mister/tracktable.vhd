LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.all;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity tracktable is
port(
	wraddr	:in std_logic_vector(9 downto 0);
	wrdat	:in std_logic_vector(7 downto 0);
	wr		:in std_logic;
	
	table	:in std_logic_vector(7 downto 0);
	haddr	:out std_logic_vector(31 downto 0);
	
	clk		:in std_logic
);
end tracktable;
 
architecture rtl of tracktable is
subtype DAT_LAT_TYPE is std_logic_vector(31 downto 0); 
type DAT_LAT_ARRAY is array (natural range <>) of DAT_LAT_TYPE; 
signal	RAM		:DAT_LAT_ARRAY(0 to 255);
signal	iwaddr	:integer range 0 to 255;
signal	itable	:integer range 0 to 255;
signal	imgsize	:std_logic_vector(31 downto 0);
signal 	BUF0 	:std_logic_vector(7 downto 0);
signal 	BUF1 	:std_logic_vector(7 downto 0);
signal 	BUF2 	:std_logic_vector(7 downto 0);

begin

	iwaddr<=conv_integer(wraddr(9 downto 2));
	itable<=conv_integer(table);
	
	process(clk)
	variable BUF3	:std_logic_vector(7 downto 0);
	variable BUFF	:std_logic_vector(31 downto 0);
	begin
		if(clk' event and clk='1')then
			if(wr='1')then
				BUF3:=x"00";
				case wraddr(1 downto 0) is
				when "00" =>
					BUF0<=wrdat;
				when "01" =>
					BUF1<=wrdat;
				when "10" =>
					BUF2<=wrdat;
				when "11" =>
					BUF3:=wrdat;
				when others =>
				end case;
				BUFF:=BUF3 & BUF2 & BUF1 & BUF0;
				if(iwaddr=7)then
					imgsize<=BUFF;
				end if;
				if((iwaddr>7) and (BUFF>=imgsize))then
					RAM(iwaddr)<=x"00000000";
				else
					RAM(iwaddr)<=BUFF;
				end if;
			end if;
			haddr<=RAM(itable);
		end if;
	end process;
	
end rtl;
