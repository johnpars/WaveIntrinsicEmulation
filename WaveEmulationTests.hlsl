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
#define TEST_READ_LANE_AT    6
#define TEST_READ_LANE_FIRST 7

// Tests
// ----------------------------------------------------------------------

#define WAVE_IDX floor(i / WAVE_SIZE)

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
    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        _Output0[i] = WaveGetLaneIndex();
        _Output1[i] = Wave::GetLaneIndex();
    }
}

namespace IsFirstLane
{
    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

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

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        const bool value = _Input[i] > _ThresholdAny;

        _Output0[WAVE_IDX] = WaveActiveAnyTrue(value);
        _Output1[WAVE_IDX] = Wave::ActiveAnyTrue(value);
    }
}

namespace ActiveAllTrue
{
    cbuffer Constants : register(b0)
    {
        uint _ThresholdAll;
    };

    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        const bool value = _Input[i] > _ThresholdAll;

        _Output0[WAVE_IDX] = WaveActiveAllTrue(value);
        _Output1[WAVE_IDX] = Wave::ActiveAllTrue(value);
    }
}

namespace ActiveBallot
{
    cbuffer Constants : register(b0)
    {
        uint _ThresholdActive;
    };

    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        if (_Input[i] > _ThresholdActive)
        {
            // Intrinsic
            const uint4 activeLaneMaskIntrinsic = WaveActiveBallot(true);
            _Output0[WAVE_IDX] = activeLaneMaskIntrinsic.x +
                                             activeLaneMaskIntrinsic.y +
                                             activeLaneMaskIntrinsic.z +
                                             activeLaneMaskIntrinsic.w;

            // Emulated
            const uint4 activeLaneMaskEmulated  = Wave::ActiveBallot(true);
            _Output1[WAVE_IDX] = activeLaneMaskEmulated.x +
                                             activeLaneMaskEmulated.y +
                                             activeLaneMaskEmulated.z +
                                             activeLaneMaskEmulated.w;
        }
    }
}

// Broadcast
namespace ReadLaneAt
{
    cbuffer Constants : register(b0)
    {
        uint _ReadLaneIndex;
    };

    Buffer<float> _Input : register(t0);

    RWBuffer<float> _Output0 : register(u0);
    RWBuffer<float> _Output1 : register(u1);

    void Test(uint i)
    {
        const float value = _Input[i];
        _Output0[WAVE_IDX] = WaveReadLaneAt(value, _ReadLaneIndex);
        _Output1[WAVE_IDX] = Wave::ReadLaneAt(value, _ReadLaneIndex);
    }
}

namespace ReadLaneFirst
{
    Buffer<float> _Input : register(t0);

    RWBuffer<float> _Output0 : register(u0);
    RWBuffer<float> _Output1 : register(u1);

    void Test(uint i)
    {
        if (WaveGetLaneIndex() > 16)
        {
            const float value = _Input[i];
            _Output0[WAVE_IDX] = WaveReadLaneFirst(value);
            _Output1[WAVE_IDX] = Wave::ReadLaneFirst(value);
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
#elif TEST_ID == TEST_READ_LANE_AT
    {
        ReadLaneAt::Test(i);
    }
#elif TEST_ID == TEST_READ_LANE_FIRST
    {
        ReadLaneFirst::Test(i);
    }
#endif
}