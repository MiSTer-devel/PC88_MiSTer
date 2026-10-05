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
