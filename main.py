from tests import WaveEmulationTestSuite

W  = '\033[0m'
R  = '\033[31m'
G  = '\033[32m'


def run(name, function):
    result = function()
    print((G + "PASS" if result else R + "FAIL") + W + " [{}]".format(name))
    return result


tests = WaveEmulationTestSuite()

print(G + "\nRunning tests...\n")

overall = True
overall &= run("GetLaneCount",    tests.get_lane_count)
overall &= run("GetLaneIndex",    tests.get_lane_index)
overall &= run("IsFirstLane",     tests.is_first_lane)
overall &= run("ActiveAnyTrue",   tests.active_any_true)
overall &= run("ActiveAllTrue",   tests.active_all_true)
overall &= run("ActiveBallot",    tests.active_ballot)
overall &= run("ReadLaneAt",      tests.read_lane_at)
overall &= run("ReadLaneFirst",   tests.read_lane_first)
overall &= run("ActiveAllEqual",  tests.active_all_equal)
overall &= run("ActiveBitAnd",    tests.active_bit_and)
overall &= run("ActiveBitOr",     tests.active_bit_or)
overall &= run("ActiveBitXor",    tests.active_bit_xor)
overall &= run("ActiveCountBits", tests.active_count_bits)
overall &= run("ActiveMax",       tests.active_max)
overall &= run("ActiveMin",       tests.active_min)
overall &= run("ActiveProduct",   tests.active_product)
overall &= run("ActiveSum",       tests.active_sum)
overall &= run("PrefixCountBits", tests.prefix_count_bits)
overall &= run("PrefixSum",       tests.prefix_sum)
overall &= run("PrefixProduct",   tests.prefix_product)

print("\nOverall Result: " + (G + "PASS" if overall else R + "FAIL") )
