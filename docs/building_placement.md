# Building Placement System

The building placement module handles the preview and validation system for placing buildings in the game.

## Overview

When a player selects a peon and clicks a build button (Farm, Barracks, etc.), the game enters "placement mode". The player sees a colored preview rectangle that follows their mouse cursor, showing where the building will be placed. Green indicates a valid location; red indicates invalid.

## User Flow

1. Select a peon
2. Click a build button in the command bar (e.g., "F" for Farm)
3. Mouse cursor now shows a building preview
4. Move mouse to find a valid location (green = valid, red = invalid)
5. Left-click to confirm placement, or right-click/Escape to cancel
6. If confirmed, the peon walks to the location and begins construction

## Validation Rules

A placement location is **valid** if all of the following are true:

### Terrain Clear
- The grid area must be clear of trees, water, and other impassable terrain
- Uses `map:isAreaClear(gridX, gridY, width, height)`

### No Building Overlap
- Cannot overlap with any existing building
- Checks all buildings: Town Hall, Gold Mines, Farms, Barracks, Towers, etc.
- Uses axis-aligned bounding box collision

### Town Hall Special Rule
- Town Halls cannot be placed within 2 tiles of any Gold Mine
- This ensures workers have space to path around the mine
- Edge-to-edge gap must be >= 2 tiles

## Building Sizes

| Building | Grid Size |
|----------|-----------|
| Farm | 2x2 |
| Scout Tower | 2x2 |
| Lumber Mill | 3x3 |
| Blacksmith | 3x3 |
| Stable | 3x3 |
| Barracks | 3x3 |
| Archery Range | 3x3 |
| Siege Workshop | 3x3 |
| Town Hall | 4x4 |

The building_placement module queries these sizes directly from each building's `GRID_SIZE` constant (e.g., `Farm.GRID_SIZE`), so the building modules are the single source of truth.

## Module API

### Creation
```lua
local BuildingPlacement = require("building_placement")
local placement = BuildingPlacement.new()
```

### Starting Placement
```lua
placement:start(peon, "farm")  -- peon is the unit that will build
```

### Checking State
```lua
if placement:isActive() then ... end
if placement:isValid() then ... end
local buildingType = placement:getBuildingType()
local peon = placement:getPeon()
local gridX, gridY = placement:getGridPosition()
```

### Update Loop (call every frame while active)
```lua
placement:update(map, goldMines, allBuildings)
```

### Drawing
```lua
placement:draw(map, Game.fonts)
```

### Input Handling
```lua
-- In mousepressed:
local handled, peon, buildingType, gridX, gridY = placement:mousepressed(x, y, button, map)
if handled and peon then
    -- Placement confirmed - send peon to build
    peon:goToBuild(gridX, gridY, buildingType, createBuilding, costGold, costLumber)
end

-- In keypressed:
if placement:keypressed(key) then
    return  -- Escape was pressed, placement cancelled
end
```

### Cancelling
```lua
placement:cancel()
```

## Visual Feedback

- **Green rectangle**: Valid placement location
- **Red rectangle**: Invalid placement location
- **White outline**: Building footprint border
- **Status text**: "Left-click to place [building] | Right-click to cancel"

## Integration with Gameplay

The module is instantiated in `Gameplay.load()`:
```lua
buildingPlacement = M.BuildingPlacement.new()
```

Command buttons call `buildingPlacement:start(peon, type)` to begin placement.

The draw loop calls `update()` and `draw()` to show the preview.

Input handlers check `isActive()` and forward events to the module.

On successful placement, gameplay.lua gets the building cost via `getBuildingCost()` and tells the peon to walk to the site and build.
