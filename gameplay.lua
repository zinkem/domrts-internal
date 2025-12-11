--[[
    Gameplay Scene
    RTS Resource Gathering with scrolling map
    Includes full tech tree with all buildings and units

    ENHANCED: Now includes particle effects and visual enhancements
]]

-- All modules consolidated into one table to avoid upvalue limit
local M = {
    Map = require("map"),
    TownHall = require("townhall"),
    GoldMine = require("goldmine"),
    Peon = require("peon"),
    Farm = require("farm"),
    Barracks = require("barracks"),
    Footman = require("footman"),
    Pathfinding = require("pathfinding"),
    Requirements = require("requirements"),
    ScoutTower = require("scouttower"),
    UIDraw = require("ui_draw"),
    CommandBar = require("command_bar"),
    Surrender = require("surrender"),
    BuildingPlacement = require("building_placement"),
    Quadtree = require("quadtree"),
}

-- Optional modules (graceful fallback)
pcall(function() M.LumberMill = require("lumbermill") end)
pcall(function() M.Blacksmith = require("blacksmith") end)
pcall(function() M.ArcheryRange = require("archeryrange") end)
pcall(function() M.Stable = require("stable") end)
pcall(function() M.SiegeWorkshop = require("siegeworkshop") end)
pcall(function() M.Archer = require("archer") end)
pcall(function() M.Knight = require("knight") end)
pcall(function() M.FlyingScout = require("flyingscout") end)
pcall(function() M.Ballista = require("ballista") end)
pcall(function() M.Kamikaze = require("kamikaze") end)
pcall(function() M.Teams = require("teams") end)
pcall(function() M.Player = require("player") end)
pcall(function() M.AI = require("ai") end)
pcall(function() M.Effects = require("effects") end)
pcall(function() M.DrawUtils = require("draw_utils") end)
pcall(function() M.Audio = require("audio") end)
pcall(function() M.MusicPlayer = require("music_player") end)

local Gameplay = {}

-- Persistent quadtree for spatial queries (refreshed once per frame)
local unitQuadtree = nil
local WORLD_SIZE = 64 * 32  -- 64 tiles * 32 pixels

-- Game state
local elapsedTime = 0
local victory = false
local defeat = false
local endScreenButton = nil

-- Game stats for victory screen
local gameStats = {
    -- Combat stats
    unitsKilled = 0,
    unitsLost = 0,
    buildingsDestroyed = 0,
    buildingsLost = 0,

    -- Economy stats
    goldCollected = 0,
    lumberCollected = 0,

    -- Production stats
    peonsProduced = 0,
    footmenProduced = 0,

    -- Building timeline (time when each building was completed)
    buildingTimeline = {},  -- {time = seconds, type = "barracks", team = 1}

    -- AI stats (for comparison)
    aiUnitsKilled = 0,
    aiUnitsLost = 0,
    aiBuildingsDestroyed = 0,
    aiBuildingsLost = 0,
    aiGoldCollected = 0,
    aiLumberCollected = 0,
    aiPeonsProduced = 0,
    aiFootmenProduced = 0,
}

local resources = {
    gold = 1000,
    lumber = 400
}

-- Debug mode state
local debugMode = false
local debugCheckboxRect = {x = 0, y = 0, w = 0, h = 0}  -- Set in draw

-- Unit capacity
local BASE_CAPACITY = 4
local currentPop = 0
local maxPop = BASE_CAPACITY

local map = nil
local townHall = nil
local goldMines = {}
local peons = {}
local farms = {}
local barracks = {}
local footmen = {}

-- New building tables
local lumberMills = {}
local blacksmiths = {}
local scoutTowers = {}
local archeryRanges = {}
local stables = {}
local siegeWorkshops = {}
local townHalls = {}  -- Additional town halls (built by peons)

-- New unit tables
local archers = {}
local knights = {}
local flyingScouts = {}
local ballistas = {}
local kamikazes = {}

-- AI controller
local enemyAI = nil
local enemyTownHall = nil

local selectedEntities = {}  -- Support multiple selection

-- Building placement (module instance created in load())
local buildingPlacement = nil

-- Box selection
local isBoxSelecting = false
local boxStartX, boxStartY = 0, 0
local boxEndX, boxEndY = 0, 0

-- Map dragging and cursor state (consolidated to reduce upvalues)
local input = {
    isMapDragging = false,
    mouseDownTime = 0,
    mouseDownX = 0,
    mouseDownY = 0,
    dragHoldTime = 0.25,
    dragMoveThreshold = 5,
    cursorState = "normal",
    cursorChargeProgress = 0,
    attackMoveMode = false  -- 'a' key attack-move mode
}

-- UI Layout - Stone/Metal Medieval Theme
local UI = {
    -- Stone colors
    stoneLight = {0.45, 0.42, 0.38, 1},
    stoneMid = {0.35, 0.32, 0.28, 1},
    stoneDark = {0.25, 0.22, 0.18, 1},
    stoneAccent = {0.55, 0.52, 0.45, 1},
    stoneHighlight = {0.6, 0.58, 0.52, 1},

    -- Metal colors
    metalGold = {0.85, 0.7, 0.35, 1},
    metalBronze = {0.7, 0.5, 0.3, 1},
    metalIron = {0.5, 0.52, 0.55, 1},
    metalShine = {0.95, 0.9, 0.75, 1},

    -- Text colors
    textLight = {0.95, 0.92, 0.85, 1},
    textDark = {0.2, 0.18, 0.15, 1},
    textGold = {1, 0.85, 0.3, 1},
    textLumber = {0.6, 0.45, 0.25, 1},
    textPop = {0.7, 0.85, 0.7, 1},

    -- UI dimensions
    topBarHeight = 42,
    minimapSize = 160,
    bottomPanelHeight = 70,  -- Horizontal command bar
    bottomPanelWidth = 280,
}

-- Notification system
local notifications = {}
local NOTIFICATION_DURATION = 4.0
local NOTIFICATION_SLIDE_TIME = 0.3
local NOTIFICATION_HEIGHT = 36
local NOTIFICATION_SPACING = 4
local MAX_NOTIFICATIONS = 6

local function addNotification(message)
    -- Create new notification with slide animation
    local notif = {
        text = message,
        timer = NOTIFICATION_DURATION,
        slideProgress = 0,  -- 0 = off screen, 1 = fully visible
        targetSlot = 1
    }

    -- Shift existing notifications up
    for _, existing in ipairs(notifications) do
        existing.targetSlot = existing.targetSlot + 1
    end

    -- Insert at front
    table.insert(notifications, 1, notif)

    -- Remove oldest if too many
    while #notifications > MAX_NOTIFICATIONS do
        table.remove(notifications)
    end
end

local function checkAllMinesDepleted()
    for _, mine in ipairs(goldMines) do
        if not mine.depleted then return false end
    end
    return true
end

local function countPlayerUnits(unitList)
    local playerTeam = M.Teams and M.Teams.PLAYER or 1
    local count = 0
    for _, unit in ipairs(unitList) do
        if unit.team == nil or unit.team == playerTeam then
            count = count + 1
        end
    end
    return count
end

-- Check if entity belongs to human player (for command filtering)
local function isPlayerOwned(entity)
    if not entity then return false end
    local playerTeam = M.Teams and M.Teams.PLAYER or 1
    return entity.team == nil or entity.team == playerTeam
end

-- Find the closest non-depleted gold mine to a world position
local function findClosestMine(worldX, worldY)
    local closestMine = nil
    local closestDist = math.huge

    for _, mine in ipairs(goldMines) do
        if not mine.depleted then
            local mx, my = mine:getWorldCenter()
            local dx = mx - worldX
            local dy = my - worldY
            local dist = dx * dx + dy * dy
            if dist < closestDist then
                closestDist = dist
                closestMine = mine
            end
        end
    end

    return closestMine
end

local function calculatePopulation()
    -- Only count player-owned units
    currentPop = countPlayerUnits(peons) + countPlayerUnits(footmen) + countPlayerUnits(archers) +
                 countPlayerUnits(knights) + countPlayerUnits(flyingScouts) +
                 countPlayerUnits(ballistas) + countPlayerUnits(kamikazes)

    -- Only count player-owned farms
    local playerTeam = M.Teams and M.Teams.PLAYER or 1
    maxPop = BASE_CAPACITY
    for _, farm in ipairs(farms) do
        if farm.completed and (farm.team == nil or farm.team == playerTeam) then
            maxPop = maxPop + M.Farm.CAPACITY_BONUS
        end
    end
end

local function getAllBuildings()
    local buildings = {townHall}
    for _, m in ipairs(goldMines) do table.insert(buildings, m) end
    for _, f in ipairs(farms) do table.insert(buildings, f) end
    for _, b in ipairs(barracks) do table.insert(buildings, b) end
    for _, b in ipairs(lumberMills) do table.insert(buildings, b) end
    for _, b in ipairs(blacksmiths) do table.insert(buildings, b) end
    for _, b in ipairs(scoutTowers) do table.insert(buildings, b) end
    for _, b in ipairs(archeryRanges) do table.insert(buildings, b) end
    for _, b in ipairs(stables) do table.insert(buildings, b) end
    for _, b in ipairs(siegeWorkshops) do table.insert(buildings, b) end
    for _, b in ipairs(townHalls) do table.insert(buildings, b) end
    return buildings
end

local function getAllUnits()
    local units = {}
    for _, p in ipairs(peons) do if p.visible then table.insert(units, p) end end
    for _, f in ipairs(footmen) do table.insert(units, f) end
    for _, a in ipairs(archers) do table.insert(units, a) end
    for _, k in ipairs(knights) do table.insert(units, k) end
    for _, f in ipairs(flyingScouts) do table.insert(units, f) end
    for _, b in ipairs(ballistas) do table.insert(units, b) end
    for _, k in ipairs(kamikazes) do table.insert(units, k) end
    return units
end

-- Accessor functions for quadtree
local function getUnitX(unit) return unit.worldX end
local function getUnitY(unit) return unit.worldY end

-- Maximum separation query radius (largest possible unit radius * 2)
local MAX_SEPARATION_RADIUS = 32

-- Refresh the persistent quadtree with current unit positions (O(n) once per frame)
local function refreshUnitQuadtree(allUnits)
    if not unitQuadtree then
        unitQuadtree = M.Quadtree.new(0, 0, WORLD_SIZE, WORLD_SIZE)
    else
        unitQuadtree:clear()
    end
    for _, unit in ipairs(allUnits) do
        unitQuadtree:insert(unit, getUnitX, getUnitY)
    end
end

local function separateUnits()
    local allUnits = getAllUnits()
    local allBuildings = getAllBuildings()

    -- Helper to check if position collides with any building
    local function collidesWithBuilding(x, y, radius)
        for _, b in ipairs(allBuildings) do
            if b.getWorldBounds then
                local bx1, by1, bx2, by2 = b:getWorldBounds()
                local closestX = math.max(bx1, math.min(x, bx2))
                local closestY = math.max(by1, math.min(y, by2))
                local dx = x - closestX
                local dy = y - closestY
                if (dx * dx + dy * dy) < (radius * radius) then
                    return true
                end
            end
        end
        return false
    end

    -- Use persistent quadtree (already refreshed at start of frame)
    local qt = unitQuadtree

    -- Multiple passes for better separation
    for pass = 1, 3 do
        for _, a in ipairs(allUnits) do
            -- Skip if peon carrying gold or heading to mine
            local aCarryingGold = a.carryingGold and a.carryingGold > 0
            local aTargetingMine = a.targetMine ~= nil
            if aCarryingGold or aTargetingMine then
                goto continue_a
            end

            -- Query nearby units using quadtree
            local nearby = qt:query(a.worldX, a.worldY, MAX_SEPARATION_RADIUS, nil, getUnitX, getUnitY)

            for _, b in ipairs(nearby) do
                if a == b then goto continue_b end

                -- Skip if peon carrying gold or heading to mine
                local bCarryingGold = b.carryingGold and b.carryingGold > 0
                local bTargetingMine = b.targetMine ~= nil
                if bCarryingGold or bTargetingMine then
                    goto continue_b
                end

                local dx = b.worldX - a.worldX
                local dy = b.worldY - a.worldY
                local dist = math.sqrt(dx * dx + dy * dy)
                local minDist = a.radius + b.radius

                if dist < minDist and dist > 0.1 then
                    local overlap = (minDist - dist) / 2 + 0.5
                    local nx, ny = dx / dist, dy / dist

                    -- Calculate new positions
                    local ax, ay = a.worldX - nx * overlap, a.worldY - ny * overlap
                    local bx, by = b.worldX + nx * overlap, b.worldY + ny * overlap

                    -- Only apply if the new position is passable AND not in a building
                    if map:isWorldPosPassable(ax, ay) and not collidesWithBuilding(ax, ay, a.radius) then
                        a.worldX, a.worldY = ax, ay
                    end
                    if map:isWorldPosPassable(bx, by) and not collidesWithBuilding(bx, by, b.radius) then
                        b.worldX, b.worldY = bx, by
                    end
                elseif dist < 0.1 then
                    -- Exactly overlapping, push in random direction
                    local angle = math.random() * math.pi * 2
                    local push = minDist / 2 + 1
                    local ax = a.worldX + math.cos(angle) * push
                    local ay = a.worldY + math.sin(angle) * push
                    if map:isWorldPosPassable(ax, ay) and not collidesWithBuilding(ax, ay, a.radius) then
                        a.worldX, a.worldY = ax, ay
                    end
                end

                ::continue_b::
            end

            ::continue_a::
        end
    end
    return allUnits, allBuildings
end

-- Helper: Draw stone panel background (using UIDraw module)
local function drawStonePanel(x, y, w, h, cornerRadius)
    M.UIDraw.drawStonePanel(x, y, w, h, cornerRadius)
end

-- Helper: Draw resource group with icon (using UIDraw module)
local function drawResourceGroup(x, y, iconType, value, label)
    M.UIDraw.drawResourceGroup(x, y, iconType, value, label, Game.fonts)
end

local function drawTopBar(screenW)
    M.UIDraw.drawTopBar(screenW, resources, currentPop, maxPop, elapsedTime, townHall.tier, Game.settings.gameSpeed, Game.fonts)

    -- Debug mode checkbox (positioned left of the tier indicator)
    local checkboxSize = 16
    local checkboxX = screenW - UI.minimapSize - 120
    local checkboxY = 12
    debugCheckboxRect = {x = checkboxX, y = checkboxY, w = checkboxSize + 50, h = checkboxSize + 4}

    -- Checkbox background
    love.graphics.setColor(UI.stoneDark[1], UI.stoneDark[2], UI.stoneDark[3], 0.9)
    love.graphics.rectangle("fill", checkboxX - 2, checkboxY - 2, checkboxSize + 4, checkboxSize + 4, 2)

    -- Checkbox border
    love.graphics.setColor(UI.metalBronze[1], UI.metalBronze[2], UI.metalBronze[3], 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", checkboxX - 2, checkboxY - 2, checkboxSize + 4, checkboxSize + 4, 2)

    -- Checkmark if enabled
    if debugMode then
        love.graphics.setColor(0.4, 0.9, 0.4, 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(checkboxX + 2, checkboxY + 8, checkboxX + 6, checkboxY + 12)
        love.graphics.line(checkboxX + 6, checkboxY + 12, checkboxX + 14, checkboxY + 4)
    end

    -- Label
    love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], 0.9)
    if Game.fonts and Game.fonts.small then
        love.graphics.setFont(Game.fonts.small)
    end
    love.graphics.print("Debug", checkboxX + checkboxSize + 6, checkboxY)
end

local function drawMinimap(screenW)
    local mmX, mmY, mmSize = M.UIDraw.drawMinimapFrame(screenW)

    -- Draw actual minimap
    local mmScale = mmSize / map.width
    map:drawMinimap(mmX, mmY, mmSize)

    local playerTeam = M.Teams and M.Teams.PLAYER or 1

    -- Helper to check if entity should show on minimap
    local function isMinimapVisible(entity, requireVisible)
        if not map.fogEnabled then return true end
        if entity.team == playerTeam then return true end

        local wx, wy
        if entity.getWorldCenter then
            wx, wy = entity:getWorldCenter()
        else
            wx, wy = entity.worldX, entity.worldY
        end
        local gx, gy = map:worldToGrid(wx, wy)

        if requireVisible then
            return map:isTileVisible(gx, gy)
        else
            return map:isTileExplored(gx, gy)
        end
    end

    -- Draw all entities on minimap
    townHall:drawOnMinimap(mmX, mmY, mmScale)
    for _, m in ipairs(goldMines) do
        if isMinimapVisible(m, false) then m:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, f in ipairs(farms) do
        if isMinimapVisible(f, false) then f:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(barracks) do
        if isMinimapVisible(b, false) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(lumberMills) do
        if isMinimapVisible(b, false) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(blacksmiths) do
        if isMinimapVisible(b, false) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(scoutTowers) do
        if isMinimapVisible(b, false) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(archeryRanges) do
        if isMinimapVisible(b, false) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(stables) do
        if isMinimapVisible(b, false) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(siegeWorkshops) do
        if isMinimapVisible(b, false) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(townHalls) do
        if isMinimapVisible(b, false) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end

    -- Units require visibility (not just explored)
    for _, p in ipairs(peons) do
        if isMinimapVisible(p, true) then p:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, f in ipairs(footmen) do
        if isMinimapVisible(f, true) then f:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, a in ipairs(archers) do
        if isMinimapVisible(a, true) then a:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, k in ipairs(knights) do
        if isMinimapVisible(k, true) then k:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, f in ipairs(flyingScouts) do
        if isMinimapVisible(f, true) then f:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, b in ipairs(ballistas) do
        if isMinimapVisible(b, true) then b:drawOnMinimap(mmX, mmY, mmScale) end
    end
    for _, k in ipairs(kamikazes) do
        if isMinimapVisible(k, true) then k:drawOnMinimap(mmX, mmY, mmScale) end
    end
end

-- Command bar button definitions
local commandButtons = {}
local commandBarY = 0
local COMMAND_BUTTON_SIZE = 50
local COMMAND_BUTTON_SPACING = 4

