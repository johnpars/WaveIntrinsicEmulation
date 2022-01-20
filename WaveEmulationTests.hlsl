#include "WaveEmulation.hlsl"

// Inputs
Buffer<uint> _ExecutionMaskBuffer : register(t0);
Buffer<uint> _DataBuffer          : register(t1); // Warning: May not always be bound.

// Outputs
RWBuffer<uint> _Output0 : register(u0);
RWBuffer<uint> _Output1 : register(u1);

// Util
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------

#define WAVE_IDX floor(i / WAVE_SIZE)

uint GetData(uint i)
{
    return _DataBuffer[i];
}

bool KillLane(uint i)
{
    return _ExecutionMaskBuffer[i] != 1;
}

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
#define TEST_PREFIX_COUNT_BITS 17
#define TEST_PREFIX_SUM        18

// Tests
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------

// Query
// ----------------------------------------------------------------------

namespace GetLaneCount
{
    void Test(uint i)
    {
        _Output0[WAVE_IDX] = WaveGetLaneCount();
        _Output1[WAVE_IDX] = Wave::GetLaneCount();
    }
}

namespace GetLaneIndex
{
    void Test(uint i)
    {
        _Output0[i] = WaveGetLaneIndex();
        _Output1[i] = Wave::GetLaneIndex();
    }
}

namespace IsFirstLane
{
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

    void Test(uint i)
    {
        const bool value = GetData(i) > _ThresholdAny;

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

    void Test(uint i)
    {
        const bool value = GetData(i) > _ThresholdAll;

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

    void Test(uint i)
    {
        if (GetData(i) > _ThresholdActive)
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

    void Test(uint i)
    {
        const uint value = GetData(i);
        _Output0[WAVE_IDX] = WaveReadLaneAt(value, _ReadLaneIndex);
        _Output1[WAVE_IDX] = Wave::ReadLaneAt(value, _ReadLaneIndex);
    }
}

namespace ReadLaneFirst
{
    void Test(uint i)
    {
        // Test to make sure we read the first active lane.
        if (WaveGetLaneIndex() > WAVE_SIZE / 2)
        {
            const uint value = GetData(i);
            _Output0[WAVE_IDX] = WaveReadLaneFirst(value);
            _Output1[WAVE_IDX] = Wave::ReadLaneFirst(value);
        }
    }
}


// Reduction
// ----------------------------------------------------------------------

namespace ActiveAllEqual
{
    void Test(uint i)
    {
        uint value = GetData(i);
        _Output0[WAVE_IDX] = WaveActiveAllEqual(value);
        _Output1[WAVE_IDX] = Wave::ActiveAllEqual(value);
    }
}

namespace ActiveBitAnd
{
    void Test(uint i)
    {
        uint value = GetData(i);

        if (i == 111)
            value = 12562;

        _Output0[WAVE_IDX] = WaveActiveBitAnd(value);
        _Output1[WAVE_IDX] = Wave::ActiveBitAnd(value);
    }
}

namespace ActiveBitOr
{
    void Test(uint i)
    {
        uint value = GetData(i);

        if (i == 142)
            value = 12562;

        _Output0[WAVE_IDX] = WaveActiveBitOr(value);
        _Output1[WAVE_IDX] = Wave::ActiveBitOr(value);
    }
}

namespace ActiveBitXor
{
    void Test(uint i)
    {
        uint value = GetData(i);

        _Output0[WAVE_IDX] = WaveActiveBitXor(value);
        _Output1[WAVE_IDX] = Wave::ActiveBitXor(value);
    }
}

namespace ActiveCountBits
{
    void Test(uint i)
    {
        uint value = GetData(i);

        _Output0[WAVE_IDX] = WaveActiveCountBits(value);
        _Output1[WAVE_IDX] = Wave::ActiveCountBits(value);
    }
}

namespace ActiveMax
{
    void Test(uint i)
    {
        uint value = GetData(i);

        _Output0[WAVE_IDX] = WaveActiveMax(value);
        _Output1[WAVE_IDX] = Wave::ActiveMax(value);
    }
}

namespace ActiveMin
{
    void Test(uint i)
    {
        uint value = GetData(i);

        _Output0[WAVE_IDX] = WaveActiveMin(value);
        _Output1[WAVE_IDX] = Wave::ActiveMin(value);
    }
}

namespace ActiveProduct
{
    void Test(uint i)
    {
        uint value = GetData(i);
        _Output0[WAVE_IDX] = WaveActiveProduct(value);
        _Output1[WAVE_IDX] = Wave::ActiveProduct(value);
    }
}

namespace ActiveSum
{
    void Test(uint i)
    {
        uint value = GetData(i);
        _Output0[WAVE_IDX] = WaveActiveSum(value);
        _Output1[WAVE_IDX] = Wave::ActiveSum(value);
    }
}

// Scan & Prefix
// ----------------------------------------------------------------------

namespace PrefixCountBits
{
    void Test(uint i)
    {
        uint value = GetData(i);
        _Output0[i] = WavePrefixCountBits(value);
        _Output1[i] = Wave::PrefixCountBits(value);
    }
}

namespace PrefixSum
{
    void Test(uint i)
    {
        uint value = GetData(i);
        _Output0[i] = WavePrefixSum(value);
        _Output1[i] = Wave::PrefixSum(value);
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

    if (KillLane(i))
        return;

    Wave::Configure(groupIndex);

#if TEST == TEST_GET_LANE_COUNT
    {
        GetLaneCount::Test(i);
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
#elif TEST == TEST_PREFIX_COUNT_BITS
    {
        PrefixCountBits::Test(i);
    }
#elif TEST == TEST_PREFIX_SUM
    {
        PrefixSum::Test(i);
    }
#endif
}