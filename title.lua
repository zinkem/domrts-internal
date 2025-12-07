--[[
    Title Screen - Desert Warrior Edition
    Features the warrior prominently with a side panel UI
    Color scheme: Teal, Gold, Sand
]]

local Title = {}

-- Import audio
local Audio
pcall(function() Audio = require("audio") end)

-- Local state
local animTimer = 0
local particles = {}
local buttons = {}
local checkboxes = {}

-- Background image state
local bgImage = nil
local bgCanvas = nil
local jiggleShader = nil
local jiggleTime = 0
local jiggleActive = false
local jiggleDuration = 1.2
local clickX, clickY = 0, 0

-- Color palette inspired by the warrior
local Colors = {
    -- Teals (from her hair/clothes)
    tealDark = {0.10, 0.25, 0.35, 1},
    tealMid = {0.15, 0.40, 0.50, 1},
    tealLight = {0.25, 0.55, 0.65, 1},
    tealBright = {0.30, 0.70, 0.80, 1},
    
    -- Golds (from her armor)
    goldDark = {0.45, 0.35, 0.15, 1},
    goldMid = {0.72, 0.58, 0.22, 1},
    goldLight = {0.92, 0.78, 0.35, 1},
    goldBright = {1.0, 0.88, 0.45, 1},
    
    -- Sand/Stone (from environment)
    sandDark = {0.25, 0.22, 0.18, 1},
    sandMid = {0.45, 0.40, 0.32, 1},
    sandLight = {0.65, 0.58, 0.48, 1},
    
    -- UI
    panelBg = {0.08, 0.12, 0.18, 0.92},
    panelBorder = {0.25, 0.45, 0.55, 1},
    textLight = {0.95, 0.92, 0.85, 1},
    textGold = {1.0, 0.85, 0.35, 1},
    textMuted = {0.6, 0.55, 0.5, 1},
}

-- Gelatin jiggle shader
local jiggleShaderCode = [[
extern float time;
extern float intensity;
extern vec2 clickPos;
extern vec2 resolution;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec2 clickUV = clickPos / resolution;
    float dist = distance(uv, clickUV);
    
    float wave = sin(dist * 20.0 - time * 10.0) * 0.5 + 0.5;
    float decay = exp(-dist * 2.5) * exp(-time * 2.5);
    
    float jiggleX = sin(uv.y * 12.0 + time * 14.0) * wave * decay * intensity * 0.025;
    float jiggleY = sin(uv.x * 10.0 + time * 12.0) * wave * decay * intensity * 0.02;
    jiggleX += sin(uv.y * 6.0 - time * 8.0) * decay * intensity * 0.012;
    jiggleY += cos(uv.x * 8.0 - time * 9.0) * decay * intensity * 0.01;
    
    vec2 displaced = clamp(uv + vec2(jiggleX, jiggleY), 0.0, 1.0);
    return Texel(texture, displaced) * color;
}
]]

-- Hash for procedural effects
local function hash(a, b)
    local h = (a * 374761393 + b * 668265263) % 2147483647
    h = ((h * 1274126177) % 2147483647)
    return (h % 1000) / 1000
end

-- Spawn desert dust particles
local function spawnParticle()
    local screenW, screenH = love.graphics.getDimensions()
    local side = math.random() > 0.5
    table.insert(particles, {
        x = side and -10 or (screenW + 10),
        y = math.random(screenH * 0.3, screenH),
        vx = side and (20 + math.random() * 40) or (-20 - math.random() * 40),
        vy = -5 - math.random() * 15,
        size = 1 + math.random() * 3,
        life = 4 + math.random() * 3,
        maxLife = 4 + math.random() * 3,
        alpha = 0.2 + math.random() * 0.3,
        type = math.random() > 0.8 and "spark" or "dust"
    })
end

