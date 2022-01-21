import random
import math
import numpy as np
import coalpy.gpu as gpu

WAVE_SIZE = 32
NUM_WAVE  = 16

# kernels
base_defines = ["WAVE_SIZE={}".format(WAVE_SIZE), "NUM_WAVE={}".format(NUM_WAVE)]
s_get_lane_count    = gpu.Shader(file="WaveEmulationTests.hlsl", name="GetLaneCount",    main_function="Main", defines= base_defines + ["TEST=0"])
s_get_lane_index    = gpu.Shader(file="WaveEmulationTests.hlsl", name="GetLaneIndex",    main_function="Main", defines= base_defines + ["TEST=1"])
s_is_first_lane     = gpu.Shader(file="WaveEmulationTests.hlsl", name="IsFirstLane",     main_function="Main", defines= base_defines + ["TEST=2"])
s_active_any_true   = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveAnyTrue",   main_function="Main", defines= base_defines + ["TEST=3"])
s_active_all_true   = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveAllTrue",   main_function="Main", defines= base_defines + ["TEST=4"])
s_active_ballot     = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBallot",    main_function="Main", defines= base_defines + ["TEST=5"])
s_read_lane_at      = gpu.Shader(file="WaveEmulationTests.hlsl", name="ReadLaneAt",      main_function="Main", defines= base_defines + ["TEST=6"])
s_read_lane_first   = gpu.Shader(file="WaveEmulationTests.hlsl", name="ReadLaneFirst",   main_function="Main", defines= base_defines + ["TEST=7"])
s_active_all_equal  = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveAllEqual",  main_function="Main", defines= base_defines + ["TEST=8"])
s_active_bit_and    = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBitAnd",    main_function="Main", defines= base_defines + ["TEST=9"])
s_active_bit_or     = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBitOr",     main_function="Main", defines= base_defines + ["TEST=10"])
s_active_bit_xor    = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveBitXor",    main_function="Main", defines= base_defines + ["TEST=11"])
s_active_count_bits = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveCountBits", main_function="Main", defines= base_defines + ["TEST=12"])
s_active_max        = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveMax",       main_function="Main", defines= base_defines + ["TEST=13"])
s_active_min        = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveMin",       main_function="Main", defines= base_defines + ["TEST=14"])
s_active_product    = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveProduct",   main_function="Main", defines= base_defines + ["TEST=15"])
s_active_sum        = gpu.Shader(file="WaveEmulationTests.hlsl", name="ActiveSum",       main_function="Main", defines= base_defines + ["TEST=16"])
s_prefix_count_bits = gpu.Shader(file="WaveEmulationTests.hlsl", name="PrefixCountBits", main_function="Main", defines= base_defines + ["TEST=17"])
s_prefix_sum        = gpu.Shader(file="WaveEmulationTests.hlsl", name="PrefixSum",       main_function="Main", defines= base_defines + ["TEST=18"])
s_prefix_product    = gpu.Shader(file="WaveEmulationTests.hlsl", name="PrefixProduct",   main_function="Main", defines= base_defines + ["TEST=19"])
s_integration       = gpu.Shader(file="WaveEmulationTests.hlsl", name="Integration",     main_function="Main", defines= base_defines + ["TEST=20"])

# kernel (clearing)
s_clear_buffer = gpu.Shader(file="ClearBuffer.hlsl", name="ClearBuffer", main_function="Main")


def resolve_buffer(buffer, type):
    request = gpu.ResourceDownloadRequest(buffer)
    request.resolve()
    return np.frombuffer(request.data_as_bytearray(), dtype=type)