-- Get command buttons for current selection
local function getCommandButtons()
    local buttons = {}
    local selEntity = selectedEntities[1]
    local playerTeam = M.Teams and M.Teams.PLAYER or 1

    if not selEntity or selEntity.team ~= playerTeam then
        return buttons
    end

    -- Common commands for mobile units
    if selEntity.moveTo then
        table.insert(buttons, {
            hotkey = "A",
            text = "Attack",
            icon = "attack",
            enabled = selEntity.setAttackTarget ~= nil,
            action = function()
                if #selectedEntities > 0 then
                    input.attackMoveMode = true
                    addNotification("Attack-Move: Click to attack")
                end
            end
        })
        table.insert(buttons, {
            hotkey = "S",
            text = "Stop",
            icon = "stop",
            enabled = true,
            action = function()
                for _, entity in ipairs(selectedEntities) do
                    if isPlayerOwned(entity) then
                        if entity.stop then entity:stop()
                        elseif entity.state then entity.state = "Idle" end
                    end
                end
            end
        })
    end

    -- Peon build commands
    if selEntity.type == "peon" then
        local canBuild = selEntity.state ~= "Building"
        local Farm = require("farm")
        local Barracks = require("barracks")
        local LumberMill = require("lumbermill")
        local Blacksmith = require("blacksmith")
        local ScoutTower = require("scouttower")
        local Stable = require("stable")
        local SiegeWorkshop = require("siegeworkshop")
        local TownHall = require("townhall")

        -- Basic buildings (always available)
        table.insert(buttons, {
            hotkey = "F",
            text = "Farm",
            icon = "farm",
            cost = M.Farm.COST_GOLD .. "/" .. M.Farm.COST_LUMBER,
            enabled = canBuild and resources.gold >= M.Farm.COST_GOLD and resources.lumber >= M.Farm.COST_LUMBER,
            action = function()
                if resources.gold >= M.Farm.COST_GOLD and resources.lumber >= M.Farm.COST_LUMBER then
                    buildingPlacement:start(selEntity, "farm")
                end
            end
        })
        table.insert(buttons, {
            hotkey = "B",
            text = "Barracks",
            icon = "barracks",
            cost = M.Barracks.COST_GOLD .. "/" .. M.Barracks.COST_LUMBER,
            enabled = canBuild and resources.gold >= M.Barracks.COST_GOLD and resources.lumber >= M.Barracks.COST_LUMBER,
            action = function()
                if resources.gold >= M.Barracks.COST_GOLD and resources.lumber >= M.Barracks.COST_LUMBER then
                    buildingPlacement:start(selEntity, "barracks")
                end
            end
        })
        table.insert(buttons, {
            hotkey = "T",
            text = "Tower",
            icon = "tower",
            cost = M.ScoutTower.COST_GOLD .. "/" .. M.ScoutTower.COST_LUMBER,
            enabled = canBuild and resources.gold >= M.ScoutTower.COST_GOLD and resources.lumber >= M.ScoutTower.COST_LUMBER,
            action = function()
                if resources.gold >= M.ScoutTower.COST_GOLD and resources.lumber >= M.ScoutTower.COST_LUMBER then
                    buildingPlacement:start(selEntity, "scouttower")
                end
            end
        })
        table.insert(buttons, {
            hotkey = "L",
            text = "Lumber Mill",
            icon = "lumbermill",
            cost = M.LumberMill.COST_GOLD .. "/" .. M.LumberMill.COST_LUMBER,
            enabled = canBuild and M.Requirements.canBuild("lumbermill") and resources.gold >= M.LumberMill.COST_GOLD and resources.lumber >= M.LumberMill.COST_LUMBER,
            requirement = not M.Requirements.canBuild("lumbermill") and "Barracks" or nil,
            action = function()
                if M.Requirements.canBuild("lumbermill") and resources.gold >= M.LumberMill.COST_GOLD and resources.lumber >= M.LumberMill.COST_LUMBER then
                    buildingPlacement:start(selEntity, "lumbermill")
                end
            end
        })
        table.insert(buttons, {
            hotkey = "K",
            text = "Blacksmith",
            icon = "blacksmith",
            cost = M.Blacksmith.COST_GOLD .. "/" .. M.Blacksmith.COST_LUMBER,
            enabled = canBuild and M.Requirements.canBuild("blacksmith") and resources.gold >= M.Blacksmith.COST_GOLD and resources.lumber >= M.Blacksmith.COST_LUMBER,
            requirement = not M.Requirements.canBuild("blacksmith") and "Barracks" or nil,
            action = function()
                if M.Requirements.canBuild("blacksmith") and resources.gold >= M.Blacksmith.COST_GOLD and resources.lumber >= M.Blacksmith.COST_LUMBER then
                    buildingPlacement:start(selEntity, "blacksmith")
                end
            end
        })
        table.insert(buttons, {
            hotkey = "E",
            text = "Stable",
            icon = "stable",
            cost = M.Stable.COST_GOLD .. "/" .. M.Stable.COST_LUMBER,
            enabled = canBuild and M.Requirements.canBuild("stable") and resources.gold >= M.Stable.COST_GOLD and resources.lumber >= M.Stable.COST_LUMBER,
            requirement = not M.Requirements.canBuild("stable") and "Hold" or nil,
            action = function()
                if M.Requirements.canBuild("stable") and resources.gold >= M.Stable.COST_GOLD and resources.lumber >= M.Stable.COST_LUMBER then
                    buildingPlacement:start(selEntity, "stable")
                end
            end
        })
        table.insert(buttons, {
            hotkey = "G",
            text = "Siege",
            icon = "siegeworkshop",
            cost = M.SiegeWorkshop.COST_GOLD .. "/" .. M.SiegeWorkshop.COST_LUMBER,
            enabled = canBuild and M.Requirements.canBuild("siegeworkshop") and resources.gold >= M.SiegeWorkshop.COST_GOLD and resources.lumber >= M.SiegeWorkshop.COST_LUMBER,
            requirement = not M.Requirements.canBuild("siegeworkshop") and "Keep" or nil,
            action = function()
                if M.Requirements.canBuild("siegeworkshop") and resources.gold >= M.SiegeWorkshop.COST_GOLD and resources.lumber >= M.SiegeWorkshop.COST_LUMBER then
                    buildingPlacement:start(selEntity, "siegeworkshop")
                end
            end
        })
        table.insert(buttons, {
            hotkey = "H",
            text = "Town Hall",
            icon = "townhall",
            cost = M.TownHall.COST_GOLD .. "/" .. M.TownHall.COST_LUMBER,
            enabled = canBuild and M.Requirements.canBuild("townhall") and resources.gold >= M.TownHall.COST_GOLD and resources.lumber >= M.TownHall.COST_LUMBER,
            requirement = not M.Requirements.canBuild("townhall") and "Hold" or nil,
            action = function()
                if M.Requirements.canBuild("townhall") and resources.gold >= M.TownHall.COST_GOLD and resources.lumber >= M.TownHall.COST_LUMBER then
                    buildingPlacement:start(selEntity, "townhall")
                end
            end
        })
    end

    -- Town Hall commands
    if selEntity.type == "townhall" and selEntity.completed then
        local TownHall = require("townhall")
        local canTrain = selEntity:canProduce() and resources.gold >= selEntity.productionCost and currentPop < maxPop

        table.insert(buttons, {
            hotkey = "W",
            text = "Peon",
            icon = "peon",
            cost = tostring(selEntity.productionCost),
            enabled = canTrain,
            action = function()
                if selEntity:canProduce() and resources.gold >= selEntity.productionCost and currentPop < maxPop then
                    if selEntity:startProduction() then
                        resources.gold = resources.gold - selEntity.productionCost
                        if Game.Replay then Game.Replay.log("QUEUE", "Player queued Peon at Town Hall") end
                    end
                end
            end
        })

        -- Upgrade to Hold
        if selEntity.tier == 1 and not selEntity.isUpgrading then
            local canUpgrade = M.Requirements.canUpgradeToHold() and selEntity:canUpgrade()
            local canAfford = resources.gold >= M.TownHall.HOLD_COST_GOLD and resources.lumber >= M.TownHall.HOLD_COST_LUMBER
            table.insert(buttons, {
                hotkey = "U",
                text = "Hold",
                icon = "upgrade",
                cost = M.TownHall.HOLD_COST_GOLD .. "/" .. M.TownHall.HOLD_COST_LUMBER,
                enabled = canUpgrade and canAfford,
                requirement = not M.Requirements.hasBarracks() and "Barracks" or nil,
                action = function()
                    if canUpgrade and canAfford then
                        resources.gold = resources.gold - M.TownHall.HOLD_COST_GOLD
                        resources.lumber = resources.lumber - M.TownHall.HOLD_COST_LUMBER
                        selEntity:startUpgrade()
                    end
                end
            })
        end

        -- Upgrade to Keep (requires Stable, Blacksmith, Lumber Mill)
        if selEntity.tier == 2 and not selEntity.isUpgrading then
            local hasStable = M.Requirements.hasStable and M.Requirements.hasStable() or false
            local hasBlacksmith = M.Requirements.hasBlacksmith and M.Requirements.hasBlacksmith() or false
            local hasLumberMill = M.Requirements.hasLumberMill and M.Requirements.hasLumberMill() or false
            local canUpgrade = hasStable and hasBlacksmith and hasLumberMill and selEntity:canUpgrade()
            local canAfford = resources.gold >= M.TownHall.KEEP_COST_GOLD and resources.lumber >= M.TownHall.KEEP_COST_LUMBER

            -- Determine which requirement to show
            local missingReq = nil
            if not hasStable then missingReq = "Stable"
            elseif not hasBlacksmith then missingReq = "Blacksmith"
            elseif not hasLumberMill then missingReq = "Lumber Mill"
            end

            table.insert(buttons, {
                hotkey = "U",
                text = "Keep",
                icon = "upgrade",
                cost = M.TownHall.KEEP_COST_GOLD .. "/" .. M.TownHall.KEEP_COST_LUMBER,
                enabled = canUpgrade and canAfford,
                requirement = missingReq,
                action = function()
                    if canUpgrade and canAfford then
                        resources.gold = resources.gold - M.TownHall.KEEP_COST_GOLD
                        resources.lumber = resources.lumber - M.TownHall.KEEP_COST_LUMBER
                        selEntity:startUpgrade()
                    end
                end
            })
        end
    end

    -- Barracks commands
    if selEntity.type == "barracks" and selEntity.completed then
        local Barracks = require("barracks")
        local canTrainFootman = selEntity:canProduce() and resources.gold >= M.Barracks.FOOTMAN_COST and currentPop < maxPop
        table.insert(buttons, {
            hotkey = "T",
            text = "Footman",
            icon = "footman",
            cost = tostring(M.Barracks.FOOTMAN_COST),
            enabled = canTrainFootman,
            action = function()
                if selEntity:canProduce() and resources.gold >= M.Barracks.FOOTMAN_COST and currentPop < maxPop then
                    if selEntity:startProduction("footman") then
                        resources.gold = resources.gold - M.Barracks.FOOTMAN_COST
                        if Game.Replay then Game.Replay.log("QUEUE", "Player queued Footman at Barracks") end
                    end
                end
            end
        })

        -- Archer training (requires Lumber Mill)
        local hasLumberMill = M.Requirements.hasLumberMill and M.Requirements.hasLumberMill() or false
        local archerCostGold = 150
        local archerCostLumber = 50
        local canTrainArcher = selEntity:canProduce() and hasLumberMill and
                              resources.gold >= archerCostGold and
                              resources.lumber >= archerCostLumber and
                              currentPop < maxPop
        table.insert(buttons, {
            hotkey = "A",
            text = "Archer",
            icon = "archer",
            cost = archerCostGold .. "/" .. archerCostLumber,
            enabled = canTrainArcher,
            requirement = not hasLumberMill and "Lumber Mill" or nil,
            action = function()
                if selEntity:canProduce() and hasLumberMill and
                   resources.gold >= archerCostGold and
                   resources.lumber >= archerCostLumber and
                   currentPop < maxPop then
                    if selEntity:startProduction("archer") then
                        resources.gold = resources.gold - archerCostGold
                        resources.lumber = resources.lumber - archerCostLumber
                        if Game.Replay then Game.Replay.log("QUEUE", "Player queued Archer at Barracks") end
                    end
                end
            end
        })

        -- Knight training (requires Stable)
        local hasStable = M.Requirements.hasStable and M.Requirements.hasStable() or false
        local canTrainKnight = selEntity:canProduce() and hasStable and
                              resources.gold >= M.Barracks.KNIGHT_COST_GOLD and
                              resources.lumber >= M.Barracks.KNIGHT_COST_LUMBER and
                              currentPop < maxPop
        table.insert(buttons, {
            hotkey = "K",
            text = "Knight",
            icon = "knight",
            cost = M.Barracks.KNIGHT_COST_GOLD .. "/" .. M.Barracks.KNIGHT_COST_LUMBER,
            enabled = canTrainKnight,
            requirement = not hasStable and "Stable" or nil,
            action = function()
                if selEntity:canProduce() and hasStable and
                   resources.gold >= M.Barracks.KNIGHT_COST_GOLD and
                   resources.lumber >= M.Barracks.KNIGHT_COST_LUMBER and
                   currentPop < maxPop then
                    if selEntity:startProduction("knight") then
                        resources.gold = resources.gold - M.Barracks.KNIGHT_COST_GOLD
                        resources.lumber = resources.lumber - M.Barracks.KNIGHT_COST_LUMBER
                        if Game.Replay then Game.Replay.log("QUEUE", "Player queued Knight at Barracks") end
                    end
                end
            end
        })

        -- Ballista training (requires Blacksmith)
        local hasBlacksmith = M.Requirements.hasBlacksmith and M.Requirements.hasBlacksmith() or false
        local ballistaCostGold = 500
        local ballistaCostLumber = 200
        local canTrainBallista = selEntity:canProduce() and hasBlacksmith and
                                resources.gold >= ballistaCostGold and
                                resources.lumber >= ballistaCostLumber and
                                currentPop < maxPop
        table.insert(buttons, {
            hotkey = "B",
            text = "Ballista",
            icon = "ballista",
            cost = ballistaCostGold .. "/" .. ballistaCostLumber,
            enabled = canTrainBallista,
            requirement = not hasBlacksmith and "Blacksmith" or nil,
            action = function()
                if selEntity:canProduce() and hasBlacksmith and
                   resources.gold >= ballistaCostGold and
                   resources.lumber >= ballistaCostLumber and
                   currentPop < maxPop then
                    if selEntity:startProduction("ballista") then
                        resources.gold = resources.gold - ballistaCostGold
                        resources.lumber = resources.lumber - ballistaCostLumber
                        if Game.Replay then Game.Replay.log("QUEUE", "Player queued Ballista at Barracks") end
                    end
                end
            end
        })
    end

    -- Archery Range commands (legacy - building removed)
    if selEntity.type == "archeryrange" and selEntity.completed then
        local ArcheryRange = require("archeryrange")
        local canTrain = selEntity:canProduce() and
                        resources.gold >= M.ArcheryRange.ARCHER_COST_GOLD and
                        resources.lumber >= M.ArcheryRange.ARCHER_COST_LUMBER and
                        currentPop < maxPop
        table.insert(buttons, {
            hotkey = "A",
            text = "Archer",
            icon = "archer",
            cost = M.ArcheryRange.ARCHER_COST_GOLD .. "/" .. M.ArcheryRange.ARCHER_COST_LUMBER,
            enabled = canTrain,
            action = function()
                if selEntity:canProduce() and
                   resources.gold >= M.ArcheryRange.ARCHER_COST_GOLD and
                   resources.lumber >= M.ArcheryRange.ARCHER_COST_LUMBER and
                   currentPop < maxPop then
                    if selEntity:startProduction() then
                        resources.gold = resources.gold - M.ArcheryRange.ARCHER_COST_GOLD
                        resources.lumber = resources.lumber - M.ArcheryRange.ARCHER_COST_LUMBER
                    end
                end
            end
        })
    end

    -- Siege Workshop commands
    if selEntity.type == "siegeworkshop" and selEntity.completed then
        local SiegeWorkshop = require("siegeworkshop")

        -- Flying Scout
        local canTrainScout = selEntity:canProduce() and
                             resources.gold >= M.SiegeWorkshop.FLYINGSCOUT_COST_GOLD and
                             resources.lumber >= M.SiegeWorkshop.FLYINGSCOUT_COST_LUMBER and
                             currentPop < maxPop
        table.insert(buttons, {
            hotkey = "S",
            text = "Scout",
            icon = "flyingscout",
            cost = M.SiegeWorkshop.FLYINGSCOUT_COST_GOLD .. "/" .. M.SiegeWorkshop.FLYINGSCOUT_COST_LUMBER,
            enabled = canTrainScout,
            action = function()
                if selEntity:canProduce() and
                   resources.gold >= M.SiegeWorkshop.FLYINGSCOUT_COST_GOLD and
                   resources.lumber >= M.SiegeWorkshop.FLYINGSCOUT_COST_LUMBER and
                   currentPop < maxPop then
                    if selEntity:startProduction("flyingscout") then
                        resources.gold = resources.gold - M.SiegeWorkshop.FLYINGSCOUT_COST_GOLD
                        resources.lumber = resources.lumber - M.SiegeWorkshop.FLYINGSCOUT_COST_LUMBER
                    end
                end
            end
        })

        -- Kamikaze
        local canTrainKamikaze = selEntity:canProduce() and
                                resources.gold >= M.SiegeWorkshop.KAMIKAZE_COST_GOLD and
                                resources.lumber >= M.SiegeWorkshop.KAMIKAZE_COST_LUMBER and
                                currentPop < maxPop
        table.insert(buttons, {
            hotkey = "K",
            text = "Kamikaze",
            icon = "kamikaze",
            cost = M.SiegeWorkshop.KAMIKAZE_COST_GOLD .. "/" .. M.SiegeWorkshop.KAMIKAZE_COST_LUMBER,
            enabled = canTrainKamikaze,
            action = function()
                if selEntity:canProduce() and
                   resources.gold >= M.SiegeWorkshop.KAMIKAZE_COST_GOLD and
                   resources.lumber >= M.SiegeWorkshop.KAMIKAZE_COST_LUMBER and
                   currentPop < maxPop then
                    if selEntity:startProduction("kamikaze") then
                        resources.gold = resources.gold - M.SiegeWorkshop.KAMIKAZE_COST_GOLD
                        resources.lumber = resources.lumber - M.SiegeWorkshop.KAMIKAZE_COST_LUMBER
                    end
                end
            end
        })
    end

    -- Stable commands (Paladin upgrade)
    if selEntity.type == "stable" and selEntity.completed then
        local Stable = require("stable")
        local canUpgrade = not selEntity.paladinUpgradeComplete and resources.gold >= M.Stable.PALADIN_UPGRADE_COST
        if not selEntity.paladinUpgradeComplete then
            table.insert(buttons, {
                hotkey = "P",
                text = "Paladin",
                icon = "upgrade",
                cost = tostring(M.Stable.PALADIN_UPGRADE_COST),
                enabled = canUpgrade,
                action = function()
                    if not selEntity.paladinUpgradeComplete and resources.gold >= M.Stable.PALADIN_UPGRADE_COST then
                        resources.gold = resources.gold - M.Stable.PALADIN_UPGRADE_COST
                        selEntity.paladinUpgradeComplete = true
                        addNotification("Paladin upgrade complete!")
                    end
                end
            })
        end
    end

    -- Scout Tower upgrade commands
    if selEntity.type == "scouttower" and selEntity.completed and selEntity:canUpgrade() then
        local ScoutTower = require("scouttower")

        -- Guard Tower upgrade (requires Lumber Mill)
        local guardGold, guardLumber = M.ScoutTower.GUARD_TOWER_COST_GOLD, M.ScoutTower.GUARD_TOWER_COST_LUMBER
        local canUpgradeGuard = M.Requirements.canUpgradeToGuardTower() and
                               resources.gold >= guardGold and resources.lumber >= guardLumber
        local guardReq = not M.Requirements.canUpgradeToGuardTower() and "Lumber Mill" or nil
        table.insert(buttons, {
            hotkey = "G",
            text = "Guard Tower",
            icon = "tower",
            cost = guardGold .. "/" .. guardLumber,
            enabled = canUpgradeGuard,
            requirement = guardReq,
            action = function()
                if M.Requirements.canUpgradeToGuardTower() and
                   resources.gold >= guardGold and resources.lumber >= guardLumber then
                    if selEntity:startUpgrade("guardtower") then
                        resources.gold = resources.gold - guardGold
                        resources.lumber = resources.lumber - guardLumber
                        addNotification("Upgrading to Guard Tower...")
                    end
                end
            end
        })

        -- Cannon Tower upgrade (requires Blacksmith + Keep)
        local cannonGold, cannonLumber = M.ScoutTower.CANNON_TOWER_COST_GOLD, M.ScoutTower.CANNON_TOWER_COST_LUMBER
        local canUpgradeCannon = M.Requirements.canUpgradeToCannonTower() and
                                resources.gold >= cannonGold and resources.lumber >= cannonLumber
        local cannonReq = nil
        if not M.Requirements.hasBlacksmith() then
            cannonReq = "Blacksmith"
        elseif not M.Requirements.isKeep() then
            cannonReq = "Keep"
        end
        table.insert(buttons, {
            hotkey = "C",
            text = "Cannon Tower",
            icon = "tower",
            cost = cannonGold .. "/" .. cannonLumber,
            enabled = canUpgradeCannon,
            requirement = cannonReq,
            action = function()
                if M.Requirements.canUpgradeToCannonTower() and
                   resources.gold >= cannonGold and resources.lumber >= cannonLumber then
                    if selEntity:startUpgrade("cannontower") then
                        resources.gold = resources.gold - cannonGold
                        resources.lumber = resources.lumber - cannonLumber
                        addNotification("Upgrading to Cannon Tower...")
                    end
                end
            end
        })
    end

    return buttons
