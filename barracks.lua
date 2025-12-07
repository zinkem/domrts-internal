--[[
    Barracks
    Military training building that produces footmen and other combat units
    Size: 3x3 tiles, grid-aligned
    Style: Stone training facility with training yard, weapons racks, and garrison quarters
]]

local Button = require("button")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Palette shader for retro pixel art effect
local PaletteShader
pcall(function() PaletteShader = require("palette_shader") end)

-- Static palette renderer (shared by all barracks)
local paletteRenderer = nil
local usePaletteShader = true

--============================================================================
-- ISOMETRIC RENDERING SYSTEM
-- True 2:1 isometric projection with pre-rendered texture caching
--============================================================================

-- Isometric constants (2:1 ratio means slope of 0.5)
local ISO_ANGLE = math.atan(0.5)  -- ~26.57 degrees
local ISO_COS = math.cos(ISO_ANGLE)
local ISO_SIN = math.sin(ISO_ANGLE)

-- Project 3D isometric coordinates to 2D screen
-- x = right, y = back-left, z = up
local function isoProject(x, y, z, originX, originY)
    local screenX = originX + (x - y) * 0.5
    local screenY = originY + (x + y) * 0.25 - z * 0.5
    return screenX, screenY
end

-- Draw an isometric quad (4 corners in 3D space)
local function isoQuad(p1, p2, p3, p4, originX, originY, color)
    local sx1, sy1 = isoProject(p1[1], p1[2], p1[3], originX, originY)
    local sx2, sy2 = isoProject(p2[1], p2[2], p2[3], originX, originY)
    local sx3, sy3 = isoProject(p3[1], p3[2], p3[3], originX, originY)
    local sx4, sy4 = isoProject(p4[1], p4[2], p4[3], originX, originY)
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon("fill", sx1, sy1, sx2, sy2, sx3, sy3, sx4, sy4)
end

-- Draw an isometric box (cube or rectangular prism)
local function isoBox(x, y, z, w, d, h, originX, originY, topColor, leftColor, rightColor)
    -- Top face
    isoQuad(
        {x, y, z + h},
        {x + w, y, z + h},
        {x + w, y + d, z + h},
        {x, y + d, z + h},
        originX, originY, topColor
    )
    
    -- Left face (visible from front-left)
    isoQuad(
        {x, y + d, z},
        {x, y + d, z + h},
        {x + w, y + d, z + h},
        {x + w, y + d, z},
        originX, originY, leftColor
    )
    
    -- Right face (visible from front-right)
    isoQuad(
        {x + w, y, z},
        {x + w, y, z + h},
        {x + w, y + d, z + h},
        {x + w, y + d, z},
        originX, originY, rightColor
    )
end

-- Shared gradient/texture helper functions
local function gradientRect(rx, ry, rw, rh, c1, c2, weathering)
    for i = 0, rh - 1 do
        local t = i / rh
        local r = c1[1] + (c2[1] - c1[1]) * t
        local g = c1[2] + (c2[2] - c1[2]) * t
        local b = c1[3] + (c2[3] - c1[3]) * t
        if weathering then
            local noise = (math.sin(rx * 0.3 + i * 0.5) * 0.02 + math.cos(ry * 0.2 + i * 0.7) * 0.02)
            r, g, b = r + noise, g + noise, b + noise
        end
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", rx, ry + i, rw, 1)
    end
end

local function weatheredRect(rx, ry, rw, rh, baseColor, darken)
    darken = darken or 0.15
    gradientRect(rx, ry, rw, rh, 
        {baseColor[1] + 0.05, baseColor[2] + 0.05, baseColor[3] + 0.05},
        {baseColor[1] - darken, baseColor[2] - darken, baseColor[3] - darken}, true)
    love.graphics.setColor(0, 0, 0, 0.04)
    for i = 1, 3 do
        local stainX = rx + math.sin(rx + i * 17) * rw * 0.3 + rw * 0.3
        local stainY = ry + math.cos(ry + i * 13) * rh * 0.3 + rh * 0.5
        love.graphics.ellipse("fill", stainX, stainY, rw * 0.12, rh * 0.08)
    end
