--[[
    Blacksmith
    Upgrade building for weapons and armor research
    Size: 3x3 tiles, grid-aligned
    Style: Stone forge with anvil, bellows, smoking chimney, and weapon displays
]]

local Button = require("button")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Building renderer for retro pixel art effect
local BuildingRenderer
pcall(function() BuildingRenderer = require("building_renderer") end)

-- Shared isometric utilities
local IsoUtils = require("iso_utils")
local isoProject = IsoUtils.project
local isoQuad = IsoUtils.quad
local isoBox = IsoUtils.box
local isoOctagonalPrism = IsoUtils.octagonalPrism
local isoOctagon = IsoUtils.octagon

-- Smoke particle system
local smokeParticles = {}

-- Helper functions
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

-- Update smoke particles
local function updateSmokeParticles(dt, buildingId)
    if not smokeParticles[buildingId] then
        smokeParticles[buildingId] = {}
    end
    
    local particles = smokeParticles[buildingId]
    
    -- Update existing particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        p.y = p.y - p.speed * dt
        p.x = p.x + math.sin(p.life * 3 + p.seed) * 0.4
        p.size = p.size + dt * 3
        p.alpha = p.life / p.maxLife * 0.5
        
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
    
    -- Spawn new particles
    if #particles < 10 and math.random() < dt * 5 then
        table.insert(particles, {
            x = 0,
            y = 0,
            speed = 18 + math.random() * 12,
            size = 3 + math.random() * 2,
            life = 1.8 + math.random() * 0.6,
            maxLife = 2.4,
            alpha = 0.5,
            seed = math.random() * 10
        })
    end
end

local function drawSmokeParticles(buildingId, screenX, screenY)
    local particles = smokeParticles[buildingId]
    if not particles then return end
    
    for _, p in ipairs(particles) do
        love.graphics.setColor(0.25, 0.25, 0.28, p.alpha)
        love.graphics.circle("fill", screenX + p.x, screenY + p.y, p.size)
    end
end

-- Draw forge fire
local function drawForgeFire(x, y, time, scale)
    scale = scale or 1
    local flicker = math.sin(time * 15) * 0.2 + math.cos(time * 21) * 0.15
    
    -- Outer glow (orange)
    love.graphics.setColor(1, 0.4, 0.08, 0.25 + flicker * 0.1)
    love.graphics.circle("fill", x, y, 12 * scale)
    
    -- Mid flame (yellow-orange)
    love.graphics.setColor(1, 0.6, 0.15, 0.7 + flicker * 0.15)
    love.graphics.circle("fill", x, y - 2 * scale, 8 * scale)
    
    -- Core (bright yellow)
    love.graphics.setColor(1, 0.85, 0.35, 0.95)
    love.graphics.circle("fill", x, y - 3 * scale, 5 * scale)
    
    -- Hot white center
    love.graphics.setColor(1, 0.98, 0.85, 0.9)
    love.graphics.circle("fill", x, y - 4 * scale, 2.5 * scale)
    
    -- Sparks
    for i = 1, 3 do
        local sparkX = x + math.sin(time * 8 + i * 2) * 6 * scale
        local sparkY = y - 5 * scale - math.abs(math.sin(time * 12 + i * 3)) * 8 * scale
        love.graphics.setColor(1, 0.7, 0.2, 0.6 + flicker * 0.3)
        love.graphics.circle("fill", sparkX, sparkY, 1 * scale)
    end
end

local Blacksmith = {}
Blacksmith.__index = Blacksmith

Blacksmith.GRID_SIZE = 3

-- Build costs
Blacksmith.COST_GOLD = 800
Blacksmith.COST_LUMBER = 400
Blacksmith.BUILD_TIME = 40.0

-- Upgrade costs
Blacksmith.UPGRADE_WEAPON_COST = 400
Blacksmith.UPGRADE_ARMOR_COST = 500
Blacksmith.UPGRADE_TIME = 30.0

-- Static counter for unique IDs
local blacksmithIdCounter = 0

