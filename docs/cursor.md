# Custom Cursor System

The cursor module provides a medieval-themed custom cursor that replaces the system cursor across all game screens.

## Overview

The game uses a golden/bronze pointer cursor styled to match the medieval fantasy theme. The system cursor is hidden and our custom cursor is drawn on top of everything else.

## Visual Style

The cursor is a stylized arrow pointer with:
- Shadow for depth
- Golden/bronze main body
- Inner highlight for metallic sheen
- Dark outline
- Decorative dot at the tip

## Usage

### Requiring the Module
```lua
local Cursor = require("cursor")
```

### In Scene Load
Hide the system cursor when entering any scene that uses the custom cursor:
```lua
function MyScene.load()
    love.mouse.setVisible(false)
    -- ... rest of load
end
```

### In Scene Draw
Draw the cursor at the end of the draw function (so it appears on top):
```lua
function MyScene.draw()
    -- ... draw everything else ...

    -- Custom cursor (always on top)
    Cursor.draw()
end
```

## Module API

### Cursor.draw()
Draws the cursor at the current mouse position. Call this at the end of your draw function.

### Cursor.drawNormal(mx, my)
Draws the normal pointer cursor at a specific position. Used internally by `draw()`, but can be called directly if needed.

## Screens Using the Cursor

- **title.lua** - Title/main menu screen
- **gameconfig.lua** - New game configuration screen
- **replaybrowser.lua** - Replay browser screen
- **gameplay.lua** - Main gameplay (has additional cursor states)

## Gameplay-Specific Cursors

The gameplay screen has additional cursor states beyond the normal pointer:
- **grabbing** - Closed fist when dragging the map
- **charging** - Hand opening with charge ring when holding right-click
- **attack** - Red crosshair with sword when in attack-move mode

These specialized cursors are currently implemented directly in gameplay.lua rather than in the shared cursor module, since they require gameplay-specific state.

## Future Improvements

Potential enhancements:
- Move all cursor states to the shared module
- Add hover states for interactive elements
- Support cursor themes/skins
