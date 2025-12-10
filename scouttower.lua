--[[
    Scout Tower
    Defensive structure with extended sight radius
    Can be upgraded to: Guard Tower (ranged attack) or Cannon Tower (siege damage)
    Size: 3x3 tiles, grid-aligned
    Special: Provides vision radius of 9 tiles
    Requires: Lumber Mill for upgrades
]]

local Button = require("button")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Building renderer for retro pixel art effect
local BuildingRenderer
pcall(function() BuildingRenderer = require("building_renderer") end)

--============================================================================
-- ISOMETRIC RENDERING SYSTEM
-- True 2:1 isometric projection at 2x scale
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

-- Draw beacon/torch fire
local function drawBeaconFire(x, y, time, scale)
    scale = scale or 1
    local flicker = math.sin(time * 10) * 0.15 + math.cos(time * 14) * 0.1
    
    -- Outer glow
    love.graphics.setColor(1, 0.35, 0.08, 0.2 + flicker * 0.08)
    love.graphics.circle("fill", x, y, 14 * scale)
    
    -- Mid flame
    love.graphics.setColor(1, 0.55, 0.12, 0.65 + flicker * 0.2)
    love.graphics.circle("fill", x, y - 3 * scale, 9 * scale)
    
    -- Inner flame
    love.graphics.setColor(1, 0.75, 0.25, 0.9)
    love.graphics.circle("fill", x, y - 5 * scale, 5 * scale)
    
    -- Hot core
    love.graphics.setColor(1, 0.92, 0.6, 0.85)
    love.graphics.circle("fill", x, y - 6 * scale, 2.5 * scale)
end

local ScoutTower = {}
ScoutTower.__index = ScoutTower

ScoutTower.GRID_SIZE = 2  -- 2x2 tiles
ScoutTower.COST_GOLD = 200
ScoutTower.COST_LUMBER = 100
ScoutTower.BUILD_TIME = 12.0

-- Upgrade costs (requires Lumber Mill)
ScoutTower.GUARD_TOWER_COST_GOLD = 200
ScoutTower.GUARD_TOWER_COST_LUMBER = 100
ScoutTower.GUARD_TOWER_TIME = 15.0

ScoutTower.CANNON_TOWER_COST_GOLD = 400
ScoutTower.CANNON_TOWER_COST_LUMBER = 200
ScoutTower.CANNON_TOWER_TIME = 20.0

-- Static counter for unique IDs
local scoutTowerIdCounter = 0

function ScoutTower.new(params)
    local self = setmetatable({}, ScoutTower)
    
    scoutTowerIdCounter = scoutTowerIdCounter + 1
    self.uniqueId = scoutTowerIdCounter
    self.animTimer = 0
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = ScoutTower.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "scouttower"
    self.name = "Scout Tower"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Tower tier: 1 = Scout, 2 = Guard Tower, 3 = Cannon Tower
    self.tier = 1
    
    -- Combat stats (base Scout Tower has no attack)
    self.maxHp = 100
    self.hp = self.maxHp
    self.sightRadius = 9  -- Extended vision range!
    self.attackDamage = 0
    self.attackRange = 0
    self.attackSpeed = 0
    self.attackCooldown = 0
    self.target = nil
    self.attackAnimTimer = 0
    
    -- Building state
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = ScoutTower.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    -- Upgrade state
    self.isUpgrading = false
    self.upgradeProgress = 0
    self.upgradeTime = 0
    self.upgradeTarget = nil  -- "guardtower" or "cannontower"
    
    -- Beacon state
    self.beaconLit = true
    
    -- Flash effect
    self.flashTimer = 0
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function ScoutTower:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function ScoutTower:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function ScoutTower:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function ScoutTower:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function ScoutTower:update(dt)
    self.animTimer = (self.animTimer or 0) + dt
    
    -- Update flash timer
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
    
    -- Update attack cooldown
    if self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end
    
    -- Update attack animation
    if self.attackAnimTimer > 0 then
        self.attackAnimTimer = self.attackAnimTimer - dt
    end
    
    -- Handle construction
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return true, false  -- build complete, upgrade not complete
        end
        return false, false
    end
    
    -- Handle upgrading
    if self.isUpgrading then
        self.upgradeProgress = self.upgradeProgress + dt
        if self.upgradeProgress >= self.upgradeTime then
            self.isUpgrading = false
            self.upgradeProgress = 0
            self:applyUpgrade()
            return false, true  -- upgrade complete
        end
    end
    
    return false, false
