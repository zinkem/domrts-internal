# Retrospective: Peon Sprite Canvas Caching

**Issue**: #44 - Peon outline rendering draws body 5x per peon
**Branch**: `perf/44-peon-sprite-caching`
**Date**: 2025-12-11

## Summary

Implemented a modular canvas caching system that prerenders peon sprites at load time, reducing draw calls from ~175 primitives per peon to 5 canvas blits. This follows the pattern from the rotoscopescenes project's `render_utils.lua`.

## Problem Analysis

### Original Implementation
The peon `draw()` function:
1. Drew ~35 graphics primitives (ellipses, rectangles, polygons, lines) for body parts
2. Repeated this 4x for outline offsets (4 directions)
3. Drew once more for the main body
4. Total: **~175 draw calls per peon per frame**

With 60 peons on screen: **~10,500 draw calls** just for peon rendering.

### Root Cause
Love2D's immediate-mode graphics API treats each primitive as a separate draw call. While individual calls are fast, the sheer volume creates CPU overhead from state changes and GPU command submission.

## Solution Design

### Cross-Project Inspiration: rotoscopescenes

The solution came from examining `../rotoscopescenes/`, a sibling Love2D project focused on character animation with hand-drawn aesthetics. Despite its name suggesting video processing, it's actually a **procedural character animation system** with features like:

- Dynamic jump animations that adapt to movement state
- 12 FPS keyframe animation with smoothstep interpolation
- "Wobble" rendering for organic, sketchy look
- Visual animation editor for tweaking frames

**How the Pattern Evolved There**

The git history tells the story of refactoring toward canvas caching:

1. **`01f0da0`** - *"Refactor: consolidate duplicate character rendering code"*
   - Created `render_utils.lua` with color manipulation helpers
   - Extracted shared `renderCharacterBody()` function
   - Reduced ~170 lines of duplication between editor and game rendering

2. **`81de11e`** - *"Refactor: extract character rendering to RenderUtils for reuse"*
   - Moved ~600 lines from `BodyEditor.draw()` into reusable functions
   - Added key functions:
     - `drawCharacterAtOrigin()` - core rendering with layers, physics, face
     - `prerenderFrame()` - render single frame to canvas
     - `prerenderAllFrames()` - batch prerender walk/run/jump animations

3. **`324fbac`** - *"Use RenderUtils to prerender player character frames"*
   - Connected prerendering to game initialization
   - Player now renders from body spec via cached canvases

**The Core Pattern from rotoscopescenes**

```lua
-- render_utils.lua:728-756
function RenderUtils.prerenderFrame(frame, facingDir, body, options)
    local charWidth = 180
    local charHeight = 140
    local canvas = love.graphics.newCanvas(charWidth, charHeight)

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()

    -- Position character in center of canvas
    local cx = charWidth / 2
    local cy = charHeight - 20
    love.graphics.translate(cx, cy)
    if facingDir == -1 then
        love.graphics.scale(-1, 1)
    end

    RenderUtils.drawCharacterAtOrigin(frame, offsetFrame, body, options or {})

    love.graphics.pop()
    love.graphics.setCanvas()
    return canvas
end
```

The batch prerender function then generates all animation variants:

```lua
function RenderUtils.prerenderAllFrames(walkFrames, runFrames, jumpFrames, body)
    local frames = {
        walk = {right = {}, left = {}},
        run = {right = {}, left = {}},
        jump = {right = {}, left = {}},
    }
    for i, frameData in ipairs(walkFrames) do
        frames.walk.right[i] = RenderUtils.prerenderFrame(frameData, 1, body, {...})
        frames.walk.left[i] = RenderUtils.prerenderFrame(frameData, -1, body, {...})
    end
    -- ... run, jump similarly
    return frames
end
```

**What We Adapted**

The rotoscopescenes pattern was designed for a single player character with:
- Complex body spec (torso, limbs, face, clothing layers)
- Directional facing (left/right mirroring)
- Multiple animation states (walk, run, jump, crouch)

For artcraft peons, we adapted this to:
- Simpler but still multi-part sprites
- No directional mirroring needed (peons face camera)
- Different state matrix (idle, walk, chop, harvest × carry state)
- Combinatorial variant generation (our `prerender()` auto-generates all combinations)

The key architectural difference: rotoscopescenes prerenders specific known frames, while our `SpriteCache` module uses **declarative variants** that automatically generate all combinations. This makes it easier to extend to other unit types.

### Key Insight
Peon visual appearance depends on discrete states that can be enumerated:
- **Animation state**: idle, walk, chop, harvest
- **Carry state**: none, gold, lumber
- **Animation frame**: 4-8 frames per state

Total combinations: ~44 unique sprites that cover all visual variations.

### Architecture

Created a **modular, reusable** `SpriteCache` module:

```
sprite_cache.lua
├── SpriteCache.new(width, height, options)
├── cache:prerender(state, drawFn, variants)  -- generates all combinations
├── cache:get(state, variant1, variant2, ...)  -- O(1) lookup
├── cache:getStats()  -- memory tracking
└── cache:clear()  -- cleanup
```

The prerender function accepts a variants table and automatically generates all combinations:
```lua
cache:prerender("walk", drawFn, {
    carry = {"none", "gold", "lumber"},  -- 3 variants
    frame = {0, 1, 2, 3, 4, 5}           -- 6 frames
})  -- generates 18 canvases
```

