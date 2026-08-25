import logging
import os
import random
from collections import deque
from dataclasses import dataclass
from typing import Deque, Iterable, Sequence, Tuple

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import (
    NextTimeStep,
    ReadOnly,
    RisingEdge,
    ClockCycles
)
from cocotb.types import LogicArray

MAX_WAIT_CYCLES = 64

@dataclass(frozen=True)
class Config:
    seed: int
    random_iters: int
    num_signals: int
    signal_width: int
    offset_width: int

    @classmethod
    def from_environment(cls):
        config = cls(
            seed=int(os.getenv("SEED", "0x51A72026"), 0),
            random_iters=int(os.getenv("RANDOM_ITERS", "20"), 0),
            num_signals=int(os.getenv("NUM_SIGNALS", "4"), 0),
            signal_width=int(os.getenv("SIGNAL_WIDTH", "32"), 0),
            offset_width=int(os.getenv("OFFSET_WIDTH", "32"), 0),
        )

        assert config.random_iters > 0, "RANDOM_ITERS must be greater than zero"
        assert config.num_signals > 0, "NUM_SIGNALS must be greater than zero"
        assert config.signal_width > 0, "SIGNAL_WIDTH must be greater than zero"
        assert config.offset_width > 0, "OFFSET_WIDTH must be greater than zero"

        return config


@dataclass(frozen=True)
class ExpectedResult:
    signal_out: Tuple[int, ...]
    label: str


def signed_limits(width: int) -> Tuple[int, int]:
    """Return the minimum and maximum values for a signed value of width bits."""
    return -(1 << (width - 1)), (1 << (width - 1)) - 1


def pack_signed(values: Iterable[int], width: int) -> int:
    """Pack signed lane values into the DUT's little-lane-order input bus."""
    mask = (1 << width) - 1
    packed = 0
    for lane, value in enumerate(values):
        packed |= (value & mask) << (lane * width)
    return packed


def unpack_signed(packed: int, width: int, count: int) -> Tuple[int, ...]:
    """Unpack a bus into signed lane values, with lane zero in the LSBs."""
    mask = (1 << width) - 1
    sign_bit = 1 << (width - 1)
    values = []

    for lane in range(count):
        value = (packed >> (lane * width)) & mask
        if value & sign_bit:
            value -= 1 << width
        values.append(value)

    return tuple(values)


def saturate(value: int, width: int) -> int:
    """Saturate value to the range of a width-bit signed output."""
    minimum, maximum = signed_limits(width)
    return min(max(value, minimum), maximum)


class SubOffsetScoreboard:
    """Cycle-accurate reference model for the two-stage subOffset pipeline."""

    def __init__(self, dut, config: Config):
        self.dut = dut
        self.config = config
        self.checked = 0

        # Queue of expected values
        self._expected: Deque[ExpectedResult] = deque()

    def add_expected(
        self,
        signal_in: Sequence[int],
        offset_in: Sequence[int],
        label: str,
    ) -> None:
        """Predict and enqueue the result for one pair of arithmetic inputs."""
        assert len(signal_in) == self.config.num_signals
        assert len(offset_in) == self.config.num_signals

        # calculate expected value for all input slices
        expected = tuple(
            saturate(signal - offset, self.config.signal_width)
            for signal, offset in zip(signal_in, offset_in)
        )
        self._expected.append(ExpectedResult(expected, label))

    def check_output(self) -> None:
        assert self._expected, "Scoreboard underflow"

        expected = self._expected.popleft()
        actual = unpack_signed(
            int(self.dut.signalOut.value),
            self.config.signal_width,
            self.config.num_signals,
        )

        errors = []
        for lane, (actual_value, expected_value) in enumerate(
            zip(actual, expected.signal_out)
        ):
            if actual_value != expected_value:
                errors.append(
                    f"lane {lane}: expected {expected_value}, got {actual_value}"
                )

        assert not errors, f"{expected.label}: " + "; ".join(errors)
        self.checked += 1

    @property
    def pending(self) -> int:
        return len(self._expected)