end

function ScoutTower:applyUpgrade()
    if self.upgradeTarget == "guardtower" then
        self.tier = 2
        self.name = "Guard Tower"
        self.maxHp = 130
        self.hp = self.maxHp
        self.attackDamage = 12
        self.attackRange = 7
        self.attackSpeed = 1.5
    elseif self.upgradeTarget == "cannontower" then
        self.tier = 3
        self.name = "Cannon Tower"
        self.maxHp = 160
        self.hp = self.maxHp
        self.attackDamage = 35
        self.attackRange = 8
        self.attackSpeed = 0.5  -- Slow but powerful
    end
    self.upgradeTarget = nil
end

function ScoutTower:startUpgrade(upgradeType)
    if not self.completed or self.isUpgrading or self.tier > 1 then
        return false
    end
    
    if upgradeType == "guardtower" then
        self.isUpgrading = true
        self.upgradeProgress = 0
        self.upgradeTime = ScoutTower.GUARD_TOWER_TIME
        self.upgradeTarget = "guardtower"
        return true
    elseif upgradeType == "cannontower" then
        self.isUpgrading = true
        self.upgradeProgress = 0
        self.upgradeTime = ScoutTower.CANNON_TOWER_TIME
        self.upgradeTarget = "cannontower"
        return true
    end
    return false
end

function ScoutTower:canUpgrade()
    return self.completed and not self.isUpgrading and self.tier == 1
end

function ScoutTower:getUpgradeCost(upgradeType)
    if upgradeType == "guardtower" then
        return ScoutTower.GUARD_TOWER_COST_GOLD, ScoutTower.GUARD_TOWER_COST_LUMBER
    elseif upgradeType == "cannontower" then
        return ScoutTower.CANNON_TOWER_COST_GOLD, ScoutTower.CANNON_TOWER_COST_LUMBER
    end
    return 0, 0
end

-- Attack methods (for upgraded towers)
function ScoutTower:attack(target)
    if self.tier == 1 or not self.completed or self.attackCooldown > 0 then
        return false
    end
    
    self.target = target
    self.attackCooldown = 1 / self.attackSpeed
    self.attackAnimTimer = 0.3
    
    if target and target.takeDamage then
        target:takeDamage(self.attackDamage)
    end
    
    return true
end

function ScoutTower:canAttack()
    return self.tier > 1 and self.completed and self.attackCooldown <= 0
end

function ScoutTower:getAttackRange()
    return self.attackRange * 32
end

