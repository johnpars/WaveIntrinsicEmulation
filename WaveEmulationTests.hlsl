#define WAVE_SIZE 32

// Force wave op emulation for the tests and use the intrinsics here.
#define EMULATE_WAVE_OPS 1

#include "WaveEmulation.hlsl"

// Tests IDs
// ----------------------------------------------------------------------
#define TEST_GET_LANE_COUNT 0
#define TEST_GET_LANE_INDEX 1
#define TEST_IS_FIRST_LANE  2

// Tests
// ----------------------------------------------------------------------

namespace GetLaneCount
{
    RWBuffer<uint> _Output : register(u0);

    void Test()
    {
        _Output[0] = WaveGetLaneCount();
        _Output[1] = Wave::GetLaneCount();
    }
}

namespace GetLaneIndex
{
    RWBuffer<uint> _Output0 : register(u0); // Intrinsic
    RWBuffer<uint> _Output1 : register(u1); // Emulated

    void Test(uint i)
    {
        _Output0[i] = WaveGetLaneIndex();
        _Output1[i] = Wave::GetLaneIndex();
    }
}

namespace IsFirstLane
{
    RWBuffer<uint> _Output0 : register(u0); // Intrinsic
    RWBuffer<uint> _Output1 : register(u1); // Emulated

    void Test(uint i)
    {
        _Output0[i] = WaveIsFirstLane();
        _Output1[i] = Wave::IsFirstLane();
    }
}

// Kernel
// ----------------------------------------------------------------------

// Launch blocks with multiple waves to ensure the emulation is ok across various waves.
#define NUM_WAVE 2

[numthreads(WAVE_SIZE * NUM_WAVE, 1, 1)]
void Main(uint dispatchThreadID : SV_DispatchThreadID, uint groupIndex : SV_GroupIndex)
{
    const uint i = dispatchThreadID.x;

    Wave::Configure(groupIndex);

#if TEST_ID == TEST_GET_LANE_COUNT
    {
        GetLaneCount::Test();
    }
#elif TEST_ID == TEST_GET_LANE_INDEX
    {
        GetLaneIndex::Test(i);
    }
#elif TEST_ID == TEST_IS_FIRST_LANE
    {
        IsFirstLane::Test(i);
    }
#endif
}