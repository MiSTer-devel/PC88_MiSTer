-- DDS(Direct Digital Synthesizer) clock enabler for OPN
-- Generated at https://pgate1.at-ninja.jp/memo/dds/dds.htm
--
-- Generate from 20MHz to
-- 3.9936MHz: カウンタ 13bit、加算値 624、最大値 3125、誤差 0.0000000000
-- 7.9872MHz: カウンタ 13bit、加算値 1248、最大値 3125、誤差 0.0000000000

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity DDS_OPN is
    generic(
        add_val	:integer	:=624;
        max_val :integer    :=3125
    );
	port(
		rst, clk : in std_logic;
		enable : out std_logic
	);
end DDS_OPN;

architecture RTL of DDS_OPN is

constant COUNT_WIDTH : integer := 13;
constant ADD_NUM : std_logic_vector(COUNT_WIDTH-1 downto 0)
	:= std_logic_vector(to_unsigned(add_val, COUNT_WIDTH));
constant MAX_NUM : std_logic_vector(COUNT_WIDTH-1 downto 0)
	:= std_logic_vector(to_unsigned(max_val, COUNT_WIDTH));

signal add   : std_logic_vector(COUNT_WIDTH-1 downto 0);
signal max   : std_logic_vector(COUNT_WIDTH-1 downto 0);
signal count : std_logic_vector(COUNT_WIDTH-1 downto 0);
signal sa    : std_logic_vector(COUNT_WIDTH-1 downto 0);

begin

	add <= ADD_NUM;
	max <= MAX_NUM;

	sa <= count - max;

	process(clk) begin
		if rising_edge(clk) then
			if rst='1' then
				count <= (others => '0');
			elsif sa(COUNT_WIDTH-1)='1' then -- count < max
				count <= count + add;
			else
				count <= sa + add;
			end if;
		end if;
	end process;

	enable <= not sa(COUNT_WIDTH-1);

end RTL;