function ScoutTower:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Draw construction scaffolding if being built
    if self.isBuilding then
        love.graphics.setColor(0.5, 0.45, 0.4, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.45, 0.3, 0.8)
        love.graphics.rectangle("fill", x + size/2 - 8, y + 10, 16, size - 20)
        love.graphics.setColor(0.5, 0.4, 0.25, 0.8)
        love.graphics.line(x + 10, y + 20, x + size - 10, y + 20)
        love.graphics.line(x + 10, y + 40, x + size - 10, y + 40)
        
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
    local function drawTierTower(ox, oy)
        if self.tier == 1 then
            self:drawScoutTowerIso(ox, oy, size)
        elseif self.tier == 2 then
            self:drawGuardTowerIso(ox, oy, size)
        else
            self:drawCannonTowerIso(ox, oy, size)
        end
    end

    if BuildingRenderer and BuildingRenderer.begin("large") then
        drawTierTower(32, 64)
        BuildingRenderer.finishWithSize("large", x - 32, y - 64, 1)
    else
        drawTierTower(x, y)
    end
    
    -- Draw beacon fire on top (outside shader for glow effect)
    if self.completed and self.beaconLit then
        local beaconX = x + size * 0.5
        local beaconY = y - 12
        drawBeaconFire(beaconX, beaconY, self.animTimer, 0.9)
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
        
        -- Draw attack range circle when selected (for upgraded towers)
        if self.tier > 1 then
            love.graphics.setColor(1, 0.3, 0.3, 0.15)
            local cx, cy = self:getWorldCenter()
            if self.map then
                cx, cy = self.map:worldToScreen(cx, cy)
            end
            love.graphics.circle("fill", cx, cy, self:getAttackRange())
            love.graphics.setColor(1, 0.3, 0.3, 0.4)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", cx, cy, self:getAttackRange())
        end
    end
    
    -- Upgrade progress bar
    if self.isUpgrading then
        local barW = size - 10
        local progress = self.upgradeProgress / self.upgradeTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.8, 0.6, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    self:drawHealthBar()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Scout Tower (Tier 1) - Basic watchtower, no attack
