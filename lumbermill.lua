--[[
    Lumber Mill
    Utility building that enables tower upgrades
    Size: 3x3 tiles, grid-aligned
    Style: Isometric wooden sawmill with saw blade, log piles, water wheel
]]

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Palette shader for retro pixel art effect
local PaletteShader
pcall(function() PaletteShader = require("palette_shader") end)

-- Static palette renderer (shared by all lumber mills)
local paletteRenderer = nil
local usePaletteShader = true

-- Sawdust particle system
local sawdustParticles = {}

--============================================================================
-- ISOMETRIC RENDERING SYSTEM
--============================================================================

local function isoProject(x, y, z, originX, originY)
    local screenX = originX + (x - y) * 0.5
    local screenY = originY + (x + y) * 0.25 - z * 0.5
    return screenX, screenY
end

local function isoQuad(p1, p2, p3, p4, originX, originY, color)
    local sx1, sy1 = isoProject(p1[1], p1[2], p1[3], originX, originY)
    local sx2, sy2 = isoProject(p2[1], p2[2], p2[3], originX, originY)
    local sx3, sy3 = isoProject(p3[1], p3[2], p3[3], originX, originY)
    local sx4, sy4 = isoProject(p4[1], p4[2], p4[3], originX, originY)
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon("fill", sx1, sy1, sx2, sy2, sx3, sy3, sx4, sy4)
end

local function isoBox(x, y, z, w, d, h, originX, originY, topColor, leftColor, rightColor)
    -- Top face
    isoQuad(
        {x, y, z + h},
        {x + w, y, z + h},
        {x + w, y + d, z + h},
        {x, y + d, z + h},
        originX, originY, topColor
    )
    
    -- Left face (front-left visible)
    isoQuad(
        {x, y + d, z},
        {x, y + d, z + h},
        {x + w, y + d, z + h},
        {x + w, y + d, z},
        originX, originY, leftColor
    )
    
    -- Right face (front-right visible)
    isoQuad(
        {x + w, y, z},
        {x + w, y, z + h},
        {x + w, y + d, z + h},
        {x + w, y + d, z},
        originX, originY, rightColor
    )
end

-- Update sawdust particles
local function updateSawdustParticles(dt, buildingId)
    if not sawdustParticles[buildingId] then
        sawdustParticles[buildingId] = {}
    end
    
    local particles = sawdustParticles[buildingId]
    
    -- Update existing particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 30 * dt  -- Gravity
        p.alpha = (p.life / p.maxLife) * 0.6
        
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
    
    -- Spawn new particles (sawdust spray)
    if #particles < 12 and math.random() < dt * 8 then
        table.insert(particles, {
            x = 0,
            y = 0,
            vx = -20 + math.random() * 40,
            vy = -30 - math.random() * 20,
            life = 0.8 + math.random() * 0.4,
            maxLife = 1.2,
            alpha = 0.6,
            size = 1 + math.random() * 2
        })
    end
end

local function drawSawdustParticles(buildingId, screenX, screenY)
    local particles = sawdustParticles[buildingId]
    if not particles then return end
    
    for _, p in ipairs(particles) do
        love.graphics.setColor(0.65, 0.55, 0.35, p.alpha)
        love.graphics.circle("fill", screenX + p.x, screenY + p.y, p.size)
    end
end

-- Initialize palette renderer
local function initPaletteRenderer()
    local canvasSize = 128  -- 3x3 building needs room for 2x scale
    
    if paletteRenderer then
        local canvas = paletteRenderer:getCanvas()
        if canvas then
            local w, h = canvas:getDimensions()
            if w ~= canvasSize or h ~= canvasSize then
                paletteRenderer = nil
            end
        end
    end
    
    if paletteRenderer or not PaletteShader then return end
    
    paletteRenderer = PaletteShader.new({
        width = canvasSize,
        height = canvasSize,
        palette = PaletteShader.PALETTES.FANTASY,
        dithering = false,
        ditherStrength = 0
    })
end

local LumberMill = {}
LumberMill.__index = LumberMill

LumberMill.GRID_SIZE = 3
LumberMill.COST_GOLD = 250
LumberMill.COST_LUMBER = 0
LumberMill.BUILD_TIME = 12.0

-- Static counter for unique IDs
local lumberMillIdCounter = 0

