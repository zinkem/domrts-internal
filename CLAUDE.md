# ArtCraft - AI Context File

## Project Overview

A Warcraft-style RTS game built with LÖVE 11.4 (Love2D) and Lua.
Resolution: 1280x720 fixed. Isometric 2:1 projection.

**See [main.lua](main.lua) lines 1-200 for comprehensive file structure documentation.**

## Quick Reference

### Core Architecture

| File | Responsibility | Lines | Complexity |
|------|----------------|-------|------------|
| gameplay.lua | Main game loop, state, rendering, input | ~5000 | HIGH - central hub |
| peon.lua | Worker AI, resource gathering, building | ~1500 | HIGH - complex state machine |
| unit.lua | Base unit behavior, combat, movement | ~800 | MEDIUM |
| map.lua | Terrain, fog of war, camera, tiles | ~1500 | MEDIUM |
| pathfinding.lua | A* navigation, path caching | ~900 | MEDIUM |
| townhall.lua | Main building, peon production | ~2200 | MEDIUM |

### Key Modules by Category

**Entry/Scenes:** main.lua, title.lua, gameplay.lua, victory.lua
**Units:** peon.lua, footman.lua, knight.lua, archer.lua, ballista.lua, kamikaze.lua, flyingscout.lua
**Buildings:** townhall.lua, barracks.lua, blacksmith.lua, farm.lua, lumbermill.lua, scouttower.lua, stable.lua, siegeworkshop.lua, goldmine.lua
**Systems:** map.lua, pathfinding.lua, flowfield.lua, quadtree.lua, ai.lua
**UI:** button.lua, command_bar.lua, ui_draw.lua, draw_utils.lua
**Utils:** iso_utils.lua, building_renderer.lua, building_placement.lua, cursor.lua, audio.lua

### Common Patterns

1. **State machines** - Units/buildings use string states: "Idle", "Moving", "Attacking", etc.
2. **Team ownership** - `entity.team` (1 = player, 2 = enemy AI)
3. **Grid coordinates** - `tileX, tileY` for map positions
4. **World coordinates** - `x, y` in pixels for rendering
5. **Isometric conversion** - Use `iso_utils.lua` for grid<->screen transforms

### Performance Hotspots (see workplan.txt)

1. `getAllUnits()` / `getAllBuildings()` - called multiple times per frame
2. Unit separation - O(n²) distance calculations
3. Peon collision - checks all buildings per move
4. Fog of war neighbor checking
5. Depth sorting every frame

## Development Conventions

### Commit Messages
Use the template in `.gitmessage`. Include:
- Type prefix: feat, fix, refactor, perf, docs, test, chore
- Bug risk assessment
- Affected modules checklist

### File Organization
- One unit type per file (peon.lua, footman.lua, etc.)
- One building type per file (townhall.lua, barracks.lua, etc.)
- Shared utilities in dedicated modules (iso_utils.lua, draw_utils.lua)

### State Machine Convention
```lua
unit.state = "Idle"  -- String-based states
function unit:update(dt)
    if self.state == "Idle" then
        -- idle logic
    elseif self.state == "Moving" then
        -- movement logic
    end
end
```

### Building Requirements
Buildings use a tech tree. Check `requirements.lua` for dependency validation.

## AI Instructions

### Before Making Changes
1. Read the target file(s) first
2. Check workplan.txt for related performance concerns
3. Understand the state machine if modifying unit/building behavior

### High-Risk Areas
- gameplay.lua - touches everything, easy to break
- peon.lua - complex state machine, many edge cases
- pathfinding.lua - performance critical
- quadtree.lua - spatial queries depend on this

### Testing Checklist
- [ ] Manual playtest with 10+ units
- [ ] Check for console errors
- [ ] Verify no performance regression
- [ ] Test edge cases (map boundaries, depleted resources)

## Recent Focus Areas

Check `git log --oneline -10` for recent changes.
Recent commits are more likely to have undiscovered bugs.

## Git Hooks

This repo uses custom hooks in `.githooks/`. Enable with:
```bash
git config core.hooksPath .githooks
```

Hooks provide:
- **prepare-commit-msg**: Injects diff into commit message for AI review
- **post-commit**: Shows workplan reminders after each commit
- **post-checkout**: Shows recent commits when switching branches

## Resources

- [LÖVE 11.4 Wiki](https://love2d.org/wiki/Main_Page)
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)
