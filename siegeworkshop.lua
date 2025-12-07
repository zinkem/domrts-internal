--[[
    Siege Workshop
    Military building that produces siege units
    Size: 3x3 tiles, grid-aligned
    Style: Isometric industrial forge with smokestacks, gears, catapult arm
    Requires: Keep (Town Hall tier 3)
    Produces: Flying Scout, Ballista, Kamikaze
]]

local Button = require("button")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Palette shader for retro pixel art effect
local PaletteShader
pcall(function() PaletteShader = require("palette_shader") end)

-- Static palette renderer
local paletteRenderer = nil
local usePaletteShader = true

-- Smoke particle system
local smokeParticles = {}

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

-- Update smoke particles
local function updateSmokeParticles(dt, buildingId)
    if not smokeParticles[buildingId] then
        smokeParticles[buildingId] = {}
    end
    
    local particles = smokeParticles[buildingId]
    
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        p.y = p.y - p.speed * dt
        p.x = p.x + math.sin(p.life * 2.5 + p.seed) * 0.5
        p.size = p.size + dt * 4
        p.alpha = (p.life / p.maxLife) * 0.45
        
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
    
    -- Spawn new smoke
    if #particles < 15 and math.random() < dt * 6 then
        table.insert(particles, {
            x = (math.random() - 0.5) * 8,
            y = 0,
            speed = 20 + math.random() * 15,
            size = 4 + math.random() * 3,
            life = 2.0 + math.random() * 0.8,
            maxLife = 2.8,
            alpha = 0.45,
            seed = math.random() * 10
        })
    end
end

local function drawSmokeParticles(buildingId, screenX, screenY)
    local particles = smokeParticles[buildingId]
    if not particles then return end
    
    for _, p in ipairs(particles) do
        love.graphics.setColor(0.35, 0.35, 0.38, p.alpha)
        love.graphics.circle("fill", screenX + p.x, screenY + p.y, p.size)
    end
end

-- Initialize palette renderer
local function initPaletteRenderer()
    local canvasSize = 128
    
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

local SiegeWorkshop = {}
SiegeWorkshop.__index = SiegeWorkshop

SiegeWorkshop.GRID_SIZE = 3
SiegeWorkshop.COST_GOLD = 800
SiegeWorkshop.COST_LUMBER = 400
SiegeWorkshop.BUILD_TIME = 25.0

-- Unit costs
SiegeWorkshop.FLYINGSCOUT_COST_GOLD = 200
SiegeWorkshop.FLYINGSCOUT_COST_LUMBER = 100
SiegeWorkshop.FLYINGSCOUT_TIME = 12.0

SiegeWorkshop.BALLISTA_COST_GOLD = 500
SiegeWorkshop.BALLISTA_COST_LUMBER = 200
SiegeWorkshop.BALLISTA_TIME = 18.0

SiegeWorkshop.KAMIKAZE_COST_GOLD = 300
SiegeWorkshop.KAMIKAZE_COST_LUMBER = 100
SiegeWorkshop.KAMIKAZE_TIME = 8.0

-- Static counter for unique IDs
local siegeWorkshopIdCounter = 0

function SiegeWorkshop.new(params)
    local self = setmetatable({}, SiegeWorkshop)
    
    siegeWorkshopIdCounter = siegeWorkshopIdCounter + 1
    self.uniqueId = siegeWorkshopIdCounter
    self.animTimer = 0
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = SiegeWorkshop.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "siegeworkshop"
    self.name = "Siege Workshop"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 90
    self.hp = self.maxHp
    self.sightRadius = 6
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = SiegeWorkshop.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    self.isProducing = false
    self.productionTimer = 0
    self.producingUnit = nil
    self.productionTime = 0
    
    -- Gear animation
    self.gearAngle = 0
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function SiegeWorkshop:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function SiegeWorkshop:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function SiegeWorkshop:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function SiegeWorkshop:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function SiegeWorkshop:getSpawnPos()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize + 20, wy + self.pixelSize / 2
end