function LumberMill.new(params)
    local self = setmetatable({}, LumberMill)
    
    lumberMillIdCounter = lumberMillIdCounter + 1
    self.uniqueId = lumberMillIdCounter
    self.animTimer = 0
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = LumberMill.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "lumbermill"
    self.name = "Lumber Mill"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 50
    self.hp = self.maxHp
    self.sightRadius = 5
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = LumberMill.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    -- Saw blade animation
    self.sawAngle = 0
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function LumberMill:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function LumberMill:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function LumberMill:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function LumberMill:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function LumberMill:update(dt)
    self.animTimer = (self.animTimer or 0) + dt
    self.sawAngle = (self.sawAngle or 0) + dt * 4  -- Rotating saw
    
    -- Update sawdust when completed
    if self.completed then
        updateSawdustParticles(dt, self.uniqueId)
    end
    
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return true
        end
    end
    return false
end

function LumberMill:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction site
        love.graphics.setColor(0.5, 0.4, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.3, 0.8)
        -- Lumber stacks
        love.graphics.rectangle("fill", x + 5, y + 10, 25, 8)
        love.graphics.rectangle("fill", x + size - 30, y + 15, 25, 8)
        
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
        
        if self.selected then
            love.graphics.setColor(0, 1, 0, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    
    -- Use palette shader if enabled, with 2x scaling
    if usePaletteShader and PaletteShader then
        initPaletteRenderer()
        if paletteRenderer then
            paletteRenderer:beginCapture()
            self:drawLumberMillIso(16, 32, 96)  -- Draw at offset in 128px canvas
            paletteRenderer:endCapture()
            
            -- Draw at 2x scale
            local drawScale = 2
            local canvasSize = 128
            local scaledSize = canvasSize * drawScale
            local offsetX = x + (size - scaledSize) / 2
            local offsetY = y + size - scaledSize
            paletteRenderer:draw(offsetX, offsetY, drawScale)
        end
    else
        -- Draw directly at 2x scale
        love.graphics.push()
        local drawScale = 2
        local canvasSize = 128
        local scaledSize = canvasSize * drawScale
        local offsetX = x + (size - scaledSize) / 2
        local offsetY = y + size - scaledSize
        love.graphics.translate(offsetX, offsetY)
        love.graphics.scale(drawScale, drawScale)
        self:drawLumberMillIso(16, 32, 96)
        love.graphics.pop()
    end
    
    -- Sawdust particles (outside shader)
    if self.completed then
        local sawX, sawY = self:getScreenPos()
        drawSawdustParticles(self.uniqueId, sawX + size * 0.75, sawY + size * 0.3)
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    self:drawHealthBar()
    love.graphics.setColor(1, 1, 1, 1)
end

function LumberMill:drawLumberMillIso(x, y, size)
    local scale = 1
    local originX = x + size/2
    local originY = y + size - 12
    
    -- Colors
    local woodTop = {0.55, 0.42, 0.28}
    local woodLeft = {0.42, 0.32, 0.22}
    local woodRight = {0.48, 0.38, 0.25}
    local woodDark = {0.32, 0.24, 0.16}
    local roofTop = {0.38, 0.28, 0.18}
    local roofLeft = {0.30, 0.22, 0.14}
    local roofRight = {0.34, 0.25, 0.16}
    local metalColor = {0.55, 0.55, 0.60}
    local metalDark = {0.40, 0.40, 0.45}
    local waterColor = {0.35, 0.50, 0.60}
    
    -- === GROUND/SAWDUST PILE ===
    love.graphics.setColor(0.50, 0.42, 0.30, 0.6)
    local gx, gy = isoProject(0, 0, 0, originX, originY)
    love.graphics.ellipse("fill", gx, gy + 3, 35, 12)
    
    -- === MAIN BUILDING ===
    local mainW, mainD, mainH = 40*scale, 35*scale, 28*scale
    local mainX, mainY = -mainW/2, -mainD/2
    
    isoBox(mainX, mainY, 0, mainW, mainD, mainH, originX, originY,
           woodTop, woodLeft, woodRight)
    
    -- Wood plank lines on walls
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 0.5)
    for i = 1, 4 do
        local z = i * 6 * scale
        local lx1, ly1 = isoProject(mainX, mainY + mainD, z, originX, originY)
        local lx2, ly2 = isoProject(mainX + mainW, mainY + mainD, z, originX, originY)
        love.graphics.line(lx1, ly1, lx2, ly2)
        
        local rx1, ry1 = isoProject(mainX + mainW, mainY, z, originX, originY)
        local rx2, ry2 = isoProject(mainX + mainW, mainY + mainD, z, originX, originY)
        love.graphics.line(rx1, ry1, rx2, ry2)
    end
    
    -- === PEAKED ROOF ===
    local roofBase = mainH
    local roofPeak = 18*scale
    local roofOverhang = 5*scale
    
    -- Left roof slope
    isoQuad(
        {mainX - roofOverhang, mainY - roofOverhang, roofBase},
        {0, mainY + mainD/2, roofBase + roofPeak},
        {0, mainY + mainD/2, roofBase + roofPeak},
        {mainX - roofOverhang, mainY + mainD + roofOverhang, roofBase},
        originX, originY, roofLeft
    )
    
    -- Right roof slope
    isoQuad(
        {mainX + mainW + roofOverhang, mainY - roofOverhang, roofBase},
        {0, mainY + mainD/2, roofBase + roofPeak},
        {0, mainY + mainD/2, roofBase + roofPeak},
        {mainX + mainW + roofOverhang, mainY + mainD + roofOverhang, roofBase},
        originX, originY, roofRight
    )
    
    -- Front gable
    isoQuad(
        {mainX - roofOverhang, mainY + mainD + roofOverhang, roofBase},
        {0, mainY + mainD/2, roofBase + roofPeak},
        {0, mainY + mainD/2, roofBase + roofPeak},
        {mainX + mainW + roofOverhang, mainY + mainD + roofOverhang, roofBase},
        originX, originY, roofTop
    )
    
    -- Ridge highlight
    love.graphics.setColor(0.45, 0.35, 0.25, 1)
    local r1x, r1y = isoProject(0, mainY - roofOverhang, roofBase + roofPeak, originX, originY)
    local r2x, r2y = isoProject(0, mainY + mainD + roofOverhang, roofBase + roofPeak, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(r1x, r1y, r2x, r2y)
    love.graphics.setLineWidth(1)
    
    -- === LARGE SAW BLADE ===
    local sawX, sawY = mainX + mainW + 8*scale, mainY + mainD/2
    local sawZ = 15*scale
    local sawRadius = 14*scale
    
    -- Saw mounting bracket
    isoBox(mainX + mainW - 2*scale, sawY - 4*scale, 8*scale, 6*scale, 8*scale, 12*scale,
           originX, originY, metalDark, metalDark, metalColor)
    
    -- Saw blade (circle with teeth)
    local sawScreenX, sawScreenY = isoProject(sawX, sawY, sawZ, originX, originY)
    
    -- Blade body
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    love.graphics.circle("fill", sawScreenX, sawScreenY, sawRadius)
    
    -- Center hub
    love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
    love.graphics.circle("fill", sawScreenX, sawScreenY, sawRadius * 0.3)
    
    -- Saw teeth
    love.graphics.setColor(0.65, 0.65, 0.70, 1)
    local numTeeth = 12
    for i = 0, numTeeth - 1 do
        local angle = (i / numTeeth) * math.pi * 2 + (self.sawAngle or 0)
        local tx1 = sawScreenX + math.cos(angle) * sawRadius * 0.85
        local ty1 = sawScreenY + math.sin(angle) * sawRadius * 0.85
        local tx2 = sawScreenX + math.cos(angle + 0.15) * (sawRadius + 3)
        local ty2 = sawScreenY + math.sin(angle + 0.15) * (sawRadius + 3)
        local tx3 = sawScreenX + math.cos(angle - 0.15) * (sawRadius + 3)
        local ty3 = sawScreenY + math.sin(angle - 0.15) * (sawRadius + 3)
        love.graphics.polygon("fill", tx1, ty1, tx2, ty2, tx3, ty3)
    end
    
    -- Center bolt
    love.graphics.setColor(0.50, 0.50, 0.55, 1)
    love.graphics.circle("fill", sawScreenX, sawScreenY, 3)
    
    -- === DOOR ===
    local doorW, doorH = 10*scale, 18*scale
    local doorX = -doorW/2
    
    isoQuad(
        {doorX, mainY + mainD + 0.5, 0},
        {doorX + doorW, mainY + mainD + 0.5, 0},
        {doorX + doorW, mainY + mainD + 0.5, doorH},
        {doorX, mainY + mainD + 0.5, doorH},
        originX, originY, woodDark
    )
    
    -- Door frame
    love.graphics.setColor(woodDark[1] * 0.8, woodDark[2] * 0.8, woodDark[3] * 0.8, 1)
    local df1x, df1y = isoProject(doorX, mainY + mainD + 0.5, 0, originX, originY)
    local df2x, df2y = isoProject(doorX, mainY + mainD + 0.5, doorH, originX, originY)
    local df3x, df3y = isoProject(doorX + doorW, mainY + mainD + 0.5, doorH, originX, originY)
    local df4x, df4y = isoProject(doorX + doorW, mainY + mainD + 0.5, 0, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(df1x, df1y, df2x, df2y)
    love.graphics.line(df2x, df2y, df3x, df3y)
    love.graphics.line(df3x, df3y, df4x, df4y)
    love.graphics.setLineWidth(1)
    
    -- === LOG PILE ===
    local logX, logY = mainX - 18*scale, mainY + 5*scale
    local logColors = {
        {0.50, 0.38, 0.25},
        {0.45, 0.35, 0.22},
        {0.52, 0.40, 0.27}
    }
    
    -- Stack of logs
    for row = 0, 2 do
        for col = 0, 2 - row do
            local lx = logX + col * 5*scale + row * 2.5*scale
            local ly = logY
            local lz = row * 4*scale
            local color = logColors[(row + col) % 3 + 1]
            
            -- Log as small box
            isoBox(lx, ly, lz, 4*scale, 12*scale, 3*scale, originX, originY,
                   color, {color[1]*0.8, color[2]*0.8, color[3]*0.8}, color)
            
            -- Log end circle
            local endX, endY = isoProject(lx + 2*scale, ly + 12*scale, lz + 1.5*scale, originX, originY)
            love.graphics.setColor(0.60, 0.50, 0.35, 1)
            love.graphics.circle("fill", endX, endY, 2)
            love.graphics.setColor(0.45, 0.35, 0.25, 1)
            love.graphics.circle("fill", endX, endY, 1)
        end
    end
    
    -- === WINDOW ===
    local winX, winY = mainX + mainW, mainY + mainD/2 - 5*scale
    local winW, winH = 1, 8*scale
    
    isoQuad(
        {winX + 0.5, winY, 12*scale},
        {winX + 0.5, winY + 8*scale, 12*scale},
        {winX + 0.5, winY + 8*scale, 20*scale},
        {winX + 0.5, winY, 20*scale},
        originX, originY, {0.3, 0.4, 0.5, 0.8}
    )
    
    -- Window frame
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    local w1x, w1y = isoProject(winX + 0.5, winY, 12*scale, originX, originY)
    local w2x, w2y = isoProject(winX + 0.5, winY + 8*scale, 12*scale, originX, originY)
    local w3x, w3y = isoProject(winX + 0.5, winY + 8*scale, 20*scale, originX, originY)
    local w4x, w4y = isoProject(winX + 0.5, winY, 20*scale, originX, originY)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", w1x, w1y, w2x, w2y, w3x, w3y, w4x, w4y)
    
    -- Cross bars
    local wcx, wcy = isoProject(winX + 0.5, winY + 4*scale, 16*scale, originX, originY)
    love.graphics.line(w1x, w1y + (w4y - w1y)/2, w2x, w2y + (w3y - w2y)/2)
    love.graphics.line((w1x + w2x)/2, (w1y + w2y)/2, (w4x + w3x)/2, (w4y + w3y)/2)
    
    -- === CHIMNEY WITH SMOKE ===
    local chimX, chimY = mainX + mainW - 8*scale, mainY + 6*scale
    
    isoBox(chimX, chimY, roofBase, 6*scale, 6*scale, 12*scale, originX, originY,
           {0.40, 0.35, 0.30}, {0.32, 0.28, 0.24}, {0.36, 0.32, 0.28})
    
    -- Smoke puffs
    local smokeX, smokeY = isoProject(chimX + 3*scale, chimY + 3*scale, roofBase + 14*scale, originX, originY)
    love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
    love.graphics.circle("fill", smokeX, smokeY - 3, 4)
    love.graphics.circle("fill", smokeX + 2, smokeY - 9, 3)
    love.graphics.circle("fill", smokeX + 4, smokeY - 14, 2.5)
end

function LumberMill:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function LumberMill:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function LumberMill:updateUI(resources, screenW, screenH, font) end
function LumberMill:drawUI() end
function LumberMill:mousepressed(x, y, button) end
function LumberMill:mousereleased(x, y, button) end

function LumberMill:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        if Teams then
            local teamColor = Teams.getColor(self.team, "minimapBuilding")
            love.graphics.setColor(teamColor[1], teamColor[2], teamColor[3], 1)
        else
            love.graphics.setColor(0.5, 0.4, 0.25, 1)
        end
    else
        love.graphics.setColor(0.4, 0.35, 0.2, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

-- Combat Methods --

function LumberMill:takeDamage(amount)
    self.hp = self.hp - amount
end

function LumberMill:isDead()
    return self.hp <= 0
end

function LumberMill:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 10
    local barHeight = 4
    local barX = x + 5
    local barY = y - 8
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
    
    -- Health bar
    local healthPct = self.hp / self.maxHp
    love.graphics.setColor(1 - healthPct, healthPct, 0.2, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPct, barHeight)
    
    -- Border
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
end

-- Static functions
LumberMill.setPaletteShaderEnabled = function(enabled)
    usePaletteShader = enabled
end

LumberMill.isPaletteShaderEnabled = function()
    return usePaletteShader
end

return LumberMill
