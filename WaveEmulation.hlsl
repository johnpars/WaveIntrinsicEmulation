// Utility for the LDS emulation of compute wave-ops in SM 6.0.

// Idea: Initialize LDS to null / inactive, after every op, active thread resets the lane to null.
// Idea: Use asuint to reduce LDS usage

namespace Wave
{
#if EMULATE_WAVE_OPS

    // Per-thread state.
    static uint s_GroupIndex;
    static uint s_LaneIndex;

    // LDS scratch space and execution mask for emulation.
    // For a max
    groupshared uint g_ExecutionMask [WAVE_SIZE * NUM_WAVE];
    groupshared uint g_ScalarPerLane [WAVE_SIZE * NUM_WAVE];
    groupshared bool g_BoolPerLane   [WAVE_SIZE * NUM_WAVE];
    groupshared uint g_ScalarPerWave [NUM_WAVE];
    groupshared bool g_BoolPerWave   [NUM_WAVE];


    // Utility

    void Configure(uint groupIndex)
    {
        // Initialize the execution mask to an inactive state.
        g_ExecutionMask[groupIndex] = 0;

        // Cache the group / lane index in static thread memory.
        s_GroupIndex = groupIndex;
        s_LaneIndex  = groupIndex % WAVE_SIZE;
    }

    void ActivateLane() { g_ExecutionMask[s_GroupIndex] = 1; }
    void KillLane()     { g_ExecutionMask[s_GroupIndex] = 0; }

    // Query
    uint GetLaneCount() { return WAVE_SIZE; }
    uint GetLaneIndex() { return s_LaneIndex; }
    uint GetWaveIndex() { return floor(s_GroupIndex / WAVE_SIZE); }
    bool IsFirstLane()  { return GetLaneIndex() == 0; }

    // Vote
    bool ActiveAnyTrue(bool e)
    {
        const uint waveIndex = GetWaveIndex();

        ActivateLane();
        {
            InterlockedOr(g_ScalarPerWave[waveIndex], (uint)e);
            GroupMemoryBarrierWithGroupSync();
        }
        KillLane();

        return g_ScalarPerWave[waveIndex];
    }

    bool ActiveAllTrue(bool e)
    {

    }

#else
    void Configure(uint groupIndex) {  }

    // Query
    uint GetLaneCount() { return WaveGetLaneCount(); }
    uint GetLaneIndex() { return WaveGetLaneIndex(); }
    bool IsFirstLane()  { return WaveIsFirstLane();  }

    // Vote
    bool ActiveAnyTrue(bool e) { return WaveActiveAnyTrue(e); }
#endif
}
