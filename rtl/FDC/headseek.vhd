LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity headseek is
generic(
	maxtrack	:integer	:=79;
	maxset		:integer	:=10;
	initseek	:integer	:=0
);
port(
	desttrack	:in integer range 0 to maxtrack;
	destset		:in std_logic;
	setwait		:in integer range 0 to maxset;		--settling time
	
	curtrack	:out integer range 0 to maxtrack;
	
	reachtrack	:out std_logic;
	busy		:out std_logic;
	
	track0		:in std_logic;
	seek		:out std_logic;
	sdir		:out std_logic;
	
	init		:in std_logic;
	seekerr		:out std_logic;
	
	sft			:in std_logic;
	clk			:in std_logic;
	rstn		:in std_logic
);
end headseek;

architecture rtl of headseek is
--RECALIBRATE steps out until TRACK0, giving up after 77 step pulses (uPD765).
constant recalsteps	:integer	:=77;
signal	current	:integer range 0 to maxtrack;

	type state_t is (
		ST_INIWAIT,
		ST_INIOUT,
		ST_INIERR,
		ST_IDLE,
		ST_CONTROL,
		ST_WAITSET,
		ST_NOP
	);
	signal	state	:state_t;
	
	type movestate_t is(
		MS_IDLE,
		MS_SEEKON,
		MS_SEEKOFF,
		MS_SEEKWAIT,
		MS_SEEKWAIT2
	);
	signal	movestate	:movestate_t;
	

signal	movedir		:std_logic;
signal	move		:std_logic;
signal	intbusy		:std_logic;
signal	curdir		:std_logic;
signal	wsetcount	:integer range 0 to maxset;
signal	seekerrb	:std_logic;
signal	busyb		:std_logic;

begin

	process(clk,rstn)begin
		if(rstn='0')then
			current<=0;
			movedir<='1';
			move<='0';
			reachtrack<='0';
			seekerrb<='0';
			if(initseek=0)then
				busyb<='0';
				state<=ST_IDLE;
			else
				busyb<='1';
				current<=recalsteps;
				wsetcount<=maxset;
				state<=ST_INIWAIT;
			end if;
		elsif(clk' event and clk='1')then
			reachtrack<='0';
			move<='0';
			if(init='1')then
				STATE<=ST_INIWAIT;
				current<=recalsteps;
				wsetcount<=maxset;
				seekerrb<='0';
				busyb<='1';
			end if;
			case state is
			when ST_INIWAIT =>		--let track0 follow the newly selected drive
				if(wsetcount>0)then
					wsetcount<=wsetcount-1;
				else
					state<=ST_INIOUT;
				end if;
			when ST_INIOUT =>
				if(intbusy='0')then
					if(track0='1')then
						if(current>0)then
							current<=current-1;
							movedir<='1';
							move<='1';
						else
							state<=ST_INIERR;
						end if;
					else
						current<=0;
						seekerrb<='0';
						wsetcount<=setwait;
						state<=ST_WAITSET;
					end if;
				end if;
			when ST_INIERR =>		--report the failure one step period after the last step, as a seek end
				if(sft='1')then
					seekerrb<='1';
					busyb<='0';
					state<=ST_IDLE;
				end if;
			when ST_IDLE =>
				if(destset='1')then
					seekerrb<='0';
					if(current=desttrack)then
						reachtrack<='1';
						state<=ST_NOP;
						busyb<='1';
					else
						if(desttrack>current)then
							movedir<='0';
						else
							movedir<='1';
						end if;
						state<=ST_CONTROL;
						busyb<='1';
					end if;
				end if;
			when ST_NOP =>
				busyb<='0';
				state<=st_IDLE;
			when ST_CONTROL =>
				if(intbusy='0')then
					if(current=desttrack)then
						wsetcount<=setwait;
						state<=ST_WAITSET;
					else
						move<='1';
						if(movedir='1')then
							current<=current-1;
						else
							current<=current+1;
						end if;
					end if;
				end if;
			when ST_WAITSET =>
				if(sft='1')then
					if(wsetcount>0)then
						wsetcount<=wsetcount-1;
					else
						reachtrack<='1';
						busyb<='0';
						state<=ST_IDLE;
					end if;
				end if;
			when others=>
				state<=ST_IDLE;
			end case;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			seek<='1';
			curdir<='0';
			movestate<=MS_IDLE;
		elsif(clk' event and clk='1')then
			if(move='1')then
				curdir<=movedir;
				movestate<=MS_SEEKON;
			elsif(sft='1')then
				case movestate is
				when MS_SEEKON =>
					seek<='0';
					movestate<=MS_SEEKOFF;
				when MS_SEEKOFF =>
					seek<='1';
					movestate<=MS_SEEKWAIT;
				--a step takes four sft periods, (16-SRT)*2 ms as on the uPD765 at 4 MHz
				when MS_SEEKWAIT =>
					movestate<=MS_SEEKWAIT2;
				when MS_SEEKWAIT2 =>
					movestate<=MS_IDLE;
				when others =>
					movestate<=MS_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	intbusy<=	'1' when move='1' else
				'1' when movestate/=MS_IDLE else
				'0';

	sdir<=curdir;
	curtrack<=current;
	seekerr<=seekerrb and not (destset or init);
	busy<=	'1' when destset='1' else
				'1' when init='1' else
				busyb;
end rtl;
				
			
		
		


