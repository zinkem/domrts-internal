--[[
    Gameplay Scene
    RTS Resource Gathering with scrolling map
    Includes full tech tree with all buildings and units
    
    ENHANCED: Now includes particle effects and visual enhancements
]]

local Map = require("map")
local TownHall = require("townhall")
local GoldMine = require("goldmine")
local Peon = require("peon")
local Farm = require("farm")
local Barracks = require("barracks")
local Footman = require("footman")
-- FlowField no longer needed - using pathfinding.lua
local Requirements = require("requirements")

-- New buildings
local LumberMill = require("lumbermill")
local Blacksmith = require("blacksmith")
local ScoutTower = require("scouttower")
local ArcheryRange = require("archeryrange")
local Stable = require("stable")
local SiegeWorkshop = require("siegeworkshop")

-- New units
local Archer = require("archer")
local Knight = require("knight")
local FlyingScout = require("flyingscout")
local Ballista = require("ballista")
local Kamikaze = require("kamikaze")
local UIDraw = require("ui_draw")

-- Team system
local Teams
local Player
local AI
pcall(function() Teams = require("teams") end)
pcall(function() Player = require("player") end)
pcall(function() AI = require("ai") end)

-- Visual effects (optional - graceful fallback)
local Effects, DrawUtils
pcall(function() Effects = require("effects") end)
pcall(function() DrawUtils = require("draw_utils") end)

local Gameplay = {}

-- Game state
local elapsedTime = 0
local victory = false
local defeat = false

-- Game stats for victory screen
local gameStats = {
    unitsKilled = 0,
    unitsLost = 0,
    buildingsDestroyed = 0,
    buildingsLost = 0,
    goldCollected = 0,
    lumberCollected = 0,
}

local resources = {
    gold = 1000,
    lumber = 400
}

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

-- Building placement
local isPlacingBuilding = false
local placingBuildingType = nil
local placingPeon = nil
local placementGridX, placementGridY = 0, 0
local placementValid = false

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
    cursorChargeProgress = 0
}

-- UI Layout - Stone/Metal Medieval Theme
local UI = {
    -- Stone colors
    stoneLight = {0.45, 0.42, 0.38, 1},
    stoneMid = {0.35, 0.32, 0.28, 1},
    stoneDark = {0.25, 0.22, 0.18, 1},
    stoneAccent = {0.55, 0.52, 0.45, 1},
    
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
    bottomPanelHeight = 180,
    bottomPanelWidth = 280,
}

-- Notification system
local notifications = {}
local NOTIFICATION_DURATION = 3.0

local function addNotification(message)
    table.insert(notifications, {text = message, timer = NOTIFICATION_DURATION})
end

local function checkAllMinesDepleted()
    for _, mine in ipairs(goldMines) do
        if not mine.depleted then return false end
    end
    return true
end

local function countPlayerUnits(unitList)
    local playerTeam = Teams and Teams.PLAYER or 1
    local count = 0
    for _, unit in ipairs(unitList) do
        if unit.team == nil or unit.team == playerTeam then
            count = count + 1
        end
    end
    return count
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
    local playerTeam = Teams and Teams.PLAYER or 1
    maxPop = BASE_CAPACITY
    for _, farm in ipairs(farms) do
        if farm.completed and (farm.team == nil or farm.team == playerTeam) then 
            maxPop = maxPop + Farm.CAPACITY_BONUS 
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

local function separateUnits()
    local allUnits = getAllUnits()
    local buildings = getAllBuildings()
    
    -- Helper to check if position collides with any building
    local function collidesWithBuilding(x, y, radius)
        for _, b in ipairs(buildings) do
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
    
    -- Multiple passes for better separation
    for pass = 1, 3 do
        for i = 1, #allUnits do
            for j = i + 1, #allUnits do
                local a, b = allUnits[i], allUnits[j]
                
                -- Skip collision if either unit is a peon carrying gold
                local aCarryingGold = a.carryingGold and a.carryingGold > 0
                local bCarryingGold = b.carryingGold and b.carryingGold > 0
                if aCarryingGold or bCarryingGold then
                    goto continue
                end
                
                local dx = b.worldX - a.worldX
                local dy = b.worldY - a.worldY
                local dist = math.sqrt(dx * dx + dy * dy)
                local minDist = a.radius + b.radius
                
                if dist < minDist and dist > 0.1 then
                    local overlap = (minDist - dist) / 2 + 0.5
                    local nx, ny = dx / dist, dy / dist
                    
                    -- Push apart
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
                
                ::continue::
            end
        end
    end
end

-- Helper: Draw stone panel background (using UIDraw module)
local function drawStonePanel(x, y, w, h, cornerRadius)
    UIDraw.drawStonePanel(x, y, w, h, cornerRadius)
end

-- Helper: Draw resource group with icon (using UIDraw module)
local function drawResourceGroup(x, y, iconType, value, label)
    UIDraw.drawResourceGroup(x, y, iconType, value, label, Game.fonts)
end

local function drawTopBar(screenW)
    UIDraw.drawTopBar(screenW, resources, currentPop, maxPop, elapsedTime, townHall.tier, Game.settings.gameSpeed, Game.fonts)
