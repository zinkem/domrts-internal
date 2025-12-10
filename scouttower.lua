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

-- Draw an octagonal prism (tower shape)
-- cx, cy = center position, r = radius, z = base height, h = height
local function isoOctagon(cx, cy, z, r, originX, originY, color)
    -- Octagon vertices: cut corners at 45 degrees
    -- Corner cut is r * (1 - 1/sqrt(2)) ≈ r * 0.293
    local cut = r * 0.293
    local points = {
        {cx - r + cut, cy - r, z},        -- top edge left
        {cx + r - cut, cy - r, z},        -- top edge right
        {cx + r, cy - r + cut, z},        -- right edge top
        {cx + r, cy + r - cut, z},        -- right edge bottom
        {cx + r - cut, cy + r, z},        -- bottom edge right
        {cx - r + cut, cy + r, z},        -- bottom edge left
        {cx - r, cy + r - cut, z},        -- left edge bottom
        {cx - r, cy - r + cut, z},        -- left edge top
    }

    -- Project all points
    local screenPts = {}
    for i, p in ipairs(points) do
        local sx, sy = isoProject(p[1], p[2], p[3], originX, originY)
        screenPts[i] = {sx, sy}
    end

    -- Draw as polygon
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon("fill",
        screenPts[1][1], screenPts[1][2],
        screenPts[2][1], screenPts[2][2],
        screenPts[3][1], screenPts[3][2],
        screenPts[4][1], screenPts[4][2],
        screenPts[5][1], screenPts[5][2],
        screenPts[6][1], screenPts[6][2],
        screenPts[7][1], screenPts[7][2],
        screenPts[8][1], screenPts[8][2]
    )
end

