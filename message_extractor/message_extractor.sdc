create_clock -period 20 [get_ports ref_clk]

derive_pll_clocks
derive_clock_uncertainty

set_input_delay  0 -clock [get_clocks inst|pll_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]] [remove_from_collection [all_inputs] [get_ports ref_clk]]
set_output_delay 0 -clock [get_clocks inst|pll_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]] [all_outputs]
