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
	constant VVIS2	:integer	:=400; -- originaly 480
	constant CPD	:integer	:=3;
	constant HFP	:integer	:=2; -- originaly 3
	constant HSY	:integer	:=12;
	constant HBP	:integer	:=HUWIDTH-HUVIS-HFP-HSY;
	constant HIV	:integer	:=HFP+HSY+HBP;
	constant VFP    :integer    :=80; -- originally 11
	constant VSY	:integer	:=2;
	constant VBP	:integer	:=VWIDTH-VVIS-VFP-VSY;
	constant VBP2	:integer	:=VWIDTH-VVIS2-VFP-VSY;
	constant VIV	:integer	:=VFP+VSY+VBP;
	constant VIV2	:integer	:=VFP+VSY+VBP2;

	--24kHz monitor timing (OSD option). Lines and blanking come from the CRTC
	--parameters (rows, character height, vertical retrace rows).
	constant HWIDTH24	:integer	:=848;
	constant HUWIDTH24	:integer	:=HWIDTH24/DOTPU;
	constant HFP24	:integer	:=8;
	constant HSY24	:integer	:=8;
	constant HIV24	:integer	:=HUWIDTH24-HUVIS;
	constant VSY24	:integer	:=2;
	constant VBP24	:integer	:=38;
	--dot clock: 75MHz*16/57 = 21.0526MHz
	constant DOTNUM24	:integer	:=16;
	constant DOTDEN24	:integer	:=57;
	--accepted CRTC parameters: character height 8-20, rows 1-25, retrace 40 lines or more
	constant CHRLMIN24	:integer	:=8;
	constant CHRLMAX24	:integer	:=20;
	constant ROWSMAX24	:integer	:=25;
	constant VRETMIN24	:integer	:=VSY24+VBP24;
	--used until a parameter set is written: the ROM's 25-line set
	constant ROWSDEF24	:integer	:=25;
	constant CHRLDEF24	:integer	:=16;
	constant VRETDEF24	:integer	:=48;

	--counter ranges for both timings
	constant HUWMAX	:integer	:=HUWIDTH24;
	constant VWMAX	:integer	:=(ROWSMAX24+8)*CHRLMAX24;

end VIDEO_TIMING_pkg;
