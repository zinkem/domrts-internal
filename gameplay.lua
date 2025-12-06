--[[
    Gameplay Scene
    RTS Resource Gathering with scrolling map
    Includes full tech tree with all buildings and units
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

local Gameplay = {}

-- Game state
local elapsedTime = 0
local victory = false

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

local function calculatePopulation()
    currentPop = #peons + #footmen + #archers + #knights + #flyingScouts + #ballistas + #kamikazes
    maxPop = BASE_CAPACITY
    for _, farm in ipairs(farms) do
        if farm.completed then maxPop = maxPop + Farm.CAPACITY_BONUS end
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
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    local boxW, boxH = 400, 200
    local boxX, boxY = (screenW - boxW) / 2, (screenH - boxH) / 2
    
    love.graphics.setColor(0.1, 0.25, 0.1, 1)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 10)
    love.graphics.setColor(0.3, 0.7, 0.3, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 10)
    
    love.graphics.setFont(Game.fonts.title)
    love.graphics.setColor(1, 0.85, 0, 1)
    love.graphics.print("VICTORY!", (screenW - Game.fonts.title:getWidth("VICTORY!")) / 2, boxY + 30)
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("All gold mines depleted!", (screenW - Game.fonts.medium:getWidth("All gold mines depleted!")) / 2, boxY + 100)
    love.graphics.print("Final Gold: " .. resources.gold, (screenW - Game.fonts.medium:getWidth("Final Gold: " .. resources.gold)) / 2, boxY + 130)
    
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Press SPACE to continue", (screenW - Game.fonts.small:getWidth("Press SPACE to continue")) / 2, boxY + 165)
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

local function createBuilding(gridX, gridY, buildingType, peon)
    if buildingType == "farm" then
        local building = Farm.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        building.builderPeon = peon
        table.insert(farms, building)
    elseif buildingType == "barracks" then
        local building = Barracks.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        building.builderPeon = peon
        table.insert(barracks, building)
    elseif buildingType == "lumbermill" then
        local building = LumberMill.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        building.builderPeon = peon
        table.insert(lumberMills, building)
    elseif buildingType == "blacksmith" then
        local building = Blacksmith.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        building.builderPeon = peon
        table.insert(blacksmiths, building)
    elseif buildingType == "scouttower" then
        local building = ScoutTower.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        building.builderPeon = peon
        table.insert(scoutTowers, building)
    elseif buildingType == "archeryrange" then
        local building = ArcheryRange.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        building.builderPeon = peon
        table.insert(archeryRanges, building)
    elseif buildingType == "stable" then
        local building = Stable.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        building.builderPeon = peon
        -- Set callback for Paladin upgrade
        building.onPaladinUpgrade = function()
            for _, knight in ipairs(knights) do
                knight:upgradeToPaladin()
            end
        end
        table.insert(stables, building)
    elseif buildingType == "siegeworkshop" then
        local building = SiegeWorkshop.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        building.builderPeon = peon
        table.insert(siegeWorkshops, building)
    elseif buildingType == "townhall" then
        local building = TownHall.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
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

-- Setup callbacks for peons to check resources and send notifications
local function setupPeonCallbacks(peon)
    peon.onNotify = addNotification
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
end

function Gameplay.load()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Pathfinding computed on-demand, no need to invalidate
    
    elapsedTime = 0
    victory = false
    resources.gold = 1000
    resources.lumber = 400
    notifications = {}
    peons = {}
    footmen = {}
    farms = {}
    barracks = {}
    goldMines = {}
    
    -- Clear new building tables
    lumberMills = {}
    blacksmiths = {}
    scoutTowers = {}
    archeryRanges = {}
    stables = {}
    siegeWorkshops = {}
    townHalls = {}
    
    -- Clear new unit tables
    archers = {}
    knights = {}
    flyingScouts = {}
    ballistas = {}
    kamikazes = {}
    
    selectedEntities = {}
    isPlacingBuilding = false
    isBoxSelecting = false
    
    map = Map.new()
    map:setViewport(0, UI.topBarHeight, screenW, screenH - UI.topBarHeight)
    
    local buildingSize = 3
    local thGridX, thGridY = map:findClearArea(buildingSize, buildingSize, 10, 30, 15)
    townHall = TownHall.new({gridX = thGridX, gridY = thGridY, map = map})
    
    local m1X, m1Y = map:findClearArea(buildingSize, buildingSize, thGridX + 8, thGridY + 5, 10)
    table.insert(goldMines, GoldMine.new({gridX = m1X, gridY = m1Y, gold = 50000, map = map}))
    
    local m2X, m2Y = map:findClearArea(buildingSize, buildingSize, 45, 12, 15)
    table.insert(goldMines, GoldMine.new({gridX = m2X, gridY = m2Y, gold = 75000, map = map}))
    
    local m3X, m3Y = map:findClearArea(buildingSize, buildingSize, 50, 50, 15)
    table.insert(goldMines, GoldMine.new({gridX = m3X, gridY = m3Y, gold = 100000, map = map}))
    
    local spawnX, spawnY = townHall:getSpawnPos()
    for i = 1, 3 do
        local newPeon = Peon.new({
            worldX = spawnX + (i - 1) * 35,
            worldY = spawnY + (i - 2) * 30,
            map = map
        })
        setupPeonCallbacks(newPeon)
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)
    end
    
    calculatePopulation()
    updateRequirementsState()
    
    local thCenterX, thCenterY = townHall:getWorldCenter()
    map:centerOn(thCenterX, thCenterY)
