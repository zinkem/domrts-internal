--[[
    Gameplay Scene
    Main game area with UI prototypes
    Click once to win!
]]

local Gameplay = {}

local elapsedTime = 0
local gameStarted = false

local UI = {
    padding = 10,
    panelColor = {0.12, 0.14, 0.18, 0.95},
    panelBorder = {0.25, 0.3, 0.4, 1},
    textColor = {0.85, 0.85, 0.9, 1},
    accentColor = {0.4, 0.6, 0.8, 1},
    headerColor = {0.6, 0.7, 0.85, 1},
    minimapBg = {0.08, 0.1, 0.12, 1},
    gameAreaBg = {0.05, 0.07, 0.1, 1}
}

local gameData = {
    day = 1,
    time = "12:00",
    resources = {
        gold = 1000,
        wood = 500,
        food = 250
    },
    population = 42,
    happiness = 78
}

local minimapObjects = {}
local selectedObject = nil

local function generateMinimapObjects()
    minimapObjects = {}
    for i = 1, 12 do
        table.insert(minimapObjects, {
            x = math.random(10, 140),
            y = math.random(10, 140),
            size = math.random(3, 8),
            color = {math.random(40, 80)/100, math.random(50, 90)/100, math.random(60, 100)/100}
        })
    end
end

local function formatElapsedTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    local ms = math.floor((seconds % 1) * 100)
    return string.format("%02d:%02d.%02d", mins, secs, ms)
end

local function formatGameTime(seconds)
    local gameHour = 12 + math.floor(seconds / 10) % 12
    local gameMin = math.floor((seconds * 6) % 60)
    local ampm = gameHour >= 12 and "PM" or "AM"
    if gameHour > 12 then gameHour = gameHour - 12 end
    return string.format("%d:%02d %s", gameHour, gameMin, ampm)
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
    love.graphics.print("GAMEPLAY PROTOTYPE", 20, 18)
    
    love.graphics.setColor(UI.textColor)
    love.graphics.setFont(Game.fonts.small)
    local timerText = "Time: " .. formatElapsedTime(elapsedTime)
    love.graphics.print(timerText, screenW - 150, 22)
    
    love.graphics.setColor(0.5, 0.8, 0.5, 1)
    local instructionText = "Click the game area to WIN!"
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
    love.graphics.print("Information", panelX + 15, panelY + 15)
    
    love.graphics.setColor(UI.panelBorder)
    love.graphics.line(panelX + 15, panelY + 50, panelX + panelWidth - 15, panelY + 50)
    
    love.graphics.setFont(Game.fonts.small)
    local infoY = panelY + 70
    local lineHeight = 28
    
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Day:", panelX + 20, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(gameData.day), panelX + 120, infoY)
    infoY = infoY + lineHeight
    
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Time:", panelX + 20, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(gameData.time, panelX + 120, infoY)
    infoY = infoY + lineHeight + 10
    
    love.graphics.setColor(UI.headerColor)
    love.graphics.print("Resources", panelX + 20, infoY)
    infoY = infoY + lineHeight
    
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("Gold:", panelX + 30, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(gameData.resources.gold), panelX + 120, infoY)
    infoY = infoY + lineHeight
    
    love.graphics.setColor(0.6, 0.4, 0.2, 1)
    love.graphics.print("Wood:", panelX + 30, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(gameData.resources.wood), panelX + 120, infoY)
    infoY = infoY + lineHeight
    
    love.graphics.setColor(0.4, 0.8, 0.4, 1)
    love.graphics.print("Food:", panelX + 30, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(gameData.resources.food), panelX + 120, infoY)
    infoY = infoY + lineHeight + 10
    
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Population:", panelX + 20, infoY)
    love.graphics.setColor(UI.textColor)
    love.graphics.print(tostring(gameData.population), panelX + 120, infoY)
    infoY = infoY + lineHeight
    
    love.graphics.setColor(UI.accentColor)
    love.graphics.print("Happiness:", panelX + 20, infoY)
    infoY = infoY + lineHeight
    
    local barWidth = panelWidth - 50
    local barHeight = 12
    love.graphics.setColor(0.2, 0.2, 0.25, 1)
    love.graphics.rectangle("fill", panelX + 25, infoY, barWidth, barHeight, 4)
    
    local happinessWidth = (gameData.happiness / 100) * barWidth
    local happinessColor = gameData.happiness > 50 and {0.3, 0.7, 0.4, 1} or {0.7, 0.4, 0.3, 1}
    love.graphics.setColor(happinessColor)
    love.graphics.rectangle("fill", panelX + 25, infoY, happinessWidth, barHeight, 4)
    
    love.graphics.setColor(UI.textColor)
    love.graphics.print(gameData.happiness .. "%", panelX + 30 + barWidth/2 - 15, infoY - 2)
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
    
    if selectedObject then
        love.graphics.print("Object: " .. selectedObject.name, panelX + 15, panelY + 65)
        love.graphics.print("Type: " .. selectedObject.type, panelX + 15, panelY + 90)
        love.graphics.print("Health: " .. selectedObject.health, panelX + 15, panelY + 115)
    else
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.print("Nothing selected", panelX + 15, panelY + 65)
    end
    
    local minimapY = panelY + panelHeight - 180
    
    love.graphics.setColor(UI.headerColor)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print("Minimap", panelX + 15, minimapY)
    
    local mapX = panelX + 10
    local mapY = minimapY + 30
    local mapSize = 150
    
    love.graphics.setColor(UI.minimapBg)
    love.graphics.rectangle("fill", mapX, mapY, mapSize, mapSize, 4)
    
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mapX, mapY, mapSize, mapSize, 4)
    
    for _, obj in ipairs(minimapObjects) do
        love.graphics.setColor(obj.color)
        love.graphics.circle("fill", mapX + obj.x, mapY + obj.y, obj.size)
    end
    
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mapX + 40, mapY + 40, 70, 50)
end

