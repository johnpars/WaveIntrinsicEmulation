import tests


def run(name, function):
    result = function()
    print(name + " : " + ("PASS" if result else "FAIL"))


run("GetLaneCount",  tests.get_lane_count)
run("GetLaneIndex",  tests.get_lane_index)
run("IsFirstLane",   tests.is_first_lane)
run("ActiveAnyTrue", tests.active_any_true)
run("ActiveAllTrue", tests.active_all_true)
run("ActiveBallot",  tests.active_ballot)