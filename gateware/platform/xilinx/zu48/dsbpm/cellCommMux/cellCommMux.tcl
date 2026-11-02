##################################################################
# CREATE IP cellCommMux
##################################################################

set cellCommMux [create_ip -name axis_interconnect -vendor xilinx.com -library ip -version 1.1 -module_name cellCommMux]

set_property -dict { 
  CONFIG.C_NUM_SI_SLOTS {4}
  CONFIG.SWITCH_TDATA_NUM_BYTES {4}
  CONFIG.HAS_TSTRB {false}
  CONFIG.HAS_TKEEP {false}
  CONFIG.HAS_TID {false}
  CONFIG.HAS_TDEST {false}
  CONFIG.SWITCH_PACKET_MODE {true}
  CONFIG.C_SWITCH_MAX_XFERS_PER_ARB {512}
  CONFIG.C_SWITCH_NUM_CYCLES_TIMEOUT {1024}
  CONFIG.M00_AXIS_TDATA_NUM_BYTES {4}
  CONFIG.S00_AXIS_TDATA_NUM_BYTES {4}
  CONFIG.S00_AXIS_FIFO_MODE {2_(Packet)}
  CONFIG.C_S00_AXIS_FIFO_DEPTH {32}
  CONFIG.S01_AXIS_TDATA_NUM_BYTES {4}
  CONFIG.S01_AXIS_FIFO_MODE {2_(Packet)}
  CONFIG.C_S01_AXIS_FIFO_DEPTH {32}
  CONFIG.S02_AXIS_TDATA_NUM_BYTES {4}
  CONFIG.S02_AXIS_FIFO_MODE {2_(Packet)}
  CONFIG.C_S02_AXIS_FIFO_DEPTH {32}
  CONFIG.S03_AXIS_TDATA_NUM_BYTES {4}
  CONFIG.S03_AXIS_FIFO_MODE {2_(Packet)}
  CONFIG.M00_S01_CONNECTIVITY {true}
  CONFIG.M00_S02_CONNECTIVITY {true}
  CONFIG.M00_S03_CONNECTIVITY {true}
  CONFIG.Component_Name {forwardCellLinkMux}
} [get_ips cellCommMux]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $cellCommMux

##################################################################
