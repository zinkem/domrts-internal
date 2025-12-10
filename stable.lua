--[[
    Stable
    Enables Knight production at Barracks
    Has Paladin upgrade (requires Siege Workshop)
    Size: 3x3 tiles, grid-aligned
    Style: Isometric wooden barn with horse silhouette
    Requires: Hold (Town Hall tier 2)
]]

local Button = require("button")
local Requirements = require("requirements")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Building renderer for retro pixel art effect
local BuildingRenderer
pcall(function() BuildingRenderer = require("building_renderer") end)

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

local Stable = {}
Stable.__index = Stable

Stable.GRID_SIZE = 3
Stable.COST_GOLD = 500
Stable.COST_LUMBER = 200
Stable.BUILD_TIME = 20.0
Stable.PALADIN_UPGRADE_COST = 100

-- Static counter
local stableIdCounter = 0

function Stable.new(params)
    local self = setmetatable({}, Stable)
    
    stableIdCounter = stableIdCounter + 1
    self.uniqueId = stableIdCounter
    self.animTimer = 0
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = Stable.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "stable"
    self.name = "Stable"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 60
    self.hp = self.maxHp
    self.sightRadius = 5
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = Stable.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    -- Paladin upgrade
    self.hasPaladinUpgrade = false
    self.isUpgrading = false
    self.upgradeProgress = 0
    self.upgradeTime = 15.0
    
    -- Callback for when paladin upgrade completes
    self.onPaladinUpgrade = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function Stable:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function Stable:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function Stable:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function Stable:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function Stable:update(dt)
    self.animTimer = (self.animTimer or 0) + dt
    
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return true, false
        end
        return false, false
    end
    
    if self.isUpgrading then
        self.upgradeProgress = self.upgradeProgress + dt
        if self.upgradeProgress >= self.upgradeTime then
            self.isUpgrading = false
            self.upgradeProgress = 0
            self.hasPaladinUpgrade = true
            if self.onPaladinUpgrade then
                self.onPaladinUpgrade()
            end
            return false, true
        end
    end
    
    return false, false
end

function Stable:startPaladinUpgrade()
    if self.completed and not self.isUpgrading and not self.hasPaladinUpgrade then
        self.isUpgrading = true
        self.upgradeProgress = 0
        return true
    end
    return false
end

function Stable:canUpgrade()
    return self.completed and not self.isUpgrading and not self.hasPaladinUpgrade
end

function Stable:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction site
        love.graphics.setColor(0.5, 0.42, 0.32, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.55, 0.45, 0.3, 0.8)
        love.graphics.rectangle("fill", x + 8, y + 12, 20, 8)
        love.graphics.setColor(0.7, 0.65, 0.4, 0.8)
        love.graphics.rectangle("fill", x + size - 28, y + 18, 22, 6)
        
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
    local drawScale = 2
    local canvasSize = 128
    local scaledSize = canvasSize * drawScale
    local offsetX = x + (size - scaledSize) / 2
    local offsetY = y + size - scaledSize

    if BuildingRenderer and BuildingRenderer.begin("large") then
        self:drawStableIso(16, 20, 96)
        BuildingRenderer.finishWithSize("large", offsetX, offsetY, drawScale)
    else
        love.graphics.push()
        love.graphics.translate(offsetX, offsetY)
        love.graphics.scale(drawScale, drawScale)
        self:drawStableIso(16, 20, 96)
        love.graphics.pop()
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    -- Upgrade progress bar
    if self.isUpgrading then
        local barW = size - 10
        local progress = self.upgradeProgress / self.upgradeTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.8, 0.7, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    self:drawHealthBar()
    love.graphics.setColor(1, 1, 1, 1)
end