end

local function drawTorchFlame(tx, ty)
    for r = 8, 1, -1 do
        local alpha = (1 - r/8) * 0.15
        love.graphics.setColor(1, 0.5, 0.1, alpha)
        love.graphics.circle("fill", tx, ty, r)
    end
    love.graphics.setColor(1, 0.8, 0.3, 0.9)
    love.graphics.circle("fill", tx, ty, 3)
    love.graphics.setColor(1, 0.95, 0.7, 0.7)
    love.graphics.circle("fill", tx, ty - 1, 1.5)
end

local function drawBanner(bx, by, bannerColor, emblemColor, goldDark, goldMid)
    gradientRect(bx - 1, by - 30, 2, 22,
        {goldMid[1], goldMid[2], goldMid[3]},
        {goldDark[1] - 0.1, goldDark[2] - 0.1, goldDark[3] - 0.05}, false)
    love.graphics.setColor(bannerColor)
    love.graphics.polygon("fill", bx + 1, by - 28, bx + 18, by - 22, bx + 15, by - 14, bx + 1, by - 10)
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.polygon("fill", bx + 1, by - 28, bx + 8, by - 25, bx + 6, by - 18, bx + 1, by - 16)
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.polygon("fill", bx + 12, by - 23, bx + 18, by - 22, bx + 15, by - 14, bx + 10, by - 16)
    love.graphics.setColor(emblemColor)
    -- Sword emblem for barracks
    love.graphics.polygon("fill", bx + 9, by - 22, bx + 10, by - 14, bx + 8, by - 14)
    love.graphics.rectangle("fill", bx + 6, by - 17, 6, 2)
end

-- Initialize the palette renderer
local function initPaletteRenderer()
    local canvasSize = 128  -- 3x3 building but needs larger canvas for 2x scale isometric
    
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

local Barracks = {}
Barracks.__index = Barracks

Barracks.GRID_SIZE = 3

-- Build costs
Barracks.COST_GOLD = 600
Barracks.COST_LUMBER = 100
Barracks.BUILD_TIME = 45.0

-- Unit production costs
Barracks.FOOTMAN_COST_GOLD = 135
Barracks.FOOTMAN_COST_LUMBER = 0
Barracks.FOOTMAN_TIME = 6.0

-- Static counter for unique IDs
local barracksIdCounter = 0

function Barracks.new(params)
    local self = setmetatable({}, Barracks)
    
    barracksIdCounter = barracksIdCounter + 1
    self.uniqueId = barracksIdCounter
    self.animTimer = 0
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = Barracks.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "barracks"
    self.name = "Barracks"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    self.owner = params.owner or nil
    
    -- Combat stats
    self.maxHp = 80
    self.hp = self.maxHp
    self.sightRadius = 6
    
    -- Building construction state
    self.isBuilding = params.isBuilding or false
    self.buildProgress = 0
    self.buildTime = Barracks.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    -- Production state
    self.isProducing = false
    self.productionTime = Barracks.FOOTMAN_TIME
    self.productionTimer = 0
    self.productionQueue = {}
    self.maxQueueSize = 5
    
    -- Flash effect for damage
    self.flashTimer = 0
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function Barracks:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function Barracks:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function Barracks:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function Barracks:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function Barracks:update(dt)
    self.animTimer = (self.animTimer or 0) + dt
    
    -- Update flash timer
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
    
    -- Handle construction
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return false, true  -- unit ready, build complete
        end
        return false, false
    end
    
    -- Handle production
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= self.productionTime then
            if #self.productionQueue > 0 then
                table.remove(self.productionQueue, 1)
            end
            
            if #self.productionQueue > 0 then
                self.productionTimer = 0
            else
                self.isProducing = false
                self.productionTimer = 0
            end
            return true, false  -- unit ready
        end
    end
    return false, false
end