function Blacksmith.new(params)
    local self = setmetatable({}, Blacksmith)
    
    blacksmithIdCounter = blacksmithIdCounter + 1
    self.uniqueId = blacksmithIdCounter
    self.animTimer = 0
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = Blacksmith.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "blacksmith"
    self.name = "Blacksmith"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    self.owner = params.owner or nil
    
    -- Combat stats
    self.maxHp = 60
    self.hp = self.maxHp
    self.sightRadius = 5
    
    -- Building construction state
    self.isBuilding = params.isBuilding or false
    self.buildProgress = 0
    self.buildTime = Blacksmith.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    -- Upgrade state
    self.isUpgrading = false
    self.upgradeProgress = 0
    self.upgradeTime = 0
    self.currentUpgrade = nil
    
    -- Research/upgrades completed
    self.weaponLevel = 0
    self.armorLevel = 0
    self.maxUpgradeLevel = 3
    
    -- Flash effect for damage
    self.flashTimer = 0
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function Blacksmith:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function Blacksmith:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function Blacksmith:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function Blacksmith:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function Blacksmith:update(dt)
    self.animTimer = (self.animTimer or 0) + dt
    
    -- Update flash timer
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
    
    -- Update smoke particles when completed
    if self.completed then
        updateSmokeParticles(dt, self.uniqueId)
    end
    
    -- Handle construction
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return false, true  -- upgrade complete, build complete
        end
        return false, false
    end
    
    -- Handle upgrading
    if self.isUpgrading then
        self.upgradeProgress = self.upgradeProgress + dt
        if self.upgradeProgress >= self.upgradeTime then
            self.isUpgrading = false
            self.upgradeProgress = 0
            -- Apply upgrade
            if self.currentUpgrade == "weapon" then
                self.weaponLevel = self.weaponLevel + 1
            elseif self.currentUpgrade == "armor" then
                self.armorLevel = self.armorLevel + 1
            end
            self.currentUpgrade = nil
            return true, false  -- upgrade complete
        end
    end
    
    return false, false
end

function Blacksmith:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Draw construction scaffolding if being built
    if self.isBuilding then
        love.graphics.setColor(0.5, 0.4, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.3, 0.8)
        love.graphics.rectangle("fill", x + 4, y + 4, 3, size - 8)
        love.graphics.rectangle("fill", x + size - 7, y + 4, 3, size - 8)
        love.graphics.rectangle("fill", x + 4, y + size/2 - 2, size - 8, 3)
        
        local barW = size - 8
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 4, y + size/2 - 3, barW, 6, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 4, y + size/2 - 3, barW * progress, 6, 2)
        
        if self.selected then
            love.graphics.setColor(0, 1, 0, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
        end
        
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    
    -- Use palette shader if enabled
    local canvasSize = 128
    local offsetX = x + (size - canvasSize) / 2
    local offsetY = y + size - canvasSize

    if BuildingRenderer and BuildingRenderer.begin("large") then
        self:drawBlacksmithIso(32, 32, 64)
        BuildingRenderer.finishWithSize("large", offsetX, offsetY, 1)
    else
        love.graphics.push()
        love.graphics.translate(offsetX, offsetY)
        self:drawBlacksmithIso(32, 32, 64)
        love.graphics.pop()
    end
    
    -- Draw smoke above the chimney
    if self.completed then
        local smokeX, smokeY = self:getScreenPos()
        -- Chimney is roughly at top-right of building
        drawSmokeParticles(self.uniqueId, smokeX + size * 0.65, smokeY - 15)
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
    
    -- Upgrade progress bar
    if self.isUpgrading then
        local barW = size - 8
        local progress = self.upgradeProgress / self.upgradeTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 4, y + size + 4, barW, 6, 2)
        love.graphics.setColor(0.8, 0.5, 0.2, 1)
        love.graphics.rectangle("fill", x + 4, y + size + 4, barW * progress, 6, 2)
    end
    
    self:drawHealthBar()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Isometric Blacksmith drawing