function Stable:drawStableIso(x, y, size)
    local scale = 1
    local originX = x + size/2
    local originY = y + size - 10
    
    -- Colors
    local woodTop = {0.58, 0.42, 0.28}
    local woodLeft = {0.45, 0.32, 0.20}
    local woodRight = {0.52, 0.38, 0.25}
    local woodDark = {0.35, 0.25, 0.15}
    local roofTop = {0.55, 0.38, 0.22}
    local roofLeft = {0.42, 0.28, 0.16}
    local roofRight = {0.48, 0.32, 0.18}
    local hayColor = {0.70, 0.62, 0.38}
    local hayDark = {0.60, 0.52, 0.30}
    local doorColor = {0.15, 0.12, 0.08}
    local metalColor = {0.45, 0.42, 0.45}
    local horseColor = {0.35, 0.28, 0.22}
    
    -- === GROUND (hay covered) ===
    isoQuad(
        {-30*scale, -25*scale, 0},
        {30*scale, -25*scale, 0},
        {30*scale, 30*scale, 0},
        {-30*scale, 30*scale, 0},
        originX, originY, hayDark
    )
    
    -- Scattered hay on ground
    love.graphics.setColor(hayColor[1], hayColor[2], hayColor[3], 0.6)
    for i = 1, 8 do
        local hx, hy = isoProject(-20 + i * 5, 20 + math.sin(i) * 5, 0.5, originX, originY)
        love.graphics.ellipse("fill", hx, hy, 3, 1.5)
    end
    
    -- === MAIN BARN BUILDING ===
    local barnW, barnD, barnH = 45*scale, 38*scale, 28*scale
    local barnX, barnY = -barnW/2, -barnD/2
    
    isoBox(barnX, barnY, 0, barnW, barnD, barnH, originX, originY,
           woodTop, woodLeft, woodRight)
    
    -- Wood plank lines on walls
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 0.4)
    for i = 1, 4 do
        local z = i * 6*scale
        -- Front wall
        local lx1, ly1 = isoProject(barnX, barnY + barnD, z, originX, originY)
        local lx2, ly2 = isoProject(barnX + barnW, barnY + barnD, z, originX, originY)
        love.graphics.line(lx1, ly1, lx2, ly2)
        -- Right wall
        local rx1, ry1 = isoProject(barnX + barnW, barnY, z, originX, originY)
        local rx2, ry2 = isoProject(barnX + barnW, barnY + barnD, z, originX, originY)
        love.graphics.line(rx1, ry1, rx2, ry2)
    end
    
    -- === PEAKED BARN ROOF ===
    local roofBase = barnH
    local roofPeak = 16*scale
    local roofOverhang = 5*scale
    
    -- Left slope
    isoQuad(
        {barnX - roofOverhang, barnY - roofOverhang, roofBase},
        {barnX + barnW/2, barnY + barnD/2, roofBase + roofPeak},
        {barnX + barnW/2, barnY + barnD/2, roofBase + roofPeak},
        {barnX - roofOverhang, barnY + barnD + roofOverhang, roofBase},
        originX, originY, roofLeft
    )
    
    -- Right slope
    isoQuad(
        {barnX + barnW + roofOverhang, barnY - roofOverhang, roofBase},
        {barnX + barnW/2, barnY + barnD/2, roofBase + roofPeak},
        {barnX + barnW/2, barnY + barnD/2, roofBase + roofPeak},
        {barnX + barnW + roofOverhang, barnY + barnD + roofOverhang, roofBase},
        originX, originY, roofRight
    )
    
    -- Front gable
    isoQuad(
        {barnX - roofOverhang, barnY + barnD + roofOverhang, roofBase},
        {barnX + barnW/2, barnY + barnD/2, roofBase + roofPeak},
        {barnX + barnW/2, barnY + barnD/2, roofBase + roofPeak},
        {barnX + barnW + roofOverhang, barnY + barnD + roofOverhang, roofBase},
        originX, originY, roofTop
    )
    
    -- Roof ridge highlight
    love.graphics.setColor(0.62, 0.45, 0.28, 1)
    local r1x, r1y = isoProject(barnX + barnW/2, barnY - roofOverhang, roofBase + roofPeak, originX, originY)
    local r2x, r2y = isoProject(barnX + barnW/2, barnY + barnD + roofOverhang, roofBase + roofPeak, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(r1x, r1y, r2x, r2y)
    love.graphics.setLineWidth(1)
    
    -- === LARGE DOOR OPENING ===
    local doorW, doorH = 22*scale, 22*scale
    local doorX = -doorW/2
    
    -- Door recess
    isoQuad(
        {doorX, barnY + barnD + 0.5, 0},
        {doorX + doorW, barnY + barnD + 0.5, 0},
        {doorX + doorW, barnY + barnD + 0.5, doorH},
        {doorX, barnY + barnD + 0.5, doorH},
        originX, originY, doorColor
    )
    
    -- Door frame
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    local df1x, df1y = isoProject(doorX - 2*scale, barnY + barnD + 0.5, 0, originX, originY)
    local df2x, df2y = isoProject(doorX - 2*scale, barnY + barnD + 0.5, doorH + 2*scale, originX, originY)
    local df3x, df3y = isoProject(doorX + doorW + 2*scale, barnY + barnD + 0.5, doorH + 2*scale, originX, originY)
    local df4x, df4y = isoProject(doorX + doorW + 2*scale, barnY + barnD + 0.5, 0, originX, originY)
    love.graphics.setLineWidth(3)
    love.graphics.line(df1x, df1y, df2x, df2y)
    love.graphics.line(df2x, df2y, df3x, df3y)
    love.graphics.line(df3x, df3y, df4x, df4y)
    love.graphics.setLineWidth(1)
    
    -- X-pattern on doors
    love.graphics.setColor(woodDark[1] * 0.8, woodDark[2] * 0.8, woodDark[3] * 0.8, 0.7)
    local dx1, dy1 = isoProject(doorX + 2*scale, barnY + barnD + 1, 2*scale, originX, originY)
    local dx2, dy2 = isoProject(doorX + doorW/2 - 1*scale, barnY + barnD + 1, doorH - 2*scale, originX, originY)
    local dx3, dy3 = isoProject(doorX + doorW/2 - 1*scale, barnY + barnD + 1, 2*scale, originX, originY)
    local dx4, dy4 = isoProject(doorX + 2*scale, barnY + barnD + 1, doorH - 2*scale, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(dx1, dy1, dx2, dy2)
    love.graphics.line(dx3, dy3, dx4, dy4)
    -- Right door half
    local dx5, dy5 = isoProject(doorX + doorW/2 + 1*scale, barnY + barnD + 1, 2*scale, originX, originY)
    local dx6, dy6 = isoProject(doorX + doorW - 2*scale, barnY + barnD + 1, doorH - 2*scale, originX, originY)
    local dx7, dy7 = isoProject(doorX + doorW - 2*scale, barnY + barnD + 1, 2*scale, originX, originY)
    local dx8, dy8 = isoProject(doorX + doorW/2 + 1*scale, barnY + barnD + 1, doorH - 2*scale, originX, originY)
    love.graphics.line(dx5, dy5, dx6, dy6)
    love.graphics.line(dx7, dy7, dx8, dy8)
    love.graphics.setLineWidth(1)
    
    -- === HORSE HEAD SILHOUETTE ===
    local horseX, horseY = isoProject(3*scale, barnY + barnD + 2, 10*scale, originX, originY)
    
    love.graphics.setColor(horseColor[1], horseColor[2], horseColor[3], 1)
    -- Head
    love.graphics.ellipse("fill", horseX, horseY, 6, 5)
    -- Snout
    love.graphics.ellipse("fill", horseX + 6, horseY + 3, 4, 3)
    -- Ear
    love.graphics.polygon("fill", 
        horseX - 2, horseY - 4,
        horseX + 1, horseY - 9,
        horseX + 4, horseY - 4
    )
    -- Eye highlight
    love.graphics.setColor(0.2, 0.15, 0.1, 1)
    love.graphics.circle("fill", horseX + 2, horseY - 1, 1.5)
    
    -- === HORSESHOE ABOVE DOOR ===
    local hsX, hsY = isoProject(0, barnY + barnD + 0.5, doorH + 4*scale, originX, originY)
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", hsX, hsY, 6, math.pi * 0.15, math.pi * 0.85)
    love.graphics.setLineWidth(1)
    
    -- === HAY BALES ===
    -- Front hay bale
    local hay1X, hay1Y = barnX + barnW - 5*scale, barnY + barnD + 10*scale
    isoBox(hay1X, hay1Y, 0, 10*scale, 8*scale, 6*scale, originX, originY,
           hayColor, hayDark, hayColor)
    
    -- Stacked hay
    isoBox(hay1X + 2*scale, hay1Y + 1*scale, 6*scale, 6*scale, 5*scale, 4*scale, originX, originY,
           hayColor, hayDark, hayColor)
    
    -- === PALADIN BANNER (if upgraded) ===
    if self.hasPaladinUpgrade then
        local bannerX, bannerY = barnX + 5*scale, barnY + barnD
        
        -- Pole
        love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
        local bp1x, bp1y = isoProject(bannerX, bannerY, roofBase, originX, originY)
        local bp2x, bp2y = isoProject(bannerX, bannerY, roofBase + roofPeak + 8*scale, originX, originY)
        love.graphics.setLineWidth(2)
        love.graphics.line(bp1x, bp1y, bp2x, bp2y)
        love.graphics.setLineWidth(1)
        
        -- Gold banner
        love.graphics.setColor(0.85, 0.75, 0.25, 1)
        love.graphics.polygon("fill",
            bp2x, bp2y,
            bp2x + 16, bp2y + 4,
            bp2x + 14, bp2y + 18,
            bp2x, bp2y + 14
        )
        
        -- Cross on banner
        love.graphics.setColor(0.95, 0.88, 0.40, 1)
        love.graphics.rectangle("fill", bp2x + 5, bp2y + 2, 4, 14)
        love.graphics.rectangle("fill", bp2x + 2, bp2y + 6, 10, 4)
    end
    
    -- === FENCE SECTION ===
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    -- Posts
    for i = 0, 2 do
        local postX = barnX - 8*scale + i * 12*scale
        local postY = barnY + barnD + 15*scale
        local p1x, p1y = isoProject(postX, postY, 0, originX, originY)
        local p2x, p2y = isoProject(postX, postY, 8*scale, originX, originY)
        love.graphics.setLineWidth(2)
        love.graphics.line(p1x, p1y, p2x, p2y)
    end
    
    -- Rails
    local fr1x1, fr1y1 = isoProject(barnX - 8*scale, barnY + barnD + 15*scale, 3*scale, originX, originY)
    local fr1x2, fr1y2 = isoProject(barnX + 16*scale, barnY + barnD + 15*scale, 3*scale, originX, originY)
    love.graphics.line(fr1x1, fr1y1, fr1x2, fr1y2)
    
    local fr2x1, fr2y1 = isoProject(barnX - 8*scale, barnY + barnD + 15*scale, 6*scale, originX, originY)
    local fr2x2, fr2y2 = isoProject(barnX + 16*scale, barnY + barnD + 15*scale, 6*scale, originX, originY)
    love.graphics.line(fr2x1, fr2y1, fr2x2, fr2y2)
    love.graphics.setLineWidth(1)
end

function Stable:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function Stable:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function Stable:getUpgradeProgress()
    if self.isUpgrading then
        return math.floor((self.upgradeProgress / self.upgradeTime) * 100)
    end
    return 0
end

function Stable:updateUI(resources, screenW, screenH, font) end
function Stable:drawUI() end
function Stable:mousepressed(x, y, button) end
function Stable:mousereleased(x, y, button) end

function Stable:takeDamage(amount)
    self.hp = self.hp - amount
end

function Stable:isDead()
    return self.hp <= 0
end

function Stable:drawHealthBar()
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

function Stable:drawOnMinimap(mapX, mapY, scale)
    if Teams then
        local teamColor = Teams.getColor(self.team, "minimapBuilding")
        love.graphics.setColor(teamColor[1], teamColor[2], teamColor[3], 1)
    else
        love.graphics.setColor(0.5, 0.4, 0.3, 1)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return Stable
