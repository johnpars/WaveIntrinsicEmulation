// Utility for the emulation of SM 6.0 compute wave-ops for SM 5.0.

// Idea: Initialize LDS to null / inactive, after every op, active thread resets the lane to null.
// Idea: Use asuint to reduce LDS usage
// TODO: Check that per-wave results are in scalar registers, not vector registers.
// TODO: Execution mask is currently hard coded 32-bit, need to support up to 128 bit (128 lane wave).

namespace Wave
{
#if EMULATE_WAVE_OPS

    // Per-thread state.
    static uint s_GroupIndex;
    static uint s_LaneIndex;

    // LDS scratch space and execution mask for emulation.
    groupshared uint g_ScalarPerLane [WAVE_SIZE * NUM_WAVE];
    groupshared bool g_BoolPerLane   [WAVE_SIZE * NUM_WAVE];
    groupshared uint g_ScalarPerWave [NUM_WAVE];
    groupshared bool g_BoolPerWave   [NUM_WAVE];
    groupshared uint g_ExecutionMask [NUM_WAVE];

    // Query
    uint GetLaneCount() { return WAVE_SIZE; }
    uint GetLaneIndex() { return s_LaneIndex; }
    uint GetWaveIndex() { return floor(s_GroupIndex / WAVE_SIZE); }
    bool IsFirstLane()  { return GetLaneIndex() == 0; }

    // Vote
    bool ActiveAnyTrue(bool e)
    {
        const uint waveIndex = GetWaveIndex();

        InterlockedOr(g_ScalarPerWave[waveIndex], (uint)e);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[waveIndex];
    }

    bool ActiveAllTrue(bool e)
    {
        const uint waveIndex = GetWaveIndex();

        if (IsFirstLane())
            g_ScalarPerWave[waveIndex] = 1;
        GroupMemoryBarrierWithGroupSync();

        InterlockedAnd(g_ScalarPerWave[waveIndex], (uint)e);
        GroupMemoryBarrierWithGroupSync();

        return g_ScalarPerWave[waveIndex];
    }

    uint4 ActiveBallot(bool e)
    {
        const uint waveIndex = GetWaveIndex();

        InterlockedOr(g_ExecutionMask[waveIndex], e << GetLaneIndex());
        GroupMemoryBarrierWithGroupSync();

        return uint4(g_ExecutionMask[waveIndex], 0, 0, 0);
    }

    float ReadLaneAt(float v, uint laneIndex)
    {
        g_ScalarPerLane[s_GroupIndex] = asuint(v);
        GroupMemoryBarrierWithGroupSync();

        return asfloat(g_ScalarPerLane[(GetWaveIndex() * GetLaneCount()) + laneIndex]);
    }

    void Configure(uint groupIndex)
    {
        // Cache the group / lane index in static thread memory.
        s_GroupIndex = groupIndex;
        s_LaneIndex  = groupIndex % WAVE_SIZE;

        // Initialize the execution mask to an inactive state.
        if (IsFirstLane())
            g_ExecutionMask[GetWaveIndex()] = 0;
    }
#else
    // Query
    uint GetLaneCount() { return WaveGetLaneCount(); }
    uint GetLaneIndex() { return WaveGetLaneIndex(); }
    bool IsFirstLane()  { return WaveIsFirstLane();  }

    // Vote
    bool ActiveAnyTrue(bool e) { return WaveActiveAnyTrue(e); }
    bool ActiveAllTrue(bool e) { return WaveActiveAllTrue(e); }
    uint4 ActiveBallot(bool e) { return WaveActiveBallot(e);  }

    // Broadcast
    uint ReadLaneAt(uint i, uint laneIndex) { return WaveReadLaneAt(i, landIndex); }

    // Unused
    void Configure(uint groupIndex) {}
#endif
}
