# Performance Optimization Report: Building Collision Quadtree

## Issue
[#42 - PERF: Peon collision checks all buildings per move](https://github.com/zinkem/domrts/issues/42)

## Problem

`Peon:canMoveTo()` was checking collisions against ALL buildings every time it was called. This function is called up to 8 times per peon per frame (once for each movement direction).

```lua
-- OLD: O(peons × buildings)
function Peon:canMoveTo(newX, newY, buildings)
    for _, b in ipairs(buildings) do  -- Loops ALL buildings!
        local penetration = self:getBuildingPenetration(newX, newY, b)
        if penetration > 0 then
            return false
        end
    end
    return true
end
```

### Impact Analysis

| Scenario | Peons | Buildings | Checks/Frame |
|----------|-------|-----------|--------------|
| Early game | 7 | 10 | 7 × 8 × 10 = **560** |
| Mid game | 20 | 30 | 20 × 8 × 30 = **4,800** |
| Late game | 40 | 60 | 40 × 8 × 60 = **19,200** |
| Stress test | 60 | 100 | 60 × 8 × 100 = **48,000** |

On larger maps (256×256), players build more structures and train more peons, making this bottleneck increasingly severe.

## Solution

Reuse the existing quadtree infrastructure (from unit separation optimization) for buildings.

### Changes

1. **gameplay.lua**: Added `buildingQuadtree` alongside existing `unitQuadtree`
   - Accessor functions `getBuildingX`/`getBuildingY` use building center from `getWorldBounds()`
   - Refreshed once per frame (buildings don't move, but can be built/destroyed)
   - Passed to peons via `peon.buildingQuadtreeRef` property injection

2. **peon.lua**: Modified `canMoveTo()` to query nearby buildings
   - Query radius: 78 pixels (peon radius + max 3×3 building half-size + margin)
   - Falls back to linear search if quadtree unavailable
   - Uses reusable results table to avoid per-query allocation

```lua
-- NEW: O(peons × log(buildings))
function Peon:canMoveTo(newX, newY, buildings)
    local nearbyBuildings
    if self.buildingQuadtreeRef then
        nearbyBuildings = self.buildingQuadtreeRef:query(
            newX, newY, BUILDING_QUERY_RADIUS,
            queryResults, getBuildingQX, getBuildingQY
        )
    else
        nearbyBuildings = buildings  -- Fallback
    end

    for _, b in ipairs(nearbyBuildings) do
        -- Only checks 1-4 buildings instead of all 30+
    end
end
```

## Benchmark Results

```
============================================================
BENCHMARK: Building Collision - Quadtree vs Linear
============================================================

--- Early game (7 peons, 10 buildings) ---
  OLD (linear):   0.0074s (56000 collision checks)
  NEW (quadtree): 0.0047s (0 collision checks)
  Speedup: 1.58x faster

--- Mid game (20 peons, 30 buildings) ---
  OLD (linear):   0.0629s (480000 collision checks)
  NEW (quadtree): 0.0222s (0 collision checks)
  Speedup: 2.83x faster

--- Late game (40 peons, 60 buildings) ---
  OLD (linear):   0.2491s (1920000 collision checks)
  NEW (quadtree): 0.0604s (800 collision checks)
  Speedup: 4.13x faster
  Checks reduced: 2400x fewer

--- Stress test (60 peons, 100 buildings) ---
  OLD (linear):   0.6094s (4800000 collision checks)
  NEW (quadtree): 0.1103s (3200 collision checks)
  Speedup: 5.52x faster
  Checks reduced: 1500x fewer
============================================================
```

### Key Observations

1. **Sparse early game**: Quadtree queries often return 0 buildings because peons aren't near any structures. This is optimal - no work done when no work needed!

2. **Scaling**: Speedup increases with entity count (1.58x → 5.52x). The quadtree overhead is amortized over more queries.

3. **Real-world impact**: User reported 256×256 maps feeling "as smooth as other sizes" immediately after this change. The improvement was noticeable at game start, not just late game.

## Why Map Size Matters

Larger maps don't directly affect collision code, but they **enable** more buildings and peons:
- More space = more structures built
- More gold mines/trees = more workers active
- The O(n²) problem compounds with scale

## Files Changed

- `gameplay.lua` - Building quadtree infrastructure
- `peon.lua` - Spatial query in `canMoveTo()`
- `benchmarks/benchmark_building_collision.lua` - Performance validation
- `main.lua` - Benchmark CLI flag

## Lessons Learned

1. **Reuse existing infrastructure**: The quadtree was already proven for unit separation. Extending it to buildings was straightforward.

2. **Property injection pattern**: Setting `peon.buildingQuadtreeRef = buildingQuadtree` avoids changing function signatures while providing access to shared state.

3. **Benchmark early**: Creating benchmarks validates the optimization and provides concrete numbers for documentation.

4. **Query radius matters**: Too small misses collisions. Too large defeats the purpose. Used conservative radius (peon + max building size + margin).

## Run the Benchmark

```bash
/Applications/love.app/Contents/MacOS/love . --benchmark-building-collision
```