-- Draw a stylized button
local function drawButton(btn, mx, my)
    local x, y, w, h = btn.x, btn.y, btn.w, btn.h
    local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
    local isPrimary = btn.primary
    
    -- Button glow on hover
    if hovered then
        love.graphics.setColor(Colors.tealBright[1], Colors.tealBright[2], Colors.tealBright[3], 0.15)
        love.graphics.rectangle("fill", x - 4, y - 4, w + 8, h + 8, 10)
    end
    
    -- Button background
    if isPrimary then
        -- Gold gradient for primary
        for i = 0, h - 1 do
            local t = i / h
            local r = Colors.goldDark[1] + (Colors.goldMid[1] - Colors.goldDark[1]) * (1 - t * 0.5)
            local g = Colors.goldDark[2] + (Colors.goldMid[2] - Colors.goldDark[2]) * (1 - t * 0.5)
            local b = Colors.goldDark[3] + (Colors.goldMid[3] - Colors.goldDark[3]) * (1 - t * 0.5)
            if hovered then r, g, b = r + 0.1, g + 0.1, b + 0.05 end
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", x, y + i, w, 1)
        end
    else
        -- Teal for regular buttons
        for i = 0, h - 1 do
            local t = i / h
            local baseColor = hovered and Colors.tealMid or Colors.tealDark
            local r = baseColor[1] * (1 - t * 0.3)
            local g = baseColor[2] * (1 - t * 0.3)
            local b = baseColor[3] * (1 - t * 0.3)
            love.graphics.setColor(r, g, b, 0.95)
            love.graphics.rectangle("fill", x, y + i, w, 1)
        end
    end
    
    -- Border
    love.graphics.setLineWidth(isPrimary and 2 or 1)
    if isPrimary then
        love.graphics.setColor(Colors.goldLight)
    elseif hovered then
        love.graphics.setColor(Colors.tealBright)
    else
        love.graphics.setColor(Colors.tealLight[1], Colors.tealLight[2], Colors.tealLight[3], 0.6)
    end
    love.graphics.rectangle("line", x, y, w, h, 4)
    
    -- Top highlight
    love.graphics.setColor(1, 1, 1, isPrimary and 0.3 or 0.15)
    love.graphics.line(x + 4, y + 1, x + w - 4, y + 1)
    
    -- Text
    local font = Game.fonts and Game.fonts.button or love.graphics.getFont()
    love.graphics.setFont(font)
    local textW = font:getWidth(btn.text)
    local textH = font:getHeight()
    
    -- Text shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(btn.text, x + (w - textW) / 2 + 1, y + (h - textH) / 2 + 1)
    
    -- Text
    if isPrimary then
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
    elseif hovered then
        love.graphics.setColor(Colors.textGold)
    else
        love.graphics.setColor(Colors.textLight)
    end
    love.graphics.print(btn.text, x + (w - textW) / 2, y + (h - textH) / 2)
    
    return hovered
end

-- Draw checkbox
local function drawCheckbox(cb, mx, my)
    local x, y, size = cb.x, cb.y, cb.size or 20
    local hovered = mx >= x and mx <= x + size + 80 and my >= y and my <= y + size
    local checked = cb.checked
    
    -- Box background
    love.graphics.setColor(Colors.tealDark[1], Colors.tealDark[2], Colors.tealDark[3], 0.8)
    love.graphics.rectangle("fill", x, y, size, size, 3)
    
    -- Box border
    if hovered then
        love.graphics.setColor(Colors.tealBright)
    else
        love.graphics.setColor(Colors.tealLight[1], Colors.tealLight[2], Colors.tealLight[3], 0.6)
    end
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, size, size, 3)
    
    -- Checkmark
    if checked then
        love.graphics.setColor(Colors.goldLight)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 4, y + size/2, x + size/2 - 1, y + size - 5)
        love.graphics.line(x + size/2 - 1, y + size - 5, x + size - 4, y + 5)
    end
    
    -- Label
    local font = Game.fonts and Game.fonts.small or love.graphics.getFont()
    love.graphics.setFont(font)
    if hovered then
        love.graphics.setColor(Colors.textGold)
    else
        love.graphics.setColor(Colors.textLight[1], Colors.textLight[2], Colors.textLight[3], 0.8)
    end
    love.graphics.print(cb.label, x + size + 8, y + (size - font:getHeight()) / 2)
    
    return hovered
end

