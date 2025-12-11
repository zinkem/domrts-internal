# Plan: Modular Canvas Caching for Sprite Rendering

*Issue #44 - Peon outline rendering optimization*

## Goal
Create a reusable canvas caching system inspired by rotoscopescenes' `render_utils.lua` that can be applied to peons first, then extended to other units/buildings.

## Problem Statement
Peon rendering currently draws 35-40 graphics primitives per peon, then repeats this 4x for outline offsets + 1x for main body = **~175-200 draw calls per peon per frame**. With 60 peons, that's 10,000+ draw calls just for peons.

## Reference Pattern (from rotoscopescenes)
```lua
-- Prerender at load time
local canvas = love.graphics.newCanvas(width, height)
love.graphics.setCanvas(canvas)
love.graphics.clear(0, 0, 0, 0)
-- draw complex primitives once
love.graphics.setCanvas()

-- At draw time, just blit
love.graphics.draw(canvas, x, y)
```

## Peon Visual States Analysis

**States that affect appearance:**
1. **Movement**: IDLE, MOVING, CHOPPING (with animations)
2. **Carrying**: nothing, gold, lumber
3. **Tool shown**: none, axe (chopping/lumber), pickaxe (harvesting/gold)

**Animation frames needed:**
- Walk cycle: ~6 frames
- Chopping cycle: ~8 frames (faster)
- Idle breathing: ~4 frames (slow, subtle)

**Total cache entries estimate:**
- 3 visual states x 3 carry states x 6 frames x 2 directions = ~108 canvases
- At 64x64 pixels each = ~1.7 MB VRAM (very reasonable)

## Implementation Plan

### Phase 1: Create SpriteCache Module
**File: `sprite_cache.lua`**

```lua
local SpriteCache = {}

-- Core pattern from rotoscopescenes
function SpriteCache.prerenderToCanvas(width, height, drawFn)
    local canvas = love.graphics.newCanvas(width, height)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.translate(width/2, height - 10)  -- center with padding
    drawFn()
    love.graphics.pop()
    love.graphics.setCanvas()
    return canvas
end

-- Organized cache structure
function SpriteCache.new()
    return {
        cache = {},  -- cache[unitType][state][carry][frame][direction]

        get = function(self, unitType, state, carry, frame, direction)
            -- nested lookup with lazy init
        end,

        prerender = function(self, unitType, drawBodyFn, states)
            -- batch prerender all frames for a unit type
        end
    }
end
```

### Phase 2: Refactor Peon Draw
**File: `peon.lua` modifications**

1. Extract `drawBody()` to be callable standalone (no closure over x, y)
2. Add `Peon.prerenderSprites()` called once at load time
3. Modify `Peon:draw()` to use cached canvases:

```lua
function Peon:draw()
    -- Get cached canvas for current state
    local state = self:getVisualState()  -- returns {state, carry, frame, direction}
    local canvas = PeonSpriteCache:get(state)

    -- Draw outline (4 offset blits)
    love.graphics.setColor(0.1, 0.08, 0.05, 0.7)
    for _, off in ipairs({{-1.5,0}, {1.5,0}, {0,-1.5}, {0,1.5}}) do
        love.graphics.draw(canvas, x + off[1], y + off[2])
    end

    -- Draw main sprite
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, x, y)

    -- Draw flash effect live (not cached)
    if self.flashTimer > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.draw(canvas, x, y)
        love.graphics.setBlendMode("alpha")
    end

    -- Selection circle and health bar (not cached)
    self:drawHealthBar()
end
```

### Phase 3: Integration
**File: `gameplay.lua` or `main.lua`**

Call prerender once during game load:
```lua
function love.load()
    -- ... existing load code ...
    Peon.prerenderSprites()
end
```

## What Stays Live (Not Cached)
- Selection circle (pulsing animation)
- Health bar (dynamic value)
- Flash effect (temporary state)
- Shadow (could be cached separately)

## Existing Infrastructure
- `draw_utils.lua` already has:
  - `DrawUtils.drawOutline(drawFunc, thickness, color)` - 8-direction outline
  - `DrawUtils.applyFlash(entity, drawFunc)` - damage flash effect
  - `DrawUtils.drawUnitWithOutline()` - combined helper
  - Animation helpers: `getIdleBob()`, `getWalkBob()`, `globalTime`

The new sprite cache can either extend `draw_utils.lua` or be a separate module that uses it.

## Files to Modify
1. **NEW: `sprite_cache.lua`** - Reusable canvas caching module
2. **MODIFY: `peon.lua`** - Refactor draw, add prerendering
3. **MODIFY: `main.lua`** - Call prerender at load time

## Expected Performance Gain
- **Before**: ~175 primitive draws per peon x 60 peons = 10,500 draw calls
- **After**: 5 canvas blits per peon x 60 peons = 300 draw calls
- **Reduction**: ~97% fewer draw calls for peon rendering

## Memory Cost
- ~108 canvases at 64x64 RGBA = ~1.7 MB VRAM
- Acceptable trade-off for latency improvement

## Future Extensions
- Apply same pattern to Footman, Archer, Knight
- Apply to building sprites (fewer states, bigger canvases)
- Consider texture atlas packing for further optimization
