SECTIONS
{
    .ext_ddr (NOLOAD) : {
       . = ALIGN(64);
       _ext_ddr_start = .;
       _ext_ddr_end = .;
    } > ddr4_0_C0_DDR4_ADDRESS_BLOCK
}