-- Draw the side panel
local function drawPanel(panelX, panelY, panelW, panelH)
    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", panelX + 6, panelY + 6, panelW, panelH, 8)
    
    -- Panel background with gradient
    for i = 0, panelH - 1 do
        local t = i / panelH
        local alpha = Colors.panelBg[4] - t * 0.1
        love.graphics.setColor(Colors.panelBg[1], Colors.panelBg[2], Colors.panelBg[3], alpha)
        love.graphics.rectangle("fill", panelX, panelY + i, panelW, 1)
    end
    
    -- Decorative top border (gold accent)
    love.graphics.setColor(Colors.goldMid)
    love.graphics.rectangle("fill", panelX, panelY, panelW, 3)
    love.graphics.setColor(Colors.goldLight[1], Colors.goldLight[2], Colors.goldLight[3], 0.6)
    love.graphics.rectangle("fill", panelX, panelY, panelW, 1)
    
    -- Side borders
    love.graphics.setColor(Colors.panelBorder[1], Colors.panelBorder[2], Colors.panelBorder[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX, panelY + 3, panelX, panelY + panelH)
    love.graphics.line(panelX + panelW, panelY + 3, panelX + panelW, panelY + panelH)
    
    -- Bottom accent
    love.graphics.setColor(Colors.tealMid[1], Colors.tealMid[2], Colors.tealMid[3], 0.5)
    love.graphics.rectangle("fill", panelX, panelY + panelH - 2, panelW, 2)
end

-- Draw vignette overlay
local function drawVignette(screenW, screenH)
    local cx, cy = screenW / 2, screenH / 2
    local maxDist = math.sqrt(cx * cx + cy * cy)
    local gridSize = 16  -- Size of each cell
    
    -- Draw grid cells with distance-based alpha (no overlapping)
    for y = 0, screenH, gridSize do
        for x = 0, screenW, gridSize do
            -- Distance from center of this cell to screen center
            local cellCx = x + gridSize / 2
            local cellCy = y + gridSize / 2
            local dx = cellCx - cx
            local dy = cellCy - cy
            local dist = math.sqrt(dx * dx + dy * dy)
            local t = dist / maxDist  -- 0 at center, 1 at corners
            
            -- Alpha increases toward edges (vignette effect)
            local alpha = math.max(0, (t - 0.25) / 0.75) ^ 1.6 * 0.75
            
            if alpha > 0.01 then
                love.graphics.setColor(0.05, 0.08, 0.12, alpha)
                love.graphics.rectangle("fill", x, y, gridSize, gridSize)
            end
        end
    end
    
    -- Extra darkening on left for panel readability
    for i = 0, 350 do
        local alpha = (1 - i / 350) * 0.35
        love.graphics.setColor(0.05, 0.08, 0.12, alpha)
        love.graphics.rectangle("fill", i, 0, 1, screenH)
    end
end

-- Draw background image
local function drawBackgroundImage()
    if not bgImage then return end
    
    local screenW, screenH = love.graphics.getDimensions()
    local imgW, imgH = bgImage:getWidth(), bgImage:getHeight()
    
    -- Scale to cover, positioned to show the warrior on the right
    local scale = math.max(screenW / imgW, screenH / imgH) * 1.05
    local drawW = imgW * scale
    local drawH = imgH * scale
    
    -- Offset to right side so warrior is visible (panel will be on left)
    -- Shift down to show her face and flowing hair
    local drawX = (screenW - drawW) / 2 + 80
    local drawY = (screenH - drawH) / 2 + 60  -- Shift down to show head
    
    -- Canvas for shader
    if not bgCanvas or bgCanvas:getWidth() ~= screenW or bgCanvas:getHeight() ~= screenH then
        bgCanvas = love.graphics.newCanvas(screenW, screenH)
    end
    
    love.graphics.setCanvas(bgCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bgImage, drawX, drawY, 0, scale, scale)
    love.graphics.setCanvas()
    
    -- Apply jiggle shader if active
    if jiggleActive and jiggleShader then
        jiggleShader:send("time", jiggleTime)
        jiggleShader:send("intensity", math.max(0, 1 - jiggleTime / jiggleDuration))
        jiggleShader:send("clickPos", {clickX, clickY})
        jiggleShader:send("resolution", {screenW, screenH})
        love.graphics.setShader(jiggleShader)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bgCanvas, 0, 0)
    love.graphics.setShader()
end