end

local function drawMinimap(screenW)
    local mmX, mmY, mmSize = UIDraw.drawMinimapFrame(screenW)
    
    -- Draw actual minimap
    local mmScale = mmSize / map.width
    map:drawMinimap(mmX, mmY, mmSize)
    
    -- Draw all entities on minimap
    townHall:drawOnMinimap(mmX, mmY, mmScale)
    for _, m in ipairs(goldMines) do m:drawOnMinimap(mmX, mmY, mmScale) end
    for _, f in ipairs(farms) do f:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(barracks) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(lumberMills) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(blacksmiths) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(scoutTowers) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(archeryRanges) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(stables) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(siegeWorkshops) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(townHalls) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, p in ipairs(peons) do p:drawOnMinimap(mmX, mmY, mmScale) end
    for _, f in ipairs(footmen) do f:drawOnMinimap(mmX, mmY, mmScale) end
    for _, a in ipairs(archers) do a:drawOnMinimap(mmX, mmY, mmScale) end
    for _, k in ipairs(knights) do k:drawOnMinimap(mmX, mmY, mmScale) end
    for _, f in ipairs(flyingScouts) do f:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(ballistas) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, k in ipairs(kamikazes) do k:drawOnMinimap(mmX, mmY, mmScale) end
end

local function drawBottomPanel(screenW, screenH)
    local panelX, panelY, panelW, panelH = UIDraw.drawBottomPanelFrame(screenW, screenH)
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(UI.metalGold)
    
    local selEntity = selectedEntities[1]
    if selEntity then
        -- Entity name in header
        love.graphics.print(selEntity.name, panelX + 12, panelY + 8)
        
        if #selectedEntities > 1 then
            love.graphics.setColor(UI.textLight)
            love.graphics.setFont(Game.fonts.small)
            love.graphics.print("+" .. (#selectedEntities - 1) .. " more selected", panelX + 12, panelY + 36)
        end
        
        -- Status info
        love.graphics.setFont(Game.fonts.small)
        local statusY = panelY + 36
        
        if selEntity.type == "townhall" then
            if selEntity.isBuilding then
                love.graphics.setColor(0.6, 0.8, 1, 1)
                love.graphics.print("Building: " .. selEntity:getBuildProgress() .. "%", panelX + 12, statusY)
            elseif selEntity.isUpgrading then
                love.graphics.setColor(UI.metalGold)
                love.graphics.print("Upgrading: " .. selEntity:getUpgradeProgress() .. "%", panelX + 12, statusY)
            elseif selEntity.isProducing then
                love.graphics.setColor(0.5, 0.9, 0.5, 1)
                love.graphics.print("Training: " .. selEntity:getProductionProgress() .. "%", panelX + 12, statusY)
            else
                love.graphics.setColor(UI.textLight)
                love.graphics.print("Ready", panelX + 12, statusY)
            end
        elseif selEntity.type == "goldmine" then
            love.graphics.setColor(UI.textGold)
            love.graphics.print("Gold: " .. selEntity.goldReserves, panelX + 12, statusY)
        elseif selEntity.getStateText then
            love.graphics.setColor(UI.textLight)
            love.graphics.print(selEntity:getStateText(), panelX + 12, statusY)
        elseif selEntity.completed ~= nil then
            if not selEntity.completed then
                love.graphics.setColor(0.6, 0.8, 1, 1)
                love.graphics.print("Building: " .. (selEntity.getBuildProgress and selEntity:getBuildProgress() or 0) .. "%", panelX + 12, statusY)
            elseif selEntity.isProducing then
                love.graphics.setColor(0.5, 0.9, 0.5, 1)
                love.graphics.print("Training: " .. (selEntity.getProductionProgress and selEntity:getProductionProgress() or 0) .. "%", panelX + 12, statusY)
            elseif selEntity.isUpgrading then
                love.graphics.setColor(UI.metalGold)
                love.graphics.print("Upgrading...", panelX + 12, statusY)
            else
                love.graphics.setColor(UI.textLight)
                love.graphics.print("Ready", panelX + 12, statusY)
            end
        end
    else
        love.graphics.print("No Selection", panelX + 12, panelY + 8)
        love.graphics.setFont(Game.fonts.small)
        love.graphics.setColor(UI.stoneAccent)
        love.graphics.print("Click to select units", panelX + 12, panelY + 38)
        love.graphics.print("Drag to box select", panelX + 12, panelY + 54)
        love.graphics.print("Right-click to command", panelX + 12, panelY + 70)
        love.graphics.print("WASD to scroll map", panelX + 12, panelY + 86)
        love.graphics.print("1/2/3 for game speed", panelX + 12, panelY + 102)
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
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    local boxW, boxH = 450, 320
    local boxX, boxY = (screenW - boxW) / 2, (screenH - boxH) / 2
    
    -- Victory box
    love.graphics.setColor(0.1, 0.25, 0.1, 1)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 10)
    love.graphics.setColor(0.3, 0.7, 0.3, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 10)
    
    -- Title
    love.graphics.setFont(Game.fonts.title)
    love.graphics.setColor(1, 0.85, 0, 1)
    love.graphics.print("VICTORY!", (screenW - Game.fonts.title:getWidth("VICTORY!")) / 2, boxY + 20)
    
    -- Message
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("All enemy buildings destroyed!", (screenW - Game.fonts.medium:getWidth("All enemy buildings destroyed!")) / 2, boxY + 70)
    
    -- Stats
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.9, 0.9, 0.8, 1)
    local statsY = boxY + 110
    local lineHeight = 22
    
    local minutes = math.floor(elapsedTime / 60)
    local seconds = math.floor(elapsedTime % 60)
    local timeStr = string.format("Time: %d:%02d", minutes, seconds)
    love.graphics.print(timeStr, boxX + 40, statsY)
    
    love.graphics.print("Units Killed: " .. gameStats.unitsKilled, boxX + 40, statsY + lineHeight)
    love.graphics.print("Units Lost: " .. gameStats.unitsLost, boxX + 40, statsY + lineHeight * 2)
    love.graphics.print("Buildings Destroyed: " .. gameStats.buildingsDestroyed, boxX + 40, statsY + lineHeight * 3)
    love.graphics.print("Buildings Lost: " .. gameStats.buildingsLost, boxX + 40, statsY + lineHeight * 4)
    
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("Final Gold: " .. resources.gold, boxX + 250, statsY + lineHeight)
    love.graphics.setColor(0.6, 0.45, 0.25, 1)
    love.graphics.print("Final Lumber: " .. resources.lumber, boxX + 250, statsY + lineHeight * 2)
    
    -- Continue prompt
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Press SPACE to return to title", (screenW - Game.fonts.small:getWidth("Press SPACE to return to title")) / 2, boxY + boxH - 35)
end

