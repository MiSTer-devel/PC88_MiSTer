library IEEE,work;
use IEEE.std_logic_1164.all;
use	IEEE.std_logic_unsigned.all;

entity sftmul is
generic(
	DATAWIDTH	:integer 	:=32;
	DATBWIDTH	:integer	:=10
);
port(
	DATA	:in std_logic_vector(DATAWIDTH-1 downto 0);
	DATB	:in std_logic_vector(DATBWIDTH-1 downto 0);
	
	DATQ	:out std_logic_vector(DATAWIDTH+DATBWIDTH-1 downto 0);
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end sftmul;

architecture rtl of sftmul is
constant SFTDATWIDTH	:integer	:=DATAWIDTH+DATBWIDTH;
subtype SFTDAT_TYPE is std_logic_vector(SFTDATWIDTH-1 downto 0);
type SFTDAT_ARRAY is array (natural range <>) of SFTDAT_TYPE;
subtype DATB_TYPE is std_logic_vector(DATBWIDTH-1 downto 0);
type DATB_ARRAY is array (natural range <>) of DATB_TYPE;
signal	SFTDAT	:SFTDAT_ARRAY(0 to DATBWIDTH);
signal	DATAS	:SFTDAT_ARRAY(0 to DATBWIDTH);
signal	DATBS	:DATB_ARRAY(0 to DATBWIDTH);

component shiftadd
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
end component;
begin

	gen0	:for i in 0 to DATBWIDTH-1 generate
		sfta	:shiftadd generic map(SFTDATWIDTH,DATBWIDTH) port map(
			DATIN		=>SFTDAT(i),
			ADDVALIN	=>DATAS(i),
			SFTIN		=>DATBS(i),
			
			DATOUT		=>SFTDAT(i+1),
			ADDVALOUT	=>DATAS(i+1),
			SFTOUT		=>DATBS(i+1),
			
			clk			=>clk,
			rstn		=>rstn
		);
	end generate;

	SFTDAT(0)<=(others=>'0');
	DATAS(0)(DATAWIDTH-1 downto 0)<=DATA;
	DATAS(0)(DATAWIDTH+DATBWIDTH-1 downto DATAWIDTH)<=(others=>'0');
	DATBS(0)<=DATB;
	DATQ<=SFTDAT(DATBWIDTH);
end rtl;
