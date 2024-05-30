# SFPs - MGT 129 - zSFP 2
set_property PACKAGE_PIN N38        [get_ports SFP2_RX_P]
set_property PACKAGE_PIN N39        [get_ports SFP2_RX_N]
set_property PACKAGE_PIN P35        [get_ports SFP2_TX_P]
set_property PACKAGE_PIN P36        [get_ports SFP2_TX_N]
set_property PACKAGE_PIN AP18       [get_ports SFP2_TX_ENABLE]
set_property IOSTANDARD LVCMOS12    [get_ports SFP2_TX_ENABLE]

# USER_MGT_SI570
set_property PACKAGE_PIN M32        [get_ports USER_MGT_SI570_CLK_N]
set_property PACKAGE_PIN M31        [get_ports USER_MGT_SI570_CLK_P]

# User DIP switch
set_property PACKAGE_PIN M18        [get_ports {DIP_SWITCH[0]}]
set_property PACKAGE_PIN L14        [get_ports {DIP_SWITCH[1]}]
set_property PACKAGE_PIN AF15       [get_ports {DIP_SWITCH[2]}]
set_property PACKAGE_PIN AP15       [get_ports {DIP_SWITCH[3]}]
set_property PACKAGE_PIN N21        [get_ports {DIP_SWITCH[4]}]
set_property PACKAGE_PIN N20        [get_ports {DIP_SWITCH[5]}]
set_property PACKAGE_PIN AW5        [get_ports {DIP_SWITCH[6]}]
set_property PACKAGE_PIN AW6        [get_ports {DIP_SWITCH[7]}]
set_property IOSTANDARD LVCMOS12    [get_ports {DIP_SWITCH[0]}]
set_property IOSTANDARD LVCMOS12    [get_ports {DIP_SWITCH[1]}]
set_property IOSTANDARD LVCMOS18    [get_ports {DIP_SWITCH[2]}]
set_property IOSTANDARD LVCMOS18    [get_ports {DIP_SWITCH[3]}]
set_property IOSTANDARD LVCMOS18    [get_ports {DIP_SWITCH[4]}]
set_property IOSTANDARD LVCMOS18    [get_ports {DIP_SWITCH[5]}]
set_property IOSTANDARD LVCMOS18    [get_ports {DIP_SWITCH[6]}]
set_property IOSTANDARD LVCMOS18    [get_ports {DIP_SWITCH[7]}]

# Analog signal conditioning card
# ADCIO_00
set_property PACKAGE_PIN AP5        [get_ports {AFE_SPI_CLK[0]}]
# ADCIO_01
set_property PACKAGE_PIN AP6        [get_ports {AFE_SPI_SDI[0]}]
# ADCIO_02
set_property PACKAGE_PIN AR6        [get_ports {AFE_SPI_LE[0]}]
# ADCIO_03
set_property PACKAGE_PIN AR7        [get_ports {AFE_SPI_CLK[1]}]
# ADCIO_04
set_property PACKAGE_PIN AV7        [get_ports {AFE_SPI_SDI[1]}]
# ADCIO_05
set_property PACKAGE_PIN AU7        [get_ports {AFE_SPI_LE[1]}]

set_property IOSTANDARD LVCMOS18    [get_ports {AFE_SPI_CLK[0]}]
set_property IOSTANDARD LVCMOS18    [get_ports {AFE_SPI_SDI[0]}]
set_property IOSTANDARD LVCMOS18    [get_ports {AFE_SPI_LE[0]}]
set_property IOSTANDARD LVCMOS18    [get_ports {AFE_SPI_CLK[1]}]
set_property IOSTANDARD LVCMOS18    [get_ports {AFE_SPI_SDI[1]}]
set_property IOSTANDARD LVCMOS18    [get_ports {AFE_SPI_LE[1]}]

set_property DRIVE 4 [get_ports {AFE_SPI_CLK[0]}]
set_property DRIVE 4 [get_ports {AFE_SPI_SDI[0]}]
set_property DRIVE 4 [get_ports {AFE_SPI_LE[0]}]
set_property DRIVE 4 [get_ports {AFE_SPI_CLK[1]}]
set_property DRIVE 4 [get_ports {AFE_SPI_SDI[1]}]
set_property DRIVE 4 [get_ports {AFE_SPI_LE[1]}]

# Analog signal conditioning card
# ADCIO_08
set_property PACKAGE_PIN AT6        [get_ports EVR_SROC]
set_property IOSTANDARD LVCMOS18    [get_ports EVR_SROC]

# User push buttons
set_property PACKAGE_PIN L22 [get_ports GPIO_SW_W]
set_property PACKAGE_PIN G24 [get_ports GPIO_SW_E]
set_property PACKAGE_PIN D20 [get_ports GPIO_SW_N]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_SW_W]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_SW_E]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_SW_N]

