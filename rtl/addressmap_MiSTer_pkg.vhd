library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

package addressmap_pkg is
	constant ADDR_N88			:std_logic_Vector(27 downto 0)	:=x"0000000";
	constant ADDR_N80			:std_logic_vector(27 downto 0)	:=x"0008000";
	constant ADDR_N88_4_0	:std_logic_vector(27 downto 0)	:=x"0010000";
	constant ADDR_N88_4_1	:std_logic_vector(27 downto 0)	:=x"0012000";
	constant ADDR_N88_4_2	:std_logic_vector(27 downto 0)	:=x"0014000";
	constant ADDR_N88_4_3	:std_logic_vector(27 downto 0)	:=x"0016000";
	constant ADDR_FONT		:std_logic_vector(27 downto 0)	:=x"0018000";
	constant ADDR_GFONT		:std_logic_vector(27 downto 0)	:=x"0019000";
	constant ADDR_SUBROM		:std_logic_vector(27 downto 0)	:=x"001a000";
	constant ADDR_KANJI1		:std_logic_vector(27 downto 0)	:=x"0020000";
	constant ADDR_KANJI2		:std_logic_vector(27 downto 0)	:=x"0040000";
	constant ADDR_BACKRAM	:std_logic_vector(27 downto 0)	:=x"0400000";
	constant ADDR_MAINRAM	:std_logic_vector(27 downto 0)	:=x"0408000";
	constant ADDR_SUBRAM		:std_logic_vector(27 downto 0)	:=x"0410000";
	constant ADDR_GVRAM		:std_logic_vector(27 downto 0)	:=x"0420000";
	constant ADDR_EXTRAM		:std_logic_vector(27 downto 0)	:=x"0480000";
	constant ADDR_ADPCM		:std_logic_vector(27 downto 0)	:=x"0600000";
	constant ADDR_FDEMU		:std_logic_vector(27 downto 0)	:=x"0800000";
end addressmap_pkg;
