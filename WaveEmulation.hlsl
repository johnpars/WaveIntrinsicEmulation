// Utility library that emulates SM 6.0 Wave Intrinsics for SM 5.0.
// Helps to write backwards-compatible wave-ops code for SM 5.0.
// Currently not optimized to ensure SGPR during broadcasts / reductions.

// Idea: Use asuint to reduce LDS usage for scalars
// TODO: Check that per-wave results are in scalar registers, not vector registers.
// TODO: Execution mask is currently hard coded 32-bit, need to support up to 128 bit (128 lane wave).
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

    uint GetPerLaneOffset()
    {
        return s_WaveIndex * WAVE_SIZE;
    }

    void Configure(uint groupIndex)
    {
        // Cache the group / lane index in static thread memory.
        s_GroupIndex = groupIndex;
        s_WaveIndex  = floor(s_GroupIndex / WAVE_SIZE);
        s_LaneIndex  = s_GroupIndex % WAVE_SIZE;
    }

    // Per-wave execution mask. (Currently hardcoded for 32-lane wide waves).
    // -----------------------------------------------------------------------

    groupshared uint g_ExecutionMask [NUM_WAVE];

    void ConfigureExecutionMask(bool laneMask = true)
    {
        // Reset the execution mask.
        g_ExecutionMask[s_WaveIndex] = 0;

        // Atomically configure the mask per-lane.
        InterlockedOr(g_ExecutionMask[s_WaveIndex], laneMask << s_LaneIndex);
    }

    bool IsLaneActive(uint laneIndex)
    {
        return (g_ExecutionMask[s_WaveIndex] & (1u << laneIndex)) != 0;
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

    // LDS scratch space.
    // -----------------------------------------------------------------------

    groupshared uint g_ScalarPerLane [WAVE_SIZE * NUM_WAVE];
    groupshared uint g_ScalarPerWave [NUM_WAVE];

    // Query
    // -----------------------------------------------------------------------

    uint GetLaneCount()
    {
        return WAVE_SIZE;
    }

    uint GetLaneIndex()
    {
        return s_LaneIndex;
    }

    bool IsFirstLane()
    {
        ConfigureExecutionMask();

        // Following the rules of WaveIsFirstLane, return true for the first-most active lane in the wave.
        return s_LaneIndex == GetFirstActiveLaneIndex();
    }

    // Vote
    // -----------------------------------------------------------------------

    bool ActiveAnyTrue(bool bit)
    {
        // Clear the wave.
        g_ScalarPerWave[s_WaveIndex] = 0u;

        // Atomically OR the first bit.
        InterlockedOr(g_ScalarPerWave[s_WaveIndex], bit << 0u);

        // Any are true if the first bit is set.
        return (g_ScalarPerWave[s_WaveIndex] & (1u << 0u)) != 0u;
    }

    bool ActiveAllTrue(bool bit)
    {
        // Set the first bit.
        g_ScalarPerWave[s_WaveIndex] = 1u << 0u;

        // Atomically AND the first bit.
        InterlockedAnd(g_ScalarPerWave[s_WaveIndex], bit << 0u);

        // All are true if the first bit is set.
        return (g_ScalarPerWave[s_WaveIndex] & (1u << 0u)) != 0u;
    }

    uint4 ActiveBallot(bool bit)
    {
        // Directly use the execution mask to evaluate the expression across the wave.
        ConfigureExecutionMask(bit);

        return uint4(g_ExecutionMask[s_WaveIndex], 0, 0, 0);
    }

    // Broadcast
    // -----------------------------------------------------------------------

    uint ReadLaneAt(uint value, uint laneIndex)
    {
        // We will need the execution mask to safeguard against inactive lane results.
        ConfigureExecutionMask();

        // Microsoft docs state that "The return value from an invalid lane is undefined."
        // Return zero seems to match the intrinsic behavior and passes tests.
        if (!IsLaneActive(laneIndex))
            return 0;

        // Write the lane values to LDS.
        g_ScalarPerLane[s_GroupIndex] = value;

        return g_ScalarPerLane[GetPerLaneOffset() + laneIndex];
    }

    uint ReadLaneFirst(uint value)
    {
        // We will need the execution mask to search for the first-most active lane.
        ConfigureExecutionMask();

        // Search for the first-most active lane.
        uint firstLane = GetFirstActiveLaneIndex();

        // Write the lane values to LDS.
        g_ScalarPerLane[s_GroupIndex] = value;

        return g_ScalarPerLane[GetPerLaneOffset() + firstLane];
    }

    // Reduction
    // -----------------------------------------------------------------------

    bool ActiveAllEqual(uint value)
    {
        // Clear all bits.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically OR the lane's result.
        InterlockedOr(g_ScalarPerWave[s_WaveIndex], value);

        // Comparison with original lane result.
        return g_ScalarPerWave[s_WaveIndex] == value;
    }

    uint ActiveBitAnd(uint value)
    {
        // Set all bits.
        g_ScalarPerWave[s_WaveIndex] = 0xffffffff;

        // Atomically AND the lane's result.
        InterlockedAnd(g_ScalarPerWave[s_WaveIndex], value);

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveBitOr(uint value)
    {
        // Clear all bits.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically OR the lane's result.
        InterlockedOr(g_ScalarPerWave[s_WaveIndex], value);

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveBitXor(uint value)
    {
        // Clear all bits.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically XOR the lane's result.
        InterlockedXor(g_ScalarPerWave[s_WaveIndex], value);

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveCountBits(uint bit)
    {
        // Case a ballot on the bit.
        const uint4 ballot = ActiveBallot(bit);

        // Just count up the ballot results with the intrinsic.
        return countbits(ballot.x) +
               countbits(ballot.y) +
               countbits(ballot.z) +
               countbits(ballot.w);
    }

    uint ActiveMax(uint value)
    {
        // Clear the wave.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically Max the lane's result.
        InterlockedMax(g_ScalarPerWave[s_WaveIndex], value);

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveMin(uint value)
    {
        // Set all bits.
        g_ScalarPerWave[s_WaveIndex] = 0xffffffff;

        // Atomically Min the lane's result.
        InterlockedMin(g_ScalarPerWave[s_WaveIndex], value);

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveProduct(uint value)
    {
        // Must be emulated more manually since there is no atomic product to help us.
        ConfigureExecutionMask();

        // Write lane values to LDS.
        g_ScalarPerLane[s_GroupIndex] = value;

        // Task an active lane with resolving the product in LDS.
        if (s_LaneIndex == GetFirstActiveLaneIndex())
        {
            // Initialize the reduction to the identity.
            g_ScalarPerWave[s_WaveIndex] = 1;

            // Scan and reduce.
            for (uint laneIndex = 0; laneIndex < WAVE_SIZE; ++laneIndex)
            {
                if (!IsLaneActive(laneIndex))
                    continue;

                g_ScalarPerWave[s_WaveIndex] *= g_ScalarPerLane[GetPerLaneOffset() + laneIndex];
            }
        }

        // For some unknown reason a barrier is mandatory here.
        // This should technically not be the case since we are only every doing intra-wave coordination, not intra-block coordination,
        // but it's likely there is some kind of compiler rule I am missing that is forcing the need for the barrier.
        // I'm also not sure performing reduction on the LDS even makes sense here, it can be done for each lane.
        GroupMemoryBarrier();

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint ActiveSum(uint value)
    {
        // Clear the wave.
        g_ScalarPerWave[s_WaveIndex] = 0;

        // Atomically Add the lane's result.
        InterlockedAdd(g_ScalarPerWave[s_WaveIndex], value);

        return g_ScalarPerWave[s_WaveIndex];
    }

    uint PrefixSum(uint value)
    {
        ConfigureExecutionMask();

        // Set the value for each lane.
        g_ScalarPerLane[s_GroupIndex] = value;

        // Grab the lane offset into LDS.
        const uint offset = GetPerLaneOffset();

        if (s_LaneIndex == GetFirstActiveLaneIndex())
        {
            // Keep track of the last active lane.
            uint lastActiveLaneIndex = s_LaneIndex;

            // Scan over the wave, beginning with the lane after the first active one.
            for (uint laneIndex = s_LaneIndex + 1; laneIndex < WAVE_SIZE; ++laneIndex)
            {
                if (!IsLaneActive(laneIndex))
                    continue;

                // Prefix sum.
                g_ScalarPerLane[offset + laneIndex] += g_ScalarPerLane[offset + lastActiveLaneIndex];

                // Update the last active lane index.
                lastActiveLaneIndex = laneIndex;
            }
        }

        // Just computed the inclusive prefix sum, subtract the lane's value to get the exclusive one.
        return g_ScalarPerLane[offset + s_LaneIndex] - value;
    }

    uint PrefixCountBits(bool bit)
    {
        // Re-use the prefix sum for scalars.
        return PrefixSum(bit << 0u);
    }

    uint PrefixProduct(uint value)
    {
        ConfigureExecutionMask();

        // Set the value for each lane.
        g_ScalarPerLane[s_GroupIndex] = value;

        // Grab the lane offset into LDS.
        const uint offset = GetPerLaneOffset();

        if (s_LaneIndex == GetFirstActiveLaneIndex())
        {
            // Begin with the identity for the first active lane.
            uint prefixProduct = 1;

            // Perform an exclusive prefix product. It is better to do it this way rather than an inclusive prefix product
            // (follow by a division of the lane's value at the end) since it prevents stability issues and divide by 0.
            for (uint laneIndex = s_LaneIndex; laneIndex < WAVE_SIZE; ++laneIndex)
            {
                if (!IsLaneActive(laneIndex))
                    continue;

                // Preserve this lane's value for the next iteration.
                uint laneValue = g_ScalarPerLane[offset + laneIndex];

                // Set this lane to the prefix product computed in the previous iteration.
                g_ScalarPerLane[offset + laneIndex] = prefixProduct;

                // Prefix product for next iteration.
                prefixProduct *= laneValue;
            }
        }

        // Exclusive prefix product, which means we need to divide by the lane's value.
        return g_ScalarPerLane[offset + s_LaneIndex];
    }
}
