--[[
================================================================================
PROJECT: Love2D RTS Game
FRAMEWORK: LÖVE 11.4 (Love2D)
LANGUAGE: Lua
RESOLUTION: 1280x720 (fixed)
================================================================================

OVERVIEW:
    A real-time strategy game featuring resource gathering, base building, and
    unit production. Players command peons (workers) to harvest gold from mines
    and lumber from trees, construct buildings, and train military units.

================================================================================
FILE STRUCTURE & RESPONSIBILITIES:
================================================================================

ENTRY & SCENE MANAGEMENT:
    main.lua        - Entry point, scene manager, global Game table, Love2D callbacks
    conf.lua        - LÖVE2D window/engine configuration
    title.lua       - Title screen with animated background, settings toggles
    victory.lua     - Victory screen with time display
    gameplay.lua    - Main game scene: update loop, rendering, input handling,
                      unit/building management, resource tracking, UI panels

MAP & PATHFINDING:
    map.lua         - 64x64 tile grid, terrain generation (grass/trees via noise),
                      camera scrolling, coordinate conversion (grid/world/screen),
                      minimap rendering, tile passability checks
    flowfield.lua   - BFS-based flow field pathfinding for navigation around
                      obstacles, direction field caching, building avoidance

UNITS:
    peon.lua        - Worker unit: states (Idle/Moving/Harvesting/Returning/
                      Chopping/Building), gold/lumber carrying, mine harvesting,
                      tree chopping, building construction, flow field movement
    footman.lua     - Military unit: states (Idle/Moving), combat-ready,
                      flow field movement, building collision

BUILDINGS:
    townhall.lua    - Main base (3x3), produces peons, resource drop-off point
    barracks.lua    - Military building (3x3), produces footmen, build time
    farm.lua        - Supply building (2x2), +4 unit capacity each, build time
    goldmine.lua    - Resource node (3x3), finite gold reserves, depletion

UI COMPONENTS:
    button.lua      - Reusable button with hover/press states
    radio_group.lua - Radio button group for settings toggles
    confirm_modal.lua - Modal dialog for confirmations

================================================================================
KEY SYSTEMS & DATA FLOW:
================================================================================

COORDINATE SYSTEMS:
    Grid:   1-indexed tile positions (1,1 to 64,64)
    World:  Pixel coordinates (0,0 to 2048,2048) - grid * 32
    Screen: Viewport-relative pixels after camera offset

RESOURCE SYSTEM (gameplay.lua):
    resources = {gold=, lumber=}
    Peons harvest -> carry -> return to townhall -> deposit
    Buildings cost gold + lumber to construct

UNIT CAPACITY (gameplay.lua):
    BASE_CAPACITY = 4, each Farm adds +4
    currentPop tracks peons + footmen count
    Production blocked when currentPop >= maxPop

PATHFINDING (flowfield.lua):
    FlowField.getField(destX, destY, map, buildings) - cached field lookup
    FlowField.invalidateAll() - clear cache on map changes
    Units store flowField reference, query getDirection() each frame

BUILDING PLACEMENT (gameplay.lua):
    isPlacingBuilding flag, validates terrain + building overlap
    Peon walks to site -> STATE_BUILDING -> building updates -> finishBuilding()

SELECTION SYSTEM (gameplay.lua):
    selectedEntities[] array, box selection, click selection
    Entity.selected flag for rendering highlight
    Right-click context: move/harvest/attack based on target

================================================================================
KNOWN ISSUES & FIXES:
================================================================================

BUG FIX: Peons not entering gold mines
    PROBLEM: Multiple issues prevented peons from entering mines:
    
    1) In gameplay.lua line ~941, peon:update() was called with
       goldMines[1] hardcoded, so peons would only properly check
       against the first mine regardless of their actual target.
    
    2) In peon.lua canMoveTo(), collision detection blocked peons
       from approaching ANY building including their target mine.
    
    3) In gameplay.lua pushUnitOutOfBuildings(), all units were
       pushed away from all buildings every frame, including peons
       trying to enter their target mine.
    
    4) In peon.lua computePath(), pathfinding treated the target mine
       as an obstacle, routing peons AROUND the mine instead of TO it.
    
    5) In peon.lua updateWaypoint(), line-of-sight checks treated
       the target mine as blocking, preventing waypoint progression.
    
    FIX: 
    - peon.lua updateMoving(): Use self.targetMine instead of the
      goldMine parameter for the isTouchingBuilding check (line ~307)
    
    - peon.lua canMoveTo(): Skip collision check when building is
      self.targetMine so peon can walk into the mine (line ~144)
    
    - gameplay.lua pushUnitOutOfBuildings(): Skip pushing when unit
      has targetMine and building is that target mine (line ~625)
    
    - peon.lua computePath(): Filter out self.targetMine from the
      buildings list before passing to Pathfinding.findPath (line ~173)
    
    - peon.lua updateWaypoint(): Filter out self.targetMine from
      buildings when checking line-of-sight to next waypoint (line ~188)
    
    FILES AFFECTED: peon.lua, gameplay.lua

