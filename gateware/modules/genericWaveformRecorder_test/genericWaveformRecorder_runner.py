import os
from pathlib import Path

from cocotb_tools.runner import get_runner

PRODUCTION_ACQ_CAPACITY = 1 << 23
WRAP_TEST_ACQ_CAPACITY = 1024
FIFO_CAPACITY = 256

THIS_PATH = Path(__file__).resolve().parent
MODULES_PATH = THIS_PATH / ".."
BEDROCK_PATH = THIS_PATH / ".." / ".." / "submodules" / "bedrock"
BEDORCK_DSP_PATH = BEDROCK_PATH / "dsp"

VERILATOR_COMPILE_ARGS = [
    "--timing",
    "-Wno-width",
    "-Wno-pinmissing",
    "-trace",
    "-trace-fst",
    "-trace-structs",
]

VERILATOR_SIM_ARGS = [
    "-Wno-width",
    "-Wno-pinmissing",
    "-trace",
    "-trace-fst",
    "-trace-structs",
]

def run_test(
    *,
    acq_capacity,
    fifo_capacity,
    testcase,
    build_name,
):
    sim = os.getenv("SIM", "verilator")

    sources = [
        BEDORCK_DSP_PATH / "fifo.v",
        MODULES_PATH / "genericFifo.v",
        MODULES_PATH / "forwardData.v",
        MODULES_PATH / "genericWaveformRecorder.v",
    ]

    build_dir = THIS_PATH / "sim_build" / build_name

    runner = get_runner(sim)

    runner.build(
        sources=sources,
        hdl_toplevel="genericWaveformRecorder",
        parameters={
            "ACQ_CAPACITY": acq_capacity,
            "FIFO_CAPACITY": fifo_capacity,
        },
        build_dir=build_dir,
        build_args=VERILATOR_COMPILE_ARGS,
        always=True,
        waves=True,
    )

    runner.test(
        hdl_toplevel="genericWaveformRecorder",
        test_module="genericWaveformRecorder_test",
        testcase=testcase,
        build_dir=build_dir,
        elab_args=VERILATOR_SIM_ARGS,
        test_args=VERILATOR_SIM_ARGS,
        extra_env={
            # Keep Python scoreboard geometry identical to HDL.
            "ACQ_CAPACITY": str(acq_capacity),
            "FIFO_CAPACITY": str(fifo_capacity),
            "SEED": os.getenv("SEED", "0x51A72026"),
            "RANDOM_ITERS": os.getenv("RANDOM_ITERS", "5"),
            "AXI_AWREADY_PERCENT": os.getenv(
                "AXI_AWREADY_PERCENT", "75"
            ),
            "AXI_WREADY_PERCENT": os.getenv(
                "AXI_WREADY_PERCENT", "75"
            ),
        },
        waves=True,
    )

def test_generic_waveform_recorder():
    run_test(
        acq_capacity=PRODUCTION_ACQ_CAPACITY,
        fifo_capacity=FIFO_CAPACITY,
        testcase="execute_normal_tests",
        build_name="production_capacity",
    )

    run_test(
        acq_capacity=WRAP_TEST_ACQ_CAPACITY,
        fifo_capacity=FIFO_CAPACITY,
        testcase="execute_address_wrap_test",
        build_name="wrap_capacity",
    )


if __name__ == "__main__":
    test_generic_waveform_recorder()
