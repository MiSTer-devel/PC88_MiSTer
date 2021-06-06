LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity GraphALU is
port(
	CS		:in std_logic;
	RDn		:in std_logic;
	RDDAT0	:in std_logic_vector(7 downto 0);
	RDDAT1	:in std_logic_vector(7 downto 0);
	RDDAT2	:in std_logic_vector(7 downto 0);
	
	WRDAT0	:out std_logic_vector(7 downto 0);
	WRDAT1	:out std_logic_vector(7 downto 0);
	WRDAT2	:out std_logic_vector(7 downto 0);
	WEBIT	:out std_logic_vector(2 downto 0);
	
	CPUWD	:in std_logic_vector(7 downto 0);
	CPURD	:out std_logic_vector(7 downto 0);
	
	ALU0	:in std_logic_vector(1 downto 0);
	ALU1	:in std_logic_vector(1 downto 0);
	ALU2	:in std_logic_vector(1 downto 0);
	
	GDM		:in std_logic_vector(1 downto 0);
	
	PLN		:in std_logic_vector(2 downto 0);

	GVAM	:in std_logic;
	GAM		:in std_logic;
	NSEL	:in integer range 0 to 3;

	clk		:in std_logic;
	rstn	:in std_logic
);
end GraphALU;

architecture MAIN of GraphALU is
signal	LASTD0	:std_logic_vector(7 downto 0);
signal	LASTD1	:std_logic_vector(7 downto 0);
signal	LASTD2	:std_logic_vector(7 downto 0);
begin
	
	process(clk,rstn)begin
		if(rstn='0')then
			LASTD0<=(others=>'0');
			LASTD1<=(others=>'0');
			LASTD2<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(CS='1' and RDn='0')then
				LASTD0<=RDDAT0;
				LASTD1<=RDDAT1;
				LASTD2<=RDDAT2;
			end if;
		end if;
	end process;
	
	process(GVAM,GDM,ALU0,ALU1,ALU2,RDDAT0,RDDAT1,RDDAT2,LASTD0,LASTD1,LASTD2,CPUWD)begin
		if(GVAM='1')then
			case GDM is
			when "00" =>
				case ALU0 is
				when "00" =>
					WRDAT0<=RDDAT0 and (not CPUWD);
				when "01" =>
					WRDAT0<=RDDAT0 or CPUWD;
				when "10" =>
					WRDAT0<=RDDAT0 xor CPUWD;
				when others =>
					WRDAT0<=RDDAT0;
				end case;
			
				case ALU1 is
				when "00" =>
					WRDAT1<=RDDAT1 and (not CPUWD);
				when "01" =>
					WRDAT1<=RDDAT1 or CPUWD;
				when "10" =>
					WRDAT1<=RDDAT1 xor CPUWD;
				when others =>
					WRDAT1<=RDDAT1;
				end case;
			
				case ALU2 is
				when "00" =>
					WRDAT2<=RDDAT2 and (not CPUWD);
				when "01" =>
					WRDAT2<=RDDAT2 or CPUWD;
				when "10" =>
					WRDAT2<=RDDAT2 xor CPUWD;
				when others =>
					WRDAT2<=RDDAT2;
				end case;
			
			when "01" =>
				WRDAT0<=LASTD0;
				WRDAT1<=LASTD1;
				WRDAT2<=LASTD2;
			when "10" =>
				WRDAT0<=LASTD1;
				WRDAT1<=RDDAT1;
				WRDAT2<=RDDAT2;
			when others=>
				WRDAT0<=RDDAT1;
				WRDAT1<=LASTD0;
				WRDAT2<=RDDAT2;
			end case;
		else
			WRDAT0<=CPUWD;
			WRDAT1<=CPUWD;
			WRDAT2<=CPUWD;
		end if;
	end process;
	
	WEBIT(0)<=	'1' when GVAM='1' and GAM='1' else
				'1' when GVAM='0' and NSEL=0 else
				'0';
	WEBIT(1)<=	'1' when GVAM='1' and GAM='1' else
				'1' when GVAM='0' and NSEL=1 else
				'0';
	WEBIT(2)<=	'1' when GVAM='1' and GAM='1' else
				'1' when GVAM='0' and NSEL=2 else
				'0';
	
	process(RDDAT0,RDDAT1,RDDAT2,PLN)
	variable MDAT0,MDAT1,MDAT2	:std_logic_vector(7 downto 0);
	begin
		for i in 0 to 7 loop
			MDAT0(i):=(not PLN(0)) xor RDDAT0(i);
			MDAT1(i):=(not PLN(1)) xor RDDAT1(i);
			MDAT2(i):=(not PLN(2)) xor RDDAT2(i);
		end loop;
		CPURD<=MDAT0 and MDAT1 and MDAT2;
	end process;

end MAIN;