local function drawGameArea(x, y, w, h)
    love.graphics.setColor(0.06, 0.08, 0.12, 1)
    love.graphics.rectangle("fill", x, y, w, h, 8)
    
    love.graphics.setColor(0.1, 0.12, 0.16, 0.5)
    local gridSize = 40
    for gx = x, x + w, gridSize do
        love.graphics.line(gx, y, gx, y + h)
    end
    for gy = y, y + h, gridSize do
        love.graphics.line(x, gy, x + w, gy)
    end
    
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 8)
    
    love.graphics.setColor(0.4, 0.5, 0.6, 0.8 + math.sin(elapsedTime * 3) * 0.2)
    love.graphics.setFont(Game.fonts.large)
    local msg = "Click Here to Win!"
    local msgWidth = Game.fonts.large:getWidth(msg)
    local msgHeight = Game.fonts.large:getHeight()
    love.graphics.print(msg, x + (w - msgWidth) / 2, y + (h - msgHeight) / 2)
end

function Gameplay.load()
    elapsedTime = 0
    gameStarted = true
    selectedObject = nil
    generateMinimapObjects()
    
    gameData.day = 1
    gameData.resources.gold = math.random(800, 1200)
    gameData.resources.wood = math.random(400, 600)
    gameData.resources.food = math.random(200, 300)
    gameData.population = math.random(30, 60)
    gameData.happiness = math.random(60, 90)
end

function Gameplay.update(dt)
    if gameStarted then
        elapsedTime = elapsedTime + dt
        gameData.time = formatGameTime(elapsedTime)
        gameData.happiness = math.floor(78 + math.sin(elapsedTime * 0.5) * 10)
    end
end

function Gameplay.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    love.graphics.setColor(UI.gameAreaBg)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    local gameAreaX = 220
    local gameAreaY = 80
    local gameAreaW = screenW - 400
    local gameAreaH = screenH - 100
    
    drawGameArea(gameAreaX, gameAreaY, gameAreaW, gameAreaH)
    drawTopBar(screenW)
    drawInfoPanel(gameAreaY, gameAreaH)
    drawRightPanel(screenW, gameAreaY, gameAreaH)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Gameplay.keypressed(key)
    if key == "escape" then
        Game.SceneManager.switch("title")
    end
end

function Gameplay.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    local screenW, screenH = love.graphics.getDimensions()
    
    local gameAreaX = 220
    local gameAreaY = 80
    local gameAreaW = screenW - 400
    local gameAreaH = screenH - 100
    
    if x >= gameAreaX and x <= gameAreaX + gameAreaW and
       y >= gameAreaY and y <= gameAreaY + gameAreaH then
        Game.finalTime = elapsedTime
        Game.SceneManager.switch("victory")
    end
end

function Gameplay.mousereleased(x, y, button)
end

return Gameplay
