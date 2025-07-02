# CPLL reference clock constraint (will be overridden by required constraint on IBUFDS_GTE4 input in context). Needed here as we are not using OOC
# build for GTY4 transceiver. The other MGT clocks are already constrained
# by system.bd build
create_clock -period 6.4 [get_ports USER_MGT_SI570_CLK_P]
create_clock -period 6.4 [get_ports IDT_8A34001_Q7_CLK_P]
create_clock -period 6.4 [get_ports IDT_8A34001_Q11_CLK_P]

# RFDC clocks
# 499.64 MHz
create_clock -period 2.001 [get_ports FPGA_REFCLK_OUT_C_P]
# 1.53 MHz
create_clock -period 652.80 [get_ports SYSREF_FPGA_C_P]

set clk_pl_0_period                   [get_property PERIOD [get_clocks clk_pl_0]]
set clk_mgt_rx_period                 [get_property PERIOD [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]]]
set clk_drp_period                    [get_property PERIOD [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/rfadc_mmcm/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst/CLKOUT0}]]]
set clk_ddr_ui_period                 [get_property PERIOD [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]]]
set clk_adc_dac_period                [get_property PERIOD [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/rfadc_mmcm/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst/CLKOUT0}]]]

#########################################
# Set max delay constraints for clock
# to/from sys with 1 destination clock
# period
#########################################
# Frequency counters
set_max_delay -datapath_only -from [get_clocks RFADC0_CLK] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks RFDAC0_CLK] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks FPGA_REFCLK_OUT_C_P] -to [get_clocks clk_pl_0] $clk_pl_0_period

set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/rfadc_mmcm/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst/CLKOUT0}]] $clk_drp_period
# ADC to Sys clock, status registers
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/rfadc_mmcm/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst/CLKOUT0}]] -to [get_clocks clk_pl_0] $clk_pl_0_period
# DAC to Sys clock, status registers
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/rfadc_mmcm/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst/CLKOUT1}]] -to [get_clocks clk_pl_0] $clk_pl_0_period
# Sys clock to DAC, DPRAM
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/rfadc_mmcm/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst/CLKOUT1}]] $clk_adc_dac_period
# EVR to DAC clock, EVR hearbeat marker
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/rfadc_mmcm/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst/CLKOUT1}]] $clk_adc_dac_period

# Set max delay path between MGT reference clocks O2 and system clock,
# only used at the frequency meter module
set_max_delay -datapath_only -from [get_clocks USER_MGT_SI570_CLK_O2] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks IDT_8A34001_Q7_CLK_O2] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks IDT_8A34001_Q11_CLK_O2] -to [get_clocks clk_pl_0] $clk_pl_0_period

# Set max delay path between SYS clock and RX MGT clock. Crossing domains already
# and with ASYNC_REG properties in RTL.
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]] $clk_mgt_rx_period
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]] -to [get_clocks clk_pl_0] $clk_pl_0_period

# Set max delay path between sys clock and DDR clock,
# only used for monitoring and debug
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]] $clk_ddr_ui_period
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]] -to [get_clocks clk_pl_0] $clk_pl_0_period

# Set max delay path between EVR clock and DDR clock,
# only used for monitoring and debug
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]] $clk_ddr_ui_period
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]] $clk_mgt_rx_period

#########################################
# Don't check timing across clock domains.
#########################################
set_false_path -from [get_clocks SYSREF_FPGA_C_P] -to [get_clocks FPGA_REFCLK_OUT_C_P]
# FPGA_REFCLK_OUT to ADC/DAC clk
set_false_path -from [get_clocks FPGA_REFCLK_OUT_C_P] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/rfadc_mmcm/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst/CLKOUT0}]]
# Set false path between ADC clock and RX MGT clock. Safely crossing domains already
# and with ASYNC_REG properties in RTL.
set_false_path -from [get_clocks clk_out1_system_rfadc_mmcm_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]]
set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]] -to [get_clocks clk_out1_system_rfadc_mmcm_0]
