LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity FECcont is
generic(
	SDRAWIDTH	:integer	:=22
);
port(
	HIGHADDR	:in std_logic_vector(15 downto 0);
	BUFADDR		:out std_logic_vector(7 downto 0);
	RD			:in std_logic;
	WR			:in std_logic;
	RDDAT		:out std_logic_vector(15 downto 0);
	WRDAT		:in std_logic_vector(15 downto 0);
	BUFRD		:out std_logic;
	BUFWR		:out std_logic;
	BUFWAIT		:in std_logic;
	BUSY		:out std_logic;
	
	SDR_ADDR	:out std_logic_vector(SDRAWIDTH-1 downto 0);
	SDR_RD		:out std_logic;
	SDR_WR		:out std_logic;
	SDR_RDAT	:in std_logic_vector(15 downto 0);
	SDR_WDAT	:out std_logic_vector(15 downto 0);
	SDR_WAIT	:in std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end FECcont;

architecture rtl of FECcont is
signal	CURADDR	:std_logic_vector(7 downto 0);
type state_t is(
	st_IDLE,
	st_READ,
	st_WRITE
);
signal state	:state_t;
type intstate_t is(
	is_RD,
	is_WR,
	is_NEXT
);
signal	intstate	:intstate_t;

begin

	BUSY<=	'1' when RD='1' else
			'1' when WR='1' else
			'1' when state=st_READ else
			'1' when state=st_WRITE else
			'0';
	
	SDR_ADDR<=HIGHADDR(SDRAWIDTH-9 downto 0) & CURADDR;
	BUFADDR<=CURADDR;
	
	RDDAT<=SDR_RDAT;
	SDR_WDAT<=WRDAT;
	
	process(clk,rstn)
	variable mwait	:integer range 0 to 3;
	begin
		if(rstn='0')then
			CURADDR<=(others=>'0');
			state<=st_IDLE;
			SDR_RD<='0';
			SDR_WR<='0';
			BUFRD<='0';
			BUFWR<='0';
			mwait:=0;
		elsif(clk' event and clk='1')then
			if(mwait/=0)then
				mwait:=mwait-1;
			else
				case state is
				when st_IDLE =>
					if(RD='1')then
						CURADDR<=(others=>'0');
						intstate<=is_RD;
						SDR_RD<='1';
						state<=st_READ;
						mwait:=1;
					elsif(WR='1')then
						CURADDR<=(others=>'0');
						intstate<=is_RD;
						BUFRD<='1';
						state<=st_WRITE;
						mwait:=1;
					end if;
					
				when st_READ =>
					case intstate is
					when is_RD =>
						if(SDR_WAIT='0')then
							BUFWR<='1';
							intstate<=is_WR;
							mwait:=1;
						end if;
					when is_WR =>
						if(BUFWAIT='0')then
							SDR_RD<='0';
							BUFWR<='0';
							intstate<=is_NEXT;
						end if;
					when is_NEXT =>
						if(CURADDR/=x"ff")then
							CURADDR<=CURADDR+x"01";
							intstate<=is_RD;
							SDR_RD<='1';
							mwait:=1;
						else
							state<=st_IDLE;
						end if;
					when others =>
						state<=st_IDLE;
					end case;
				when st_WRITE =>
					case intstate is
					when is_RD =>
						if(BUFWAIT='0')then
							SDR_WR<='1';
							intstate<=is_WR;
							mwait:=1;
						end if;
					when is_WR =>
						if(SDR_WAIT='0')then
							SDR_WR<='0';
							BUFRD<='0';
							intstate<=is_NEXT;
						end if;
					when is_NEXT =>
						if(CURADDR/=x"ff")then
							CURADDR<=CURADDR+x"01";
							intstate<=is_RD;
							BUFRD<='1';
							mwait:=1;
						else
							state<=st_IDLE;
						end if;
					when others =>
						state<=st_IDLE;
					end case;
				when others =>
					state<=st_IDLE;
				end case;
			end if;
		end if;
	end process;
	
end rtl;
