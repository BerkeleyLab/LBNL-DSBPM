SECTIONS
{
    .ext_ddr_0 (NOLOAD) : {
       . = ALIGN(64);
       _ext_ddr_0_start = .;
       _ext_ddr_0_end = .;
    } > ddr4_0_C0_DDR4_ADDRESS_BLOCK_0

    .ext_ddr_1 (NOLOAD) : {
       . = ALIGN(64);
       _ext_ddr_1_start = .;
       _ext_ddr_1_end = .;
    } > ddr4_0_C0_DDR4_ADDRESS_BLOCK_1
}
