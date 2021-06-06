library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

package VIDEO_TIMING_pkg is
	constant DOTPU	:integer	:=8;
	constant HWIDTH	:integer	:=800;
	constant HUWIDTH :integer	:=HWIDTH/DOTPU;
	constant VWIDTH	:integer	:=525;
	constant HVIS	:integer	:=640;
	constant HUVIS	:integer	:=HVIS/DOTPU;
	constant VVIS	:integer	:=400;
	constant VVIS2	:integer	:=480;
	constant CPD	:integer	:=3;
	constant HFP	:integer	:=3;
	constant HSY	:integer	:=12;
	constant HBP	:integer	:=HUWIDTH-HUVIS-HFP-HSY;
	constant HIV	:integer	:=HFP+HSY+HBP;
	constant VFP	:integer	:=11;
	constant VSY	:integer	:=2;
	constant VBP	:integer	:=VWIDTH-VVIS-VFP-VSY;
	constant VBP2	:integer	:=VWIDTH-VVIS2-VFP-VSY;
	constant VIV	:integer	:=VFP+VSY+VBP;
	constant VIV2	:integer	:=VFP+VSY+VBP2;
	
end VIDEO_TIMING_pkg;