function Barracks:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Draw construction scaffolding if being built
    if self.isBuilding then
        love.graphics.setColor(0.5, 0.4, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.3, 0.8)
        love.graphics.rectangle("fill", x + 5, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + size - 9, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 2, size - 10, 4)
        
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
    
    -- Use palette shader if enabled
    if usePaletteShader and PaletteShader then
        initPaletteRenderer()
        if paletteRenderer then
            paletteRenderer:beginCapture()
            -- Offset to position 96px building in 128px canvas (raised 10%)
            self:drawBarracksIso(16, 19, size)
            paletteRenderer:endCapture()
            paletteRenderer:draw(x - 16, y - 19, 1)
        end
    else
        self:drawBarracksIso(x, y, size)
    end
    
    -- Damage flash
    if self.flashTimer > 0 then
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.rectangle("fill", x, y, size, size)
    end
    
    -- Selection highlight
    if self.selected then
        local playerTeam = Teams and Teams.PLAYER or 1
        if self.team == playerTeam then
            love.graphics.setColor(0, 1, 0, 0.8)
        else
            love.graphics.setColor(1, 0, 0, 0.8)
        end
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
    end
    
    -- Production progress bar
    if self.isProducing then
        local barW = size - 10
        local progress = self.productionTimer / self.productionTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.8, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    self:drawHealthBar()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Isometric Barracks drawing (2x scale)