## Implementation Details

### Files Created/Modified

1. **NEW: `sprite_cache.lua`** (175 lines)
   - Generic canvas caching module
   - Combinatorial prerendering
   - Nested cache structure for fast lookup
   - Memory tracking

2. **MODIFIED: `peon.lua`**
   - Added `drawPeonBodyAtOrigin(params)` - parameterized body drawing
   - Added `Peon.prerenderSprites()` - called once at load time
   - Added `Peon:getVisualState()` - maps runtime state to cache keys
   - Refactored `Peon:draw()` to use cached canvases with fallback

3. **MODIFIED: `main.lua`**
   - Calls `Peon.prerenderSprites()` during `love.load()`

4. **NEW: `benchmarks/benchmark_peon_rendering.lua`**
   - Compares live drawing vs cached canvas performance

5. **NEW: `plans/sprite-canvas-caching.md`**
   - Preserved implementation plan as documentation

### What Gets Cached vs. Rendered Live

**Cached (in sprite canvases):**
- Body, limbs, head, face
- Arms swing animation
- Tools (axe/pickaxe)
- Carried resources (gold sack/lumber bundle)
- Breathing animation

**Rendered Live (per frame):**
- Selection circle (pulsing animation)
- Shadow (stays at ground level)
- Health bar (dynamic value)
- Damage flash effect (temporary state)
- Vertical bounce offsets (chop jump, walk bob, idle bob)

### Quantization Strategy

Continuous `animTimer` is quantized to discrete frames:
```lua
local phase = self.animTimer * animSpeed
local frame = math.floor(phase % frameCount)
```

This maps smooth animation timing to prerendered frame indices.

## Benchmark Results

```
============================================================
BENCHMARK: Peon Rendering - Canvas Caching vs Live Drawing
============================================================

Creating sprite cache...
  Cached 44 canvases (0.69 MB VRAM)

--- Small army (10 peons) ---
  OLD (live):   0.114s    NEW (cached): 0.003s    Speedup: 36.5x

--- Medium army (30 peons) ---
  OLD (live):   0.071s    NEW (cached): 0.011s    Speedup: 6.8x

--- Large army (60 peons) ---
  OLD (live):   0.080s    NEW (cached): 0.026s    Speedup: 3.1x

--- Stress test (100 peons) ---
  OLD (live):   0.133s    NEW (cached): 0.051s    Speedup: 2.6x

Draw calls reduced: 29.2x fewer across all scenarios
```

## Memory Trade-off

- **VRAM Cost**: 44 canvases at 64x64 RGBA = 0.69 MB
- **Benefit**: 2.6-36x faster rendering, 29x fewer draw calls
- **Verdict**: Excellent trade-off

## Design Decisions

### Why Not Cache Everything?

Some elements must remain live:
1. **Health bar** - value changes dynamically
2. **Selection circle** - pulsing animation tied to global time
3. **Flash effect** - temporary visual feedback
4. **Vertical offsets** - smooth bounce tied to continuous time

Caching these would require either:
- Many more cache variants (explosion of combinations)
- Losing smooth animation (stuttery appearance)

### Why Quantize to Frames?

Caching every unique `animTimer` value is impossible. Quantizing to ~6 frames per animation:
- Provides smooth enough animation (10-12 FPS animation rate)
- Keeps cache size manageable (44 total canvases)
- Matches typical sprite sheet animation

### Why Modular Design?

The `SpriteCache` module is intentionally generic:
- Can be reused for Footman, Archer, Knight, etc.
- Can be applied to building sprites
- Encapsulates canvas management complexity
- Easy to extend with new features (e.g., texture atlases)

## Lessons Learned

1. **Reference existing code** - Looking at rotoscopescenes' approach saved design time
2. **Enumerate states before implementing** - Counting 44 variants upfront validated the approach
3. **Keep fallback paths** - The live drawing fallback ensures the game still works without caching
4. **Benchmark before and after** - Concrete numbers validate the optimization

## Future Work

1. Apply pattern to other unit types (Footman, Archer, Knight)
2. Consider building sprite caching (fewer states, larger canvases)
3. Investigate texture atlas packing for further VRAM optimization
4. Profile real gameplay to measure actual frame time improvement

## Branch Comparison: Feature vs Develop

Final sanity check comparing actual peon draw performance between branches:

| Branch | Sprite Cache | Per Frame (60 peons) | Potential FPS |
|--------|-------------|----------------------|---------------|
| `develop` | NOT AVAILABLE | 1.22 ms | 816 |
| `perf/44-peon-sprite-caching` | ENABLED | 0.20 ms | 5,112 |

**Result: 6.1x faster** peon rendering with no regressions. The feature branch is definitively an improvement over develop.

## Files Changed

```
 benchmarks/benchmark_peon_rendering.lua | 397 ++++++++++++++++++++++++
 main.lua                                |   9 +
 peon.lua                                | 380 +++++++++++++++--------
 plans/sprite-canvas-caching.md          |  96 ++++++
 sprite_cache.lua                        | 175 +++++++++++
 5 files changed, 932 insertions(+), 125 deletions(-)
```
