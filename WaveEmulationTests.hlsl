// NVIDIA based architecture
#define WAVE_SIZE 32

// Launch blocks with multiple waves to ensure the emulation is ok across various waves.
#define NUM_WAVE 16

// Force wave op emulation for the tests and use the intrinsics here.
#define EMULATE_WAVE_OPS 1

#include "WaveEmulation.hlsl"

// Tests IDs
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
#define TEST_GET_LANE_COUNT    0
#define TEST_GET_LANE_INDEX    1
#define TEST_IS_FIRST_LANE     2
#define TEST_ACTIVE_ANY_TRUE   3
#define TEST_ACTIVE_ALL_TRUE   4
#define TEST_ACTIVE_BALLOT     5
#define TEST_READ_LANE_AT      6
#define TEST_READ_LANE_FIRST   7
#define TEST_ACTIVE_ALL_EQUAL  8
#define TEST_ACTIVE_BIT_AND    9
#define TEST_ACTIVE_BIT_OR     10
#define TEST_ACTIVE_BIT_XOR    11
#define TEST_ACTIVE_COUNT_BITS 12
#define TEST_ACTIVE_MAX        13
#define TEST_ACTIVE_MIN        14
#define TEST_ACTIVE_PRODUCT    15
#define TEST_ACTIVE_SUM        16

// Tests
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------

#define WAVE_IDX floor(i / WAVE_SIZE)

// Query
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
// ----------------------------------------------------------------------

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
// ----------------------------------------------------------------------

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
        // Test to make sure we read the first active lane.
        if (WaveGetLaneIndex() > WAVE_SIZE / 2)
        {
            const float value = _Input[i];
            _Output0[WAVE_IDX] = WaveReadLaneFirst(value);
            _Output1[WAVE_IDX] = Wave::ReadLaneFirst(value);
        }
    }
}


// Reduction
// ----------------------------------------------------------------------

namespace ActiveAllEqual
{
    Buffer<float> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        if (i < 30)
            return;

        float value;

        // Generate some intermittent random value.
        if (i == 151 || i == 402)
            value = 4.0f;
        else
            value = _Input[i];

        _Output0[WAVE_IDX] = WaveActiveAllEqual(value);
        _Output1[WAVE_IDX] = Wave::ActiveAllEqual(value);
    }
}

namespace ActiveBitAnd
{
    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        uint value = _Input[i];

        if (i == 142)
            value = 12562;

        _Output0[WAVE_IDX] = WaveActiveBitAnd(value);
        _Output1[WAVE_IDX] = Wave::ActiveBitAnd(value);
    }
}

namespace ActiveBitOr
{
    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        uint value = _Input[i];

        if (i == 142)
            value = 12562;

        _Output0[WAVE_IDX] = WaveActiveBitOr(value);
        _Output1[WAVE_IDX] = Wave::ActiveBitOr(value);
    }
}

namespace ActiveBitXor
{
    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        uint value = _Input[i];

        _Output0[WAVE_IDX] = WaveActiveBitXor(value);
        _Output1[WAVE_IDX] = Wave::ActiveBitXor(value);
    }
}

namespace ActiveCountBits
{
    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        uint value = _Input[i];

        _Output0[WAVE_IDX] = WaveActiveCountBits(value);
        _Output1[WAVE_IDX] = Wave::ActiveCountBits(value);
    }
}

namespace ActiveMax
{
    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        uint value = _Input[i];

        _Output0[WAVE_IDX] = WaveActiveMax(value);
        _Output1[WAVE_IDX] = Wave::ActiveMax(value);
    }
}

namespace ActiveMin
{
    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        uint value = _Input[i];

        _Output0[WAVE_IDX] = WaveActiveMin(value);
        _Output1[WAVE_IDX] = Wave::ActiveMin(value);
    }
}

namespace ActiveProduct
{
    Buffer<uint> _Input : register(t0);

    RWBuffer<uint> _Output0 : register(u0);
    RWBuffer<uint> _Output1 : register(u1);

    void Test(uint i)
    {
        // Test the execution mask
        if (i < 52 || i > 451)
            return;

        uint value = _Input[i];

        _Output0[WAVE_IDX] = WaveActiveProduct(value);
        _Output1[WAVE_IDX] = Wave::ActiveProduct(value);
    }
}

namespace ActiveSum
{
    Buffer<float> _Input : register(t0);

    RWBuffer<float> _Output0 : register(u0);
    RWBuffer<float> _Output1 : register(u1);

    void Test(uint i)
    {
        // Test the execution mask
        if (i < 52 || i > 451)
            return;

        float value = _Input[i];

        _Output0[WAVE_IDX] = WaveActiveSum(value);
        _Output1[WAVE_IDX] = Wave::ActiveSum(value);
    }
}

// Kernel
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------

[numthreads(WAVE_SIZE * NUM_WAVE, 1, 1)]
void Main(uint dispatchThreadID : SV_DispatchThreadID, uint groupIndex : SV_GroupIndex)
{
    const uint i = dispatchThreadID.x;

    Wave::Configure(groupIndex);

#if TEST == TEST_GET_LANE_COUNT
    {
        GetLaneCount::Test();
    }
#elif TEST == TEST_GET_LANE_INDEX
    {
        GetLaneIndex::Test(i);
    }
#elif TEST == TEST_IS_FIRST_LANE
    {
        IsFirstLane::Test(i);
    }
#elif TEST == TEST_ACTIVE_ANY_TRUE
    {
        ActiveAnyTrue::Test(i);
    }
#elif TEST == TEST_ACTIVE_ALL_TRUE
    {
        ActiveAllTrue::Test(i);
    }
#elif TEST == TEST_ACTIVE_BALLOT
    {
        ActiveBallot::Test(i);
    }
#elif TEST == TEST_READ_LANE_AT
    {
        ReadLaneAt::Test(i);
    }
#elif TEST == TEST_READ_LANE_FIRST
    {
        ReadLaneFirst::Test(i);
    }
#elif TEST == TEST_ACTIVE_ALL_EQUAL
    {
        ActiveAllEqual::Test(i);
    }
#elif TEST == TEST_ACTIVE_BIT_AND
    {
        ActiveBitAnd::Test(i);
    }
#elif TEST == TEST_ACTIVE_BIT_OR
    {
        ActiveBitOr::Test(i);
    }
#elif TEST == TEST_ACTIVE_BIT_XOR
    {
        ActiveBitXor::Test(i);
    }
#elif TEST == TEST_ACTIVE_COUNT_BITS
    {
        ActiveCountBits::Test(i);
    }
#elif TEST == TEST_ACTIVE_MAX
    {
        ActiveMax::Test(i);
    }
#elif TEST == TEST_ACTIVE_MIN
    {
        ActiveMin::Test(i);
    }
#elif TEST == TEST_ACTIVE_PRODUCT
    {
        ActiveProduct::Test(i);
    }
#elif TEST == TEST_ACTIVE_SUM
    {
        ActiveSum::Test(i);
    }
#endif
}