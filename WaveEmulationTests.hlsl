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

uint GetData(uint i)
{
    return _DataBuffer[i];
}

bool KillLane(uint i)
{
    return _ExecutionMaskBuffer[i] != 1;
}

void OutputPerLane(uint i, uint intrinsic, uint emulated)
{
    _Output0[i] = intrinsic;
    _Output1[i] = emulated;
}

void OutputPerWave(uint i, uint intrinsic, uint emulated)
{
    _Output0[floor(i / WAVE_SIZE)] = intrinsic;
    _Output1[floor(i / WAVE_SIZE)] = emulated;
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
#define TEST_PREFIX_PRODUCT    19

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
        OutputPerWave(i,
            WaveGetLaneCount(),
            Wave::GetLaneCount()
        );
    }
}

namespace GetLaneIndex
{
    void Test(uint i)
    {
        OutputPerLane(i,
            WaveGetLaneIndex(),
            Wave::GetLaneIndex()
        );
    }
}

namespace IsFirstLane
{
    void Test(uint i)
    {
        OutputPerLane(i,
            WaveIsFirstLane(),
            Wave::IsFirstLane()
        );
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

        OutputPerWave(i,
            WaveActiveAnyTrue(value),
            Wave::ActiveAnyTrue(value)
        );
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

        OutputPerWave(i,
            WaveActiveAllTrue(value),
            Wave::ActiveAllTrue(value)
        );
    }
}

namespace ActiveBallot
{
    void Test(uint i)
    {
        const uint4 activeLaneMaskIntrinsic = WaveActiveBallot(true);
        uint intrinsic = activeLaneMaskIntrinsic.x +
                         activeLaneMaskIntrinsic.y +
                         activeLaneMaskIntrinsic.z +
                         activeLaneMaskIntrinsic.w;

        const uint4 activeLaneMaskEmulated  = Wave::ActiveBallot(true);
        uint emulated = activeLaneMaskEmulated.x +
                        activeLaneMaskEmulated.y +
                        activeLaneMaskEmulated.z +
                        activeLaneMaskEmulated.w;

        OutputPerWave(i, intrinsic, emulated);
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

        OutputPerWave(i,
            WaveReadLaneAt(value, _ReadLaneIndex),
            Wave::ReadLaneAt(value, _ReadLaneIndex)
        );
    }
}

namespace ReadLaneFirst
{
    void Test(uint i)
    {
        const uint value = GetData(i);

        OutputPerWave(i,
            WaveReadLaneFirst(value),
            Wave::ReadLaneFirst(value)
        );
    }
}


// Reduction
// ----------------------------------------------------------------------

namespace ActiveAllEqual
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerWave(i,
            WaveActiveAllEqual(value),
            Wave::ActiveAllEqual(value)
        );
    }
}

namespace ActiveBitAnd
{
    void Test(uint i)
    {
        uint value = GetData(i);

        if (i == 111)
            value = 12562;

        OutputPerWave(i,
            WaveActiveBitAnd(value),
            Wave::ActiveBitAnd(value)
        );
    }
}

namespace ActiveBitOr
{
    void Test(uint i)
    {
        uint value = GetData(i);

        if (i == 142)
            value = 12562;

        OutputPerWave(i,
            WaveActiveBitOr(value),
            Wave::ActiveBitOr(value)
        );
    }
}

namespace ActiveBitXor
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerWave(i,
            WaveActiveBitXor(value),
            Wave::ActiveBitXor(value)
        );
    }
}

namespace ActiveCountBits
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerWave(i,
            WaveActiveCountBits(value),
            Wave::ActiveCountBits(value)
        );
    }
}

namespace ActiveMax
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerWave(i,
            WaveActiveMax(value),
            Wave::ActiveMax(value)
        );
    }
}

namespace ActiveMin
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerWave(i,
            WaveActiveMin(value),
            Wave::ActiveMin(value)
        );
    }
}

namespace ActiveProduct
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerWave(i,
            WaveActiveProduct(value),
            Wave::ActiveProduct(value)
        );
    }
}

namespace ActiveSum
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerWave(i,
            WaveActiveSum(value),
            Wave::ActiveSum(value)
        );
    }
}

// Scan & Prefix
// ----------------------------------------------------------------------

namespace PrefixCountBits
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerLane(i,
            WavePrefixCountBits(value),
            Wave::PrefixCountBits(value)
        );
    }
}

namespace PrefixSum
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerLane(i,
            WavePrefixSum(value),
            Wave::PrefixSum(value)
        );
    }
}

namespace PrefixProduct
{
    void Test(uint i)
    {
        uint value = GetData(i);

        OutputPerLane(i,
            WavePrefixProduct(value),
            Wave::PrefixProduct(value)
        );
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
#elif TEST == TEST_PREFIX_PRODUCT
    {
        PrefixProduct::Test(i);
    }
#endif
}