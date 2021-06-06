library	IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity MULTI is
	generic(
		Awidth	:integer	:=8;
		Bwidth	:integer	:=8
	);
	port(
		A		:in std_logic_vector(Awidth-1 downto 0);
		B		:in std_logic_vector(Bwidth-1 downto 0);
		write	:in std_logic;
		
		Q		:out std_logic_vector(Awidth+Bwidth-1 downto 0);
		done	:out std_logic;
		
		clk		:in std_logic;
		rstn	:in std_logic
	);
end MULTI;

architecture MAIN of MULTI is
signal	COL	:integer range 0 to Bwidth-1 ;
signal	B_shift	:std_logic_vector(Bwidth-1 downto 0);
signal	busy	:std_logic;
begin

	process(clk,rstn)
	variable	SUM	:std_logic_vector(Awidth+Bwidth-1 downto 0);
	variable	SUMA :std_logic_vector(Awidth+Bwidth-1 downto 0);
	begin
		if(rstn='0')then
			SUM:=(others=>'0');
			COL<=0;
			B_shift<=(others=>'0');
			busy<='0';
			done<='0';
			Q<=(others=>'0');
		elsif(clk' event and clk='1')then
			SUMA(Awidth-1 downto 0):=A;
			for i in 0 to Bwidth-1 loop
				SUMA(Awidth+i):=SUMA(Awidth-1);
			end loop;

			if(write='1')then
				SUM:=(others=>'0');
				COL<=Bwidth-1;
				B_shift(Bwidth-1 downto 1)<=B(Bwidth-2 downto 0);
				B_shift(0)<='0';
				if(B(Bwidth-1)='1')then
					SUM:=SUM+SUMA;
				end if;
				busy<='1';
			elsif(COL/=0)then
				SUM(Awidth+Bwidth-1 downto 1):=SUM(Awidth+Bwidth-2 downto 0);
				SUM(0):='0';
				B_shift(0)<='0';
				if(B_shift(Bwidth-1)='1')then
					SUM:=SUM+SUMA;
				end if;
				B_shift(Bwidth-1 downto 1)<=B_shift(Bwidth-2 downto 0);
				COL<=COL-1;
			elsif(busy='1')then
				Q<=SUM;
				busy<='0';
				done<='1';
			else
				done<='0';
			end if;
		end if;
	end process;
end MAIN;
