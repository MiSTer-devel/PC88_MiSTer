derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# The Z80 cores (T80a_ce) step only on CE_R and CE_F. While a CPU runs, two
# of its enables are at least 4 rclk apart (the SDRAM controller's 19-clock
# pattern), so paths from one register to another inside the same CPU get
# 4 clocks. Paths from outside a CPU, and Reset_s (its asynchronous reset),
# keep the default check. The main and the sub CPU are kept apart.
proc pc88_cpu_regs {inst} {
	set regs [get_registers -nowarn {__pc88_no_such_register__}]
	foreach pat [list "$inst|*" "$inst|T80:u0|*" "$inst|T80:u0|T80_Reg:Regs|*"] {
		set c [get_registers -nowarn $pat]
		if {[get_collection_size $c] == 0} {
			post_message -type critical_warning "PC88.sdc: no register matches $pat"
		}
		set regs [add_to_collection $regs $c]
	}
	set rst [get_registers -nowarn "$inst|Reset_s*"]
	if {[get_collection_size $rst] == 0} {
		post_message -type critical_warning "PC88.sdc: no register matches $inst|Reset_s"
	}
	set regs [remove_from_collection $regs $rst]
	post_message -type info "PC88.sdc: $inst: [get_collection_size $regs] registers"
	return $regs
}

foreach inst {
	emu:emu|PC88MiSTer:PC88_top|T80a_ce:CPU
	emu:emu|PC88MiSTer:PC88_top|SUBunitsMiSTer:SUBU|T80a_ce:cpu
} {
	set regs [pc88_cpu_regs $inst]
	set_multicycle_path -setup 4 -from $regs -to $regs
	set_multicycle_path -hold  3 -from $regs -to $regs
}

