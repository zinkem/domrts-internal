--[[
    Gameplay Scene
    RTS Resource Gathering Game
    Harvest gold from the mine to win!
]]

local Button = require("button")
local TownHall = require("townhall")
local GoldMine = require("goldmine")
local Peon = require("peon")

local Gameplay = {}

-- Game state
local elapsedTime = 0
local gameStarted = false
local victory = false

local resources = {
    gold = 1000,
    lumber = 400
}

local townHall = nil
local goldMine = nil
local peons = {}
local selectedEntity = nil

-- Action buttons
local trainPeonButton = nil

-- UI Colors (preserved from original)
local UI = {
    padding = 10,
    panelColor = {0.12, 0.14, 0.18, 0.95},
    panelBorder = {0.25, 0.3, 0.4, 1},
    textColor = {0.85, 0.85, 0.9, 1},
    accentColor = {0.4, 0.6, 0.8, 1},
    headerColor = {0.6, 0.7, 0.85, 1},
    minimapBg = {0.08, 0.1, 0.12, 1},
    gameAreaBg = {0.2, 0.45, 0.2, 1} -- Green grass
}

-- Game area bounds
local gameArea = {
    x = 220,
    y = 80,
    w = 0,
    h = 0
}

local function formatElapsedTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    local ms = math.floor((seconds % 1) * 100)
    return string.format("%02d:%02d.%02d", mins, secs, ms)
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
    
    love.graphics.setColor(UI.textColor)
    love.graphics.setFont(Game.fonts.small)
    local timerText = "Time: " .. formatElapsedTime(elapsedTime)
    love.graphics.print(timerText, screenW - 150, 22)
    
    -- Instructions
    love.graphics.setColor(0.5, 0.8, 0.5, 1)
    local instructionText = "Deplete the mine to WIN!"
    local instructionWidth = Game.fonts.small:getWidth(instructionText)
    love.graphics.print(instructionText, (screenW - instructionWidth) / 2, 22)
end

local function drawInfoPanel(startY, height)
    local panelWidth = 200
    local panelX = 10
    local panelY = startY
    local panelHeight = height
    
    love.graphics.setColor(UI.panelColor)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8)
    
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8)
    
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("Resources", panelX + 15, panelY + 15)
    
    love.graphics.setColor(UI.panelBorder)
    love.graphics.line(panelX + 15, panelY + 50, panelX + panelWidth - 15, panelY + 50)
    
    love.graphics.setFont(Game.fonts.small)
    local infoY = panelY + 70
    local lineHeight = 28
    
    -- Gold
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("Gold:", panelX + 20, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(resources.gold), panelX + 120, infoY)
    infoY = infoY + lineHeight
    
    -- Lumber
    love.graphics.setColor(0.6, 0.4, 0.2, 1)
    love.graphics.print("Lumber:", panelX + 20, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(resources.lumber), panelX + 120, infoY)
    infoY = infoY + lineHeight + 10
    
    -- Units count
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Peons:", panelX + 20, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(#peons), panelX + 120, infoY)
    infoY = infoY + lineHeight
    
    -- Mine status
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Mine:", panelX + 20, infoY)
    if goldMine then
        if goldMine.depleted then
            love.graphics.setColor(0.8, 0.3, 0.3, 1)
            love.graphics.print("DEPLETED", panelX + 120, infoY)
        else
            love.graphics.setColor(0.3, 0.8, 0.3, 1)
            love.graphics.print(tostring(goldMine.goldReserves), panelX + 120, infoY)
        end
    end
end

