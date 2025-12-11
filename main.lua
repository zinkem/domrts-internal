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
    knight.lua      - Mounted cavalry unit, faster movement, higher damage
    archer.lua      - Ranged unit, attacks from distance
    ballista.lua    - Siege unit, high damage vs buildings
    kamikaze.lua    - Explosive unit, suicide attack
    flyingscout.lua - Aerial scout unit, ignores terrain

BUILDINGS:
    townhall.lua    - Main base (4x4), produces peons, resource drop-off point
                      Upgrades: Town Hall -> Hold -> Keep
    barracks.lua    - Military building (3x3), produces footmen
                      Requires: Town Hall
    blacksmith.lua  - Upgrade building (2x2), weapon/armor research
                      Requires: Town Hall
    farm.lua        - Supply building (2x2), +4 unit capacity each
                      Requires: Town Hall
    lumbermill.lua  - Utility building (3x3), enables tower upgrades
                      Requires: Town Hall
    scouttower.lua  - Defensive tower (2x2), extended sight radius (9 tiles)
                      Upgrades: Scout Tower -> Guard Tower (ranged) -> Cannon Tower (siege)
                      Requires: Lumber Mill for upgrades
    stable.lua      - Cavalry building (3x3), enables Knight production at Barracks
                      Has Paladin upgrade (requires Siege Workshop)
                      Requires: Hold (Town Hall tier 2)
    siegeworkshop.lua - Siege building (3x3), produces Flying Scout, Ballista, Kamikaze
                      Requires: Keep (Town Hall tier 3)
    goldmine.lua    - Resource node (3x3), finite gold reserves, depletion

UI COMPONENTS:
    button.lua      - Reusable button with hover/press states
    radio_group.lua - Radio button group for settings toggles
    confirm_modal.lua - Modal dialog for confirmations
    requirements.lua - Building/upgrade requirement checks

================================================================================
BUILDING TECH TREE:
================================================================================

TIER 1 - TOWN HALL (Base):
    ├── Farm (2x2)              - 250g, 50L  - +4 population capacity
    ├── Barracks (3x3)          - 700g, 450L - Trains Footmen
    ├── Blacksmith (2x2)        - 800g, 400L - Weapon/Armor upgrades
    └── Lumber Mill (3x3)       - 250g, 0L   - Enables tower upgrades
        └── Scout Tower (2x2)   - 200g, 100L - Vision tower (9 tile sight)
            ├── Guard Tower     - 200g, 100L - Ranged attack (12 dmg)
            └── Cannon Tower    - 400g, 200L - Siege attack (35 dmg)

TIER 2 - HOLD (Town Hall upgrade: 1200g, 500L):
    └── Stable (3x3)            - 500g, 200L - Enables Knights at Barracks
        └── Paladin Upgrade     - 100g       - Upgrades existing Knights

TIER 3 - KEEP (Town Hall upgrade: 2000g, 1000L):
    └── Siege Workshop (3x3)    - 800g, 400L - Siege unit production
        ├── Flying Scout        - 200g, 100L - Aerial scout
        ├── Ballista            - 500g, 200L - Anti-building siege
        └── Kamikaze            - 300g, 100L - Explosive unit

================================================================================
BUILDING DETAILS:
================================================================================

TOWN HALL (townhall.lua)
    Size: 4x4 tiles (128x128 pixels)
    HP: 150
    Sight: 8 tiles
    Tiers: Town Hall (1) -> Hold (2) -> Keep (3)
    Production: Peons (400g, 10s)
    Queue: 5 units max
    Special: Resource drop-off point for gold/lumber
    Isometric: True 2:1 projection with palette shader

BARRACKS (barracks.lua)
    Size: 3x3 tiles (96x96 pixels)
    HP: 80
    Sight: 6 tiles
    Cost: 700 gold, 450 lumber
    Build Time: 45 seconds
    Production: Footman (135g, 6s), Knight (if Stable built)
    Queue: 5 units max
    Isometric: True 2:1 projection, 2x scale

BLACKSMITH (blacksmith.lua)
    Size: 2x2 tiles (64x64 pixels)
    HP: 60
    Sight: 5 tiles
    Cost: 800 gold, 400 lumber
    Build Time: 40 seconds
    Upgrades:
        - Weapon Upgrade (400g per level, max 3)
        - Armor Upgrade (500g per level, max 3)
    Upgrade Time: 30 seconds each
    Special: Smoking chimney, animated forge fire
    Isometric: True 2:1 projection, 2x scale

SCOUT TOWER (scouttower.lua)
    Size: 2x2 tiles (64x64 pixels, graphic extends upward)
    HP: 100 (Scout) / 130 (Guard) / 160 (Cannon)
    Sight: 9 tiles (extended vision)
    Cost: 200 gold, 100 lumber
    Build Time: 12 seconds
    Upgrades (requires Lumber Mill):
        - Guard Tower (200g, 100L, 15s) - Ranged attack, 12 dmg, 7 range
        - Cannon Tower (400g, 200L, 20s) - Siege attack, 35 dmg, 8 range
    Attack Speed: Guard 1.5/s, Cannon 0.5/s
    Special: Beacon fire on top, battlements
    Isometric: True 2:1 projection, 2x scale

