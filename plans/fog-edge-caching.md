# Plan: Fog of War Edge Caching

*Issue #43 - Fog of war checks 8 neighbors per visible cell every frame*

## Goal
Cache fog edge alpha values to avoid recalculating 8 neighbor lookups per fog cell every frame. Only recalculate when fog state actually changes.

## Problem Statement
In `map.lua:941-1006`, fog rendering calculates neighbor brightness for each visible fog cell to create smooth edges:
- Each cell checks 8 neighbors
- On a 128x128 map with ~475 visible fog cells = **3,800 lookups/frame**
- This runs every frame even when fog hasn't changed

## Current Code Analysis

### Fog States
```lua
Map.FOG_UNEXPLORED = 0  -- Black, never seen
Map.FOG_EXPLORED = 1    -- Dimmed, seen before
Map.FOG_VISIBLE = 2     -- Full visibility
```

### Update Flow
1. `updateFog()` called every frame:
   - Resets all VISIBLE → EXPLORED
   - Reveals areas around units/buildings
2. `drawFog()` renders fog with edge softening

### Edge Calculation (the expensive part)
For each fog cell, counts neighbors brighter/darker to determine alpha:
```lua
-- For UNEXPLORED cells: count brighter neighbors
local brighterCount = countBrighterNeighbors(fx, fy, fogState)
local alpha = 1 - (brighterCount * 0.08)

-- For EXPLORED cells: count brighter neighbors
local alpha = 0.6 - (brighterCount * 0.04)

-- For VISIBLE cells: count darker neighbors
for dy = -1, 1 do
    for dx = -1, 1 do
        if nVis < Map.FOG_VISIBLE then darkerCount = darkerCount + 1 end
    end
end
```

## Solution Design

### Key Insight
The edge alpha for a cell depends only on:
1. The cell's own fog state
2. The fog states of its 8 neighbors

We can cache the computed alpha and only recalculate when any of these 9 cells change.

### Approach: Incremental Cache Update
Track which cells changed state this frame, then only recalculate edge alpha for changed cells + their neighbors.

```lua
self.fogChangedCells = {}  -- List of {x, y} that changed

-- When setting fog state:
if self.fog[fy][fx] ~= newState then
    self.fog[fy][fx] = newState
    table.insert(self.fogChangedCells, {fx, fy})
end

-- At end of updateFog:
-- Only recalc edge alpha for changed cells + their neighbors
for _, cell in ipairs(self.fogChangedCells) do
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = cell[1] + dx, cell[2] + dy
            if nx >= 1 and nx <= fogWidth and ny >= 1 and ny <= fogHeight then
                self.fogEdgeAlpha[ny][nx] = self:computeFogEdgeAlpha(nx, ny)
            end
        end
    end
end
```

## Implementation Plan

### Phase 1: Add Edge Cache Structure
**File: `map.lua`**
- Add `self.fogEdgeAlpha = {}` in Map:new()
- Initialize cache in `initFog()`

### Phase 2: Track Changed Cells
**File: `map.lua`**
- Modify `revealArea()` to track changed cells
- Modify the VISIBLE→EXPLORED reset to track changes
- Clear change list at start of `updateFog()`

### Phase 3: Incremental Cache Update
**File: `map.lua`**
- Add `Map:computeFogEdgeAlpha(fx, fy)` - extracts current neighbor calculation
- Add `Map:updateFogEdgeCache()` - only updates changed cells + neighbors
- Call at end of `updateFog()`

### Phase 4: Use Cache in Draw
**File: `map.lua`**
- Modify `drawFog()` to read from `fogEdgeAlpha[fy][fx]` instead of calculating

## Files to Modify
1. **map.lua** - All changes in one file

## Expected Performance Gain
- **Before**: 475 cells × 8 neighbors = 3,800 lookups/frame
- **After**: Only changed cells (~50-100) × 9 cells = 450-900 lookups/frame
- **Reduction**: ~75-88% fewer neighbor lookups

When units are stationary (idle army), nearly zero recalculations.

## Memory Cost
- `fogEdgeAlpha[256][256]` = 65K floats = ~260 KB (negligible)

## Edge Cases
- Initial fog reveal (large area) - acceptable one-time cost
- Building placed - reveals area, triggers recalc
- Unit death - fog shrinks, triggers recalc
