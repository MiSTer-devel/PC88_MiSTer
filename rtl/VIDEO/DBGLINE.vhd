LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity DBGLINE is
port(
	START		:in std_logic;
	dat0		:in std_logic_vector(7 downto 0);
	dat1		:in std_logic_vector(7 downto 0);
	dat2		:in std_logic_vector(7 downto 0);
	dat3		:in std_logic_vector(7 downto 0);
	dat4		:in std_logic_vector(7 downto 0);
	dat5		:in std_logic_vector(7 downto 0);
	dat6		:in std_logic_vector(7 downto 0);
	dat7		:in std_logic_vector(7 downto 0);
	
	BUSUSE		:out std_logic;
	TVRAM_ADR	:out std_logic_vector(11 downto 0);
	TVRAM_WDAT	:out std_logic_vector(7 downto 0);
	TVRAM_WR	:out std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end DBGLINE;

architecture rtl of DBGLINE is
signal	state	:integer range 0 to 3;
constant st_IDLE	:integer	:=0;
constant st_SETADR	:integer	:=1;
constant st_SETDAT	:integer	:=2;
constant st_NEXT	:integer	:=3;
signal ADR			:std_logic_vector(11 downto 0);
constant BASEADR	:std_logic_vector(11 downto 0)	:=x"f6e";
signal	cdat		:std_logic_vector(3 downto 0);
signal	cchr		:std_logic_vector(7 downto 0);

begin

	cdat<=
		dat0(7 downto 4)	when ADR=x"000" else
		dat0(3 downto 0)	when ADR=x"002" else
		dat1(7 downto 4)	when ADR=x"006" else
		dat1(3 downto 0)	when ADR=x"008" else
		dat2(7 downto 4)	when ADR=x"00c" else
		dat2(3 downto 0)	when ADR=x"00e" else
		dat3(7 downto 4)	when ADR=x"012" else
		dat3(3 downto 0)	when ADR=x"014" else
		dat4(7 downto 4)	when ADR=x"018" else
		dat4(3 downto 0)	when ADR=x"01a" else
		dat5(7 downto 4)	when ADR=x"01e" else
		dat5(3 downto 0)	when ADR=x"020" else
		dat6(7 downto 4)	when ADR=x"024" else
		dat6(3 downto 0)	when ADR=x"026" else
		dat7(7 downto 4)	when ADR=x"02a" else
		dat7(3 downto 0)	when ADR=x"02c" else
		(others=>'0');
	
	cchr<=	x"3" & cdat when cdat<x"a" else
			x"4" & (cdat-x"9");
		
	process(clk,rstn)begin
		if(rstn='0')then
			ADR<=(others=>'0');
			TVRAM_WDAT<=(others=>'0');
			TVRAM_WR<='0';
			STATE<=ST_IDLE;
		elsif(clk' event and clk='1')then
			TVRAM_WR<='0';
			if(START='1')then
				ADR<=(others=>'0');
				STATE<=ST_SETDAT;
				BUSUSE<='1';
			else
				case STATE is
				when st_SETADR =>
					ADR<=ADR+x"001";
					STATE<=ST_SETDAT;
				when st_SETDAT =>
					STATE<=ST_NEXT;
					case ADR is
					when x"000" | x"002" | x"006" | x"008" | x"00c" | x"00e" | x"012" | x"014" | x"018" | x"01a" | x"01e" | x"020" | x"024" | x"026" | x"02a" | x"02c" =>
						TVRAM_WDAT<=cchr;
						TVRAM_WR<='1';
					when x"004" | x"00a" | x"010" | x"016" | x"01c" | x"022" | x"028" =>
						TVRAM_WDAT<=x"20";
						TVRAM_WR<='1';
					when x"001" | x"003" | x"005" | x"007" | x"009" | x"00b" | x"00d" | x"00f" |
						 x"011" | x"013" | x"015" | x"017" | x"019" | x"01b" | x"01d" | x"01f" | 
						 x"021" | x"023" | x"025" | x"027" | x"029" | x"02b" | x"02d" =>
						 TVRAM_WDAT<=x"07";
						TVRAM_WR<='1';
					when others=>
						TVRAM_WDAT<=(others=>'0');
						BUSUSE<='0';
						STATE<=st_IDLE;
					end case;
				when st_NEXT =>
					state<=ST_SETADR;
				when others=>
					state<=ST_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	TVRAM_ADR<=BASEADR+ADR;
	
end rtl;
						
			
				
					