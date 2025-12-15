Direct-Sampling Beam Position Monitor
=====================================

Gateware/Software for Direct-Sampling Beam Position Monitor

### Building

This repository contains both gateware and software
for the Direct-Sampling Beam Position Monitor.

#### Gateware Dependencies

To build the gateware the following dependencies are needed:

* GNU Make
* Xilinx Vivado (2022.1 tested), available [here](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools.html)
* Xilinx Vitis (2022.1 tested), available [here](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vitis.html)

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
ARM_TOOLCHAIN_LOCATION=/media/Xilinx/Vivado/2022.1/Vitis/2022.1/gnu/aarch64/lin/aarch64-none
(time make PLATFORM=<PLATFORM_NAME> APP=<APP_NAME> SAMPLES_PER_TURN= <SAMPLES_PER_TURN> VCXO_TYPE=<VCXO_TYPE> CROSS_COMPILE=${ARM_TOOLCHAIN_LOCATION}/bin/aarch64-none-elf- && notify-send 'Compilation SUCCESS' || notify-send 'Compilation ERROR'; date) 2>&1 | tee make_output
```

So, for example, to generate the DSBPM application for the ZCU208 board, 81 samples per turn
and VCXO with center frequency of 160MHz:

```bash
ARM_TOOLCHAIN_LOCATION=/media/Xilinx/Vivado/2022.1/Vitis/2022.1/gnu/aarch64/lin/aarch64-none
(time make PLATFORM=zcu208 APP=dsbpm SAMPLES_PER_TURN=81 VCXO_TYPE=160 CROSS_COMPILE=${ARM_TOOLCHAIN_LOCATION}/bin/aarch64-none-elf- && notify-send 'Compilation SUCCESS' || notify-send 'Compilation ERROR'; date) 2>&1 | tee make_output
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
xsct download_bit.tcl ../syn/<APP>_<PLATFORM>/<APP>_<PLATFORM>_top.bit
```

#### Deploying software

The following script can download the software via JTAG:

```bash
cd software/scripts
xsct download_elf.tcl ../../gateware/syn/<APP>_<PLATFORM>/psu_init.tcl ../app/<APP>/<APP>_<PLATFORM>.elf
```

#### Depoying configuration files

The `dsbpm` project makes use of the following configuration files loaded on boot
from the SD card:

* SYSPARMS.CSV

Configuration parameters in .csv format with the following lines, for example:

```
Ethernet Address,AA:4C:42:4E:4C:02
Use DHCP,1
IP Address,192.168.1.129
IP Netmask,255.255.255.0
IP Gateway,192.168.1.1
User MGT ref offset,0
Startup debug flags,0
PLL RF divisor,328
PLL multiplier,81
Single pass?,0
Single pass event,0
ADC clocks per heartbeat,24928000
EVR clocks per fast acquisition,12464
EVR clocks per slow acquisition,12464000
ADC for button ABCD,3210
RFDC MMCM DivClk Divider,1000
RFDC MMCM Clk Multiplier,3375
RFDC MMCM Clk0 Divider,10250
X calibration (mm p.u.),16.0
Y calibration (mm p.u.),16.0
Q calibration (p.u.),16.0
Button rotation (0 or 45),45
AFE attenuator trims (dB),0 0 0 0
```

IMPORTANT NOTE: The board will first try to request an IP via DHCP, if it's
compiled with LWIP_DHCP enabled and the parameter `Use DHCP` is set to `1`.
If that fails, then it will fallback to IP address `192.168.1.10/24`.

If LWIP_DHCP is disabled or `Use DHCP` is set to `0`, then it will use static
IP address and the embedded software will use the `IP Address`, `IP Netmask`
and `IP Gateway` from the `sysParms.csv` configuration file.

If `sysParms.csv` file corrupted, the default IP address 192.168.1.128/24 will
be used.

* RFTABLE.CSV

RF Demodulation table for the synchronous Digital Down-Conversion (DDC) local
oscillator. It needs 2 floating point ([-1,1]) values separated by a comma
representing I and Q values. The values are scaled to the full ADC range by the
embedded software. Example:

```
 1.000000,-0.000000
 0.019394,-0.999809
