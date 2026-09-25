library IEEE;
use IEEE.std_logic_1164.all;

--Passes a CPU write to the OPN as a single clk21m write. The chip select and
--write strobe come from the CPU clock, so they are synchronised first. The
--address and data are used as they are: the CPU holds them for longer than the
--three to five clk21m cycles (up to 250 ns) this takes.
entity fmwrsync is
port(
	CSn		:in std_logic;
	WRn		:in std_logic;
	WROn	:out std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
);
end fmwrsync;

architecture rtl of fmwrsync is
signal	s1,s2,s3	:std_logic;
signal	wrp			:std_logic;

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
			if(rstn='0')then
				s1<='0';
				s2<='0';
				s3<='0';
				wrp<='0';
			else
				s1<=not(CSn or WRn);
				s2<=s1;
				s3<=s2;
				wrp<=s2 and not s3;
			end if;
		end if;
	end process;

	WROn<=not wrp;

end rtl;