FARM (farm.lua)
    Size: 2x2 tiles (64x64 pixels)
    HP: 50
    Sight: 5 tiles
    Cost: 250 gold, 50 lumber
    Build Time: 10 seconds
    Capacity Bonus: +4 units per farm
    Visual: Thatched farmhouse with wheat fields

LUMBER MILL (lumbermill.lua)
    Size: 3x3 tiles (96x96 pixels)
    HP: 50
    Sight: 5 tiles
    Cost: 250 gold, 0 lumber
    Build Time: 12 seconds
    Special: Enables Scout Tower upgrades
    Visual: Sawmill with saw blade, log piles

STABLE (stable.lua)
    Size: 3x3 tiles (96x96 pixels)
    HP: 60
    Sight: 5 tiles
    Cost: 500 gold, 200 lumber
    Build Time: 20 seconds
    Requires: Hold (Town Hall tier 2)
    Enables: Knight production at Barracks
    Upgrades:
        - Paladin Upgrade (100g, 15s) - Converts all Knights
    Visual: Barn-style building with horse silhouette

SIEGE WORKSHOP (siegeworkshop.lua)
    Size: 3x3 tiles (96x96 pixels)
    HP: 90
    Sight: 6 tiles
    Cost: 800 gold, 400 lumber
    Build Time: 25 seconds
    Requires: Keep (Town Hall tier 3)
    Production:
        - Flying Scout (200g, 100L, 12s)
        - Ballista (500g, 200L, 18s)
        - Kamikaze (300g, 100L, 8s)
    Visual: Industrial building with smokestacks, gears

================================================================================
ISOMETRIC RENDERING SYSTEM:
================================================================================

All buildings use a consistent isometric rendering approach:

PROJECTION:
    isoProject(x, y, z, originX, originY)
    - True 2:1 isometric ratio (slope of 0.5, ~26.57 degrees)
    - screenX = originX + (x - y) * 0.5
    - screenY = originY + (x + y) * 0.25 - z * 0.5

PRIMITIVES:
    isoQuad(p1, p2, p3, p4, originX, originY, color)
    - 4 corners in 3D space, projected to 2D polygon

    isoBox(x, y, z, w, d, h, originX, originY, topColor, leftColor, rightColor)
    - Rectangular prism with top, left, and right visible faces

SCALE:
    Buildings use 2x scale factor for larger, more detailed sprites
    Origin is at bottom edge of sprite (buildings grow upward)

EFFECTS:
    - gradientRect() for vertical color gradients
    - weatheredRect() for aged stone/wood textures
    - drawTorchFlame() / drawBeaconFire() for animated flames
    - drawSmokeParticles() for chimney smoke
    - PaletteShader for retro pixel art quantization

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
GLOBAL STATE (Game table):
================================================================================

    Game.settings.musicEnabled  - Audio toggle
    Game.settings.soundEnabled  - Audio toggle
    Game.settings.gameSpeed     - Game speed multiplier (0.5=slow, 1.0=normal, 2.0=fast)
    Game.settings.paletteShader - Retro pixel art shader for buildings
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
    → blacksmith.lua (COST_GOLD, COST_LUMBER, BUILD_TIME, UPGRADE_COST)
    → scouttower.lua (COST_GOLD, COST_LUMBER, BUILD_TIME, upgrade costs)

To change unit/building visuals:
    → Each file has a :draw() method with Love2D graphics calls
    → Isometric buildings have drawXxxIso() methods

To modify terrain generation:
    → map.lua: generateTerrain(), noise2D(), treeThreshold

To add new unit types:
    → Create new file following footman.lua pattern
    → Add to gameplay.lua: require, table, update loop, selection, commands

To add new building types:
    → Create new file following farm.lua/barracks.lua pattern
    → Add to gameplay.lua: require, table, update loop, placement validation
    → Add button to peon.lua updateUI if peon-built
    → Add to requirements.lua if has prerequisites

To modify pathfinding behavior:
    → flowfield.lua: generate(), DIRECTIONS, diagonal costs

To modify UI panels:
    → gameplay.lua: drawTopBar(), drawSelectionPanel(), drawMinimap area
    → Individual entity:drawUI() methods for action buttons

To add new game mechanics:
    → gameplay.lua: update(), handleRightClick(), mousepressed()

================================================================================
CODING CONVENTIONS & GOTCHAS:
================================================================================