local function drawDefeatScreen()
    local screenW, screenH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    local boxW, boxH = 450, 320
    local boxX, boxY = (screenW - boxW) / 2, (screenH - boxH) / 2
    
    -- Defeat box
    love.graphics.setColor(0.25, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 10)
    love.graphics.setColor(0.7, 0.2, 0.2, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 10)
    
    -- Title
    love.graphics.setFont(Game.fonts.title)
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.print("DEFEAT", (screenW - Game.fonts.title:getWidth("DEFEAT")) / 2, boxY + 20)
    
    -- Message
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Your Town Hall was destroyed!", (screenW - Game.fonts.medium:getWidth("Your Town Hall was destroyed!")) / 2, boxY + 70)
    
    -- Stats
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.9, 0.9, 0.8, 1)
    local statsY = boxY + 110
    local lineHeight = 22
    
    local minutes = math.floor(elapsedTime / 60)
    local seconds = math.floor(elapsedTime % 60)
    local timeStr = string.format("Time: %d:%02d", minutes, seconds)
    love.graphics.print(timeStr, boxX + 40, statsY)
    
    love.graphics.print("Units Killed: " .. gameStats.unitsKilled, boxX + 40, statsY + lineHeight)
    love.graphics.print("Units Lost: " .. gameStats.unitsLost, boxX + 40, statsY + lineHeight * 2)
    love.graphics.print("Buildings Destroyed: " .. gameStats.buildingsDestroyed, boxX + 40, statsY + lineHeight * 3)
    love.graphics.print("Buildings Lost: " .. gameStats.buildingsLost, boxX + 40, statsY + lineHeight * 4)
    
    -- Continue prompt
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Press SPACE to return to title", (screenW - Game.fonts.small:getWidth("Press SPACE to return to title")) / 2, boxY + boxH - 35)
end

local function getBuildingSize(buildingType)
    if buildingType == "farm" or buildingType == "lumbermill" or buildingType == "blacksmith" 
       or buildingType == "scouttower" or buildingType == "stable" then
        return 2
    else
        return 3  -- barracks, archeryrange, siegeworkshop
    end
end

local function drawBuildingPlacement()
    if not isPlacingBuilding then return end
    
    local mx, my = love.mouse.getPosition()
    if not map:isInViewport(mx, my) then return end
    
    local worldX, worldY = map:screenToWorld(mx, my)
    local gridX, gridY = map:worldToGrid(worldX, worldY)
    local buildSize = getBuildingSize(placingBuildingType)
    
    -- Check if area is clear of trees/terrain
    placementValid = map:isAreaClear(gridX, gridY, buildSize, buildSize)
    
    -- Also check for overlap with existing buildings
    if placementValid then
        local function buildingsOverlap(ax, ay, aSize, bx, by, bSize)
            return ax < bx + bSize and ax + aSize > bx and
                   ay < by + bSize and ay + aSize > by
        end
        
        -- Check all buildings
        local allBuildings = getAllBuildings()
        for _, building in ipairs(allBuildings) do
            if building.gridSize and buildingsOverlap(gridX, gridY, buildSize, building.gridX, building.gridY, building.gridSize) then
                placementValid = false
                break
            end
        end
    end
    
    placementGridX, placementGridY = gridX, gridY
    
    local screenX, screenY = map:worldToScreen(map:gridToWorld(gridX, gridY))
    local pixelSize = buildSize * 32
    
    love.graphics.setColor(placementValid and {0, 1, 0, 0.4} or {1, 0, 0, 0.4})
    love.graphics.rectangle("fill", screenX, screenY, pixelSize, pixelSize)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", screenX, screenY, pixelSize, pixelSize)
    
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Left-click to place " .. placingBuildingType .. " | Right-click to cancel", map.viewportX + 10, map.viewportY + map.viewportH - 25)
end

