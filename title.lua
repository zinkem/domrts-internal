--[[
    Title Screen
    Medieval stone-themed title screen with animated background
]]

local Title = {}

-- Import UI drawing utilities
local UIDraw
pcall(function() UIDraw = require("ui_draw") end)

-- Import audio
local Audio
pcall(function() Audio = require("audio") end)

-- Local state
local animTimer = 0
local particles = {}
local buttons = {}

-- UI colors (same as main game)
local UI = {
    stoneLight = {0.32, 0.30, 0.26, 1},
    stoneMid = {0.20, 0.18, 0.16, 1},
    stoneDark = {0.10, 0.09, 0.08, 1},
    stoneHighlight = {0.48, 0.44, 0.38, 1},
    stoneShadow = {0.05, 0.04, 0.03, 1},
    metalGold = {0.72, 0.58, 0.26, 1},
    metalGoldLight = {0.88, 0.72, 0.42, 1},
    metalBronze = {0.50, 0.38, 0.20, 1},
    metalBronzeLight = {0.65, 0.50, 0.30, 1},
    metalBronzeDark = {0.30, 0.22, 0.10, 1},
    textLight = {0.92, 0.88, 0.80, 1},
    textGold = {1, 0.82, 0.25, 1},
}

-- Hash function for procedural effects
local function hash(a, b)
    local h = (a * 374761393 + b * 668265263) % 2147483647
    h = ((h * 1274126177) % 2147483647)
    return (h % 1000) / 1000
end

-- Draw stone panel (simplified from ui_draw)
local function drawStonePanel(x, y, w, h, cornerRadius, subtle)
    cornerRadius = cornerRadius or 6
    
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + 4, y + 4, w, h, cornerRadius)
    
    -- Main panel with vertical gradient
    local steps = h
    for i = 0, steps - 1 do
        local t = i / steps
        local r = UI.stoneMid[1] * (1 - t * 0.3)
        local g = UI.stoneMid[2] * (1 - t * 0.3)
        local b = UI.stoneMid[3] * (1 - t * 0.3)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", x, y + i, w, 1, i == 0 and cornerRadius or 0)
    end
    
    -- Stone texture (if not subtle)
    if not subtle then
        -- Color blotches
        local numBlotches = math.floor(w * h / 800)
        for i = 1, numBlotches do
            local bx = x + hash(i, 1) * w
            local by = y + hash(1, i) * h
            local bsize = 8 + hash(i, i) * 15
            local colorVar = (hash(i * 3, i * 5) - 0.5) * 0.06
            
            love.graphics.setColor(UI.stoneMid[1] + colorVar, UI.stoneMid[2] + colorVar, UI.stoneMid[3] + colorVar, 0.15)
            love.graphics.ellipse("fill", bx, by, bsize, bsize * 0.6)
        end
        
        -- Sparse cracks
        local numCracks = 3 + math.floor(hash(w, 1) * 4)
        for c = 1, numCracks do
            local cx = x + 10 + hash(c, 100) * (w - 20)
            local cy = y + 10 + hash(100, c) * (h - 20)
            local angle = hash(c, 101) * math.pi * 2
            local length = 10 + hash(c, 102) * 20
            
            love.graphics.setColor(0, 0, 0, 0.2)
            love.graphics.setLineWidth(1)
            local px, py = cx, cy
            for s = 1, math.floor(length / 4) do
                angle = angle + (hash(c * s, s) - 0.5) * 0.5
                local nx = px + math.cos(angle) * 4
                local ny = py + math.sin(angle) * 3
                if nx > x + 5 and nx < x + w - 5 and ny > y + 5 and ny < y + h - 5 then
                    love.graphics.line(px, py, nx, ny)
                    px, py = nx, ny
                end
            end
        end
    end
    
    -- Beveled border
    -- Top/left highlight
    love.graphics.setColor(UI.stoneHighlight[1], UI.stoneHighlight[2], UI.stoneHighlight[3], 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + cornerRadius, y + 1, x + w - cornerRadius, y + 1)
    love.graphics.line(x + 1, y + cornerRadius, x + 1, y + h - cornerRadius)
    
    -- Bottom/right shadow
    love.graphics.setColor(UI.stoneShadow[1], UI.stoneShadow[2], UI.stoneShadow[3], 0.7)
    love.graphics.line(x + cornerRadius, y + h - 1, x + w - cornerRadius, y + h - 1)
    love.graphics.line(x + w - 1, y + cornerRadius, x + w - 1, y + h - cornerRadius)
    
    -- Metal trim at bottom
    love.graphics.setColor(UI.metalBronze)
    love.graphics.rectangle("fill", x, y + h - 4, w, 4)
    love.graphics.setColor(UI.metalBronzeLight[1], UI.metalBronzeLight[2], UI.metalBronzeLight[3], 0.5)
    love.graphics.rectangle("fill", x, y + h - 4, w, 1)