function ScoutTower:drawScoutTowerIso(x, y, size)
    -- Origin at bottom of sprite, 2x scale
    local originX = x + size/2
    local originY = y + size - 8
    local scale = 2
    
    -- Color palette - defensive stone fortress
    local stoneTop = {0.65, 0.62, 0.58}
    local stoneLeft = {0.45, 0.43, 0.40}
    local stoneRight = {0.52, 0.50, 0.46}
    local stoneDark = {0.32, 0.30, 0.28}
    local stoneShadow = {0.25, 0.23, 0.22}
    local woodColor = {0.42, 0.30, 0.20}
    local woodDark = {0.30, 0.22, 0.15}
    local roofColor = {0.35, 0.32, 0.30}
    
    -- === BASE FOUNDATION ===
    local baseW = 30 * scale
    local baseD = 30 * scale
    local baseH = 6 * scale
    local baseX = -baseW/2
    local baseY = -baseD/2
    
    isoBox(baseX - 2*scale, baseY - 2*scale, 0, baseW + 4*scale, baseD + 4*scale, baseH, originX, originY,
           stoneDark, stoneShadow, stoneDark)
    
    -- === MAIN TOWER BODY ===
    local towerW = 26 * scale
    local towerD = 26 * scale
    local towerH = 50 * scale
    local towerX = -towerW/2
    local towerY = -towerD/2
    
    isoBox(towerX, towerY, baseH, towerW, towerD, towerH, originX, originY,
           stoneTop, stoneLeft, stoneRight)
    
    -- Stone texture lines on walls
    love.graphics.setColor(stoneDark[1], stoneDark[2], stoneDark[3], 0.35)
    for row = 1, 5 do
        local z = baseH + row * 9 * scale
        local sx1, sy1 = isoProject(towerX, towerY + towerD, z, originX, originY)
        local sx2, sy2 = isoProject(towerX + towerW, towerY + towerD, z, originX, originY)
        love.graphics.line(sx1, sy1, sx2, sy2)
        local sx3, sy3 = isoProject(towerX + towerW, towerY, z, originX, originY)
        local sx4, sy4 = isoProject(towerX + towerW, towerY + towerD, z, originX, originY)
        love.graphics.line(sx3, sy3, sx4, sy4)
    end
    
    -- === WINDOW SLITS ===
    love.graphics.setColor(0.12, 0.10, 0.08, 1)
    for i = 0, 1 do
        local slitX = towerX + 6*scale + i * 14*scale
        local slitZ = baseH + 20*scale
        isoQuad(
            {slitX, towerY + towerD, slitZ},
            {slitX + 3*scale, towerY + towerD, slitZ},
            {slitX + 3*scale, towerY + towerD, slitZ + 12*scale},
            {slitX, towerY + towerD, slitZ + 12*scale},
            originX, originY, {0.12, 0.10, 0.08}
        )
    end
    
    -- === BATTLEMENTS ===
    local battleH = 8 * scale
    local battleZ = baseH + towerH
    local merlonW = 5 * scale
    local merlonD = 3 * scale
    local gap = 4 * scale
    
    for i = 0, 2 do
        local merlonX = towerX + 2*scale + i * (merlonW + gap)
        isoBox(merlonX, towerY + towerD - merlonD, battleZ, merlonW, merlonD + 1*scale, battleH,
               originX, originY, stoneTop, stoneLeft, stoneRight)
    end
    for i = 0, 2 do
        local merlonY = towerY + 2*scale + i * (merlonW + gap)
        isoBox(towerX + towerW - merlonD, merlonY, battleZ, merlonD + 1*scale, merlonW, battleH,
               originX, originY, stoneTop, stoneLeft, stoneRight)
    end
    
    -- === TOWER FLOOR ===
    isoQuad(
        {towerX + 2*scale, towerY + 2*scale, battleZ},
        {towerX + towerW - 2*scale, towerY + 2*scale, battleZ},
        {towerX + towerW - 2*scale, towerY + towerD - 2*scale, battleZ},
        {towerX + 2*scale, towerY + towerD - 2*scale, battleZ},
        originX, originY, woodColor
    )
    
    -- === DOOR ===
    local doorW = 8 * scale
    local doorH = 14 * scale
    local doorX = -doorW/2
    
    isoQuad(
        {doorX - 2*scale, towerY + towerD, baseH},
        {doorX + doorW + 2*scale, towerY + towerD, baseH},
        {doorX + doorW + 2*scale, towerY + towerD, baseH + doorH + 3*scale},
        {doorX - 2*scale, towerY + towerD, baseH + doorH + 3*scale},
        originX, originY, stoneDark
    )
    isoQuad(
        {doorX, towerY + towerD + 0.5*scale, baseH},
        {doorX + doorW, towerY + towerD + 0.5*scale, baseH},
        {doorX + doorW, towerY + towerD + 0.5*scale, baseH + doorH},
        {doorX, towerY + towerD + 0.5*scale, baseH + doorH},
        originX, originY, {0.18, 0.12, 0.08}
    )
    
    -- === TEAM BANNER ===
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {0.55, 0.15, 0.12, 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {0.85, 0.80, 0.40, 1}
    
    local poleX = towerX + 2*scale + merlonW/2
    local poleY = towerY + towerD
    local poleZ = battleZ + battleH
    
    love.graphics.setColor(woodColor[1], woodColor[2], woodColor[3], 1)
    local pp1x, pp1y = isoProject(poleX, poleY, poleZ, originX, originY)
    local pp2x, pp2y = isoProject(poleX, poleY, poleZ + 16*scale, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(pp1x, pp1y, pp2x, pp2y)
    love.graphics.setLineWidth(1)
    
    local bx, by = pp2x, pp2y
    local wave = math.sin((self.animTimer or 0) * 4) * 2
    love.graphics.setColor(bannerColor[1], bannerColor[2], bannerColor[3], 1)
    love.graphics.polygon("fill",
        bx, by,
        bx + 14 + wave, by + 3,
        bx + 12 + wave, by + 12,
        bx, by + 9)
    
    love.graphics.setColor(emblemColor[1], emblemColor[2], emblemColor[3], 1)
    love.graphics.circle("fill", bx + 7 + wave*0.5, by + 6, 3)
end

-- Guard Tower (Tier 2) - Ranged attack with archers
function ScoutTower:drawGuardTowerIso(x, y, size)
    -- Draw base scout tower first
    self:drawScoutTowerIso(x, y, size)
    
    local originX = x + size/2
    local originY = y + size - 8
    local scale = 2
    
    -- Additional elements for Guard Tower
    local metalColor = {0.55, 0.55, 0.58}
    
    -- Arrow slits have crossbars (for archers)
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 0.8)
    local towerW = 26 * scale
    local towerD = 26 * scale
    local towerX = -towerW/2
    local towerY = -towerD/2
    local baseH = 6 * scale
    
    for i = 0, 1 do
        local slitX = towerX + 6*scale + i * 14*scale
        local slitZ = baseH + 26*scale
        local cx1, cy1 = isoProject(slitX - 1*scale, towerY + towerD, slitZ, originX, originY)
        local cx2, cy2 = isoProject(slitX + 4*scale, towerY + towerD, slitZ, originX, originY)
        love.graphics.setLineWidth(2)
        love.graphics.line(cx1, cy1, cx2, cy2)
    end
    love.graphics.setLineWidth(1)
end

-- Cannon Tower (Tier 3) - Heavy siege damage
function ScoutTower:drawCannonTowerIso(x, y, size)
    -- Draw base scout tower
    self:drawScoutTowerIso(x, y, size)
    
    local originX = x + size/2
    local originY = y + size - 8
    local scale = 2
    
    local metalColor = {0.45, 0.45, 0.50}
    local metalDark = {0.30, 0.30, 0.35}
    local bronzeColor = {0.55, 0.42, 0.28}
    
    local towerW = 26 * scale
    local towerD = 26 * scale
    local towerY = -towerD/2
    local baseH = 6 * scale
    
    -- Cannon barrel protruding from front
    local cannonZ = baseH + 30*scale
    local cannonX, cannonY = isoProject(0, towerY + towerD + 5*scale, cannonZ, originX, originY)
    
    -- Cannon barrel
    love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
    love.graphics.circle("fill", cannonX, cannonY, 6)
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    love.graphics.circle("fill", cannonX, cannonY, 4)
    love.graphics.setColor(0.15, 0.12, 0.10, 1)
    love.graphics.circle("fill", cannonX, cannonY, 2)
    
    -- Cannon mount
    local mountX, mountY = isoProject(0, towerY + towerD, cannonZ - 5*scale, originX, originY)
    love.graphics.setColor(bronzeColor[1], bronzeColor[2], bronzeColor[3], 1)
    love.graphics.rectangle("fill", mountX - 5, mountY - 3, 10, 6)
end

function ScoutTower:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

-- Combat Methods
function ScoutTower:takeDamage(amount)
    self.hp = self.hp - amount
    self.flashTimer = 0.1
end

function ScoutTower:isDead()
    return self.hp <= 0
end

function ScoutTower:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 10
    local barHeight = 5
    local barX = x + 5
    local barY = y - 14
    
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
    
    local healthPct = self.hp / self.maxHp
    love.graphics.setColor(1 - healthPct, healthPct, 0.2, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPct, barHeight)
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
end

function ScoutTower:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function ScoutTower:getUpgradeProgress()
    if self.isUpgrading then
        return math.floor((self.upgradeProgress / self.upgradeTime) * 100)
    end
    return 0
end

function ScoutTower:updateUI(resources, screenW, screenH, font) end
function ScoutTower:drawUI() end
function ScoutTower:mousepressed(x, y, button) end
function ScoutTower:mousereleased(x, y, button) end

function ScoutTower:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        if Teams then
            local teamColor = Teams.getColor(self.team, "minimapBuilding")
            love.graphics.setColor(teamColor[1], teamColor[2], teamColor[3], 1)
        else
            love.graphics.setColor(0.5, 0.5, 0.6, 1)
        end
    else
        love.graphics.setColor(0.4, 0.4, 0.45, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
    
    -- Dot for defensive structure
    if self.tier > 1 then
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        love.graphics.circle("fill", x + self.gridSize * scale / 2, y + self.gridSize * scale / 2, 2)
    end
end

return ScoutTower
