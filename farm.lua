--[[
    Farm
    Provides unit capacity (+4 units per farm)
    Size: 2x2 tiles, grid-aligned
    Style: Isometric farmhouse with wheat fields and fence
]]

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Palette shader for retro pixel art effect
local PaletteShader
pcall(function() PaletteShader = require("palette_shader") end)

-- Static palette renderer
local paletteRenderer = nil
local usePaletteShader = true

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
    
    -- Left face
    isoQuad(
        {x, y + d, z},
        {x, y + d, z + h},
        {x + w, y + d, z + h},
        {x + w, y + d, z},
        originX, originY, leftColor
    )
    
    -- Right face
    isoQuad(
        {x + w, y, z},
        {x + w, y, z + h},
        {x + w, y + d, z + h},
        {x + w, y + d, z},
        originX, originY, rightColor
    )
end

-- Initialize palette renderer
local function initPaletteRenderer()
    local canvasSize = 96  -- 2x2 building
    
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

local Farm = {}
Farm.__index = Farm

Farm.GRID_SIZE = 2
Farm.COST_GOLD = 250
Farm.COST_LUMBER = 50
Farm.BUILD_TIME = 10.0
Farm.CAPACITY_BONUS = 4

-- Static counter for unique IDs
local farmIdCounter = 0

function Farm.new(params)
    local self = setmetatable({}, Farm)
    
    farmIdCounter = farmIdCounter + 1
    self.uniqueId = farmIdCounter
    self.animTimer = 0
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = Farm.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "farm"
    self.name = "Farm"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 50
    self.hp = self.maxHp
    self.sightRadius = 5
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = Farm.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function Farm:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function Farm:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function Farm:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function Farm:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function Farm:update(dt)
    self.animTimer = (self.animTimer or 0) + dt
    
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

