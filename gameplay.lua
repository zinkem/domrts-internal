--[[
    Gameplay Scene
    RTS Resource Gathering with scrolling map
]]

local Map = require("map")
local TownHall = require("townhall")
local GoldMine = require("goldmine")
local Peon = require("peon")

local Gameplay = {}

-- Game state
local elapsedTime = 0
local victory = false

local resources = {
    gold = 1000,
    lumber = 400
}

local map = nil
local townHall = nil
local goldMines = {}
local peons = {}
local selectedEntity = nil

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
        if not mine.depleted then
            return false
        end
    end
    return true
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
    love.graphics.print("WASD/Arrows to scroll | Deplete all mines to WIN!", 250, 22)
    
    love.graphics.setColor(UI.textColor)
    love.graphics.print(string.format("Time: %02d:%02d", math.floor(elapsedTime/60), math.floor(elapsedTime%60)), screenW - 100, 22)
end

local function drawInfoPanel(startY, height)
    local panelW = 200
    local panelX = 10
    
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
    y = y + 25
    
    love.graphics.setColor(0.6, 0.4, 0.2, 1)
    love.graphics.print("Lumber:", panelX + 20, y)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(resources.lumber), panelX + 100, y)
    y = y + 35
    
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Peons:", panelX + 20, y)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(#peons), panelX + 100, y)
    y = y + 25
    
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Mines:", panelX + 20, y)
    local activeMines = 0
    for _, m in ipairs(goldMines) do
        if not m.depleted then activeMines = activeMines + 1 end
    end
    love.graphics.setColor(UI.textColor)
    love.graphics.print(activeMines .. "/" .. #goldMines, panelX + 100, y)
end

local function drawRightPanel(screenW, startY, height)
    local panelW = 170
    local panelX = screenW - panelW - 10
    
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
    
    if selectedEntity then
        love.graphics.print("Name: " .. selectedEntity.name, panelX + 15, startY + 50)
        love.graphics.print("Type: " .. selectedEntity.type, panelX + 15, startY + 75)
        
        if selectedEntity.type == "townhall" then
            if selectedEntity.isProducing then
                love.graphics.setColor(0.3, 0.8, 0.3, 1)
                love.graphics.print("Training: " .. selectedEntity:getProductionProgress() .. "%", panelX + 15, startY + 100)
            else
                love.graphics.setColor(0.5, 0.5, 0.55, 1)
                love.graphics.print("Ready", panelX + 15, startY + 100)
            end
        elseif selectedEntity.type == "goldmine" then
            love.graphics.setColor(1, 0.85, 0, 1)
            love.graphics.print("Gold: " .. selectedEntity.goldReserves, panelX + 15, startY + 100)
        elseif selectedEntity.type == "peon" then
            love.graphics.setColor(0.7, 0.8, 0.9, 1)
            love.graphics.print("Status: " .. selectedEntity:getStateText(), panelX + 15, startY + 100)
            if selectedEntity.carryingGold > 0 then
                love.graphics.setColor(1, 0.85, 0, 1)
                love.graphics.print("Carrying: " .. selectedEntity.carryingGold, panelX + 15, startY + 120)
            end
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.print("Nothing selected", panelX + 15, startY + 50)
        love.graphics.print("Left-click: select", panelX + 15, startY + 75)
        love.graphics.print("Right-click: command", panelX + 15, startY + 95)
    end
    
    -- Minimap
    local minimapY = startY + height - 170
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("Minimap", panelX + 15, minimapY)
    
    local mmX = panelX + 10
    local mmY = minimapY + 25
    local mmSize = 150
    local mmScale = mmSize / map.width
    
    map:drawMinimap(mmX, mmY, mmSize)
    
    -- Draw entities on minimap
    townHall:drawOnMinimap(mmX, mmY, mmScale)
    for _, mine in ipairs(goldMines) do
        mine:drawOnMinimap(mmX, mmY, mmScale)
    end
    for _, peon in ipairs(peons) do
        peon:drawOnMinimap(mmX, mmY, mmScale)
    end
end

local function drawVictoryScreen()
    local screenW, screenH = love.graphics.getDimensions()
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    local boxW, boxH = 400, 200
    local boxX = (screenW - boxW) / 2
    local boxY = (screenH - boxH) / 2
    
    love.graphics.setColor(0.1, 0.25, 0.1, 1)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 10)
    love.graphics.setColor(0.3, 0.7, 0.3, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 10)
    
    love.graphics.setFont(Game.fonts.title)
    love.graphics.setColor(1, 0.85, 0, 1)
    local title = "VICTORY!"
    love.graphics.print(title, (screenW - Game.fonts.title:getWidth(title)) / 2, boxY + 30)
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    local msg = "All gold mines depleted!"
    love.graphics.print(msg, (screenW - Game.fonts.medium:getWidth(msg)) / 2, boxY + 100)
    
    local gold = "Final Gold: " .. resources.gold
    love.graphics.print(gold, (screenW - Game.fonts.medium:getWidth(gold)) / 2, boxY + 130)
    
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local hint = "Press SPACE to continue"
    love.graphics.print(hint, (screenW - Game.fonts.small:getWidth(hint)) / 2, boxY + 165)
end

