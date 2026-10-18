LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.FDC_timing.all;

entity FDtiming is
generic(
	sysclk	:integer	:=21477		--in kHz
);
port(
	drv0sel		:in std_logic;		--0:300rpm 1:360rpm
	drv1sel		:in std_logic;
	drv0sele	:in std_logic;		--1:speed selectable
	drv1sele	:in std_logic;

	drv0hd		:in std_logic;
	drv0hdi		:in std_logic;		--IBM 1.44MB format
	drv1hd		:in std_logic;
	drv1hdi		:in std_logic;		--IBM 1.44MB format
	
	drv0hds		:out std_logic;
	drv1hds		:out std_logic;
	
	drv0int		:out integer range 0 to (BR_300_D*sysclk/1000000);
	drv1int		:out integer range 0 to (BR_300_D*sysclk/1000000);
	-- the same bit cells in 1/256 clocks, rounded, for FM and for MFM (half)
	drv0f		:out integer range 0 to (BR_300_D*sysclk*16+31250)/62500;
	drv0m		:out integer range 0 to (BR_300_D*sysclk*16+31250)/62500;
	drv1f		:out integer range 0 to (BR_300_D*sysclk*16+31250)/62500;
	drv1m		:out integer range 0 to (BR_300_D*sysclk*16+31250)/62500;
	
	hmssft		:out std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end FDtiming;

architecture rtl of FDtiming is
function cellf(br :integer) return integer is	-- BR_ns*sysclk*256/10^6, rounded
begin
	return (br*sysclk*16+31250)/62500;
end cellf;
function cellm(br :integer) return integer is	-- the MFM half, rounded on its own
begin
	return (br*sysclk*8+31250)/62500;
end cellm;
component sftgen
generic(
	maxlen	:integer	:=100
);
port(
	len		:in integer range 0 to maxlen;
	sft		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin
	drv0int<=	BR_360_D*sysclk/1000000 when drv0sel='1' and drv0hd='0' else
				BR_300_H*sysclk/1000000 when drv0sel='1' and drv0sele='1' and drv0hd='1' and drv0hdi='0' else
				BR_360_H*sysclk/1000000 when drv0sel='1' and drv0sele='0' and drv0hd='1' and drv0hdi='0' else
				BR_360_I*sysclk/1000000 when drv0sel='1' and drv0hd='1' and drv0hdi='1' else
				BR_300_D*sysclk/1000000 when drv0sel='0' and drv0hd='0' else
				BR_360_H*sysclk/1000000 when drv0sel='0' and drv0sele='1' and drv0hd='1' and drv0hdi='0' else
				BR_300_H*sysclk/1000000 when drv0sel='0' and drv0sele='0' and drv0hd='1' and drv0hdi='0' else
				BR_300_I*sysclk/1000000 when drv0sel='0' and drv0hd='1' and drv0hdi='1' else
				0;

	drv0f<=	cellf(BR_360_D) when drv0sel='1' and drv0hd='0' else
				cellf(BR_300_H) when drv0sel='1' and drv0sele='1' and drv0hd='1' and drv0hdi='0' else
				cellf(BR_360_H) when drv0sel='1' and drv0sele='0' and drv0hd='1' and drv0hdi='0' else
				cellf(BR_360_I) when drv0sel='1' and drv0hd='1' and drv0hdi='1' else
				cellf(BR_300_D) when drv0sel='0' and drv0hd='0' else
				cellf(BR_360_H) when drv0sel='0' and drv0sele='1' and drv0hd='1' and drv0hdi='0' else
				cellf(BR_300_H) when drv0sel='0' and drv0sele='0' and drv0hd='1' and drv0hdi='0' else
				cellf(BR_300_I) when drv0sel='0' and drv0hd='1' and drv0hdi='1' else
				0;

	drv0m<=	cellm(BR_360_D) when drv0sel='1' and drv0hd='0' else
				cellm(BR_300_H) when drv0sel='1' and drv0sele='1' and drv0hd='1' and drv0hdi='0' else
				cellm(BR_360_H) when drv0sel='1' and drv0sele='0' and drv0hd='1' and drv0hdi='0' else
				cellm(BR_360_I) when drv0sel='1' and drv0hd='1' and drv0hdi='1' else
				cellm(BR_300_D) when drv0sel='0' and drv0hd='0' else
				cellm(BR_360_H) when drv0sel='0' and drv0sele='1' and drv0hd='1' and drv0hdi='0' else
				cellm(BR_300_H) when drv0sel='0' and drv0sele='0' and drv0hd='1' and drv0hdi='0' else
				cellm(BR_300_I) when drv0sel='0' and drv0hd='1' and drv0hdi='1' else
				0;

	drv1int<=	BR_360_D*sysclk/1000000 when drv1sel='1' and drv1hd='0' else
				BR_300_H*sysclk/1000000 when drv1sel='1' and drv1sele='1' and drv1hd='1' and drv1hdi='0' else
				BR_360_H*sysclk/1000000 when drv1sel='1' and drv1sele='0' and drv1hd='1' and drv1hdi='0' else
				BR_360_I*sysclk/1000000 when drv1sel='1' and drv1hd='1' and drv1hdi='1' else
				BR_300_D*sysclk/1000000 when drv1sel='0' and drv1hd='0' else
				BR_360_H*sysclk/1000000 when drv1sel='0' and drv1sele='1' and drv1hd='1' and drv1hdi='0' else
				BR_300_H*sysclk/1000000 when drv1sel='0' and drv1sele='0' and drv1hd='1' and drv1hdi='0' else
				BR_300_I*sysclk/1000000 when drv1sel='0' and drv1hd='1' and drv1hdi='1' else
				0;

	drv1f<=	cellf(BR_360_D) when drv1sel='1' and drv1hd='0' else
				cellf(BR_300_H) when drv1sel='1' and drv1sele='1' and drv1hd='1' and drv1hdi='0' else
				cellf(BR_360_H) when drv1sel='1' and drv1sele='0' and drv1hd='1' and drv1hdi='0' else
				cellf(BR_360_I) when drv1sel='1' and drv1hd='1' and drv1hdi='1' else
				cellf(BR_300_D) when drv1sel='0' and drv1hd='0' else
				cellf(BR_360_H) when drv1sel='0' and drv1sele='1' and drv1hd='1' and drv1hdi='0' else
				cellf(BR_300_H) when drv1sel='0' and drv1sele='0' and drv1hd='1' and drv1hdi='0' else
				cellf(BR_300_I) when drv1sel='0' and drv1hd='1' and drv1hdi='1' else
				0;

	drv1m<=	cellm(BR_360_D) when drv1sel='1' and drv1hd='0' else
				cellm(BR_300_H) when drv1sel='1' and drv1sele='1' and drv1hd='1' and drv1hdi='0' else
				cellm(BR_360_H) when drv1sel='1' and drv1sele='0' and drv1hd='1' and drv1hdi='0' else
				cellm(BR_360_I) when drv1sel='1' and drv1hd='1' and drv1hdi='1' else
				cellm(BR_300_D) when drv1sel='0' and drv1hd='0' else
				cellm(BR_360_H) when drv1sel='0' and drv1sele='1' and drv1hd='1' and drv1hdi='0' else
				cellm(BR_300_H) when drv1sel='0' and drv1sele='0' and drv1hd='1' and drv1hdi='0' else
				cellm(BR_300_I) when drv1sel='0' and drv1hd='1' and drv1hdi='1' else
				0;
	
	drv0hds<=	'1' when drv0sele='1' and drv0hd='1' and drv0hdi='0' else '0';
	drv1hds<=	'1' when drv1sele='1' and drv1hd='1' and drv1hdi='0' else '0';
	
	hmss:sftgen generic map((sysclk/2)-1) port map((sysclk/2)-1,hmssft,clk,rstn);
end rtl;

	