--[[
    Victory Scene
    Displays the player's winning time and options to continue
]]

local Button = require("button")

local Victory = {}

local playAgainButton
local mainMenuButton

local celebrationTime = 0
local stars = {}
local starCount = 30

local colors = {
    background = {0.05, 0.08, 0.12},
    title = {1, 0.85, 0.3},
    score = {0.9, 0.9, 0.95},
    scoreLabel = {0.6, 0.7, 0.8}
}

local function createStar()
    local screenW, screenH = love.graphics.getDimensions()
    return {
        x = math.random(0, screenW),
        y = math.random(0, screenH),
        size = math.random(2, 5),
        speed = math.random(50, 150),
        angle = math.random() * math.pi * 2,
        rotSpeed = (math.random() - 0.5) * 4,
        alpha = math.random(50, 100) / 100,
        color = {
            math.random(80, 100) / 100,
            math.random(70, 90) / 100,
            math.random(20, 50) / 100
        }
    }
end

local function drawStar(x, y, innerRadius, outerRadius, points)
    local vertices = {}
    for i = 0, points * 2 - 1 do
        local angle = (i * math.pi / points) - math.pi / 2
        local radius = i % 2 == 0 and outerRadius or innerRadius
        table.insert(vertices, x + math.cos(angle) * radius)
        table.insert(vertices, y + math.sin(angle) * radius)
    end
    if #vertices >= 6 then
        love.graphics.polygon("fill", vertices)
    end
end

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    local ms = math.floor((seconds % 1) * 1000)
    return string.format("%02d:%02d.%03d", mins, secs, ms)
end

local function getPerformanceMessage(seconds)
    if seconds < 1 then
        return "Lightning Fast!"
    elseif seconds < 3 then
        return "Speed Demon!"
    elseif seconds < 5 then
        return "Quick Clicker!"
    elseif seconds < 10 then
        return "Nice Work!"
    else
        return "You took your time!"
    end
end

function Victory.load()
    local screenW, screenH = love.graphics.getDimensions()
    
    celebrationTime = 0
    
    stars = {}
    for i = 1, starCount do
        table.insert(stars, createStar())
    end
    
    local buttonWidth = 220
    local buttonHeight = 50
    local centerX = (screenW - buttonWidth) / 2
    
    playAgainButton = Button.new({
        x = centerX,
        y = screenH / 2 + 100,
        width = buttonWidth,
        height = buttonHeight,
        text = "Play Again",
        font = Game.fonts.medium,
        colors = {
            normal = {0.3, 0.6, 0.4, 1},
            hover = {0.4, 0.7, 0.5, 1},
            pressed = {0.2, 0.5, 0.3, 1},
            text = {1, 1, 1, 1},
            border = {0.2, 0.4, 0.3, 1}
        },
        onClick = function()
            Game.SceneManager.switch("gameplay")
        end
    })
    
    mainMenuButton = Button.new({
        x = centerX,
        y = screenH / 2 + 170,
        width = buttonWidth,
        height = buttonHeight,
        text = "Main Menu",
        font = Game.fonts.medium,
        onClick = function()
            Game.SceneManager.switch("title")
        end
    })
end

function Victory.update(dt)
    celebrationTime = celebrationTime + dt
    
    local screenW, screenH = love.graphics.getDimensions()
    
    for i, star in ipairs(stars) do
        star.x = star.x + math.cos(star.angle) * star.speed * dt
        star.y = star.y + math.sin(star.angle) * star.speed * dt
        star.angle = star.angle + star.rotSpeed * dt
        
        if star.x < -20 then star.x = screenW + 20 end
        if star.x > screenW + 20 then star.x = -20 end
        if star.y < -20 then star.y = screenH + 20 end
        if star.y > screenH + 20 then star.y = -20 end
    end
    
    playAgainButton:update(dt)
    mainMenuButton:update(dt)
end

function Victory.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    love.graphics.setBackgroundColor(colors.background)
    love.graphics.clear(colors.background)
    
    for i, star in ipairs(stars) do
        love.graphics.push()
        love.graphics.translate(star.x, star.y)
        love.graphics.rotate(star.angle)
        love.graphics.setColor(star.color[1], star.color[2], star.color[3], star.alpha)
        drawStar(0, 0, star.size, star.size * 2, 5)
        love.graphics.pop()
    end
    
    love.graphics.setFont(Game.fonts.title)
    local titleScale = 1 + math.sin(celebrationTime * 3) * 0.05
    local title = "VICTORY!"
    local titleWidth = Game.fonts.title:getWidth(title)
    local titleX = screenW / 2
    local titleY = screenH / 4
    
    love.graphics.setColor(1, 0.8, 0.2, 0.3)
    love.graphics.push()
    love.graphics.translate(titleX, titleY)
    love.graphics.scale(titleScale * 1.1, titleScale * 1.1)
    love.graphics.print(title, -titleWidth / 2, -Game.fonts.title:getHeight() / 2)
    love.graphics.pop()
    
    love.graphics.setColor(colors.title)
    love.graphics.push()
    love.graphics.translate(titleX, titleY)
    love.graphics.scale(titleScale, titleScale)
    love.graphics.print(title, -titleWidth / 2, -Game.fonts.title:getHeight() / 2)
    love.graphics.pop()
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(colors.scoreLabel)
    local scoreLabel = "Your Time:"
    local scoreLabelWidth = Game.fonts.medium:getWidth(scoreLabel)
    love.graphics.print(scoreLabel, (screenW - scoreLabelWidth) / 2, screenH / 2 - 30)
    
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(colors.score)
    local timeStr = formatTime(Game.finalTime or 0)
    local timeWidth = Game.fonts.large:getWidth(timeStr)
    love.graphics.print(timeStr, (screenW - timeWidth) / 2, screenH / 2 + 10)
    
    love.graphics.setFont(Game.fonts.medium)
    local performanceMsg = getPerformanceMessage(Game.finalTime or 0)
    love.graphics.setColor(0.7, 0.8, 0.9, 0.8 + math.sin(celebrationTime * 2) * 0.2)
    local msgWidth = Game.fonts.medium:getWidth(performanceMsg)
    love.graphics.print(performanceMsg, (screenW - msgWidth) / 2, screenH / 2 + 60)
    
    playAgainButton:draw()
    mainMenuButton:draw()
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Victory.keypressed(key)
    if key == "escape" then
        Game.SceneManager.switch("title")
    elseif key == "return" or key == "space" then
        Game.SceneManager.switch("gameplay")
    end
end

function Victory.mousepressed(x, y, button)
    playAgainButton:mousepressed(x, y, button)
    mainMenuButton:mousepressed(x, y, button)
end

function Victory.mousereleased(x, y, button)
    playAgainButton:mousereleased(x, y, button)
    mainMenuButton:mousereleased(x, y, button)
end

return Victory
