##################################################################
# CREATE IP adcToSysFIFO
##################################################################

set adcToSysFIFO [create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name adcToSysFIFO]

set_property -dict { 
  CONFIG.Fifo_Implementation {Independent_Clocks_Distributed_RAM}
  CONFIG.synchronization_stages {2}
  CONFIG.Performance_Options {Standard_FIFO}
  CONFIG.Input_Data_Width {64}
  CONFIG.Input_Depth {16}
  CONFIG.Output_Data_Width {64}
  CONFIG.Output_Depth {16}
  CONFIG.Use_Embedded_Registers {false}
  CONFIG.Reset_Type {Asynchronous_Reset}
  CONFIG.Full_Flags_Reset_Value {1}
  CONFIG.Data_Count_Width {4}
  CONFIG.Write_Data_Count_Width {4}
  CONFIG.Read_Data_Count_Width {4}
  CONFIG.Full_Threshold_Assert_Value {13}
  CONFIG.Full_Threshold_Negate_Value {12}
  CONFIG.Empty_Threshold_Assert_Value {2}
  CONFIG.Empty_Threshold_Negate_Value {3}
} [get_ips adcToSysFIFO]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $adcToSysFIFO

##################################################################