local function drawBoxSelection()
    if not isBoxSelecting then return end
    love.graphics.setColor(0, 1, 0, 0.2)
    local x1, y1 = math.min(boxStartX, boxEndX), math.min(boxStartY, boxEndY)
    local w, h = math.abs(boxEndX - boxStartX), math.abs(boxEndY - boxStartY)
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
    
    love.graphics.setColor(1, 1, 1, 1)
end

local function startBuildingPlacement(peon, buildingType)
    isPlacingBuilding = true
    placingBuildingType = buildingType
    placingPeon = peon
end

local function cancelBuildingPlacement()
    isPlacingBuilding = false
    placingBuildingType = nil
    placingPeon = nil
end

-- Callback for AI to create buildings
local function aiCreateBuilding(peon, buildingType, gridX, gridY, team)
    if not peon or not gridX or not gridY then return end
    
    -- Get building center in world coords
    local buildingSize = 2
    if buildingType == "barracks" then buildingSize = 3 end
    
    local worldX = (gridX + buildingSize / 2) * 32
    local worldY = (gridY + buildingSize / 2) * 32
    
    -- Tell peon to go build
    peon:goToBuild(worldX, worldY, buildingType, function()
        -- This callback is called when peon arrives
        local actualTeam = team or peon.team
        
        if buildingType == "farm" then
            local building = Farm.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = actualTeam})
            building.builderPeon = peon
            table.insert(farms, building)
        elseif buildingType == "barracks" then
            local building = Barracks.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = actualTeam})
            building.builderPeon = peon
            table.insert(barracks, building)
        end
    end)
end

local function createBuilding(gridX, gridY, buildingType, peon)
    local team = peon and peon.team or (Teams and Teams.PLAYER or 1)
    
    if buildingType == "farm" then
        local building = Farm.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(farms, building)
    elseif buildingType == "barracks" then
        local building = Barracks.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(barracks, building)
    elseif buildingType == "lumbermill" then
        local building = LumberMill.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(lumberMills, building)
    elseif buildingType == "blacksmith" then
        local building = Blacksmith.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(blacksmiths, building)
    elseif buildingType == "scouttower" then
        local building = ScoutTower.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(scoutTowers, building)
    elseif buildingType == "archeryrange" then
        local building = ArcheryRange.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(archeryRanges, building)
    elseif buildingType == "stable" then
        local building = Stable.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        -- Set callback for Paladin upgrade
        building.onPaladinUpgrade = function()
            for _, knight in ipairs(knights) do
                knight:upgradeToPaladin()
            end
        end
        table.insert(stables, building)
    elseif buildingType == "siegeworkshop" then
        local building = SiegeWorkshop.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(siegeWorkshops, building)
    elseif buildingType == "townhall" then
        local building = TownHall.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true, team = team})
        building.builderPeon = peon
        table.insert(townHalls, building)
    end
    -- Invalidate all flow fields since map topology changed
    -- Pathfinding computed on-demand, no need to invalidate
end

local function getBuildingCost(buildingType)
    if buildingType == "farm" then return Farm.COST_GOLD, Farm.COST_LUMBER
    elseif buildingType == "barracks" then return Barracks.COST_GOLD, Barracks.COST_LUMBER
    elseif buildingType == "lumbermill" then return LumberMill.COST_GOLD, LumberMill.COST_LUMBER
    elseif buildingType == "blacksmith" then return Blacksmith.COST_GOLD, Blacksmith.COST_LUMBER
    elseif buildingType == "scouttower" then return ScoutTower.COST_GOLD, ScoutTower.COST_LUMBER
    elseif buildingType == "archeryrange" then return ArcheryRange.COST_GOLD, ArcheryRange.COST_LUMBER
    elseif buildingType == "stable" then return Stable.COST_GOLD, Stable.COST_LUMBER
    elseif buildingType == "siegeworkshop" then return SiegeWorkshop.COST_GOLD, SiegeWorkshop.COST_LUMBER
    elseif buildingType == "townhall" then return TownHall.COST_GOLD, TownHall.COST_LUMBER
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

-- Check if entity belongs to human player (for selection filtering)
local function isPlayerOwned(entity)
    if not entity then return false end
    local playerTeam = Teams and Teams.PLAYER or 1
    return entity.team == nil or entity.team == playerTeam
end

