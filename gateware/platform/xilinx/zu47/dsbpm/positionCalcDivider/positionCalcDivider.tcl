##################################################################
# CREATE IP positionCalcDivider
##################################################################

set positionCalcDivider [create_ip -name div_gen -vendor xilinx.com -library ip -version 5.1 -module_name positionCalcDivider]

set_property -dict { 
  CONFIG.algorithm_type {High_Radix}
  CONFIG.dividend_and_quotient_width {28}
  CONFIG.dividend_has_tuser {true}
  CONFIG.dividend_tuser_width {4}
  CONFIG.divisor_width {29}
  CONFIG.divisor_has_tuser {true}
  CONFIG.divisor_tuser_width {28}
  CONFIG.remainder_type {Fractional}
  CONFIG.fractional_width {28}
  CONFIG.latency {35}
} [get_ips positionCalcDivider]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $positionCalcDivider

##################################################################