function Title.load()
    animTimer = 0
    particles = {}
    jiggleTime = 0
    jiggleActive = false
    
    -- Load background image
    local imagePath = "images/female_desert_warrior_with_spear_and_shield.png"
    local success, result = pcall(function()
        return love.graphics.newImage(imagePath)
    end)
    if success then
        bgImage = result
        print("Title: Loaded warrior background")
    else
        bgImage = nil
        print("Title: Could not load " .. imagePath)
    end
    
    -- Create jiggle shader
    local shaderSuccess
    shaderSuccess, jiggleShader = pcall(function()
        return love.graphics.newShader(jiggleShaderCode)
    end)
    if not shaderSuccess then
        print("Title: Shader error: " .. tostring(jiggleShader))
        jiggleShader = nil
    end
    
    -- Audio
    if Audio and Audio.init then Audio.init() end
    if Audio and Audio.playRandomMusic then Audio.playRandomMusic() end
    
    -- Layout
    local screenW, screenH = love.graphics.getDimensions()
    local panelW = 280
    local panelX = 40
    local panelY = 80
    local panelH = screenH - 160
    
    local btnW = panelW - 40
    local btnH = 42
    local btnX = panelX + 20
    local btnStartY = panelY + 180
    local btnSpacing = 50
    
    buttons = {
        {
            text = "QUICK PLAY",
            x = btnX, y = btnStartY, w = btnW, h = btnH,
            action = function() Game.SceneManager.switch("gameplay") end,
            primary = true
        },
        {
            text = "New Game",
            x = btnX, y = btnStartY + btnSpacing, w = btnW, h = btnH,
            action = function() Game.SceneManager.switch("gameconfig") end
        },
        {
            text = "How to Play",
            x = btnX, y = btnStartY + btnSpacing * 2, w = btnW, h = btnH,
            action = function() Game.SceneManager.switch("tutorial") end
        },
        {
            text = "Settings",
            x = btnX, y = btnStartY + btnSpacing * 3, w = btnW, h = btnH,
            action = function() 
                -- Could open settings menu
            end
        },
        {
            text = "Exit Game",
            x = btnX, y = btnStartY + btnSpacing * 4 + 20, w = btnW, h = btnH,
            action = function() love.event.quit() end
        },
        {
            text = "DEV PREVIEW",
            x = btnX, y = btnStartY + btnSpacing * 5 + 30, w = btnW, h = btnH,
            action = function() Game.SceneManager.switch("devpreview") end,
            dev = true  -- Special styling for dev button
        }
    }
    
    -- Checkboxes for audio
    local cbY = panelY + panelH - 90
    checkboxes = {
        {
            label = "Music",
            x = btnX, y = cbY,
            size = 22,
            checked = Game.settings.musicEnabled,
            toggle = function(cb)
                cb.checked = not cb.checked
                Game.settings.musicEnabled = cb.checked
            end
        },
        {
            label = "Sound FX",
            x = btnX + 110, y = cbY,
            size = 22,
            checked = Game.settings.soundEnabled,
            toggle = function(cb)
                cb.checked = not cb.checked
                Game.settings.soundEnabled = cb.checked
            end
        }
    }
end

function Title.update(dt)
    animTimer = animTimer + dt
    
    -- Update jiggle
    if jiggleActive then
        jiggleTime = jiggleTime + dt
        if jiggleTime >= jiggleDuration then
            jiggleActive = false
            jiggleTime = 0
        end
    end
    
    -- Audio
    if Audio and Audio.update then Audio.update(dt) end
    
    -- Spawn dust particles
    if math.random() < dt * 1.5 then
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
    
    -- Sync checkboxes with settings
    if checkboxes[1] then checkboxes[1].checked = Game.settings.musicEnabled end
    if checkboxes[2] then checkboxes[2].checked = Game.settings.soundEnabled end
end

