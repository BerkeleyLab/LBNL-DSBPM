##################################################################
# rmsBandSelect FILES
##################################################################

proc write_fir_compiler_rmsBandSelect { fir_compiler_rmsBandSelect_filepath } {
  set fir_compiler_rmsBandSelect [open $fir_compiler_rmsBandSelect_filepath  w+]

  puts $fir_compiler_rmsBandSelect {; Coefficients for RMS band-selection FIR filter}
  puts $fir_compiler_rmsBandSelect {; From http://t-filter.appspot.com/fir/index.html}
  puts $fir_compiler_rmsBandSelect {;   10 kHz sampling}
  puts $fir_compiler_rmsBandSelect {;   Pass band 0 to 200, 1 dB ripple}
  puts $fir_compiler_rmsBandSelect {;   Stop band 400 to 5000, 60 dB attenuation}
  puts $fir_compiler_rmsBandSelect {}
  puts $fir_compiler_rmsBandSelect {RADIX = 10;}
  puts $fir_compiler_rmsBandSelect {COEFDATA = }
  puts $fir_compiler_rmsBandSelect { 0.0006762307161231497,}
  puts $fir_compiler_rmsBandSelect { 0.000512448042120653,}
  puts $fir_compiler_rmsBandSelect { 0.0006880146121029105,}
  puts $fir_compiler_rmsBandSelect { 0.0008868159561171186,}
  puts $fir_compiler_rmsBandSelect { 0.001105197479845018,}
  puts $fir_compiler_rmsBandSelect { 0.001337809084174929,}
  puts $fir_compiler_rmsBandSelect { 0.001577569538217206,}
  puts $fir_compiler_rmsBandSelect { 0.001815811804373526,}
  puts $fir_compiler_rmsBandSelect { 0.002041931482757052,}
  puts $fir_compiler_rmsBandSelect { 0.002245044015582535,}
  puts $fir_compiler_rmsBandSelect { 0.002410910445816493,}
  puts $fir_compiler_rmsBandSelect { 0.002528257731419754,}
  puts $fir_compiler_rmsBandSelect { 0.002581473890290243,}
  puts $fir_compiler_rmsBandSelect { 0.002557917455996036,}
  puts $fir_compiler_rmsBandSelect { 0.002445779689778131,}
  puts $fir_compiler_rmsBandSelect { 0.002233484254641496,}
  puts $fir_compiler_rmsBandSelect { 0.001912208483533567,}
  puts $fir_compiler_rmsBandSelect { 0.001476540012515474,}
  puts $fir_compiler_rmsBandSelect { 0.0009243666587644849,}
  puts $fir_compiler_rmsBandSelect { 0.0002566944293226388,}
  puts $fir_compiler_rmsBandSelect { -0.000520138367807496,}
  puts $fir_compiler_rmsBandSelect { -0.001395450480472969,}
  puts $fir_compiler_rmsBandSelect { -0.002352769208232938,}
  puts $fir_compiler_rmsBandSelect { -0.003371219663314996,}
  puts $fir_compiler_rmsBandSelect { -0.004425189875512349,}
  puts $fir_compiler_rmsBandSelect { -0.005483940080410983,}
  puts $fir_compiler_rmsBandSelect { -0.006512652809968109,}
  puts $fir_compiler_rmsBandSelect { -0.007473067963760303,}
  puts $fir_compiler_rmsBandSelect { -0.008324382038418687,}
  puts $fir_compiler_rmsBandSelect { -0.009024064576780708,}
  puts $fir_compiler_rmsBandSelect { -0.009529654737371138,}
  puts $fir_compiler_rmsBandSelect { -0.009799080994073931,}
  puts $fir_compiler_rmsBandSelect { -0.009792500227768342,}
  puts $fir_compiler_rmsBandSelect { -0.009473562988478188,}
  puts $fir_compiler_rmsBandSelect { -0.00881088151870005,}
  puts $fir_compiler_rmsBandSelect { -0.007779419203846298,}
  puts $fir_compiler_rmsBandSelect { -0.006361300200091128,}
  puts $fir_compiler_rmsBandSelect { -0.004546981198814183,}
  puts $fir_compiler_rmsBandSelect { -0.002336059607662464,}
  puts $fir_compiler_rmsBandSelect { 0.0002620001477619449,}
  puts $fir_compiler_rmsBandSelect { 0.003227946844091129,}
  puts $fir_compiler_rmsBandSelect { 0.006532154875173394,}
  puts $fir_compiler_rmsBandSelect { 0.01013509535322343,}
  puts $fir_compiler_rmsBandSelect { 0.01398793963330795,}
  puts $fir_compiler_rmsBandSelect { 0.01803342624292084,}
  puts $fir_compiler_rmsBandSelect { 0.02220705414321104,}
  puts $fir_compiler_rmsBandSelect { 0.02643832411204626,}
  puts $fir_compiler_rmsBandSelect { 0.03065241592814769,}
  puts $fir_compiler_rmsBandSelect { 0.03477184755812673,}
  puts $fir_compiler_rmsBandSelect { 0.03871857513356691,}
  puts $fir_compiler_rmsBandSelect { 0.04241574716284882,}
  puts $fir_compiler_rmsBandSelect { 0.04578996944352306,}
  puts $fir_compiler_rmsBandSelect { 0.04877303168213444,}
  puts $fir_compiler_rmsBandSelect { 0.05130367229855051,}
  puts $fir_compiler_rmsBandSelect { 0.05332931180258929,}
  puts $fir_compiler_rmsBandSelect { 0.05480752222572739,}
  puts $fir_compiler_rmsBandSelect { 0.05570718096405709,}
  puts $fir_compiler_rmsBandSelect { 0.05600918881396932,}
  puts $fir_compiler_rmsBandSelect { 0.05570718096405709,}
  puts $fir_compiler_rmsBandSelect { 0.05480752222572739,}
  puts $fir_compiler_rmsBandSelect { 0.05332931180258929,}
  puts $fir_compiler_rmsBandSelect { 0.05130367229855051,}
  puts $fir_compiler_rmsBandSelect { 0.04877303168213444,}
  puts $fir_compiler_rmsBandSelect { 0.04578996944352306,}
  puts $fir_compiler_rmsBandSelect { 0.04241574716284882,}
  puts $fir_compiler_rmsBandSelect { 0.03871857513356691,}
  puts $fir_compiler_rmsBandSelect { 0.03477184755812673,}
  puts $fir_compiler_rmsBandSelect { 0.03065241592814769,}
  puts $fir_compiler_rmsBandSelect { 0.02643832411204626,}
  puts $fir_compiler_rmsBandSelect { 0.02220705414321104,}
  puts $fir_compiler_rmsBandSelect { 0.01803342624292084,}
  puts $fir_compiler_rmsBandSelect { 0.01398793963330795,}
  puts $fir_compiler_rmsBandSelect { 0.01013509535322343,}
  puts $fir_compiler_rmsBandSelect { 0.006532154875173394,}
  puts $fir_compiler_rmsBandSelect { 0.003227946844091129,}
  puts $fir_compiler_rmsBandSelect { 0.0002620001477619449,}
  puts $fir_compiler_rmsBandSelect { -0.002336059607662464,}
  puts $fir_compiler_rmsBandSelect { -0.004546981198814183,}
  puts $fir_compiler_rmsBandSelect { -0.006361300200091128,}
  puts $fir_compiler_rmsBandSelect { -0.007779419203846298,}
  puts $fir_compiler_rmsBandSelect { -0.00881088151870005,}
  puts $fir_compiler_rmsBandSelect { -0.009473562988478188,}
  puts $fir_compiler_rmsBandSelect { -0.009792500227768342,}
  puts $fir_compiler_rmsBandSelect { -0.009799080994073931,}
  puts $fir_compiler_rmsBandSelect { -0.009529654737371138,}
  puts $fir_compiler_rmsBandSelect { -0.009024064576780708,}
  puts $fir_compiler_rmsBandSelect { -0.008324382038418687,}
  puts $fir_compiler_rmsBandSelect { -0.007473067963760303,}
  puts $fir_compiler_rmsBandSelect { -0.006512652809968109,}
  puts $fir_compiler_rmsBandSelect { -0.005483940080410983,}
  puts $fir_compiler_rmsBandSelect { -0.004425189875512349,}
  puts $fir_compiler_rmsBandSelect { -0.003371219663314996,}
  puts $fir_compiler_rmsBandSelect { -0.002352769208232938,}
  puts $fir_compiler_rmsBandSelect { -0.001395450480472969,}
  puts $fir_compiler_rmsBandSelect { -0.000520138367807496,}
  puts $fir_compiler_rmsBandSelect { 0.0002566944293226388,}
  puts $fir_compiler_rmsBandSelect { 0.0009243666587644849,}
  puts $fir_compiler_rmsBandSelect { 0.001476540012515474,}
  puts $fir_compiler_rmsBandSelect { 0.001912208483533567,}
  puts $fir_compiler_rmsBandSelect { 0.002233484254641496,}
  puts $fir_compiler_rmsBandSelect { 0.002445779689778131,}
  puts $fir_compiler_rmsBandSelect { 0.002557917455996036,}
  puts $fir_compiler_rmsBandSelect { 0.002581473890290243,}
  puts $fir_compiler_rmsBandSelect { 0.002528257731419754,}
  puts $fir_compiler_rmsBandSelect { 0.002410910445816493,}
  puts $fir_compiler_rmsBandSelect { 0.002245044015582535,}
  puts $fir_compiler_rmsBandSelect { 0.002041931482757052,}
  puts $fir_compiler_rmsBandSelect { 0.001815811804373526,}
  puts $fir_compiler_rmsBandSelect { 0.001577569538217206,}
  puts $fir_compiler_rmsBandSelect { 0.001337809084174929,}
  puts $fir_compiler_rmsBandSelect { 0.001105197479845018,}
  puts $fir_compiler_rmsBandSelect { 0.0008868159561171186,}
  puts $fir_compiler_rmsBandSelect { 0.0006880146121029105,}
  puts $fir_compiler_rmsBandSelect { 0.000512448042120653,}
  puts $fir_compiler_rmsBandSelect { 0.0006762307161231497;}

  flush $fir_compiler_rmsBandSelect
  close $fir_compiler_rmsBandSelect
}

##################################################################
# CREATE IP rmsBandSelect
##################################################################

set rmsBandSelect [create_ip -name fir_compiler -vendor xilinx.com -library ip -version 7.2 -module_name rmsBandSelect]

write_fir_compiler_rmsBandSelect  [file join [get_property IP_DIR [get_ips rmsBandSelect]] rmsBandSelect.coe]
set_property -dict { 
  CONFIG.CoefficientSource {COE_File}
  CONFIG.Coefficient_File {rmsBandSelect.coe}
  CONFIG.Coefficient_Sets {1}
  CONFIG.Sample_Frequency {0.01}
  CONFIG.Clock_Frequency {100}
  CONFIG.Coefficient_Sign {Signed}
  CONFIG.Quantization {Quantize_Only}
  CONFIG.Coefficient_Width {18}
  CONFIG.Coefficient_Fractional_Bits {21}
  CONFIG.Coefficient_Structure {Non_Symmetric}
  CONFIG.Data_Width {24}
  CONFIG.Data_Fractional_Bits {0}
  CONFIG.Output_Rounding_Mode {Truncate_LSBs}
  CONFIG.Output_Width {25}
  CONFIG.Filter_Architecture {Systolic_Multiply_Accumulate}
  CONFIG.S_DATA_Has_TUSER {Not_Required}
  CONFIG.M_DATA_Has_TUSER {Not_Required}
} [get_ips rmsBandSelect]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $rmsBandSelect

##################################################################
