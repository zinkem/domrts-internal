--[[
    Victory Screen
    Medieval stone-themed victory/results screen
]]

local Victory = {}

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

local animTimer = 0
local particles = {}

-- Draw stone panel
local function drawStonePanel(x, y, w, h, cornerRadius)
    cornerRadius = cornerRadius or 6
    
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x + 5, y + 5, w, h, cornerRadius)
    
    -- Main panel with gradient
    for i = 0, h - 1 do
        local t = i / h
        local r = UI.stoneMid[1] * (1 - t * 0.25)
        local g = UI.stoneMid[2] * (1 - t * 0.25)
        local b = UI.stoneMid[3] * (1 - t * 0.25)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", x, y + i, w, 1, i == 0 and cornerRadius or 0)
    end
    
    -- Stone texture
    local numBlotches = math.floor(w * h / 600)
    for i = 1, numBlotches do
        local bx = x + hash(i, 1) * w
        local by = y + hash(1, i) * h
        local bsize = 6 + hash(i, i) * 12
        local colorVar = (hash(i * 3, i * 5) - 0.5) * 0.05
        
        love.graphics.setColor(UI.stoneMid[1] + colorVar, UI.stoneMid[2] + colorVar, UI.stoneMid[3] + colorVar, 0.12)
        love.graphics.ellipse("fill", bx, by, bsize, bsize * 0.6)
    end
    
    -- Cracks
    local numCracks = 2 + math.floor(hash(w, 1) * 3)
    for c = 1, numCracks do
        local cx = x + 15 + hash(c, 100) * (w - 30)
        local cy = y + 15 + hash(100, c) * (h - 30)
        local angle = hash(c, 101) * math.pi * 2
        local length = 8 + hash(c, 102) * 15
        
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.setLineWidth(1)
        local px, py = cx, cy
        for s = 1, math.floor(length / 4) do
            angle = angle + (hash(c * s, s) - 0.5) * 0.5
            local nx = px + math.cos(angle) * 4
            local ny = py + math.sin(angle) * 3
            if nx > x + 8 and nx < x + w - 8 and ny > y + 8 and ny < y + h - 8 then
                love.graphics.line(px, py, nx, ny)
                px, py = nx, ny
            end
        end
    end
    
    -- Beveled border
    love.graphics.setColor(UI.stoneHighlight[1], UI.stoneHighlight[2], UI.stoneHighlight[3], 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + cornerRadius, y + 1, x + w - cornerRadius, y + 1)
    love.graphics.line(x + 1, y + cornerRadius, x + 1, y + h - cornerRadius)
    
    love.graphics.setColor(UI.stoneShadow[1], UI.stoneShadow[2], UI.stoneShadow[3], 0.6)
    love.graphics.line(x + cornerRadius, y + h - 1, x + w - cornerRadius, y + h - 1)
    love.graphics.line(x + w - 1, y + cornerRadius, x + w - 1, y + h - cornerRadius)
    
    -- Metal trim
    love.graphics.setColor(UI.metalBronze)
    love.graphics.rectangle("fill", x, y + h - 5, w, 5)
    love.graphics.setColor(UI.metalBronzeLight[1], UI.metalBronzeLight[2], UI.metalBronzeLight[3], 0.5)
    love.graphics.rectangle("fill", x, y + h - 5, w, 1)
end

-- Draw rivet
local function drawRivet(cx, cy, radius)
    love.graphics.setColor(UI.metalGold)
    love.graphics.circle("fill", cx, cy, radius)
    love.graphics.setColor(UI.metalGoldLight[1], UI.metalGoldLight[2], UI.metalGoldLight[3], 0.7)
    love.graphics.circle("fill", cx - radius * 0.3, cy - radius * 0.3, radius * 0.4)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.arc("fill", cx, cy, radius * 0.8, math.pi * 0.3, math.pi * 0.7)
end

-- Spawn celebration particle
local function spawnParticle(x, y)
    table.insert(particles, {
        x = x,
        y = y,
        vx = (math.random() - 0.5) * 100,
        vy = -50 - math.random() * 100,
        size = 2 + math.random() * 3,
        life = 1.5 + math.random(),
        maxLife = 1.5 + math.random(),
        color = math.random() > 0.5 and "gold" or "orange"
    })
end

function Victory.load()
    animTimer = 0
    particles = {}
    
    -- Spawn initial celebration particles
    local screenW, screenH = love.graphics.getDimensions()
    for i = 1, 30 do
        spawnParticle(screenW / 2 + (math.random() - 0.5) * 200, screenH / 2)
    end
end

