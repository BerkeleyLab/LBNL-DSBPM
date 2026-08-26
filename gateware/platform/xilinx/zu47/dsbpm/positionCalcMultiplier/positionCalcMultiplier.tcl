##################################################################
# CREATE IP positionCalcMultiplier
##################################################################

set positionCalcMultiplier [create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name positionCalcMultiplier]

set_property -dict { 
  CONFIG.PortAWidth {32}
  CONFIG.PortBWidth {32}
  CONFIG.Multiplier_Construction {Use_Mults}
  CONFIG.OutputWidthHigh {63}
} [get_ips positionCalcMultiplier]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $positionCalcMultiplier

##################################################################
