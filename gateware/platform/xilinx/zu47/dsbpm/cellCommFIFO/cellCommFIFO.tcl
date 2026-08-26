##################################################################
# CREATE IP cellCommFIFO
##################################################################

set cellCommFIFO [create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name cellCommFIFO]

set_property -dict { 
  CONFIG.Fifo_Implementation {Common_Clock_Block_RAM}
  CONFIG.INTERFACE_TYPE {AXI_STREAM}
  CONFIG.Input_Data_Width {33}
  CONFIG.Input_Depth {64}
  CONFIG.Output_Data_Width {33}
  CONFIG.Output_Depth {64}
  CONFIG.Use_Embedded_Registers {false}
  CONFIG.Reset_Type {Asynchronous_Reset}
  CONFIG.Full_Flags_Reset_Value {1}
  CONFIG.Data_Count_Width {6}
  CONFIG.Write_Data_Count_Width {6}
  CONFIG.Read_Data_Count_Width {6}
  CONFIG.Full_Threshold_Assert_Value {62}
  CONFIG.Full_Threshold_Negate_Value {61}
  CONFIG.Clock_Type_AXI {Independent_Clock}
  CONFIG.TDATA_NUM_BYTES {4}
  CONFIG.TUSER_WIDTH {0}
  CONFIG.Enable_TLAST {true}
  CONFIG.TSTRB_WIDTH {4}
  CONFIG.TKEEP_WIDTH {4}
  CONFIG.FIFO_Implementation_wach {Independent_Clocks_Distributed_RAM}
  CONFIG.Full_Threshold_Assert_Value_wach {15}
  CONFIG.Empty_Threshold_Assert_Value_wach {13}
  CONFIG.FIFO_Implementation_wdch {Independent_Clocks_Block_RAM}
  CONFIG.Empty_Threshold_Assert_Value_wdch {1021}
  CONFIG.FIFO_Implementation_wrch {Independent_Clocks_Distributed_RAM}
  CONFIG.Full_Threshold_Assert_Value_wrch {15}
  CONFIG.Empty_Threshold_Assert_Value_wrch {13}
  CONFIG.FIFO_Implementation_rach {Independent_Clocks_Distributed_RAM}
  CONFIG.Full_Threshold_Assert_Value_rach {15}
  CONFIG.Empty_Threshold_Assert_Value_rach {13}
  CONFIG.FIFO_Implementation_rdch {Independent_Clocks_Block_RAM}
  CONFIG.Empty_Threshold_Assert_Value_rdch {1021}
  CONFIG.FIFO_Implementation_axis {Independent_Clocks_Block_RAM}
  CONFIG.Input_Depth_axis {256}
  CONFIG.Full_Threshold_Assert_Value_axis {255}
  CONFIG.Empty_Threshold_Assert_Value_axis {253}
} [get_ips cellCommFIFO]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $cellCommFIFO

##################################################################
