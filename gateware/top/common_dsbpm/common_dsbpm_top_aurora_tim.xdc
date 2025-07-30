# Override LOC properties of CCW and CW due to OOC setting the aurora MGT cores
# to the same physical location

# CCW
set_property LOC GTYE4_CHANNEL_X0Y4 [get_cells -hierarchical -filter {NAME =~ *auroraCellCommCCW*gen_channel_container[1].*gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST}]

# CW
set_property LOC GTYE4_CHANNEL_X0Y5 [get_cells -hierarchical -filter {NAME =~ *auroraCellCommCW*gen_channel_container[1].*gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST}]

#########################################
# Set max delay constraints for clock
# to/from sys with 1 destination clock
# period
#########################################

# Aurora clock periods

set clk_auroraCCW_period            [get_property PERIOD [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *cellComm/cellCommAuroraCore/auroraCellCommCCW*RXOUTCLK}]]]
set clk_auroraCW_period             [get_property PERIOD [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *cellComm/cellCommAuroraCore/auroraCellCommCW*RXOUTCLK}]]]

set clk_aurora_sync_period          [get_property PERIOD [get_clocks sync_clk_i]]
set clk_aurora_user_period          [get_property PERIOD [get_clocks user_clk_i]]

# Aurora CCW TX Clock and System clock

set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *cellComm/cellCommAuroraCore/auroraCellCommCCW*TXOUTCLK}]] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *cellComm/cellCommAuroraCore/auroraCellCommCCW*TXOUTCLK}]] $clk_auroraCCW_period

# Aurora RX Clocks and System clock

set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *cellComm/cellCommAuroraCore/auroraCellCommCCW*RXOUTCLK}]] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *cellComm/cellCommAuroraCore/auroraCellCommCCW*RXOUTCLK}]] $clk_auroraCCW_period

set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *cellComm/cellCommAuroraCore/auroraCellCommCW*RXOUTCLK}]] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *cellComm/cellCommAuroraCore/auroraCellCommCW*RXOUTCLK}]] $clk_auroraCW_period

# Aurora MMCM Clocks and System clock

set_max_delay -datapath_only -from [get_clocks sync_clk_i] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks sync_clk_i] $clk_aurora_sync_period

set_max_delay -datapath_only -from [get_clocks user_clk_i] -to [get_clocks clk_pl_0] $clk_pl_0_period
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks user_clk_i] $clk_aurora_user_period
