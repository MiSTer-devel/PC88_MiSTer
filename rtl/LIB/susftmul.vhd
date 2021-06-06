library IEEE,work;
use IEEE.std_logic_1164.all;
use	IEEE.std_logic_unsigned.all;

entity susftmul is
generic(
	SIGNINWIDTH		:integer	:=32;
	UNSIGNINWIDTH	:integer	:=16
);
port(
	SIGNIN	:in std_logic_vector(SIGNINWIDTH-1 downto 0);
	UNSIGNIN:in std_logic_vector(UNSIGNINWIDTH-1 downto 0);
	
	MULOUT	:out std_logic_vector(SIGNINWIDTH+UNSIGNINWIDTH-1 downto 0);
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end susftmul;

architecture rtl of susftmul is
signal	insign	:std_logic;
signal	abssign	:std_logic_vector(SIGNINWIDTH-2 downto 0);
signal	unsmul	:std_logic_vector(SIGNINWIDTH+UNSIGNINWIDTH-2 downto 0);
signal	outsign	:std_logic;

component sftmul
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
end component;

component delayer is
generic(
	counts	:integer	:=5
);
port(
	a		:in std_logic;
	q		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin
	insign<=SIGNIN(SIGNINWIDTH-1);
	sigdelay	:delayer generic map(UNSIGNINWIDTH-1) port map(insign,outsign,clk,rstn);
	
	abssign<=	SIGNIN(SIGNINWIDTH-2 downto 0) when SIGNIN(SIGNINWIDTH-1)='0' else
				(not SIGNIN(SIGNINWIDTH-2 downto 0)+1);
	
	mul	:sftmul generic map(SIGNINWIDTH-1,UNSIGNINWIDTH) port map(abssign,UNSIGNIN,unsmul,clk,rstn);
	
	MULOUT<= '0' & unsmul when outsign='0' else
			'1' & (not unsmul)+1;
	
end rtl;