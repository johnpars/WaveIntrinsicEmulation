import tests

W  = '\033[0m'
R  = '\033[31m'
G  = '\033[32m'


def run(name, function):
    result = function()
    print((G + "PASS" if result else R + "FAIL") + W + " [{}]".format(name))

print("\n\nAsserting wave emulation validation against built-in wave intrinsics...\n")
run("GetLaneCount",    tests.get_lane_count)
run("GetLaneIndex",    tests.get_lane_index)
run("IsFirstLane",     tests.is_first_lane)
run("ActiveAnyTrue",   tests.active_any_true)
run("ActiveAllTrue",   tests.active_all_true)
run("ActiveBallot",    tests.active_ballot)
run("ReadLaneAt",      tests.read_lane_at)
run("ReadLaneFirst",   tests.read_lane_first)
run("ActiveAllEqual",  tests.active_all_equal)
run("ActiveBitAnd",    tests.active_bit_and)
run("ActiveBitOr",     tests.active_bit_or)
run("ActiveBitXor",    tests.active_bit_xor)
run("ActiveCountBits", tests.active_count_bits)
run("ActiveMax",       tests.active_max)
run("ActiveMin",       tests.active_min)
run("ActiveProduct",   tests.active_product)
run("ActiveSum",       tests.active_sum)