# SI570 C0 clock. 300 MHz
create_clock -period 3.334 [get_ports SYS_CLK_C0_P]

# DDR clock
set clk_ddr_ui_period                 [get_property PERIOD [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *system_i/ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]]]

## These signals once asserted, stays asserted for multiple clock cycles.

## False path constraint is added to improve the HOLD timing.
set_false_path -hold -to [get_pins -hier -filter {NAME =~ *ddr4_0*/*/*/*/*/*/*.u_xiphy_control/xiphy_control/RIU_ADDR*}]
set_false_path -hold -to [get_pins -hier -filter {NAME =~ *ddr4_0*/*/*/*/*/*/*.u_xiphy_control/xiphy_control/RIU_WR_DATA*}]

set_property SLEW FAST  [ \
    get_ports { \
        DDR4_C0_ADR[*] \
        DDR4_C0_ACT_N \
        DDR4_C0_BA[*] \
        DDR4_C0_BG[*] \
        DDR4_C0_CKE \
        DDR4_C0_CK_T \
        DDR4_C0_CK_C \
        DDR4_C0_ODT \
        DDR4_C0_DQ[*] \
        DDR4_C0_DQS_T[*] \
        DDR4_C0_DQS_C[*] \
    } \
]
set_property IBUF_LOW_PWR FALSE  [ \
    get_ports { \
        DDR4_C0_DQ[*] \
        DDR4_C0_DQS_T[*] \
        DDR4_C0_DQS_C[*] \
    } \
]
set_property ODT RTT_40  [ \
    get_ports { \
        DDR4_C0_DQ[*] \
        DDR4_C0_DQS_T[*] \
        DDR4_C0_DQS_C[*] \
    } \
]
set_property EQUALIZATION EQ_LEVEL2 [ \
    get_ports { \
        DDR4_C0_DQ[*] \
        DDR4_C0_DQS_T[*] \
        DDR4_C0_DQS_C[*] \
    } \
]
set_property PRE_EMPHASIS RDRV_240 [ \
    get_ports { \
        DDR4_C0_DQ[*] \
        DDR4_C0_DQS_T[*] \
        DDR4_C0_DQS_C[*] \
    } \
]
set_property SLEW FAST              [get_ports {DDR4_C0_CS_N[*]}]
set_property DATA_RATE SDR          [get_ports {DDR4_C0_CS_N[*]}]
set_property SLEW FAST              [get_ports {DDR4_C0_DM_DBI_N[*]}]
set_property IBUF_LOW_PWR FALSE     [get_ports {DDR4_C0_DM_DBI_N[*]}]
set_property ODT RTT_40             [get_ports {DDR4_C0_DM_DBI_N[*]}]
set_property EQUALIZATION EQ_LEVEL2 [get_ports {DDR4_C0_DM_DBI_N[*]}]
set_property PRE_EMPHASIS RDRV_240  [get_ports {DDR4_C0_DM_DBI_N[*]}]
set_property DATA_RATE DDR          [get_ports {DDR4_C0_DM_DBI_N[*]}]
set_property DATA_RATE SDR          [ \
    get_ports { \
        DDR4_C0_ADR[*] \
        DDR4_C0_ACT_N \
        DDR4_C0_BA[*] \
        DDR4_C0_BG[*] \
        DDR4_C0_CKE \
        DDR4_C0_ODT \
    } \
]
set_property DATA_RATE DDR          [ \
    get_ports { \
        DDR4_C0_DQ[*] \
        DDR4_C0_DQS_T[*] \
        DDR4_C0_DQS_C[*] \
        DDR4_C0_CK_T \
        DDR4_C0_CK_C \
    } \
]