-- Draw octagonal prism walls (visible faces only)
local function isoOctagonalPrism(cx, cy, z, r, h, originX, originY, topColor, wallColors)
    -- wallColors is a table of 8 colors for each face, or we compute shading
    local cut = r * 0.293

    -- Define the 8 vertices at bottom and top
    local bottomPts = {
        {cx - r + cut, cy - r, z},        -- 1: top edge left
        {cx + r - cut, cy - r, z},        -- 2: top edge right
        {cx + r, cy - r + cut, z},        -- 3: right edge top
        {cx + r, cy + r - cut, z},        -- 4: right edge bottom
        {cx + r - cut, cy + r, z},        -- 5: bottom edge right
        {cx - r + cut, cy + r, z},        -- 6: bottom edge left
        {cx - r, cy + r - cut, z},        -- 7: left edge bottom
        {cx - r, cy - r + cut, z},        -- 8: left edge top
    }

    local topPts = {}
    for i, p in ipairs(bottomPts) do
        topPts[i] = {p[1], p[2], z + h}
    end

    -- Draw visible wall faces (faces 3-7 are typically visible in isometric)
    -- Face indices go clockwise, we draw faces facing "camera" (south-east-ish)
    local faces = {
        {3, 4, wallColors[1] or {0.52, 0.50, 0.46}},  -- right face (bright)
        {4, 5, wallColors[2] or {0.48, 0.46, 0.42}},  -- bottom-right corner
        {5, 6, wallColors[3] or {0.45, 0.43, 0.40}},  -- bottom face (medium)
        {6, 7, wallColors[4] or {0.42, 0.40, 0.38}},  -- bottom-left corner
    }

    for _, face in ipairs(faces) do
        local i1, i2, color = face[1], face[2], face[3]
        isoQuad(
            bottomPts[i1], bottomPts[i2], topPts[i2], topPts[i1],
            originX, originY, color
        )
    end

    -- Draw top face
    isoOctagon(cx, cy, z + h, r, originX, originY, topColor)
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
    local stoneDark = {0.32, 0.30, 0.28}
    local stoneShadow = {0.25, 0.23, 0.22}
    local woodColor = {0.42, 0.30, 0.20}

    -- Wall colors for octagonal faces (gradient from light to dark)
    local wallColors = {
        {0.55, 0.53, 0.49},  -- right face (brightest)
        {0.50, 0.48, 0.44},  -- bottom-right corner
        {0.45, 0.43, 0.40},  -- bottom face
        {0.40, 0.38, 0.36},  -- bottom-left corner (darkest visible)
    }

    -- === BASE FOUNDATION (square) ===
    local baseR = 16 * scale
    local baseH = 6 * scale

    isoOctagonalPrism(0, 0, 0, baseR + 2*scale, baseH, originX, originY,
        stoneDark, {{0.28, 0.26, 0.24}, {0.25, 0.23, 0.22}, {0.22, 0.20, 0.19}, {0.20, 0.18, 0.17}})

    -- === MAIN TOWER BODY (octagonal) ===
    local towerR = 14 * scale
    local towerH = 50 * scale

    isoOctagonalPrism(0, 0, baseH, towerR, towerH, originX, originY, stoneTop, wallColors)

    -- === STONE BAND DETAILS ===
    -- Draw horizontal bands on the tower
    love.graphics.setColor(stoneDark[1], stoneDark[2], stoneDark[3], 0.4)
    for row = 1, 4 do
        local z = baseH + row * 11 * scale
        local bandR = towerR + 0.5
        isoOctagon(0, 0, z, bandR, originX, originY, {stoneDark[1], stoneDark[2], stoneDark[3], 0.3})
    end

    -- === WINDOW SLIT ===
    -- Single window on front face
    local cut = towerR * 0.293
    local windowZ = baseH + 22 * scale
    local windowH = 12 * scale
    local windowW = 3 * scale
    local frontY = towerR  -- front face Y position

    isoQuad(
        {-windowW/2, frontY, windowZ},
        {windowW/2, frontY, windowZ},
        {windowW/2, frontY, windowZ + windowH},
        {-windowW/2, frontY, windowZ + windowH},
        originX, originY, {0.10, 0.08, 0.06}
    )

    -- === BATTLEMENTS (merlons around the top) ===
    local battleZ = baseH + towerH
    local battleH = 8 * scale
    local merlonSize = 4 * scale

    -- Place merlons at key positions around the octagon
    local merlonPositions = {
        {towerR * 0.7, towerR * 0.7},    -- front-right
        {-towerR * 0.7, towerR * 0.7},   -- front-left
        {towerR, 0},                       -- right
        {0, towerR},                       -- front
    }

    for _, pos in ipairs(merlonPositions) do
        isoBox(pos[1] - merlonSize/2, pos[2] - merlonSize/2, battleZ,
               merlonSize, merlonSize, battleH, originX, originY,
               stoneTop, wallColors[3], wallColors[1])
    end

    -- === WOODEN PLATFORM TOP ===
    local platformR = towerR - 2*scale
    isoOctagon(0, 0, battleZ, platformR, originX, originY, woodColor)

    -- === DOOR ===
    local doorW = 7 * scale
    local doorH = 12 * scale

    -- Door frame (darker stone)
    isoQuad(
        {-doorW/2 - 1*scale, frontY, baseH},
        {doorW/2 + 1*scale, frontY, baseH},
        {doorW/2 + 1*scale, frontY, baseH + doorH + 2*scale},
        {-doorW/2 - 1*scale, frontY, baseH + doorH + 2*scale},
        originX, originY, stoneDark
    )
    -- Door (wood)
    isoQuad(
        {-doorW/2, frontY + 0.5*scale, baseH},
        {doorW/2, frontY + 0.5*scale, baseH},
        {doorW/2, frontY + 0.5*scale, baseH + doorH},
        {-doorW/2, frontY + 0.5*scale, baseH + doorH},
        originX, originY, {0.18, 0.12, 0.08}
    )

    -- === TEAM BANNER ===
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {0.55, 0.15, 0.12, 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {0.85, 0.80, 0.40, 1}

    local poleX = towerR * 0.5
    local poleY = towerR * 0.5
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
    local towerR = 14 * scale
    local baseH = 6 * scale

    -- Arrow crossbar on the window slit
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 0.9)
    local windowZ = baseH + 28*scale
    local frontY = towerR
    local cx1, cy1 = isoProject(-3*scale, frontY, windowZ, originX, originY)
    local cx2, cy2 = isoProject(3*scale, frontY, windowZ, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx1, cy1, cx2, cy2)
    love.graphics.setLineWidth(1)

    -- Additional arrow slits on side faces
    local sideWindowZ = baseH + 25*scale
    -- Right side window
    isoQuad(
        {towerR, -2*scale, sideWindowZ},
        {towerR, 2*scale, sideWindowZ},
        {towerR, 2*scale, sideWindowZ + 10*scale},
        {towerR, -2*scale, sideWindowZ + 10*scale},
        originX, originY, {0.10, 0.08, 0.06}
    )
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

    local towerR = 14 * scale
    local baseH = 6 * scale
    local frontY = towerR

    -- Cannon barrel protruding from front
    local cannonZ = baseH + 28*scale
    local cannonX, cannonY = isoProject(0, frontY + 6*scale, cannonZ, originX, originY)

    -- Cannon barrel (larger for cannon tower)
    love.graphics.setColor(metalDark[1], metalDark[2], metalDark[3], 1)
    love.graphics.circle("fill", cannonX, cannonY, 8)
    love.graphics.setColor(metalColor[1], metalColor[2], metalColor[3], 1)
    love.graphics.circle("fill", cannonX, cannonY, 6)
    love.graphics.setColor(0.12, 0.10, 0.08, 1)
    love.graphics.circle("fill", cannonX, cannonY, 3)

    -- Cannon mount/bracket
    local mountX, mountY = isoProject(0, frontY + 2*scale, cannonZ - 4*scale, originX, originY)
    love.graphics.setColor(bronzeColor[1], bronzeColor[2], bronzeColor[3], 1)
    love.graphics.rectangle("fill", mountX - 6, mountY - 4, 12, 8, 2)

    -- Decorative bronze band on barrel
    love.graphics.setColor(bronzeColor[1], bronzeColor[2], bronzeColor[3], 0.8)
    love.graphics.circle("line", cannonX, cannonY, 7)
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
