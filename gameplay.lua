--[[
    Gameplay Scene
    RTS Resource Gathering with scrolling map
]]

local Map = require("map")
local TownHall = require("townhall")
local GoldMine = require("goldmine")
local Peon = require("peon")
local Farm = require("farm")
local Barracks = require("barracks")
local Footman = require("footman")
local FlowField = require("flowfield")

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

-- UI Layout
local UI = {
    panelColor = {0.12, 0.14, 0.18, 0.95},
    panelBorder = {0.25, 0.3, 0.4, 1},
    textColor = {0.85, 0.85, 0.9, 1},
    accentColor = {0.4, 0.6, 0.8, 1},
    headerColor = {0.6, 0.7, 0.85, 1}
}

local function checkAllMinesDepleted()
    for _, mine in ipairs(goldMines) do
        if not mine.depleted then return false end
    end
    return true
end

local function calculatePopulation()
    currentPop = #peons + #footmen
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
    return buildings
end

local function separateUnits()
    local allUnits = {}
    for _, p in ipairs(peons) do if p.visible then table.insert(allUnits, p) end end
    for _, f in ipairs(footmen) do table.insert(allUnits, f) end
    
    -- Multiple passes for better separation
    for pass = 1, 3 do
        for i = 1, #allUnits do
            for j = i + 1, #allUnits do
                local a, b = allUnits[i], allUnits[j]
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
                    
                    -- Only apply if the new position is passable
                    if map:isWorldPosPassable(ax, ay) then
                        a.worldX, a.worldY = ax, ay
                    end
                    if map:isWorldPosPassable(bx, by) then
                        b.worldX, b.worldY = bx, by
                    end
                elseif dist < 0.1 then
                    -- Exactly overlapping, push in random direction
                    local angle = math.random() * math.pi * 2
                    local push = minDist / 2 + 1
                    local ax = a.worldX + math.cos(angle) * push
                    local ay = a.worldY + math.sin(angle) * push
                    if map:isWorldPosPassable(ax, ay) then
                        a.worldX, a.worldY = ax, ay
                    end
                end
            end
        end
    end
end

local function drawTopBar(screenW)
    local barHeight = 60
    love.graphics.setColor(UI.panelColor)
    love.graphics.rectangle("fill", 0, 0, screenW, barHeight)
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, barHeight, screenW, barHeight)
    
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("RESOURCE GATHERING", 20, 18)
    
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.5, 0.8, 0.5, 1)
    love.graphics.print("WASD/Arrows: scroll | Drag: box select | Deplete mines to WIN!", 250, 22)
    
    love.graphics.setColor(UI.textColor)
    love.graphics.print(string.format("Time: %02d:%02d", math.floor(elapsedTime/60), math.floor(elapsedTime%60)), screenW - 100, 22)
end