function Blacksmith:drawBlacksmithIso(x, y, size)
    local originX = x + size/2
    local originY = y + size - 6  -- Bottom edge stays in place
    local scale = 2  -- 2x scale factor
    
    -- Color palette - industrial forge theme
    local stoneTop = {0.55, 0.52, 0.48}
    local stoneLeft = {0.38, 0.35, 0.32}
    local stoneRight = {0.45, 0.42, 0.38}
    local stoneDark = {0.28, 0.26, 0.24}
    local brickTop = {0.52, 0.32, 0.22}
    local brickLeft = {0.38, 0.22, 0.15}
    local brickRight = {0.45, 0.28, 0.18}
    local woodColor = {0.42, 0.30, 0.20}
    local woodDark = {0.30, 0.20, 0.14}
    local metalColor = {0.52, 0.52, 0.55}
    local metalDark = {0.35, 0.35, 0.40}
    local metalLight = {0.68, 0.68, 0.72}
    local roofLeft = {0.28, 0.22, 0.18}
    local roofRight = {0.38, 0.30, 0.24}
    local dirtColor = {0.40, 0.32, 0.25}
    local dirtDark = {0.30, 0.24, 0.18}
    
    -- === DIRT GROUND ===
    for layer = 0, 2 do
        local t = layer / 2
        local r = dirtDark[1] + (dirtColor[1] - dirtDark[1]) * t
        local g = dirtDark[2] + (dirtColor[2] - dirtDark[2]) * t
        local b = dirtDark[3] + (dirtColor[3] - dirtDark[3]) * t
        local dirtW = (50 - layer * 5) * scale
        local dirtD = (25 - layer * 2.5) * scale
        isoQuad(
            {-dirtW/2, -dirtD/2, (-1.5 + layer * 0.5) * scale},
            {dirtW/2, -dirtD/2, (-1.5 + layer * 0.5) * scale},
            {dirtW/2, dirtD/2, (-1.5 + layer * 0.5) * scale},
            {-dirtW/2, dirtD/2, (-1.5 + layer * 0.5) * scale},
            originX, originY, {r, g, b}
        )
    end
    
    -- === MAIN BUILDING (open workshop, octagonal) ===
    local mainR = 20 * scale  -- radius for octagonal shape
    local mainH = 22 * scale
    local mainCX = -3 * scale
    local mainCY = 0

    -- Wall colors for octagonal faces
    local mainWallColors = {
        {stoneRight[1], stoneRight[2], stoneRight[3]},
        {0.42, 0.39, 0.35},
        {stoneLeft[1], stoneLeft[2], stoneLeft[3]},
        {0.35, 0.32, 0.29},
    }

    isoOctagonalPrism(mainCX, mainCY, 0, mainR, mainH, originX, originY, stoneTop, mainWallColors)

    -- Stone texture bands
    for row = 1, 2 do
        local z = row * 8 * scale
        isoOctagon(mainCX, mainCY, z, mainR + 0.3, originX, originY, {stoneDark[1], stoneDark[2], stoneDark[3], 0.25})
    end

    -- === ROOF EAVES ===
    local eaveR = mainR + 5*scale
    local eaveH = 2*scale
    local eaveDark = {roofLeft[1] * 0.8, roofLeft[2] * 0.8, roofLeft[3] * 0.8}
    local eaveWallColors = {
        {eaveDark[1] * 1.1, eaveDark[2] * 1.1, eaveDark[3] * 1.1},
        {eaveDark[1], eaveDark[2], eaveDark[3]},
        {eaveDark[1] * 0.9, eaveDark[2] * 0.9, eaveDark[3] * 0.9},
        {eaveDark[1] * 0.8, eaveDark[2] * 0.8, eaveDark[3] * 0.8},
    }
    isoOctagonalPrism(mainCX, mainCY, mainH - 1*scale, eaveR, eaveH, originX, originY, eaveDark, eaveWallColors)

    -- === SLOPED ROOF (lean-to style, octagonal pyramid) ===
    local roofBase = mainH
    local roofHeight = 10 * scale

    IsoUtils.pyramidRoof(mainCX, mainCY, roofBase, mainR + 2*scale, roofHeight, originX, originY, roofLeft)

    -- === FORGE (brick chimney structure, octagonal) ===
    local forgeR = 8 * scale  -- radius for octagonal shape
    local forgeH = 35 * scale
    local forgeCX = mainCX + mainR - 2*scale
    local forgeCY = -8 * scale

    -- Wall colors for forge octagonal faces
    local forgeWallColors = {
        {brickRight[1], brickRight[2], brickRight[3]},
        {0.42, 0.25, 0.16},
        {brickLeft[1], brickLeft[2], brickLeft[3]},
        {0.35, 0.20, 0.13},
    }

    isoOctagonalPrism(forgeCX, forgeCY, 0, forgeR, forgeH, originX, originY, brickTop, forgeWallColors)

    -- Brick texture bands on chimney
    for row = 1, 5 do
        local z = row * 6 * scale
        isoOctagon(forgeCX, forgeCY, z, forgeR + 0.3, originX, originY, {0.25, 0.15, 0.10, 0.3})
    end

    -- Chimney opening (top) - smaller octagon
    isoOctagon(forgeCX, forgeCY, forgeH, forgeR - 2*scale, originX, originY, {0.15, 0.12, 0.10})

    -- Forge fire opening (front face)
    local forgeFrontY = forgeCY + forgeR
    isoQuad(
        {forgeCX - 4*scale, forgeFrontY, 2*scale},
        {forgeCX + 4*scale, forgeFrontY, 2*scale},
        {forgeCX + 4*scale, forgeFrontY, 12*scale},
        {forgeCX - 4*scale, forgeFrontY, 12*scale},
        originX, originY, {0.12, 0.08, 0.06}
    )

    -- Forge fire glow
    local fireX, fireY = isoProject(forgeCX, forgeFrontY + 1*scale, 7*scale, originX, originY)
    drawForgeFire(fireX, fireY, self.animTimer or 0, 1.2)
    
    -- === ANVIL ===
    local anvilX, anvilY = -8*scale, 8*scale
    -- Anvil base
    isoBox(anvilX - 4*scale, anvilY - 3*scale, 0, 8*scale, 6*scale, 4*scale, originX, originY,
           metalColor, metalDark, metalColor)
    -- Anvil body
    isoBox(anvilX - 5*scale, anvilY - 4*scale, 4*scale, 10*scale, 8*scale, 5*scale, originX, originY,
           metalLight, metalDark, metalColor)
    -- Anvil horn
    isoQuad(
        {anvilX + 5*scale, anvilY, 6*scale},
        {anvilX + 10*scale, anvilY + 2*scale, 7*scale},
        {anvilX + 10*scale, anvilY + 2*scale, 8*scale},
        {anvilX + 5*scale, anvilY + 4*scale, 8*scale},
        originX, originY, metalColor
    )
    -- Anvil highlight
    love.graphics.setColor(1, 1, 1, 0.15)
    local ahx, ahy = isoProject(anvilX - 5*scale, anvilY - 4*scale, 9*scale, originX, originY)
    love.graphics.circle("fill", ahx + 4, ahy, 3)
    
    -- === BELLOWS ===
    local bellowsX, bellowsY = forgeCX - forgeR - 4*scale, forgeCY + 2*scale
    -- Bellows body (leather)
    love.graphics.setColor(0.45, 0.32, 0.22, 1)
    local bl1x, bl1y = isoProject(bellowsX, bellowsY, 3*scale, originX, originY)
    local bl2x, bl2y = isoProject(bellowsX + 8*scale, bellowsY, 5*scale, originX, originY)
    local bl3x, bl3y = isoProject(bellowsX + 8*scale, bellowsY + 6*scale, 5*scale, originX, originY)
    local bl4x, bl4y = isoProject(bellowsX, bellowsY + 6*scale, 3*scale, originX, originY)
    love.graphics.polygon("fill", bl1x, bl1y, bl2x, bl2y, bl3x, bl3y, bl4x, bl4y)
    -- Bellows handle
    love.graphics.setColor(woodColor[1], woodColor[2], woodColor[3], 1)
    local bh1x, bh1y = isoProject(bellowsX - 2*scale, bellowsY + 3*scale, 4*scale, originX, originY)
    local bh2x, bh2y = isoProject(bellowsX - 6*scale, bellowsY + 3*scale, 6*scale, originX, originY)
    love.graphics.setLineWidth(3)
    love.graphics.line(bh1x, bh1y, bh2x, bh2y)
    love.graphics.setLineWidth(1)
    
    -- === TOOL RACK (hammers, tongs) ===
    local rackX, rackY = mainCX - mainR + 4*scale, mainCY + mainR
    -- Rack board
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    local tr1x, tr1y = isoProject(rackX, rackY, 10*scale, originX, originY)
    local tr2x, tr2y = isoProject(rackX + 14*scale, rackY, 10*scale, originX, originY)
    love.graphics.setLineWidth(4)
    love.graphics.line(tr1x, tr1y, tr2x, tr2y)
    love.graphics.setLineWidth(1)
    
    -- Hanging tools
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    for i = 0, 2 do
        local toolX = rackX + 3*scale + i * 5*scale
        local th1x, th1y = isoProject(toolX, rackY, 10*scale, originX, originY)
        local th2x, th2y = isoProject(toolX, rackY, 4*scale, originX, originY)
        love.graphics.setLineWidth(2)
        love.graphics.line(th1x, th1y, th2x, th2y)
        -- Tool head
        if i == 1 then
            -- Hammer head
            love.graphics.setColor(0.50, 0.50, 0.55, 1)
            local hhx, hhy = isoProject(toolX, rackY, 4*scale, originX, originY)
            love.graphics.rectangle("fill", hhx - 5, hhy - 2, 10, 5)
        else
            -- Tongs
            love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
            local tgx, tgy = isoProject(toolX, rackY, 4*scale, originX, originY)
            love.graphics.line(tgx, tgy, tgx - 3, tgy + 6)
            love.graphics.line(tgx, tgy, tgx + 3, tgy + 6)
        end
        love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    end
    love.graphics.setLineWidth(1)
    
    -- === WATER BARREL (for quenching) ===
    local barrelX, barrelY = -22*scale, 6*scale
    -- Barrel body
    love.graphics.setColor(woodColor[1], woodColor[2], woodColor[3], 1)
    local bb1x, bb1y = isoProject(barrelX, barrelY, 0, originX, originY)
    local bb2x, bb2y = isoProject(barrelX, barrelY, 10*scale, originX, originY)
    love.graphics.setLineWidth(10)
    love.graphics.line(bb1x, bb1y, bb2x, bb2y)
    love.graphics.setLineWidth(1)
    -- Barrel bands
    love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
    local bd1x, bd1y = isoProject(barrelX, barrelY, 2*scale, originX, originY)
    local bd2x, bd2y = isoProject(barrelX, barrelY, 8*scale, originX, originY)
    love.graphics.circle("line", bd1x, bd1y, 5.5)
    love.graphics.circle("line", bd2x, bd2y, 5.5)
    -- Water surface
    love.graphics.setColor(0.3, 0.4, 0.5, 0.7)
    local bwx, bwy = isoProject(barrelX, barrelY, 9*scale, originX, originY)
    love.graphics.circle("fill", bwx, bwy, 4)
    
    -- === GLOWING HOT METAL on anvil (if working) ===
    if self.isUpgrading then
        local hotX, hotY = isoProject(anvilX, anvilY, 10*scale, originX, originY)
        love.graphics.setColor(1, 0.5, 0.1, 0.6 + math.sin(self.animTimer * 8) * 0.2)
        love.graphics.rectangle("fill", hotX - 6, hotY - 2, 12, 5)
        love.graphics.setColor(1, 0.8, 0.3, 0.8)
        love.graphics.rectangle("fill", hotX - 5, hotY, 10, 2)
    end
