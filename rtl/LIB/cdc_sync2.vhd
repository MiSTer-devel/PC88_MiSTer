library IEEE;
use IEEE.std_logic_1164.all;

--Brings a single bit into the clk domain through two registers. Use only
--q; s1 must feed nothing but s2. There is no reset: after a reset q follows
--d within two clocks.
entity cdc_sync2 is
port(
	d		:in std_logic;
	q		:out std_logic;

	clk		:in std_logic
);
end cdc_sync2;

architecture rtl of cdc_sync2 is
signal	s1,s2	:std_logic;

--Keep the synchronising registers from being duplicated or retimed.
attribute preserve : boolean;
attribute dont_replicate : boolean;
attribute dont_retime : boolean;
attribute preserve of s1, s2 : signal is true;
attribute dont_replicate of s1, s2 : signal is true;
attribute dont_retime of s1, s2 : signal is true;

begin
	process(clk)begin
		if(clk' event and clk='1')then
			s1<=d;
			s2<=s1;
		end if;
	end process;

	q<=s2;

end rtl;