local function updateRequirementsState()
    Requirements.setGameState({
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
            -- Track stats
            local playerTeam = Teams and Teams.PLAYER or 1
            if unit.team == playerTeam then
                gameStats.unitsLost = gameStats.unitsLost + 1
            else
                gameStats.unitsKilled = gameStats.unitsKilled + 1
            end
            -- Spawn death effect
            if Effects then
                Effects.blood(unit.worldX, unit.worldY)
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
            -- Track stats
            local playerTeam = Teams and Teams.PLAYER or 1
            if building.team == playerTeam then
                gameStats.buildingsLost = gameStats.buildingsLost + 1
            else
                gameStats.buildingsDestroyed = gameStats.buildingsDestroyed + 1
            end
            -- Clear map area
            if building.gridX and building.gridSize and map then
                -- Could restore grass tiles here
            end
            table.remove(buildingList, i)
        end
    end
end

-- Check victory/defeat conditions
local function checkVictoryConditions()
    local enemyTeam = Teams and Teams.ENEMY or 2
    local playerTeam = Teams and Teams.PLAYER or 1
    
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
        return
    end
    
    -- Check if player's main townhall is destroyed
    if townHall and townHall.isDead and townHall:isDead() then
        defeat = true
        return
    end
end

-- Setup callbacks for peons to check resources and send notifications
local function setupPeonCallbacks(peon)
    peon.onNotify = addNotification
    
    local playerTeam = Teams and Teams.PLAYER or 1
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
            if gold > 0 then resources.gold = resources.gold + gold end
            if lumber > 0 then resources.lumber = resources.lumber + lumber end
        end
    else
        -- AI peon callbacks
        peon.resourceCheck = function()
            if not enemyAI then return false, 0, 0 end
            local gold = enemyAI.gold
            local lumber = enemyAI.lumber
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
                if gold > 0 then enemyAI:addGold(gold) end
                if lumber > 0 then enemyAI:addLumber(lumber) end
            end
        end
    end
end

function Gameplay.load()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Hide system cursor and use custom
    love.mouse.setVisible(false)
    input.cursorState = "normal"
    input.cursorChargeProgress = 0
    
    -- Initialize visual effects system
    if Effects then Effects.init() end
    
    -- Pathfinding computed on-demand, no need to invalidate
    
    elapsedTime = 0
    victory = false
    defeat = false
    resources.gold = 1000
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
    isPlacingBuilding = false
    isBoxSelecting = false
    input.isMapDragging = false
    
    map = Map.new()
    map:setViewport(0, UI.topBarHeight, screenW, screenH - UI.topBarHeight)
    
    -- Human player team
    local playerTeam = Teams and Teams.PLAYER or 1
    local enemyTeam = Teams and Teams.ENEMY or 2
    
    local buildingSize = 3
    
    -- === PLAYER BASE (bottom-left area) ===
    local thGridX, thGridY = map:findClearArea(buildingSize, buildingSize, 10, 30, 15)
    townHall = TownHall.new({gridX = thGridX, gridY = thGridY, map = map, team = playerTeam})
    
    -- Gold mine near player
    local m1X, m1Y = map:findClearArea(buildingSize, buildingSize, thGridX + 8, thGridY + 5, 10)
    table.insert(goldMines, GoldMine.new({gridX = m1X, gridY = m1Y, gold = 50000, map = map}))
    
    -- Player starting peons - send to closest mine
    local spawnX, spawnY = townHall:getSpawnPos()
    for i = 1, 3 do
        local newPeon = Peon.new({
            worldX = spawnX + (i - 1) * 35,
            worldY = spawnY + (i - 2) * 30,
            map = map,
            team = playerTeam
        })
        setupPeonCallbacks(newPeon)
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)
        -- Auto-send to closest mine
        local closestMine = findClosestMine(newPeon.worldX, newPeon.worldY)
        if closestMine then
            newPeon:goToMine(closestMine)
        end
    end
    
    -- === ENEMY BASE (top-right area) ===
    local enemyThGridX, enemyThGridY = map:findClearArea(buildingSize, buildingSize, 52, 12, 15)
    enemyTownHall = TownHall.new({gridX = enemyThGridX, gridY = enemyThGridY, map = map, team = enemyTeam})
    table.insert(townHalls, enemyTownHall)  -- Store in additional townhalls list
    
    -- Gold mine near enemy
    local m2X, m2Y = map:findClearArea(buildingSize, buildingSize, enemyThGridX - 8, enemyThGridY + 5, 10)
    table.insert(goldMines, GoldMine.new({gridX = m2X, gridY = m2Y, gold = 50000, map = map}))
    
    -- Center gold mine (contested)
    local m3X, m3Y = map:findClearArea(buildingSize, buildingSize, 32, 32, 15)
    table.insert(goldMines, GoldMine.new({gridX = m3X, gridY = m3Y, gold = 100000, map = map}))
    
    -- Enemy starting peons - send to closest mine
    local enemySpawnX, enemySpawnY = enemyTownHall:getSpawnPos()
    for i = 1, 3 do
        local newPeon = Peon.new({
            worldX = enemySpawnX + (i - 1) * 35,
            worldY = enemySpawnY + (i - 2) * 30,
            map = map,
            team = enemyTeam
        })
        -- Enemy peons need resource callbacks for AI economy
        setupPeonCallbacks(newPeon)
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)
        -- Auto-send to closest mine
        local closestMine = findClosestMine(newPeon.worldX, newPeon.worldY)
        if closestMine then
            newPeon:goToMine(closestMine)
        end
    end
    
    -- Initialize AI controller
    if AI then
        enemyAI = AI.new({
            team = enemyTeam,
            townHall = enemyTownHall,
            map = map,
            startGold = 1000,
            startLumber = 400
        })
    end
    
    calculatePopulation()
    updateRequirementsState()
    
    local thCenterX, thCenterY = townHall:getWorldCenter()
    map:centerOn(thCenterX, thCenterY)