================================================================================
COMMON MODIFICATIONS & RELEVANT FILES:
================================================================================

To modify unit stats (speed, harvest rate, costs):
    → peon.lua (speed, harvestAmount, harvestTime, choppingTime)
    → footman.lua (speed)
    → townhall.lua (productionCost, productionTime)
    → barracks.lua (FOOTMAN_COST, FOOTMAN_TIME)

To modify building stats (costs, build time, size):
    → farm.lua (COST_GOLD, COST_LUMBER, BUILD_TIME, CAPACITY_BONUS)
    → barracks.lua (COST_GOLD, COST_LUMBER, BUILD_TIME)

To change unit/building visuals:
    → Each file has a :draw() method with Love2D graphics calls

To modify terrain generation:
    → map.lua: generateTerrain(), noise2D(), treeThreshold

To add new unit types:
    → Create new file following footman.lua pattern
    → Add to gameplay.lua: require, table, update loop, selection, commands

To add new building types:
    → Create new file following farm.lua/barracks.lua pattern
    → Add to gameplay.lua: require, table, update loop, placement validation
    → Add button to peon.lua updateUI if peon-built

To modify pathfinding behavior:
    → flowfield.lua: generate(), DIRECTIONS, diagonal costs

To modify UI panels:
    → gameplay.lua: drawTopBar(), drawSelectionPanel(), drawMinimap area
    → Individual entity:drawUI() methods for action buttons

To add new game mechanics:
    → gameplay.lua: update(), handleRightClick(), mousepressed()

================================================================================
GLOBAL STATE (Game table):
================================================================================

    Game.settings.musicEnabled  - Audio toggle
    Game.settings.soundEnabled  - Audio toggle
    Game.settings.gameSpeed     - Game speed multiplier (0.5=slow, 1.0=normal, 2.0=fast)
    Game.currentScene           - Active scene module
    Game.scenes                 - Registered scene table
    Game.SceneManager           - Scene switching interface
    Game.fonts                  - Preloaded fonts (small/medium/large/title)
    Game.finalTime              - Victory screen time display

CONTROLS:
    1 - Slow speed (0.5x)
    2 - Normal speed (1x)
    3 - Fast speed (2x)

================================================================================
]]

--[[
    Main Entry Point
    Handles scene management and global state
]]

-- Global game state
Game = {
    settings = {
        musicEnabled = true,
        soundEnabled = true,
        gameSpeed = 1.0  -- 0.5 = slow, 1.0 = normal, 2.0 = fast
    },
    currentScene = nil,
    scenes = {}
}

-- Scene manager
local SceneManager = {}

function SceneManager.switch(sceneName, options)
    if Game.scenes[sceneName] then
        -- Unload current scene if it has an unload function
        if Game.currentScene and Game.currentScene.unload then
            Game.currentScene.unload()
        end
        Game.currentScene = Game.scenes[sceneName]
        if Game.currentScene.load then
            Game.currentScene.load(options)  -- Pass options to scene
        end
    else
        error("Scene not found: " .. sceneName)
    end