function Gameplay.load()
    local screenW, screenH = love.graphics.getDimensions()
    
    elapsedTime = 0
    victory = false
    resources.gold = 1000
    resources.lumber = 400
    peons = {}
    goldMines = {}
    selectedEntity = nil
    
    -- Create map
    map = Map.new()
    
    -- Set viewport (game area between panels)
    local viewX = 220
    local viewY = 70
    local viewW = screenW - 400
    local viewH = screenH - 90
    map:setViewport(viewX, viewY, viewW, viewH)
    
    -- Place Town Hall near center-left of map
    local thGridX = 10
    local thGridY = 30
    townHall = TownHall.new({
        gridX = thGridX,
        gridY = thGridY,
        map = map
    })
    
    -- Place 3 Gold Mines evenly distributed
    -- Mine 1: 5 tiles diagonally from town hall
    local mine1 = GoldMine.new({
        gridX = thGridX + 8,
        gridY = thGridY + 5,
        gold = 50000,
        map = map
    })
    table.insert(goldMines, mine1)
    
    -- Mine 2: Upper right quadrant
    local mine2 = GoldMine.new({
        gridX = 45,
        gridY = 12,
        gold = 75000,
        map = map
    })
    table.insert(goldMines, mine2)
    
    -- Mine 3: Lower right quadrant
    local mine3 = GoldMine.new({
        gridX = 50,
        gridY = 50,
        gold = 100000,
        map = map
    })
    table.insert(goldMines, mine3)
    
    -- Center camera on town hall
    local thCenterX, thCenterY = townHall:getWorldCenter()
    map:centerOn(thCenterX, thCenterY)
end

function Gameplay.update(dt)
    if victory then return end
    
    elapsedTime = elapsedTime + dt
    
    -- Update map (scrolling)
    map:update(dt)
    
    -- Update town hall
    if townHall:update(dt) then
        -- Spawn peon
        local spawnX, spawnY = townHall:getSpawnPos()
        local peon = Peon.new({
            worldX = spawnX,
            worldY = spawnY,
            map = map
        })
        table.insert(peons, peon)
    end
    
    -- Update gold mines
    for _, mine in ipairs(goldMines) do
        mine:update(dt)
    end
    
    -- Update peons
    for _, peon in ipairs(peons) do
        local deposited = peon:update(dt, townHall)
        if deposited > 0 then
            resources.gold = resources.gold + deposited
        end
    end
    
    -- Update selected entity UI
    local screenW, screenH = love.graphics.getDimensions()
    if selectedEntity and selectedEntity.updateUI then
        selectedEntity:updateUI(resources, screenW, screenH, Game.fonts.small)
    end
    
    -- Check victory
    if checkAllMinesDepleted() then
        victory = true
        Game.finalTime = elapsedTime
    end
end

function Gameplay.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Background
    love.graphics.setColor(UI.panelColor)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Draw map (tiles)
    map:draw()
    
    -- Draw entities (with scissor still active from map)
    love.graphics.setScissor(map.viewportX, map.viewportY, map.viewportW, map.viewportH)
    
    townHall:draw()
    for _, mine in ipairs(goldMines) do
        mine:draw()
    end
    for _, peon in ipairs(peons) do
        peon:draw()
    end
    
    love.graphics.setScissor()
    
    -- Draw UI panels
    drawTopBar(screenW)
    drawInfoPanel(70, screenH - 90)
    drawRightPanel(screenW, 70, screenH - 90)
    
    -- Draw entity action buttons
    if selectedEntity and selectedEntity.drawUI then
        selectedEntity:drawUI()
    end
    
    -- Victory overlay
    if victory then
        drawVictoryScreen()
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Gameplay.keypressed(key)
    if victory then
        if key == "space" or key == "return" then
            Game.SceneManager.switch("victory")
        end
        return
    end
    
    if key == "escape" then
        if selectedEntity then
            selectedEntity.selected = false
            selectedEntity = nil
        end
    end
end

function Gameplay.mousepressed(x, y, button)
    if victory then return end
    
    -- Handle entity UI clicks
    if selectedEntity and selectedEntity.mousepressed then
        selectedEntity:mousepressed(x, y, button)
    end
    
    -- Check if click is in viewport
    if not map:isInViewport(x, y) then
        return
    end
    
    if button == 1 then
        handleLeftClick(x, y)
    elseif button == 2 then
        handleRightClick(x, y)
    end
end

function handleLeftClick(x, y)
    -- Deselect current
    if selectedEntity then
        selectedEntity.selected = false
        selectedEntity = nil
    end
    
    -- Check peons first
    for _, peon in ipairs(peons) do
        if peon.visible and peon:containsPoint(x, y) then
            peon.selected = true
            selectedEntity = peon
            return
        end
    end
    
    -- Check town hall
    if townHall:containsPoint(x, y) then
        townHall.selected = true
        selectedEntity = townHall
        return
    end
    
    -- Check gold mines
    for _, mine in ipairs(goldMines) do
        if mine:containsPoint(x, y) then
            mine.selected = true
            selectedEntity = mine
            return
        end
    end
end

function handleRightClick(x, y)
    if not selectedEntity or selectedEntity.type ~= "peon" then
        return
    end
    
    local peon = selectedEntity
    
    -- Convert screen to world coords for move target
    local worldX, worldY = map:screenToWorld(x, y)
    
    -- Check if clicking on a gold mine
    for _, mine in ipairs(goldMines) do
        if mine:containsPoint(x, y) and not mine.depleted then
            peon:goToMine(mine)
            return
        end
    end
    
    -- Check if clicking on town hall
    if townHall:containsPoint(x, y) then
        if peon.carryingGold > 0 then
            peon.state = Peon.STATE_RETURNING
        else
            peon:moveTo(worldX, worldY)
        end
        return
    end
    
    -- Move to location
    peon:moveTo(worldX, worldY)
end

function Gameplay.mousereleased(x, y, button)
    if selectedEntity and selectedEntity.mousereleased then
        selectedEntity:mousereleased(x, y, button)
    end
end

return Gameplay
