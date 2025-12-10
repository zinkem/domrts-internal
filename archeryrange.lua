--[[
    Archery Range
    Military building that produces archers
    Size: 3x3 tiles, grid-aligned
    Style: Open-air training ground with covered archer station, targets, bow racks
    Requires: Barracks
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

local ArcheryRange = {}
ArcheryRange.__index = ArcheryRange

ArcheryRange.GRID_SIZE = 3
ArcheryRange.COST_GOLD = 500
ArcheryRange.COST_LUMBER = 150
ArcheryRange.BUILD_TIME = 18.0
ArcheryRange.ARCHER_COST_GOLD = 150
ArcheryRange.ARCHER_COST_LUMBER = 50
ArcheryRange.ARCHER_TIME = 10.0

-- Static counter for unique IDs
local archeryRangeIdCounter = 0

function ArcheryRange.new(params)
    local self = setmetatable({}, ArcheryRange)

    archeryRangeIdCounter = archeryRangeIdCounter + 1
    self.uniqueId = archeryRangeIdCounter
    self.animTimer = 0

    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = ArcheryRange.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "archeryrange"
    self.name = "Archery Range"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 70
    self.hp = self.maxHp
    self.sightRadius = 6
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = ArcheryRange.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    self.isProducing = false
    self.productionTimer = 0
    self.actionButton = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function ArcheryRange:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function ArcheryRange:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function ArcheryRange:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function ArcheryRange:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function ArcheryRange:getSpawnPos()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize + 20, wy + self.pixelSize / 2
end

function ArcheryRange:update(dt)
    self.animTimer = (self.animTimer or 0) + dt

    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return false, true  -- no archer, build complete
        end
        return false, false
    end
    
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= ArcheryRange.ARCHER_TIME then
            self.isProducing = false
            self.productionTimer = 0
            return true, false  -- archer ready
        end
    end
    return false, false
end

function ArcheryRange:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize

    if self.isBuilding then
        -- Construction scaffolding
        love.graphics.setColor(0.5, 0.45, 0.35, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.35, 0.8)
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

    -- Use palette shader with 2x scaling
    local drawScale = 2
    local canvasSize = 128
    local scaledSize = canvasSize * drawScale
    local offsetX = x + (size - scaledSize) / 2
    local offsetY = y + size - scaledSize

    if BuildingRenderer and BuildingRenderer.begin("large") then
        self:drawArcheryRangeIso(16, 20, 96)
        BuildingRenderer.finishWithSize("large", offsetX, offsetY, drawScale)
    else
        love.graphics.push()
        love.graphics.translate(offsetX, offsetY)
        love.graphics.scale(drawScale, drawScale)
        self:drawArcheryRangeIso(16, 20, 96)
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
        love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
    end

    -- Production progress bar
    if self.completed and self.isProducing then
        local barW = size - 10
        local progress = self.productionTimer / ArcheryRange.ARCHER_TIME
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.3, 0.7, 0.4, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end

    self:drawHealthBar()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Isometric Archery Range drawing
function ArcheryRange:drawArcheryRangeIso(x, y, size)
    local scale = 1
    local originX = x + size/2
    local originY = y + size - 10

    -- Colors
    local woodTop = {0.52, 0.40, 0.26}
    local woodLeft = {0.40, 0.30, 0.18}
    local woodRight = {0.46, 0.35, 0.22}
    local woodDark = {0.32, 0.24, 0.15}
    local roofTop = {0.38, 0.28, 0.18}
    local roofLeft = {0.30, 0.22, 0.14}
    local dirtColor = {0.45, 0.38, 0.28}
    local dirtDark = {0.35, 0.28, 0.20}
    local grassColor = {0.35, 0.50, 0.28}
    local targetWhite = {0.90, 0.85, 0.75}
    local targetRed = {0.75, 0.22, 0.18}
    local metalColor = {0.55, 0.55, 0.60}

    -- === TRAINING GROUND (dirt) ===
    for layer = 0, 2 do
        local t = layer / 2
        local r = dirtDark[1] + (dirtColor[1] - dirtDark[1]) * t
        local g = dirtDark[2] + (dirtColor[2] - dirtDark[2]) * t
        local b = dirtDark[3] + (dirtColor[3] - dirtDark[3]) * t
        local dirtW = (60 - layer * 5) * scale
        local dirtD = (35 - layer * 3) * scale
        isoQuad(
            {-dirtW/2, -dirtD/2, (-1 + layer * 0.3) * scale},
            {dirtW/2, -dirtD/2, (-1 + layer * 0.3) * scale},
            {dirtW/2, dirtD/2, (-1 + layer * 0.3) * scale},
            {-dirtW/2, dirtD/2, (-1 + layer * 0.3) * scale},
            originX, originY, {r, g, b}
        )
    end

    -- === ARCHER'S PAVILION (octagonal, open-air shelter) ===
    local pavR = 14*scale  -- radius for octagonal shape
    local pavH = 18*scale
    local pavCX = -12*scale
    local pavCY = -8*scale

    -- Low wall base (partial walls)
    local wallColors = {
        {woodRight[1], woodRight[2], woodRight[3]},
        {0.44, 0.33, 0.20},
        {woodLeft[1], woodLeft[2], woodLeft[3]},
        {0.38, 0.28, 0.16},
    }

    isoOctagonalPrism(pavCX, pavCY, 0, pavR, 6*scale, originX, originY, woodTop, wallColors)

    -- Support columns (rectangular) at corners
    local colW, colD, colH = 3*scale, 3*scale, pavH
    local colPositions = {
        {pavCX + pavR - 3*scale, pavCY + pavR - 3*scale},  -- front-right
        {pavCX - pavR, pavCY + pavR - 3*scale},            -- front-left
        {pavCX + pavR - 3*scale, pavCY - pavR},            -- back-right
        {pavCX - pavR, pavCY - pavR},                       -- back-left
    }

    for _, pos in ipairs(colPositions) do
        isoBox(pos[1], pos[2], 0, colW, colD, colH, originX, originY,
               woodTop, woodLeft, woodRight)
    end

    -- Roof eaves
    local eaveR = pavR + 6*scale
    local eaveH = 2*scale
    local eaveDark = {roofLeft[1] * 0.85, roofLeft[2] * 0.85, roofLeft[3] * 0.85}
    local eaveWallColors = {
        {eaveDark[1] * 1.1, eaveDark[2] * 1.1, eaveDark[3] * 1.1},
        {eaveDark[1], eaveDark[2], eaveDark[3]},
        {eaveDark[1] * 0.9, eaveDark[2] * 0.9, eaveDark[3] * 0.9},
        {eaveDark[1] * 0.8, eaveDark[2] * 0.8, eaveDark[3] * 0.8},
    }
    isoOctagonalPrism(pavCX, pavCY, pavH - 1*scale, eaveR, eaveH, originX, originY, eaveDark, eaveWallColors)

    -- Roof (octagonal pyramid)
    IsoUtils.pyramidRoof(pavCX, pavCY, pavH, pavR + 4*scale, 10*scale, originX, originY, roofLeft)

    -- === TARGET RANGE (3 targets in a row) ===
    local targetY = 18*scale
    for i = 0, 2 do
        local tx = -14*scale + i * 14*scale
        local tz = 8*scale

        -- Target stand (post)
        isoBox(tx - 1*scale, targetY - 1*scale, 0, 2*scale, 2*scale, 12*scale, originX, originY,
               woodTop, woodDark, woodTop)

        -- Target board (facing archer)
        local boardX, boardY = isoProject(tx, targetY + 1, tz, originX, originY)

        -- Outer ring (white)
        love.graphics.setColor(targetWhite[1], targetWhite[2], targetWhite[3], 1)
        love.graphics.circle("fill", boardX, boardY, 7)

        -- Red ring
        love.graphics.setColor(targetRed[1], targetRed[2], targetRed[3], 1)
        love.graphics.circle("fill", boardX, boardY, 5)

        -- Inner white ring
        love.graphics.setColor(targetWhite[1], targetWhite[2], targetWhite[3], 1)
        love.graphics.circle("fill", boardX, boardY, 3)

        -- Bullseye (red)
        love.graphics.setColor(targetRed[1], targetRed[2], targetRed[3], 1)
        love.graphics.circle("fill", boardX, boardY, 1.5)

        -- Arrow stuck in target
        local arrowOffset = (i - 1) * 1.5
        love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
        love.graphics.line(boardX + arrowOffset, boardY, boardX + arrowOffset, boardY - 6)
        love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
        love.graphics.polygon("fill",
            boardX + arrowOffset - 1.5, boardY - 6,
            boardX + arrowOffset + 1.5, boardY - 6,
            boardX + arrowOffset, boardY - 9)
    end

    -- === BOW RACK (left side) ===
    local rackX, rackY = -24*scale, 6*scale

    -- Rack frame
    isoBox(rackX, rackY, 0, 2*scale, 8*scale, 14*scale, originX, originY,
           woodTop, woodDark, woodTop)

    -- Horizontal bar
    isoBox(rackX - 3*scale, rackY + 1*scale, 12*scale, 8*scale, 2*scale, 1*scale, originX, originY,
           woodTop, woodDark, woodTop)

    -- Bows hanging
    love.graphics.setColor(0.55, 0.40, 0.25, 1)
    love.graphics.setLineWidth(1.5)
    for i = 0, 2 do
        local bx, by = isoProject(rackX + 1*scale + i * 2.5*scale, rackY + 2*scale, 10*scale - i, originX, originY)
        love.graphics.arc("line", "open", bx, by, 5, math.pi * 0.4, math.pi * 1.6, 8)
        -- Bowstring
        love.graphics.setColor(0.70, 0.65, 0.55, 0.8)
        love.graphics.line(bx - 3, by - 4, bx - 3, by + 4)
        love.graphics.setColor(0.55, 0.40, 0.25, 1)
    end
    love.graphics.setLineWidth(1)

    -- === ARROW QUIVER (near pavilion) ===
    local quiverX, quiverY = pavCX + pavR + 2*scale, pavCY + 4*scale

    -- Quiver body (leather)
    love.graphics.setColor(0.45, 0.32, 0.22, 1)
    local qx1, qy1 = isoProject(quiverX, quiverY, 0, originX, originY)
    local qx2, qy2 = isoProject(quiverX, quiverY, 10*scale, originX, originY)
    love.graphics.setLineWidth(6)
    love.graphics.line(qx1, qy1, qx2, qy2)
    love.graphics.setLineWidth(1)

    -- Arrows sticking out
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    for i = 0, 3 do
        local ax, ay = isoProject(quiverX + (i-1.5)*0.8*scale, quiverY + (i-1.5)*0.5*scale, 10*scale + i, originX, originY)
        love.graphics.line(ax, ay, ax, ay - 5 - i)
        -- Arrow fletching
        love.graphics.setColor(0.20, 0.50, 0.25, 1)
        love.graphics.ellipse("fill", ax, ay - 3 - i, 1, 2)
        love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    end

    -- === GRASS PATCHES ===
    love.graphics.setColor(grassColor[1], grassColor[2], grassColor[3], 0.7)
    local grassPositions = {
        {22*scale, -12*scale},
        {24*scale, 8*scale},
        {-26*scale, -14*scale},
    }
    for _, pos in ipairs(grassPositions) do
        local gx, gy = isoProject(pos[1], pos[2], 0, originX, originY)
        love.graphics.ellipse("fill", gx, gy, 4, 2)
    end

    -- === TEAM BANNER ===
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {0.20, 0.50, 0.25, 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {0.90, 0.85, 0.50, 1}

    -- Banner pole on roof
    local poleX, poleY = pavCX + pavR - 5*scale, pavCY
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    local pp1x, pp1y = isoProject(poleX, poleY, pavH + 5*scale, originX, originY)
    local pp2x, pp2y = isoProject(poleX, poleY, pavH + 20*scale, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(pp1x, pp1y, pp2x, pp2y)
    love.graphics.setLineWidth(1)

    -- Banner cloth
    local wave = math.sin((self.animTimer or 0) * 3) * 2
    love.graphics.setColor(bannerColor[1], bannerColor[2], bannerColor[3], 1)
    love.graphics.polygon("fill",
        pp2x, pp2y,
        pp2x + 14 + wave, pp2y + 3,
        pp2x + 12 + wave, pp2y + 14,
        pp2x, pp2y + 11)

    -- Bow emblem on banner
    love.graphics.setColor(emblemColor[1], emblemColor[2], emblemColor[3], 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.arc("line", "open", pp2x + 7 + wave * 0.5, pp2y + 7, 4, math.pi * 0.5, math.pi * 1.5, 6)
    -- Bowstring on emblem
    love.graphics.line(pp2x + 3 + wave * 0.5, pp2y + 4, pp2x + 3 + wave * 0.5, pp2y + 10)
    love.graphics.setLineWidth(1)
end

function ArcheryRange:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function ArcheryRange:startProduction()
    if self.completed and not self.isProducing then
        self.isProducing = true
        self.productionTimer = 0
        return true
    end
    return false
end

function ArcheryRange:canProduce()
    return self.completed and not self.isProducing
end

function ArcheryRange:getProductionProgress()
    if self.isProducing then
        return math.floor((self.productionTimer / ArcheryRange.ARCHER_TIME) * 100)
    end
    return 0
end

function ArcheryRange:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function ArcheryRange:updateUI(resources, screenW, screenH, font, currentPop, maxPop)
    -- UI now handled by command buttons in gameplay.lua
end

function ArcheryRange:drawUI()
    -- UI now handled by command buttons in gameplay.lua
end

function ArcheryRange:mousepressed(x, y, button)
    -- UI now handled by command buttons in gameplay.lua
end

function ArcheryRange:mousereleased(x, y, button)
    -- UI now handled by command buttons in gameplay.lua
end

function ArcheryRange:takeDamage(amount)
    self.hp = self.hp - amount
end

function ArcheryRange:isDead()
    return self.hp <= 0
end

function ArcheryRange:drawHealthBar()
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

function ArcheryRange:drawOnMinimap(mapX, mapY, scale)
    local Teams = require("teams")
    if Teams then
        local teamColor = Teams.getColor(self.team, "minimapBuilding")
        love.graphics.setColor(teamColor[1], teamColor[2], teamColor[3], 1)
    else
        love.graphics.setColor(0.35, 0.5, 0.35, 1)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return ArcheryRange