function Barracks:drawBarracksIso(x, y, size)
    local originX = x + size/2
    local originY = y + size - 16  -- Adjusted up to prevent cutoff
    local scale = 2  -- 2x scale factor
    
    -- Color palette - martial/military theme
    local stoneTop = {0.62, 0.58, 0.52}
    local stoneLeft = {0.45, 0.42, 0.38}
    local stoneRight = {0.52, 0.48, 0.44}
    local stoneDark = {0.32, 0.30, 0.28}
    local roofLeft = {0.35, 0.18, 0.12}
    local roofRight = {0.48, 0.25, 0.16}
    local roofFront = {0.40, 0.20, 0.14}
    local woodColor = {0.40, 0.28, 0.18}
    local woodDark = {0.28, 0.18, 0.12}
    local metalColor = {0.55, 0.55, 0.58}
    local metalDark = {0.38, 0.38, 0.42}
    local doorColor = {0.22, 0.15, 0.10}
    local dirtColor = {0.42, 0.35, 0.28}
    local dirtDark = {0.32, 0.26, 0.20}
    
    -- === DIRT TRAINING GROUND ===
    for layer = 0, 3 do
        local t = layer / 3
        local r = dirtDark[1] + (dirtColor[1] - dirtDark[1]) * t
        local g = dirtDark[2] + (dirtColor[2] - dirtDark[2]) * t
        local b = dirtDark[3] + (dirtColor[3] - dirtDark[3]) * t
        local dirtW = (70 - layer * 6) * scale
        local dirtD = (35 - layer * 3) * scale
        isoQuad(
            {-dirtW/2, -dirtD/2, (-2 + layer * 0.5) * scale},
            {dirtW/2, -dirtD/2, (-2 + layer * 0.5) * scale},
            {dirtW/2, dirtD/2, (-2 + layer * 0.5) * scale},
            {-dirtW/2, dirtD/2, (-2 + layer * 0.5) * scale},
            originX, originY, {r, g, b}
        )
    end
    
    -- === MAIN BARRACKS BUILDING ===
    local mainW = 55 * scale
    local mainD = 35 * scale
    local mainH = 32 * scale
    local mainX = -mainW/2
    local mainY = -mainD/2 - 5 * scale
    
    isoBox(mainX, mainY, 0, mainW, mainD, mainH, originX, originY,
           stoneTop, stoneLeft, stoneRight)
    
    -- Stone texture lines
    love.graphics.setColor(stoneDark[1], stoneDark[2], stoneDark[3], 0.35)
    for row = 1, 3 do
        local z = row * 9 * scale
        local sx1, sy1 = isoProject(mainX, mainY + mainD, z, originX, originY)
        local sx2, sy2 = isoProject(mainX + mainW, mainY + mainD, z, originX, originY)
        love.graphics.line(sx1, sy1, sx2, sy2)
    end
    for row = 1, 3 do
        local z = row * 9 * scale
        local sx1, sy1 = isoProject(mainX + mainW, mainY, z, originX, originY)
        local sx2, sy2 = isoProject(mainX + mainW, mainY + mainD, z, originX, originY)
        love.graphics.line(sx1, sy1, sx2, sy2)
    end
    
    -- === SLOPED ROOF ===
    local roofBase = mainH
    local roofPeak = 16 * scale
    
    -- Left roof slope
    isoQuad(
        {mainX - 3*scale, mainY - 3*scale, roofBase},
        {mainX - 3*scale, mainY + mainD + 3*scale, roofBase},
        {0, mainY + mainD/2, roofBase + roofPeak},
        {0, mainY + mainD/2, roofBase + roofPeak},
        originX, originY, roofLeft
    )
    
    -- Right roof slope
    isoQuad(
        {mainX + mainW + 3*scale, mainY - 3*scale, roofBase},
        {mainX + mainW + 3*scale, mainY + mainD + 3*scale, roofBase},
        {0, mainY + mainD/2, roofBase + roofPeak},
        {0, mainY + mainD/2, roofBase + roofPeak},
        originX, originY, roofRight
    )
    
    -- Roof ridge
    love.graphics.setColor(0.55, 0.30, 0.20, 1)
    local rx1, ry1 = isoProject(0, mainY - 3*scale, roofBase + roofPeak, originX, originY)
    local rx2, ry2 = isoProject(0, mainY + mainD + 3*scale, roofBase + roofPeak, originX, originY)
    love.graphics.setLineWidth(3)
    love.graphics.line(rx1, ry1, rx2, ry2)
    love.graphics.setLineWidth(1)
    
    -- === FRONT DOOR (large garrison entrance) ===
    local doorW = 16 * scale
    local doorH = 20 * scale
    local doorX = -doorW/2
    
    -- Door frame
    isoQuad(
        {doorX - 2*scale, mainY + mainD, 0},
        {doorX + doorW + 2*scale, mainY + mainD, 0},
        {doorX + doorW + 2*scale, mainY + mainD, doorH + 3*scale},
        {doorX - 2*scale, mainY + mainD, doorH + 3*scale},
        originX, originY, stoneDark
    )
    
    -- Door opening (dark)
    isoQuad(
        {doorX, mainY + mainD + 0.5*scale, 0},
        {doorX + doorW, mainY + mainD + 0.5*scale, 0},
        {doorX + doorW, mainY + mainD + 0.5*scale, doorH},
        {doorX, mainY + mainD + 0.5*scale, doorH},
        originX, originY, doorColor
    )
    
    -- Door arch
    local archY = mainY + mainD + 0.5*scale
    local asx1, asy1 = isoProject(doorX, archY, doorH, originX, originY)
    local asx2, asy2 = isoProject(doorX + doorW, archY, doorH, originX, originY)
    local asx3, asy3 = isoProject(doorX + doorW/2, archY, doorH + 4*scale, originX, originY)
    love.graphics.setColor(doorColor[1], doorColor[2], doorColor[3], 1)
    love.graphics.polygon("fill", asx1, asy1, asx2, asy2, asx3, asy3)
    
    -- === WINDOW SLITS (arrow loops) ===
    love.graphics.setColor(0.12, 0.10, 0.08, 1)
    -- Left wall windows
    for i = 0, 1 do
        local winX = mainX + 10*scale + i * 18*scale
        isoQuad(
            {winX, mainY + mainD, 14*scale},
            {winX + 4*scale, mainY + mainD, 14*scale},
            {winX + 4*scale, mainY + mainD, 24*scale},
            {winX, mainY + mainD, 24*scale},
            originX, originY, {0.12, 0.10, 0.08}
        )
    end
    -- Right wall windows
    for i = 0, 1 do
        isoQuad(
            {mainX + mainW, mainY + 8*scale + i * 14*scale, 14*scale},
            {mainX + mainW, mainY + 12*scale + i * 14*scale, 14*scale},
            {mainX + mainW, mainY + 12*scale + i * 14*scale, 24*scale},
            {mainX + mainW, mainY + 8*scale + i * 14*scale, 24*scale},
            originX, originY, {0.12, 0.10, 0.08}
        )
    end
    
    -- === TRAINING DUMMY in yard ===
    local dummyX, dummyY = 20*scale, 18*scale
    -- Pole
    love.graphics.setColor(woodColor[1], woodColor[2], woodColor[3], 1)
    local dp1x, dp1y = isoProject(dummyX, dummyY, 0, originX, originY)
    local dp2x, dp2y = isoProject(dummyX, dummyY, 18*scale, originX, originY)
    love.graphics.setLineWidth(4)
    love.graphics.line(dp1x, dp1y, dp2x, dp2y)
    -- Crossbar (arms)
    local da1x, da1y = isoProject(dummyX - 6*scale, dummyY, 14*scale, originX, originY)
    local da2x, da2y = isoProject(dummyX + 6*scale, dummyY, 14*scale, originX, originY)
    love.graphics.line(da1x, da1y, da2x, da2y)
    -- Head (sack)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.65, 0.55, 0.40, 1)
    local dhx, dhy = isoProject(dummyX, dummyY, 20*scale, originX, originY)
    love.graphics.circle("fill", dhx, dhy, 6)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", dhx - 2, dhy - 2, 1.5)
    love.graphics.circle("fill", dhx + 2, dhy - 2, 1.5)
    
    -- === WEAPONS RACK ===
    local rackX, rackY = -24*scale, 16*scale
    -- Rack frame
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    local wr1x, wr1y = isoProject(rackX, rackY, 0, originX, originY)
    local wr2x, wr2y = isoProject(rackX, rackY, 14*scale, originX, originY)
    local wr3x, wr3y = isoProject(rackX + 10*scale, rackY, 0, originX, originY)
    local wr4x, wr4y = isoProject(rackX + 10*scale, rackY, 14*scale, originX, originY)
    love.graphics.setLineWidth(3)
    love.graphics.line(wr1x, wr1y, wr2x, wr2y)
    love.graphics.line(wr3x, wr3y, wr4x, wr4y)
    -- Horizontal bar
    local wh1x, wh1y = isoProject(rackX, rackY, 12*scale, originX, originY)
    local wh2x, wh2y = isoProject(rackX + 10*scale, rackY, 12*scale, originX, originY)
    love.graphics.line(wh1x, wh1y, wh2x, wh2y)
    love.graphics.setLineWidth(1)
    
    -- Swords on rack
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    for i = 0, 2 do
        local swX = rackX + 2*scale + i * 3*scale
        local sw1x, sw1y = isoProject(swX, rackY - 1*scale, 12*scale, originX, originY)
        local sw2x, sw2y = isoProject(swX, rackY - 1*scale, 2*scale, originX, originY)
        love.graphics.setLineWidth(2)
        love.graphics.line(sw1x, sw1y, sw2x, sw2y)
        -- Hilt
        love.graphics.setColor(woodColor[1], woodColor[2], woodColor[3], 1)
        local shx, shy = isoProject(swX, rackY - 1*scale, 12*scale, originX, originY)
        love.graphics.circle("fill", shx, shy, 2.5)
        love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    end
    love.graphics.setLineWidth(1)
    
    -- === TEAM BANNER ===
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {0.65, 0.20, 0.15, 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {0.85, 0.75, 0.35, 1}
    
    -- Banner pole on roof
    local poleX = mainX + mainW - 8*scale
    local poleY = mainY + mainD/2
    love.graphics.setColor(woodColor[1], woodColor[2], woodColor[3], 1)
    local px1, py1 = isoProject(poleX, poleY, roofBase + roofPeak - 5*scale, originX, originY)
    local px2, py2 = isoProject(poleX, poleY, roofBase + roofPeak + 18*scale, originX, originY)
    love.graphics.setLineWidth(3)
    love.graphics.line(px1, py1, px2, py2)
    love.graphics.setLineWidth(1)
    
    -- Banner cloth
    local bx, by = isoProject(poleX + 2*scale, poleY, roofBase + roofPeak + 15*scale, originX, originY)
    love.graphics.setColor(bannerColor[1], bannerColor[2], bannerColor[3], 1)
    local wave = math.sin((self.animTimer or 0) * 3) * 2
    love.graphics.polygon("fill",
        bx, by,
        bx + 18 + wave, by + 3,
        bx + 16 + wave, by + 16,
        bx, by + 13)
    -- Sword emblem
    love.graphics.setColor(emblemColor[1], emblemColor[2], emblemColor[3], 1)
    love.graphics.polygon("fill", bx + 9 + wave*0.5, by + 4, bx + 11 + wave*0.5, by + 12, bx + 7 + wave*0.5, by + 12)
    love.graphics.rectangle("fill", bx + 5 + wave*0.5, by + 7, 8, 2)
    
    -- === TORCHES ===
    local torch1x, torch1y = isoProject(doorX - 8*scale, mainY + mainD + 2*scale, 16*scale, originX, originY)
    local torch2x, torch2y = isoProject(doorX + doorW + 8*scale, mainY + mainD + 2*scale, 16*scale, originX, originY)
    drawTorchFlame(torch1x, torch1y)
    drawTorchFlame(torch2x, torch2y)
end

function Barracks:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

-- Combat Methods
function Barracks:takeDamage(amount)
    self.hp = self.hp - amount
    self.flashTimer = 0.1
end

function Barracks:isDead()
    return self.hp <= 0
end

function Barracks:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 10
    local barHeight = 6
    local barX = x + 5
    local barY = y - 12
    
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
    
    local healthPct = self.hp / self.maxHp
    love.graphics.setColor(1 - healthPct, healthPct, 0.2, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPct, barHeight)
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
end

-- Production Methods
function Barracks:startProduction(unitType)
    unitType = unitType or "footman"
    if #self.productionQueue < self.maxQueueSize then
        table.insert(self.productionQueue, unitType)
        
        if not self.isProducing and #self.productionQueue > 0 then
            self.isProducing = true
            self.productionTimer = 0
        end
        return true
    end
    return false
end

function Barracks:cancelProduction()
    if #self.productionQueue > 0 then
        table.remove(self.productionQueue)
        if #self.productionQueue == 0 then
            self.isProducing = false
            self.productionTimer = 0
        end
        return Barracks.FOOTMAN_COST_GOLD
    end
    return 0
end

function Barracks:getQueueSize()
    return #self.productionQueue
end

function Barracks:canProduce()
    return self.completed and not self.isBuilding and #self.productionQueue < self.maxQueueSize
end

function Barracks:getProductionProgress()
    if self.isProducing then
        return math.floor((self.productionTimer / self.productionTime) * 100)
    end
    return 0
end

function Barracks:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function Barracks:getSpawnPos()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize + 20, wy + self.pixelSize / 2
end

function Barracks:drawOnMinimap(mapX, mapY, scale)
    if Teams then
        local teamColor = Teams.getColor(self.team, "minimapBuilding")
        love.graphics.setColor(teamColor[1], teamColor[2], teamColor[3], 1)
    else
        love.graphics.setColor(0.65, 0.25, 0.15, 1)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

-- Static functions for palette shader control
function Barracks.setPaletteShaderEnabled(enabled)
    usePaletteShader = enabled
end

function Barracks.isPaletteShaderEnabled()
    return usePaletteShader
end

function Barracks.setPalette(palette)
    if paletteRenderer then
        paletteRenderer:setPalette(palette)
    end
end

function Barracks.getPaletteShader()
    initPaletteRenderer()
    return paletteRenderer
end

Barracks.PALETTES = PaletteShader and PaletteShader.PALETTES or {}

return Barracks
