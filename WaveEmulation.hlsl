// Utility library that emulates SM 6.0 Wave Intrinsics for SM 5.0.
// Helps to write backwards-compatible wave-ops code for SM 5.0.
// Currently not optimized to ensure SGPR during broadcasts / reductions.

// Idea: Initialize LDS to null / inactive, after every op, active thread resets the lane to null.
// Idea: Use asuint to reduce LDS usage
// TODO: Check that per-wave results are in scalar registers, not vector registers.
// TODO: Execution mask is currently hard coded 32-bit, need to support up to 128 bit (128 lane wave).
// TODO: Need to clean the execution mask each time it is used.
// Idea: Use #define ActiveAllTrue(e) WaveActiveAllTrue(e)? To avoid multiple function prototypes. Note looks like it won't work due to namespace
// TODO: Is it worth the registers for wave/lane index or pay the ALU for it for when its needed?
// TODO: Figure out how to perform a parallel reduction for the emulations that do not use atomics. Need to be careful of inactive lanes.

#ifndef WAVE_SIZE
#error WARNING: Using the Wave Emulation library without having specified WAVE_SIZE
#endif

#ifndef NUM_WAVE
#error WARNING: Using the Wave Emulation library without having specified NUM_WAVE
#endif

namespace Wave
{
    // Per-thread state.
    // -----------------------------------------------------------------------

    static uint s_GroupIndex;
    static uint s_WaveIndex;
    static uint s_LaneIndex;

    void Configure(uint groupIndex)
    {
        // Cache the group / lane index in static thread memory.
        s_GroupIndex = groupIndex;
        s_WaveIndex  = floor(s_GroupIndex / WAVE_SIZE);
        s_LaneIndex  = groupIndex % WAVE_SIZE;
    }

    // Per-wave execution mask. (Currently hardcoded for 32-lane wide waves).
    // -----------------------------------------------------------------------

    groupshared uint g_ExecutionMask [NUM_WAVE];

    void ConfigureExecutionMask(uint laneMask = 1u)
    {
        // Reset the execution mask.
        g_ExecutionMask[s_WaveIndex] = 0;
        GroupMemoryBarrierWithGroupSync();

        // Atomically configure the mask per-lane.
        InterlockedOr(g_ExecutionMask[s_WaveIndex], laneMask << s_LaneIndex);
        GroupMemoryBarrierWithGroupSync();
    }

    bool IsLaneActive(uint laneIndex)
    {
        return g_ExecutionMask[s_WaveIndex] & (1u << laneIndex);
    }

    uint GetFirstActiveLaneIndex()
    {
        uint laneIndex;

        // Find the first-most active lane.
        for (laneIndex = 0; laneIndex < WAVE_SIZE; ++laneIndex)
        {
            if (IsLaneActive(laneIndex))
                break;
        }

        return laneIndex;
    }

    // LDS scratch space and execution mask for emulation.
    // -----------------------------------------------------------------------

    groupshared uint g_ScalarPerLane [WAVE_SIZE * NUM_WAVE];
    groupshared uint g_ScalarPerWave [NUM_WAVE];

    groupshared bool g_BoolPerLane   [WAVE_SIZE * NUM_WAVE];
    groupshared bool g_BoolPerWave   [NUM_WAVE];

    groupshared float g_FloatPerLane [WAVE_SIZE * NUM_WAVE];
    groupshared float g_FloatPerWave [NUM_WAVE];

    // Query
    // -----------------------------------------------------------------------

    uint GetLaneCount() { return WAVE_SIZE; }
    uint GetLaneIndex() { return s_LaneIndex; }
    bool IsFirstLane()  { return GetLaneIndex() == 0; }

    // Vote
    // -----------------------------------------------------------------------