class TB:
    def __init__(self, dut, config: Config):
        dut._log.setLevel(logging.INFO)
        self.dut = dut
        self.config = config
        self.rng = random.Random(config.seed)
        self.scoreboard = SubOffsetScoreboard(dut, config)

        self.dut.validIn.value = 0
        self.dut.signalIn.value = 0
        self.dut.offsetIn.value = 0

        cocotb.start_soon(Clock(dut.clk, 8, unit="ns").start())
        self.monitor_task = cocotb.start_soon(self._monitor_task())

    async def _monitor_task(self) -> None:
        while True:
            await RisingEdge(self.dut.clk)
            await ReadOnly()

            if self.dut.validOut.value == 0:
                continue

            self.scoreboard.check_output()

    def _check_background_tasks(self):
        tasks = (
            ("monitor task", self.monitor_task),
        )

        for name, task in tasks:
            if task.done():
                try:
                    task.result()
                except Exception as exc:
                    raise AssertionError(f"FAIL: {name} failed: {exc}") from exc

                raise AssertionError(f"FAIL: {name} stopped unexpectedly")

    def _validate_inputs(
        self,
        signal_in: Sequence[int],
        offset_in: Sequence[int],
    ) -> None:
        assert len(signal_in) == self.config.num_signals
        assert len(offset_in) == self.config.num_signals

        signal_min, signal_max = signed_limits(self.config.signal_width)
        offset_min, offset_max = signed_limits(self.config.offset_width)
        assert all(signal_min <= value <= signal_max for value in signal_in)
        assert all(offset_min <= value <= offset_max for value in offset_in)

    async def drive_sample(
        self,
        signal_in: Sequence[int],
        offset_in: Sequence[int],
        label: str,
    ) -> None:
        """Drive one operation"""
        self._validate_inputs(signal_in, offset_in)
        self.scoreboard.add_expected(signal_in, offset_in, label)

        self.dut.signalIn.value = pack_signed(signal_in, self.config.signal_width)
        self.dut.offsetIn.value = pack_signed(offset_in, self.config.offset_width)
        self.dut.validIn.value = 1

        await RisingEdge(self.dut.clk)

        dead_signal = "X" *self.config.signal_width *self.config.num_signals
        dead_offset = "X" *self.config.offset_width *self.config.num_signals

        self.dut.signalIn.value = LogicArray(dead_signal)
        self.dut.offsetIn.value = LogicArray(dead_offset)
        self.dut.validIn.value = 0

        self._check_background_tasks()

    async def start_test(self, name):
        self.dut._log.info(f"--- Starting {name} ---")

        self.dut.signalIn.value = 0
        self.dut.offsetIn.value = 0
        self.dut.validIn.value = 0

        await ClockCycles(self.dut.clk, 2)
        self._check_background_tasks()

    async def wait_for_drain(self, max_cycles):
        for _ in range(max_cycles):
            await RisingEdge(self.dut.clk)
            await ReadOnly()

            self._check_background_tasks()

            if self.scoreboard.pending:
                continue

            if not self.scoreboard.pending:
                await NextTimeStep()
                return

        assert False, (
            "Scoreboard: did not get empty before timeout"
        )

    def constrained_signed(self, width: int) -> int:
        """Generate legal signed data with extra weight on useful boundaries."""
        minimum, maximum = signed_limits(width)
        boundary_values = tuple(
            value
            for value in (
                minimum,
                minimum + 1,
                -1,
                0,
                1,
                maximum - 1,
                maximum,
            )
            if minimum <= value <= maximum
        )

        # Half of the samples target a boundary; the other half cover the
        # complete legal input range uniformly.
        if self.rng.randrange(2):
            return self.rng.choice(boundary_values)
        return self.rng.randint(minimum, maximum)


async def do_min_max_test(tb: TB) -> None:
    """Drive all min/max combinations through every arithmetic lane."""

    await tb.start_test("Min-Max Test")

    signal_min, signal_max = signed_limits(tb.config.signal_width)
    offset_min, offset_max = signed_limits(tb.config.offset_width)
    combinations = (
        (signal_min, offset_min),
        (signal_min, offset_max),
        (signal_max, offset_min),
        (signal_max, offset_max),
    )

    # Rotating the combinations makes each packed lane see every combination
    # and simultaneously verifies that lane packing and isolation are correct.
    for vector_index in range(len(combinations)):
        lane_pairs = tuple(
            combinations[(vector_index + lane) % len(combinations)]
            for lane in range(tb.config.num_signals)
        )
        signal_in = tuple(pair[0] for pair in lane_pairs)
        offset_in = tuple(pair[1] for pair in lane_pairs)
        await tb.drive_sample(
            signal_in,
            offset_in,
            f"directed min/max vector {vector_index}",
        )

    await tb.wait_for_drain(MAX_WAIT_CYCLES)

async def do_pseudo_random_constrained_test(tb: TB) -> None:
    """Drive deterministic, pseudo-random inputs."""

    await tb.start_test("Pseudo-Random Constrained Test")

    for iteration in range(tb.config.random_iters):
        signal_in = tuple(
            tb.constrained_signed(tb.config.signal_width)
            for _ in range(tb.config.num_signals)
        )
        offset_in = tuple(
            tb.constrained_signed(tb.config.offset_width)
            for _ in range(tb.config.num_signals)
        )
        await tb.drive_sample(
            signal_in,
            offset_in,
            f"pseudo-random vector {iteration}",
        )

    await tb.wait_for_drain(MAX_WAIT_CYCLES)


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def execute_normal_tests(dut):
    config = Config.from_environment()
    tb = TB(dut, config)

    dut._log.info(f"Regression seed: 0x{config.seed:X}")
    dut._log.info(f"Pseudo-random constrained iterations: {config.random_iters}")
    dut._log.info(
        f"NUM_SIGNALS={config.num_signals} SIGNAL_WIDTH={config.signal_width} OFFSET_WIDTH={config.offset_width}"
    )

    await ClockCycles(tb.dut.clk, 8)

    await do_min_max_test(tb)
    await do_pseudo_random_constrained_test(tb)

    assert tb.scoreboard.pending == 0
    dut._log.info(
        "--- All subOffset tests complete: %d outputs checked ---",
        tb.scoreboard.checked,
    )