# Crossings between rclk (75 MHz, general[0]) and clk21m (20 MHz, general[1]).
# Both come from the core PLL, so TimeQuest checks every crossing against the
# closest pair of edges (3.337 ns), even where the RTL already makes the
# crossing safe. Only those are listed here, by name:
#  - the first stage of each cdc_sync2, which takes a single bit and is seen
#    one clock later at worst,
#  - values that cdc_busport, cdc_hs and sdrbridge hold until a synchronized
#    flag has crossed,
#  - the address and data of the ROM loader, held until the write is
#    acknowledged.
# Held values get set_max_delay, not set_false_path, so the limit the RTL
# relies on stays checked. Hold checks are left as they are. Other crossings
# (the MiSTer framework, the F4h settings) are not covered here and still
# show up in the report.
set pc88_rclk  [get_clocks {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set pc88_clk21 [get_clocks {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]

proc pc88_cdc_regs {label patterns} {
	set regs [get_registers -nowarn {__pc88_no_such_register__}]
	foreach pat $patterns {
		set c [get_registers -nowarn $pat]
		if {[get_collection_size $c] == 0} {
			post_message -type critical_warning "PC88.sdc: $label: no register matches $pat"
		}
		set regs [add_to_collection $regs $c]
	}
	post_message -type info "PC88.sdc: $label: [get_collection_size $regs] registers"
	return $regs
}

set pc88_top {emu:emu|PC88MiSTer:PC88_top}
set pc88_sub "$pc88_top|SUBunitsMiSTer:SUBU"

# cdc_sync2: the first stage s1 of each synchronizer whose input is a register
# on the other clock (cdc_sync2.vhd). They are listed by name, so a new one
# stays in the report until it is added here.
set pats {}
foreach s {SINTMs S2INTMs INT0s INT2s INT4s LDROEs LDRWRs LDRACKs FILLDONEs
           FDEREQs FDEACKs FECREQs FECACKs SNDREQs SNDACKs RTCSTBs RTCCKs MSTBs CDIs} {
	lappend pats "$pc88_top|cdc_sync2:$s|s1"
}
foreach p [list "$pc88_sub|cdc_sync2:MON0Ss" "$pc88_sub|cdc_sync2:MON1Ss" \
	"$pc88_top|singspk:sings|cdc_sync2:sings" "$pc88_top|singspk:sings|cdc_sync2:beepens"] {
	lappend pats "$p|s1"
}
foreach p [list "$pc88_top|mainport:MP|cdc_busport:port0" "$pc88_sub|fdcport:FDP|cdc_busport:port0" \
	"$pc88_sub|fdcport:FDP|cdc_hs:ints" "$pc88_sub|fdcport:FDP|cdc_hs:tcs" \
	"$pc88_top|kbmirror:KBM|cdc_hs:rows" "$pc88_top|cdc_hs:CFGX" "$pc88_top|cdc_hs:FILLCMD"] {
	lappend pats "$p|cdc_sync2:reqs|s1" "$p|cdc_sync2:acks|s1"
}
set regs [pc88_cdc_regs "cdc_sync2 s1" $pats]
set_max_delay -from $pc88_rclk  -to $regs 13.333
set_max_delay -from $pc88_clk21 -to $regs 13.333

# cdc_busport: the held access must reach the device side within one clk21m
# clock, and rhold must reach rdatb within two rclk clocks (cdc_busport.vhd).
# With FAST the device side uses the held registers directly, inside the
# sound chips and the 8251, so it is not named.
foreach p [list "$pc88_top|mainport:MP|cdc_busport:port0" "$pc88_sub|fdcport:FDP|cdc_busport:port0"] {
	set held [pc88_cdc_regs "$p held" [list "$p|hrd" "$p|hadrb\[*\]" "$p|hwd\[*\]"]]
	set_max_delay -from $held -to $pc88_clk21 50.000
	set_max_delay -from [pc88_cdc_regs "$p rhold" [list "$p|rhold\[*\]"]] \
	              -to   [pc88_cdc_regs "$p rdatb" [list "$p|rdatb\[*\]"]] 26.666
}

# cdc_hs from clk21m to rclk: a_hold must reach b_datab within two rclk clocks
# plus one clk21m clock (cdc_hs.vhd); two rclk clocks are used.
foreach h [list "$pc88_top|kbmirror:KBM|cdc_hs:rows" "$pc88_top|cdc_hs:CFGX" "$pc88_top|cdc_hs:FILLCMD"] {
	set_max_delay -from [pc88_cdc_regs "$h a_hold"  [list "$h|a_hold\[*\]"]] \
	              -to   [pc88_cdc_regs "$h b_datab" [list "$h|b_datab\[*\]"]] 26.666
}

# sdrbridge (disk emulation, FEC buffer, ADPCM-B RAM): address, data and kind
# are held from one clk21m clock before REQ until ACK comes back, and the SDRAM
# controller takes them after it has seen REQ. Read data is registered one
# rclk clock before ACK and taken after ACK has crossed (sdrbridge.vhd).
set pc88_ram "$pc88_top|SDRAMCde0cvDEMU2:RAM"
foreach {b c} {FDEB FDE FECB FEC SNDB SND} {
	set_max_delay -from [pc88_cdc_regs "$b held" [list "$pc88_top|sdrbridge:$b|ADRb\[*\]" "$pc88_top|sdrbridge:$b|WDATb\[*\]" "$pc88_top|sdrbridge:$b|WRb"]] \
	              -to   [pc88_cdc_regs "$c take" [list "$pc88_ram|${c}ADRb\[*\]" "$pc88_ram|${c}WDATb\[*\]" "$pc88_ram|${c}JOB\[*\]"]] 26.666
	set_max_delay -from [pc88_cdc_regs "$c read"  [list "$pc88_ram|${c}RDAT\[*\]"]] \
	              -to   [pc88_cdc_regs "$b RDATb" [list "$pc88_top|sdrbridge:$b|RDATb\[*\]"]] 50.000
}

# ROM loader (the first download after the core is loaded, boot.rom; ldr_done
# keeps later downloads out): ldr_addr and ldr_dout are taken on the clk21m
# clock that raises ldr_wr, and ldr_wr holds the HPS through ioctl_wait until
# the write is acknowledged (PC8801SR.sv).
# rclk writes them only after ldr_wr has passed cdc_sync2, two rclk clocks later
# at the earliest; one rclk clock is used. The destinations are named by
# instance, since the names inside the inferred RAMs change between builds.
set ldr [pc88_cdc_regs "loader" [list "emu:emu|ldr_addr\[*\]" "emu:emu|ldr_dout\[*\]"]]
set ldr_take [pc88_cdc_regs "loader take" [list \
	"$pc88_top|SUBMEM:SUBM|*" "$pc88_top|CRTCP:CRT|fontram:GFNT|*" "$pc88_top|CRTCP:CRT|font8ram:FNT8|*" \
	"$pc88_ram|CPUADRb\[*\]" "$pc88_ram|CPUWDATb\[*\]" \
	"$pc88_top|WRPOST:WRP|padr\[*\]" "$pc88_top|WRPOST:WRP|pdat\[*\]"]]
set_max_delay -from $ldr -to $ldr_take 13.333

# Reset synchronizers: srstn21 (clk21m) from srstn, CPU_rstnr and the sub CPU's
# CPUrstnr (rclk) from CPU_rstn and srstn21. The reset clears both stages
# directly and is released through them: the first stage takes '1' and the
# second takes the first, so only their clear inputs see the other clock
# (PC88MiSTer.vhd, SUBunitsMiSTer.vhd). A release that misses a clock is seen
# one clock later; one rclk clock is used. Removal checks are left as they are.
foreach {s d} [list \
	"$pc88_top|srstn" "$pc88_top|srstn21m $pc88_top|srstn21" \
	"$pc88_top|CPU_rstn" "$pc88_top|CPU_rstnrm $pc88_top|CPU_rstnr" \
	"$pc88_top|CPU_rstn $pc88_top|srstn21" "$pc88_sub|CPUrstnrm $pc88_sub|CPUrstnr"] {
	set_max_delay -from [pc88_cdc_regs "reset from" $s] -to [pc88_cdc_regs "reset to" $d] 13.333
}