end

-- Draw a rivet
local function drawRivet(cx, cy, radius)
    love.graphics.setColor(UI.metalGold)
    love.graphics.circle("fill", cx, cy, radius)
    love.graphics.setColor(UI.metalGoldLight[1], UI.metalGoldLight[2], UI.metalGoldLight[3], 0.7)
    love.graphics.circle("fill", cx - radius * 0.3, cy - radius * 0.3, radius * 0.4)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.arc("fill", cx, cy, radius * 0.8, math.pi * 0.3, math.pi * 0.7)
end

-- Draw button
local function drawButton(btn, mx, my)
    local x, y, w, h = btn.x, btn.y, btn.w, btn.h
    local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
    
    -- Button background
    if hovered then
        love.graphics.setColor(UI.stoneLight[1] + 0.05, UI.stoneLight[2] + 0.05, UI.stoneLight[3] + 0.05, 1)
    else
        love.graphics.setColor(UI.stoneMid)
    end
    love.graphics.rectangle("fill", x, y, w, h, 6)
    
    -- Beveled border
    if hovered then
        love.graphics.setColor(UI.metalGold[1], UI.metalGold[2], UI.metalGold[3], 0.8)
    else
        love.graphics.setColor(UI.metalBronze)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 6)
    
    -- Highlight
    love.graphics.setColor(UI.stoneHighlight[1], UI.stoneHighlight[2], UI.stoneHighlight[3], 0.4)
    love.graphics.line(x + 6, y + 2, x + w - 6, y + 2)
    
    -- Text
    local font = Game.fonts and Game.fonts.medium or love.graphics.getFont()
    love.graphics.setFont(font)
    local textW = font:getWidth(btn.text)
    local textH = font:getHeight()
    
    -- Text shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(btn.text, x + (w - textW) / 2 + 1, y + (h - textH) / 2 + 1)
    
    -- Text
    if hovered then
        love.graphics.setColor(UI.textGold)
    else
        love.graphics.setColor(UI.textLight)
    end
    love.graphics.print(btn.text, x + (w - textW) / 2, y + (h - textH) / 2)
    
    return hovered
end

-- Spawn ambient particles
local function spawnParticle()
    local screenW, screenH = love.graphics.getDimensions()
    table.insert(particles, {
        x = math.random(0, screenW),
        y = screenH + 10,
        vx = (math.random() - 0.5) * 20,
        vy = -30 - math.random() * 40,
        size = 1 + math.random() * 2,
        life = 3 + math.random() * 2,
        maxLife = 3 + math.random() * 2,
        type = math.random() > 0.7 and "ember" or "dust"
    })
end

function Title.load()
    animTimer = 0
    particles = {}
    
    -- Initialize audio if available
    if Audio and Audio.init then
        Audio.init()
    end
    
    -- Start music
    if Audio and Audio.playRandomMusic then
        Audio.playRandomMusic()
    end
    
    -- Setup buttons
    local screenW, screenH = love.graphics.getDimensions()
    local btnW, btnH = 200, 50
    local btnX = (screenW - btnW) / 2
    local btnY = screenH * 0.55
    
    buttons = {
        {
            text = "Start Game",
            x = btnX, y = btnY, w = btnW, h = btnH,
            action = function()
                Game.SceneManager.switch("gameplay")
            end
        },
        {
            text = "Settings",
            x = btnX, y = btnY + 70, w = btnW, h = btnH,
            action = function()
                -- Toggle settings (simple for now)
                Game.settings.musicEnabled = not Game.settings.musicEnabled
            end
        }
    }
end

