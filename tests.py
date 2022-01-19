import random
import numpy as np
import coalpy.gpu as gpu

from enum import Enum

# emulation kernels
s_get_lane_count = gpu.Shader(file="WaveEmulationTests.hlsl", name="GetLaneCount", main_function="Main", defines=["TEST_ID=0"])
s_get_lane_index = gpu.Shader(file="WaveEmulationTests.hlsl", name="GetLaneIndex", main_function="Main", defines=["TEST_ID=1"])
s_is_first_lane  = gpu.Shader(file="WaveEmulationTests.hlsl", name="IsFirstLane",  main_function="Main", defines=["TEST_ID=2"])
s_active_any_true = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveAnyTrue", main_function="Main", defines=["TEST_ID=3"])
s_active_all_true = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveAllTrue", main_function="Main", defines=["TEST_ID=4"])
s_active_ballot = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBallot", main_function="Main", defines=["TEST_ID=5"])
s_read_lane_at = gpu.Shader(file="WaveEmulationTests.hlsl", name="ReadLaneAt", main_function="Main", defines=["TEST_ID=6"])
s_read_lane_first = gpu.Shader(file="WaveEmulationTests.hlsl", name="ReadLaneAt", main_function="Main", defines=["TEST_ID=7"])

WAVE_SIZE = 32
NUM_WAVE  = 16


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
    data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
    data_gpu = create_buffer(NUM_WAVE * WAVE_SIZE)

    output   = create_buffer(NUM_WAVE)
    output_e = create_buffer(NUM_WAVE)

    cmd = gpu.CommandList()

    cmd.upload_resource(
        source=data,
        destination=data_gpu
    )

    cmd.dispatch(
        x=1,
        shader=s_active_any_true,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ],
        constants=np.array([
            975
        ])
    )

    gpu.schedule(cmd)

    result   = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_all_true():
    data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
    data_gpu = create_buffer(NUM_WAVE * WAVE_SIZE)

    output   = create_buffer(NUM_WAVE)
    output_e = create_buffer(NUM_WAVE)

    cmd = gpu.CommandList()

    cmd.upload_resource(
        source=data,
        destination=data_gpu
    )

    cmd.dispatch(
        x=1,
        shader=s_active_all_true,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ],
        constants=np.array([
            15
        ])
    )

    gpu.schedule(cmd)

    result   = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_ballot():
    data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
    data_gpu = create_buffer(NUM_WAVE * WAVE_SIZE)

    output = create_buffer(NUM_WAVE)
    output_e = create_buffer(NUM_WAVE)

    cmd = gpu.CommandList()

    cmd.upload_resource(
        source=data,
        destination=data_gpu
    )

    cmd.dispatch(
        x=1,
        shader=s_active_ballot,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ],
        constants=np.array([
            500
        ])
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


# broadcast
# ---------------------------------------------------
def read_lane_at():
    data = np.random.rand(NUM_WAVE * WAVE_SIZE)
    data_gpu = create_buffer(NUM_WAVE * WAVE_SIZE, gpu.Format.R32_FLOAT)

    output = create_buffer(NUM_WAVE, gpu.Format.R32_FLOAT)
    output_e = create_buffer(NUM_WAVE, gpu.Format.R32_FLOAT)

    cmd = gpu.CommandList()

    cmd.upload_resource(
        source=data.astype('float32'),
        destination=data_gpu
    )

    cmd.dispatch(
        x=1,
        shader=s_read_lane_at,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ],
        constants=np.array([
            random.randint(0, 31)
        ])
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'f')
    result_e = resolve_buffer(output_e, 'f')

    return np.array_equal(result, result_e)


def read_lane_first():
    data = np.random.rand(NUM_WAVE * WAVE_SIZE)
    data_gpu = create_buffer(NUM_WAVE * WAVE_SIZE, gpu.Format.R32_FLOAT)

    output = create_buffer(NUM_WAVE, gpu.Format.R32_FLOAT)
    output_e = create_buffer(NUM_WAVE, gpu.Format.R32_FLOAT)

    cmd = gpu.CommandList()

    cmd.upload_resource(
        source=data.astype('float32'),
        destination=data_gpu
    )

    cmd.dispatch(
        x=1,
        shader=s_read_lane_first,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'f')
    result_e = resolve_buffer(output_e, 'f')

    return np.array_equal(result, result_e)


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
