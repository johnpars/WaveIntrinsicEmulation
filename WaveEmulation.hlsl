// Utility for the LDS emulation of compute wave-ops in SM 6.0.

namespace Wave
{
#if EMULATE_WAVE_OPS
    // Scratch LDS memory for emulation.
    groupshared dword g_Scratch[WAVE_SIZE];

    static uint s_GroupIndex;
    void Configure(uint groupIndex) { s_GroupIndex = groupIndex; }

    // Query
    uint GetLaneCount() { return WAVE_SIZE; }
    uint GetLaneIndex() { return s_GroupIndex % GetLaneCount(); }
    bool IsFirstLane()  { return GetLaneIndex() == 0; }
#else
    void Configure(uint groupIndex) {  }

    // Query
    uint GetLaneCount() { return WaveGetLaneCount(); }
    uint GetLaneIndex() { return WaveGetLaneIndex(); }
    bool IsFirstLane()  { return WaveIsFirstLane();  }
#endif
}
