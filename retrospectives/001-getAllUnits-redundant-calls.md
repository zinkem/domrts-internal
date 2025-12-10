# Performance Optimization Report: getAllUnits/getAllBuildings Redundant Calls

## Objective

Eliminate redundant calls to `getAllUnits()` and `getAllBuildings()` which were being called 3+ times per frame, creating new tables and iterating through 7 unit types + 10 building types each time.

## Analysis

### Initial Investigation

Examined [gameplay.lua](../gameplay.lua) to trace all call sites:

| Line | Function | Context |
|------|----------|---------|
| 2668-2669 | Both | Fog of war update |
| 2675 | `getAllBuildings()` | Immediately after above (redundant) |
| 2971-2972 | Both | Combat updates |
| 298-299 | Both | Inside `separateUnits()` |
| 3041 | `getAllUnits()` | After `separateUnits()` (redundant) |

### Key Finding

Not all calls were truly redundant. Between some calls, the underlying data changes:

- **Lines 2668 → 2971**: Units can spawn (peons from town hall, footmen from barracks, etc.) during building updates. Fresh call is **necessary**.
- **Lines 2971 → 3038**: `removeDeadUnits()` modifies source arrays. `separateUnits()` needs fresh data. **Necessary**.
- **Line 2675**: Called 6 lines after 2669 with no data changes. **Redundant**.
- **Line 3041**: Called immediately after `separateUnits()` which already computed the same list. **Redundant**.

## Solution Approaches Considered

### Approach 1: Frame-Level Caching (Rejected)

Initially proposed adding module-level cache variables:

```lua
local cachedBuildings = nil
local cachedUnits = nil

local function invalidateFrameCache()
    cachedBuildings = nil
    cachedUnits = nil
end
```

**Why rejected**: User raised valid concern about polluting module scope with more locals that could cause problems later (stale data bugs, forgotten invalidation). Agreed to pursue simpler approach.

### Approach 2: Remove Redundant Calls (Implemented)

Simply restructure code to reuse existing variables where data hasn't changed.

## Implementation

### Change 1: Remove redundant `getAllBuildings()` at line 2675

**Before:**
```lua
local allUnits = getAllUnits()
local allBuildings = getAllBuildings()
map:updateFog(allUnits, allBuildings, playerTeam)

calculatePopulation()
updateRequirementsState()

local buildings = getAllBuildings()  -- REDUNDANT

-- Town hall
local peonReady, upgradeComplete, _ = townHall:update(gameDt)
```

**After:**
```lua
local allUnits = getAllUnits()
local allBuildings = getAllBuildings()
map:updateFog(allUnits, allBuildings, playerTeam)

calculatePopulation()
updateRequirementsState()

-- Town hall
local peonReady, upgradeComplete, _ = townHall:update(gameDt)
```

Note: The removed `buildings` variable was never used - `allBuildings` from line 2669 was already available.

### Change 2: Modify `separateUnits()` to return its computed lists

**Before:**
```lua
local function separateUnits()
    local allUnits = getAllUnits()
    local buildings = getAllBuildings()
    -- ... separation logic ...
end
```

**After:**
```lua
local function separateUnits()
    local allUnits = getAllUnits()
    local allBuildings = getAllBuildings()
    -- ... separation logic ...
    return allUnits, allBuildings
end
```

Also renamed internal `buildings` to `allBuildings` for consistency.

### Change 3: Reuse returned values instead of redundant call

**Before:**
```lua
-- Separate overlapping units
separateUnits()

-- Ensure no units are inside buildings (safety check)
local allUnits = getAllUnits()  -- REDUNDANT
for _, unit in ipairs(allUnits) do
    pushUnitOutOfBuildings(unit)
end
```

**After:**
```lua
-- Separate overlapping units (returns fresh lists after dead removal)
local allUnits, allBuildings = separateUnits()

-- Ensure no units are inside buildings (safety check)
for _, unit in ipairs(allUnits) do
    pushUnitOutOfBuildings(unit)
end
```

## Verification

### Benchmark Creation

Created [benchmark_getAllUnits.lua](../benchmark_getAllUnits.lua) to measure the improvement. Added `--benchmark` flag to [main.lua](../main.lua) for easy execution.

The benchmark simulates both OLD (8 function calls per frame) and NEW (6 function calls per frame) patterns across different game sizes.

### Benchmark Results

Ran `love . --benchmark`:

| Scenario | Units | Buildings | OLD | NEW | Improvement | Per Frame |
|----------|-------|-----------|-----|-----|-------------|-----------|
| Early game | 20 | 10 | 0.028s | 0.021s | 25% | 0.7 µs |
| Mid game | 50 | 20 | 0.065s | 0.048s | 27% | 1.75 µs |
| Late game | 100 | 30 | 0.116s | 0.086s | 26% | 3.06 µs |
| Stress test | 200 | 50 | 0.206s | 0.165s | 20% | 4.05 µs |

### Real-World Impact

At 60 FPS with 100 units (typical late-game scenario):
- **3 µs saved per frame**
- **180 µs saved per second**
- Reduces table allocations by 25% for these functions
- Less GC pressure from fewer temporary tables

## Issues Encountered

1. **Edit tool string matching**: Initial edit failed because I copied grep output that had a typo (`ballistas` instead of `units`). Resolved by re-reading the exact file content.

2. **No standalone Lua interpreter**: `lua` and `luac` weren't installed. Resolved by integrating benchmark into Love2D via `--benchmark` flag.

3. **Git stash workflow**: Used `git stash` / `git stash pop` to compare before/after using the same benchmark code.

## Files Modified

- [gameplay.lua](../gameplay.lua) - Removed 2 redundant calls, modified `separateUnits()` to return values
- [main.lua](../main.lua) - Added `--benchmark` flag support

## Files Created

- [benchmark_getAllUnits.lua](../benchmark_getAllUnits.lua) - Performance benchmark

## Conclusion

Reduced `getAllUnits()`/`getAllBuildings()` calls from 8 to 6 per frame by eliminating genuinely redundant calls while preserving necessary ones where data changes. The optimization is minimal in code complexity (no new module-level state) while providing measurable improvement (~25% reduction in this specific overhead).