local function drawInfoPanel(startY, height)
    local panelW, panelX = 200, 10
    love.graphics.setColor(UI.panelColor)
    love.graphics.rectangle("fill", panelX, startY, panelW, height, 8)
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, startY, panelW, height, 8)
    
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("Resources", panelX + 15, startY + 15)
    
    love.graphics.setFont(Game.fonts.small)
    local y = startY + 50
    
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("Gold:", panelX + 20, y)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(resources.gold), panelX + 100, y)
    y = y + 22
    
    love.graphics.setColor(0.6, 0.4, 0.2, 1)
    love.graphics.print("Lumber:", panelX + 20, y)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(resources.lumber), panelX + 100, y)
    y = y + 30
    
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Population:", panelX + 20, y)
    love.graphics.setColor(currentPop >= maxPop and {1, 0.4, 0.4, 1} or UI.textColor)
    love.graphics.print(currentPop .. "/" .. maxPop, panelX + 100, y)
    y = y + 22
    
    love.graphics.setColor(0.3, 0.7, 0.3, 1)
    love.graphics.print("Peons:", panelX + 20, y)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(#peons), panelX + 100, y)
    y = y + 22
    
    love.graphics.setColor(0.7, 0.3, 0.3, 1)
    love.graphics.print("Footmen:", panelX + 20, y)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(#footmen), panelX + 100, y)
    y = y + 22
    
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Mines:", panelX + 20, y)
    local activeMines = 0
    for _, m in ipairs(goldMines) do if not m.depleted then activeMines = activeMines + 1 end end
    love.graphics.setColor(UI.textColor)
    love.graphics.print(activeMines .. "/" .. #goldMines, panelX + 100, y)
    y = y + 22
    
    love.graphics.setColor(0.5, 0.6, 0.3, 1)
    love.graphics.print("Farms:", panelX + 20, y)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(#farms), panelX + 100, y)
    y = y + 22
    
    love.graphics.setColor(0.5, 0.3, 0.3, 1)
    love.graphics.print("Barracks:", panelX + 20, y)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(#barracks), panelX + 100, y)
end

local function drawRightPanel(screenW, startY, height)
    local panelW, panelX = 170, screenW - 180
    love.graphics.setColor(UI.panelColor)
    love.graphics.rectangle("fill", panelX, startY, panelW, height, 8)
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, startY, panelW, height, 8)
    
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("Selected", panelX + 15, startY + 15)
    
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(UI.textColor)
    
    local selEntity = selectedEntities[1]
    if selEntity then
        love.graphics.print("Name: " .. selEntity.name, panelX + 15, startY + 50)
        love.graphics.print("Type: " .. selEntity.type, panelX + 15, startY + 70)
        
        if #selectedEntities > 1 then
            love.graphics.setColor(0.6, 0.8, 0.6, 1)
            love.graphics.print("+" .. (#selectedEntities - 1) .. " more", panelX + 15, startY + 90)
        elseif selEntity.type == "townhall" then
            love.graphics.setColor(selEntity.isProducing and {0.3, 0.8, 0.3, 1} or {0.5, 0.5, 0.55, 1})
            love.graphics.print(selEntity.isProducing and ("Training: " .. selEntity:getProductionProgress() .. "%") or "Ready", panelX + 15, startY + 95)
        elseif selEntity.type == "goldmine" then
            love.graphics.setColor(1, 0.85, 0, 1)
            love.graphics.print("Gold: " .. selEntity.goldReserves, panelX + 15, startY + 95)
        elseif selEntity.type == "peon" then
            love.graphics.setColor(0.7, 0.8, 0.9, 1)
            love.graphics.print("Status: " .. selEntity:getStateText(), panelX + 15, startY + 95)
        elseif selEntity.type == "footman" then
            love.graphics.setColor(0.8, 0.5, 0.5, 1)
            love.graphics.print("Status: " .. selEntity:getStateText(), panelX + 15, startY + 95)
        elseif selEntity.type == "farm" then
            love.graphics.setColor(0.5, 0.7, 0.4, 1)
            love.graphics.print(selEntity.completed and ("Capacity: +" .. Farm.CAPACITY_BONUS) or ("Building: " .. selEntity:getBuildProgress() .. "%"), panelX + 15, startY + 95)
        elseif selEntity.type == "barracks" then
            if selEntity.completed then
                love.graphics.setColor(selEntity.isProducing and {0.8, 0.4, 0.4, 1} or {0.5, 0.5, 0.55, 1})
                love.graphics.print(selEntity.isProducing and ("Training: " .. selEntity:getProductionProgress() .. "%") or "Ready", panelX + 15, startY + 95)
            else
                love.graphics.setColor(0.7, 0.7, 0.4, 1)
                love.graphics.print("Building: " .. selEntity:getBuildProgress() .. "%", panelX + 15, startY + 95)
            end
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.print("Nothing selected", panelX + 15, startY + 50)
        love.graphics.print("Left-click: select", panelX + 15, startY + 70)
        love.graphics.print("Drag: box select", panelX + 15, startY + 90)
        love.graphics.print("Right-click: command", panelX + 15, startY + 110)
    end
    
    -- Minimap
    local minimapY = startY + height - 170
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("Minimap", panelX + 15, minimapY)
    
    local mmX, mmY, mmSize = panelX + 10, minimapY + 25, 150
    local mmScale = mmSize / map.width
    
    map:drawMinimap(mmX, mmY, mmSize)
    townHall:drawOnMinimap(mmX, mmY, mmScale)
    for _, m in ipairs(goldMines) do m:drawOnMinimap(mmX, mmY, mmScale) end
    for _, f in ipairs(farms) do f:drawOnMinimap(mmX, mmY, mmScale) end
    for _, b in ipairs(barracks) do b:drawOnMinimap(mmX, mmY, mmScale) end
    for _, p in ipairs(peons) do p:drawOnMinimap(mmX, mmY, mmScale) end
    for _, f in ipairs(footmen) do f:drawOnMinimap(mmX, mmY, mmScale) end
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

local function drawBuildingPlacement()
    if not isPlacingBuilding then return end
    
    local mx, my = love.mouse.getPosition()
    if not map:isInViewport(mx, my) then return end
    
    local worldX, worldY = map:screenToWorld(mx, my)
    local gridX, gridY = map:worldToGrid(worldX, worldY)
    local buildSize = placingBuildingType == "farm" and 2 or 3
    
    placementValid = map:isAreaClear(gridX, gridY, buildSize, buildSize)
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
        local farm = Farm.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        farm.builderPeon = peon
        table.insert(farms, farm)
    elseif buildingType == "barracks" then
        local barrack = Barracks.new({gridX = gridX, gridY = gridY, map = map, isBuilding = true})
        barrack.builderPeon = peon
        table.insert(barracks, barrack)
    end
    -- Invalidate all flow fields since map topology changed
    FlowField.invalidateAll()
end

local function findNearestTree(worldX, worldY)
    local gridX, gridY = map:worldToGrid(worldX, worldY)
    
    -- If clicked tile is a tree, use it
    if map:isTileTree(gridX, gridY) then
        return gridX, gridY
    end
    
    -- Search in expanding rings for nearest tree
    for radius = 1, 15 do
        local bestDist = math.huge
        local bestX, bestY = nil, nil
        
        for dy = -radius, radius do
            for dx = -radius, radius do
                -- Only check tiles on the ring edge
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local tx, ty = gridX + dx, gridY + dy
                    if map:isTileTree(tx, ty) then
                        -- Calculate distance from original click
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
    for _, b in ipairs(buildings) do
        if b.getWorldBounds then
            local bx1, by1, bx2, by2 = b:getWorldBounds()
            local closestX = math.max(bx1, math.min(unit.worldX, bx2))
            local closestY = math.max(by1, math.min(unit.worldY, by2))
            local dx = unit.worldX - closestX
            local dy = unit.worldY - closestY
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist < unit.radius then
                -- Inside building, push out
                if dist > 0.1 then
                    local pushDist = unit.radius - dist + 2
                    unit.worldX = unit.worldX + (dx / dist) * pushDist
                    unit.worldY = unit.worldY + (dy / dist) * pushDist
                else
                    -- At center, push in arbitrary direction (away from building center)
                    local bcx, bcy = b:getWorldCenter()
                    dx = unit.worldX - bcx
                    dy = unit.worldY - bcy
                    dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 0.1 then
                        local pushDist = unit.radius + (bx2 - bx1) / 2 + 5
                        unit.worldX = bcx + (dx / dist) * pushDist
                        unit.worldY = bcy + (dy / dist) * pushDist
                    else
                        unit.worldX = bx2 + unit.radius + 5
                        unit.worldY = by1 + (by2 - by1) / 2
                    end
                end
            end
        end
    end
end

local function clearSelection()
    for _, e in ipairs(selectedEntities) do e.selected = false end
    selectedEntities = {}
end

function Gameplay.load()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Clear any cached flow fields from previous game
    FlowField.invalidateAll()
    
    elapsedTime = 0
    victory = false
    resources.gold = 1000
    resources.lumber = 400
    peons = {}
    footmen = {}
    farms = {}
    barracks = {}
    goldMines = {}
    selectedEntities = {}
    isPlacingBuilding = false
    isBoxSelecting = false
    
    map = Map.new()
    map:setViewport(220, 70, screenW - 400, screenH - 90)
    
    local buildingSize = 3
    local thGridX, thGridY = map:findClearArea(buildingSize, buildingSize, 10, 30, 15)
    townHall = TownHall.new({gridX = thGridX, gridY = thGridY, map = map})
    
    local m1X, m1Y = map:findClearArea(buildingSize, buildingSize, thGridX + 8, thGridY + 5, 10)
    table.insert(goldMines, GoldMine.new({gridX = m1X, gridY = m1Y, gold = 50000, map = map}))
    
    local m2X, m2Y = map:findClearArea(buildingSize, buildingSize, 45, 12, 15)
    table.insert(goldMines, GoldMine.new({gridX = m2X, gridY = m2Y, gold = 75000, map = map}))
    
    local m3X, m3Y = map:findClearArea(buildingSize, buildingSize, 50, 50, 15)
    table.insert(goldMines, GoldMine.new({gridX = m3X, gridY = m3Y, gold = 100000, map = map}))
    
    -- Spawn 3 starting peons (away from town hall)
    local spawnX, spawnY = townHall:getSpawnPos()
    for i = 1, 3 do
        local newPeon = Peon.new({
            worldX = spawnX + (i - 1) * 35,
            worldY = spawnY + (i - 2) * 30,
            map = map
        })
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)
    end
    
    calculatePopulation()
    
    local thCenterX, thCenterY = townHall:getWorldCenter()
    map:centerOn(thCenterX, thCenterY)
end

function Gameplay.update(dt)
    if victory then return end
    
    elapsedTime = elapsedTime + dt
    map:update(dt)
    calculatePopulation()
    
    local buildings = getAllBuildings()
    
    -- Town hall
    if townHall:update(dt) and currentPop < maxPop then
        local spawnX, spawnY = townHall:getSpawnPos()
        local newPeon = Peon.new({worldX = spawnX, worldY = spawnY, map = map})
        pushUnitOutOfBuildings(newPeon)
        table.insert(peons, newPeon)
        calculatePopulation()
    end
    
    -- Gold mines
    for _, mine in ipairs(goldMines) do mine:update(dt) end
    
    -- Farms
    for _, farm in ipairs(farms) do
        if farm:update(dt) and farm.builderPeon then
            farm.builderPeon:finishBuilding()
            farm.builderPeon = nil
            calculatePopulation()
        end
    end
    
    -- Barracks
    for _, barrack in ipairs(barracks) do
        local footmanReady, buildComplete = barrack:update(dt)
        if buildComplete and barrack.builderPeon then
            barrack.builderPeon:finishBuilding()
            barrack.builderPeon = nil
        end
        if footmanReady and currentPop < maxPop then
            local spawnX, spawnY = barrack:getSpawnPos()
            local newFootman = Footman.new({worldX = spawnX, worldY = spawnY, map = map})
            pushUnitOutOfBuildings(newFootman)
            table.insert(footmen, newFootman)
            calculatePopulation()
        end
    end
    
    -- Peons
    for _, peon in ipairs(peons) do
        local goldDep, lumberDep = peon:update(dt, townHall, buildings)
        resources.gold = resources.gold + goldDep
        resources.lumber = resources.lumber + lumberDep
    end
    
    -- Footmen
    for _, footman in ipairs(footmen) do
        footman:update(dt, buildings)
    end
    
    -- Separate overlapping units
    separateUnits()
    
    -- Update selected entity UI
    local screenW, screenH = love.graphics.getDimensions()
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.updateUI then
        if selEntity.type == "peon" then
            selEntity:updateUI(resources, screenW, screenH, Game.fonts.small, startBuildingPlacement)
        elseif selEntity.type == "townhall" or selEntity.type == "barracks" then
            selEntity:updateUI(resources, screenW, screenH, Game.fonts.small, currentPop, maxPop)
        else
            selEntity:updateUI(resources, screenW, screenH, Game.fonts.small)
        end
    end
    
    if checkAllMinesDepleted() then
        victory = true
        Game.finalTime = elapsedTime
    end
end

function Gameplay.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    love.graphics.setColor(UI.panelColor)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    map:draw()
    
    love.graphics.setScissor(map.viewportX, map.viewportY, map.viewportW, map.viewportH)
    
    for _, farm in ipairs(farms) do farm:draw() end
    for _, barrack in ipairs(barracks) do barrack:draw() end
    townHall:draw()
    for _, mine in ipairs(goldMines) do mine:draw() end
    for _, peon in ipairs(peons) do peon:draw() end
    for _, footman in ipairs(footmen) do footman:draw() end
    
    drawBuildingPlacement()
    drawBoxSelection()
    
    love.graphics.setScissor()
    
    drawTopBar(screenW)
    drawInfoPanel(70, screenH - 90)
    drawRightPanel(screenW, 70, screenH - 90)
    
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.drawUI then selEntity:drawUI() end
    
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
end

function Gameplay.mousepressed(x, y, button)
    if victory then return end
    
    -- Building placement
    if isPlacingBuilding then
        if button == 1 and placementValid and map:isInViewport(x, y) then
            if placingBuildingType == "farm" then
                resources.gold = resources.gold - Farm.COST_GOLD
                resources.lumber = resources.lumber - Farm.COST_LUMBER
            else
                resources.gold = resources.gold - Barracks.COST_GOLD
                resources.lumber = resources.lumber - Barracks.COST_LUMBER
            end
            placingPeon:goToBuild(placementGridX, placementGridY, placingBuildingType, createBuilding)
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
        -- Start box selection
        isBoxSelecting = true
        boxStartX, boxStartY = x, y
        boxEndX, boxEndY = x, y
    elseif button == 2 then
        handleRightClick(x, y)
    end
end

function Gameplay.mousemoved(x, y, dx, dy)
    if isBoxSelecting then
        boxEndX, boxEndY = x, y
    end
end

function Gameplay.mousereleased(x, y, button)
    local selEntity = selectedEntities[1]
    if selEntity and selEntity.mousereleased then selEntity:mousereleased(x, y, button) end
    
    if button == 1 and isBoxSelecting then
        isBoxSelecting = false
        
        local boxW = math.abs(boxEndX - boxStartX)
        local boxH = math.abs(boxEndY - boxStartY)
        
        if boxW < 5 and boxH < 5 then
            -- Single click
            handleLeftClick(x, y)
        else
            -- Box selection
            clearSelection()
            
            -- Select units in box (peons and footmen only)
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
        end
    end
end

function handleLeftClick(x, y)
    clearSelection()
    
    -- Check peons
    for _, peon in ipairs(peons) do
        if peon.visible and peon:containsPoint(x, y) then
            peon.selected = true
            table.insert(selectedEntities, peon)
            return
        end
    end
    
    -- Check footmen
    for _, footman in ipairs(footmen) do
        if footman:containsPoint(x, y) then
            footman.selected = true
            table.insert(selectedEntities, footman)
            return
        end
    end
    
    -- Check buildings
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
    
    -- Only check for tree if clicked directly on a tree tile
    local gridX, gridY = map:worldToGrid(worldX, worldY)
    local clickedTree = map:isTileTree(gridX, gridY)
    local treeX, treeY = nil, nil
    if clickedTree then
        treeX, treeY = gridX, gridY
    end
    
    local clickedOnBuilding = false
    for _, farm in ipairs(farms) do
        if farm:containsPoint(x, y) then clickedOnBuilding = true break end
    end
    if not clickedOnBuilding then
        for _, barrack in ipairs(barracks) do
            if barrack:containsPoint(x, y) then clickedOnBuilding = true break end
        end
    end
    
    -- Generate flow field for the destination (shared by all units going there)
    local flowField = nil
    if clickedMine then
        flowField = FlowField.getField(clickedMine.gridX + 1, clickedMine.gridY + 1, map, buildings)
    elseif treeX then
        flowField = FlowField.getField(treeX, treeY, map, buildings)
    elseif not clickedOnBuilding and not clickedTownHall and map:isWorldPosPassable(worldX, worldY) then
        flowField = FlowField.getField(gridX, gridY, map, buildings)
    end
    
    -- Command all selected units
    for _, entity in ipairs(selectedEntities) do
        if entity.type == "peon" then
            local peon = entity
            
            if clickedMine then
                peon:goToMine(clickedMine, flowField)
            elseif clickedTownHall then
                if peon.carryingGold > 0 or peon.carryingLumber > 0 then
                    peon.state = Peon.STATE_RETURNING
                    peon.flowField = nil  -- Will be set in updateReturning
                else
                    peon:moveTo(worldX, worldY, flowField)
                end
            elseif treeX then
                peon:goToTree(treeX, treeY, flowField)
            elseif not clickedOnBuilding and map:isWorldPosPassable(worldX, worldY) then
                peon:moveTo(worldX, worldY, flowField)
            end
            
        elseif entity.type == "footman" then
            -- Footmen can only move
            if not clickedOnBuilding and not clickedMine and not clickedTownHall and not clickedTree and map:isWorldPosPassable(worldX, worldY) then
                entity:moveTo(worldX, worldY, flowField)
            end
        end
    end
end

return Gameplay
