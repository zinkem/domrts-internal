# Retrospective: Fog Edge Caching (Rejected)

**Issue**: #43 - Fog of war neighbor checking
**Branch**: `perf/43-fog-edge-caching`
**PR**: #49 (left open, not merged)
**Date**: 2025-12-11

## Summary

Attempted to cache fog edge alpha values to avoid recalculating 8 neighbor lookups per fog cell every frame. The optimization showed **mixed results** - significantly faster for idle scenarios but slower during active gameplay. Decision: leave PR open, do not merge.

## Problem Analysis

### Original Hotspot
From workplan.txt:
> Fog of war neighbor checking (map.lua:941-1006)
> - 8 neighbor checks per visible fog cell (~475 cells x 8 = 3,800 lookups/frame)
> - Fix: Cache fog edge states, only recalculate when fog changes

### The Theory
Fog edge alpha depends only on:
1. The cell's own fog state (UNEXPLORED, EXPLORED, VISIBLE)
2. The fog states of its 8 neighbors

Cache the computed alpha, only recalculate when any of these 9 cells change.

### Implementation
- Added `fogEdgeAlpha` cache and `fogChangedCells` tracking
- Modified `updateFog()` to track which cells change state
- Modified `revealArea()` to record state transitions
- Added `computeFogEdgeAlpha()` - extracts neighbor calculation
- Added `updateFogEdgeCache()` - only updates affected cells + neighbors
- Modified `drawFog()` to read cached alphas instead of calculating

## Benchmark Results

| Scenario | develop | feature | Difference |
|----------|---------|---------|------------|
| **Steady state** (no fog changes) | 11.5 ms | 2.4 ms | **4.8x faster** |
| **With fog updates** (active gameplay) | 18.2 ms | 32.8 ms | **1.8x slower** |

## Why It Failed

### The VISIBLE→EXPLORED Reset Pattern

The core issue is in `updateFog()`:

```lua
-- Reset all visible to explored (will be re-revealed by current units)
for y = 1, self.fogHeight do
    for x = 1, self.fogWidth do
        if self.fog[y][x] == Map.FOG_VISIBLE then
            self.fog[y][x] = Map.FOG_EXPLORED
            -- This marks the cell as changed!
        end
    end
end
```

Every frame during normal gameplay:
1. All VISIBLE cells reset to EXPLORED (marking them as "changed")
2. Units re-reveal their sight areas (marking more cells as "changed")
3. The cache rebuild touches most of the visible area

**Result**: The overhead of tracking changes + rebuilding cache exceeds the savings from caching.

### When It Works vs Doesn't

| Scenario | Cache Effective? | Why |
|----------|------------------|-----|
| Idle army (no movement) | ✅ Yes | No fog changes, cache fully utilized |
| Building placement | ✅ Mostly | One-time reveal, then stable |
| Units moving | ❌ No | Continuous fog updates every frame |
| Combat | ❌ No | Units constantly repositioning |

Since "units moving" and "combat" are the majority of gameplay, the optimization regresses the common case.

## Lessons Learned

### 1. Benchmark Before Celebrating
The theoretical analysis ("75-88% fewer lookups") looked great on paper. The benchmark revealed the reality: the change tracking overhead dominated.

### 2. Understand the Full Update Pattern
The optimization targeted `drawFog()` but didn't account for how `updateFog()` works. The VISIBLE→EXPLORED reset is fundamental to how fog reveals work - units must continuously "hold" visibility.

### 3. Caching Has Overhead
Change tracking isn't free:
- Checking if state changed: `if self.fog[y][x] ~= newState`
- Recording changes: `table.insert(self.fogChangedCells, {x, y})`
- Iterating changed cells + neighbors to rebuild cache

For a cache to win, savings must exceed this overhead. When most data changes every frame, caching loses.

### 4. Test Both Steady-State and Active Scenarios
The benchmark tested both, which revealed the trade-off. Testing only idle would have hidden the regression.

### 5. "Feels Good" Is Valid Data
The user noted "develop honestly feels pretty good right now." Subjective performance perception matters - if current performance is acceptable, risky optimizations aren't worth it.

## Alternative Approaches (Not Pursued)

1. **Optimize the reset pattern itself** - Instead of resetting all VISIBLE→EXPLORED, track which cells were revealed last frame and only reset those.

2. **Coarser granularity** - Cache at region level (8x8 chunks) instead of per-cell.

3. **Temporal stability detection** - Only enable caching when fog has been stable for N frames.

4. **Different fog model** - Instead of "units hold visibility," use "fog slowly creeps back" which would have fewer changes per frame.

These weren't pursued because current performance is acceptable.

## Outcome

- PR #49 left open with benchmark analysis comment
- Branch preserved for potential future revisit
- Workplan item marked as "investigated, deprioritized"
- **Key insight**: Not all hotspots benefit from caching

## Files Changed (in PR)

```
 benchmarks/benchmark_fog_caching.lua |  89 ++++++++++
 main.lua                             |  35 ++--
 map.lua                              | 220 ++++++++++++++++++------
 plans/fog-edge-caching.md            | 121 ++++++++++++++
 workplan.txt                         |   3 +-
 5 files changed, 398 insertions(+), 70 deletions(-)
```

## Positive Outcomes

Despite not merging the optimization:

1. **Dynamic benchmark discovery** - `main.lua` now auto-discovers benchmarks from `--benchmark-NAME` flags, making future benchmarking easier.

2. **Understanding gained** - We now understand the fog update pattern better, which informs future optimization attempts.

3. **Process validated** - The benchmark-before-merge workflow caught a regression that would have degraded gameplay performance.
