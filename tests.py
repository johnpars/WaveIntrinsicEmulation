import random
import numpy as np
import coalpy.gpu as gpu

# kernels
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
s_prefix_count_bits = gpu.Shader(file="WaveEmulationTests.hlsl", name="PrefixCountBits", main_function="Main", defines=["TEST=17"])


WAVE_SIZE = 16
NUM_WAVE  = 8


def resolve_buffer(buffer, type):
    request = gpu.ResourceDownloadRequest(buffer)
    request.resolve()
    return np.frombuffer(request.data_as_bytearray(), dtype=type)


def dispatch_test(data, b_data, b_output, b_output_e, constants, test_kernel):
    cmd = gpu.CommandList()

    if data is not None:
        cmd.upload_resource(data, b_data)

    if constants is None:
        constants = []

    cmd.dispatch(
        x=1,
        inputs=b_data,
        shader=test_kernel,
        outputs=[
            b_output,
            b_output_e
        ],
        constants=constants
    )

    gpu.schedule(cmd)

    result0 = resolve_buffer(b_output,   'i')
    result1 = resolve_buffer(b_output_e, 'i')

    return np.array_equal(result0, result1)


def dispatch_test_no_input(b_output, b_output_e, test_kernel):
    return dispatch_test(None, None, b_output, b_output_e, None, test_kernel)


class WaveEmulationTestSuite:

    def __init__(self):

        self.b_input = gpu.Buffer(
            type=gpu.BufferType.Standard,
            format=gpu.Format.R32_UINT,
            element_count=WAVE_SIZE * NUM_WAVE
        )

        self.b_output_wave = gpu.Buffer(
            type=gpu.BufferType.Standard,
            format=gpu.Format.R32_UINT,
            element_count=NUM_WAVE
        )

        self.b_output_wave_e = gpu.Buffer(
            type=gpu.BufferType.Standard,
            format=gpu.Format.R32_UINT,
            element_count=NUM_WAVE
        )

        self.b_output_lane = gpu.Buffer(
            type=gpu.BufferType.Standard,
            format=gpu.Format.R32_UINT,
            element_count=NUM_WAVE * WAVE_SIZE
        )

        self.b_output_lane_e = gpu.Buffer(
            type=gpu.BufferType.Standard,
            format=gpu.Format.R32_UINT,
            element_count=NUM_WAVE * WAVE_SIZE
        )

    # query
    # ---------------------------------------------------
    def get_lane_count(self):
        return dispatch_test_no_input(self.b_output_wave, self.b_output_wave_e, s_get_lane_count)

    def get_lane_index(self):
        return dispatch_test_no_input(self.b_output_lane, self.b_output_lane_e, s_get_lane_index)

    def is_first_lane(self):
        return dispatch_test_no_input(self.b_output_lane, self.b_output_lane_e, s_is_first_lane)

    # vote
    # ---------------------------------------------------
    def active_any_true(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_any_true)

    def active_all_true(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_all_true)

    def active_ballot(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, np.array([500]), s_active_ballot)

    # broadcast
    # ---------------------------------------------------
    def read_lane_at(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, np.array([random.randint(0, WAVE_SIZE - 1)]), s_read_lane_at)

    def read_lane_first(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_read_lane_first)

    # reduction
    # ---------------------------------------------------
    def active_all_equal(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_all_equal)

    def active_bit_and(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_bit_and)

    def active_bit_or(self):
        data = np.repeat(1234, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_bit_or)

    def active_bit_xor(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_bit_xor)

    def active_count_bits(self):
        data = np.random.randint(0, 10000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_count_bits)

    def active_max(self):
        data = np.random.randint(100, 10000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_max)

    def active_min(self):
        data = np.random.randint(100, 10000, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_min)

    def active_product(self):
        data = np.random.randint(1, 3, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_product)


    def active_sum(self):
        data = np.random.randint(2, 510, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_wave, self.b_output_wave_e, None, s_active_sum)

    # scan & prefix
    # ---------------------------------------------------
    def prefix_count_bits(self):
        data = np.random.randint(0, 2, NUM_WAVE * WAVE_SIZE)
        return dispatch_test(data, self.b_input, self.b_output_lane, self.b_output_lane_e, None, s_prefix_count_bits)

    def prefix_sum(self):
        pass

    def prefix_product(self):
        pass
