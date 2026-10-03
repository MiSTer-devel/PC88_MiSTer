library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.VIDEO_TIMING_pkg.all;

entity synccont2 is
generic(
	DOTPU	:integer	:=8;
	HWIDTH	:integer	:=800;
	VWIDTH	:integer	:=525;
	HVIS	:integer	:=640;
	VVIS	:integer	:=400;
	VVIS2	:integer	:=480;
	CPD		:integer	:=3;		--clocks per dot
	HFP		:integer	:=3;
	HSY		:integer	:=12;
	VFP		:integer	:=51;
	VSY		:integer	:=2
);	
port(
	VT24	:in std_logic	:='0';		-- 1:24kHz or 15kHz timing (lines from the CRTC)
	VT15	:in std_logic	:='0';		-- 1:15kHz timing
	VRET24	:in integer range 0 to VWMAX-1	:=VRETMIN24;	-- retrace lines in 24kHz or 15kHz timing

	UCOUNT	:in integer range 0 to DOTPU-1;
	HUCOUNT	:in integer range 0 to HUWMAX-1;
	VCOUNT	:in integer range 0 to VWMAX-1;
	HCOMP	:in std_logic;
	VCOMP	:in std_logic;

	HSYNC	:out std_logic;
	VSYNC	:out std_logic;
	VISIBLE	:out std_logic;
	VIDEN		:out std_logic;
	
	HRTC	:out std_logic;
	VRTC	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;
	ce		:in std_logic := '1'
);
end synccont2;

architecture MAIN of  synccont2 is
constant 	HUWIDTH :integer	:=HWIDTH/DOTPU;
constant 	HUVIS	:integer	:=HVIS/DOTPU;
constant 	HBP		:integer	:=HUWIDTH-HUVIS-HFP-HSY;
constant 	HIV		:integer	:=HFP+HSY+HBP;
constant 	VBP		:integer	:=VWIDTH-VVIS-VFP-VSY;
constant 	VBP2		:integer	:=VWIDTH-VVIS2-VFP-VSY;
constant	VIV		:integer	:=VFP+VSY+VBP;
constant	VIV2		:integer	:=VFP+VSY+VBP2;

signal	HSYNCB	:std_logic_vector(7 downto 0);
signal	VSYNCB	:std_logic_vector(7 downto 0);
signal	VISIBLEB:std_logic_vector(7 downto 0);
signal	VIDENB:std_logic_vector(7 downto 0);
signal	HSYNCN	:std_logic;
signal	VSYNCN	:std_logic;
signal	VISIBLEN:std_logic;
signal	VIDENEN:std_logic;
signal	hfps,hsye,hivs	:integer range 0 to HUWMAX;
signal	vfps,vsye,vivs,viv2s	:integer range 0 to VWMAX;
begin
	--24kHz: front porch 7, sync 2, back porch in the retrace lines
	--15kHz: front porch 15, sync 3, back porch in the retrace lines
	hfps<=	HFP15 when VT15='1' else HFP24 when VT24='1' else HFP;
	hsye<=	HFP15+HSY15 when VT15='1' else HFP24+HSY24 when VT24='1' else HFP+HSY;
	hivs<=	HIV15 when VT15='1' else HIV24 when VT24='1' else HIV;
	vfps<=	VFP15 when VT15='1' else VFP24 when VT24='1' else VFP;
	vsye<=	VFP15+VSY15 when VT15='1' else VFP24+VSY24 when VT24='1' else VFP+VSY;
	vivs<=	VRET24 when VT24='1' else VIV;
	viv2s<=	VRET24 when VT24='1' else VIV2;

	HSYNCN<=	'0' when (HUCOUNT<hfps) else
				'1' when (HUCOUNT<hsye) else
				'0';
	VSYNCN<=	'0' when (VCOUNT<vfps) else
				'1' when (VCOUNT<vsye) else
				'0';
	VISIBLEN<=	'0' when VCOUNT<vivs else
					'0' when HUCOUNT<hivs else
					'1';
	VIDENEN<=	'0' when VCOUNT<viv2s else
					'0' when HUCOUNT<hivs else
					'1';
	VRTC		<=	'1' when VCOUNT<vivs else '0';
	HRTC        <=    '1' when HUCOUNT<hivs else '0';

	process	(clk,rstn)begin
		if(rstn='0')then
			HSYNCB<=(others=>'0');
			VSYNCB<=(others=>'0');
			VISIBLEB<=(others=>'0');
			VIDENB<=(others=>'0');
			HSYNC<='0';
			VSYNC<='0';
			VISIBLE<='0';
			VIDEN<='0';
		elsif(clk' event and clk='1')then
		 if(ce='1')then
			HSYNC<=HSYNCB(0);
			VSYNC<=VSYNCB(0);
			VISIBLE<=VISIBLEB(0);
			VIDEN<=VIDENB(0);
			VSYNCB(7 downto 0)<=VSYNCN & VSYNCB(7 downto 1);
			HSYNCB(7 downto 0)<=HSYNCN & HSYNCB(7 downto 1);
			VISIBLEB(7 downto 0)<=VISIBLEN & VISIBLEB(7 downto 1);
			VIDENB(7 downto 0)<=VIDENEN & VIDENB(7 downto 1);
		 end if;
		end if;
	end process;
end MAIN;


