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
	--sync positions: the picture sits where the FH's does through an OSSC Pro.
	--Vertical sync starts 7 lines after the display, and the back porch takes
	--the rest of the retrace.
	constant VFP24	:integer	:=7;
	constant VSY24	:integer	:=2;
	--dot clock: 400/19 MHz = 21.0526MHz from rclk 2125/28 MHz (75.892857MHz,
	--rtl/pll/pll_0002.v): (400/19)/(2125/28) = 448/1615 exactly
	constant DOTNUM24	:integer	:=448;
	constant DOTDEN24	:integer	:=1615;
	--accepted CRTC parameters: character height 8-20, rows 1-25, retrace 40 lines or more
	constant CHRLMIN24	:integer	:=8;
	constant CHRLMAX24	:integer	:=20;
	constant ROWSMAX24	:integer	:=25;
	--the retrace floor stays 40 lines, as before the sync position was moved
	constant VRETMIN24	:integer	:=40;
	--used until a parameter set is written: the ROM's 25-line set
	constant ROWSDEF24	:integer	:=25;
	constant CHRLDEF24	:integer	:=16;
	constant VRETDEF24	:integer	:=48;

	--15kHz monitor timing (OSD option). Lines and blanking come from the CRTC
	--parameters as in 24kHz, and the screen is drawn 200 lines.
	constant HWIDTH15	:integer	:=896;
	constant HUWIDTH15	:integer	:=HWIDTH15/DOTPU;
	--sync positions: the picture sits where the FH's does through an OSSC Pro.
	--Vertical sync starts 15 lines after the display, and the back porch takes
	--the rest of the retrace.
	constant HFP15	:integer	:=8;
	constant HSY15	:integer	:=8;
	constant HIV15	:integer	:=HUWIDTH15-HUVIS;
	constant VFP15	:integer	:=15;
	constant VSY15	:integer	:=3;
	--dot clock: 315/22 MHz = 14.3182MHz from rclk 2125/28 MHz. The exact ratio
	--is 882/4675; 223/1182 is 0.96 ppm fast and keeps the accumulator at 11 bits
	constant DOTNUM15	:integer	:=223;
	constant DOTDEN15	:integer	:=1182;
	--accepted CRTC parameters: as in 24kHz, but retrace 19 lines or more
	--(front porch and sync, and at least one line of back porch)
	constant VRETMIN15	:integer	:=VFP15+VSY15+1;
	--used until a parameter set is written: the ROM's 25-line set
	constant CHRLDEF15	:integer	:=8;
	constant VRETDEF15	:integer	:=56;

	--TRAMCONV takes the parameter set at this line of the retrace
	constant CAPLINE	:integer	:=8;

	--counter ranges for all timings
	constant HUWMAX	:integer	:=HUWIDTH15;
	constant DOTDENMAX	:integer	:=DOTDEN24;
	constant VWMAX	:integer	:=(ROWSMAX24+8)*CHRLMAX24;

end VIDEO_TIMING_pkg;