    bool ActiveAnyTrue(bool e)
    {
        InterlockedOr(g_ScalarPerWave[s_WaveIndex], (uint)e);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    bool ActiveAllTrue(bool e)
    {
        if (IsFirstLane())
            g_ScalarPerWave[s_WaveIndex] = 1;
        GroupMemoryBarrierWithGroupSync();

        InterlockedAnd(g_ScalarPerWave[s_WaveIndex], (uint)e);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint4 ActiveBallot(bool e)
    {
        // Directly use the execution mask to evaluate the expression across the wave.
        ConfigureExecutionMask(e);

        return uint4(g_ExecutionMask[s_WaveIndex], 0, 0, 0);
    }

    // Broadcast
    // -----------------------------------------------------------------------

    uint ReadLaneAt(uint v, uint laneIndex)
    {
        g_ScalarPerLane[s_GroupIndex] = v;
        GroupMemoryBarrierWithGroupSync();
        return g_ScalarPerLane[(s_WaveIndex * GetLaneCount()) + laneIndex];
    }

    float ReadLaneAt(float v, uint laneIndex)
    {
        return asfloat(ReadLaneAt(asuint(v), laneIndex));
    }

    uint ReadLaneFirst(uint v)
    {
        ConfigureExecutionMask();
        uint firstLane = GetFirstActiveLaneIndex();
        return ReadLaneAt(v, firstLane);
    }

    float ReadLaneFirst(float v)
    {
        return asfloat(ReadLaneFirst(asuint(v)));
    }

    // Reduction
    // -----------------------------------------------------------------------

    bool ActiveAllEqual(uint v)
    {
        // Clear all bits.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically OR the lane's result.
        InterlockedOr(g_ScalarPerWave[s_WaveIndex], v);
        GroupMemoryBarrierWithGroupSync();

        // Comparison with original lane result.
        return g_ScalarPerWave[s_WaveIndex] == v;
    }

    bool ActiveAllEqual(float v)
    {
        return ActiveAllEqual(asuint(v));
    }

    uint ActiveBitAnd(uint v)
    {
        // Set all bits.
        g_ScalarPerWave[s_WaveIndex] = 0;
        g_ScalarPerWave[s_WaveIndex] = ~0u;

        // Atomically AND the lane's result.
        InterlockedAnd(g_ScalarPerWave[s_WaveIndex], v);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveBitOr(uint v)
    {
        // Clear all bits.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically OR the lane's result.
        InterlockedOr(g_ScalarPerWave[s_WaveIndex], v);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveBitXor(uint v)
    {
        // Clear all bits.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically XOR the lane's result.
        InterlockedXor(g_ScalarPerWave[s_WaveIndex], v);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveCountBits(uint e)
    {
        uint4 ballot = ActiveBallot(e);

        return countbits(ballot.x) +
               countbits(ballot.y) +
               countbits(ballot.z) +
               countbits(ballot.w);
    }

    uint ActiveMax(uint v)
    {
        // Clear the wave.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically Max the lane's result.
        InterlockedMax(g_ScalarPerWave[s_WaveIndex], v);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveMin(uint v)
    {
        // Set all bits for the wave result.
        g_ScalarPerWave[s_WaveIndex] = 0;
        g_ScalarPerWave[s_WaveIndex] = ~0u;

        // Atomically Min the lane's result.
        InterlockedMin(g_ScalarPerWave[s_WaveIndex], v);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveProduct(uint v)
    {
        // Must be emulated more manually since there is no atomic product to help us.
        ConfigureExecutionMask();

        // Write lane values to LDS.
        g_ScalarPerLane[s_GroupIndex] = v;
        GroupMemoryBarrierWithGroupSync();

        const uint firstActiveLane = GetFirstActiveLaneIndex();

        // Task an active lane with resolving the product in LDS.
        if (s_LaneIndex == firstActiveLane)
        {
            g_ScalarPerWave[s_WaveIndex] = 1;

            for (uint laneIndex = 0; laneIndex < WAVE_SIZE; ++laneIndex)
            {
                if (!IsLaneActive(laneIndex))
                    continue;

                g_ScalarPerWave[s_WaveIndex] *= g_ScalarPerLane[(s_WaveIndex * GetLaneCount()) + laneIndex];
            }
        }
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveSum(uint v)
    {
        // Clear the wave.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically Add the lane's result.
        InterlockedAdd(g_ScalarPerWave[s_WaveIndex], v);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[s_WaveIndex];
    }

    float ActiveSum(float v)
    {
        // Must be emulated more manually since there is no float atomics to help us.
        ConfigureExecutionMask();

        // Write lane values to LDS.
        g_FloatPerLane[s_GroupIndex] = v;
        GroupMemoryBarrierWithGroupSync();

        const uint firstActiveLane = GetFirstActiveLaneIndex();

        // Task an active lane with resolving the product in LDS.
        // NOTE: See TODO, can't safely do a parallel reduction due to potentially inactive lanes.
        if (s_LaneIndex == firstActiveLane)
        {
            g_FloatPerWave[s_WaveIndex] = 0;

            for (uint laneIndex = 0; laneIndex < WAVE_SIZE; ++laneIndex)
            {
                if (!IsLaneActive(laneIndex))
                    continue;

                g_FloatPerWave[s_WaveIndex] += g_FloatPerLane[(s_WaveIndex * GetLaneCount()) + laneIndex];
            }
        }
        GroupMemoryBarrierWithGroupSync();

        return g_FloatPerWave[s_WaveIndex];
    }
}