function Title.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    
    -- Background gradient (desert sky colors)
    for i = 0, screenH - 1 do
        local t = i / screenH
        local r = 0.15 + t * 0.1
        local g = 0.20 + t * 0.08
        local b = 0.28 - t * 0.05
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 0, i, screenW, 1)
    end
    
    -- Background image
    drawBackgroundImage()
    
    -- Vignette
    drawVignette(screenW, screenH)
    
    -- Dust particles
    for _, p in ipairs(particles) do
        local alpha = (p.life / p.maxLife) * p.alpha
        if p.type == "spark" then
            love.graphics.setColor(Colors.goldLight[1], Colors.goldLight[2], Colors.goldLight[3], alpha)
        else
            love.graphics.setColor(Colors.sandLight[1], Colors.sandLight[2], Colors.sandLight[3], alpha * 0.6)
        end
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
    
    -- Side panel
    local panelW = 280
    local panelX = 40
    local panelY = 80
    local panelH = screenH - 160
    
    drawPanel(panelX, panelY, panelW, panelH)
    
    -- Title
    local titleFont = Game.fonts and Game.fonts.title or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    
    local title = "DOMINION"
    local titleW = titleFont:getWidth(title)
    -- Center title in panel, but ensure it doesn't go off-screen
    local titleX = math.max(10, panelX + (panelW - titleW) / 2)
    local titleY = panelY + 25
    
    -- Title glow
    local glowPulse = 0.6 + math.sin(animTimer * 2) * 0.4
    love.graphics.setColor(Colors.goldMid[1], Colors.goldMid[2], Colors.goldMid[3], 0.25 * glowPulse)
    for dx = -3, 3 do
        for dy = -3, 3 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.print(title, titleX + dx, titleY + dy)
            end
        end
    end
    
    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(title, titleX + 2, titleY + 2)
    
    -- Title main
    love.graphics.setColor(Colors.goldBright)
    love.graphics.print(title, titleX, titleY)
    
    -- Subtitle
    local subtitleFont = Game.fonts and Game.fonts.subtitle or love.graphics.getFont()
    love.graphics.setFont(subtitleFont)
    local subtitle = "Rise to Power"
    local subtitleW = subtitleFont:getWidth(subtitle)
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(subtitle, panelX + (panelW - subtitleW) / 2 + 1, titleY + 55 + 1)
    love.graphics.setColor(Colors.tealBright[1], Colors.tealBright[2], Colors.tealBright[3], 0.9)
    love.graphics.print(subtitle, panelX + (panelW - subtitleW) / 2, titleY + 55)
    
    -- Decorative line under subtitle
    local lineY = titleY + 95
    love.graphics.setColor(Colors.goldMid[1], Colors.goldMid[2], Colors.goldMid[3], 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX + 30, lineY, panelX + panelW - 30, lineY)
    
    -- Diamond accent in center of line
    local diamondX = panelX + panelW / 2
    love.graphics.setColor(Colors.goldLight)
    love.graphics.polygon("fill", 
        diamondX, lineY - 5,
        diamondX + 5, lineY,
        diamondX, lineY + 5,
        diamondX - 5, lineY
    )
    
    -- Buttons
    for _, btn in ipairs(buttons) do
        drawButton(btn, mx, my)
    end
    
    -- Audio section label
    local smallFont = Game.fonts and Game.fonts.small or love.graphics.getFont()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(Colors.textMuted)
    love.graphics.print("Audio", panelX + 20, panelY + panelH - 115)
    
    -- Checkboxes
    for _, cb in ipairs(checkboxes) do
        drawCheckbox(cb, mx, my)
    end
    
    -- Version in corner
    love.graphics.setColor(Colors.textLight[1], Colors.textLight[2], Colors.textLight[3], 0.3)
    love.graphics.print("v0.1 - Made with LÖVE", screenW - 150, screenH - 25)
end

function Title.keypressed(key)
    if key == "return" or key == "space" then
        Game.SceneManager.switch("gameplay")
    elseif key == "escape" then
        love.event.quit()
    elseif key == "m" then
        Game.settings.musicEnabled = not Game.settings.musicEnabled
    end
end

function Title.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    -- Trigger jiggle on background click
    if bgImage then
        jiggleActive = true
        jiggleTime = 0
        clickX = x
        clickY = y
    end
    
    -- Check buttons
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            if btn.action then btn.action() end
            return
        end
    end
    
    -- Check checkboxes
    for _, cb in ipairs(checkboxes) do
        local size = cb.size or 20
        if x >= cb.x and x <= cb.x + size + 80 and
           y >= cb.y and y <= cb.y + size then
            if cb.toggle then cb.toggle(cb) end
            return
        end
    end
end

function Title.unload()
    bgCanvas = nil
end

return Title
