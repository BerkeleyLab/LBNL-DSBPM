##################################################################
# CREATE IP cellCommSendFIFO
##################################################################

set cellCommSendFIFO [create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name cellCommSendFIFO]

set_property -dict { 
  CONFIG.Fifo_Implementation {Common_Clock_Block_RAM}
  CONFIG.INTERFACE_TYPE {AXI_STREAM}
  CONFIG.Use_Embedded_Registers {false}
  CONFIG.Reset_Type {Asynchronous_Reset}
  CONFIG.Full_Flags_Reset_Value {1}
  CONFIG.Full_Threshold_Assert_Value {1022}
  CONFIG.Full_Threshold_Negate_Value {1021}
  CONFIG.TDATA_NUM_BYTES {4}
  CONFIG.TUSER_WIDTH {0}
  CONFIG.Enable_TLAST {true}
  CONFIG.TSTRB_WIDTH {4}
  CONFIG.TKEEP_WIDTH {4}
  CONFIG.FIFO_Implementation_wach {Common_Clock_Distributed_RAM}
  CONFIG.Full_Threshold_Assert_Value_wach {15}
  CONFIG.Empty_Threshold_Assert_Value_wach {14}
  CONFIG.FIFO_Implementation_wrch {Common_Clock_Distributed_RAM}
  CONFIG.Full_Threshold_Assert_Value_wrch {15}
  CONFIG.Empty_Threshold_Assert_Value_wrch {14}
  CONFIG.FIFO_Implementation_rach {Common_Clock_Distributed_RAM}
  CONFIG.Full_Threshold_Assert_Value_rach {15}
  CONFIG.Empty_Threshold_Assert_Value_rach {14}
  CONFIG.FIFO_Application_Type_axis {Packet_FIFO}
} [get_ips cellCommSendFIFO]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $cellCommSendFIFO

##################################################################
