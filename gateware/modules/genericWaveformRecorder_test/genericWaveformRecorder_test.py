import logging
import os
import random
from dataclasses import dataclass

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import (
    ClockCycles,
    NextTimeStep,
    ReadOnly,
    RisingEdge,
)

#
# Register offsets
#
WR_REG_OFFSET_CSR = 0
WR_REG_OFFSET_PRETRIGGER_COUNT = 1
WR_REG_OFFSET_ACQUISITION_COUNT = 2
WR_REG_OFFSET_ADDRESS_LSB = 3
WR_REG_OFFSET_ADDRESS_MSB = 4
# Read-only offsets
WR_REG_OFFSET_CSR2 = 5
WR_REG_OFFSET_TIMESTAMP_SECONDS = 6
WR_REG_OFFSET_TIMESTAMP_TICKS = 7


#
# Write CSR fields
#
WR_W_CSR_TRIGGER_MASK = 0xFF000000
WR_W_CSR_EVENT_TRIGGER_7_ENABLE = 0x80000000
WR_W_CSR_EVENT_TRIGGER_6_ENABLE = 0x40000000
WR_W_CSR_EVENT_TRIGGER_5_ENABLE = 0x20000000
WR_W_CSR_EVENT_TRIGGER_4_ENABLE = 0x10000000
WR_W_CSR_EVENT_TRIGGER_1_ENABLE = 0x02000000
WR_W_CSR_SOFT_TRIGGER_ENABLE = 0x01000000
WR_W_CSR_RESET_BAR_MODE = 0x00000400
WR_W_CSR_TEST_ACQUISITION_MODE = 0x00000200
WR_W_CSR_DIAGNOSTIC_MODE = 0x00000100
WR_W_CSR_ARM = 0x00000001


#
# Read CSR fields
#
WR_R_CSR_TRIGGER_MASK = 0xFF000000
WR_R_CSR_PRE_TRIG_DONE = 0x00010000
WR_R_CSR_DIAG_MODE = 0x00000100
WR_R_CSR_FULL = 0x00000080
WR_R_CSR_BRESP = 0x00000060
WR_R_CSR_OVERRUN = 0x00000010
WR_R_CSR_STATE = 0x0000000E
WR_R_CSR_ARM = 0x00000001

#
# Read CSR2 fields
#
WR_R_CSR2_FIFO_COUNT_MASK = 0x0000FFFF

AXI_DRAIN_IDLE_CYCLES = 128
FIFO_DRAIN_MAX_CYCLES = 4096
AXI_QUIESCE_MAX_CYCLES = 1024


@dataclass
class RegressionConfig:
    seed: int
    random_iters: int
    axi_awready_percent: int
    axi_wready_percent: int
    acq_capacity: int
    fifo_capacity: int

    @classmethod
    def from_environment(cls):
        config = cls(
            seed=int(os.getenv("SEED", "0x51A72026"), 0),
            random_iters=int(os.getenv("RANDOM_ITERS", "5"), 0),
            axi_awready_percent=int(os.getenv("AXI_AWREADY_PERCENT", "75"), 0),
            axi_wready_percent=int(os.getenv("AXI_WREADY_PERCENT", "75"), 0),
            acq_capacity=int(os.getenv("ACQ_CAPACITY", str(1 << 23)), 0),
            fifo_capacity=int(os.getenv("FIFO_CAPACITY", "256"), 0),
        )

        assert 0 <= config.axi_awready_percent <= 100, (
            "AXI_AWREADY_PERCENT must be in the range 0..100"
        )
        assert 0 <= config.axi_wready_percent <= 100, (
            "AXI_WREADY_PERCENT must be in the range 0..100"
        )
        assert config.random_iters > 0, "RANDOM_ITERS must be greater than zero"
        assert config.acq_capacity > 0, "ACQ_CAPACITY must be greater than zero"
        assert (config.acq_capacity & (config.acq_capacity - 1)) == 0, (
            "ACQ_CAPACITY must be a power of two for this regression"
        )
        assert config.fifo_capacity > 0, "FIFO_CAPACITY must be greater than zero"
        assert (config.fifo_capacity & (config.fifo_capacity - 1)) == 0, (
            "FIFO_CAPACITY must be a power of two for this regression"
        )

        return config


