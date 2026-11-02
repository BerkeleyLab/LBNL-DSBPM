import os
from pathlib import Path

from cocotb_tools.runner import get_runner

THIS_PATH = Path(__file__).resolve().parent
MODULES_PATH = THIS_PATH / ".."

NUM_SIGNALS   = 4
USER_WIDTH    = 1
SIGNAL_WIDTH  = 32
OFFSET_WIDTH  = 32

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
    num_signals,
    user_width,
    signal_width,
    offset_width,
    testcase,
    build_name,
):
    sim = os.getenv("SIM", "verilator")

    sources = [
        MODULES_PATH / "subOffset.v",
    ]

    build_dir = THIS_PATH / "sim_build" / build_name

    runner = get_runner(sim)

    runner.build(
        sources=sources,
        hdl_toplevel="subOffset",
        parameters={
            "NUM_SIGNALS": num_signals,
            "USER_WIDTH": user_width,
            "SIGNAL_WIDTH": signal_width,
            "OFFSET_WIDTH": offset_width,
        },
        build_dir=build_dir,
        build_args=VERILATOR_COMPILE_ARGS,
        always=True,
        waves=True,
    )

    runner.test(
        hdl_toplevel="subOffset",
        test_module="subOffset_test",
        testcase=testcase,
        build_dir=build_dir,
        elab_args=VERILATOR_SIM_ARGS,
        test_args=VERILATOR_SIM_ARGS,
        extra_env={
            # Keep Python scoreboard geometry identical to HDL.
            "NUM_SIGNALS": str(num_signals),
            "USER_WIDTH": str(user_width),
            "SIGNAL_WIDTH": str(signal_width),
            "OFFSET_WIDTH": str(offset_width),
            "SEED": os.getenv("SEED", "0x51A72026"),
            "RANDOM_ITERS": os.getenv("RANDOM_ITERS", "20"),
        },
        waves=True,
    )

def test_sub_offset():
    run_test(
        num_signals=NUM_SIGNALS,
        signal_width=SIGNAL_WIDTH,
        user_width=USER_WIDTH,
        offset_width=OFFSET_WIDTH,
        testcase="execute_normal_tests",
        build_name="sub_offset",
    )

if __name__ == "__main__":
    test_sub_offset()