-0.999245,-0.038773
-0.058144, 0.998306
...
```

* PTTABLE.CSV

PT low/high demodulation table for the synchronous Digital Down-Conversion (DDC)
local oscillator. It needs 4 floating point ([-1,1]) values separated by a comma
representing I and Q values for the pilot-tone low and high. The values are
scaled to the full ADC range by the embedded software. Example:

```
 1.000000,-0.000000, 1.000000,-0.000000
 0.064255,-0.997932,-0.025513,-0.999672
-0.991745,-0.128251,-0.998695, 0.051011
-0.191713, 0.981453, 0.076478, 0.997070
...
```

* PTGEN.CSV

PT generation table for the synchronous DAC. It needs 2 floating point ([-1,1])
values separated by a comma representing I and Q values. The values are scaled
to the full DAC range by the embedded software. Example:

```
 1.000000, 0.000000
 0.993454, 0.008103
 0.973846, 0.015915
 0.941496, 0.023072
```

* LMK04XX.CSV (optional)
* LMXADC.CSV (optional)
* LMXDAC.CSV (optional)

Values for the LMK 04828B, LMX2594 (ADC) and LMX2594 (DAC) chips. It requires
1 decimal value per line, using the format specified by the SPI transaction
of the corresponding chip.

### Updates

The following system parameters can be updated via TFTP:

* RF demodulation table
* Pilot demodulation Tone table
* Pilot Tone generation table
* LMK04828B configuration table
* LMX 2594 ADC configuration table
* LMK 2494 DAC configuration table
* System parameters
* Gateware + Software boot file (BOOT.bin)

#### Update System parameters table

An example of the parameters used can be found at: `software/app/<APP>/scripts/sysParms.csv`

```bash
tftp -v -m binary <system IP> -c put sysParms.csv sysParms.csv
```

#### Generating demodulation/generation tables

The tables are generated by a python script `createDemodGenTables.py` located at:
`software/scripts`

To execute that script do:

```bash
cd software/scripts
python3 createDemodGenTables.py
```

#### Generating LMK/LMX tables

The tables are generated from a [TICS Pro](https://www.ti.com/tool/TICSPRO-SW)
file by a shell script `createRFCLKtable.sh` located at: `software/scripts`

To execute that script do:

```bash
cd software/scripts
sh createRFCLKtable.sh <TICS_pro_filename.tcs> > <CSV_filename.csv>
```

#### Update the RF demodulation table

An example of the RF table can be found at: `software/scripts/rfTableSR_81_328_bin_20_conjugate.csv`

```bash
tftp -v -m binary <system IP> -c put <RF TABLE>.csv rfTable.csv
```

#### Update Pilot tone demodulation table

An example of the PT table can be found at: `software/scripts/ptTableSR_81_328_L7_19_H11_19_bin_20_conjugate.csv`

```bash
tftp -v -m binary <system IP> -c put <PT TABLE>.csv ptTable.csv
```

#### Update LMK04828B table

The LMK table can be generated by using one of the default TICS pro files available
at: `software/target/<TARGET_NAME>/lmk04828B.tcs`

```bash
tftp -v -m binary <system IP> -c put <LMK TABLE>.csv LMK04XX.csv
```

#### Update LMK2594 ADC/DAC tables

The LMX tables (ADC/DAC) can be generated by using one of the default TICS pro files available
at : `software/target/<TARGET_NAME>/lmx2594(ADC/DAC).tcs`

```bash
tftp -v -m binary <system IP> -c put <LMK TABLE>.csv [LMXADC|LMXDAC].csv
```

#### Update Pilot tone generation table

An example of the PT generation table can be found at: `software/scripts/ptGen_81_7_low_11_high_19.csv`

```bash
tftp -v -m binary <system IP> -c put <PTGEN TABLE>.csv ptGen.csv
```

#### Update system image file (BOOT.bin):

```bash
tftp -v -m binary <system IP> -c put BOOT.bin BOOT.bin
```

When copying `BOOT.bin`, the user needs to reboot the system via a power cycle
or via the console `boot` command.

Another option to upgrade the image is to use the `programFlash.sh` script
located at: `software/scripts`. The script will automatically readback the
image file from the system and perform a byte-to-byte comparison to detect
possible transmission errors.

```bash
cd software/scripts
sh ./programFlash.sh <system IP> [BOOT.bin filename]
```

If `BOOT.bin filename` is missing the current path is assumed.