local function drawRightPanel(screenW, startY, height)
    local panelWidth = 170
    local panelX = screenW - panelWidth - 10
    local panelY = startY
    local panelHeight = height
    
    love.graphics.setColor(UI.panelColor)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8)
    
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8)
    
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("Selected", panelX + 15, panelY + 15)
    
    love.graphics.setColor(UI.panelBorder)
    love.graphics.line(panelX + 15, panelY + 50, panelX + panelWidth - 15, panelY + 50)
    
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(UI.textColor)
    
    if selectedEntity then
        love.graphics.print("Name: " .. selectedEntity.name, panelX + 15, panelY + 65)
        love.graphics.print("Type: " .. selectedEntity.type, panelX + 15, panelY + 90)
        
        -- Type-specific info
        if selectedEntity.type == "townhall" then
            if selectedEntity.isProducing then
                love.graphics.setColor(0.3, 0.8, 0.3, 1)
                love.graphics.print("Training: " .. selectedEntity:getProductionProgress() .. "%", panelX + 15, panelY + 115)
            else
                love.graphics.setColor(0.5, 0.5, 0.55, 1)
                love.graphics.print("Ready to train", panelX + 15, panelY + 115)
            end
        elseif selectedEntity.type == "goldmine" then
            love.graphics.setColor(1, 0.85, 0, 1)
            love.graphics.print("Gold: " .. selectedEntity.goldReserves, panelX + 15, panelY + 115)
        elseif selectedEntity.type == "peon" then
            love.graphics.setColor(0.7, 0.8, 0.9, 1)
            love.graphics.print("Status: " .. selectedEntity:getStateText(), panelX + 15, panelY + 115)
            if selectedEntity.carryingGold > 0 then
                love.graphics.setColor(1, 0.85, 0, 1)
                love.graphics.print("Carrying: " .. selectedEntity.carryingGold, panelX + 15, panelY + 140)
            end
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.print("Nothing selected", panelX + 15, panelY + 65)
        love.graphics.print("Left-click to select", panelX + 15, panelY + 90)
        love.graphics.print("Right-click to command", panelX + 15, panelY + 115)
    end
    
    -- Minimap
    local minimapY = panelY + panelHeight - 180
    
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("Minimap", panelX + 15, minimapY)
    
    local mapX = panelX + 10
    local mapY = minimapY + 30
    local mapSize = 150
    
    -- Minimap background (green like game area)
    love.graphics.setColor(0.15, 0.3, 0.15, 1)
    love.graphics.rectangle("fill", mapX, mapY, mapSize, mapSize, 4)
    
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mapX, mapY, mapSize, mapSize, 4)
    
    -- Draw entities on minimap
    local scaleX = mapSize / gameArea.w
    local scaleY = mapSize / gameArea.h
    
    -- Town Hall on minimap
    if townHall then
        local tx = mapX + (townHall.x - gameArea.x) * scaleX
        local ty = mapY + (townHall.y - gameArea.y) * scaleY
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", tx, ty, 12, 12)
    end
    
    -- Gold Mine on minimap
    if goldMine then
        local mx = mapX + (goldMine.x - gameArea.x) * scaleX
        local my = mapY + (goldMine.y - gameArea.y) * scaleY
        if goldMine.depleted then
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
        else
            love.graphics.setColor(1, 0.85, 0, 1)
        end
        love.graphics.rectangle("fill", mx, my, 8, 8)
    end
    
    -- Peons on minimap
    love.graphics.setColor(0.3, 0.8, 0.3, 1)
    for _, peon in ipairs(peons) do
        if peon.visible then
            local px = mapX + (peon.x - gameArea.x) * scaleX
            local py = mapY + (peon.y - gameArea.y) * scaleY
            love.graphics.circle("fill", px, py, 3)
        end
    end
end

local function drawActionButtons()
    if trainPeonButton then
        trainPeonButton:draw()
    end
end

local function drawGameArea()
    -- Green grass background
    love.graphics.setColor(0.25, 0.5, 0.25, 1)
    love.graphics.rectangle("fill", gameArea.x, gameArea.y, gameArea.w, gameArea.h, 8)
    
    -- Grass texture variation
    love.graphics.setColor(0.3, 0.55, 0.3, 0.4)
    for i = 1, 40 do
        local gx = gameArea.x + ((i * 73) % gameArea.w)
        local gy = gameArea.y + ((i * 47) % gameArea.h)
        love.graphics.circle("fill", gx, gy, 15 + (i % 10))
    end
    
    -- Border
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", gameArea.x, gameArea.y, gameArea.w, gameArea.h, 8)
    
    -- Draw entities
    if townHall then
        townHall:draw()
    end
    
    if goldMine then
        goldMine:draw()
    end
    
    for _, peon in ipairs(peons) do
        peon:draw()
    end
end

local function drawVictoryScreen()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Victory box
    local boxWidth = 400
    local boxHeight = 200
    local boxX = (screenW - boxWidth) / 2
    local boxY = (screenH - boxHeight) / 2
    
    love.graphics.setColor(0.1, 0.25, 0.1, 1)
    love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, 10)
    
    love.graphics.setColor(0.3, 0.7, 0.3, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, 10)
    
    -- Victory text
    love.graphics.setFont(Game.fonts.title)
    love.graphics.setColor(1, 0.85, 0, 1)
    local title = "VICTORY!"
    local titleWidth = Game.fonts.title:getWidth(title)
    love.graphics.print(title, (screenW - titleWidth) / 2, boxY + 30)
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    local msg1 = "The gold mine has been depleted!"
    local msg1Width = Game.fonts.medium:getWidth(msg1)
    love.graphics.print(msg1, (screenW - msg1Width) / 2, boxY + 100)
    
    local msg2 = "Final Gold: " .. resources.gold
    local msg2Width = Game.fonts.medium:getWidth(msg2)
    love.graphics.print(msg2, (screenW - msg2Width) / 2, boxY + 130)
    
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local msg3 = "Press SPACE or ENTER to continue"
    local msg3Width = Game.fonts.small:getWidth(msg3)
    love.graphics.print(msg3, (screenW - msg3Width) / 2, boxY + 165)
end