end

local function drawCommandBar(screenW, screenH)
    local barH = 70
    local barY = screenH - barH
    commandBarY = barY

    -- Draw bar background
    M.UIDraw.drawCommandBar(screenW, screenH)

    local selEntity = selectedEntities[1]

    -- Left section: Selection info
    local infoX = 15
    local infoY = barY + 10

    love.graphics.setFont(Game.fonts.medium)

    if selEntity then
        -- Entity name
        love.graphics.setColor(UI.metalGold)
        love.graphics.print(selEntity.name, infoX, infoY)

        -- HP bar
        if selEntity.hp and selEntity.maxHp then
            local hpBarW = 120
            local hpBarH = 8
            local hpY = infoY + 22
            local hpPercent = selEntity.hp / selEntity.maxHp

            love.graphics.setColor(0.2, 0.15, 0.1, 1)
            love.graphics.rectangle("fill", infoX, hpY, hpBarW, hpBarH, 2)

            local hpColor = hpPercent > 0.5 and {0.3, 0.8, 0.3} or (hpPercent > 0.25 and {0.9, 0.7, 0.2} or {0.9, 0.3, 0.2})
            love.graphics.setColor(hpColor)
            love.graphics.rectangle("fill", infoX, hpY, hpBarW * hpPercent, hpBarH, 2)

            love.graphics.setColor(0.5, 0.4, 0.3, 1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", infoX, hpY, hpBarW, hpBarH, 2)

            -- HP text
            love.graphics.setFont(Game.fonts.small)
            love.graphics.setColor(UI.textLight)
            love.graphics.print(math.floor(selEntity.hp) .. "/" .. selEntity.maxHp, infoX + hpBarW + 8, hpY - 2)
        end

        -- Status text or progress bar
        love.graphics.setFont(Game.fonts.small)
        local statusY = infoY + 38
        local progressBarW = 120  -- Match HP bar width
        local progressBarH = 6

        if selEntity.type == "townhall" or selEntity.type == "barracks" or
           selEntity.type == "archeryrange" or selEntity.type == "stable" or selEntity.type == "siegeworkshop" then
            if selEntity.isBuilding then
                -- Building progress bar (blue)
                local progress = (selEntity.getBuildProgress and selEntity:getBuildProgress() or 0) / 100

                love.graphics.setColor(0.15, 0.15, 0.2, 1)
                love.graphics.rectangle("fill", infoX, statusY, progressBarW, progressBarH, 2)

                love.graphics.setColor(0.4, 0.7, 1, 1)
                love.graphics.rectangle("fill", infoX, statusY, progressBarW * progress, progressBarH, 2)

                love.graphics.setColor(0.5, 0.6, 0.7, 1)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", infoX, statusY, progressBarW, progressBarH, 2)

                love.graphics.setColor(0.6, 0.8, 1, 1)
                love.graphics.print("Building...", infoX + progressBarW + 8, statusY - 2)

            elseif selEntity.isProducing then
                -- Training progress bar (gold/yellow)
                local progress = (selEntity.getProductionProgress and selEntity:getProductionProgress() or 0) / 100
                local queueSize = selEntity.getQueueSize and selEntity:getQueueSize() or 0

                -- Background
                love.graphics.setColor(0.2, 0.18, 0.1, 1)
                love.graphics.rectangle("fill", infoX, statusY, progressBarW, progressBarH, 2)

                -- Progress fill with gradient effect (gold to yellow)
                local fillW = progressBarW * progress
                if fillW > 0 then
                    -- Main fill
                    love.graphics.setColor(0.95, 0.8, 0.3, 1)
                    love.graphics.rectangle("fill", infoX, statusY, fillW, progressBarH, 2)
                    -- Shine highlight on top half
                    love.graphics.setColor(1, 0.95, 0.6, 0.5)
                    love.graphics.rectangle("fill", infoX, statusY, fillW, progressBarH / 2, 2)
                end

                -- Border
                love.graphics.setColor(0.6, 0.5, 0.3, 1)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", infoX, statusY, progressBarW, progressBarH, 2)

                -- Queue text
                local queueText = queueSize > 1 and (" +" .. (queueSize - 1) .. " queued") or "Training..."
                love.graphics.setColor(0.9, 0.85, 0.6, 1)
                love.graphics.print(queueText, infoX + progressBarW + 8, statusY - 2)

            elseif selEntity.isUpgrading then
                love.graphics.setColor(UI.metalGold)
                love.graphics.print("Upgrading...", infoX, statusY)
            else
                -- Show "Ready" when idle
                love.graphics.setColor(UI.textLight)
                love.graphics.print("Ready", infoX, statusY)
            end
        elseif selEntity.type == "goldmine" then
            love.graphics.setColor(UI.textGold)
            love.graphics.print("Gold: " .. selEntity.goldReserves, infoX, statusY)
        elseif selEntity.getStateText then
            love.graphics.setColor(UI.textLight)
            love.graphics.print(selEntity:getStateText(), infoX, statusY)
        end

        -- Multi-select indicator
        if #selectedEntities > 1 then
            love.graphics.setColor(UI.textLight)
            love.graphics.print("+" .. (#selectedEntities - 1) .. " more", infoX + 150, infoY + 4)
        end
    else
        love.graphics.setColor(UI.stoneAccent)
        love.graphics.print("No Selection", infoX, infoY)
        love.graphics.setFont(Game.fonts.small)
        love.graphics.setColor(0.6, 0.55, 0.5, 0.8)
        love.graphics.print("Click units to select  |  Drag to box select  |  Right-click to command", infoX, infoY + 25)
    end

    -- Center section: Command buttons (primary action in center of screen)
    commandButtons = getCommandButtons()
    local btnY = barY + 8

    -- Find primary button and separate from others
    local primaryBtn = nil
    local otherBtns = {}
    for _, btn in ipairs(commandButtons) do
        if btn.primary then
            primaryBtn = btn
        else
            table.insert(otherBtns, btn)
        end
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local hoveredBtn = nil
    local hoveredX, hoveredY = nil, nil

    -- Draw primary button in center of screen
    if primaryBtn then
        local x = (screenW - COMMAND_BUTTON_SIZE) / 2
        local hovered = mouseX >= x and mouseX <= x + COMMAND_BUTTON_SIZE and
                       mouseY >= btnY and mouseY <= btnY + COMMAND_BUTTON_SIZE
        local pressed = hovered and love.mouse.isDown(1)

        primaryBtn.x = x
        primaryBtn.y = btnY
        primaryBtn.w = COMMAND_BUTTON_SIZE
        primaryBtn.h = COMMAND_BUTTON_SIZE
        primaryBtn.hovered = hovered

        M.UIDraw.drawCommandButton(x, btnY, COMMAND_BUTTON_SIZE, COMMAND_BUTTON_SIZE,
            primaryBtn.text, primaryBtn.hotkey, primaryBtn.enabled, hovered, pressed, primaryBtn.icon)

        if hovered then
            hoveredBtn = primaryBtn
            hoveredX = x
            hoveredY = btnY
        end
    end

    -- Draw other buttons to the right of primary
    local otherStartX = primaryBtn and ((screenW + COMMAND_BUTTON_SIZE) / 2 + 15) or ((screenW - #otherBtns * (COMMAND_BUTTON_SIZE + COMMAND_BUTTON_SPACING)) / 2)

    for i, btn in ipairs(otherBtns) do
        local x = otherStartX + (i - 1) * (COMMAND_BUTTON_SIZE + COMMAND_BUTTON_SPACING)
        local hovered = mouseX >= x and mouseX <= x + COMMAND_BUTTON_SIZE and
                       mouseY >= btnY and mouseY <= btnY + COMMAND_BUTTON_SIZE
        local pressed = hovered and love.mouse.isDown(1)

        btn.x = x
        btn.y = btnY
        btn.w = COMMAND_BUTTON_SIZE
        btn.h = COMMAND_BUTTON_SIZE
        btn.hovered = hovered

        M.UIDraw.drawCommandButton(x, btnY, COMMAND_BUTTON_SIZE, COMMAND_BUTTON_SIZE,
            btn.text, btn.hotkey, btn.enabled, hovered, pressed, btn.icon)

        if hovered then
            hoveredBtn = btn
            hoveredX = x
            hoveredY = btnY
        end
    end

    -- Draw tooltip for hovered button (on top of everything)
    if hoveredBtn then
        M.CommandBar.drawTooltip(hoveredBtn, hoveredX, hoveredY)
    end
end

-- Legacy function name for compatibility (no longer draws left panel)
local function drawInfoPanel(startY, height)
    -- No longer used - resources moved to top bar
end

-- Legacy function name for compatibility
local function drawRightPanel(screenW, startY, height)
    -- Replaced by drawMinimap and drawBottomPanel
end

local function drawVictoryScreen()
    local screenW, screenH = love.graphics.getDimensions()

    -- Dark overlay with stone tint
    love.graphics.setColor(0.02, 0.03, 0.02, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local boxW, boxH = 600, 480
    local boxX, boxY = (screenW - boxW) / 2, (screenH - boxH) / 2

    -- Draw stone panel using UIDraw
    M.UIDraw.drawStonePanel(boxX, boxY, boxW, boxH, 10)

    -- Corner rivets
    local function drawRivet(cx, cy, radius)
        love.graphics.setColor(0.72, 0.58, 0.26, 1)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(0.88, 0.72, 0.42, 0.7)
        love.graphics.circle("fill", cx - radius * 0.3, cy - radius * 0.3, radius * 0.4)
    end
    local ro = 15
    drawRivet(boxX + ro, boxY + ro, 5)
    drawRivet(boxX + boxW - ro, boxY + ro, 5)
    drawRivet(boxX + ro, boxY + boxH - ro, 5)
    drawRivet(boxX + boxW - ro, boxY + boxH - ro, 5)

    -- Title with glow
    love.graphics.setFont(Game.fonts.title)
    local title = "VICTORY!"
    local titleW = Game.fonts.title:getWidth(title)
    local titleX = (screenW - titleW) / 2
    local titleY = boxY + 15

    -- Glow effect
    local glowPulse = 0.6 + math.sin(elapsedTime * 3) * 0.4
    love.graphics.setColor(1, 0.85, 0.2, 0.25 * glowPulse)
    for dx = -2, 2 do
        for dy = -2, 2 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.print(title, titleX + dx, titleY + dy)
            end
        end
    end
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(title, titleX + 2, titleY + 2)
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.print(title, titleX, titleY)

    -- Time
    local minutes = math.floor(elapsedTime / 60)
    local seconds = math.floor(elapsedTime % 60)
    local timeStr = string.format("Game Time: %d:%02d", minutes, seconds)
    love.graphics.setFont(Game.fonts.stats)
    love.graphics.setColor(0.92, 0.88, 0.80, 1)
    love.graphics.print(timeStr, (screenW - Game.fonts.stats:getWidth(timeStr)) / 2, titleY + 70)

    -- Decorative line
    love.graphics.setColor(0.50, 0.38, 0.20, 1)
    love.graphics.setLineWidth(2)
    local lineY = titleY + 95
    love.graphics.line(boxX + 40, lineY, boxX + boxW - 40, lineY)
    drawRivet(boxX + 40, lineY, 3)
    drawRivet(boxX + boxW - 40, lineY, 3)

    -- Stats table header
    local tableY = lineY + 15
    local col1 = boxX + 50   -- Stat name
    local col2 = boxX + 280  -- Player
    local col3 = boxX + 400  -- Enemy
    local rowH = 22

    love.graphics.setFont(Game.fonts.header)
    love.graphics.setColor(0.72, 0.58, 0.26, 1)
    love.graphics.print("STATISTIC", col1, tableY)
    love.graphics.setColor(0.4, 0.6, 1, 1)
    love.graphics.print("YOU", col2 + 20, tableY)
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.print("ENEMY", col3 + 10, tableY)

    -- Header underline
    love.graphics.setColor(0.50, 0.38, 0.20, 0.5)
    love.graphics.line(col1, tableY + 25, boxX + boxW - 50, tableY + 25)

    -- Stats rows
    love.graphics.setFont(Game.fonts.stats)
    local statsY = tableY + 35

    local function drawStatRow(label, playerVal, enemyVal, y)
        love.graphics.setColor(0.92, 0.88, 0.80, 0.9)
        love.graphics.print(label, col1, y)

        -- Player value (blue tint)
        love.graphics.setColor(0.7, 0.8, 1, 1)
        love.graphics.print(tostring(playerVal), col2 + 30, y)

        -- Enemy value (red tint)
        love.graphics.setColor(1, 0.7, 0.7, 1)
        love.graphics.print(tostring(enemyVal), col3 + 30, y)
    end

    drawStatRow("Units Killed", gameStats.unitsKilled, gameStats.aiUnitsKilled, statsY)
    drawStatRow("Units Lost", gameStats.unitsLost, gameStats.aiUnitsLost, statsY + rowH)
    drawStatRow("Buildings Destroyed", gameStats.buildingsDestroyed, gameStats.aiBuildingsDestroyed, statsY + rowH * 2)
    drawStatRow("Buildings Lost", gameStats.buildingsLost, gameStats.aiBuildingsLost, statsY + rowH * 3)

    -- Separator
    love.graphics.setColor(0.50, 0.38, 0.20, 0.3)
    love.graphics.line(col1, statsY + rowH * 3.7, boxX + boxW - 50, statsY + rowH * 3.7)

    drawStatRow("Gold Collected", gameStats.goldCollected, gameStats.aiGoldCollected, statsY + rowH * 4)
    drawStatRow("Lumber Collected", gameStats.lumberCollected, gameStats.aiLumberCollected, statsY + rowH * 5)
    drawStatRow("Peons Trained", gameStats.peonsProduced, gameStats.aiPeonsProduced, statsY + rowH * 6)
    drawStatRow("Footmen Trained", gameStats.footmenProduced, gameStats.aiFootmenProduced, statsY + rowH * 7)

    -- Score calculation
    local playerScore = gameStats.unitsKilled * 10 + gameStats.buildingsDestroyed * 50
                       + gameStats.goldCollected / 100 + gameStats.lumberCollected / 50
                       - gameStats.unitsLost * 5 - gameStats.buildingsLost * 25
    local aiScore = gameStats.aiUnitsKilled * 10 + gameStats.aiBuildingsDestroyed * 50
                   + gameStats.aiGoldCollected / 100 + gameStats.aiLumberCollected / 50
                   - gameStats.aiUnitsLost * 5 - gameStats.aiBuildingsLost * 25

    -- Score section
    local scoreY = statsY + rowH * 8.5
    love.graphics.setColor(0.50, 0.38, 0.20, 0.5)
    love.graphics.line(col1, scoreY - 5, boxX + boxW - 50, scoreY - 5)

    love.graphics.setFont(Game.fonts.statsLarge)
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("SCORE", col1, scoreY)
    love.graphics.setColor(0.5, 0.7, 1, 1)
    love.graphics.print(string.format("%d", math.floor(playerScore)), col2 + 15, scoreY)
    love.graphics.setColor(1, 0.6, 0.6, 1)
    love.graphics.print(string.format("%d", math.floor(aiScore)), col3 + 15, scoreY)

    -- Building timeline (if any)
    if #gameStats.buildingTimeline > 0 then
        local timelineY = scoreY + 40
        love.graphics.setFont(Game.fonts.small)
        love.graphics.setColor(0.72, 0.58, 0.26, 0.8)
        love.graphics.print("Building Timeline:", col1, timelineY)

        love.graphics.setColor(0.8, 0.75, 0.65, 0.7)
        local timelineText = ""
        for i, entry in ipairs(gameStats.buildingTimeline) do
            if i <= 6 then  -- Show max 6 entries
                local m = math.floor(entry.time / 60)
                local s = math.floor(entry.time % 60)
                local team = entry.team == 1 and "You" or "AI"
                timelineText = timelineText .. string.format("%d:%02d %s-%s  ", m, s, team, entry.type)
            end
        end
        love.graphics.print(timelineText, col1, timelineY + 18)
    end

    -- Return to Menu button
    local btnW, btnH = 180, 40
    local btnX = (screenW - btnW) / 2
    local btnY = boxY + boxH - 55

    -- Store button bounds for click detection
    endScreenButton = {x = btnX, y = btnY, w = btnW, h = btnH}

    local mx, my = love.mouse.getPosition()
    local hovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    -- Button background
    if hovered then
        love.graphics.setColor(0.35, 0.28, 0.18, 1)
    else
        love.graphics.setColor(0.22, 0.18, 0.14, 1)
    end
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6)

    -- Button border
    if hovered then
        love.graphics.setColor(0.9, 0.75, 0.4, 1)
    else
        love.graphics.setColor(0.6, 0.5, 0.3, 1)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 6)

    -- Button text
    love.graphics.setFont(Game.fonts.medium)
    local btnText = "Return to Menu"
    local textW = Game.fonts.medium:getWidth(btnText)
    love.graphics.setColor(hovered and {1, 0.95, 0.8, 1} or {0.92, 0.88, 0.78, 1})
    love.graphics.print(btnText, btnX + (btnW - textW) / 2, btnY + 10)
end

local function drawDefeatScreen()
    local screenW, screenH = love.graphics.getDimensions()

    -- Dark overlay with red tint
    love.graphics.setColor(0.03, 0.02, 0.02, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local boxW, boxH = 600, 480
    local boxX, boxY = (screenW - boxW) / 2, (screenH - boxH) / 2

    -- Draw stone panel using UIDraw
    M.UIDraw.drawStonePanel(boxX, boxY, boxW, boxH, 10)

    -- Corner rivets (darker for defeat)
    local function drawRivet(cx, cy, radius)
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(0.6, 0.45, 0.3, 0.5)
        love.graphics.circle("fill", cx - radius * 0.3, cy - radius * 0.3, radius * 0.4)
    end
    local ro = 15
    drawRivet(boxX + ro, boxY + ro, 5)
    drawRivet(boxX + boxW - ro, boxY + ro, 5)
    drawRivet(boxX + ro, boxY + boxH - ro, 5)
    drawRivet(boxX + boxW - ro, boxY + boxH - ro, 5)

    -- Title with dark glow
    love.graphics.setFont(Game.fonts.title)
    local title = "DEFEAT"
    local titleW = Game.fonts.title:getWidth(title)
    local titleX = (screenW - titleW) / 2
    local titleY = boxY + 15

    -- Dark glow effect
    love.graphics.setColor(0.3, 0.1, 0.1, 0.4)
    for dx = -2, 2 do
        for dy = -2, 2 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.print(title, titleX + dx, titleY + dy)
            end
        end
    end
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(title, titleX + 2, titleY + 2)
    love.graphics.setColor(0.8, 0.25, 0.2, 1)
    love.graphics.print(title, titleX, titleY)

    -- Time
    local minutes = math.floor(elapsedTime / 60)
    local seconds = math.floor(elapsedTime % 60)
    local timeStr = string.format("Game Time: %d:%02d", minutes, seconds)
    love.graphics.setFont(Game.fonts.stats)
    love.graphics.setColor(0.92, 0.88, 0.80, 1)
    love.graphics.print(timeStr, (screenW - Game.fonts.stats:getWidth(timeStr)) / 2, titleY + 70)

    -- Decorative line
    love.graphics.setColor(0.40, 0.28, 0.15, 1)
    love.graphics.setLineWidth(2)
    local lineY = titleY + 95
    love.graphics.line(boxX + 40, lineY, boxX + boxW - 40, lineY)
    drawRivet(boxX + 40, lineY, 3)
    drawRivet(boxX + boxW - 40, lineY, 3)

    -- Stats table header
    local tableY = lineY + 15
    local col1 = boxX + 50   -- Stat name
    local col2 = boxX + 280  -- Player
    local col3 = boxX + 400  -- Enemy
    local rowH = 22

    love.graphics.setFont(Game.fonts.header)
    love.graphics.setColor(0.72, 0.58, 0.26, 1)
    love.graphics.print("STATISTIC", col1, tableY)
    love.graphics.setColor(0.4, 0.6, 1, 1)
    love.graphics.print("YOU", col2 + 20, tableY)
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.print("ENEMY", col3 + 10, tableY)

    -- Header underline
    love.graphics.setColor(0.40, 0.28, 0.15, 0.5)
    love.graphics.line(col1, tableY + 25, boxX + boxW - 50, tableY + 25)

    -- Stats rows
    love.graphics.setFont(Game.fonts.stats)
    local statsY = tableY + 35

    local function drawStatRow(label, playerVal, enemyVal, y)
        love.graphics.setColor(0.92, 0.88, 0.80, 0.9)
        love.graphics.print(label, col1, y)
        love.graphics.setColor(0.7, 0.8, 1, 1)
        love.graphics.print(tostring(playerVal), col2 + 30, y)
        love.graphics.setColor(1, 0.7, 0.7, 1)
        love.graphics.print(tostring(enemyVal), col3 + 30, y)
    end

    drawStatRow("Units Killed", gameStats.unitsKilled, gameStats.aiUnitsKilled, statsY)
    drawStatRow("Units Lost", gameStats.unitsLost, gameStats.aiUnitsLost, statsY + rowH)
    drawStatRow("Buildings Destroyed", gameStats.buildingsDestroyed, gameStats.aiBuildingsDestroyed, statsY + rowH * 2)
    drawStatRow("Buildings Lost", gameStats.buildingsLost, gameStats.aiBuildingsLost, statsY + rowH * 3)

    love.graphics.setColor(0.40, 0.28, 0.15, 0.3)
    love.graphics.line(col1, statsY + rowH * 3.7, boxX + boxW - 50, statsY + rowH * 3.7)

    drawStatRow("Gold Collected", gameStats.goldCollected, gameStats.aiGoldCollected, statsY + rowH * 4)
    drawStatRow("Lumber Collected", gameStats.lumberCollected, gameStats.aiLumberCollected, statsY + rowH * 5)
    drawStatRow("Peons Trained", gameStats.peonsProduced, gameStats.aiPeonsProduced, statsY + rowH * 6)
    drawStatRow("Footmen Trained", gameStats.footmenProduced, gameStats.aiFootmenProduced, statsY + rowH * 7)

    -- Score calculation
    local playerScore = gameStats.unitsKilled * 10 + gameStats.buildingsDestroyed * 50
                       + gameStats.goldCollected / 100 + gameStats.lumberCollected / 50
                       - gameStats.unitsLost * 5 - gameStats.buildingsLost * 25
    local aiScore = gameStats.aiUnitsKilled * 10 + gameStats.aiBuildingsDestroyed * 50
                   + gameStats.aiGoldCollected / 100 + gameStats.aiLumberCollected / 50
                   - gameStats.aiUnitsLost * 5 - gameStats.aiBuildingsLost * 25

    -- Score section
    local scoreY = statsY + rowH * 8.5
    love.graphics.setColor(0.40, 0.28, 0.15, 0.5)
    love.graphics.line(col1, scoreY - 5, boxX + boxW - 50, scoreY - 5)

    love.graphics.setFont(Game.fonts.statsLarge)
    love.graphics.setColor(0.8, 0.6, 0.3, 1)
    love.graphics.print("SCORE", col1, scoreY)
    love.graphics.setColor(0.5, 0.7, 1, 1)
    love.graphics.print(string.format("%d", math.floor(playerScore)), col2 + 15, scoreY)
    love.graphics.setColor(1, 0.6, 0.6, 1)
    love.graphics.print(string.format("%d", math.floor(aiScore)), col3 + 15, scoreY)

    -- Return to Menu button
    local btnW, btnH = 180, 40
    local btnX = (screenW - btnW) / 2
    local btnY = boxY + boxH - 55

    -- Store button bounds for click detection
    endScreenButton = {x = btnX, y = btnY, w = btnW, h = btnH}

    local mx, my = love.mouse.getPosition()
    local hovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    -- Button background
    if hovered then
        love.graphics.setColor(0.35, 0.28, 0.18, 1)
    else
        love.graphics.setColor(0.22, 0.18, 0.14, 1)
    end
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6)

    -- Button border
    if hovered then
        love.graphics.setColor(0.9, 0.75, 0.4, 1)
    else
        love.graphics.setColor(0.6, 0.5, 0.3, 1)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 6)

    -- Button text
    love.graphics.setFont(Game.fonts.medium)
    local btnText = "Return to Menu"
    local textW = Game.fonts.medium:getWidth(btnText)
    love.graphics.setColor(hovered and {1, 0.95, 0.8, 1} or {0.92, 0.88, 0.78, 1})
    love.graphics.print(btnText, btnX + (btnW - textW) / 2, btnY + 10)
end

local function drawBoxSelection()
    if not isBoxSelecting then return end
    local x1, y1 = math.min(boxStartX, boxEndX), math.min(boxStartY, boxEndY)
    local w, h = math.abs(boxEndX - boxStartX), math.abs(boxEndY - boxStartY)
    -- Only draw if box has meaningful size (avoid drawing at 0,0 or tiny boxes)
    if w < 2 and h < 2 then return end
    love.graphics.setColor(0, 1, 0, 0.2)
    love.graphics.rectangle("fill", x1, y1, w, h)
    love.graphics.setColor(0, 1, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x1, y1, w, h)
end

local function drawCursor()
    local mx, my = love.mouse.getPosition()

    if input.cursorState == "grabbing" then
        -- Grabbing hand cursor - closed fist
        local size = 20
        love.graphics.push()
        love.graphics.translate(mx, my)

        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.ellipse("fill", 3, size/2 + 3, size/2 - 2, size/3)

        -- Closed fist (palm)
        love.graphics.setColor(0.9, 0.75, 0.6, 1)
        love.graphics.ellipse("fill", 0, size/2 - 2, size/2 - 2, size/3 + 2)

        -- Knuckles (4 bumps on top)
        for i = 0, 3 do
            local kx = -6 + i * 4
            love.graphics.ellipse("fill", kx, size/2 - 8, 3, 4)
        end

        -- Thumb tucked on side
        love.graphics.ellipse("fill", -size/2 + 2, size/2 - 2, 4, 5)

        -- Outline
        love.graphics.setColor(0.3, 0.2, 0.15, 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.ellipse("line", 0, size/2 - 2, size/2 - 2, size/3 + 2)

        -- Finger lines on knuckles
        love.graphics.setLineWidth(1)
        for i = 0, 2 do
            local lx = -4 + i * 4
            love.graphics.line(lx, size/2 - 10, lx, size/2 - 5)
        end

        love.graphics.pop()

    elseif input.cursorState == "charging" then
        -- Hand opening up with charge indicator
        local size = 18
        local pulse = 1 + input.cursorChargeProgress * 0.3  -- Scale up as charging
        local shake = math.sin(love.timer.getTime() * 30) * input.cursorChargeProgress * 2

        love.graphics.push()
        love.graphics.translate(mx + shake, my)
        love.graphics.scale(pulse, pulse)

        -- Charge ring growing around cursor
        love.graphics.setColor(0.9, 0.7, 0.2, input.cursorChargeProgress * 0.8)
        love.graphics.setLineWidth(2)
        local ringRadius = 12 + input.cursorChargeProgress * 8
        love.graphics.arc("line", 0, size/2, ringRadius, -math.pi/2, -math.pi/2 + input.cursorChargeProgress * math.pi * 2)

        -- Open hand (palm)
        love.graphics.setColor(0.9, 0.75, 0.6, 1)
        love.graphics.ellipse("fill", 0, size/2 + 2, size/2 - 3, size/3)

        -- Fingers spreading based on charge
        local spread = input.cursorChargeProgress * 0.3
        for i = 0, 3 do
            local angle = (-0.3 - spread) + (i * (0.2 + spread * 0.15))
            local fx = math.sin(angle) * 10
            local fy = -math.cos(angle) * 12 + size/2 - 5
            love.graphics.ellipse("fill", fx, fy, 2.5, 6)
        end

        -- Thumb
        love.graphics.ellipse("fill", -size/2 + 1, size/2, 3, 5)

        -- Outline
        love.graphics.setColor(0.3, 0.2, 0.15, 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.ellipse("line", 0, size/2 + 2, size/2 - 3, size/3)

        love.graphics.pop()

    else
        -- Check for attack-move mode first
        if input.attackMoveMode then
            -- Attack cursor - red sword/crosshair
            local size = 22
            love.graphics.push()
            love.graphics.translate(mx, my)

            -- Pulsing effect
            local pulse = 1 + math.sin(love.timer.getTime() * 6) * 0.1
            love.graphics.scale(pulse, pulse)

            -- Shadow
            love.graphics.setColor(0, 0, 0, 0.4)
            love.graphics.circle("line", 2, 2, size/2)

            -- Crosshair circle
            love.graphics.setColor(0.9, 0.2, 0.2, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 0, 0, size/2)

            -- Cross lines
            love.graphics.line(-size/2 - 4, 0, -size/4, 0)
            love.graphics.line(size/4, 0, size/2 + 4, 0)
            love.graphics.line(0, -size/2 - 4, 0, -size/4)
            love.graphics.line(0, size/4, 0, size/2 + 4)

            -- Center dot
            love.graphics.setColor(1, 0.3, 0.3, 1)
            love.graphics.circle("fill", 0, 0, 3)

            -- Sword icon in center
            love.graphics.setColor(0.8, 0.8, 0.85, 1)
            love.graphics.setLineWidth(2)
            love.graphics.line(0, -4, 0, 6)  -- Blade
            love.graphics.setColor(0.6, 0.5, 0.3, 1)
            love.graphics.line(-3, 0, 3, 0)  -- Crossguard

            love.graphics.pop()
        else
            -- Normal pointer cursor
            local size = 20

            love.graphics.push()
            love.graphics.translate(mx, my)

            -- Shadow
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.polygon("fill", 3, 3, 3, size + 3, 8, size - 4 + 3, 12, size + 5 + 3, 15, size + 3, 10, size - 3 + 3, 18, size - 3 + 3)

            -- Main arrow body (golden/bronze medieval style)
            love.graphics.setColor(0.85, 0.7, 0.35, 1)
            love.graphics.polygon("fill", 0, 0, 0, size, 5, size - 4, 9, size + 5, 12, size, 7, size - 3, 15, size - 3)

            -- Inner highlight
            love.graphics.setColor(0.95, 0.85, 0.5, 1)
            love.graphics.polygon("fill", 2, 4, 2, size - 4, 5, size - 6)

            -- Outline
            love.graphics.setColor(0.3, 0.2, 0.1, 1)
            love.graphics.setLineWidth(1.5)
            love.graphics.polygon("line", 0, 0, 0, size, 5, size - 4, 9, size + 5, 12, size, 7, size - 3, 15, size - 3)

            -- Decorative dot at top
            love.graphics.setColor(0.7, 0.5, 0.3, 1)
            love.graphics.circle("fill", 1, 2, 2)

            love.graphics.pop()
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Callback for AI to create buildings
local function aiCreateBuilding(peon, buildingType, gridX, gridY, team)
    if not peon or not gridX or not gridY then return end

    -- goToBuild expects grid coordinates, not world coordinates
    -- Tell peon to go build at the grid location
    peon:goToBuild(gridX, gridY, buildingType, function()
        -- This callback is called when peon arrives
        local actualTeam = team or peon.team

        if buildingType == "farm" then
            local building = M.Farm.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = actualTeam})
            building.builderPeon = peon
            table.insert(farms, building)
        elseif buildingType == "barracks" then
            local building = M.Barracks.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = actualTeam})
            building.builderPeon = peon
            table.insert(barracks, building)
        end
    end)
end

local function createBuilding(gridX, gridY, buildingType, peon)
    local team = peon and peon.team or (M.Teams and M.Teams.PLAYER or 1)
    local building = nil

    if buildingType == "farm" then
        building = M.Farm.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(farms, building)
    elseif buildingType == "barracks" then
        building = M.Barracks.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(barracks, building)
    elseif buildingType == "lumbermill" and M.LumberMill then
        building = M.LumberMill.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(lumberMills, building)
    elseif buildingType == "blacksmith" and M.Blacksmith then
        building = M.Blacksmith.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(blacksmiths, building)
    elseif buildingType == "scouttower" then
        building = M.ScoutTower.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(scoutTowers, building)
    elseif buildingType == "archeryrange" and M.ArcheryRange then
        building = M.ArcheryRange.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(archeryRanges, building)
    elseif buildingType == "stable" and M.Stable then
        building = M.Stable.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        -- Set callback for Paladin upgrade
        building.onPaladinUpgrade = function()
            for _, knight in ipairs(knights) do
                knight:upgradeToPaladin()
            end
        end
        table.insert(stables, building)
    elseif buildingType == "siegeworkshop" and M.SiegeWorkshop then
        building = M.SiegeWorkshop.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(siegeWorkshops, building)
    elseif buildingType == "townhall" then
        building = M.TownHall.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(townHalls, building)
    end

    -- Mark building as blocked in navigation grid
    if building then
        M.Pathfinding.markBuilding(building, false)
        -- Log building construction start
        local playerTeam = M.Teams and M.Teams.PLAYER or 1
        local teamName = team == playerTeam and "Player" or "AI"
        local buildingName = buildingType:gsub("^%l", string.upper)  -- Capitalize first letter
        if Game.Replay then Game.Replay.log("ORDER", teamName .. " started building " .. buildingName) end
    end
end

local function getBuildingCost(buildingType)
    local ok, mod = pcall(require, buildingType)
    if ok and mod and mod.COST_GOLD and mod.COST_LUMBER then
        return mod.COST_GOLD, mod.COST_LUMBER
    end
    return 0, 0
end

local function findNearestTree(worldX, worldY)
    local gridX, gridY = map:worldToGrid(worldX, worldY)

    if map:isTileTree(gridX, gridY) then
        return gridX, gridY
    end

    for radius = 1, 15 do
        local bestDist = math.huge
        local bestX, bestY = nil, nil

        for dy = -radius, radius do
            for dx = -radius, radius do
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local tx, ty = gridX + dx, gridY + dy
                    if map:isTileTree(tx, ty) then
                        local dist = dx * dx + dy * dy
                        if dist < bestDist then
                            bestDist = dist
                            bestX, bestY = tx, ty
                        end
                    end
                end
            end
        end

        if bestX then
            return bestX, bestY
        end
    end

    return nil, nil
end

local function pushUnitOutOfBuildings(unit)
    local buildings = getAllBuildings()

    -- Helper to check if position collides with any building
    local function collidesWithAnyBuilding(x, y, radius, excludeBuilding)
        for _, b in ipairs(buildings) do
            if b ~= excludeBuilding and b.getWorldBounds then
                local bx1, by1, bx2, by2 = b:getWorldBounds()
                local closestX = math.max(bx1, math.min(x, bx2))
                local closestY = math.max(by1, math.min(y, by2))
                local dx = x - closestX
                local dy = y - closestY
                if (dx * dx + dy * dy) < (radius * radius) then
                    return true
                end
            end
        end
        return false
    end

    -- Multiple passes to handle being pushed into another building
    for pass = 1, 5 do
        local pushedThisPass = false

        for _, b in ipairs(buildings) do
            -- Skip pushing peon away from its target mine
            if unit.targetMine and b == unit.targetMine then
                goto continue
            end

            if b.getWorldBounds then
                local bx1, by1, bx2, by2 = b:getWorldBounds()
                local closestX = math.max(bx1, math.min(unit.worldX, bx2))
                local closestY = math.max(by1, math.min(unit.worldY, by2))
                local dx = unit.worldX - closestX
                local dy = unit.worldY - closestY
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist < unit.radius then
                    pushedThisPass = true
                    local newX, newY

                    if dist > 0.1 then
                        local pushDist = unit.radius - dist + 2
                        newX = unit.worldX + (dx / dist) * pushDist
                        newY = unit.worldY + (dy / dist) * pushDist
                    else
                        -- Unit is exactly inside, push to nearest edge
                        local bcx, bcy = b:getWorldCenter()
                        dx = unit.worldX - bcx
                        dy = unit.worldY - bcy
                        dist = math.sqrt(dx * dx + dy * dy)
                        if dist > 0.1 then
                            local pushDist = unit.radius + math.max(bx2 - bx1, by2 - by1) / 2 + 5
                            newX = bcx + (dx / dist) * pushDist
                            newY = bcy + (dy / dist) * pushDist
                        else
                            newX = bx2 + unit.radius + 5
                            newY = by1 + (by2 - by1) / 2
                        end
                    end

                    -- Check if new position would collide with another building
                    if not collidesWithAnyBuilding(newX, newY, unit.radius, b) and map:isWorldPosPassable(newX, newY) then
                        unit.worldX = newX
                        unit.worldY = newY
                    else
                        -- Try 8 directions around the building
                        local bcx, bcy = b:getWorldCenter()
                        local halfW = (bx2 - bx1) / 2
                        local halfH = (by2 - by1) / 2
                        local escapeRadius = math.max(halfW, halfH) + unit.radius + 5

                        local angles = {0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi, -3*math.pi/4, -math.pi/2, -math.pi/4}
                        for _, angle in ipairs(angles) do
                            local testX = bcx + math.cos(angle) * escapeRadius
                            local testY = bcy + math.sin(angle) * escapeRadius
                            if not collidesWithAnyBuilding(testX, testY, unit.radius, nil) and map:isWorldPosPassable(testX, testY) then
                                unit.worldX = testX
                                unit.worldY = testY
                                break
                            end
                        end
                    end
                end
            end

            ::continue::
        end

        if not pushedThisPass then
            break
        end
    end
end

local function clearSelection()
    for _, e in ipairs(selectedEntities) do e.selected = false end
    selectedEntities = {}
end

-- Helper to check if current selection contains units
local function selectionHasUnits()
    for _, e in ipairs(selectedEntities) do
        if e.type == "peon" or e.type == "footman" or e.type == "archer" or
           e.type == "knight" or e.type == "flyingscout" or e.type == "ballista" or e.type == "kamikaze" then
            return true
        end
    end
    return false
end

-- Helper to check if current selection contains buildings
local function selectionHasBuildings()
    for _, e in ipairs(selectedEntities) do
        if e.type == "townhall" or e.type == "barracks" or e.type == "farm" or
           e.type == "lumbermill" or e.type == "blacksmith" or e.type == "scouttower" or
           e.type == "archeryrange" or e.type == "stable" or e.type == "siegeworkshop" then
            return true
        end
    end
    return false
end

-- Helper to check if entity is a unit (not a building)
local function isUnit(entity)
    return entity.type == "peon" or entity.type == "footman" or entity.type == "archer" or
           entity.type == "knight" or entity.type == "flyingscout" or entity.type == "ballista" or entity.type == "kamikaze"
end

-- Helper to check if entity is a building
local function isBuilding(entity)
    return entity.type == "townhall" or entity.type == "barracks" or entity.type == "farm" or
           entity.type == "lumbermill" or entity.type == "blacksmith" or entity.type == "scouttower" or
           entity.type == "archeryrange" or entity.type == "stable" or entity.type == "siegeworkshop"
end

local function updateRequirementsState()
    M.Requirements.setGameState({
        townHall = townHall,
        barracks = barracks,
        farms = farms,
        archeryRanges = archeryRanges,
        stables = stables,
        siegeWorkshops = siegeWorkshops,
        lumberMills = lumberMills,
        blacksmiths = blacksmiths,
        scoutTowers = scoutTowers
    })
end

-- Remove dead units from a list
local function removeDeadUnits(unitList, isPlayer)
    for i = #unitList, 1, -1 do
        local unit = unitList[i]
        if unit.isDead and unit:isDead() then
            -- Track stats for both sides
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = unit.team == playerTeam and "Player" or "AI"
            local unitType = unit.unitType or "Unit"
            if Game.Replay then
                Game.Replay.log("DEATH", teamName .. " " .. unitType .. " killed")
            end
            if unit.team == playerTeam then
                gameStats.unitsLost = gameStats.unitsLost + 1
                gameStats.aiUnitsKilled = gameStats.aiUnitsKilled + 1
            else
                gameStats.unitsKilled = gameStats.unitsKilled + 1
                gameStats.aiUnitsLost = gameStats.aiUnitsLost + 1
            end
            -- Spawn death effect
            if Effects then
                M.Effects.blood(unit.worldX, unit.worldY)
            end
            table.remove(unitList, i)
        end
    end
end

-- Remove dead buildings from a list
local function removeDeadBuildings(buildingList)
    for i = #buildingList, 1, -1 do
        local building = buildingList[i]
        if building.isDead and building:isDead() then
            -- Track stats for both sides
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            local buildingType = building.buildingType or "Building"
            if Game.Replay then
                Game.Replay.log("DESTROY", teamName .. " " .. buildingType .. " destroyed")
            end
            if building.team == playerTeam then
                gameStats.buildingsLost = gameStats.buildingsLost + 1
                gameStats.aiBuildingsDestroyed = gameStats.aiBuildingsDestroyed + 1
            else
                gameStats.buildingsDestroyed = gameStats.buildingsDestroyed + 1
                gameStats.aiBuildingsLost = gameStats.aiBuildingsLost + 1
            end
            -- Clear map area and update navGrid
            if building.gridX and building.gridSize and map then
                -- Mark building area as walkable in navGrid
                M.Pathfinding.markBuilding(building, true)
            end
            table.remove(buildingList, i)
        end
    end
end

-- Check victory/defeat conditions
local function checkVictoryConditions()
    local enemyTeam = M.Teams and M.Teams.ENEMY or 2
    local playerTeam = M.Teams and M.Teams.PLAYER or 1

    -- Check if all enemy buildings are destroyed
    local enemyBuildingsLeft = 0
    for _, b in ipairs(townHalls) do
        if b.team == enemyTeam and (not b.isDead or not b:isDead()) then
            enemyBuildingsLeft = enemyBuildingsLeft + 1
        end
    end
    for _, b in ipairs(barracks) do
        if b.team == enemyTeam and (not b.isDead or not b:isDead()) then
            enemyBuildingsLeft = enemyBuildingsLeft + 1
        end
    end
    for _, b in ipairs(farms) do
        if b.team == enemyTeam and (not b.isDead or not b:isDead()) then
            enemyBuildingsLeft = enemyBuildingsLeft + 1
        end
    end
    -- Add other building types as needed

    if enemyBuildingsLeft == 0 then
        victory = true
        if Game.Replay then Game.Replay.log("GAME", "Victory!") Game.Replay.finish() end
        return
    end

    -- Check if player's main townhall is destroyed
    if townHall and townHall.isDead and townHall:isDead() then
        defeat = true
        if Game.Replay then Game.Replay.log("GAME", "Defeat") Game.Replay.finish() end
        return
    end
end

-- Setup callbacks for peons to check resources and send notifications
local function setupPeonCallbacks(peon)
    peon.onNotify = addNotification

    local playerTeam = M.Teams and M.Teams.PLAYER or 1
    local isPlayerUnit = (peon.team == nil or peon.team == playerTeam)

    if isPlayerUnit then
        -- Player peon callbacks
        peon.resourceCheck = function()
            local gold = resources.gold
            local lumber = resources.lumber
            local canAfford = gold >= peon.buildCostGold and lumber >= peon.buildCostLumber
            return canAfford, gold, lumber
        end
        peon.deductResources = function(costGold, costLumber)
            resources.gold = resources.gold - costGold
            resources.lumber = resources.lumber - costLumber
        end
        peon.addResources = function(gold, lumber)
            if gold > 0 then
                resources.gold = resources.gold + gold
                gameStats.goldCollected = gameStats.goldCollected + gold
            end
            if lumber > 0 then
                resources.lumber = resources.lumber + lumber
                gameStats.lumberCollected = gameStats.lumberCollected + lumber
            end
        end
    else
        -- AI peon callbacks
        peon.resourceCheck = function()
            if not enemyAI then return false, 0, 0 end
            local gold = enemyM.AI.gold
            local lumber = enemyM.AI.lumber
            local canAfford = gold >= peon.buildCostGold and lumber >= peon.buildCostLumber
            return canAfford, gold, lumber
        end
        peon.deductResources = function(costGold, costLumber)
            if enemyAI then
                enemyAI:spend(costGold, costLumber)
            end
        end
        peon.addResources = function(gold, lumber)
            if enemyAI then
                if gold > 0 then
                    enemyAI:addGold(gold)
                    gameStats.aiGoldCollected = gameStats.aiGoldCollected + gold
                end
                if lumber > 0 then
                    enemyAI:addLumber(lumber)
                    gameStats.aiLumberCollected = gameStats.aiLumberCollected + lumber
                end
            end
        end
    end
end

-- Tutorial mode settings
local tutorialMode = false
local tutorialOptions = {}
local gameOptions = {}  -- Store game config options

function Gameplay.load(options)
    options = options or {}
    tutorialMode = options.tutorialMode or false
    tutorialOptions = options
    gameOptions = options  -- Store for later use

    local screenW, screenH = love.graphics.getDimensions()

    -- Hide system cursor and use custom
    love.mouse.setVisible(false)
    input.cursorState = "normal"
    input.cursorChargeProgress = 0

    -- Initialize visual effects system
    if Effects then M.Effects.init() end

    -- Initialize audio system
    if Audio and M.Audio.init then M.Audio.init() end
    if Audio and M.Audio.playRandomMusic then M.Audio.playRandomMusic() end

    -- Initialize music player UI
    if M.MusicPlayer then M.MusicPlayer.init(screenW, screenH) end

    -- Initialize replay logger for new game
    if Game.Replay then
        Game.Replay.reset()
        -- Log CONFIG first (at very top of replay)
        Game.Replay.log("CONFIG", string.format("Map size: %d, Tileset: %s",
            options.mapSize or 64, options.tileset or "summer"))
        Game.Replay.log("CONFIG", string.format("Tree density: %.0f%%, River: %s",
            (options.treeDensity or 0.50) * 100,
            (options.riverEnabled ~= false) and "yes" or "no"))
        if options.enemies and #options.enemies > 0 then
            Game.Replay.log("CONFIG", string.format("AI: %s", options.enemies[1].personality or "blinky"))
        end
        Game.Replay.log("CONFIG", string.format("Starting resources: %d gold, %d lumber", 2000, 400))
        -- Then log game start
        Game.Replay.log("GAME", "New game started" .. (tutorialMode and " (Tutorial)" or ""))
    end

    -- Pathfinding computed on-demand, no need to invalidate

    elapsedTime = 0
    victory = false
    defeat = false
    endScreenButton = nil

    -- Initialize surrender dialog
    M.Surrender.init(function()
        defeat = true
    end)

    resources.gold = 2000
    resources.lumber = 400
    notifications = {}
    peons = {}
    footmen = {}
    farms = {}
    barracks = {}
    goldMines = {}

    -- Reset game stats
    gameStats.unitsKilled = 0
    gameStats.unitsLost = 0
    gameStats.buildingsDestroyed = 0
    gameStats.buildingsLost = 0
    gameStats.goldCollected = 0
    gameStats.lumberCollected = 0
    gameStats.peonsProduced = 0
    gameStats.footmenProduced = 0
    gameStats.buildingTimeline = {}
    gameStats.aiUnitsKilled = 0
    gameStats.aiUnitsLost = 0
    gameStats.aiBuildingsDestroyed = 0
    gameStats.aiBuildingsLost = 0
    gameStats.aiGoldCollected = 0
    gameStats.aiLumberCollected = 0
    gameStats.aiPeonsProduced = 0
    gameStats.aiFootmenProduced = 0

    -- Clear new building tables
    lumberMills = {}
    blacksmiths = {}
    scoutTowers = {}
    archeryRanges = {}
    stables = {}
    siegeWorkshops = {}
    townHalls = {}

    -- Reset AI
    enemyAI = nil
    enemyTownHall = nil

    -- Clear new unit tables
    archers = {}
    knights = {}
    flyingScouts = {}
    ballistas = {}
    kamikazes = {}

    selectedEntities = {}
    buildingPlacement = M.BuildingPlacement.new()
    isBoxSelecting = false
    input.isMapDragging = false

    -- Create map with options from game config
    local mapOptions = {
        mapSize = options.mapSize or 64,
        tileset = options.tileset or "summer",
        treeDensity = options.treeDensity or 0.50,
        riverEnabled = options.riverEnabled ~= false,  -- Default true
        numBridges = options.numBridges or 2,
        riverWidth = options.riverWidth or 3
    }
    map = M.Map.new(mapOptions)
    map:setViewport(0, UI.topBarHeight, screenW, screenH - UI.topBarHeight - 70)  -- 70 = command bar height

    -- Set up callback for tree depletion (updates navGrid)
    map.onTreeDepleted = function(gridX, gridY)
        M.Pathfinding.markTile(gridX, gridY, true)  -- Mark depleted tree as walkable
    end

    -- Human player team
    local playerTeam = M.Teams and M.Teams.PLAYER or 1
    local enemyTeam = M.Teams and M.Teams.ENEMY or 2

    local buildingSize = 3
    local mapSize = options.mapSize or 64
    
    -- Minimum distance from map edge (10% of map size, at least 5 tiles)
    local edgeBuffer = math.max(5, math.floor(mapSize * 0.10))
    -- Minimum gap between townhall and mine edges (in tiles)
    local minTownHallMineGap = 3
    
    -- Helper to calculate edge-to-edge gap between two buildings
    local function getEdgeGap(x1, y1, size1, x2, y2, size2)
        local gapX = math.max(x2 - (x1 + size1), x1 - (x2 + size2))
        local gapY = math.max(y2 - (y1 + size1), y1 - (y2 + size2))
        -- If buildings overlap in one axis, gap in that axis is negative
        -- Return the minimum gap (most constrained direction)
        if gapX < 0 and gapY < 0 then
            return math.max(gapX, gapY)  -- Both overlapping, return least negative
        elseif gapX < 0 then
            return gapY  -- Overlapping in X, so Y gap matters
        elseif gapY < 0 then
            return gapX  -- Overlapping in Y, so X gap matters
        else
            return math.min(gapX, gapY)  -- Neither overlapping, return smallest gap
        end
    end

    -- === PLAYER BASE (bottom-left area) ===
    -- Scale starting position based on map size, respecting edge buffer
    local playerStartX = math.max(edgeBuffer, math.floor(mapSize * 0.15))
    local playerStartY = math.min(mapSize - edgeBuffer - buildingSize, math.floor(mapSize * 0.7))
    local thGridX, thGridY = map:findClearArea(buildingSize, buildingSize, playerStartX, playerStartY, 15)

    -- Fallback if no clear area found - force clear the preferred location
    if not thGridX then
        thGridX, thGridY = playerStartX, playerStartY
        map:clearArea(thGridX, thGridY, buildingSize + 2, buildingSize + 2)
    end

    -- Clamp townhall position to respect edge buffer
    thGridX = math.max(edgeBuffer, math.min(mapSize - edgeBuffer - buildingSize, thGridX))
    thGridY = math.max(edgeBuffer, math.min(mapSize - edgeBuffer - buildingSize, thGridY))
    
    townHall = M.TownHall.new({gridX = thGridX, gridY = thGridY, map = map, team = playerTeam})

    -- Clear trees around town hall (5 tile radius for peons and nearby buildings)
    local clearRadius = 5
    map:clearArea(thGridX - clearRadius, thGridY - clearRadius,
                  buildingSize + clearRadius * 2, buildingSize + clearRadius * 2)

    -- Gold mine near player (to the right of town hall)
    -- Place mine far enough away that even with search radius it can't get too close
    local mineOffsetX = buildingSize + minTownHallMineGap + 4  -- Extra buffer for search
    local mineSearchRadius = 3  -- Small radius so it can't come back too close
    local mineSearchX = thGridX + mineOffsetX
    local mineSearchY = thGridY
    local m1X, m1Y = map:findClearArea(buildingSize, buildingSize, mineSearchX, mineSearchY, mineSearchRadius)
    
    -- Verify mine placement - if still too close or nil, try further out
    if not m1X or getEdgeGap(thGridX, thGridY, buildingSize, m1X, m1Y, buildingSize) < minTownHallMineGap then
        m1X, m1Y = map:findClearArea(buildingSize, buildingSize, thGridX + mineOffsetX + 5, thGridY, mineSearchRadius)
    end
    
    -- Final fallback - just place it at a fixed position if all else fails
    if not m1X or getEdgeGap(thGridX, thGridY, buildingSize, m1X, m1Y, buildingSize) < minTownHallMineGap then
        m1X = thGridX + buildingSize + minTownHallMineGap + 2
        m1Y = thGridY
        map:clearArea(m1X, m1Y, buildingSize, buildingSize)
    end
    
    table.insert(goldMines, M.GoldMine.new({gridX = m1X, gridY = m1Y, gold = 50000, map = map}))

    -- Player starting farms (2 already built) - place on opposite side from mine (left of town hall)
    local farmX, farmY = map:findClearArea(2, 2, thGridX - 4, thGridY, 8)
    if farmX then
        local startFarm = M.Farm.new({gridX = farmX, gridY = farmY, map = map, isBuilding = false, team = playerTeam})
        startFarm.completed = true
        table.insert(farms, startFarm)
    end

    -- Second starting farm (also on left side)
    local farm2X, farm2Y = map:findClearArea(2, 2, thGridX - 4, thGridY + 3, 8)
    if farm2X then
        local startFarm2 = M.Farm.new({gridX = farm2X, gridY = farm2Y, map = map, isBuilding = false, team = playerTeam})
        startFarm2.completed = true
        table.insert(farms, startFarm2)
    end

    -- Player starting peons - 7 total, 6 on gold, 1 on lumber (every 7th)
    local spawnX, spawnY = townHall:getSpawnPos()
    for i = 1, 7 do
        local newPeon = M.Peon.new({
            worldX = spawnX + ((i - 1) % 4) * 35,
            worldY = spawnY + math.floor((i - 1) / 4) * 30,
            map = map,
            team = playerTeam
        })
        setupPeonCallbacks(newPeon)
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)

        -- 7th peon goes to lumber
        if i == 7 then
            -- Find a nearby tree
            local treeX, treeY = nil, nil
            local peonGridX = math.floor(newPeon.worldX / 32) + 1
            local peonGridY = math.floor(newPeon.worldY / 32) + 1
            for radius = 3, 15 do
                for dx = -radius, radius do
                    for dy = -radius, radius do
                        local checkX = peonGridX + dx
                        local checkY = peonGridY + dy
                        if map:isTileTree(checkX, checkY) then
                            treeX, treeY = checkX, checkY
                            break
                        end
                    end
                    if treeX then break end
                end
                if treeX then break end
            end
            if treeX then
                newPeon:goToTree(treeX, treeY)
            end
        else
            -- Send to closest mine
            local closestMine = findClosestMine(newPeon.worldX, newPeon.worldY)
            if closestMine then
                newPeon:goToMine(closestMine)
            end
        end
    end

    -- === ENEMY BASE (top-right area) ===
    -- Scale enemy position based on map size, respecting edge buffer
    local enemyStartX = math.min(mapSize - edgeBuffer - buildingSize, math.floor(mapSize * 0.8))
    local enemyStartY = math.max(edgeBuffer, math.floor(mapSize * 0.2))
    local enemyThGridX, enemyThGridY = map:findClearArea(buildingSize, buildingSize, enemyStartX, enemyStartY, 15)

    -- Fallback if no clear area found - force clear the preferred location
    if not enemyThGridX then
        enemyThGridX, enemyThGridY = enemyStartX, enemyStartY
        map:clearArea(enemyThGridX, enemyThGridY, buildingSize + 2, buildingSize + 2)
    end

    -- Clamp enemy townhall position to respect edge buffer
    enemyThGridX = math.max(edgeBuffer, math.min(mapSize - edgeBuffer - buildingSize, enemyThGridX))
    enemyThGridY = math.max(edgeBuffer, math.min(mapSize - edgeBuffer - buildingSize, enemyThGridY))
    
    enemyTownHall = M.TownHall.new({gridX = enemyThGridX, gridY = enemyThGridY, map = map, team = enemyTeam})
    table.insert(townHalls, enemyTownHall)  -- Store in additional townhalls list

    -- Clear trees around enemy town hall (5 tile radius for peons and nearby buildings)
    map:clearArea(enemyThGridX - clearRadius, enemyThGridY - clearRadius,
                  buildingSize + clearRadius * 2, buildingSize + clearRadius * 2)

    -- Gold mine near enemy (to the left of town hall)
    -- Place mine far enough away that even with search radius it can't get too close
    local enemyMineSearchX = enemyThGridX - mineOffsetX - buildingSize
    local enemyMineSearchY = enemyThGridY
    local m2X, m2Y = map:findClearArea(buildingSize, buildingSize, enemyMineSearchX, enemyMineSearchY, mineSearchRadius)
    
    -- Verify mine placement - if still too close or nil, try further out
    if not m2X or getEdgeGap(enemyThGridX, enemyThGridY, buildingSize, m2X, m2Y, buildingSize) < minTownHallMineGap then
        m2X, m2Y = map:findClearArea(buildingSize, buildingSize, enemyThGridX - mineOffsetX - 5 - buildingSize, enemyThGridY, mineSearchRadius)
    end
    
    -- Final fallback - just place it at a fixed position if all else fails
    if not m2X or getEdgeGap(enemyThGridX, enemyThGridY, buildingSize, m2X, m2Y, buildingSize) < minTownHallMineGap then
        m2X = enemyThGridX - buildingSize - minTownHallMineGap - 2 - buildingSize
        m2Y = enemyThGridY
        map:clearArea(m2X, m2Y, buildingSize, buildingSize)
    end
    
    table.insert(goldMines, M.GoldMine.new({gridX = m2X, gridY = m2Y, gold = 50000, map = map}))

    -- Center gold mine (contested) - scale to map center
    local centerX = math.floor(mapSize / 2)
    local centerY = math.floor(mapSize / 2)
    local m3X, m3Y = map:findClearArea(buildingSize, buildingSize, centerX, centerY, 15)
    table.insert(goldMines, M.GoldMine.new({gridX = m3X, gridY = m3Y, gold = 100000, map = map}))

    -- Additional gold mines for larger maps
    if mapSize >= 128 then
        -- Lower-right quadrant
        local m4X, m4Y = map:findClearArea(buildingSize, buildingSize, math.floor(mapSize * 0.7), math.floor(mapSize * 0.6), 12)
        if m4X then table.insert(goldMines, M.GoldMine.new({gridX = m4X, gridY = m4Y, gold = 75000, map = map})) end
        -- Upper-left quadrant
        local m5X, m5Y = map:findClearArea(buildingSize, buildingSize, math.floor(mapSize * 0.3), math.floor(mapSize * 0.4), 12)
        if m5X then table.insert(goldMines, M.GoldMine.new({gridX = m5X, gridY = m5Y, gold = 75000, map = map})) end
    end

    -- Enemy starting peons - 7 total, 6 on gold, 1 on lumber (every 7th)
    local enemySpawnX, enemySpawnY = enemyTownHall:getSpawnPos()
    for i = 1, 7 do
        local newPeon = M.Peon.new({
            worldX = enemySpawnX + ((i - 1) % 4) * 35,
            worldY = enemySpawnY + math.floor((i - 1) / 4) * 30,
            map = map,
            team = enemyTeam
        })
        -- Enemy peons need resource callbacks for AI economy
        setupPeonCallbacks(newPeon)
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)

        -- 7th peon goes to lumber
        if i == 7 then
            local treeX, treeY = nil, nil
            local peonGridX = math.floor(newPeon.worldX / 32) + 1
            local peonGridY = math.floor(newPeon.worldY / 32) + 1
            for radius = 3, 15 do
                for dx = -radius, radius do
                    for dy = -radius, radius do
                        local checkX = peonGridX + dx
                        local checkY = peonGridY + dy
                        if map:isTileTree(checkX, checkY) then
                            treeX, treeY = checkX, checkY
                            break
                        end
                    end
                    if treeX then break end
                end
                if treeX then break end
            end
            if treeX then
                newPeon:goToTree(treeX, treeY)
            end
        else
            -- Send to closest mine
            local closestMine = findClosestMine(newPeon.worldX, newPeon.worldY)
            if closestMine then
                newPeon:goToMine(closestMine)
            end
        end
    end

    -- Enemy starting farm (already built) - place on opposite side from mine (right of town hall)
    local enemyFarmX, enemyFarmY = map:findClearArea(2, 2, enemyThGridX + 4, enemyThGridY, 8)
    if enemyFarmX then
        local enemyFarm = M.Farm.new({gridX = enemyFarmX, gridY = enemyFarmY, map = map, isBuilding = false, team = enemyTeam})
        enemyFarm.completed = true
        table.insert(farms, enemyFarm)
    end

    -- Initialize AI controller
    if AI then
        -- Get AI personality from options (game config or tutorial)
        local aiPersonality = tutorialOptions.aiPersonality or "blinky"

        -- Check if we have enemies defined in game config
        if options.enemies and #options.enemies > 0 then
            aiPersonality = options.enemies[1].personality or "blinky"
        end

        enemyAI = M.AI.new({
            team = enemyTeam,
            townHall = enemyTownHall,
            map = map,
            startGold = 1000,
            startLumber = 400,
            startingPeons = 7,
            personality = aiPersonality
        })
    end

    -- Disable fog in tutorial mode
    if tutorialOptions.disableFog then
        map.fogEnabled = false
    end

    -- Initialize navigation grid for pathfinding (after all buildings are placed)
    M.Pathfinding.rebuildNavGrid(map, getAllBuildings())

    -- Set up gold mine depletion callbacks (to update navGrid when depleted)
    for _, mine in ipairs(goldMines) do
        mine.onDepleted = function(m)
            M.Pathfinding.markBuilding(m, true)  -- Mark depleted mine as walkable
        end
    end

    calculatePopulation()
    updateRequirementsState()

    -- Log starting units to replay
    if Game.Replay then
        -- Player base
        Game.Replay.log("SETUP", string.format("Player Town Hall at grid (%d, %d)", thGridX, thGridY))
        local playerPeonCount, playerFarmCount = 0, 0
        for _, peon in ipairs(peons) do
            if peon.team == playerTeam then playerPeonCount = playerPeonCount + 1 end
        end
        for _, farm in ipairs(farms) do
            if farm.team == playerTeam then playerFarmCount = playerFarmCount + 1 end
        end
        Game.Replay.log("SETUP", string.format("Player: %d Peons, %d Farms", playerPeonCount, playerFarmCount))

        -- Enemy base
        Game.Replay.log("SETUP", string.format("Enemy Town Hall at grid (%d, %d)", enemyThGridX, enemyThGridY))
        local enemyPeonCount, enemyFarmCount = 0, 0
        for _, peon in ipairs(peons) do
            if peon.team == enemyTeam then enemyPeonCount = enemyPeonCount + 1 end
        end
        for _, farm in ipairs(farms) do
            if farm.team == enemyTeam then enemyFarmCount = enemyFarmCount + 1 end
        end
        Game.Replay.log("SETUP", string.format("Enemy: %d Peons, %d Farms", enemyPeonCount, enemyFarmCount))

        -- Gold mines
        for i, mine in ipairs(goldMines) do
            Game.Replay.log("SETUP", string.format("Gold Mine %d at (%d, %d) with %d gold",
                i, mine.gridX or 0, mine.gridY or 0, mine.gold or 0))
        end
    end

    local thCenterX, thCenterY = townHall:getWorldCenter()
    map:centerOn(thCenterX, thCenterY)
