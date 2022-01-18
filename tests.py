import numpy as np
import coalpy.gpu as gpu

from enum import Enum

# emulation kernels
s_get_lane_count = gpu.Shader(file="WaveEmulationTests.hlsl", name="GetLaneCount", main_function="Main", defines=["TEST_ID=0"])
s_get_lane_index = gpu.Shader(file="WaveEmulationTests.hlsl", name="GetLaneIndex", main_function="Main", defines=["TEST_ID=1"])
s_is_first_lane  = gpu.Shader(file="WaveEmulationTests.hlsl", name="IsFirstLane",  main_function="Main", defines=["TEST_ID=2"])

WAVE_SIZE = 32

NUM_WAVE = 2


def create_buffer(size, fmt=gpu.Format.R32_UINT):
    return gpu.Buffer(format=fmt, element_count=size)


def resolve_buffer(buffer, type):
    request = gpu.ResourceDownloadRequest(buffer)
    request.resolve()
    return np.frombuffer(request.data_as_bytearray(), dtype=type)


# query
# ---------------------------------------------------
def get_lane_count():
    cmd = gpu.CommandList()

    output = create_buffer(2)

    cmd.dispatch(
        x=1,
        shader=s_get_lane_count,
        outputs=output
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')

    return result[0] == result[1]


def get_lane_index():
    cmd = gpu.CommandList()

    output   = create_buffer(NUM_WAVE * WAVE_SIZE)
    output_e = create_buffer(NUM_WAVE * WAVE_SIZE)

    cmd.dispatch(
        x=1,
        shader=s_get_lane_index,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result   = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def is_first_lane():
    cmd = gpu.CommandList()

    output   = create_buffer(NUM_WAVE * WAVE_SIZE)
    output_e = create_buffer(NUM_WAVE * WAVE_SIZE)

    cmd.dispatch(
        x=1,
        shader=s_is_first_lane,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result   = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


# vote
# ---------------------------------------------------
def active_any_true():
    pass


def active_all_true():
    pass


def active_ballot():
    pass


# broadcast
# ---------------------------------------------------
def read_lane_at():
    pass


def read_lane_first():
    pass


# reduction
# ---------------------------------------------------
def active_all_equal():
    pass


def active_bit_and():
    pass


def active_bit_or():
    pass


def active_bit_xor():
    pass


def active_count_bits():
    pass


def active_max():
    pass


def active_min():
    pass


def active_product():
    pass


def active_sum():
    pass


# scan & prefix
# ---------------------------------------------------
def prefix_count_bits():
    pass


def prefix_sum():
    pass


def prefix_product():
    pass