end

function Gameplay.update(dt)
    if victory then return end
    
    -- Apply game speed multiplier
    local gameDt = dt * Game.settings.gameSpeed
    
    elapsedTime = elapsedTime + gameDt
    map:update(dt)  -- Camera stays at real-time for responsiveness
    calculatePopulation()
    updateRequirementsState()
    
    local buildings = getAllBuildings()
    
    -- Town hall
    local peonReady, upgradeComplete, _ = townHall:update(gameDt)
    if peonReady and currentPop < maxPop then
        local spawnX, spawnY = townHall:getSpawnPos()
        local newPeon = Peon.new({worldX = spawnX, worldY = spawnY, map = map})
        setupPeonCallbacks(newPeon)
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)
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
                local newUnit = Footman.new({worldX = spawnX, worldY = spawnY, map = map})
                pushUnitOutOfBuildings(newUnit)
                table.insert(footmen, newUnit)
            elseif unitType == "knight" then
                local newUnit = Knight.new({worldX = spawnX, worldY = spawnY, map = map})
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
            local newUnit = Archer.new({worldX = spawnX, worldY = spawnY, map = map})
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
                local newUnit = FlyingScout.new({worldX = spawnX, worldY = spawnY, map = map})
                pushUnitOutOfBuildings(newUnit)
                table.insert(flyingScouts, newUnit)
            elseif unitType == "ballista" then
                local newUnit = Ballista.new({worldX = spawnX, worldY = spawnY, map = map})
                pushUnitOutOfBuildings(newUnit)
                table.insert(ballistas, newUnit)
            elseif unitType == "kamikaze" then
                local newUnit = Kamikaze.new({worldX = spawnX, worldY = spawnY, map = map})
                pushUnitOutOfBuildings(newUnit)
                table.insert(kamikazes, newUnit)
            end
            calculatePopulation()
        end
    end
    
    -- Additional Town Halls
    for _, building in ipairs(townHalls) do
        local peonReady, upgradeComplete, buildComplete = building:update(gameDt)
        if buildComplete and building.builderPeon then
            local peon = building.builderPeon
            peon:finishBuilding(building)
            pushUnitOutOfBuildings(peon)
            building.builderPeon = nil
        end
        if peonReady and currentPop < maxPop then
            local spawnX, spawnY = building:getSpawnPos()
            local newPeon = Peon.new({worldX = spawnX, worldY = spawnY, map = map})
            setupPeonCallbacks(newPeon)
            pushUnitOutOfBuildings(newPeon)
            table.insert(peons, newPeon)
            calculatePopulation()
        end
    end
    
    -- Refresh requirements state after all building updates
    -- (ensures UI sees completed buildings on the same frame they finish)
    updateRequirementsState()
    
    -- Peons
    for _, peon in ipairs(peons) do
        peon:update(gameDt, buildings, townHall, goldMines[1], resources)
    end
    
    -- Footmen
    for _, footman in ipairs(footmen) do
        footman:update(gameDt, buildings)
    end
    
    -- Archers
    for _, archer in ipairs(archers) do
        archer:update(gameDt, buildings)
    end
    
    -- Knights
    for _, knight in ipairs(knights) do
        knight:update(gameDt, buildings)
    end
    
    -- Flying Scouts
    for _, unit in ipairs(flyingScouts) do
        unit:update(gameDt, buildings)
    end
    
    -- Ballistas
    for _, unit in ipairs(ballistas) do
        unit:update(gameDt, buildings)
    end
    
    -- Kamikazes
    for _, unit in ipairs(kamikazes) do
        unit:update(gameDt, buildings)
    end
    
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
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Gameplay.keypressed(key)
    if victory then
        if key == "space" or key == "return" then Game.SceneManager.switch("victory") end
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
    if victory then return end
    
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
    
    if isBoxSelecting then
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
    
    if button == 1 and isBoxSelecting then
        isBoxSelecting = false
        
        local boxW = math.abs(boxEndX - boxStartX)
        local boxH = math.abs(boxEndY - boxStartY)
        
        if boxW < 5 and boxH < 5 then
            handleLeftClick(x, y)
        else
            clearSelection()
            
            -- Select all unit types in box
            for _, peon in ipairs(peons) do
                if peon:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    peon.selected = true
                    table.insert(selectedEntities, peon)
                end
            end
            for _, footman in ipairs(footmen) do
                if footman:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    footman.selected = true
                    table.insert(selectedEntities, footman)
                end
            end
            for _, archer in ipairs(archers) do
                if archer:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    archer.selected = true
                    table.insert(selectedEntities, archer)
                end
            end
            for _, knight in ipairs(knights) do
                if knight:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    knight.selected = true
                    table.insert(selectedEntities, knight)
                end
            end
            for _, unit in ipairs(flyingScouts) do
                if unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    unit.selected = true
                    table.insert(selectedEntities, unit)
                end
            end
            for _, unit in ipairs(ballistas) do
                if unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    unit.selected = true
                    table.insert(selectedEntities, unit)
                end
            end
            for _, unit in ipairs(kamikazes) do
                if unit:isInBox(boxStartX, boxStartY, boxEndX, boxEndY) then
                    unit.selected = true
                    table.insert(selectedEntities, unit)
                end
            end
        end
    end