end

function Gameplay.update(dt)
    -- Update surrender dialog (even during victory/defeat for animation)
    M.Surrender.update(dt)

    -- Pause game if surrender dialog is active
    if M.Surrender.isActive() then return end

    if victory or defeat then return end

    -- Update cursor state
    if input.isMapDragging then
        input.cursorState = "grabbing"
        input.cursorChargeProgress = 0
    elseif isBoxSelecting and love.mouse.isDown(1) then
        local mouseX, mouseY = love.mouse.getPosition()
        local mouseHeldTime = love.timer.getTime() - input.mouseDownTime
        local mouseMoved = math.abs(mouseX - input.mouseDownX) > input.dragMoveThreshold or
                          math.abs(mouseY - input.mouseDownY) > input.dragMoveThreshold

        if not mouseMoved and mouseHeldTime > 0 then
            -- Charging up to grab
            input.cursorChargeProgress = math.min(1, mouseHeldTime / input.dragHoldTime)
            input.cursorState = "charging"

            if mouseHeldTime >= input.dragHoldTime then
                input.isMapDragging = true
                isBoxSelecting = false
                input.cursorState = "grabbing"
            end
        else
            input.cursorState = "normal"
            input.cursorChargeProgress = 0
        end
    else
        input.cursorState = "normal"
        input.cursorChargeProgress = 0
    end

    -- Apply game speed multiplier
    local gameDt = dt * Game.settings.gameSpeed

    -- Update visual effects
    if Effects then M.Effects.update(gameDt) end
    if DrawUtils then M.DrawUtils.update(gameDt) end

    -- Update audio (check if music ended, play next)
    if Audio and M.Audio.update then M.Audio.update(gameDt) end

    -- Update music player UI
    local screenW, screenH = love.graphics.getDimensions()
    if M.MusicPlayer then M.MusicPlayer.update(gameDt, screenW, screenH) end

    -- Update replay logger
    if Game.Replay then Game.Replay.tick(gameDt) end

    elapsedTime = elapsedTime + gameDt

    -- Disable edge scroll when placing buildings, dragging map, or in UI
    local disableEdgeScroll = buildingPlacement:isActive() or input.isMapDragging or isBoxSelecting

    -- Also disable during tutorial selection steps
    if tutorialMode then
        local ok, Tutorial = pcall(require, "tutorial")
        if ok and Tutorial and Tutorial.shouldDisableEdgeScroll and Tutorial.shouldDisableEdgeScroll() then
            disableEdgeScroll = true
        end
    end

    map:update(dt, disableEdgeScroll)  -- Camera stays at real-time for responsiveness

    -- Update fog of war
    local playerTeam = M.Teams and M.Teams.PLAYER or 1
    local allUnits = getAllUnits()
    local allBuildings = getAllBuildings()
    map:updateFog(allUnits, allBuildings, playerTeam)

    -- Refresh quadtree once per frame for spatial queries
    refreshUnitQuadtree(allUnits)

    calculatePopulation()
    updateRequirementsState()

    -- Town hall
    local peonReady, upgradeComplete, _ = townHall:update(gameDt)
    if peonReady and currentPop < maxPop then
        local spawnX, spawnY = townHall:getSpawnPos()
        local newPeon = M.Peon.new({worldX = spawnX, worldY = spawnY, map = map, team = townHall.team})
        setupPeonCallbacks(newPeon)
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)
        -- Track production
        local playerTeam = M.Teams and M.Teams.PLAYER or 1
        local teamName = townHall.team == playerTeam and "Player" or "AI"
        if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Peon trained") end
        if townHall.team == playerTeam then
            gameStats.peonsProduced = gameStats.peonsProduced + 1
        else
            gameStats.aiPeonsProduced = gameStats.aiPeonsProduced + 1
        end
        -- Auto-send to closest mine
        local closestMine = findClosestMine(spawnX, spawnY)
        if closestMine then
            newPeon:goToMine(closestMine)
        end
        calculatePopulation()
    end

    -- Gold mines
    for _, mine in ipairs(goldMines) do mine:update(gameDt) end

    -- Farms
    for _, farm in ipairs(farms) do
        if farm:update(gameDt) and farm.builderPeon then
            local peon = farm.builderPeon
            peon:finishBuilding(farm)
            pushUnitOutOfBuildings(peon)
            farm.builderPeon = nil
            calculatePopulation()
            -- Log and track building completion
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = farm.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("BUILD", teamName .. " Farm completed") end
            table.insert(gameStats.buildingTimeline, {
                time = elapsedTime,
                type = "Farm",
                team = farm.team
            })
            -- Send AI peons back to mining
            local enemyTeam = M.Teams and M.Teams.ENEMY or 2
            if peon.team == enemyTeam then
                local closestMine = findClosestMine(peon.worldX, peon.worldY)
                if closestMine then
                    peon:goToMine(closestMine)
                end
            end
        end
    end

    -- Barracks
    for _, barrack in ipairs(barracks) do
        local unitType, buildComplete = barrack:update(gameDt)
        if buildComplete and barrack.builderPeon then
            local peon = barrack.builderPeon
            peon:finishBuilding(barrack)
            pushUnitOutOfBuildings(peon)
            barrack.builderPeon = nil
            -- Log and track building completion
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = barrack.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("BUILD", teamName .. " Barracks completed") end
            table.insert(gameStats.buildingTimeline, {
                time = elapsedTime,
                type = "Barracks",
                team = barrack.team
            })
            -- Send AI peons back to mining
            local enemyTeam = M.Teams and M.Teams.ENEMY or 2
            if peon.team == enemyTeam then
                local closestMine = findClosestMine(peon.worldX, peon.worldY)
                if closestMine then
                    peon:goToMine(closestMine)
                end
            end
        end
        if unitType and currentPop < maxPop then
            local spawnX, spawnY = barrack:getSpawnPos()
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = barrack.team == playerTeam and "Player" or "AI"
            if unitType == "footman" then
                local newUnit = M.Footman.new({worldX = spawnX, worldY = spawnY, map = map, team = barrack.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(footmen, newUnit)
                if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Footman trained") end
                -- Track production
                if barrack.team == playerTeam then
                    gameStats.footmenProduced = gameStats.footmenProduced + 1
                else
                    gameStats.aiFootmenProduced = gameStats.aiFootmenProduced + 1
                end
            elseif unitType == "knight" then
                local newUnit = M.Knight.new({worldX = spawnX, worldY = spawnY, map = map, team = barrack.team})
                -- Check if Paladin upgrade is active
                for _, stable in ipairs(stables) do
                    if stable.completed and stable.hasPaladinUpgrade then
                        newUnit:upgradeToPaladin()
                        break
                    end
                end
                pushUnitOutOfBuildings(newUnit)
                table.insert(knights, newUnit)
                if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Knight trained") end
            elseif unitType == "archer" then
                local newUnit = M.Archer.new({worldX = spawnX, worldY = spawnY, map = map, team = barrack.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(archers, newUnit)
                if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Archer trained") end
            elseif unitType == "ballista" then
                local newUnit = M.Ballista.new({worldX = spawnX, worldY = spawnY, map = map, team = barrack.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(ballistas, newUnit)
                if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Ballista trained") end
            end
            calculatePopulation()
        end
    end

    -- Lumber Mills
    for _, building in ipairs(lumberMills) do
        if building:update(gameDt) and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("BUILD", teamName .. " Lumber Mill completed") end
        end
    end

    -- Blacksmiths
    for _, building in ipairs(blacksmiths) do
        if building:update(gameDt) and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("BUILD", teamName .. " Blacksmith completed") end
        end
    end

    -- Scout Towers
    for _, building in ipairs(scoutTowers) do
        if building:update(gameDt) and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("BUILD", teamName .. " Scout Tower completed") end
        end
    end

    -- Archery Ranges
    for _, building in ipairs(archeryRanges) do
        local archerReady, buildComplete = building:update(gameDt)
        if buildComplete and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("BUILD", teamName .. " Archery Range completed") end
        end
        if archerReady and currentPop < maxPop then
            local spawnX, spawnY = building:getSpawnPos()
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            local newUnit = M.Archer.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
            pushUnitOutOfBuildings(newUnit)
            table.insert(archers, newUnit)
            if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Archer trained") end
            calculatePopulation()
        end
    end

    -- Stables
    for _, building in ipairs(stables) do
        if building:update(gameDt) and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("BUILD", teamName .. " Stable completed") end
        end
    end

    -- Siege Workshops
    for _, building in ipairs(siegeWorkshops) do
        local unitType, buildComplete = building:update(gameDt)
        if buildComplete and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("BUILD", teamName .. " Siege Workshop completed") end
        end
        if unitType and currentPop < maxPop then
            local spawnX, spawnY = building:getSpawnPos()
            local playerTeam = M.Teams and M.Teams.PLAYER or 1
            local teamName = building.team == playerTeam and "Player" or "AI"
            if unitType == "flyingscout" then
                local newUnit = M.FlyingScout.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(flyingScouts, newUnit)
                if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Flying Scout trained") end
            elseif unitType == "ballista" then
                local newUnit = M.Ballista.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(ballistas, newUnit)
                if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Ballista trained") end
            elseif unitType == "kamikaze" then
                local newUnit = M.Kamikaze.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(kamikazes, newUnit)
                if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Kamikaze trained") end
            end
            calculatePopulation()
        end
    end

    -- Additional Town Halls (includes enemy townhall)
    for _, building in ipairs(townHalls) do
        local peonReady, upgradeComplete, buildComplete = building:update(gameDt)
        if buildComplete and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
        end

        -- Handle peon spawning - check against appropriate team's population
        local canSpawn = false
        local playerTeam = M.Teams and M.Teams.PLAYER or 1
        local enemyTeam = M.Teams and M.Teams.ENEMY or 2

        if building.team == playerTeam then
            canSpawn = peonReady and currentPop < maxPop
        elseif building.team == enemyTeam and enemyAI then
            -- AI handles its own population check
            local aiPop = #enemyM.AI.peons + #enemyM.AI.footmen
            local aiMaxPop = 4 + #enemyM.AI.farms * 4
            canSpawn = peonReady and aiPop < aiMaxPop
        end

        if canSpawn then
            local spawnX, spawnY = building:getSpawnPos()
            local newPeon = M.Peon.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
            setupPeonCallbacks(newPeon)
            pushUnitOutOfBuildings(newPeon)
            table.insert(peons, newPeon)
            local teamName = building.team == playerTeam and "Player" or "AI"
            if Game.Replay then Game.Replay.log("SPAWN", teamName .. " Peon trained") end

            -- Auto-send to mine or lumber based on team
            if building.team == enemyTeam and enemyAI then
                enemyAI:onPeonSpawned(newPeon, goldMines)
            else
                -- Player peons go to closest mine
                local closestMine = findClosestMine(spawnX, spawnY)
                if closestMine then
                    newPeon:goToMine(closestMine)
                end
            end

            calculatePopulation()
        end
    end

    -- Update AI
    if enemyAI then
        enemyAI:update(gameDt, goldMines, townHall, aiCreateBuilding, peons, footmen, farms, barracks)
    end

    -- Refresh requirements state after all building updates
    -- (ensures UI sees completed buildings on the same frame they finish)
    updateRequirementsState()

    -- Get all units and buildings for combat
    local allUnits = getAllUnits()
    local allBuildings = getAllBuildings()

    -- Peons - each peon uses their team's townhall for returning resources
    local playerTeam = M.Teams and M.Teams.PLAYER or 1
    for _, peon in ipairs(peons) do
        -- Set quadtree reference for O(log n) unit separation lookups
        peon.unitQuadtreeRef = unitQuadtree
        local peonTownHall = townHall  -- Default to player's townhall
        if peon.team ~= playerTeam and enemyTownHall then
            peonTownHall = enemyTownHall
        end
        peon:update(gameDt, buildings, peonTownHall, goldMines[1], resources, allUnits, allBuildings)
    end

    -- Footmen
    for _, footman in ipairs(footmen) do
        footman:update(gameDt, buildings, unitQuadtree, allUnits, allBuildings)
    end

    -- Archers
    for _, archer in ipairs(archers) do
        archer:update(gameDt, buildings, unitQuadtree, allUnits, allBuildings)
    end

    -- Knights
    for _, knight in ipairs(knights) do
        knight:update(gameDt, buildings, unitQuadtree, allUnits, allBuildings)
    end

    -- Flying Scouts
    for _, unit in ipairs(flyingScouts) do
        unit:update(gameDt, buildings, unitQuadtree, allUnits, allBuildings)
    end

    -- Ballistas
    for _, unit in ipairs(ballistas) do
        unit:update(gameDt, buildings, unitQuadtree, allUnits, allBuildings)
    end

    -- Kamikazes
    for _, unit in ipairs(kamikazes) do
        unit:update(gameDt, buildings, unitQuadtree, allUnits, allBuildings)
    end

    -- Remove dead units
    removeDeadUnits(peons)
    removeDeadUnits(footmen)
    removeDeadUnits(archers)
    removeDeadUnits(knights)
    removeDeadUnits(flyingScouts)
    removeDeadUnits(ballistas)
    removeDeadUnits(kamikazes)

    -- Remove dead buildings
    removeDeadBuildings(townHalls)
    removeDeadBuildings(barracks)
    removeDeadBuildings(farms)
    removeDeadBuildings(lumberMills)
    removeDeadBuildings(blacksmiths)
    removeDeadBuildings(scoutTowers)
    removeDeadBuildings(archeryRanges)
    removeDeadBuildings(stables)
    removeDeadBuildings(siegeWorkshops)

    -- Check victory/defeat conditions
    checkVictoryConditions()

    -- Separate overlapping units (returns fresh lists after dead removal)
    local allUnits, allBuildings = separateUnits()

    -- Ensure no units are inside buildings (safety check)
    for _, unit in ipairs(allUnits) do
        pushUnitOutOfBuildings(unit)
    end

    -- Update selected entity UI
    local screenW, screenH = love.graphics.getDimensions()
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.updateUI then
        if selEntity.type == "peon" then
            selEntity:updateUI(resources, screenW, screenH, Game.fonts.small, startBuildingPlacement)
        elseif selEntity.type == "townhall" or selEntity.type == "barracks" or selEntity.type == "archeryrange" or selEntity.type == "siegeworkshop" then
            selEntity:updateUI(resources, screenW, screenH, Game.fonts.small, currentPop, maxPop)
        else
            selEntity:updateUI(resources, screenW, screenH, Game.fonts.small)
        end
    end

    -- Update notifications
    for i = #notifications, 1, -1 do
        local notif = notifications[i]
        notif.timer = notif.timer - gameDt

        -- Slide in animation
        if notif.slideProgress < 1 then
            notif.slideProgress = math.min(1, notif.slideProgress + gameDt / NOTIFICATION_SLIDE_TIME)
        end

        -- Animate slot position
        notif.currentSlot = notif.currentSlot or notif.targetSlot
        notif.currentSlot = notif.currentSlot + (notif.targetSlot - notif.currentSlot) * math.min(1, gameDt * 8)

        if notif.timer <= 0 then
            table.remove(notifications, i)
        end
    end

    if checkAllMinesDepleted() then
        victory = true
        Game.finalTime = elapsedTime
        if Game.Replay then Game.Replay.log("GAME", "Victory - All mines depleted!") Game.Replay.finish() end
    end
end

function Gameplay.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Background color (dark stone)
    love.graphics.setColor(UI.stoneDark)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setScissor(map.viewportX, map.viewportY, map.viewportW, map.viewportH)

    local playerTeam = M.Teams and M.Teams.PLAYER or 1

    -- Helper to check if entity is visible based on fog
    local function isEntityVisible(entity, requireVisible)
        if not map.fogEnabled then return true end

        -- Player entities always visible
        if entity.team == playerTeam then return true end

        -- Get entity grid position
        local wx, wy
        if entity.getWorldCenter then
            wx, wy = entity:getWorldCenter()
        else
            wx, wy = entity.worldX, entity.worldY
        end
        local gx, gy = map:worldToGrid(wx, wy)

        if requireVisible then
            return map:isTileVisible(gx, gy)
        else
            return map:isTileExplored(gx, gy)
        end
    end

    -- =========================================================================
    -- ROW-BY-ROW ISOMETRIC RENDERING
    -- Draw from top to bottom, deferring buildings to their bottom row
    -- Order per row: ground/trees -> buildings -> units
    -- =========================================================================

    -- Build lookup tables for buildings by their bottom row
    local buildingsByBottomY = {}

    local function registerBuilding(building)
        if not isEntityVisible(building, false) then return end
        local bottomY = building.gridY + (building.gridSize or 1) - 1
        if not buildingsByBottomY[bottomY] then
            buildingsByBottomY[bottomY] = {}
        end
        table.insert(buildingsByBottomY[bottomY], building)
    end

    -- Register all buildings
    for _, farm in ipairs(farms) do registerBuilding(farm) end
    for _, barrack in ipairs(barracks) do registerBuilding(barrack) end
    for _, building in ipairs(lumberMills) do registerBuilding(building) end
    for _, building in ipairs(blacksmiths) do registerBuilding(building) end
    for _, building in ipairs(scoutTowers) do registerBuilding(building) end
    for _, building in ipairs(archeryRanges) do registerBuilding(building) end
    for _, building in ipairs(stables) do registerBuilding(building) end
    for _, building in ipairs(siegeWorkshops) do registerBuilding(building) end
    for _, building in ipairs(townHalls) do registerBuilding(building) end
    registerBuilding(townHall)  -- Player's main town hall
    for _, mine in ipairs(goldMines) do registerBuilding(mine) end

    -- Build lookup for units by their grid Y (floored from world position)
    local unitsByY = {}

    local function registerUnit(unit)
        if not isEntityVisible(unit, true) then return end
        local gridY = math.floor((unit.worldY or 0) / 32) + 1
        if not unitsByY[gridY] then
            unitsByY[gridY] = {}
        end
        table.insert(unitsByY[gridY], unit)
    end

    -- Register all units
    for _, peon in ipairs(peons) do registerUnit(peon) end
    for _, footman in ipairs(footmen) do registerUnit(footman) end
    for _, archer in ipairs(archers) do registerUnit(archer) end
    for _, knight in ipairs(knights) do registerUnit(knight) end
    for _, unit in ipairs(flyingScouts) do registerUnit(unit) end
    for _, unit in ipairs(ballistas) do registerUnit(unit) end
    for _, unit in ipairs(kamikazes) do registerUnit(unit) end

    -- Sort units within each row by X for consistent ordering
    for y, units in pairs(unitsByY) do
        table.sort(units, function(a, b)
            return (a.worldX or 0) < (b.worldX or 0)
        end)
    end

    -- Sort buildings within each row by X (by gridX)
    for y, buildings in pairs(buildingsByBottomY) do
        table.sort(buildings, function(a, b)
            return a.gridX < b.gridX
        end)
    end

    -- Check if map supports row-by-row rendering
    if map.drawRow then
        -- Row-by-row rendering with proper depth
        for y = 1, map.gridHeight do
            -- Draw ground and trees for this row
            map:drawRow(y)

            -- Draw buildings whose bottom edge is at this Y
            if buildingsByBottomY[y] then
                for _, building in ipairs(buildingsByBottomY[y]) do
                    building:draw()
                end
            end

            -- Draw units at this Y
            if unitsByY[y] then
                for _, unit in ipairs(unitsByY[y]) do
                    unit:draw()
                end
            end
        end
    else
        -- Fallback: draw map first, then buildings/units sorted by bottom Y
        map:draw()

        -- Collect and sort all buildings by bottom Y, then X
        local sortedBuildings = {}
        for bottomY, buildings in pairs(buildingsByBottomY) do
            for _, building in ipairs(buildings) do
                table.insert(sortedBuildings, {building = building, bottomY = bottomY})
            end
        end
        table.sort(sortedBuildings, function(a, b)
            if a.bottomY ~= b.bottomY then
                return a.bottomY < b.bottomY
            end
            return a.building.gridX < b.building.gridX
        end)

        -- Draw buildings in sorted order
        for _, entry in ipairs(sortedBuildings) do
            entry.building:draw()
        end

        -- Collect and sort all units by Y, then X
        local sortedUnits = {}
        for gridY, units in pairs(unitsByY) do
            for _, unit in ipairs(units) do
                table.insert(sortedUnits, {unit = unit, gridY = gridY})
            end
        end
        table.sort(sortedUnits, function(a, b)
            if a.gridY ~= b.gridY then
                return a.gridY < b.gridY
            end
            return (a.unit.worldX or 0) < (b.unit.worldX or 0)
        end)

        -- Draw units in sorted order
        for _, entry in ipairs(sortedUnits) do
            entry.unit:draw()
        end
    end

    -- Draw particle effects (dust, sparks, etc)
    if Effects then M.Effects.draw(map) end

    buildingPlacement:update(map, goldMines, getAllBuildings())
    buildingPlacement:draw(map, Game.fonts)
    drawBoxSelection()

    love.graphics.setScissor()

    -- Draw new UI elements
    drawTopBar(screenW)
    drawMinimap(screenW)
    drawCommandBar(screenW, screenH)

    -- Draw music player (on top of top bar, but under dialogs)
    if M.MusicPlayer then M.MusicPlayer.draw(screenW, screenH, Game.fonts) end

    -- Draw selected entity's UI (buttons, etc.)
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.drawUI then
        selEntity:drawUI()
    end

    -- Draw notifications (slide in from left, stack up)
    love.graphics.setFont(Game.fonts.medium)
    local notifBaseY = screenH - 100  -- Above command bar

    for i, notif in ipairs(notifications) do
        local slot = notif.currentSlot or notif.targetSlot
        local y = notifBaseY - (slot - 1) * (NOTIFICATION_HEIGHT + NOTIFICATION_SPACING)

        -- Fade out near end
        local fadeAlpha = 1
        if notif.timer < 0.5 then
            fadeAlpha = notif.timer / 0.5
        end

        -- Slide in from left
        local slideEase = 1 - (1 - notif.slideProgress) * (1 - notif.slideProgress)  -- Ease out
        local textW = Game.fonts.medium:getWidth(notif.text)
        local boxW = textW + 30
        local offscreenX = -boxW - 20
        local onscreenX = 20
        local x = offscreenX + (onscreenX - offscreenX) * slideEase

        -- Stone-themed notification background
        love.graphics.setColor(UI.stoneDark[1], UI.stoneDark[2], UI.stoneDark[3], fadeAlpha * 0.95)
        love.graphics.rectangle("fill", x, y, boxW, NOTIFICATION_HEIGHT, 4)

        -- Border
        love.graphics.setColor(UI.metalBronze[1], UI.metalBronze[2], UI.metalBronze[3], fadeAlpha * 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, boxW, NOTIFICATION_HEIGHT, 4)

        -- Highlight on top edge
        love.graphics.setColor(UI.stoneHighlight[1], UI.stoneHighlight[2], UI.stoneHighlight[3], fadeAlpha * 0.3)
        love.graphics.line(x + 4, y + 1, x + boxW - 4, y + 1)

        -- Text with shadow
        love.graphics.setColor(0, 0, 0, fadeAlpha * 0.5)
        love.graphics.print(notif.text, x + 16, y + 9)
        love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], fadeAlpha)
        love.graphics.print(notif.text, x + 15, y + 8)
    end

    if victory and not tutorialMode then drawVictoryScreen() end
    if defeat and not tutorialMode then drawDefeatScreen() end

    -- Draw surrender dialog (on top of game, but under cursor)
    M.Surrender.draw()

    -- Draw custom cursor (always on top)
    drawCursor()

    love.graphics.setColor(1, 1, 1, 1)
end

function Gameplay.keypressed(key)
    if (victory or defeat) and not tutorialMode then
        if key == "space" or key == "return" then
            Game.SceneManager.switch("title")
        end
        return
    end

    if key == "escape" then
        -- Check if surrender dialog is active first
        if M.Surrender.isActive() then
            M.Surrender.keypressed(key)
            return
        end

        if buildingPlacement:keypressed(key) then
            -- Building placement handled escape
        elseif input.attackMoveMode then
            input.attackMoveMode = false
        elseif #selectedEntities > 0 then
            -- Something selected, deselect it
            clearSelection()
        else
            -- Nothing selected, show surrender dialog
            M.Surrender.show()
        end
    end

    -- Check command button hotkeys
    local upperKey = string.upper(key)
    for _, btn in ipairs(commandButtons) do
        if btn.hotkey == upperKey then
            if btn.enabled and btn.action then
                btn.action()
            else
                -- Button disabled (supply limit, insufficient resources, etc.)
                if M.Audio and M.Audio.playAlert then M.Audio.playAlert() end
            end
            return
        end
    end

    -- Stop command (S) - works for all units even when not in command buttons
    if key == "s" then
        for _, entity in ipairs(selectedEntities) do
            -- Only issue commands to player-owned units
            if isPlayerOwned(entity) then
                if entity.stop then
                    entity:stop()
                elseif entity.state then
                    entity.state = "Idle"
                    if entity.path then entity.path = nil end
                    if entity.attackTarget then entity.attackTarget = nil end
                end
            end
        end
    end

    -- Game speed controls
    if key == "1" then
        Game.settings.gameSpeed = 0.5
        addNotification("Game Speed: Slow (0.5x)")
    elseif key == "2" then
        Game.settings.gameSpeed = 1.0
        addNotification("Game Speed: Normal (1x)")
    elseif key == "3" then
        Game.settings.gameSpeed = 2.0
        addNotification("Game Speed: Fast (2x)")
    elseif key == "v" then
        -- V = Toggle fog of war visibility (for testing)
        map.fogEnabled = not map.fogEnabled
        addNotification("Fog of War: " .. (map.fogEnabled and "ON" or "OFF"))
    end
end

function Gameplay.mousepressed(x, y, button)
    -- Forward to music player first (top-most UI element)
    if M.MusicPlayer and M.MusicPlayer.mousepressed(x, y, button) then return end

    -- Forward to surrender dialog first
    if M.Surrender.mousepressed(x, y, button) then return end

    if victory or defeat then return end

    -- Debug checkbox click
    if button == 1 then
        local cb = debugCheckboxRect
        if x >= cb.x and x <= cb.x + cb.w and y >= cb.y and y <= cb.y + cb.h then
            debugMode = not debugMode
            if debugMode then
                resources.gold = 100000
                resources.lumber = 100000
                addNotification("DEBUG MODE: 100k Gold & Lumber")
            else
                addNotification("Debug mode disabled")
            end
            return
        end
    end

    -- Building placement
    if buildingPlacement:isActive() then
        local handled, peon, buildingType, gridX, gridY = buildingPlacement:mousepressed(x, y, button, map)
        if handled and peon then
            -- Placement confirmed - send peon to build
            local costGold, costLumber = getBuildingCost(buildingType)
            peon:goToBuild(gridX, gridY, buildingType, createBuilding, costGold, costLumber)
        end
        if handled then return end
    end

    -- Entity UI clicks
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.mousepressed then selEntity:mousepressed(x, y, button) end

    -- Minimap
    if button == 1 and map:minimapClick(x, y) then return end

    if not map:isInViewport(x, y) then return end

    -- Attack-move mode handling
    if button == 1 and input.attackMoveMode then
        input.attackMoveMode = false
        local worldX, worldY = map:screenToWorld(x, y)
        local playerTeam = M.Teams and M.Teams.PLAYER or 1

        -- Check if clicked on an enemy - attack it directly
        local clickedEnemy = nil
        local allUnits = getAllUnits()
        for _, unit in ipairs(allUnits) do
            if unit.team and unit.team ~= playerTeam and unit:containsPoint(x, y) then
                clickedEnemy = unit
                break
            end
        end

        -- Check enemy buildings
        if not clickedEnemy then
            for _, building in ipairs(townHalls) do
                if building.team and building.team ~= playerTeam and building:containsPoint(x, y) then
                    clickedEnemy = building
                    break
                end
            end
        end
        if not clickedEnemy then
            for _, building in ipairs(barracks) do
                if building.team and building.team ~= playerTeam and building:containsPoint(x, y) then
                    clickedEnemy = building
                    break
                end
            end
        end
        if not clickedEnemy then
            for _, building in ipairs(farms) do
                if building.team and building.team ~= playerTeam and building:containsPoint(x, y) then
                    clickedEnemy = building
                    break
                end
            end
        end

        -- Issue attack-move command to all selected units
        -- For peons, attack-move on resources means gather/chop
        local clickedMine = nil
        local clickedTreeX, clickedTreeY = nil, nil

        -- Check if clicked on a gold mine
        for _, mine in ipairs(goldMines) do
            if mine:containsPoint(x, y) and not mine:isDepleted() then
                clickedMine = mine
                break
            end
        end

        -- Check if clicked on a tree (only if not on a mine)
        if not clickedMine and map then
            local gridX, gridY = map:screenToGrid(x, y)
            if map:isTileTree(gridX, gridY) then
                clickedTreeX, clickedTreeY = gridX, gridY
            end
        end

        for _, entity in ipairs(selectedEntities) do
            -- Only issue commands to player-owned units
            if not isPlayerOwned(entity) then
                -- Skip enemy units - can't command them
            -- Special handling for peons - attack-move = gather-move
            elseif entity.type == "peon" then
                if clickedMine then
                    -- Peon attack-move on gold mine = go directly to that mine
                    entity:goToMine(clickedMine)
                elseif clickedTreeX and clickedTreeY then
                    -- Peon attack-move on tree = go directly to that tree
                    entity:goToTree(clickedTreeX, clickedTreeY)
                elseif clickedEnemy and entity.setAttackTarget then
                    -- Attack an enemy
                    entity:setAttackTarget(clickedEnemy)
                else
                    -- Gather-move: move toward location, auto-gather nearby resources
                    entity:gatherMoveTo(worldX, worldY, goldMines, resources)
                end
            elseif clickedEnemy and entity.setAttackTarget then
                -- Direct attack on clicked enemy
                entity:setAttackTarget(clickedEnemy)
            elseif entity.attackMoveTo then
                -- Attack-move to location
                entity:attackMoveTo(worldX, worldY)
            elseif entity.moveTo then
                -- Fallback to regular move
                entity:moveTo(worldX, worldY)
            end
        end
        return
    end

    if button == 1 then
        isBoxSelecting = true
        input.isMapDragging = false
        input.mouseDownTime = love.timer.getTime()
        input.mouseDownX, input.mouseDownY = x, y
        boxStartX, boxStartY = x, y
        boxEndX, boxEndY = x, y
    elseif button == 2 then
        handleRightClick(x, y)
    end
end

function Gameplay.mousemoved(x, y, dx, dy)
    -- Forward to music player for drag handling
    if M.MusicPlayer then M.MusicPlayer.mousemoved(x, y, dx, dy) end

    -- Handle minimap dragging (map handles this internally in update, but we can also do it here for responsiveness)
    if map:isMinimapDragging() then
        map:minimapNavigate(x, y)
        return
    end

    -- Handle map dragging
    if input.isMapDragging then
        map:scroll(-dx, -dy)
        return
    end

    if isBoxSelecting then
        -- Check if we should enter drag mode
        local mouseHeldTime = love.timer.getTime() - input.mouseDownTime
        local mouseMoved = math.abs(x - input.mouseDownX) > input.dragMoveThreshold or
                          math.abs(y - input.mouseDownY) > input.dragMoveThreshold

        if mouseHeldTime >= input.dragHoldTime and not mouseMoved then
            -- Enter drag mode
            input.isMapDragging = true
            isBoxSelecting = false
            return
        end

        boxEndX, boxEndY = x, y
    end
end

function Gameplay.mousereleased(x, y, button)
    -- Forward to music player for drag release
    if M.MusicPlayer then M.MusicPlayer.mousereleased(x, y, button) end

    -- Forward to surrender dialog first
    if M.Surrender.mousereleased(x, y, button) then return end

    -- Forward to selected entity UI first
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.mousereleased then
        selEntity:mousereleased(x, y, button)
    end

    -- Check victory/defeat button click
    if (victory or defeat) and not tutorialMode and button == 1 and endScreenButton then
        if x >= endScreenButton.x and x <= endScreenButton.x + endScreenButton.w and
           y >= endScreenButton.y and y <= endScreenButton.y + endScreenButton.h then
            Game.SceneManager.switch("title")
            return
        end
    end

    -- Check command button clicks first
    if button == 1 then
        for _, btn in ipairs(commandButtons) do
            if btn.x and btn.hovered then
                if x >= btn.x and x <= btn.x + btn.w and
                   y >= btn.y and y <= btn.y + btn.h then
                    if btn.enabled and btn.action then
                        btn.action()
                    else
                        -- Button disabled (supply limit, insufficient resources, etc.)
                        if M.Audio and M.Audio.playAlert then M.Audio.playAlert() end
                    end
                    return
                end
            end
        end
    end

    -- Stop minimap dragging
    if button == 1 and map:isMinimapDragging() then
        map:minimapRelease()
    end

    -- Stop map dragging
    if button == 1 and input.isMapDragging then
        input.isMapDragging = false
        return  -- Don't do selection when releasing from drag
    end

    if button == 1 and isBoxSelecting then
        isBoxSelecting = false

        local boxW = math.abs(boxEndX - boxStartX)
        local boxH = math.abs(boxEndY - boxStartY)
        local shiftHeld = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

        if boxW < 5 and boxH < 5 then
            handleLeftClick(x, y, shiftHeld)
        else
            -- Box selection only selects units, never buildings
            -- If shift is held but buildings are selected, clear them (can't mix)
            if shiftHeld and selectionHasBuildings() then
                clearSelection()
            elseif not shiftHeld then
                clearSelection()
            end

            -- Helper to add to selection without duplicates
            local function addToSelection(entity)
                for _, e in ipairs(selectedEntities) do
                    if e == entity then return end  -- Already selected
                end
                entity.selected = true
                table.insert(selectedEntities, entity)
            end

            -- Select all PLAYER-OWNED unit types in box (units only, no buildings)
            for _, peon in ipairs(peons) do
                if isPlayerOwned(peon) and peon:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    addToSelection(peon)
                end
            end
            for _, footman in ipairs(footmen) do
                if isPlayerOwned(footman) and footman:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    addToSelection(footman)
                end
            end
            for _, archer in ipairs(archers) do
                if isPlayerOwned(archer) and archer:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    addToSelection(archer)
                end
            end
            for _, knight in ipairs(knights) do
                if isPlayerOwned(knight) and knight:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    addToSelection(knight)
                end
            end
            for _, unit in ipairs(flyingScouts) do
                if isPlayerOwned(unit) and unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    addToSelection(unit)
                end
            end
            for _, unit in ipairs(ballistas) do
                if isPlayerOwned(unit) and unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    addToSelection(unit)
                end
            end
            for _, unit in ipairs(kamikazes) do
                if isPlayerOwned(unit) and unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    addToSelection(unit)
                end
            end
        end
    end
end

function Gameplay.wheelmoved(x, y)
    -- Forward to music player for playlist scrolling
    if M.MusicPlayer and M.MusicPlayer.wheelmoved(x, y) then return end
end

function handleLeftClick(x, y, shiftHeld)
    -- Helper to check if entity is already selected
    local function isAlreadySelected(entity)
        for _, e in ipairs(selectedEntities) do
            if e == entity then return true end
        end
        return false
    end

    -- Helper to select a unit (handles unit/building separation)
    local function selectUnit(entity)
        -- If shift held and clicking already selected unit, deselect it
        if shiftHeld and isAlreadySelected(entity) then
            entity.selected = false
            for i, e in ipairs(selectedEntities) do
                if e == entity then
                    table.remove(selectedEntities, i)
                    break
                end
            end
            return
        end

        -- If buildings are selected, clear them (can't mix units and buildings)
        if selectionHasBuildings() then
            clearSelection()
        elseif not shiftHeld then
            -- No shift = clear existing selection
            clearSelection()
        end

        -- Add to selection
        entity.selected = true
        if not isAlreadySelected(entity) then
            table.insert(selectedEntities, entity)
        end
    end

    -- Helper to select a building (handles unit/building separation)
    local function selectBuilding(entity)
        -- If shift held and clicking already selected building, deselect it
        if shiftHeld and isAlreadySelected(entity) then
            entity.selected = false
            for i, e in ipairs(selectedEntities) do
                if e == entity then
                    table.remove(selectedEntities, i)
                    break
                end
            end
            return
        end

        -- If units are selected, clear them (can't mix units and buildings)
        if selectionHasUnits() then
            clearSelection()
        elseif not shiftHeld then
            -- No shift = clear existing selection
            clearSelection()
        end

        -- Add to selection
        entity.selected = true
        if not isAlreadySelected(entity) then
            table.insert(selectedEntities, entity)
        end
    end

    -- Check all PLAYER-OWNED unit types first (units take priority)
    for _, peon in ipairs(peons) do
        if peon.visible and isPlayerOwned(peon) and peon:containsPoint(x, y) then
            selectUnit(peon)
            return
        end
    end

    for _, footman in ipairs(footmen) do
        if isPlayerOwned(footman) and footman:containsPoint(x, y) then
            selectUnit(footman)
            return
        end
    end

    for _, archer in ipairs(archers) do
        if isPlayerOwned(archer) and archer:containsPoint(x, y) then
            selectUnit(archer)
            return
        end
    end

    for _, knight in ipairs(knights) do
        if isPlayerOwned(knight) and knight:containsPoint(x, y) then
            selectUnit(knight)
            return
        end
    end

    for _, unit in ipairs(flyingScouts) do
        if isPlayerOwned(unit) and unit:containsPoint(x, y) then
            selectUnit(unit)
            return
        end
    end

    for _, unit in ipairs(ballistas) do
        if isPlayerOwned(unit) and unit:containsPoint(x, y) then
            selectUnit(unit)
            return
        end
    end

    for _, unit in ipairs(kamikazes) do
        if isPlayerOwned(unit) and unit:containsPoint(x, y) then
            selectUnit(unit)
            return
        end
    end

    -- ENEMY UNITS - selectable for viewing HP (no controls)
    -- Only if not shift-clicking (don't mix enemy with player selection)
    if not shiftHeld then
        for _, peon in ipairs(peons) do
            if peon.visible and not isPlayerOwned(peon) and peon:containsPoint(x, y) then
                clearSelection()
                peon.selected = true
                table.insert(selectedEntities, peon)
                return
            end
        end

        for _, footman in ipairs(footmen) do
            if not isPlayerOwned(footman) and footman:containsPoint(x, y) then
                clearSelection()
                footman.selected = true
                table.insert(selectedEntities, footman)
                return
            end
        end
    end

    -- Check PLAYER-OWNED buildings
    if isPlayerOwned(townHall) and townHall:containsPoint(x, y) then
        selectBuilding(townHall)
        return
    end

    for _, building in ipairs(townHalls) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            selectBuilding(building)
            return
        end
    end

    for _, barrack in ipairs(barracks) do
        if isPlayerOwned(barrack) and barrack:containsPoint(x, y) then
            selectBuilding(barrack)
            return
        end
    end

    for _, farm in ipairs(farms) do
        if isPlayerOwned(farm) and farm:containsPoint(x, y) then
            selectBuilding(farm)
            return
        end
    end

    for _, building in ipairs(lumberMills) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            selectBuilding(building)
            return
        end
    end

    for _, building in ipairs(blacksmiths) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            selectBuilding(building)
            return
        end
    end

    for _, building in ipairs(scoutTowers) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            selectBuilding(building)
            return
        end
    end

    for _, building in ipairs(archeryRanges) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            selectBuilding(building)
            return
        end
    end

    for _, building in ipairs(stables) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            selectBuilding(building)
            return
        end
    end

    for _, building in ipairs(siegeWorkshops) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            selectBuilding(building)
            return
        end
    end

    -- ENEMY BUILDINGS - selectable for viewing HP (no controls)
    -- Check additional townhalls (includes enemy townhall)
    for _, building in ipairs(townHalls) do
        if not isPlayerOwned(building) and building:containsPoint(x, y) then
            clearSelection()
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end

    -- Enemy barracks
    for _, barrack in ipairs(barracks) do
        if not isPlayerOwned(barrack) and barrack:containsPoint(x, y) then
            clearSelection()
            barrack.selected = true
            table.insert(selectedEntities, barrack)
            return
        end
    end

    -- Enemy farms
    for _, farm in ipairs(farms) do
        if not isPlayerOwned(farm) and farm:containsPoint(x, y) then
            farm.selected = true
            table.insert(selectedEntities, farm)
            return
        end
    end

    -- Gold mines are neutral - anyone can select/view them
    for _, mine in ipairs(goldMines) do
        if mine:containsPoint(x, y) then
            mine.selected = true
            table.insert(selectedEntities, mine)
            return
        end
    end
end

function handleRightClick(x, y)
    if #selectedEntities == 0 then return end

    local worldX, worldY = map:screenToWorld(x, y)
    local buildings = getAllBuildings()
    local playerTeam = M.Teams and M.Teams.PLAYER or 1

    -- Check if clicked on an enemy unit
    local clickedEnemy = nil
    local allUnits = getAllUnits()
    for _, unit in ipairs(allUnits) do
        if unit.team and unit.team ~= playerTeam and unit:containsPoint(x, y) then
            clickedEnemy = unit
            break
        end
    end

    -- Check if clicked on an enemy building
    local clickedEnemyBuilding = nil
    if not clickedEnemy then
        for _, building in ipairs(townHalls) do
            if building.team and building.team ~= playerTeam and building:containsPoint(x, y) then
                clickedEnemyBuilding = building
                break
            end
        end
        if not clickedEnemyBuilding then
            for _, building in ipairs(barracks) do
                if building.team and building.team ~= playerTeam and building:containsPoint(x, y) then
                    clickedEnemyBuilding = building
                    break
                end
            end
        end
        if not clickedEnemyBuilding then
            for _, building in ipairs(farms) do
                if building.team and building.team ~= playerTeam and building:containsPoint(x, y) then
                    clickedEnemyBuilding = building
                    break
                end
            end
        end
    end

    -- If clicked enemy, send attack command
    if clickedEnemy or clickedEnemyBuilding then
        local target = clickedEnemy or clickedEnemyBuilding
        local attackCount = 0
        for _, entity in ipairs(selectedEntities) do
            -- Only issue attack commands to player-owned units
            if isPlayerOwned(entity) and entity.setAttackTarget then
                entity:setAttackTarget(target)
                attackCount = attackCount + 1
            end
        end
        if attackCount > 0 then
            addNotification("Attacking " .. (target.name or "target"))
        end
        return
    end

    -- Check what was clicked ONCE (not per-unit)
    local clickedMine = nil
    for _, mine in ipairs(goldMines) do
        if mine:containsPoint(x, y) and not mine.depleted then
            clickedMine = mine
            break
        end
    end

    local clickedTownHall = townHall:containsPoint(x, y)

    local gridX, gridY = map:worldToGrid(worldX, worldY)
    local clickedTree = map:isTileTree(gridX, gridY)
    local treeX, treeY = nil, nil

    -- If clicked on a tree or non-passable area, try to find nearest reachable tree
    -- (peons will use findNearestReachableTree, but we need coordinates for flow field)
    if clickedTree or not map:isWorldPosPassable(worldX, worldY) then
        -- Search for nearest tree with accessible neighbor
        local directions = {{-1,0}, {1,0}, {0,-1}, {0,1}, {-1,-1}, {1,-1}, {-1,1}, {1,1}}

        -- First check clicked tile if it's a tree
        if clickedTree then
            for _, dir in ipairs(directions) do
                local standX = gridX + dir[1]
                local standY = gridY + dir[2]
                if map:isTilePassable(standX, standY) then
                    treeX, treeY = gridX, gridY
                    break
                end
            end
        end

        -- If not found, search in expanding rings
        if not treeX then
            for radius = 1, 10 do
                for dx = -radius, radius do
                    for dy = -radius, radius do
                        if math.abs(dx) == radius or math.abs(dy) == radius then
                            local checkX = gridX + dx
                            local checkY = gridY + dy

                            if map:isTileTree(checkX, checkY) then
                                for _, dir in ipairs(directions) do
                                    local standX = checkX + dir[1]
                                    local standY = checkY + dir[2]
                                    if map:isTilePassable(standX, standY) then
                                        treeX, treeY = checkX, checkY
                                        break
                                    end
                                end
                                if treeX then break end
                            end
                        end
                    end
                    if treeX then break end
                end
                if treeX then break end
            end
        end
    end

    local clickedOnBuilding = false
    for _, building in ipairs(buildings) do
        if building ~= townHall and building.containsPoint and building:containsPoint(x, y) then
            clickedOnBuilding = true
            break
        end
    end

    -- Command all selected units (only player-owned)
    for _, entity in ipairs(selectedEntities) do
        -- Skip enemy units - can't command them
        if not isPlayerOwned(entity) then
            -- Do nothing for enemy units
        elseif entity.type == "peon" then
            local peon = entity

            if clickedMine then
                peon:goToMine(clickedMine)
            elseif clickedTownHall then
                if peon.carryingGold > 0 or peon.carryingLumber > 0 then
                    peon.state = M.Peon.STATE_RETURNING
                    peon.path = nil
                else
                    peon:moveTo(worldX, worldY)
                end
            elseif treeX then
                peon:goToTree(treeX, treeY)
            elseif not clickedOnBuilding and map:isWorldPosPassable(worldX, worldY) then
                peon:moveTo(worldX, worldY)
            end

        elseif entity.moveTo then
            -- All other mobile units (footman, archer, knight, flyingscout, ballista, kamikaze)
            if not clickedOnBuilding and not clickedMine and not clickedTownHall and not clickedTree then
                if map:isWorldPosPassable(worldX, worldY) or entity.type == "flyingscout" then
                    entity:moveTo(worldX, worldY)
                end
            end
        end
    end
end

function Gameplay.unload()
    -- Restore system cursor when leaving gameplay
    love.mouse.setVisible(true)
end

-- Get game state for tutorial to check conditions
function Gameplay.getTutorialState()
    local playerTeam = M.Teams and M.Teams.PLAYER or 1

    -- Count player peons
    local peonCount = 0
    for _, p in ipairs(peons) do
        if p.team == playerTeam then
            peonCount = peonCount + 1
        end
    end

    return {
        -- Core references
        townHall = townHall,
        selectedEntities = selectedEntities,
        playerTeam = playerTeam,

        -- Lists
        peons = peons,
        footmen = footmen,
        farms = farms,
        barracks = barracks,

        -- Counts
        peonCount = peonCount,

        -- Building placement
        isPlacingBuilding = buildingPlacement:isActive(),
        placingBuildingType = buildingPlacement:getBuildingType(),

        -- Win conditions
        victory = victory,
        defeat = defeat,
    }
end

-- Force select an entity (used by tutorial to restore selection)
function Gameplay.forceSelect(entity)
    -- Clear current selection
    for _, e in ipairs(selectedEntities) do
        e.selected = false
    end
    selectedEntities = {}

    -- Select the specified entity
    if entity then
        entity.selected = true
        selectedEntities = {entity}
    end
end

return Gameplay