end

function Blacksmith:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

-- Combat Methods
function Blacksmith:takeDamage(amount)
    self.hp = self.hp - amount
    self.flashTimer = 0.1
end

function Blacksmith:isDead()
    return self.hp <= 0
end

function Blacksmith:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 8
    local barHeight = 5
    local barX = x + 4
    local barY = y - 10
    
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
    
    local healthPct = self.hp / self.maxHp
    love.graphics.setColor(1 - healthPct, healthPct, 0.2, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPct, barHeight)
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
end

-- Upgrade Methods
function Blacksmith:startUpgrade(upgradeType)
    if self.isUpgrading then return false end
    
    if upgradeType == "weapon" and self.weaponLevel < self.maxUpgradeLevel then
        self.isUpgrading = true
        self.upgradeProgress = 0
        self.upgradeTime = Blacksmith.UPGRADE_TIME
        self.currentUpgrade = "weapon"
        return true
    elseif upgradeType == "armor" and self.armorLevel < self.maxUpgradeLevel then
        self.isUpgrading = true
        self.upgradeProgress = 0
        self.upgradeTime = Blacksmith.UPGRADE_TIME
        self.currentUpgrade = "armor"
        return true
    end
    return false
end

function Blacksmith:canUpgrade(upgradeType)
    if not self.completed or self.isBuilding or self.isUpgrading then
        return false
    end
    if upgradeType == "weapon" then
        return self.weaponLevel < self.maxUpgradeLevel
    elseif upgradeType == "armor" then
        return self.armorLevel < self.maxUpgradeLevel
    end
    return false
end

function Blacksmith:getUpgradeCost(upgradeType)
    if upgradeType == "weapon" then
        return Blacksmith.UPGRADE_WEAPON_COST * (self.weaponLevel + 1), 0
    elseif upgradeType == "armor" then
        return Blacksmith.UPGRADE_ARMOR_COST * (self.armorLevel + 1), 0
    end
    return 0, 0
end

function Blacksmith:getUpgradeProgress()
    if self.isUpgrading then
        return math.floor((self.upgradeProgress / self.upgradeTime) * 100)
    end
    return 0
end

function Blacksmith:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function Blacksmith:drawOnMinimap(mapX, mapY, scale)
    if Teams then
        local teamColor = Teams.getColor(self.team, "minimapBuilding")
        love.graphics.setColor(teamColor[1] * 0.8, teamColor[2] * 0.6, teamColor[3] * 0.4, 1)
    else
        love.graphics.setColor(0.55, 0.40, 0.25, 1)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return Blacksmith