function Farm:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction site
        love.graphics.setColor(0.5, 0.45, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.35, 0.8)
        love.graphics.rectangle("fill", x + 5, y + 10, 20, 8)
        love.graphics.rectangle("fill", x + size - 25, y + 15, 20, 8)
        
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
        
        if self.selected then
            love.graphics.setColor(0, 1, 0, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    
    -- Use palette shader with 2x scaling
    if usePaletteShader and PaletteShader then
        initPaletteRenderer()
        if paletteRenderer then
            paletteRenderer:beginCapture()
            self:drawFarmIso(16, 16, 64)
            paletteRenderer:endCapture()
            
            local drawScale = 2
            local canvasSize = 96
            local scaledSize = canvasSize * drawScale
            local offsetX = x + (size - scaledSize) / 2
            local offsetY = y + size - scaledSize + 32
            paletteRenderer:draw(offsetX, offsetY, drawScale)
        end
    else
        love.graphics.push()
        local drawScale = 2
        local canvasSize = 96
        local scaledSize = canvasSize * drawScale
        local offsetX = x + (size - scaledSize) / 2
        local offsetY = y + size - scaledSize + 32
        love.graphics.translate(offsetX, offsetY)
        love.graphics.scale(drawScale, drawScale)
        self:drawFarmIso(16, 16, 64)
        love.graphics.pop()
    end
    
    -- Selection
    if self.selected then
        local playerTeam = Teams and Teams.PLAYER or 1
        if self.team == playerTeam then
            love.graphics.setColor(0, 1, 0, 0.8)
        else
            love.graphics.setColor(1, 0, 0, 0.8)
        end
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    self:drawHealthBar()
    love.graphics.setColor(1, 1, 1, 1)
end

function Farm:drawFarmIso(x, y, size)
    local scale = 1
    local originX = x + size/2
    local originY = y + size - 8
    
    -- Colors
    local woodTop = {0.58, 0.45, 0.30}
    local woodLeft = {0.45, 0.35, 0.22}
    local woodRight = {0.52, 0.40, 0.26}
    local woodDark = {0.35, 0.26, 0.16}
    local thatchTop = {0.68, 0.60, 0.38}
    local thatchLeft = {0.55, 0.48, 0.28}
    local thatchRight = {0.60, 0.52, 0.32}
    local dirtColor = {0.48, 0.40, 0.28}
    local wheatColor = {0.82, 0.72, 0.32}
    local wheatDark = {0.65, 0.55, 0.25}
    local fenceColor = {0.50, 0.38, 0.24}
    
    -- === DIRT GROUND ===
    isoQuad(
        {-26*scale, -26*scale, 0},
        {26*scale, -26*scale, 0},
        {26*scale, 26*scale, 0},
        {-26*scale, 26*scale, 0},
        originX, originY, dirtColor
    )
    
    -- === WHEAT FIELD (front right area) ===
    local fieldX, fieldY = 2*scale, 2*scale
    
    -- Wheat stalks
    local time = self.animTimer or 0
    for row = 0, 3 do
        for col = 0, 3 do
            local wx = fieldX + 2 + col * 5*scale
            local wy = fieldY + 2 + row * 5.5*scale
            local sway = math.sin(time * 1.8 + row * 0.6 + col * 0.4) * 0.6
            
            local bx, by = isoProject(wx + sway * 0.3, wy, 0, originX, originY)
            local tx, ty = isoProject(wx + sway, wy, 5*scale, originX, originY)
            
            -- Stalk
            love.graphics.setColor(wheatDark[1], wheatDark[2], wheatDark[3], 1)
            love.graphics.setLineWidth(1)
            love.graphics.line(bx, by, tx, ty)
            
            -- Wheat head
            love.graphics.setColor(wheatColor[1], wheatColor[2], wheatColor[3], 1)
            love.graphics.ellipse("fill", tx, ty - 1, 1.5, 2.5)
        end
    end
    
    -- === FARMHOUSE ===
    local houseW, houseD, houseH = 20*scale, 16*scale, 12*scale
    local houseX, houseY = -22*scale, -18*scale
    
    -- House walls
    isoBox(houseX, houseY, 0, houseW, houseD, houseH, originX, originY,
           woodTop, woodLeft, woodRight)
    
    -- Wood plank lines
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 0.4)
    for i = 1, 2 do
        local z = i * 4*scale
        local lx1, ly1 = isoProject(houseX, houseY + houseD, z, originX, originY)
        local lx2, ly2 = isoProject(houseX + houseW, houseY + houseD, z, originX, originY)
        love.graphics.line(lx1, ly1, lx2, ly2)
    end
    
    -- === THATCHED ROOF ===
    local roofBase = houseH
    local roofPeak = 9*scale
    local roofOverhang = 3*scale
    
    -- Left slope
    isoQuad(
        {houseX - roofOverhang, houseY - roofOverhang, roofBase},
        {houseX + houseW/2, houseY + houseD/2, roofBase + roofPeak},
        {houseX + houseW/2, houseY + houseD/2, roofBase + roofPeak},
        {houseX - roofOverhang, houseY + houseD + roofOverhang, roofBase},
        originX, originY, thatchLeft
    )
    
    -- Right slope
    isoQuad(
        {houseX + houseW + roofOverhang, houseY - roofOverhang, roofBase},
        {houseX + houseW/2, houseY + houseD/2, roofBase + roofPeak},
        {houseX + houseW/2, houseY + houseD/2, roofBase + roofPeak},
        {houseX + houseW + roofOverhang, houseY + houseD + roofOverhang, roofBase},
        originX, originY, thatchRight
    )
    
    -- Front gable
    isoQuad(
        {houseX - roofOverhang, houseY + houseD + roofOverhang, roofBase},
        {houseX + houseW/2, houseY + houseD/2, roofBase + roofPeak},
        {houseX + houseW/2, houseY + houseD/2, roofBase + roofPeak},
        {houseX + houseW + roofOverhang, houseY + houseD + roofOverhang, roofBase},
        originX, originY, thatchTop
    )
    
    -- === DOOR ===
    local doorW, doorH = 5*scale, 9*scale
    local doorX = houseX + houseW/2 - doorW/2
    
    isoQuad(
        {doorX, houseY + houseD + 0.5, 0},
        {doorX + doorW, houseY + houseD + 0.5, 0},
        {doorX + doorW, houseY + houseD + 0.5, doorH},
        {doorX, houseY + houseD + 0.5, doorH},
        originX, originY, woodDark
    )
    
    -- === WINDOW ===
    local winX, winY = houseX + houseW, houseY + houseD/2 - 2*scale
    isoQuad(
        {winX + 0.5, winY, 4*scale},
        {winX + 0.5, winY + 5*scale, 4*scale},
        {winX + 0.5, winY + 5*scale, 8*scale},
        {winX + 0.5, winY, 8*scale},
        originX, originY, {0.4, 0.5, 0.6, 0.8}
    )
    
    -- === FENCE ===
    love.graphics.setColor(fenceColor[1], fenceColor[2], fenceColor[3], 1)
    
    -- Front fence posts
    for i = 0, 2 do
        local postX = -2*scale + i * 12*scale
        local postY = 24*scale
        local p1x, p1y = isoProject(postX, postY, 0, originX, originY)
        local p2x, p2y = isoProject(postX, postY, 6*scale, originX, originY)
        love.graphics.setLineWidth(2)
        love.graphics.line(p1x, p1y, p2x, p2y)
    end
    
    -- Fence rails
    love.graphics.setLineWidth(1)
    local r1x1, r1y1 = isoProject(-2*scale, 24*scale, 2*scale, originX, originY)
    local r1x2, r1y2 = isoProject(22*scale, 24*scale, 2*scale, originX, originY)
    love.graphics.line(r1x1, r1y1, r1x2, r1y2)
    
    local r2x1, r2y1 = isoProject(-2*scale, 24*scale, 4.5*scale, originX, originY)
    local r2x2, r2y2 = isoProject(22*scale, 24*scale, 4.5*scale, originX, originY)
    love.graphics.line(r2x1, r2y1, r2x2, r2y2)
    
    -- === HAY BALES ===
    local hayX, hayY = houseX + houseW + 3*scale, houseY + houseD - 2*scale
    love.graphics.setColor(0.72, 0.62, 0.35, 1)
    local hbx, hby = isoProject(hayX, hayY, 0, originX, originY)
    love.graphics.ellipse("fill", hbx, hby, 4, 2.5)
    love.graphics.setColor(0.65, 0.55, 0.30, 1)
    love.graphics.ellipse("fill", hbx - 1, hby - 2.5, 3.5, 2)
end

function Farm:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function Farm:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function Farm:updateUI(resources, screenW, screenH, font) end
function Farm:drawUI() end
function Farm:mousepressed(x, y, button) end
function Farm:mousereleased(x, y, button) end

-- Combat Methods --

function Farm:takeDamage(amount)
    self.hp = self.hp - amount
end

function Farm:isDead()
    return self.hp <= 0
end

function Farm:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 10
    local barHeight = 4
    local barX = x + 5
    local barY = y - 8
    
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
    
    local healthPct = self.hp / self.maxHp
    love.graphics.setColor(1 - healthPct, healthPct, 0.2, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPct, barHeight)
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
end

function Farm:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        if Teams then
            Teams.setColor(self.team, "minimapBuilding")
        else
            love.graphics.setColor(0.5, 0.6, 0.3, 1)
        end
    else
        love.graphics.setColor(0.4, 0.4, 0.3, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

-- Static functions
Farm.setPaletteShaderEnabled = function(enabled)
    usePaletteShader = enabled
end

Farm.isPaletteShaderEnabled = function()
    return usePaletteShader
end

return Farm
