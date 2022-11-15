Direct-Sampling Beam Position Monitor
=====================================

Gateware/Software for Direct-Sampling Beam Position Monitor

### Building

This repository contains both gateware and software
for the Direct-Sampling Beam Position Monitor.

#### Gateware Dependencies

To build the gateware the following dependencies are needed:

* GNU Make
* Xilinx Vivado (2020.2.2 tested), available [here](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools.html)
* Xilinx Vitis (2020.2.2 tested), available [here](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vitis.html)

Make sure `vivado` and `vitis` are in PATH.

#### Software Dependencies

To build the software the following dependencies are needed:

* aarch64-none toolchain, bundled within Vitis

#### Building Instructions

With the dependencies in place a simple `make` should be able to generate
both gateware and software, plus the SD boot image .bin.

```bash
make
```

A suggestion in running the `make` command is to measure the time
and redirect stdout/stderr to a file so you can inspect it later:

```bash
ARM_TOOLCHAIN_LOCATION=/media/Xilinx/Vivado/2020.1/Vitis/2020.1/gnu/aarch64/lin/aarch64-none
(time make PLATFORM=<PLATFORM_NAME> APP=<APP_NAME> CROSS_COMPILE=${ARM_TOOLCHAIN_LOCATION}/bin/aarch64-none-elf-; date) 2>&1 | tee make_output
```

For now the following combinations of PLATFORM and APP are supported:

| APP / PLATFORM | zcu111 | zcu208 |
|:--------------:|:------:|:------:|
|       bpm      |        |    x   |

So, for example, to generate the DSBPM application for the ZCU208 board:

```bash
ARM_TOOLCHAIN_LOCATION=/media/Xilinx/Vivado/2020.1/Vitis/2020.1/gnu/aarch64/lin/aarch64-none
(time make PLATFORM=zcu208 APP=dsbpm CROSS_COMPILE=${ARM_TOOLCHAIN_LOCATION}/bin/aarch64-none-elf-; date) 2>&1 | tee make_output
```

### Deploying

To deploy the gateware and the software we can use a variety of
methods. For development, JTAG is being used. Remember to check
the DIP switches on development boards and ensure the switches
are set to JTAG mode and NOT SD Card mode.

#### Deploying gateware

The following script can download the gateware via JTAG:

```bash
cd gateware/scripts
xsct download_bit.tcl ../syn/dsbpm_zcu208/dsbpm_zcu208_top.bit
```

#### Deploying software

The following script can download the software via JTAG:

```bash
cd software/scripts
xsct download_elf.tcl ../../gateware/syn/dsbpm_zcu208/psu_init.tcl ../app/dsbpm/dsbpm_zcu208.elf
```
