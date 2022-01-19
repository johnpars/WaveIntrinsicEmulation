import random
import numpy as np
import coalpy.gpu as gpu

from enum import Enum

# emulation kernels
s_get_lane_count    = gpu.Shader(file="WaveEmulationTests.hlsl", name="GetLaneCount",    main_function="Main", defines=["TEST=0"])
s_get_lane_index    = gpu.Shader(file="WaveEmulationTests.hlsl", name="GetLaneIndex",    main_function="Main", defines=["TEST=1"])
s_is_first_lane     = gpu.Shader(file="WaveEmulationTests.hlsl", name="IsFirstLane",     main_function="Main", defines=["TEST=2"])
s_active_any_true   = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveAnyTrue",   main_function="Main", defines=["TEST=3"])
s_active_all_true   = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveAllTrue",   main_function="Main", defines=["TEST=4"])
s_active_ballot     = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBallot",    main_function="Main", defines=["TEST=5"])
s_read_lane_at      = gpu.Shader(file="WaveEmulationTests.hlsl", name="ReadLaneAt",      main_function="Main", defines=["TEST=6"])
s_read_lane_first   = gpu.Shader(file="WaveEmulationTests.hlsl", name="ReadLaneFirst",   main_function="Main", defines=["TEST=7"])
s_active_all_equal  = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveAllEqual",  main_function="Main", defines=["TEST=8"])
s_active_bit_and    = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBitAnd",    main_function="Main", defines=["TEST=9"])
s_active_bit_or     = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBitOr",     main_function="Main", defines=["TEST=10"])
s_active_bit_xor    = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBitXor",    main_function="Main", defines=["TEST=11"])
s_active_count_bits = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveCountBits", main_function="Main", defines=["TEST=12"])
s_active_max        = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveMax",       main_function="Main", defines=["TEST=13"])
s_active_min        = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveMin",       main_function="Main", defines=["TEST=14"])
s_active_product    = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveProduct",   main_function="Main", defines=["TEST=15"])
s_active_sum        = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveSum",       main_function="Main", defines=["TEST=16"])


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
    data = np.repeat(0.31512, NUM_WAVE * WAVE_SIZE)
    data_gpu = create_buffer(NUM_WAVE * WAVE_SIZE, gpu.Format.R32_FLOAT)

    output = create_buffer(NUM_WAVE)
    output_e = create_buffer(NUM_WAVE)

    cmd = gpu.CommandList()

    cmd.upload_resource(
        source=data.astype('float32'),
        destination=data_gpu
    )

    cmd.dispatch(
        x=1,
        shader=s_active_all_equal,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_bit_and():
    data = np.repeat(3125, NUM_WAVE * WAVE_SIZE)
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
        shader=s_active_bit_and,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_bit_or():
    data = np.repeat(1234, NUM_WAVE * WAVE_SIZE)
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
        shader=s_active_bit_or,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_bit_xor():
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
        shader=s_active_bit_xor,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_count_bits():
    data = np.random.randint(0, 10000, NUM_WAVE * WAVE_SIZE)
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
        shader=s_active_count_bits,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_max():
    data = np.random.randint(0, 10000, NUM_WAVE * WAVE_SIZE)
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
        shader=s_active_max,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_min():
    data = np.random.randint(0, 10000, NUM_WAVE * WAVE_SIZE)
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
        shader=s_active_min,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_product():
    data = np.random.randint(1, 3, NUM_WAVE * WAVE_SIZE)
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
        shader=s_active_product,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


def active_sum():
    data = np.random.randint(0, 500, NUM_WAVE * WAVE_SIZE)
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
        shader=s_active_sum,
        inputs=data_gpu,
        outputs=[
            output,
            output_e
        ]
    )

    gpu.schedule(cmd)

    result = resolve_buffer(output, 'i')
    result_e = resolve_buffer(output_e, 'i')

    return np.array_equal(result, result_e)


# scan & prefix
# ---------------------------------------------------
def prefix_count_bits():
    pass


def prefix_sum():
    pass


def prefix_product():
    pass
