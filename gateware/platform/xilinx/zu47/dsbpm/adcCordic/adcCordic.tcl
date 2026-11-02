##################################################################
# CREATE IP adcCordic
##################################################################

set adcCordic [create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 -module_name adcCordic]

set_property -dict { 
  CONFIG.Functional_Selection {Translate}
  CONFIG.Pipelining_Mode {Optimal}
  CONFIG.Data_Format {SignedFraction}
  CONFIG.Input_Width {28}
  CONFIG.Output_Width {28}
  CONFIG.Compensation_Scaling {No_Scale_Compensation}
  CONFIG.cartesian_has_tuser {true}
  CONFIG.cartesian_tuser_width {6}
} [get_ips adcCordic]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $adcCordic

##################################################################