end

function Gameplay.update(dt)
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
    if Effects then Effects.update(gameDt) end
    if DrawUtils then DrawUtils.update(gameDt) end
    
    elapsedTime = elapsedTime + gameDt
    map:update(dt)  -- Camera stays at real-time for responsiveness
    calculatePopulation()
    updateRequirementsState()
    
    local buildings = getAllBuildings()
    
    -- Town hall
    local peonReady, upgradeComplete, _ = townHall:update(gameDt)
    if peonReady and currentPop < maxPop then
        local spawnX, spawnY = townHall:getSpawnPos()
        local newPeon = Peon.new({worldX = spawnX, worldY = spawnY, map = map, team = townHall.team})
        setupPeonCallbacks(newPeon)
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)
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
        end
        if unitType and currentPop < maxPop then
            local spawnX, spawnY = barrack:getSpawnPos()
            if unitType == "footman" then
                local newUnit = Footman.new({worldX = spawnX, worldY = spawnY, map = map, team = barrack.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(footmen, newUnit)
            elseif unitType == "knight" then
                local newUnit = Knight.new({worldX = spawnX, worldY = spawnY, map = map, team = barrack.team})
                -- Check if Paladin upgrade is active
                for _, stable in ipairs(stables) do
                    if stable.completed and stable.hasPaladinUpgrade then
                        newUnit:upgradeToPaladin()
                        break
                    end
                end
                pushUnitOutOfBuildings(newUnit)
                table.insert(knights, newUnit)
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
        end
    end
    
    -- Blacksmiths
    for _, building in ipairs(blacksmiths) do
        if building:update(gameDt) and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
        end
    end
    
    -- Scout Towers
    for _, building in ipairs(scoutTowers) do
        if building:update(gameDt) and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
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
        end
        if archerReady and currentPop < maxPop then
            local spawnX, spawnY = building:getSpawnPos()
            local newUnit = Archer.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
            pushUnitOutOfBuildings(newUnit)
            table.insert(archers, newUnit)
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
        end
        if unitType and currentPop < maxPop then
            local spawnX, spawnY = building:getSpawnPos()
            if unitType == "flyingscout" then
                local newUnit = FlyingScout.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(flyingScouts, newUnit)
            elseif unitType == "ballista" then
                local newUnit = Ballista.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(ballistas, newUnit)
            elseif unitType == "kamikaze" then
                local newUnit = Kamikaze.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
                pushUnitOutOfBuildings(newUnit)
                table.insert(kamikazes, newUnit)
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
        local playerTeam = Teams and Teams.PLAYER or 1
        local enemyTeam = Teams and Teams.ENEMY or 2
        
        if building.team == playerTeam then
            canSpawn = peonReady and currentPop < maxPop
        elseif building.team == enemyTeam and enemyAI then
            -- AI handles its own population check
            local aiPop = #enemyAI.peons + #enemyAI.footmen
            local aiMaxPop = 4 + #enemyAI.farms * 4
            canSpawn = peonReady and aiPop < aiMaxPop
        end
        
        if canSpawn then
            local spawnX, spawnY = building:getSpawnPos()
            local newPeon = Peon.new({worldX = spawnX, worldY = spawnY, map = map, team = building.team})
            setupPeonCallbacks(newPeon)
            pushUnitOutOfBuildings(newPeon)
            table.insert(peons, newPeon)
            
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
    local playerTeam = Teams and Teams.PLAYER or 1
    for _, peon in ipairs(peons) do
        local peonTownHall = townHall  -- Default to player's townhall
        if peon.team ~= playerTeam and enemyTownHall then
            peonTownHall = enemyTownHall
        end
        peon:update(gameDt, buildings, peonTownHall, goldMines[1], resources, allUnits, allBuildings)
    end
    
    -- Footmen
    for _, footman in ipairs(footmen) do
        footman:update(gameDt, buildings, allUnits, allBuildings)
    end
    
    -- Archers
    for _, archer in ipairs(archers) do
        archer:update(gameDt, buildings, allUnits, allBuildings)
    end
    
    -- Knights
    for _, knight in ipairs(knights) do
        knight:update(gameDt, buildings, allUnits, allBuildings)
    end
    
    -- Flying Scouts
    for _, unit in ipairs(flyingScouts) do
        unit:update(gameDt, buildings, allUnits, allBuildings)
    end
    
    -- Ballistas
    for _, unit in ipairs(ballistas) do
        unit:update(gameDt, buildings, allUnits, allBuildings)
    end
    
    -- Kamikazes
    for _, unit in ipairs(kamikazes) do
        unit:update(gameDt, buildings, allUnits, allBuildings)
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
    
    -- Separate overlapping units
    separateUnits()
    
    -- Ensure no units are inside buildings (safety check)
    local allUnits = getAllUnits()
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
        notifications[i].timer = notifications[i].timer - gameDt
        if notifications[i].timer <= 0 then
            table.remove(notifications, i)
        end
    end
    
    if checkAllMinesDepleted() then
        victory = true
        Game.finalTime = elapsedTime
    end
end

function Gameplay.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Background color (dark stone)
    love.graphics.setColor(UI.stoneDark)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    map:draw()
    
    love.graphics.setScissor(map.viewportX, map.viewportY, map.viewportW, map.viewportH)
    
    -- Draw all buildings
    for _, farm in ipairs(farms) do farm:draw() end
    for _, barrack in ipairs(barracks) do barrack:draw() end
    for _, building in ipairs(lumberMills) do building:draw() end
    for _, building in ipairs(blacksmiths) do building:draw() end
    for _, building in ipairs(scoutTowers) do building:draw() end
    for _, building in ipairs(archeryRanges) do building:draw() end
    for _, building in ipairs(stables) do building:draw() end
    for _, building in ipairs(siegeWorkshops) do building:draw() end
    for _, building in ipairs(townHalls) do building:draw() end
    townHall:draw()
    for _, mine in ipairs(goldMines) do mine:draw() end
    
    -- Draw all units
    for _, peon in ipairs(peons) do peon:draw() end
    for _, footman in ipairs(footmen) do footman:draw() end
    for _, archer in ipairs(archers) do archer:draw() end
    for _, knight in ipairs(knights) do knight:draw() end
    for _, unit in ipairs(flyingScouts) do unit:draw() end
    for _, unit in ipairs(ballistas) do unit:draw() end
    for _, unit in ipairs(kamikazes) do unit:draw() end
    
    -- Draw particle effects (dust, sparks, etc)
    if Effects then Effects.draw(map) end
    
    drawBuildingPlacement()
    drawBoxSelection()
    
    love.graphics.setScissor()
    
    -- Draw new UI elements
    drawTopBar(screenW)
    drawMinimap(screenW)
    drawBottomPanel(screenW, screenH)
    
    -- Draw entity-specific UI (buttons etc)
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.drawUI then selEntity:drawUI() end
    
    -- Draw notifications
    love.graphics.setFont(Game.fonts.medium)
    for i, notif in ipairs(notifications) do
        local alpha = math.min(1, notif.timer)
        local y = screenH / 2 - 50 + (i - 1) * 30
        -- Stone-themed notification background
        love.graphics.setColor(UI.stoneDark[1], UI.stoneDark[2], UI.stoneDark[3], alpha * 0.9)
        local textW = Game.fonts.medium:getWidth(notif.text)
        love.graphics.rectangle("fill", (screenW - textW) / 2 - 15, y - 8, textW + 30, 34, 4)
        love.graphics.setColor(UI.metalBronze[1], UI.metalBronze[2], UI.metalBronze[3], alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", (screenW - textW) / 2 - 15, y - 8, textW + 30, 34, 4)
        -- Text
        love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], alpha)
        love.graphics.print(notif.text, (screenW - textW) / 2, y)
    end
    
    if victory then drawVictoryScreen() end
    if defeat then drawDefeatScreen() end
    
    -- Draw custom cursor (always on top)
    drawCursor()
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Gameplay.keypressed(key)
    if victory or defeat then
        if key == "space" or key == "return" then 
            -- Return to title screen
            Game.SceneManager.switch("title")
        end
        return
    end
    
    if key == "escape" then
        if isPlacingBuilding then
            cancelBuildingPlacement()
        else
            clearSelection()
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
    end
end

function Gameplay.mousepressed(x, y, button)
    if victory or defeat then return end
    
    -- Building placement
    if isPlacingBuilding then
        if button == 1 and placementValid and map:isInViewport(x, y) then
            local costGold, costLumber = getBuildingCost(placingBuildingType)
            -- Don't deduct cost here - peon will check and deduct when arriving at site
            placingPeon:goToBuild(placementGridX, placementGridY, placingBuildingType, createBuilding, costGold, costLumber)
            cancelBuildingPlacement()
            return
        elseif button == 2 then
            cancelBuildingPlacement()
            return
        end
        return
    end
    
    -- Entity UI clicks
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.mousepressed then selEntity:mousepressed(x, y, button) end
    
    -- Minimap
    if button == 1 and map:minimapClick(x, y) then return end
    
    if not map:isInViewport(x, y) then return end
    
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
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.mousereleased then selEntity:mousereleased(x, y, button) end
    
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
        
        if boxW < 5 and boxH < 5 then
            handleLeftClick(x, y)
        else
            clearSelection()
            
            -- Select all PLAYER-OWNED unit types in box
            for _, peon in ipairs(peons) do
                if isPlayerOwned(peon) and peon:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    peon.selected = true
                    table.insert(selectedEntities, peon)
                end
            end
            for _, footman in ipairs(footmen) do
                if isPlayerOwned(footman) and footman:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    footman.selected = true
                    table.insert(selectedEntities, footman)
                end
            end
            for _, archer in ipairs(archers) do
                if isPlayerOwned(archer) and archer:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    archer.selected = true
                    table.insert(selectedEntities, archer)
                end
            end
            for _, knight in ipairs(knights) do
                if isPlayerOwned(knight) and knight:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    knight.selected = true
                    table.insert(selectedEntities, knight)
                end
            end
            for _, unit in ipairs(flyingScouts) do
                if isPlayerOwned(unit) and unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    unit.selected = true
                    table.insert(selectedEntities, unit)
                end
            end
            for _, unit in ipairs(ballistas) do
                if isPlayerOwned(unit) and unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    unit.selected = true
                    table.insert(selectedEntities, unit)
                end
            end
            for _, unit in ipairs(kamikazes) do
                if isPlayerOwned(unit) and unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    unit.selected = true
                    table.insert(selectedEntities, unit)
                end
            end
        end
    end
end

function handleLeftClick(x, y)
    clearSelection()
    
    -- Check all PLAYER-OWNED unit types
    for _, peon in ipairs(peons) do
        if peon.visible and isPlayerOwned(peon) and peon:containsPoint(x, y) then
            peon.selected = true
            table.insert(selectedEntities, peon)
            return
        end
    end
    
    for _, footman in ipairs(footmen) do
        if isPlayerOwned(footman) and footman:containsPoint(x, y) then
            footman.selected = true
            table.insert(selectedEntities, footman)
            return
        end
    end
    
    for _, archer in ipairs(archers) do
        if isPlayerOwned(archer) and archer:containsPoint(x, y) then
            archer.selected = true
            table.insert(selectedEntities, archer)
            return
        end
    end
    
    for _, knight in ipairs(knights) do
        if isPlayerOwned(knight) and knight:containsPoint(x, y) then
            knight.selected = true
            table.insert(selectedEntities, knight)
            return
        end
    end
    
    for _, unit in ipairs(flyingScouts) do
        if isPlayerOwned(unit) and unit:containsPoint(x, y) then
            unit.selected = true
            table.insert(selectedEntities, unit)
            return
        end
    end
    
    for _, unit in ipairs(ballistas) do
        if isPlayerOwned(unit) and unit:containsPoint(x, y) then
            unit.selected = true
            table.insert(selectedEntities, unit)
            return
        end
    end
    
    for _, unit in ipairs(kamikazes) do
        if isPlayerOwned(unit) and unit:containsPoint(x, y) then
            unit.selected = true
            table.insert(selectedEntities, unit)
            return
        end
    end
    
    -- ENEMY UNITS - selectable for viewing HP (no controls)
    for _, peon in ipairs(peons) do
        if peon.visible and not isPlayerOwned(peon) and peon:containsPoint(x, y) then
            peon.selected = true
            table.insert(selectedEntities, peon)
            return
        end
    end
    
    for _, footman in ipairs(footmen) do
        if not isPlayerOwned(footman) and footman:containsPoint(x, y) then
            footman.selected = true
            table.insert(selectedEntities, footman)
            return
        end
    end
    
    -- Check PLAYER-OWNED buildings (main townhall is always player's)
    if isPlayerOwned(townHall) and townHall:containsPoint(x, y) then
        townHall.selected = true
        table.insert(selectedEntities, townHall)
        return
    end
    
    for _, barrack in ipairs(barracks) do
        if isPlayerOwned(barrack) and barrack:containsPoint(x, y) then
            barrack.selected = true
            table.insert(selectedEntities, barrack)
            return
        end
    end
    
    for _, farm in ipairs(farms) do
        if isPlayerOwned(farm) and farm:containsPoint(x, y) then
            farm.selected = true
            table.insert(selectedEntities, farm)
            return
        end
    end
    
    for _, building in ipairs(lumberMills) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(blacksmiths) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(scoutTowers) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(archeryRanges) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(stables) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(siegeWorkshops) do
        if isPlayerOwned(building) and building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    -- ENEMY BUILDINGS - selectable for viewing HP (no controls)
    -- Check additional townhalls (includes enemy townhall)
    for _, building in ipairs(townHalls) do
        if building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    -- Enemy barracks
    for _, barrack in ipairs(barracks) do
        if not isPlayerOwned(barrack) and barrack:containsPoint(x, y) then
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
    local playerTeam = Teams and Teams.PLAYER or 1
    
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
        for _, entity in ipairs(selectedEntities) do
            if entity.setAttackTarget then
                entity:setAttackTarget(target)
            end
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
    
    -- Command all selected units
    for _, entity in ipairs(selectedEntities) do
        if entity.type == "peon" then
            local peon = entity
            
            if clickedMine then
                peon:goToMine(clickedMine)
            elseif clickedTownHall then
                if peon.carryingGold > 0 or peon.carryingLumber > 0 then
                    peon.state = Peon.STATE_RETURNING
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

return Gameplay
