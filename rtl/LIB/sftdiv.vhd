library IEEE,work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use	IEEE.std_logic_unsigned.all;

entity sftdiv is
generic(
	width	:integer	:=8
);
port(
	sel		:in std_logic_vector(width-1 downto 0);
	sftin	:in std_logic;
	
	sftout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;

	--Save and restore: REG is sftout & count. While HOLD is '1' they are kept;
	--DIRSet loads DIR (a value read from REG). rstn wins over both.
	HOLD	:in std_logic	:='0';
	REG		:out std_logic_vector(width downto 0);
	DIRSet	:in std_logic	:='0';
	DIR		:in std_logic_vector(width downto 0)	:=(others=>'0')
);
end sftdiv;

architecture rtl of sftdiv is
signal	count	:integer range 0 to (2**width)-1;
signal	sftoutb	:std_logic;
begin
	process(clk,rstn)begin
		if(rstn='0')then
			count<=0;
		elsif(clk' event and clk='1')then
			if(sftin='1')then
				if(count=0)then
					sftoutb<='1';
					count<=conv_integer(sel);
				else
					sftoutb<='0';
					count<=count-1;
				end if;
			else
				sftoutb<='0';
			end if;
			if(DIRSet='1')then
				sftoutb<=DIR(width);
				count<=conv_integer(DIR(width-1 downto 0));
			elsif(HOLD='1')then
				sftoutb<=sftoutb;
				count<=count;
			end if;
		end if;
	end process;
	sftout<=sftoutb;
	REG<=sftoutb & conv_std_logic_vector(count,width);
end rtl;