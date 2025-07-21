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
