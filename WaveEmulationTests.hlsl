// NVIDIA based architecture
#define WAVE_SIZE 32

// Launch blocks with multiple waves to ensure the emulation is ok across various waves.
#define NUM_WAVE 16

// Force wave op emulation for the tests and use the intrinsics here.
#define EMULATE_WAVE_OPS 1

#include "WaveEmulation.hlsl"

// Tests IDs
// ----------------------------------------------------------------------
#define TEST_GET_LANE_COUNT  0
#define TEST_GET_LANE_INDEX  1
#define TEST_IS_FIRST_LANE   2
#define TEST_ACTIVE_ANY_TRUE 3
#define TEST_ACTIVE_ALL_TRUE 4
#define TEST_ACTIVE_BALLOT   5

// Tests
// ----------------------------------------------------------------------

// Query

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

// Vote

namespace ActiveAnyTrue
{
    cbuffer Constants : register(b0)
    {
        uint _ThresholdAny;
    };

    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0); // Intrinsic
    RWBuffer<uint> _Output1 : register(u1); // Emulated

    void Test(uint i)
    {
        const bool value = _Input[i] > _ThresholdAny;

        _Output0[floor(i / WAVE_SIZE)] = WaveActiveAnyTrue(value);
        _Output1[floor(i / WAVE_SIZE)] = Wave::ActiveAnyTrue(value);
    }
}

namespace ActiveAllTrue
{
    cbuffer Constants : register(b0)
    {
        uint _ThresholdAll;
    };

    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0); // Intrinsic
    RWBuffer<uint> _Output1 : register(u1); // Emulated

    void Test(uint i)
    {
        const bool value = _Input[i] > _ThresholdAll;

        _Output0[floor(i / WAVE_SIZE)] = WaveActiveAllTrue(value);
        _Output1[floor(i / WAVE_SIZE)] = Wave::ActiveAllTrue(value);
    }
}

namespace ActiveBallot
{
    cbuffer Constants : register(b0)
    {
        uint _ThresholdActive;
    };

    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0); // Intrinsic
    RWBuffer<uint> _Output1 : register(u1); // Emulated

    void Test(uint i)
    {
        if (_Input[i] > _ThresholdActive)
        {
            // Intrinsic
            const uint4 activeLaneMaskIntrinsic = WaveActiveBallot(true);
            _Output0[floor(i / WAVE_SIZE)] = countbits(activeLaneMaskIntrinsic.x) +
                                             countbits(activeLaneMaskIntrinsic.y) +
                                             countbits(activeLaneMaskIntrinsic.z) +
                                             countbits(activeLaneMaskIntrinsic.w);

            // Emulated
            const uint4 activeLandMaskEmulated  = Wave::ActiveBallot(true);
            _Output1[floor(i / WAVE_SIZE)] = countbits(activeLandMaskEmulated.x) +
                                             countbits(activeLandMaskEmulated.y) +
                                             countbits(activeLandMaskEmulated.z) +
                                             countbits(activeLandMaskEmulated.w);
        }
    }
}

// Kernel
// ----------------------------------------------------------------------

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
#elif TEST_ID == TEST_ACTIVE_ANY_TRUE
    {
        ActiveAnyTrue::Test(i);
    }
#elif TEST_ID == TEST_ACTIVE_ALL_TRUE
    {
        ActiveAllTrue::Test(i);
    }
#elif TEST_ID == TEST_ACTIVE_BALLOT
    {
        ActiveBallot::Test(i);
    }
#endif
}