class TB:
    def __init__(self, dut, config):
        dut._log.setLevel(logging.INFO)
        self.dut = dut
        self.config = config

        self.stim_rng = random.Random(config.seed)
        self.axi_rng = random.Random(config.seed ^ 0xA5A55A5A)

        self.axi_bytes = len(self.dut.axi_WDATA) // 8
        self.acq_span_bytes = config.acq_capacity * self.axi_bytes
        self.axi_addr_space_bytes = 1 << len(self.dut.axi_AWADDR)

        # Bedrock fifo.v reports count = fill - 1. So empty FIFO
        # = all ones
        fifo_addr_width = (config.fifo_capacity - 1).bit_length()
        self.fifo_count_width = fifo_addr_width + 1
        self.fifo_count_mask = (1 << self.fifo_count_width) - 1
        self.fifo_empty_count = self.fifo_count_mask

        assert self.acq_span_bytes <= self.axi_addr_space_bytes, (
            "ACQ_CAPACITY is too large for the DUT AXI address width"
        )

        self.sample_drive_enable = False
        self.sample_gap = 16
        self.sample_gap_count = 0
        self.sample_number = 0

        self.random_backpressure = False
        self.error_responses_left = 0

        self.score_test_mode = False
        self.score_base_addr = 0
        self.score_first_aw = True
        self.expected_next_awaddr = 0
        self.payload_sequence_started = False
        self.expected_sample_number = 0
        self.test_axi_beats = 0

        self.burst_active = False
        self.burst_beats_left = 0
        self.aw_stalled = False
        self.stalled_awaddr = 0
        self.stalled_awlen = 0
        self.w_stalled = False
        self.stalled_wdata = 0
        self.stalled_wlast = 0

        self.dut.writeData.value = 0
        self.dut.regStrobes.value = 0
        self.dut.data.value = 0
        self.dut.testData.value = 0
        self.dut.valid.value = 0
        self.dut.triggers.value = 0
        self.dut.timestamp.value = 0
        self.dut.diagExtMode.value = 0
        self.dut.diagExtData.value = 0
        self.dut.axi_AWREADY.value = 1
        self.dut.axi_WREADY.value = 1
        self.dut.axi_BRESP.value = 0
        self.dut.axi_BVALID.value = 0

        cocotb.start_soon(Clock(dut.sysClk, 10, unit="ns").start())
        cocotb.start_soon(Clock(dut.clk, 8, unit="ns").start())

        self.sample_task = cocotb.start_soon(self._drive_samples())
        self.timestamp_task = cocotb.start_soon(self._drive_timestamp())
        self.axi_slave_task = cocotb.start_soon(self._axi_slave())
        self.axi_monitor_task = cocotb.start_soon(self._monitor_axi())

    def _read_signal(self, signal, name):
        value = signal.value
        assert value.is_resolvable, f"FAIL: {name} contains X/Z values: {value}"

        if hasattr(value, "to_unsigned"):
            return value.to_unsigned()

        return int(value)

    def _check_background_tasks(self):
        tasks = (
            ("sample driver", self.sample_task),
            ("timestamp driver", self.timestamp_task),
            ("AXI slave", self.axi_slave_task),
            ("AXI monitor", self.axi_monitor_task),
        )

        for name, task in tasks:
            if task.done():
                try:
                    task.result()
                except Exception as exc:
                    raise AssertionError(f"FAIL: {name} failed: {exc}") from exc

                raise AssertionError(f"FAIL: {name} stopped unexpectedly")

    @staticmethod
    def _repeated16(value, width):
        value &= 0xFFFF
        result = 0

        for lane in range(width // 16):
            result |= value << (16 * lane)

        return result

    def base_addr_for_region(self, region):
        base_addr = region * self.acq_span_bytes
        assert base_addr < self.axi_addr_space_bytes, (
            f"Acquisition base region {region} exceeds AXI address space: "
            f"base=0x{base_addr:x}"
        )
        return base_addr

    async def _write_reg(self, offset, value):
        assert 0 <= offset <= WR_REG_OFFSET_ADDRESS_MSB, (
            f"Invalid writable CSR offset: {offset}"
        )

        await RisingEdge(self.dut.sysClk)
        self.dut.writeData.value = value & 0xFFFFFFFF
        self.dut.regStrobes.value = 1 << offset

        await RisingEdge(self.dut.sysClk)
        self.dut.regStrobes.value = 0

        self._check_background_tasks()

    async def write32(self, offset, value):
        await self._write_reg(offset, value)

    async def read32(self, offset):
        await RisingEdge(self.dut.sysClk)
        await ReadOnly()

        if offset == WR_REG_OFFSET_CSR:
            value = self._read_signal(self.dut.csr, "csr")
        elif offset == WR_REG_OFFSET_PRETRIGGER_COUNT:
            value = self._read_signal(self.dut.pretrigCount, "pretrigCount")
        elif offset == WR_REG_OFFSET_ACQUISITION_COUNT:
            value = self._read_signal(self.dut.acqCount, "acqCount")
        elif offset == WR_REG_OFFSET_ADDRESS_LSB:
            value = self._read_signal(self.dut.acqAddressLSB, "acqAddressLSB")
        elif offset == WR_REG_OFFSET_ADDRESS_MSB:
            value = self._read_signal(self.dut.acqAddressMSB, "acqAddressMSB")
        elif offset == WR_REG_OFFSET_CSR2:
            value = self._read_signal(self.dut.csr2, "csr2")
        elif offset == WR_REG_OFFSET_TIMESTAMP_SECONDS:
            when_triggered = self._read_signal(self.dut.whenTriggered, "whenTriggered")
            value = (when_triggered >> 32) & 0xFFFFFFFF
        elif offset == WR_REG_OFFSET_TIMESTAMP_TICKS:
            when_triggered = self._read_signal(self.dut.whenTriggered, "whenTriggered")
            value = when_triggered & 0xFFFFFFFF
        else:
            raise AssertionError(f"Invalid CSR offset: {offset}")

        self._check_background_tasks()
        await NextTimeStep()

        return value

    async def wait_reg_set(self, mask, reg_offset, max_reads, what):
        for _ in range(max_reads):
            reg_value = await self.read32(reg_offset)
            if (reg_value & mask) == mask:
                return reg_value

        assert False, f"FAIL: {what}"

    async def wait_reg_clear(self, mask, reg_offset, max_reads, what):
        for _ in range(max_reads):
            reg_value = await self.read32(reg_offset)
            if (reg_value & mask) == 0:
                return reg_value

        assert False, f"FAIL: {what}"

    async def wait_csr_set(self, mask, max_reads, what):
        return await self.wait_reg_set(mask, WR_REG_OFFSET_CSR, max_reads, what)

    async def wait_csr_clear(self, mask, max_reads, what):
        return await self.wait_reg_clear(mask, WR_REG_OFFSET_CSR, max_reads, what)

    async def wait_csr2_set(self, mask, max_reads, what):
        return await self.wait_reg_set(mask, WR_REG_OFFSET_CSR2, max_reads, what)

    async def wait_csr2_clear(self, mask, max_reads, what):
        return await self.wait_reg_clear(mask, WR_REG_OFFSET_CSR2, max_reads, what)

    async def program_acquisition(self, pretrig, acq_count, base_addr, csr_value):
        await self.write32(WR_REG_OFFSET_PRETRIGGER_COUNT, pretrig)
        await self.write32(WR_REG_OFFSET_ACQUISITION_COUNT, acq_count)
        await self.write32(WR_REG_OFFSET_ADDRESS_LSB, base_addr & 0xFFFFFFFF)
        await self.write32(WR_REG_OFFSET_ADDRESS_MSB, base_addr >> 32)

        readback = await self.read32(WR_REG_OFFSET_PRETRIGGER_COUNT)
        assert readback == pretrig, (
            f"FAIL: pretrigger count CSR readback mismatch: "
            f"expected {pretrig}, got {readback}"
        )

        readback = await self.read32(WR_REG_OFFSET_ACQUISITION_COUNT)
        assert readback == acq_count, (
            f"FAIL: acquisition count CSR readback mismatch: "
            f"expected {acq_count}, got {readback}"
        )

        # The address CSRs expose the current AXI write address rather than the
        # programmed base register. Read them to exercise the interface; address
        # correctness is checked from AWADDR by the AXI monitor.
        await self.read32(WR_REG_OFFSET_ADDRESS_LSB)
        await self.read32(WR_REG_OFFSET_ADDRESS_MSB)

        self.score_base_addr = base_addr
        self.score_first_aw = True
        self.score_test_mode = bool(csr_value & WR_W_CSR_TEST_ACQUISITION_MODE)
        self.payload_sequence_started = False
        self.expected_sample_number = 0
        self.test_axi_beats = 0

        await self.write32(WR_REG_OFFSET_CSR, csr_value | WR_W_CSR_ARM)
        readback = await self.read32(WR_REG_OFFSET_CSR)

        assert (readback & WR_R_CSR_TRIGGER_MASK) == (
            csr_value & WR_W_CSR_TRIGGER_MASK
        ), "FAIL: trigger-enable CSR readback mismatch"
        assert (readback & WR_W_CSR_TEST_ACQUISITION_MODE) == (
            csr_value & WR_W_CSR_TEST_ACQUISITION_MODE
        ), "FAIL: test-mode CSR readback mismatch"
        assert (readback & WR_W_CSR_DIAGNOSTIC_MODE) == (
            csr_value & WR_W_CSR_DIAGNOSTIC_MODE
        ), "FAIL: diagnostic-mode CSR readback mismatch"

        await self.wait_csr_set(
            WR_R_CSR_ARM,
            100,
            "recorder did not acknowledge ARM",
        )

    async def pulse_trigger(self, mask):
        await RisingEdge(self.dut.clk)
        self.dut.triggers.value = mask & 0xFF

        await RisingEdge(self.dut.clk)
        self.dut.triggers.value = 0

        self._check_background_tasks()

    async def wait_for_fifo_drain(self, max_cycles):
        for _ in range(max_cycles):
            await RisingEdge(self.dut.clk)
            await ReadOnly()

            fifo_count = self._read_signal(self.dut.csr2, "csr2")
            fifo_count &= self.fifo_count_mask

            self._check_background_tasks()

            if fifo_count == self.fifo_empty_count:
                await NextTimeStep()
                return

        assert False, (
            "FAIL: FIFO did not get empty before timeout: "
            f"Actual=0x{fifo_count:x}, "
            f"Expected=0x{self.fifo_empty_count:x}"
        )

    async def wait_for_axi_quiesce(self, max_cycles):
        idle_cycles = 0

        for _ in range(max_cycles):
            await RisingEdge(self.dut.clk)
            await ReadOnly()

            awvalid = self._read_signal(self.dut.axi_AWVALID, "axi_AWVALID")
            wvalid = self._read_signal(self.dut.axi_WVALID, "axi_WVALID")
            bvalid = self._read_signal(self.dut.axi_BVALID, "axi_BVALID")

            if not awvalid and not wvalid and not bvalid:
                idle_cycles += 1
            else:
                idle_cycles = 0

            self._check_background_tasks()

            if idle_cycles >= AXI_DRAIN_IDLE_CYCLES:
                await NextTimeStep()
                return

        assert False, "FAIL: AXI interface did not become quiescent before timeout"

    async def wait_for_drain(self, fifo_drain_max_cycles, axi_quiesce_max_cycles):
        await self.wait_for_fifo_drain(fifo_drain_max_cycles)
        await self.wait_for_axi_quiesce(axi_quiesce_max_cycles)

    async def finish_normal_acquisition(self):
        await self.wait_csr_clear(
            WR_R_CSR_ARM,
            50000,
            "recorder did not complete acquisition",
        )
        await self.wait_csr_set(
            WR_R_CSR_FULL,
            100,
            "FULL did not assert after completed acquisition",
        )

        csr_value = await self.read32(WR_REG_OFFSET_CSR)
        assert (csr_value & WR_R_CSR_BRESP) == 0, "FAIL: unexpected non-OKAY BRESP"
        assert (csr_value & WR_R_CSR_OVERRUN) == 0, "FAIL: unexpected FIFO overrun"

        await self.wait_for_drain(FIFO_DRAIN_MAX_CYCLES, AXI_QUIESCE_MAX_CYCLES)

    async def start_test(self, name):
        self.dut._log.info(f"--- Starting {name} ---")

        self.random_backpressure = False
        self.error_responses_left = 0
        self.score_test_mode = False
        self.sample_drive_enable = True
        self.sample_gap = 16

        self.dut.diagExtMode.value = 0
        self.dut.diagExtData.value = 0
        self.dut.triggers.value = 0

        await ClockCycles(self.dut.clk, 2)
        self._check_background_tasks()

    async def _drive_samples(self):
        data_width = len(self.dut.data)

        while True:
            await RisingEdge(self.dut.clk)

            if not self.sample_drive_enable:
                self.dut.valid.value = 0
                self.sample_gap_count = 0
                continue

            if self.sample_gap_count == 0:
                self.dut.valid.value = 1
                self.dut.data.value = self._repeated16(
                    0x1000 + self.sample_number,
                    data_width,
                )
                self.dut.testData.value = self._repeated16(
                    0xA000 ^ self.sample_number,
                    data_width,
                )
                self.sample_number = (self.sample_number + 1) & 0xFFFF
                self.sample_gap_count = self.sample_gap - 1
            else:
                self.dut.valid.value = 0
                self.dut.data.value = self._repeated16(0xDEAD, data_width)
                self.dut.testData.value = self._repeated16(0xBEEF, data_width)
                self.sample_gap_count -= 1

    async def _drive_timestamp(self):
        timestamp_mask = (1 << len(self.dut.timestamp)) - 1

        while True:
            await RisingEdge(self.dut.clk)

            timestamp = self._read_signal(self.dut.timestamp, "timestamp")
            self.dut.timestamp.value = (timestamp + 1) & timestamp_mask

    async def _axi_slave(self):
        wvalid_prev = False
        wlast_prev = False
        wready_prev = True

        while True:
            await RisingEdge(self.dut.clk)

            # Get the previous cycle values to determine this BVALID/BRESP
            # values
            wlast_handshake = wvalid_prev and wready_prev and wlast_prev

            next_bvalid = wlast_handshake
            next_bresp = 0

            if next_bvalid and self.error_responses_left > 0:
                next_bresp = 0b10
                self.error_responses_left -= 1
                self.dut._log.info(f"Injecting BRESP error {next_bresp}")

            #
            # Choose registered slave outputs for the NEXT cycle.
            #
            if self.random_backpressure:
                next_awready = (
                    self.axi_rng.randrange(100)
                    < self.config.axi_awready_percent
                )
                next_wready = (
                    self.axi_rng.randrange(100)
                    < self.config.axi_wready_percent
                )
            else:
                next_awready = True
                next_wready = True

            self.dut.axi_AWREADY.value = int(next_awready)
            self.dut.axi_WREADY.value = int(next_wready)
            self.dut.axi_BVALID.value = int(next_bvalid)
            self.dut.axi_BRESP.value = next_bresp

            # Read values for next timestep
            await ReadOnly()

            wvalid_prev = bool(
                self._read_signal(self.dut.axi_WVALID, "axi_WVALID")
            )
            wlast_prev = bool(
                self._read_signal(self.dut.axi_WLAST, "axi_WLAST")
            )
            wready_prev = next_wready

    def _capture_axi_snapshot(self):
        return {
            "awaddr": self._read_signal(self.dut.axi_AWADDR, "axi_AWADDR"),
            "awlen": self._read_signal(self.dut.axi_AWLEN, "axi_AWLEN"),
            "awvalid": bool(
                self._read_signal(self.dut.axi_AWVALID, "axi_AWVALID")
            ),
            "awready": bool(
                self._read_signal(self.dut.axi_AWREADY, "axi_AWREADY")
            ),
            "awsize": self._read_signal(self.dut.axi_AWSIZE, "axi_AWSIZE"),
            "wdata": self._read_signal(self.dut.axi_WDATA, "axi_WDATA"),
            "wlast": bool(
                self._read_signal(self.dut.axi_WLAST, "axi_WLAST")
            ),
            "wvalid": bool(
                self._read_signal(self.dut.axi_WVALID, "axi_WVALID")
            ),
            "wready": bool(
                self._read_signal(self.dut.axi_WREADY, "axi_WREADY")
            ),
            "wstrb": self._read_signal(self.dut.axi_WSTRB, "axi_WSTRB"),
        }

    def _check_axi_snapshot(self, axi):
        awaddr = axi["awaddr"]
        awlen = axi["awlen"]
        awvalid = axi["awvalid"]
        awready = axi["awready"]
        awsize = axi["awsize"]

        wdata = axi["wdata"]
        wlast = axi["wlast"]
        wvalid = axi["wvalid"]
        wready = axi["wready"]
        wstrb = axi["wstrb"]

        assert awsize == (self.axi_bytes.bit_length() - 1), (
            f"FAIL: AXI AWSIZE is incorrect: got {awsize}"
        )
        assert wstrb == ((1 << self.axi_bytes) - 1), (
            f"FAIL: AXI WSTRB is not all ones: 0x{wstrb:x}"
        )

        # Check that address-channel payload stays stable while VALID is held
        # and READY is low.  The snapshot represents a complete clock cycle.
        if awvalid:
            if self.aw_stalled:
                assert awaddr == self.stalled_awaddr, (
                    "FAIL: AWADDR changed while AWVALID was stalled"
                )
                assert awlen == self.stalled_awlen, (
                    "FAIL: AWLEN changed while AWVALID was stalled"
                )

            if not awready:
                self.stalled_awaddr = awaddr
                self.stalled_awlen = awlen
                self.aw_stalled = True
            else:
                self.aw_stalled = False
        else:
            self.aw_stalled = False

        # Same stability check for the write-data channel.
        if wvalid:
            if self.w_stalled:
                assert wdata == self.stalled_wdata, (
                    "FAIL: WDATA changed while WVALID was stalled"
                )
                assert wlast == self.stalled_wlast, (
                    "FAIL: WLAST changed while WVALID was stalled"
                )

            if not wready:
                self.stalled_wdata = wdata
                self.stalled_wlast = wlast
                self.w_stalled = True
            else:
                self.w_stalled = False
        else:
            self.w_stalled = False

        # Because this snapshot was stable immediately before the current
        # rising edge, VALID && READY means the transfer occurred on that edge.
        if awvalid and awready:
            assert not self.burst_active, (
                "FAIL: new AW accepted while prior burst is still active"
            )

            self.burst_active = True
            self.burst_beats_left = awlen + 1

            if self.score_first_aw:
                assert awaddr == self.score_base_addr, (
                    f"FAIL: first AWADDR 0x{awaddr:x} != programmed base "
                    f"0x{self.score_base_addr:x}. This usually means the "
                    f"DUT compile-time ACQ_CAPACITY does not match the "
                    f"cocotb ACQ_CAPACITY={self.config.acq_capacity}."
                )
                self.score_first_aw = False
            else:
                assert awaddr == self.expected_next_awaddr, (
                    f"FAIL: AWADDR 0x{awaddr:x} != expected "
                    f"0x{self.expected_next_awaddr:x}"
                )

            self.expected_next_awaddr = self.score_base_addr + (
                (
                    (awaddr - self.score_base_addr)
                    + ((awlen + 1) * self.axi_bytes)
                )
                % self.acq_span_bytes
            )

        if wvalid and wready:
            assert self.burst_active, (
                "FAIL: W beat accepted without an active AW burst"
            )
            assert bool(wlast) == (self.burst_beats_left == 1), (
                "FAIL: WLAST did not match AWLEN burst framing"
            )

            lane_value = wdata & 0xFFFF
            repeated_lane = self._repeated16(
                lane_value, len(self.dut.axi_WDATA)
            )
            assert wdata == repeated_lane, (
                "FAIL: AXI WDATA lanes do not contain a consistent sample value"
            )

            if not self.payload_sequence_started:
                self.payload_sequence_started = True

                if self.score_test_mode:
                    sample_number = lane_value ^ 0xA000
                else:
                    sample_number = (lane_value - 0x1000) & 0xFFFF

                self.expected_sample_number = (sample_number + 1) & 0xFFFF
            else:
                if self.score_test_mode:
                    expected_lane = 0xA000 ^ self.expected_sample_number
                else:
                    expected_lane = (0x1000 + self.expected_sample_number) & 0xFFFF

                expected_data = self._repeated16(
                    expected_lane,
                    len(self.dut.axi_WDATA),
                )
                assert wdata == expected_data, (
                    "FAIL: AXI WDATA sample sequence is discontinuous or corrupted: "
                    f"expected 0x{expected_data:x}, got 0x{wdata:x}"
                )
                self.expected_sample_number = (
                    self.expected_sample_number + 1
                ) & 0xFFFF

            self.test_axi_beats += 1

            if self.burst_beats_left == 1:
                self.burst_beats_left = 0
                self.burst_active = False
            else:
                self.burst_beats_left -= 1

    async def _monitor_axi(self):
        # 'previous' is the AXI state that was stable during the cycle leading
        # into the current rising edge.  Therefore all handshake decisions are
        # made from previous-cycle values, not from post-edge DUT outputs.
        previous = None

        while True:
            await RisingEdge(self.dut.clk)

            if previous is not None:
                self._check_axi_snapshot(previous)

            await ReadOnly()
            previous = self._capture_axi_snapshot()


async def do_basic_triggered_capture_test(tb):
    await tb.start_test("Basic Triggered Acquisition Test")

    base = tb.base_addr_for_region(4)
    await tb.program_acquisition(
        pretrig=16,
        acq_count=48,
        base_addr=base,
        csr_value=WR_W_CSR_SOFT_TRIGGER_ENABLE,
    )
    await tb.wait_csr_set(
        WR_R_CSR_PRE_TRIG_DONE,
        20000,
        "pretrigger phase did not complete",
    )
    await ClockCycles(tb.dut.clk, 40)
    await tb.pulse_trigger(0x01)
    await tb.finish_normal_acquisition()

    timestamp_seconds = await tb.read32(WR_REG_OFFSET_TIMESTAMP_SECONDS)
    timestamp_ticks = await tb.read32(WR_REG_OFFSET_TIMESTAMP_TICKS)
    assert ((timestamp_seconds << 32) | timestamp_ticks) != 0, (
        "FAIL: trigger timestamp was not captured"
    )

    tb.dut._log.info("--- Basic Triggered Acquisition Test Complete ---\n")


async def do_early_trigger_ignored_test(tb):
    await tb.start_test("Early Trigger Ignored Test")

    tb.sample_gap = 12
    base = tb.base_addr_for_region(5)
    await tb.program_acquisition(
        pretrig=12,
        acq_count=40,
        base_addr=base,
        csr_value=WR_W_CSR_SOFT_TRIGGER_ENABLE,
    )

    await tb.pulse_trigger(0x01)
    await tb.wait_csr_set(
        WR_R_CSR_PRE_TRIG_DONE,
        20000,
        "pretrigger phase did not complete",
    )
    await ClockCycles(tb.dut.clk, 80)

    csr_value = await tb.read32(WR_REG_OFFSET_CSR)
    assert csr_value & WR_R_CSR_ARM, (
        "FAIL: early trigger incorrectly completed the acquisition"
    )

    await tb.pulse_trigger(0x01)
    await tb.finish_normal_acquisition()

    tb.dut._log.info("--- Early Trigger Ignored Test Complete ---\n")


async def do_disabled_trigger_ignored_test(tb):
    await tb.start_test("Disabled Trigger Source Ignored Test")

    base = tb.base_addr_for_region(6)
    await tb.program_acquisition(
        pretrig=8,
        acq_count=32,
        base_addr=base,
        csr_value=WR_W_CSR_EVENT_TRIGGER_1_ENABLE,
    )
    await tb.wait_csr_set(
        WR_R_CSR_PRE_TRIG_DONE,
        20000,
        "pretrigger phase did not complete",
    )

    await tb.pulse_trigger(0x01)
    await ClockCycles(tb.dut.clk, 100)

    csr_value = await tb.read32(WR_REG_OFFSET_CSR)
    assert csr_value & WR_R_CSR_ARM, (
        "FAIL: disabled trigger source incorrectly fired recorder"
    )

    await tb.pulse_trigger(0x02)
    await tb.finish_normal_acquisition()

    tb.dut._log.info("--- Disabled Trigger Source Ignored Test Complete ---\n")


async def do_testdata_mode_test(tb):
    await tb.start_test("Test Acquisition Data Mode Test")

    base = tb.base_addr_for_region(7)
    await tb.program_acquisition(
        pretrig=8,
        acq_count=32,
        base_addr=base,
        csr_value=(
            WR_W_CSR_SOFT_TRIGGER_ENABLE
            | WR_W_CSR_TEST_ACQUISITION_MODE
        ),
    )
    await tb.wait_csr_set(
        WR_R_CSR_PRE_TRIG_DONE,
        20000,
        "pretrigger phase did not complete",
    )
    await ClockCycles(tb.dut.clk, 30)
    await tb.pulse_trigger(0x01)
    await tb.finish_normal_acquisition()

    assert tb.test_axi_beats > 0, "FAIL: test mode produced no AXI data"

    tb.dut._log.info("--- Test Acquisition Data Mode Test Complete ---\n")


async def do_axi_backpressure_test(tb):
    await tb.start_test("AXI AW/W Backpressure Test")

    tb.random_backpressure = True
    tb.sample_gap = 16
    base = tb.base_addr_for_region(8)

    await tb.program_acquisition(
        pretrig=16,
        acq_count=48,
        base_addr=base,
        csr_value=WR_W_CSR_SOFT_TRIGGER_ENABLE,
    )
    await tb.wait_csr_set(
        WR_R_CSR_PRE_TRIG_DONE,
        30000,
        "pretrigger phase did not complete under backpressure",
    )
    await ClockCycles(tb.dut.clk, 80)
    await tb.pulse_trigger(0x01)
    await tb.finish_normal_acquisition()

    tb.random_backpressure = False
    tb.dut._log.info("--- AXI AW/W Backpressure Test Complete ---\n")


async def do_zero_pretrigger_test(tb):
    await tb.start_test("Zero Pretrigger Acquisition Test")

    tb.sample_gap = 14
    base = tb.base_addr_for_region(10)
    await tb.program_acquisition(
        pretrig=0,
        acq_count=16,
        base_addr=base,
        csr_value=WR_W_CSR_SOFT_TRIGGER_ENABLE,
    )
    await tb.wait_csr_set(
        WR_R_CSR_PRE_TRIG_DONE,
        5000,
        "zero-pretrigger case did not report trigger-ready",
    )
    await tb.pulse_trigger(0x01)
    await tb.finish_normal_acquisition()

    tb.dut._log.info("--- Zero Pretrigger Acquisition Test Complete ---\n")


async def do_circular_address_wrap_test(tb):
    await tb.start_test("Circular Acquisition Address Wrap Test")

    tb.sample_gap = 12
    base = tb.base_addr_for_region(11)
    await tb.program_acquisition(
        pretrig=8,
        acq_count=32,
        base_addr=base,
        csr_value=WR_W_CSR_SOFT_TRIGGER_ENABLE,
    )
    await tb.wait_csr_set(
        WR_R_CSR_PRE_TRIG_DONE,
        20000,
        "pretrigger phase did not complete",
    )

    target_beats = tb.config.acq_capacity + 32
    for _ in range(50000):
        if tb.test_axi_beats >= target_beats:
            break

        await RisingEdge(tb.dut.clk)
        tb._check_background_tasks()
    else:
        assert False, "FAIL: did not observe enough AXI beats to test address wrap"

    await tb.pulse_trigger(0x01)
    await tb.finish_normal_acquisition()

    assert tb.test_axi_beats > tb.config.acq_capacity, (
        "FAIL: address-wrap test did not emit more than one acquisition span"
    )

    tb.dut._log.info("--- Circular Acquisition Address Wrap Test Complete ---\n")


async def do_bresp_error_test(tb):
    await tb.start_test("AXI BRESP Error Abort Test")

    tb.sample_gap = 10
    tb.error_responses_left = 1
    base = tb.base_addr_for_region(9)

    await tb.program_acquisition(
        pretrig=32,
        acq_count=128,
        base_addr=base,
        csr_value=WR_W_CSR_SOFT_TRIGGER_ENABLE,
    )

    await tb.wait_csr_clear(
        WR_R_CSR_ARM,
        30000,
        "BRESP error did not abort acquisition",
    )
    await tb.wait_csr_set(
        0x00000040,
        100,
        "SLVERR BRESP was not reflected in CSR",
    )

    csr_value = await tb.read32(WR_REG_OFFSET_CSR)
    assert (csr_value & WR_R_CSR_FULL) == 0, (
        "FAIL: FULL should not assert for a BRESP-aborted acquisition"
    )

    await tb.wait_for_drain(FIFO_DRAIN_MAX_CYCLES, AXI_QUIESCE_MAX_CYCLES)

    tb.dut._log.info("--- AXI BRESP Error Abort Test Complete ---\n")


async def do_pseudo_constrained_test(tb):
    await tb.start_test("Pseudo-Constrained Acquisition Tests")

    tb.random_backpressure = True

    for iteration in range(tb.config.random_iters):
        pretrig = tb.stim_rng.randint(8, 24)
        acq_count = pretrig + tb.stim_rng.randint(16, 48)
        sample_gap = tb.stim_rng.randint(10, 20)
        trigger_wait = tb.stim_rng.randint(16, 120)
        region = tb.stim_rng.randint(3, 12)
        base = tb.base_addr_for_region(region)

        if tb.stim_rng.randint(0, 1) == 0:
            trigger_mask = 0x01
            trigger_enable = WR_W_CSR_SOFT_TRIGGER_ENABLE
        else:
            trigger_mask = 0x02
            trigger_enable = WR_W_CSR_EVENT_TRIGGER_1_ENABLE

        tb.sample_gap = sample_gap
        tb.dut._log.info(
            f"Pseudo-constrained test #{iteration + 1}: "
            f"pre={pretrig} acq={acq_count} gap={sample_gap} "
            f"trig=0x{trigger_mask:02x} wait={trigger_wait} "
            f"base=0x{base:x}"
        )

        await tb.program_acquisition(
            pretrig=pretrig,
            acq_count=acq_count,
            base_addr=base,
            csr_value=trigger_enable,
        )
        await tb.wait_csr_set(
            WR_R_CSR_PRE_TRIG_DONE,
            30000,
            "pseudo-constrained case did not finish pretrigger",
        )
        await ClockCycles(tb.dut.clk, trigger_wait)
        await tb.pulse_trigger(trigger_mask)
        await tb.finish_normal_acquisition()

    tb.random_backpressure = False
    tb.dut._log.info("--- Pseudo-Constrained Acquisition Tests Complete ---\n")


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def execute_normal_tests(dut):
    config = RegressionConfig.from_environment()
    tb = TB(dut, config)

    dut._log.info(f"Regression seed: {config.seed}")
    dut._log.info(
        "AXI READY high percentages: "
        f"AW={config.axi_awready_percent}% "
        f"W={config.axi_wready_percent}%"
    )
    dut._log.info(f"Pseudo-constrained iterations: {config.random_iters}")
    dut._log.info(f"Test FIFO_CAPACITY: {config.fifo_capacity}")
    dut._log.info(
        f"Test ACQ_CAPACITY: {config.acq_capacity} "
        "(must match the DUT compile-time ACQ_CAPACITY parameter)"
    )
    dut._log.info(
        f"Test FIFO_CAPACITY: {config.fifo_capacity} "
        "(must match the DUT compile-time FIFO_CAPACITY parameter)"
    )

    await ClockCycles(dut.sysClk, 8)

    # Tests themselves
    await do_basic_triggered_capture_test(tb)
    await do_early_trigger_ignored_test(tb)
    await do_disabled_trigger_ignored_test(tb)
    await do_testdata_mode_test(tb)
    await do_axi_backpressure_test(tb)
    await do_zero_pretrigger_test(tb)
    await do_bresp_error_test(tb)
    await do_pseudo_constrained_test(tb)

    tb.sample_drive_enable = False
    await ClockCycles(dut.sysClk, 20)
    tb._check_background_tasks()

    dut._log.info("--- All genericWaveformRecorder Tests Complete ---")


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def execute_address_wrap_test(dut):
    config = RegressionConfig.from_environment()
    tb = TB(dut, config)

    dut._log.info(f"Test FIFO_CAPACITY: {config.fifo_capacity}")
    dut._log.info(
        f"Address-wrap ACQ_CAPACITY: {config.acq_capacity} "
        "(must match the DUT compile-time ACQ_CAPACITY parameter)"
    )

    await ClockCycles(dut.sysClk, 8)

    await do_circular_address_wrap_test(tb)

    tb.sample_drive_enable = False
    await ClockCycles(dut.sysClk, 20)
    tb._check_background_tasks()

    dut._log.info("--- Address-wrap test Complete ---")