function Victory.update(dt)
    animTimer = animTimer + dt
    
    -- Spawn more particles occasionally
    local screenW, screenH = love.graphics.getDimensions()
    if math.random() < dt * 5 then
        spawnParticle(screenW / 2 + (math.random() - 0.5) * 300, screenH / 2 + 50)
    end
    
    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 100 * dt  -- Gravity
        p.life = p.life - dt
        
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function Victory.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Background texture
    for i = 1, 30 do
        local px = hash(i, 1) * screenW
        local py = hash(1, i) * screenH
        local size = 10 + hash(i, i) * 30
        love.graphics.setColor(UI.stoneLight[1], UI.stoneLight[2], UI.stoneLight[3], 0.03)
        love.graphics.ellipse("fill", px, py, size, size * 0.7)
    end
    
    -- Particles (behind panel)
    for _, p in ipairs(particles) do
        local alpha = (p.life / p.maxLife) * 0.8
        if p.color == "gold" then
            love.graphics.setColor(1, 0.85, 0.2, alpha)
        else
            love.graphics.setColor(1, 0.5, 0.1, alpha)
        end
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
    
    -- Main panel
    local panelW, panelH = 480, 380
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    
    drawStonePanel(panelX, panelY, panelW, panelH, 10)
    
    -- Corner rivets
    local rivetOffset = 15
    drawRivet(panelX + rivetOffset, panelY + rivetOffset, 5)
    drawRivet(panelX + panelW - rivetOffset, panelY + rivetOffset, 5)
    drawRivet(panelX + rivetOffset, panelY + panelH - rivetOffset, 5)
    drawRivet(panelX + panelW - rivetOffset, panelY + panelH - rivetOffset, 5)
    
    -- Victory title with glow
    local titleFont = Game.fonts and Game.fonts.title or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    
    local title = "VICTORY!"
    local titleW = titleFont:getWidth(title)
    local titleX = (screenW - titleW) / 2
    local titleY = panelY + 25
    
    -- Title glow (pulsing)
    local glowPulse = 0.6 + math.sin(animTimer * 3) * 0.4
    love.graphics.setColor(1, 0.85, 0.2, 0.3 * glowPulse)
    for dx = -3, 3 do
        for dy = -3, 3 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.print(title, titleX + dx, titleY + dy)
            end
        end
    end
    
    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(title, titleX + 3, titleY + 3)
    
    -- Title main
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.print(title, titleX, titleY)
    
    -- Subtitle
    local medFont = Game.fonts and Game.fonts.medium or love.graphics.getFont()
    love.graphics.setFont(medFont)
    local subtitle = "All enemy buildings destroyed!"
    local subtitleW = medFont:getWidth(subtitle)
    
    love.graphics.setColor(UI.textLight)
    love.graphics.print(subtitle, (screenW - subtitleW) / 2, titleY + 75)
    
    -- Decorative line
    love.graphics.setColor(UI.metalBronze)
    love.graphics.setLineWidth(2)
    local lineY = titleY + 110
    love.graphics.line(panelX + 40, lineY, panelX + panelW - 40, lineY)
    drawRivet(panelX + 40, lineY, 3)
    drawRivet(panelX + panelW - 40, lineY, 3)
    
    -- Stats
    local smallFont = Game.fonts and Game.fonts.small or love.graphics.getFont()
    love.graphics.setFont(smallFont)
    
    local statsY = lineY + 20
    local lineHeight = 26
    local leftX = panelX + 50
    local rightX = panelX + panelW / 2 + 20
    
    -- Time
    local finalTime = Game.finalTime or 0
    local minutes = math.floor(finalTime / 60)
    local seconds = math.floor(finalTime % 60)
    local timeStr = string.format("Time: %d:%02d", minutes, seconds)
    
    love.graphics.setColor(UI.textLight)
    love.graphics.print(timeStr, leftX, statsY)
    
    -- Stats from Game (if available)
    local stats = Game.gameStats or {
        unitsKilled = 0,
        unitsLost = 0,
        buildingsDestroyed = 0,
        buildingsLost = 0
    }
    
    love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], 0.9)
    love.graphics.print("Units Killed: " .. (stats.unitsKilled or 0), leftX, statsY + lineHeight)
    love.graphics.print("Units Lost: " .. (stats.unitsLost or 0), leftX, statsY + lineHeight * 2)
    love.graphics.print("Buildings Destroyed: " .. (stats.buildingsDestroyed or 0), leftX, statsY + lineHeight * 3)
    love.graphics.print("Buildings Lost: " .. (stats.buildingsLost or 0), leftX, statsY + lineHeight * 4)
    
    -- Resources
    local resources = Game.finalResources or {gold = 0, lumber = 0}
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("Final Gold: " .. (resources.gold or 0), rightX, statsY + lineHeight)
    love.graphics.setColor(0.65, 0.5, 0.3, 1)
    love.graphics.print("Final Lumber: " .. (resources.lumber or 0), rightX, statsY + lineHeight * 2)
    
    -- Continue prompt (pulsing)
    local promptAlpha = 0.5 + math.sin(animTimer * 2) * 0.3
    love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], promptAlpha)
    local prompt = "Press SPACE to return to title"
    local promptW = smallFont:getWidth(prompt)
    love.graphics.print(prompt, (screenW - promptW) / 2, panelY + panelH - 40)
end

function Victory.keypressed(key)
    if key == "space" or key == "return" or key == "escape" then
        Game.SceneManager.switch("title")
    end
end

function Victory.mousepressed(x, y, button)
    if button == 1 then
        Game.SceneManager.switch("title")
    end
end

return Victory
