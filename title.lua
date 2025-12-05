--[[
    Title Screen Scene
    Features animated background, menu buttons, settings toggles
]]

local Button = require("button")
local RadioGroup = require("radio_group")
local ConfirmModal = require("confirm_modal")

local Title = {}

local particles = {}
local particleCount = 50

local newGameButton
local exitButton
local musicToggle
local soundToggle
local exitConfirmModal

local titleWave = 0
local backgroundHue = 0

local colors = {
    background = {0.08, 0.1, 0.15},
    title = {0.9, 0.85, 0.7},
    titleGlow = {1, 0.9, 0.6, 0.3},
    copyright = {0.5, 0.5, 0.55, 1}
}

local function createParticle()
    return {
        x = math.random(0, love.graphics.getWidth()),
        y = math.random(0, love.graphics.getHeight()),
        size = math.random(2, 6),
        speed = math.random(20, 60),
        alpha = math.random(30, 80) / 100,
        wobble = math.random() * math.pi * 2,
        wobbleSpeed = math.random(1, 3)
    }
end

local function hslToRgb(h, s, l)
    if s == 0 then
        return l, l, l
    end
    
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end
    
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    
    return hue2rgb(p, q, h + 1/3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1/3)
end

function Title.load()
    local screenW, screenH = love.graphics.getDimensions()
    
    particles = {}
    for i = 1, particleCount do
        table.insert(particles, createParticle())
    end
    
    local buttonWidth = 250
    local buttonHeight = 55
    local centerX = (screenW - buttonWidth) / 2
    
    newGameButton = Button.new({
        x = centerX,
        y = screenH / 2 + 20,
        width = buttonWidth,
        height = buttonHeight,
        text = "New Game",
        font = Game.fonts.medium,
        onClick = function()
            Game.SceneManager.switch("gameplay")
        end
    })
    
    exitButton = Button.new({
        x = centerX,
        y = screenH / 2 + 90,
        width = buttonWidth,
        height = buttonHeight,
        text = "Exit to Desktop",
        font = Game.fonts.medium,
        colors = {
            normal = {0.5, 0.3, 0.3, 1},
            hover = {0.6, 0.4, 0.4, 1},
            pressed = {0.4, 0.2, 0.2, 1},
            text = {1, 1, 1, 1},
            border = {0.4, 0.25, 0.25, 1}
        },
        onClick = function()
            exitConfirmModal:show()
        end
    })
    
    musicToggle = RadioGroup.new({
        x = centerX - 20,
        y = screenH / 2 + 180,
        label = "Music",
        options = {"On", "Off"},
        selected = Game.settings.musicEnabled and 1 or 2,
        font = Game.fonts.small,
        onChange = function(index, option)
            Game.settings.musicEnabled = (index == 1)
        end
    })
    
    soundToggle = RadioGroup.new({
        x = centerX - 20,
        y = screenH / 2 + 220,
        label = "Sound",
        options = {"On", "Off"},
        selected = Game.settings.soundEnabled and 1 or 2,
        font = Game.fonts.small,
        onChange = function(index, option)
            Game.settings.soundEnabled = (index == 1)
        end
    })
    
    exitConfirmModal = ConfirmModal.new({
        message = "Are you sure you want to quit?",
        confirmText = "Quit",
        cancelText = "Cancel",
        font = Game.fonts.medium,
        onConfirm = function()
            love.event.quit()
        end,
        onCancel = function() end
    })
    
    titleWave = 0
    backgroundHue = 0
end

function Title.update(dt)
    titleWave = titleWave + dt * 2
    backgroundHue = backgroundHue + dt * 0.05
    
    for i, p in ipairs(particles) do
        p.y = p.y - p.speed * dt
        p.wobble = p.wobble + p.wobbleSpeed * dt
        p.x = p.x + math.sin(p.wobble) * 0.5
        
        if p.y < -10 then
            p.y = love.graphics.getHeight() + 10
            p.x = math.random(0, love.graphics.getWidth())
        end
    end
    
    if not exitConfirmModal:isActive() then
        newGameButton:update(dt)
        exitButton:update(dt)
        musicToggle:update(dt)
        soundToggle:update(dt)
    end
    
    exitConfirmModal:update(dt)
end

function Title.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    local bgR = 0.08 + math.sin(backgroundHue) * 0.02
    local bgG = 0.1 + math.sin(backgroundHue + 1) * 0.02
    local bgB = 0.18 + math.sin(backgroundHue + 2) * 0.03
    love.graphics.setBackgroundColor(bgR, bgG, bgB)
    love.graphics.clear(bgR, bgG, bgB)
    
    for i, p in ipairs(particles) do
        local hue = (backgroundHue + p.x / screenW) % 1
        local r, g, b = hslToRgb(hue, 0.5, 0.6)
        love.graphics.setColor(r, g, b, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
    
    love.graphics.setFont(Game.fonts.title)
    local title = "ADVENTURE AWAITS"
    local titleWidth = Game.fonts.title:getWidth(title)
    local titleX = (screenW - titleWidth) / 2
    local titleY = screenH / 4
    
    love.graphics.setColor(colors.titleGlow)
    for i = 1, #title do
        local char = title:sub(i, i)
        local charX = titleX + Game.fonts.title:getWidth(title:sub(1, i - 1))
        local charOffset = math.sin(titleWave + i * 0.3) * 5
        love.graphics.print(char, charX, titleY + charOffset)
    end
    
    love.graphics.setColor(colors.title)
    for i = 1, #title do
        local char = title:sub(i, i)
        local charX = titleX + Game.fonts.title:getWidth(title:sub(1, i - 1))
        local charOffset = math.sin(titleWave + i * 0.3) * 5
        love.graphics.print(char, charX, titleY + charOffset)
    end
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(0.7, 0.7, 0.75, 0.8 + math.sin(titleWave * 1.5) * 0.2)
    local subtitle = "Press New Game to Begin"
    local subtitleWidth = Game.fonts.medium:getWidth(subtitle)
    love.graphics.print(subtitle, (screenW - subtitleWidth) / 2, titleY + 80)
    
    newGameButton:draw()
    exitButton:draw()
    musicToggle:draw()
    soundToggle:draw()
    
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(colors.copyright)
    local copyright = "© 2025 zinkem"
    local copyrightWidth = Game.fonts.small:getWidth(copyright)
    love.graphics.print(copyright, (screenW - copyrightWidth) / 2, screenH - 40)
    
    exitConfirmModal:draw()
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Title.keypressed(key)
    if exitConfirmModal:isActive() then
        exitConfirmModal:keypressed(key)
        return
    end
    
    if key == "escape" then
        exitConfirmModal:show()
    elseif key == "return" or key == "space" then
        Game.SceneManager.switch("gameplay")
    end
end

function Title.mousepressed(x, y, button)
    if exitConfirmModal:isActive() then
        exitConfirmModal:mousepressed(x, y, button)
        return
    end
    
    newGameButton:mousepressed(x, y, button)
    exitButton:mousepressed(x, y, button)
    musicToggle:mousepressed(x, y, button)
    soundToggle:mousepressed(x, y, button)
end

function Title.mousereleased(x, y, button)
    if exitConfirmModal:isActive() then
        exitConfirmModal:mousereleased(x, y, button)
        return
    end
    
    newGameButton:mousereleased(x, y, button)
    exitButton:mousereleased(x, y, button)
end

return Title