end

function SceneManager.register(name, scene)
    Game.scenes[name] = scene
end

-- Make scene manager globally accessible
Game.SceneManager = SceneManager

-- Love2D callbacks
function love.load()
    love.window.setTitle("Dominion")
    love.window.setMode(1280, 720, {
        resizable = false,
        vsync = true
    })
    
    -- Load fonts with fallbacks
    local defaultFont = love.graphics.newFont(14)
    local function loadFont(path, size)
        local success, font = pcall(love.graphics.newFont, path, size)
        if success and font then
            return font
        else
            return love.graphics.newFont(size)
        end
    end
    
    --[[
    FONT CHOICES & OPINIONS TRACKER
    ================================
    Available fonts:
      - fonts/perigord/pe______.ttf           (medieval serif)
      - fonts/empire-crown/empirecrown.ttf    (decorative medieval)
      - fonts/empire-crown/empirecrownexpand.ttf (wider decorative)
      - fonts/morris-roman-black/MorrisRoman-Black.ttf (bold blackletter)
      - fonts/ballade/BalladeSh.ttf           (elegant script-like)
      - fonts/ballade/BalladeHf.ttf           (half version)
      - fonts/ballade/BalladeContour.ttf      (outline version)
      - fonts/knights-templar/Knight2.ttf     (templar style)
    
    OPINIONS:
      - perigord: ❌ TOO HARD TO READ for body text/tutorial messages
      - ballade: Works, but not appropriate for body text
      - morris-roman-black: ✓ GOOD for title screen title
      - empirecrown: ✓ GOOD for buttons/headers (part of current best setup)
      - knights-templar: (pending feedback)
      - default system font: ✓ GOOD for body text/stats - readable
    
    CURRENT STATUS: User likes current setup, keeping it for now.
    ]]
    
    Game.fonts = {
        -- Body text - using default font for maximum readability
        small = love.graphics.newFont(14),
        medium = love.graphics.newFont(18),
        
        -- Headers and emphasis
        large = loadFont("fonts/empire-crown/empirecrown.ttf", 28),
        title = loadFont("fonts/morris-roman-black/MorrisRoman-Black.ttf", 72),
        button = loadFont("fonts/empire-crown/empirecrown.ttf", 20),
        
        -- Stats screen - using default for reliability
        stats = love.graphics.newFont(18),
        statsLarge = love.graphics.newFont(28),
        header = loadFont("fonts/knights-templar/Knight2.ttf", 24),
        
        -- Subtitles
        subtitle = loadFont("fonts/empire-crown/empirecrownexpand.ttf", 16),
    }
    
    -- Initialize audio system
    local Audio
    pcall(function() Audio = require("audio") end)
    if Audio and Audio.init then
        Audio.init()
    end
    
    -- Load and register scenes
    Game.SceneManager.register("title", require("title"))
    Game.SceneManager.register("gameplay", require("gameplay"))
    Game.SceneManager.register("victory", require("victory"))
    Game.SceneManager.register("tutorial", require("tutorial"))
    Game.SceneManager.register("gameconfig", require("gameconfig"))
    
    -- Start with title screen
    Game.SceneManager.switch("title")
end

function love.update(dt)
    if Game.currentScene and Game.currentScene.update then
        Game.currentScene.update(dt)
    end
end

function love.draw()
    if Game.currentScene and Game.currentScene.draw then
        Game.currentScene.draw()
    end
end

function love.keypressed(key)
    if Game.currentScene and Game.currentScene.keypressed then
        Game.currentScene.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if Game.currentScene and Game.currentScene.mousepressed then
        Game.currentScene.mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if Game.currentScene and Game.currentScene.mousereleased then
        Game.currentScene.mousereleased(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if Game.currentScene and Game.currentScene.mousemoved then
        Game.currentScene.mousemoved(x, y, dx, dy)
    end
end