local function updateActionButtons()
    if selectedEntity and selectedEntity.type == "townhall" then
        local screenH = love.graphics.getHeight()
        local canAfford = resources.gold >= 400
        local canProduce = selectedEntity:canProduce()
        
        if not trainPeonButton then
            trainPeonButton = Button.new({
                x = 230,
                y = screenH - 60,
                width = 150,
                height = 40,
                text = "Train Peon (400g)",
                font = Game.fonts.small,
                onClick = function()
                    if canAfford and canProduce then
                        if selectedEntity:startProduction() then
                            resources.gold = resources.gold - 400
                        end
                    end
                end
            })
        end
        
        trainPeonButton:setEnabled(canAfford and canProduce)
    else
        trainPeonButton = nil
    end
end

local function spawnPeon()
    local spawnX, spawnY = townHall:getSpawnPoint()
    local peon = Peon.new({
        x = spawnX,
        y = spawnY
    })
    table.insert(peons, peon)
end

local function deselectAll()
    if selectedEntity then
        selectedEntity.selected = false
        selectedEntity = nil
    end
end

local function selectEntity(entity)
    deselectAll()
    entity.selected = true
    selectedEntity = entity
end

function Gameplay.load()
    local screenW, screenH = love.graphics.getDimensions()
    
    elapsedTime = 0
    gameStarted = true
    victory = false
    
    resources.gold = 1000
    resources.lumber = 400
    
    peons = {}
    selectedEntity = nil
    trainPeonButton = nil
    
    -- Calculate game area
    gameArea.x = 220
    gameArea.y = 80
    gameArea.w = screenW - 400
    gameArea.h = screenH - 100
    
    -- Create Town Hall (left side of game area)
    townHall = TownHall.new({
        x = gameArea.x + 50,
        y = gameArea.y + gameArea.h / 2 - 48
    })
    
    -- Create Gold Mine (right side of game area)
    goldMine = GoldMine.new({
        x = gameArea.x + gameArea.w - 120,
        y = gameArea.y + gameArea.h / 2 - 32,
        gold = 100000
    })
end

function Gameplay.update(dt)
    if victory then
        return
    end
    
    if gameStarted then
        elapsedTime = elapsedTime + dt
    end
    
    -- Update town hall
    if townHall then
        local peonReady = townHall:update(dt)
        if peonReady then
            spawnPeon()
        end
    end
    
    -- Update gold mine
    if goldMine then
        goldMine:update(dt)
    end
    
    -- Update peons
    for _, peon in ipairs(peons) do
        local deposited = peon:update(dt, townHall)
        if deposited and deposited > 0 then
            resources.gold = resources.gold + deposited
        end
    end
    
    -- Update action buttons
    updateActionButtons()
    if trainPeonButton then
        trainPeonButton:update(dt)
    end
    
    -- Check victory condition
    if goldMine and goldMine.depleted then
        victory = true
        Game.finalTime = elapsedTime
    end
end

function Gameplay.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Background
    love.graphics.setColor(UI.panelColor)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Draw game area first
    drawGameArea()
    
    -- Draw UI panels
    drawTopBar(screenW)
    drawInfoPanel(gameArea.y, gameArea.h)
    drawRightPanel(screenW, gameArea.y, gameArea.h)
    
    -- Draw action buttons
    drawActionButtons()
    
    -- Draw victory screen if won
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
        deselectAll()
    end
end

function Gameplay.mousepressed(x, y, button)
    if victory then
        return
    end
    
    -- Handle action button clicks
    if trainPeonButton then
        trainPeonButton:mousepressed(x, y, button)
    end
    
    -- Only handle game area clicks
    if x < gameArea.x or x > gameArea.x + gameArea.w or
       y < gameArea.y or y > gameArea.y + gameArea.h then
        return
    end
    
    if button == 1 then
        -- Left click - select
        handleLeftClick(x, y)
    elseif button == 2 then
        -- Right click - command
        handleRightClick(x, y)
    end
end

function handleLeftClick(x, y)
    deselectAll()
    
    -- Check peons first (they're on top)
    for _, peon in ipairs(peons) do
        if peon.visible and peon:containsPoint(x, y) then
            selectEntity(peon)
            return
        end
    end
    
    -- Check town hall
    if townHall and townHall:containsPoint(x, y) then
        selectEntity(townHall)
        return
    end
    
    -- Check gold mine
    if goldMine and goldMine:containsPoint(x, y) then
        selectEntity(goldMine)
        return
    end
end

function handleRightClick(x, y)
    -- Only peons can receive right-click commands
    if not selectedEntity or selectedEntity.type ~= "peon" then
        return
    end
    
    local peon = selectedEntity
    
    -- Check if clicking on gold mine
    if goldMine and goldMine:containsPoint(x, y) and not goldMine.depleted then
        peon:goToMine(goldMine)
        return
    end
    
    -- Check if clicking on town hall
    if townHall and townHall:containsPoint(x, y) then
        if peon.carryingGold > 0 then
            peon.state = Peon.STATE_RETURNING
        else
            peon:moveTo(townHall:getCenterX(), townHall:getCenterY())
        end
        return
    end
    
    -- Otherwise, move to location
    peon:moveTo(x, y)
end

function Gameplay.mousereleased(x, y, button)
    if trainPeonButton then
        trainPeonButton:mousereleased(x, y, button)
    end
end

return Gameplay