def dispatch_test(data, b_data, b_active, b_output, b_output_e, constants, test_kernel, is_per_wave=True):
    cmd = gpu.CommandList()

    # Generate a random lane execution mask for this test.
    execution_mask = np.random.randint(0, 2, NUM_WAVE * WAVE_SIZE)
    cmd.upload_resource(execution_mask, b_active)

    # Set up the inputs buffers.
    if b_data is None:
        input_table = gpu.InResourceTable(
            name="Inputs",
            resource_list=[b_active]
        )
    else:
        cmd.upload_resource(data, b_data)

        input_table = gpu.InResourceTable(
            name="Inputs",
            resource_list=[b_active, b_data]
        )

    # Default constant buffer if none given.
    if constants is None:
        constants = []

    # Clear the output targets
    clear_count = NUM_WAVE if is_per_wave else NUM_WAVE * WAVE_SIZE
    cmd.dispatch(x=math.ceil(clear_count / 32), constants=[0, clear_count], outputs=b_output, shader=s_clear_buffer)
    cmd.dispatch(x=math.ceil(clear_count / 32), constants=[0, clear_count], outputs=b_output_e, shader=s_clear_buffer)

    # Invoke the GPU test.
    cmd.dispatch(
        x=1,
        inputs=input_table,
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


class WaveEmulationTestSuite:

    def __init__(self):

        self.b_input_data = gpu.Buffer(
            type=gpu.BufferType.Standard,
            format=gpu.Format.R32_UINT,
            element_count=WAVE_SIZE * NUM_WAVE
        )

        self.b_input_inactive_lane = gpu.Buffer(
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

    # util
    # ---------------------------------------------------
    def test_per_wave(self, data, constants, kernel):
        return dispatch_test(data, self.b_input_data, self.b_input_inactive_lane, self.b_output_wave, self.b_output_wave_e, constants, kernel)

    def test_per_wave_no_data(self, kernel):
        return dispatch_test(None, None, self.b_input_inactive_lane, self.b_output_wave, self.b_output_wave_e, None, kernel)

    def test_per_lane(self, data, constants, kernel):
        return dispatch_test(data, self.b_input_data, self.b_input_inactive_lane, self.b_output_lane, self.b_output_lane_e, constants, kernel, False)

    def test_per_lane_no_data(self, kernel):
        return dispatch_test(None, None, self.b_input_inactive_lane, self.b_output_lane, self.b_output_lane_e, None, kernel, False)

    # query
    # ---------------------------------------------------
    def get_lane_count(self):
        return self.test_per_wave_no_data(s_get_lane_count)

    def get_lane_index(self):
        return self.test_per_lane_no_data(s_get_lane_index)

    def is_first_lane(self):
        return self.test_per_lane_no_data(s_is_first_lane)

    # vote
    # ---------------------------------------------------
    def active_any_true(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, np.array([990]), s_active_any_true)

    def active_all_true(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, np.array([10]), s_active_all_true)

    def active_ballot(self):
        data = np.random.randint(0, 2, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_ballot)

    # broadcast
    # ---------------------------------------------------
    def read_lane_at(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, np.array([random.randint(0, WAVE_SIZE - 1)]), s_read_lane_at)

    def read_lane_first(self):
        data = np.random.randint(0, 1000, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_read_lane_first)

    # reduction
    # ---------------------------------------------------
    def active_all_equal(self):
        data = np.repeat(12425, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_all_equal)

    def active_bit_and(self):
        data = np.repeat(1234, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_bit_and)

    def active_bit_or(self):
        data = np.repeat(1234, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_bit_or)

    def active_bit_xor(self):
        data = np.repeat(1234, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_bit_xor)

    def active_count_bits(self):
        data = np.random.randint(0, 10000, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_count_bits)

    def active_max(self):
        data = np.random.randint(100, 10000, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_max)

    def active_min(self):
        data = np.random.randint(100, 10000, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_min)

    def active_product(self):
        data = np.random.randint(1, 3, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_product)

    def active_sum(self):
        data = np.random.randint(2, 510, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_active_sum)

    # scan & prefix
    # ---------------------------------------------------
    def prefix_count_bits(self):
        data = np.random.randint(0, 2, NUM_WAVE * WAVE_SIZE)
        return self.test_per_lane(data, None, s_prefix_count_bits)

    def prefix_sum(self):
        data = np.random.randint(12, 2022, NUM_WAVE * WAVE_SIZE)
        return self.test_per_lane(data, None, s_prefix_sum)

    def prefix_product(self):
        data = np.random.randint(1, 6, NUM_WAVE * WAVE_SIZE)
        return self.test_per_lane(data, None, s_prefix_product)

    # integration
    # ----------------------------------------------------
    def integration(self):
        data = np.random.randint(1, 20, NUM_WAVE * WAVE_SIZE)
        return self.test_per_wave(data, None, s_integration)