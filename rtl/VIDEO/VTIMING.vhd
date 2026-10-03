library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.VIDEO_TIMING_pkg.all;

entity VTIMING is
generic(
	DOTPU	:integer	:=8;
	HWIDTH	:integer	:=800;
	VWIDTH	:integer	:=525;
	HVIS	:integer	:=640;
	VVIS	:integer	:=400;
	CPD		:integer	:=3;		--clocks per dot
	HFP		:integer	:=3;
	HSY		:integer	:=12;
	VFP		:integer	:=51;
	VSY		:integer	:=2
);	
port(
	VT24	:in std_logic	:='0';		-- 1:24kHz or 15kHz timing (lines from the CRTC)
	VT15	:in std_logic	:='0';		-- 1:15kHz timing
	VEND24	:in integer range 0 to VWMAX-1	:=VWMAX-1;	-- last line in 24kHz or 15kHz timing

	VCOUNT	:out integer range 0 to VWMAX-1;
	HUCOUNT	:out integer range 0 to HUWMAX-1;
	UCOUNT	:out integer range 0 to DOTPU-1;
	
	HCOMP	:out std_logic;
	VCOMP	:out std_logic;
	
	clk2	:out std_logic;
	clk3	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic;
	CE3		:out std_logic
);
end VTIMING;
architecture MAIN of VTIMING is
constant 	HUWIDTH :integer	:=HWIDTH/DOTPU;
constant 	HUVIS	:integer	:=HVIS/DOTPU;
constant 	HBP		:integer	:=HUWIDTH-HUVIS-HFP-HSY;
constant 	HIV		:integer	:=HFP+HSY+HBP;
constant 	VBP		:integer	:=VWIDTH-VVIS-VFP-VSY;
constant	VIV		:integer	:=VFP+VSY+VBP;

signal	vcounter	:integer range 0 to VWMAX-1;
signal	hucounter	:integer range 0 to HUWMAX-1;
signal	vend	:integer range 0 to VWMAX-1;
signal	huend	:integer range 0 to HUWMAX-1;
signal	ucounter	:integer range 0 to DOTPU-1;
signal	hcompb	:std_logic;
signal	vcompb	:std_logic;
signal	clk2sft	:std_logic_vector(1 downto 0);
signal	clk3sft	:std_logic_vector(2 downto 0);
signal	clk3b	:std_logic;
signal	dotacc	:integer range 0 to DOTDENMAX-1;
signal	dotnum	:integer range 0 to DOTDENMAX-1;
signal	dotden	:integer range 1 to DOTDENMAX;
signal	dotce	:std_logic;
signal	dotced	:std_logic;

begin

	process(clk,rstn)begin
		if(rstn='0')then
			clk2sft<="01";
			clk3sft<="001";
		elsif(clk' event and clk='1')then
			clk2sft<=clk2sft(0) & clk2sft(1);
			clk3sft<=clk3sft(1 downto 0) & clk3sft(2);
		end if;
	end process;
	clk2<=clk2sft(1);

	--24kHz: dot enable at DOTNUM24/DOTDEN24 of clk (every 3 or 4 clocks)
	--15kHz: at DOTNUM15/DOTDEN15 (every 5 or 6 clocks)
	dotnum<=DOTNUM15 when VT15='1' else DOTNUM24;
	dotden<=DOTDEN15 when VT15='1' else DOTDEN24;
	process(clk,rstn)begin
		if(rstn='0')then
			dotacc<=0;
			dotce<='0';
			dotced<='0';
		elsif(clk' event and clk='1')then
			if(dotacc+dotnum>=dotden)then
				dotacc<=dotacc+dotnum-dotden;
				dotce<='1';
			else
				dotacc<=dotacc+dotnum;
				dotce<='0';
			end if;
			dotced<=dotce;
		end if;
	end process;

	clk3<=dotced when VT24='1' else clk3sft(2);
	clk3b<=dotce when VT24='1' else clk3sft(1);
	CE3<=clk3b;

	vend<=VEND24 when VT24='1' else VWIDTH-1;
	huend<=HUWIDTH15-1 when VT15='1' else HUWIDTH24-1 when VT24='1' else (HWIDTH/DOTPU)-1;

	process(clk,rstn)begin
		if(rstn='0')then
			vcounter<=VWIDTH-1;
			hucounter<=0;
			ucounter<=0;
			hcompb<='0';
			vcompb<='0';
		elsif(clk' event and clk='1')then
		 if(clk3b='1')then
			hcompb<='0';
			vcompb<='0';
			if(ucounter=(DOTPU-1))then
				ucounter<=0;
				if(hucounter>=huend)then
					hucounter<=0;
					hcompb<='1';
					if(vcounter>=vend)then
						vcounter<=0;
						vcompb<='1';
					else 
						vcounter<=vcounter+1;
					end if;
				else
					hucounter<=hucounter+1;
				end if;
			else
				ucounter<=ucounter+1;
			end if;
		 end if;
		end if;
	end process;
	
	
	process(clk,rstn)begin
		if(rstn='0')then
			VCOUNT<=0;
			HUCOUNT<=0;
			UCOUNT<=0;
			VCOMP<='0';
			HCOMP<='0';
		elsif(clk' event and clk='1')then
			VCOUNT<=vcounter;
			HUCOUNT<=hucounter;
			UCOUNT<=ucounter;
			VCOMP<=vcompb;
			HCOMP<=hcompb;
		end if;
	end process;

end MAIN;
					
			
			
	