end

function handleLeftClick(x, y)
    clearSelection()
    
    -- Check all unit types
    for _, peon in ipairs(peons) do
        if peon.visible and peon:containsPoint(x, y) then
            peon.selected = true
            table.insert(selectedEntities, peon)
            return
        end
    end
    
    for _, footman in ipairs(footmen) do
        if footman:containsPoint(x, y) then
            footman.selected = true
            table.insert(selectedEntities, footman)
            return
        end
    end
    
    for _, archer in ipairs(archers) do
        if archer:containsPoint(x, y) then
            archer.selected = true
            table.insert(selectedEntities, archer)
            return
        end
    end
    
    for _, knight in ipairs(knights) do
        if knight:containsPoint(x, y) then
            knight.selected = true
            table.insert(selectedEntities, knight)
            return
        end
    end
    
    for _, unit in ipairs(flyingScouts) do
        if unit:containsPoint(x, y) then
            unit.selected = true
            table.insert(selectedEntities, unit)
            return
        end
    end
    
    for _, unit in ipairs(ballistas) do
        if unit:containsPoint(x, y) then
            unit.selected = true
            table.insert(selectedEntities, unit)
            return
        end
    end
    
    for _, unit in ipairs(kamikazes) do
        if unit:containsPoint(x, y) then
            unit.selected = true
            table.insert(selectedEntities, unit)
            return
        end
    end
    
    -- Check all buildings
    if townHall:containsPoint(x, y) then
        townHall.selected = true
        table.insert(selectedEntities, townHall)
        return
    end
    
    for _, barrack in ipairs(barracks) do
        if barrack:containsPoint(x, y) then
            barrack.selected = true
            table.insert(selectedEntities, barrack)
            return
        end
    end
    
    for _, farm in ipairs(farms) do
        if farm:containsPoint(x, y) then
            farm.selected = true
            table.insert(selectedEntities, farm)
            return
        end
    end
    
    for _, building in ipairs(lumberMills) do
        if building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(blacksmiths) do
        if building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(scoutTowers) do
        if building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(archeryRanges) do
        if building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(stables) do
        if building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
    for _, building in ipairs(siegeWorkshops) do
        if building:containsPoint(x, y) then
            building.selected = true
            table.insert(selectedEntities, building)
            return
        end
    end
    
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

return Gameplay