LUA UPVALUE LIMIT:
    Lua has a hard limit of 60 upvalues per function. An upvalue is any local
    variable from an enclosing scope that a function references.

    gameplay.lua is at ~52 upvalues. To avoid hitting the limit:

    1. NEW FEATURES GO IN SEPARATE MODULES
       - Create new_feature.lua with its own state
       - gameplay.lua just requires and calls it
       - Example: surrender.lua handles surrender dialog + credits screen

    2. If you must add to gameplay.lua:
       - Modules are consolidated in the M table (M.Farm, M.Peon, etc.)
       - Add new requires to M, not as separate locals
       - Group related state into tables, not individual locals

MODULE PATTERN:
    -- Good: state on self, passed to functions
    function Module.new()
        return { items = {}, count = 0 }
    end
    function Module.update(self, dt)
        for _, item in ipairs(self.items) do ... end
    end

    -- Avoid: module-level locals (become upvalues)
    local items = {}
    local count = 0
    function Module.update(dt)
        for _, item in ipairs(items) do ... end  -- upvalue!
    end

SCENE STRUCTURE:
    Every scene module should export:
        .load(options)      - Initialize state
        .update(dt)         - Game logic
        .draw()             - Rendering
        .keypressed(key)    - Optional
        .mousepressed(x,y,b) - Optional
        .mousereleased(x,y,b) - Optional
        .wheelmoved(x,y)    - Optional

OPTIONAL MODULES:
    Use pcall for modules that may not exist:
        pcall(function() M.LumberMill = require("lumbermill") end)

    Check before use:
        if M.LumberMill then M.LumberMill.update(dt) end

================================================================================
]]

--[[
    Main Entry Point
    Handles scene management and global state
]]

-- Replay logging system
local ReplayLogger
pcall(function() ReplayLogger = require("replay_logger") end)

-- Global game state
Game = {
    settings = {
        musicEnabled = true,
        soundEnabled = true,
        gameSpeed = 1.0,  -- 0.5 = slow, 1.0 = normal, 2.0 = fast
        paletteShader = true  -- Enable retro pixel art shader for buildings
    },
    currentScene = nil,
    scenes = {},
    Replay = ReplayLogger  -- Accessible globally as Game.Replay
}

-- Scene manager
local SceneManager = {}

function SceneManager.switch(sceneName, options)
    if Game.scenes[sceneName] then
        Game.currentScene = Game.scenes[sceneName]
        if Game.currentScene.load then
            Game.currentScene.load(options)
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
function love.load(arg)
    -- Check for benchmark mode
    for _, a in ipairs(arg or {}) do
        if a == "--benchmark" then
            local Benchmark = require("benchmarks.benchmark_getAllUnits")
            Benchmark.run()
            return
        elseif a == "--benchmark-quadtree" then
            local Benchmark = require("benchmarks.benchmark_quadtree")
            Benchmark.run()
            return
        elseif a == "--benchmark-combat" then
            local Benchmark = require("benchmarks.benchmark_combat")
            Benchmark.run()
            return
        end
    end

    love.window.setTitle("Love2D Game")
    love.window.setMode(1280, 720, {
        resizable = false,
        vsync = true
    })
    
    -- Helper to load custom fonts with fallback
    local function loadFont(path, size)
        local success, font = pcall(function()
            return love.graphics.newFont(path, size)
        end)
        if success then
            return font
        else
            print("Could not load font: " .. path .. ", using default")
            return love.graphics.newFont(size)
        end
    end
    
    Game.fonts = {
        -- Basic sizes (fallback)
        small = love.graphics.newFont(14),
        medium = love.graphics.newFont(18),
        
        -- Headers and emphasis
        large = loadFont("fonts/empire-crown/empirecrown.ttf", 28),
        title = loadFont("fonts/morris-roman-black/MorrisRoman-Black.ttf", 72),
        subtitle = loadFont("fonts/empire-crown/empirecrown.ttf", 24),
        button = loadFont("fonts/empire-crown/empirecrown.ttf", 20),
        
        -- Stats screen - using default for reliability
        stats = love.graphics.newFont(18),
        statsLarge = love.graphics.newFont(28),
        header = loadFont("fonts/knights-templar/Knight2.ttf", 24),
    }
    
    -- Load and register scenes
    Game.SceneManager.register("title", require("title"))
    Game.SceneManager.register("gameplay", require("gameplay"))
    Game.SceneManager.register("victory", require("victory"))
    
    -- Optional scenes (may not exist)
    pcall(function() Game.SceneManager.register("gameconfig", require("gameconfig")) end)
    pcall(function() Game.SceneManager.register("tutorial", require("tutorial")) end)
    pcall(function() Game.SceneManager.register("devpreview", require("devpreview")) end)
    pcall(function() Game.SceneManager.register("replaybrowser", require("replaybrowser")) end)
    
    -- Aliases for convenience
    Game.scenes["titlescreen"] = Game.scenes["title"]
    
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

function love.wheelmoved(x, y)
    if Game.currentScene and Game.currentScene.wheelmoved then
        Game.currentScene.wheelmoved(x, y)
    end
end