function Title.update(dt)
    animTimer = animTimer + dt
    
    -- Update audio
    if Audio and Audio.update then
        Audio.update(dt)
    end
    
    -- Spawn particles occasionally
    if math.random() < dt * 2 then
        spawnParticle()
    end
    
    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function Title.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    
    -- Dark stone background
    love.graphics.setColor(UI.stoneDark)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Background texture
    for i = 1, 50 do
        local px = hash(i, 1) * screenW
        local py = hash(1, i) * screenH
        local size = 5 + hash(i, i) * 20
        local dark = hash(i * 3, i * 5) > 0.5
        
        if dark then
            love.graphics.setColor(0, 0, 0, 0.1)
        else
            love.graphics.setColor(UI.stoneLight[1], UI.stoneLight[2], UI.stoneLight[3], 0.05)
        end
        love.graphics.ellipse("fill", px, py, size, size * 0.7)
    end
    
    -- Animated particles (background embers/dust)
    for _, p in ipairs(particles) do
        local alpha = (p.life / p.maxLife) * 0.6
        if p.type == "ember" then
            love.graphics.setColor(1, 0.6, 0.2, alpha)
        else
            love.graphics.setColor(0.8, 0.75, 0.65, alpha * 0.5)
        end
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
    
    -- Main title panel
    local panelW, panelH = 500, 400
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2 - 30
    
    drawStonePanel(panelX, panelY, panelW, panelH, 10)
    
    -- Corner rivets
    local rivetOffset = 15
    drawRivet(panelX + rivetOffset, panelY + rivetOffset, 5)
    drawRivet(panelX + panelW - rivetOffset, panelY + rivetOffset, 5)
    drawRivet(panelX + rivetOffset, panelY + panelH - rivetOffset, 5)
    drawRivet(panelX + panelW - rivetOffset, panelY + panelH - rivetOffset, 5)
    
    -- Title text with glow
    local titleFont = Game.fonts and Game.fonts.title or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    
    local title = "DOMINION"
    local titleW = titleFont:getWidth(title)
    local titleX = (screenW - titleW) / 2
    local titleY = panelY + 40
    
    -- Title glow
    local glowPulse = 0.7 + math.sin(animTimer * 2) * 0.3
    love.graphics.setColor(UI.metalGold[1], UI.metalGold[2], UI.metalGold[3], 0.3 * glowPulse)
    for dx = -2, 2 do
        for dy = -2, 2 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.print(title, titleX + dx, titleY + dy)
            end
        end
    end
    
    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(title, titleX + 3, titleY + 3)
    
    -- Title main
    love.graphics.setColor(UI.textGold)
    love.graphics.print(title, titleX, titleY)
    
    -- Subtitle
    local subtitleFont = Game.fonts and Game.fonts.medium or love.graphics.getFont()
    love.graphics.setFont(subtitleFont)
    local subtitle = "A Real-Time Strategy Game"
    local subtitleW = subtitleFont:getWidth(subtitle)
    
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.print(subtitle, (screenW - subtitleW) / 2 + 1, titleY + 70 + 1)
    love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], 0.8)
    love.graphics.print(subtitle, (screenW - subtitleW) / 2, titleY + 70)
    
    -- Decorative line
    love.graphics.setColor(UI.metalBronze)
    love.graphics.setLineWidth(2)
    local lineY = titleY + 110
    love.graphics.line(panelX + 50, lineY, panelX + panelW - 50, lineY)
    
    -- Line rivets
    drawRivet(panelX + 50, lineY, 3)
    drawRivet(panelX + panelW - 50, lineY, 3)
    
    -- Buttons
    for _, btn in ipairs(buttons) do
        drawButton(btn, mx, my)
    end
    
    -- Settings indicator
    local settingsFont = Game.fonts and Game.fonts.small or love.graphics.getFont()
    love.graphics.setFont(settingsFont)
    local musicStatus = Game.settings.musicEnabled and "Music: ON" or "Music: OFF"
    local soundStatus = Game.settings.soundEnabled and "Sound: ON" or "Sound: OFF"
    
    love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], 0.6)
    love.graphics.print(musicStatus .. "  |  " .. soundStatus, panelX + 20, panelY + panelH - 35)
    
    -- Version/credits
    love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], 0.4)
    love.graphics.print("Made with LÖVE", screenW - 120, screenH - 25)
    
    -- Controls hint
    local controlsY = panelY + panelH + 20
    love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], 0.5)
    local controlsText = "Controls: Click to select, Right-click to command, Arrow keys to scroll"
    local controlsW = settingsFont:getWidth(controlsText)
    love.graphics.print(controlsText, (screenW - controlsW) / 2, controlsY)
end

function Title.keypressed(key)
    if key == "return" or key == "space" then
        Game.SceneManager.switch("gameplay")
    elseif key == "m" then
        Game.settings.musicEnabled = not Game.settings.musicEnabled
    elseif key == "s" then
        Game.settings.soundEnabled = not Game.settings.soundEnabled
    end
end

function Title.mousepressed(x, y, button)
    if button == 1 then
        for _, btn in ipairs(buttons) do
            if x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h then
                if btn.action then
                    btn.action()
                end
                return
            end
        end
    end
end

function Title.unload()
    -- Don't stop music - let it continue into gameplay
end

return Title