# GPIO LEDs
set_property PACKAGE_PIN AR19 [get_ports {GPIO_LEDS[0]}]
set_property PACKAGE_PIN AT17 [get_ports {GPIO_LEDS[1]}]
set_property PACKAGE_PIN AR17 [get_ports {GPIO_LEDS[2]}]
set_property PACKAGE_PIN AU19 [get_ports {GPIO_LEDS[3]}]
set_property PACKAGE_PIN AU20 [get_ports {GPIO_LEDS[4]}]
set_property PACKAGE_PIN AW21 [get_ports {GPIO_LEDS[5]}]
set_property PACKAGE_PIN AV21 [get_ports {GPIO_LEDS[6]}]
set_property PACKAGE_PIN AV17 [get_ports {GPIO_LEDS[7]}]
set_property IOSTANDARD LVCMOS12 [get_ports {GPIO_LEDS[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports {GPIO_LEDS[1]}]
set_property IOSTANDARD LVCMOS12 [get_ports {GPIO_LEDS[2]}]
set_property IOSTANDARD LVCMOS12 [get_ports {GPIO_LEDS[3]}]
set_property IOSTANDARD LVCMOS12 [get_ports {GPIO_LEDS[4]}]
set_property IOSTANDARD LVCMOS12 [get_ports {GPIO_LEDS[5]}]
set_property IOSTANDARD LVCMOS12 [get_ports {GPIO_LEDS[6]}]
set_property IOSTANDARD LVCMOS12 [get_ports {GPIO_LEDS[7]}]

# SPI Mux Selection
set_property PACKAGE_PIN C11       [get_ports CLK_SPI_MUX_SEL0]
set_property PACKAGE_PIN B12       [get_ports CLK_SPI_MUX_SEL1]
set_property IOSTANDARD LVCMOS12   [get_ports CLK_SPI_MUX_SEL0]
set_property IOSTANDARD LVCMOS12   [get_ports CLK_SPI_MUX_SEL1]

# EVR recovered clock output. To CLK104 board
# Bank 67
set_property PACKAGE_PIN L21  [get_ports SFP_REC_CLK_N]
set_property PACKAGE_PIN M20  [get_ports SFP_REC_CLK_P]
set_property IOSTANDARD  LVDS [get_ports SFP_REC_CLK_N]
set_property IOSTANDARD  LVDS [get_ports SFP_REC_CLK_P]

# DACIO_00
set_property PACKAGE_PIN A9       [get_ports EVR_FB_CLK]
set_property IOSTANDARD  LVCMOS18 [get_ports EVR_FB_CLK]

# Note on LVDS_25 used on a 1.8V bank:
#
# There is not a specific requirement on the
# VCCO bank voltage on LVDS_25 inputs provided
# the VCCO level is high enough to ensure the
# pin voltage aligns to the Vin spec in the
# Recommended Operating Conditions table of the
# specific UltraScale+ device data sheet

# Jitter cleaner monitoring
# Assume ALS-U AR/SR RF (125.0980659 MHz)
# PL_SYSREF_P - Bank  87 VCCO - VCC1V8   - IO_L8P_HDGC_87
set_property PACKAGE_PIN B10     [get_ports SYSREF_FPGA_C_P]
# PL_SYSREF_N - Bank  87 VCCO - VCC1V8   - IO_L8N_HDGC_87
set_property PACKAGE_PIN B9      [get_ports SYSREF_FPGA_C_N]
set_property IOSTANDARD LVDS_25  [get_ports SYSREF_FPGA_C_P]
set_property IOSTANDARD LVDS_25  [get_ports SYSREF_FPGA_C_N]

# PL_CLK_P - Bank  87 VCCO - VCC1V8   - IO_L7P_HDGC_87
set_property PACKAGE_PIN B8     [get_ports FPGA_REFCLK_OUT_C_P]
# PL_CLK_N - Bank  87 VCCO - VCC1V8   - IO_L7N_HDGC_87
set_property PACKAGE_PIN B7     [get_ports FPGA_REFCLK_OUT_C_N]
set_property IOSTANDARD LVDS_25 [get_ports FPGA_REFCLK_OUT_C_P]
set_property IOSTANDARD LVDS_25 [get_ports FPGA_REFCLK_OUT_C_N]

# As we are using a HDGC pin to drive BUFG -> MMCM, we need
# to use a sub-optimal path in the ZU48. ug572-ultrascale-clocking
# page 10: "Therefore, clocks that are connected to an HDGC pin
# can only connect to MMCMs/PLLs through the BUFGCEs. To avoid
# a design rule check (DRC) error, set the property
# CLOCK_DEDICATED_ROUTE = FALSE."
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets                    FPGA_REFCLK_OUT_C]

# RFDC SYSREF
# AMS_SYSREF_P - CLK104_AMS_SYSREF_C_P     Bank 228 - SYSREF_P_228
set_property PACKAGE_PIN U5 [get_ports SYSREF_RFSOC_C_P]
# AMS_SYSREF_N - CLK104_AMS_SYSREF_C_N     Bank 228 - SYSREF_N_228
set_property PACKAGE_PIN U4 [get_ports SYSREF_RFSOC_C_N]
# set_property IOSTANDARD LVDS [get_ports SYSREF_RFSOC_C_P]
# set_property DIFF_TERM_ADV TERM_100 [get_ports SYSREF_RFSOC_C_P]

# All ADCs are clocked from the 225

# RF ADC tile 224
set_property PACKAGE_PIN AP1 [get_ports RFMC_ADC_00_N]
set_property PACKAGE_PIN AP2 [get_ports RFMC_ADC_00_P]
set_property PACKAGE_PIN AM1 [get_ports RFMC_ADC_01_N]
set_property PACKAGE_PIN AM2 [get_ports RFMC_ADC_01_P]

# RF ADC tile 225
# ADC_CLK_225_N - Bank 225 - ADC_CLK_N_225
set_property PACKAGE_PIN AD4 [get_ports RF1_CLKO_B_C_N]
# ADC_CLK_225_P - Bank 225 - ADC_CLK_P_225
set_property PACKAGE_PIN AD5 [get_ports RF1_CLKO_B_C_P]
set_property PACKAGE_PIN AK1 [get_ports RFMC_ADC_02_N]
set_property PACKAGE_PIN AK2 [get_ports RFMC_ADC_02_P]
set_property PACKAGE_PIN AH1 [get_ports RFMC_ADC_03_N]
set_property PACKAGE_PIN AH2 [get_ports RFMC_ADC_03_P]

# RF ADC tile 226
set_property PACKAGE_PIN AF1 [get_ports RFMC_ADC_04_N]
set_property PACKAGE_PIN AF2 [get_ports RFMC_ADC_04_P]
set_property PACKAGE_PIN AD1 [get_ports RFMC_ADC_05_N]
set_property PACKAGE_PIN AD2 [get_ports RFMC_ADC_05_P]

# RF ADC tile 227
set_property PACKAGE_PIN AB1 [get_ports RFMC_ADC_06_N]
set_property PACKAGE_PIN AB2 [get_ports RFMC_ADC_06_P]
set_property PACKAGE_PIN Y1 [get_ports RFMC_ADC_07_N]
set_property PACKAGE_PIN Y2 [get_ports RFMC_ADC_07_P]

# All DACs are clocked from the 230

# RF DAC tile 228
set_property PACKAGE_PIN U1 [get_ports RFMC_DAC_00_N]
set_property PACKAGE_PIN U2 [get_ports RFMC_DAC_00_P]
set_property PACKAGE_PIN R1 [get_ports RFMC_DAC_01_N]
set_property PACKAGE_PIN R2 [get_ports RFMC_DAC_01_P]

# RF DAC tile 229
set_property PACKAGE_PIN N1 [get_ports RFMC_DAC_02_N]
set_property PACKAGE_PIN N2 [get_ports RFMC_DAC_02_P]
set_property PACKAGE_PIN L1 [get_ports RFMC_DAC_03_N]
set_property PACKAGE_PIN L2 [get_ports RFMC_DAC_03_P]

# RF DAC tile 230
# DAC_CLK_230_N - Bank 230 - DAC_CLK_N_230
set_property PACKAGE_PIN N4 [get_ports RF4_CLKO_B_C_N]
# DAC_CLK_230_P - Bank 230 - DAC_CLK_P_230
set_property PACKAGE_PIN N5 [get_ports RF4_CLKO_B_C_P]
set_property PACKAGE_PIN J1 [get_ports RFMC_DAC_04_N]
set_property PACKAGE_PIN J2 [get_ports RFMC_DAC_04_P]
set_property PACKAGE_PIN G1 [get_ports RFMC_DAC_05_N]
set_property PACKAGE_PIN G2 [get_ports RFMC_DAC_05_P]

# RF DAC tile 231
set_property PACKAGE_PIN E1 [get_ports RFMC_DAC_06_N]
set_property PACKAGE_PIN E2 [get_ports RFMC_DAC_06_P]
set_property PACKAGE_PIN C1 [get_ports RFMC_DAC_07_N]
set_property PACKAGE_PIN C2 [get_ports RFMC_DAC_07_P]