## Multi-cycle path constraints for Fabric - RIU clock domain crossing signals
set_max_delay 5.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/u_ddr_cal_addr_decode/io_ready_lvl_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_io_ready_lvl_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 5.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/u_ddr_cal_addr_decode/io_read_data_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_io_read_data_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/phy_ready_riuclk_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_phy2clb_phy_ready_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/bisc_complete_riuclk_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_phy2clb_bisc_complete_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/io_addr_strobe_lvl_riuclk_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_io_addr_strobe_lvl_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/io_write_strobe_riuclk_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_io_write_strobe_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/io_address_riuclk_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_io_addr_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/io_write_data_riuclk_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_io_write_data_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 10.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/en_vtc_in_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_en_vtc_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 10.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/riu2clb_valid_r1_riuclk_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_riu2clb_valid_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 10.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/phy2clb_fixdly_rdy_low_riuclk_int_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_phy2clb_fixdly_rdy_low/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 10.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/phy2clb_fixdly_rdy_upp_riuclk_int_reg[*]/C \
     } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_phy2clb_fixdly_rdy_upp/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 10.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/phy2clb_phy_rdy_low_riuclk_int_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_phy2clb_phy_rdy_low/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 10.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/phy2clb_phy_rdy_upp_riuclk_int_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_phy2clb_phy_rdy_upp/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 10.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_r1_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/u_fab_rst_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/clb2phy_t_b_addr_riuclk_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/clb2phy_t_b_addr_i_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/slave_en_lvl_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/u_slave_en_sync/SYNC[*].sync_reg_reg[0]/D
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/slave_we_r_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/u_slave_we_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/slave_addr_r_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/u_slave_addr_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/slave_di_r_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/u_slave_di_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 3.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/slave_rdy_cptd_sclk_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/u_slave_rdy_cptd_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 12.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/slave_rdy_lvl_fclk_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/u_slave_rdy_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]
set_max_delay 12.0 -datapath_only -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/slave_do_fclk_reg[*]/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/*/*/*/u_slave_do_sync/SYNC[*].sync_reg_reg[0]/D \
    } \
]

# False paths
set_false_path -through [get_pins -hier -filter {NAME =~ *ddr4_0*/u_ddr4_infrastructure/sys_rst}]
set_false_path -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/input_rst_design_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_div_sync_r_reg[0]/D \
    } \
]
set_false_path -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/input_rst_design_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_riu_sync_r_reg[0]/D \
    } \
]
set_false_path -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/input_rst_design_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_mb_sync_r_reg[0]/D \
    } \
]
set_false_path -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_async_riu_div_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_div_sync_r_reg[0]/D \
    } \
]
set_false_path -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_async_mb_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_mb_sync_r_reg[0]/D \
    } \
]
set_false_path -from [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_async_riu_div_reg/C \
    } \
] -to [ \
    get_pins -hier -filter { \
        NAME =~ *ddr4_0*/*/rst_riu_sync_r_reg[0]/D \
    } \
]

# Set max delay path between sys clock and DDR clock,
# only used for monitoring and debug
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]] $clk_ddr_ui_period
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]] -to [get_clocks clk_pl_0] $clk_pl_0_period

# Set max delay path between EVR clock and DDR clock,
# only used for monitoring and debug
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]] $clk_ddr_ui_period
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *ddr4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST_1}]] $clk_mgt_rx_period

# Ignore warnings
create_waiver -internal -user DDR4 -tags "1010162" -scope -type METHODOLOGY -id CLKC-55 -description "Clocking Primitives will be Auto-Placed" -objects [ \
    get_cells -hierarchical "*gen_mmcme*.u_mmcme_adv_inst*" -filter {NAME =~ *ddr4_0*/*inst/u_ddr4_infrastructure*}]
create_waiver -internal -user DDR4 -tags "1010162" -scope -type METHODOLOGY -id CLKC-56 -description "Clocking Primitives will be Auto-Placed" -objects [ \
    get_cells -hierarchical "*gen_mmcme*.u_mmcme_adv_inst*" -filter {NAME =~ *ddr4_0*/*inst/u_ddr4_infrastructure*}]
create_waiver -internal -user DDR4 -tags "1010162" -scope -type METHODOLOGY -id CLKC-57 -description "Clocking Primitives will be Auto-Placed" -objects [ \
    get_cells -hierarchical "*plle_loop[*].gen_plle*.PLLE*_BASE_INST_OTHER*" -filter {NAME =~ *ddr4_0*/*inst/u_ddr4_phy_pll*}]
create_waiver -internal -user DDR4 -tags "1010162" -scope -type METHODOLOGY -id CLKC-58 -description "Clocking Primitives will be Auto-Placed" -objects [ \
    get_cells -hierarchical "*plle_loop[*].gen_plle*.PLLE*_BASE_INST_OTHER*" -filter {NAME =~ *ddr4_0*/*inst/u_ddr4_phy_pll*}]
create_waiver -internal -user DDR4 -tags "1010162" -scope -type METHODOLOGY -id CLKC-40 -description "MMCM is driven through a BUFGCE" -objects [ \
    get_cells -hierarchical "*gen_mmcme*.u_mmcme_adv_inst*" -filter {NAME =~ *ddr4_0*/*inst/u_ddr4_infrastructure*}]