function SiegeWorkshop:update(dt)
    self.animTimer = (self.animTimer or 0) + dt
    self.gearAngle = (self.gearAngle or 0) + dt * 1.5
    
    -- Update smoke when completed
    if self.completed then
        updateSmokeParticles(dt, self.uniqueId)
    end
    
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return nil, true
        end
        return nil, false
    end
    
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= self.productionTime then
            local unit = self.producingUnit
            self.isProducing = false
            self.productionTimer = 0
            self.producingUnit = nil
            self.productionTime = 0
            return unit, false
        end
    end
    return nil, false
end

function SiegeWorkshop:startProduction(unitType)
    if self.completed and not self.isProducing then
        self.isProducing = true
        self.productionTimer = 0
        self.producingUnit = unitType
        
        if unitType == "flyingscout" then
            self.productionTime = SiegeWorkshop.FLYINGSCOUT_TIME
        elseif unitType == "ballista" then
            self.productionTime = SiegeWorkshop.BALLISTA_TIME
        elseif unitType == "kamikaze" then
            self.productionTime = SiegeWorkshop.KAMIKAZE_TIME
        end
        
        return true
    end
    return false
end

function SiegeWorkshop:canProduce()
    return self.completed and not self.isProducing
end

function SiegeWorkshop:getProductionProgress()
    if self.isProducing and self.productionTime > 0 then
        return math.floor((self.productionTimer / self.productionTime) * 100)
    end
    return 0
end

function SiegeWorkshop:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function SiegeWorkshop:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction scaffolding
        love.graphics.setColor(0.45, 0.4, 0.35, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.5, 0.45, 0.38, 0.8)
        love.graphics.rectangle("fill", x + 5, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + size - 9, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 2, size - 10, 4)
        -- Gears in progress
        love.graphics.setColor(0.4, 0.38, 0.4, 0.8)
        love.graphics.circle("line", x + size/2, y + size/2, 15)
        
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
    
    -- Use palette shader with 2x scaling
    if usePaletteShader and PaletteShader then
        initPaletteRenderer()
        if paletteRenderer then
            paletteRenderer:beginCapture()
            self:drawSiegeWorkshopIso(16, 32, 96)
            paletteRenderer:endCapture()
            
            local drawScale = 2
            local canvasSize = 128
            local scaledSize = canvasSize * drawScale
            local offsetX = x + (size - scaledSize) / 2
            local offsetY = y + size - scaledSize
            paletteRenderer:draw(offsetX, offsetY, drawScale)
        end
    else
        love.graphics.push()
        local drawScale = 2
        local canvasSize = 128
        local scaledSize = canvasSize * drawScale
        local offsetX = x + (size - scaledSize) / 2
        local offsetY = y + size - scaledSize
        love.graphics.translate(offsetX, offsetY)
        love.graphics.scale(drawScale, drawScale)
        self:drawSiegeWorkshopIso(16, 32, 96)
        love.graphics.pop()
    end
    
    -- Smoke particles (outside shader)
    if self.completed then
        local smokeX, smokeY = self:getScreenPos()
        drawSmokeParticles(self.uniqueId, smokeX + size * 0.25, smokeY - 20)
        drawSmokeParticles(self.uniqueId + 1000, smokeX + size * 0.7, smokeY - 15)
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
    end
    
    -- Production progress bar
    if self.completed and self.isProducing then
        local barW = size - 10
        local progress = self.productionTimer / self.productionTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.6, 0.4, 0.3, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    self:drawHealthBar()
    love.graphics.setColor(1, 1, 1, 1)
end

function SiegeWorkshop:drawSiegeWorkshopIso(x, y, size)
    local scale = 1
    local originX = x + size/2
    local originY = y + size - 12
    
    -- Colors
    local stoneTop = {0.45, 0.42, 0.38}
    local stoneLeft = {0.35, 0.33, 0.30}
    local stoneRight = {0.40, 0.38, 0.35}
    local stoneDark = {0.28, 0.26, 0.24}
    local metalColor = {0.48, 0.46, 0.50}
    local metalDark = {0.35, 0.33, 0.38}
    local metalLight = {0.58, 0.56, 0.60}
    local woodColor = {0.50, 0.38, 0.25}
    local woodDark = {0.38, 0.28, 0.18}
    local roofColor = {0.32, 0.30, 0.28}
    local roofDark = {0.25, 0.23, 0.22}
    
    -- === GROUND SHADOW ===
    love.graphics.setColor(0, 0, 0, 0.25)
    local gx, gy = isoProject(0, 0, 0, originX, originY)
    love.graphics.ellipse("fill", gx, gy + 3, 38, 14)
    
    -- === MAIN BUILDING ===
    local mainW, mainD, mainH = 45*scale, 40*scale, 32*scale
    local mainX, mainY = -mainW/2, -mainD/2
    
    isoBox(mainX, mainY, 0, mainW, mainD, mainH, originX, originY,
           stoneTop, stoneLeft, stoneRight)
    
    -- Stone brick texture
    love.graphics.setColor(stoneDark[1], stoneDark[2], stoneDark[3], 0.4)
    for row = 0, 4 do
        for col = 0, 2 do
            local offsetX = (row % 2) * 8*scale
            -- Front wall bricks
            local bx, by = mainX + 5*scale + col * 14*scale + offsetX, mainY + mainD
            local bz = 4*scale + row * 6*scale
            local b1x, b1y = isoProject(bx, by, bz, originX, originY)
            local b2x, b2y = isoProject(bx + 12*scale, by, bz, originX, originY)
            local b3x, b3y = isoProject(bx + 12*scale, by, bz + 5*scale, originX, originY)
            local b4x, b4y = isoProject(bx, by, bz + 5*scale, originX, originY)
            love.graphics.polygon("line", b1x, b1y, b2x, b2y, b3x, b3y, b4x, b4y)
        end
    end
    
    -- === FLAT INDUSTRIAL ROOF ===
    isoQuad(
        {mainX - 3*scale, mainY - 3*scale, mainH},
        {mainX + mainW + 3*scale, mainY - 3*scale, mainH},
        {mainX + mainW + 3*scale, mainY + mainD + 3*scale, mainH},
        {mainX - 3*scale, mainY + mainD + 3*scale, mainH},
        originX, originY, roofColor
    )
    
    -- Roof edge trim
    love.graphics.setColor(roofDark[1], roofDark[2], roofDark[3], 1)
    local re1x, re1y = isoProject(mainX - 3*scale, mainY + mainD + 3*scale, mainH, originX, originY)
    local re2x, re2y = isoProject(mainX + mainW + 3*scale, mainY + mainD + 3*scale, mainH, originX, originY)
    local re3x, re3y = isoProject(mainX + mainW + 3*scale, mainY - 3*scale, mainH, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(re1x, re1y, re2x, re2y)
    love.graphics.line(re2x, re2y, re3x, re3y)
    love.graphics.setLineWidth(1)
    
    -- === SMOKESTACKS ===
    local stack1X, stack1Y = mainX + 8*scale, mainY + 8*scale
    local stack2X, stack2Y = mainX + mainW - 14*scale, mainY + 10*scale
    
    -- Stack 1 (taller)
    isoBox(stack1X, stack1Y, mainH, 8*scale, 8*scale, 18*scale, originX, originY,
           stoneTop, stoneDark, stoneLeft)
    -- Stack 1 cap
    isoBox(stack1X - 1*scale, stack1Y - 1*scale, mainH + 18*scale, 10*scale, 10*scale, 3*scale, originX, originY,
           metalColor, metalDark, metalColor)
    
    -- Stack 2 (shorter)
    isoBox(stack2X, stack2Y, mainH, 8*scale, 8*scale, 14*scale, originX, originY,
           stoneTop, stoneDark, stoneLeft)
    -- Stack 2 cap
    isoBox(stack2X - 1*scale, stack2Y - 1*scale, mainH + 14*scale, 10*scale, 10*scale, 3*scale, originX, originY,
           metalColor, metalDark, metalColor)
    
    -- === LARGE DOORS (workshop entrance) ===
    local doorW, doorH = 28*scale, 26*scale
    local doorX = -doorW/2
    
    -- Door recess
    isoQuad(
        {doorX - 2*scale, mainY + mainD + 0.5, 0},
        {doorX + doorW + 2*scale, mainY + mainD + 0.5, 0},
        {doorX + doorW + 2*scale, mainY + mainD + 0.5, doorH + 3*scale},
        {doorX - 2*scale, mainY + mainD + 0.5, doorH + 3*scale},
        originX, originY, stoneDark
    )
    
    -- Door itself
    isoQuad(
        {doorX, mainY + mainD + 1, 0},
        {doorX + doorW, mainY + mainD + 1, 0},
        {doorX + doorW, mainY + mainD + 1, doorH},
        {doorX, mainY + mainD + 1, doorH},
        originX, originY, woodDark
    )
    
    -- Door arch
    local archCX, archCY = isoProject(0, mainY + mainD + 1, doorH, originX, originY)
    love.graphics.setColor(stoneDark[1], stoneDark[2], stoneDark[3], 1)
    love.graphics.arc("fill", archCX, archCY, 12, math.pi, 2 * math.pi)
    
    -- Iron door bands
    love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
    for band = 0, 2 do
        local bandZ = 5*scale + band * 8*scale
        local db1x, db1y = isoProject(doorX, mainY + mainD + 1, bandZ, originX, originY)
        local db2x, db2y = isoProject(doorX + doorW, mainY + mainD + 1, bandZ, originX, originY)
        love.graphics.setLineWidth(2)
        love.graphics.line(db1x, db1y, db2x, db2y)
    end
    love.graphics.setLineWidth(1)
    
    -- Door hinges
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    for hinge = 0, 1 do
        local hingeZ = 8*scale + hinge * 12*scale
        local h1x, h1y = isoProject(doorX + 2*scale, mainY + mainD + 1, hingeZ, originX, originY)
        local h2x, h2y = isoProject(doorX + doorW - 2*scale, mainY + mainD + 1, hingeZ, originX, originY)
        love.graphics.circle("fill", h1x, h1y, 2.5)
        love.graphics.circle("fill", h2x, h2y, 2.5)
    end
    
    -- === CATAPULT ARM visible inside ===
    local armColor = {0.55, 0.42, 0.28}
    local armX, armY = -4*scale, mainY + mainD - 5*scale
    
    isoQuad(
        {armX - 3*scale, armY, 4*scale},
        {armX + 3*scale, armY, 4*scale},
        {armX + 5*scale, armY, 22*scale},
        {armX - 5*scale, armY, 22*scale},
        originX, originY, armColor
    )
    
    -- Counterweight
    love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
    local cwx, cwy = isoProject(armX, armY, 4*scale, originX, originY)
    love.graphics.rectangle("fill", cwx - 6, cwy - 4, 12, 8)
    
    -- === GEARS ON SIDES ===
    local gear1X, gear1Y = isoProject(mainX + mainW + 1, mainY + mainD/2 - 5*scale, 16*scale, originX, originY)
    local gear2X, gear2Y = isoProject(mainX + mainW + 1, mainY + mainD/2 + 10*scale, 12*scale, originX, originY)
    
    -- Large gear
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    love.graphics.circle("fill", gear1X, gear1Y, 10)
    love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
    love.graphics.circle("fill", gear1X, gear1Y, 5)
    
    -- Gear teeth (animated)
    love.graphics.setColor(metalLight[1], metalLight[2], metalLight[3], 1)
    local numTeeth = 8
    for i = 0, numTeeth - 1 do
        local angle = (i / numTeeth) * math.pi * 2 + (self.gearAngle or 0)
        local tx = gear1X + math.cos(angle) * 8
        local ty = gear1Y + math.sin(angle) * 8
        love.graphics.rectangle("fill", tx - 2, ty - 3, 4, 6)
    end
    
    -- Small gear (counter-rotating)
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    love.graphics.circle("fill", gear2X, gear2Y, 7)
    love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
    love.graphics.circle("fill", gear2X, gear2Y, 3)
    
    -- Small gear teeth
    love.graphics.setColor(metalLight[1], metalLight[2], metalLight[3], 1)
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - (self.gearAngle or 0) * 1.3
        local tx = gear2X + math.cos(angle) * 5.5
        local ty = gear2Y + math.sin(angle) * 5.5
        love.graphics.rectangle("fill", tx - 1.5, ty - 2, 3, 4)
    end
    
    -- === WOOD PILE ===
    local pileX, pileY = mainX + mainW - 5*scale, mainY + mainD + 8*scale
    love.graphics.setColor(woodColor[1], woodColor[2], woodColor[3], 1)
    local p1x, p1y = isoProject(pileX, pileY, 0, originX, originY)
    love.graphics.ellipse("fill", p1x, p1y, 8, 4)
    love.graphics.ellipse("fill", p1x - 3, p1y - 4, 6, 3)
    love.graphics.ellipse("fill", p1x + 2, p1y - 6, 5, 2.5)
    
    -- === BANNER/SIGN ===
    local bannerX, bannerY = mainX + 3*scale, mainY + mainD
    
    -- Pole
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    local bp1x, bp1y = isoProject(bannerX, bannerY, 10*scale, originX, originY)
    local bp2x, bp2y = isoProject(bannerX, bannerY, 28*scale, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(bp1x, bp1y, bp2x, bp2y)
    love.graphics.setLineWidth(1)
    
    -- Banner cloth
    love.graphics.setColor(0.6, 0.25, 0.15, 1)
    love.graphics.polygon("fill",
        bp2x, bp2y,
        bp2x + 14, bp2y + 4,
        bp2x + 12, bp2y + 16,
        bp2x, bp2y + 12
    )
    
    -- Catapult symbol on banner
    love.graphics.setColor(0.85, 0.75, 0.35, 1)
    love.graphics.polygon("fill", 
        bp2x + 4, bp2y + 12, 
        bp2x + 9, bp2y + 12, 
        bp2x + 6.5, bp2y + 5
    )
end

function SiegeWorkshop:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function SiegeWorkshop:updateUI(resources, screenW, screenH, font, currentPop, maxPop) end
function SiegeWorkshop:drawUI() end
function SiegeWorkshop:mousepressed(x, y, button) end
function SiegeWorkshop:mousereleased(x, y, button) end

function SiegeWorkshop:takeDamage(amount)
    self.hp = self.hp - amount
end

function SiegeWorkshop:isDead()
    return self.hp <= 0
end

function SiegeWorkshop:drawHealthBar()
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

function SiegeWorkshop:drawOnMinimap(mapX, mapY, scale)
    if Teams then
        local teamColor = Teams.getColor(self.team, "minimapBuilding")
        love.graphics.setColor(teamColor[1], teamColor[2], teamColor[3], 1)
    else
        love.graphics.setColor(0.45, 0.4, 0.35, 1)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

-- Static functions
SiegeWorkshop.setPaletteShaderEnabled = function(enabled)
    usePaletteShader = enabled
end

SiegeWorkshop.isPaletteShaderEnabled = function()
    return usePaletteShader
end

return SiegeWorkshop
