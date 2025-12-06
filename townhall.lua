--[[
    Town Hall
    Main building that produces peons
    Can upgrade: Town Hall -> Hold -> Keep
    Size: 3x3 tiles, grid-aligned, square collision
]]

local Button = require("button")
local Requirements = require("requirements")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Shared gradient/texture helper functions for building rendering
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

local function drawColumn(cx, cy, cw, ch, marble, marbleDark)
    for i = 0, cw - 1 do
        local t = i / cw
        local shade = 1 - (math.abs(t - 0.35) * 1.2)
        shade = math.max(0.7, math.min(1.0, shade))
        local r = marble[1] * shade
        local g = marble[2] * shade
        local b = marble[3] * shade
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", cx + i, cy, 1, ch)
    end
    love.graphics.setColor(0, 0, 0, 0.06)
    love.graphics.rectangle("fill", cx + cw * 0.25, cy + 3, 1, ch - 6)
    love.graphics.rectangle("fill", cx + cw * 0.5, cy + 3, 1, ch - 6)
    love.graphics.rectangle("fill", cx + cw * 0.75, cy + 3, 1, ch - 6)
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.rectangle("fill", cx + 1, cy + 2, 1, ch - 4)
end

local function drawAcroterion(ax, ay, asize, goldMid, goldLight)
    for row = 0, asize do
        local t = row / asize
        local rowW = asize * (1 - t) * 0.8
        local shade = goldMid[1] + (goldLight[1] - goldMid[1]) * (1 - t)
        love.graphics.setColor(shade, shade * 0.85, shade * 0.4, 1)
        love.graphics.rectangle("fill", ax - rowW/2, ay - row, rowW, 1)
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

local function drawBronzeDoor(dx, dy, dw, dh, bronze, bronzeLight, goldMid, goldDark)
    gradientRect(dx, dy, dw, dh,
        {bronzeLight[1], bronzeLight[2], bronzeLight[3]},
        {bronze[1] - 0.1, bronze[2] - 0.1, bronze[3] - 0.05}, true)
    local panelW = (dw - 4) / 2
    local panelH = (dh - 6) / 2
    for py = 0, 1 do
        for px = 0, 1 do
            local panelX = dx + 2 + px * (panelW + 1)
            local panelY = dy + 2 + py * (panelH + 1)
            gradientRect(panelX, panelY, panelW - 1, panelH - 1,
                {bronze[1] - 0.03, bronze[2] - 0.03, bronze[3]},
                {bronze[1] - 0.12, bronze[2] - 0.12, bronze[3] - 0.08}, false)
            love.graphics.setColor(bronzeLight[1], bronzeLight[2], bronzeLight[3], 0.3)
            love.graphics.rectangle("fill", panelX, panelY, panelW - 1, 1)
        end
    end
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.circle("fill", dx + dw/2 - dw/5, dy + dh * 0.6, 2.5)
    love.graphics.circle("fill", dx + dw/2 + dw/5, dy + dh * 0.6, 2.5)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.circle("fill", dx + dw/2 - dw/5, dy + dh * 0.6, 1.2)
    love.graphics.circle("fill", dx + dw/2 + dw/5, dy + dh * 0.6, 1.2)
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
    love.graphics.circle("fill", bx + 9, by - 19, 4)
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.circle("fill", bx + 9, by - 19, 2)
end

local TownHall = {}
TownHall.__index = TownHall

TownHall.GRID_SIZE = 3

-- Build costs for new Town Hall
TownHall.COST_GOLD = 1200
TownHall.COST_LUMBER = 500
TownHall.BUILD_TIME = 60.0

-- Upgrade costs
TownHall.HOLD_COST_GOLD = 1200
TownHall.HOLD_COST_LUMBER = 500
TownHall.HOLD_UPGRADE_TIME = 30.0

TownHall.KEEP_COST_GOLD = 2000
TownHall.KEEP_COST_LUMBER = 1000
TownHall.KEEP_UPGRADE_TIME = 45.0

function TownHall.new(params)
    local self = setmetatable({}, TownHall)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = TownHall.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "townhall"
    self.name = "Town Hall"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    self.owner = params.owner or nil  -- Reference to Player object
    
    -- Combat stats
    self.maxHp = 150
    self.hp = self.maxHp
    self.sightRadius = 8  -- Buildings see further
    
    -- Tier system: 1 = Town Hall, 2 = Hold, 3 = Keep
    self.tier = 1
    
    -- Building construction state
    self.isBuilding = params.isBuilding or false
    self.buildProgress = 0
    self.buildTime = TownHall.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    self.isProducing = false
    self.productionTime = 10.0
    self.productionTimer = 0
    self.productionCost = 400
    self.actionButton = nil
    self.productionQueue = {}  -- Queue of units to produce
    self.maxQueueSize = 5
    
    -- Upgrade state
    self.isUpgrading = false
    self.upgradeProgress = 0
    self.upgradeTime = 0
    self.upgradeButton = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function TownHall:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function TownHall:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function TownHall:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function TownHall:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function TownHall:update(dt)
    -- Handle construction
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return false, false, true  -- peon ready, upgrade complete, build complete
        end
        return false, false, false
    end
    
    -- Handle upgrading
    if self.isUpgrading then
        self.upgradeProgress = self.upgradeProgress + dt
        if self.upgradeProgress >= self.upgradeTime then
            self.isUpgrading = false
            self.upgradeProgress = 0
            self.tier = self.tier + 1
            -- Update name based on tier
            if self.tier == 2 then
                self.name = "Hold"
            elseif self.tier == 3 then
                self.name = "Keep"
            end
            return false, true, false  -- upgrade complete
        end
        return false, false, false
    end
    
    -- Handle production
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= self.productionTime then
            -- Remove the completed unit from queue
            if #self.productionQueue > 0 then
                table.remove(self.productionQueue, 1)
            end
            
            -- Check if there's another unit in queue
            if #self.productionQueue > 0 then
                -- Start next unit
                self.productionTimer = 0
            else
                -- Queue empty, stop production
                self.isProducing = false
                self.productionTimer = 0
            end
            return true, false, false  -- peon ready
        end
    end
    return false, false, false
end

function TownHall:startUpgrade()
    if not self.isUpgrading and not self.isProducing then
        self.isUpgrading = true
        self.upgradeProgress = 0
        if self.tier == 1 then
            self.upgradeTime = TownHall.HOLD_UPGRADE_TIME
        elseif self.tier == 2 then
            self.upgradeTime = TownHall.KEEP_UPGRADE_TIME
        end
        return true
    end
    return false
end

function TownHall:canUpgrade()
    if not self.completed or self.isBuilding or self.isUpgrading or self.isProducing then return false end
    if self.tier == 1 then
        return Requirements.canUpgradeToHold()
    elseif self.tier == 2 then
        return Requirements.canUpgradeToKeep()
    end
    return false
end

function TownHall:getUpgradeCost()
    if self.tier == 1 then
        return TownHall.HOLD_COST_GOLD, TownHall.HOLD_COST_LUMBER
    elseif self.tier == 2 then
        return TownHall.KEEP_COST_GOLD, TownHall.KEEP_COST_LUMBER
    end
    return 0, 0
end

function TownHall:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Draw construction scaffolding if being built
    if self.isBuilding then
        love.graphics.setColor(0.5, 0.4, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.3, 0.8)
        -- Scaffolding poles
        love.graphics.rectangle("fill", x + 5, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + size - 9, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 2, size - 10, 4)
        
        -- Build progress bar
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
        
        -- Selection highlight
        if self.selected then
            love.graphics.setColor(0, 1, 0, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
        end
        
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    
    -- Draw based on tier
    if self.tier == 1 then
        self:drawTownHall(x, y, size)
    elseif self.tier == 2 then
        self:drawHold(x, y, size)
    else
        self:drawKeep(x, y, size)
    end
    
    -- Selection highlight
    if self.selected then
        local playerTeam = Teams and Teams.PLAYER or 1
        if self.team == playerTeam then
            love.graphics.setColor(0, 1, 0, 0.8)  -- Green for player
        else
            love.graphics.setColor(1, 0, 0, 0.8)  -- Red for enemy
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
        love.graphics.setColor(0.2, 0.8, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
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
    
    -- Health bar (if damaged)
    self:drawHealthBar()
    
    love.graphics.setColor(1, 1, 1, 1)
end

function TownHall:drawTownHall(x, y, size)
    -- Desert Warrior color palette
    local tealDark = {0.10, 0.25, 0.35}
    local tealMid = {0.15, 0.40, 0.50}
    local tealLight = {0.25, 0.55, 0.65}
    local goldDark = {0.45, 0.35, 0.15}
    local goldMid = {0.72, 0.58, 0.22}
    local goldLight = {0.92, 0.78, 0.35}
    local marble = {0.88, 0.86, 0.82}
    local marbleDark = {0.70, 0.68, 0.64}
    local marbleShadow = {0.55, 0.53, 0.50}
    local bronze = {0.55, 0.45, 0.30}
    local bronzeLight = {0.70, 0.58, 0.38}
    
    -- Helper: draw vertical gradient rectangle
    local function gradientRect(rx, ry, rw, rh, c1, c2, weathering)
        for i = 0, rh - 1 do
            local t = i / rh
            local r = c1[1] + (c2[1] - c1[1]) * t
            local g = c1[2] + (c2[2] - c1[2]) * t
            local b = c1[3] + (c2[3] - c1[3]) * t
            -- Add subtle noise for weathering
            if weathering then
                local noise = (math.sin(rx * 0.3 + i * 0.5) * 0.02 + math.cos(ry * 0.2 + i * 0.7) * 0.02)
                r, g, b = r + noise, g + noise, b + noise
            end
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", rx, ry + i, rw, 1)
        end
    end
    
    -- Helper: draw weathered/aged surface
    local function weatheredRect(rx, ry, rw, rh, baseColor, darken)
        darken = darken or 0.15
        gradientRect(rx, ry, rw, rh, 
            {baseColor[1] + 0.05, baseColor[2] + 0.05, baseColor[3] + 0.05},
            {baseColor[1] - darken, baseColor[2] - darken, baseColor[3] - darken},
            true)
        -- Add some staining/aging marks
        love.graphics.setColor(0, 0, 0, 0.05)
        for i = 1, 3 do
            local stainX = rx + math.sin(rx + i * 17) * rw * 0.3 + rw * 0.3
            local stainY = ry + math.cos(ry + i * 13) * rh * 0.3 + rh * 0.5
            love.graphics.ellipse("fill", stainX, stainY, rw * 0.15, rh * 0.1)
        end
    end
    
    -- Helper: draw column with cylindrical shading
    local function drawColumn(cx, cy, cw, ch)
        -- Column is lighter on left (lit side), darker on right
        for i = 0, cw - 1 do
            local t = i / cw
            -- Cylindrical falloff
            local shade = 1 - (math.abs(t - 0.35) * 1.2)
            shade = math.max(0.7, math.min(1.0, shade))
            local r = marble[1] * shade
            local g = marble[2] * shade
            local b = marble[3] * shade
            -- Vertical weathering gradient
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", cx + i, cy, 1, ch)
        end
        -- Subtle fluting (grooves)
        love.graphics.setColor(0, 0, 0, 0.08)
        love.graphics.rectangle("fill", cx + cw * 0.25, cy + 3, 1, ch - 6)
        love.graphics.rectangle("fill", cx + cw * 0.5, cy + 3, 1, ch - 6)
        love.graphics.rectangle("fill", cx + cw * 0.75, cy + 3, 1, ch - 6)
        -- Highlight on lit edge
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("fill", cx + 1, cy + 2, 1, ch - 4)
    end
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x + size/2, y + size + 5, size/2 - 5, 10)
    
    -- Stone foundation / steps (3 levels) with gradient
    for i = 2, 0, -1 do
        local stepY = y + size - 8 + i * 4
        local stepInset = i * 4
        local baseShade = 0.65 - i * 0.05
        gradientRect(x + stepInset, stepY, size - stepInset*2, 6,
            {baseShade + 0.08, baseShade + 0.06, baseShade + 0.04},
            {baseShade - 0.05, baseShade - 0.06, baseShade - 0.06}, true)
        -- Step edge highlight
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("fill", x + stepInset, stepY, size - stepInset*2, 1)
        -- Step edge shadow
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.rectangle("fill", x + stepInset, stepY + 5, size - stepInset*2, 1)
    end
    
    -- Main temple base platform with weathering
    weatheredRect(x + 4, y + 35, size - 8, size - 43, marbleDark, 0.12)
    
    -- Back wall (inner sanctum) - darker gradient
    gradientRect(x + 20, y + 28, size - 40, 50,
        {marbleShadow[1] + 0.05, marbleShadow[2] + 0.05, marbleShadow[3] + 0.05},
        {marbleShadow[1] - 0.1, marbleShadow[2] - 0.1, marbleShadow[3] - 0.08}, true)
    
    -- Columns (6 across front)
    local numColumns = 6
    local colSpacing = (size - 24) / (numColumns - 1)
    local colWidth = 8
    local colHeight = 55
    
    for i = 0, numColumns - 1 do
        local colX = x + 12 + i * colSpacing - colWidth/2
        local colY = y + 25
        
        -- Column shadow on ground
        love.graphics.setColor(0, 0, 0, 0.12)
        love.graphics.ellipse("fill", colX + colWidth/2 + 2, colY + colHeight + 2, colWidth/2 + 1, 3)
        
        -- Column shaft with cylindrical shading
        drawColumn(colX, colY + 8, colWidth, colHeight - 8)
        
        -- Column base (torus) with gradient
        gradientRect(colX - 2, colY + colHeight - 2, colWidth + 4, 4,
            {marbleDark[1] + 0.05, marbleDark[2] + 0.05, marbleDark[3] + 0.05},
            {marbleDark[1] - 0.08, marbleDark[2] - 0.08, marbleDark[3] - 0.08}, false)
        
        -- Capital (Ionic style with gold) - gradient
        gradientRect(colX - 3, colY + 4, colWidth + 6, 6,
            {goldLight[1], goldLight[2], goldLight[3]},
            {goldDark[1], goldDark[2], goldDark[3]}, false)
        -- Volutes (spiral decorations) with highlight
        love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
        love.graphics.circle("fill", colX - 1, colY + 7, 3)
        love.graphics.circle("fill", colX + colWidth + 1, colY + 7, 3)
        love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.6)
        love.graphics.circle("fill", colX - 2, colY + 6, 1.5)
        love.graphics.circle("fill", colX + colWidth, colY + 6, 1.5)
        love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
        love.graphics.circle("fill", colX - 1, colY + 7, 1.2)
        love.graphics.circle("fill", colX + colWidth + 1, colY + 7, 1.2)
        
        -- Abacus (top of capital) with gradient
        gradientRect(colX - 4, colY, colWidth + 8, 5,
            {marble[1] + 0.05, marble[2] + 0.05, marble[3] + 0.05},
            {marble[1] - 0.05, marble[2] - 0.05, marble[3] - 0.05}, false)
    end
    
    -- Entablature (horizontal beam above columns) with gradient
    gradientRect(x + 2, y + 18, size - 4, 8,
        {marble[1] + 0.03, marble[2] + 0.03, marble[3] + 0.03},
        {marble[1] - 0.08, marble[2] - 0.08, marble[3] - 0.08}, true)
    -- Frieze with teal gradient
    gradientRect(x + 4, y + 20, size - 8, 4,
        {tealMid[1] + 0.05, tealMid[2] + 0.05, tealMid[3] + 0.05},
        {tealDark[1], tealDark[2], tealDark[3]}, false)
    -- Gold meander pattern on frieze
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    for i = 0, 8 do
        local px = x + 10 + i * 10
        love.graphics.rectangle("fill", px, y + 21, 6, 2)
    end
    
    -- Pediment (triangular roof) with gradient shading
    -- Draw as horizontal slices for gradient effect
    local pedHeight = 26
    for row = 0, pedHeight do
        local t = row / pedHeight
        local rowWidth = (size) * (1 - t)
        local rowX = x + (size - rowWidth) / 2
        local shade = marble[1] - t * 0.08
        -- Add slight variation
        local noise = math.sin(row * 0.5) * 0.01
        love.graphics.setColor(shade + noise, shade - 0.02 + noise, shade - 0.04 + noise, 1)
        love.graphics.rectangle("fill", rowX, y + 18 - row, rowWidth, 1)
    end
    
    -- Pediment shadow/depth line
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.line(x + 6, y + 16, x + size/2, y - 2)
    love.graphics.line(x + size - 6, y + 16, x + size/2, y - 2)
    
    -- Tympanum (inner triangle) with gradient
    love.graphics.setColor(tealDark[1], tealDark[2], tealDark[3], 0.85)
    love.graphics.polygon("fill", x + 15, y + 14, x + size - 15, y + 14, x + size/2, y + 2)
    -- Tympanum depth shading
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.polygon("fill", x + 18, y + 12, x + size - 18, y + 12, x + size/2, y + 4)
    
    -- Central relief figure (warrior/deity) with metallic shading
    gradientRect(x + size/2 - 4, y + 4, 8, 10,
        {goldLight[1], goldLight[2], goldLight[3]},
        {goldDark[1], goldDark[2], goldDark[3]}, false)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.circle("fill", x + size/2, y + 3, 3)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.5)
    love.graphics.circle("fill", x + size/2 - 1, y + 2, 1.5)
    
    -- Acroteria (roof corner decorations) with gradient
    local function drawAcroterion(ax, ay, asize, flip)
        for row = 0, asize do
            local t = row / asize
            local rowW = asize * (1 - t) * 0.8
            local shade = goldMid[1] + (goldLight[1] - goldMid[1]) * (1 - t)
            love.graphics.setColor(shade, shade * 0.85, shade * 0.4, 1)
            love.graphics.rectangle("fill", ax - rowW/2, ay - row, rowW, 1)
        end
    end
    drawAcroterion(x + size/2, y - 6, 8, false)
    drawAcroterion(x + 2, y + 13, 5, false)
    drawAcroterion(x + size - 2, y + 13, 5, false)
    
    -- Bronze doors with metallic gradient
    gradientRect(x + size/2 - 12, y + 50, 24, 35,
        {bronzeLight[1], bronzeLight[2], bronzeLight[3]},
        {bronze[1] - 0.1, bronze[2] - 0.1, bronze[3] - 0.05}, true)
    -- Door panel insets with darker gradient
    for py = 0, 1 do
        for px = 0, 1 do
            local panelX = x + size/2 - 10 + px * 11
            local panelY = y + 53 + py * 16
            gradientRect(panelX, panelY, 9, 14,
                {bronze[1] - 0.05, bronze[2] - 0.05, bronze[3] - 0.02},
                {bronze[1] - 0.15, bronze[2] - 0.15, bronze[3] - 0.1}, false)
            -- Panel highlight edge
            love.graphics.setColor(bronzeLight[1], bronzeLight[2], bronzeLight[3], 0.4)
            love.graphics.rectangle("fill", panelX, panelY, 9, 1)
            love.graphics.rectangle("fill", panelX, panelY, 1, 14)
        end
    end
    -- Door handles (gold rings)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.circle("fill", x + size/2 - 5, y + 68, 2.5)
    love.graphics.circle("fill", x + size/2 + 5, y + 68, 2.5)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.circle("fill", x + size/2 - 5, y + 68, 1.2)
    love.graphics.circle("fill", x + size/2 + 5, y + 68, 1.2)
    
    -- Torch flames with glow gradient
    for _, tx in ipairs({x + 16, x + size - 16}) do
        -- Outer glow
        for r = 8, 1, -1 do
            local alpha = (1 - r/8) * 0.15
            love.graphics.setColor(1, 0.5, 0.1, alpha)
            love.graphics.circle("fill", tx, y + 45, r)
        end
        -- Inner flame
        love.graphics.setColor(1, 0.8, 0.3, 0.9)
        love.graphics.circle("fill", tx, y + 45, 3)
        love.graphics.setColor(1, 0.95, 0.7, 0.7)
        love.graphics.circle("fill", tx, y + 44, 1.5)
    end
    
    -- Team colored banner with fabric folds
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {tealMid[1], tealMid[2], tealMid[3], 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {goldMid[1], goldMid[2], goldMid[3], 1}
    
    -- Banner pole with metallic gradient
    gradientRect(x + size/2 - 1, y - 30, 2, 22,
        {goldMid[1], goldMid[2], goldMid[3]},
        {goldDark[1] - 0.1, goldDark[2] - 0.1, goldDark[3] - 0.05}, false)
    
    -- Banner with subtle fold shading
    love.graphics.setColor(bannerColor)
    love.graphics.polygon("fill",
        x + size/2 + 1, y - 28,
        x + size/2 + 18, y - 22,
        x + size/2 + 15, y - 14,
        x + size/2 + 1, y - 10
    )
    -- Banner fold highlight
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.polygon("fill",
        x + size/2 + 1, y - 28,
        x + size/2 + 8, y - 25,
        x + size/2 + 6, y - 18,
        x + size/2 + 1, y - 16
    )
    -- Banner fold shadow
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.polygon("fill",
        x + size/2 + 12, y - 23,
        x + size/2 + 18, y - 22,
        x + size/2 + 15, y - 14,
        x + size/2 + 10, y - 16
    )
    -- Emblem on banner
    love.graphics.setColor(emblemColor)
    love.graphics.circle("fill", x + size/2 + 9, y - 19, 4)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", x + size/2 + 9, y - 19, 2)
    
    love.graphics.setLineWidth(1)
end

function TownHall:drawHold(x, y, size)
    -- Desert Warrior color palette
    local tealDark = {0.10, 0.25, 0.35}
    local tealMid = {0.15, 0.40, 0.50}
    local goldDark = {0.45, 0.35, 0.15}
    local goldMid = {0.72, 0.58, 0.22}
    local goldLight = {0.92, 0.78, 0.35}
    local marble = {0.88, 0.86, 0.82}
    local marbleDark = {0.70, 0.68, 0.64}
    local marbleShadow = {0.55, 0.53, 0.50}
    local bronze = {0.55, 0.45, 0.30}
    local bronzeLight = {0.70, 0.58, 0.38}
    
    -- Shadow with soft gradient
    for r = 12, 1, -1 do
        local alpha = (1 - r/12) * 0.25
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.ellipse("fill", x + size/2, y + size + 5, size/2 - 3 + r/2, 8 + r/3)
    end
    
    -- Foundation steps with gradients
    for i = 3, 0, -1 do
        local stepY = y + size - 6 + i * 4
        local stepInset = i * 3
        local baseShade = 0.68 - i * 0.04
        gradientRect(x + stepInset, stepY, size - stepInset*2, 6,
            {baseShade + 0.06, baseShade + 0.04, baseShade + 0.02},
            {baseShade - 0.06, baseShade - 0.07, baseShade - 0.07}, true)
        -- Step highlight
        love.graphics.setColor(1, 1, 1, 0.18)
        love.graphics.rectangle("fill", x + stepInset, stepY, size - stepInset*2, 1)
        -- Step shadow
        love.graphics.setColor(0, 0, 0, 0.12)
        love.graphics.rectangle("fill", x + stepInset, stepY + 5, size - stepInset*2, 1)
    end
    
    -- Main platform with weathering
    weatheredRect(x + 2, y + 30, size - 4, size - 40, marbleDark, 0.1)
    
    -- Back wall with gradient
    gradientRect(x + 15, y + 24, size - 30, 55,
        {marbleShadow[1] + 0.03, marbleShadow[2] + 0.03, marbleShadow[3] + 0.03},
        {marbleShadow[1] - 0.12, marbleShadow[2] - 0.12, marbleShadow[3] - 0.1}, true)
    
    -- Wall frieze decoration
    gradientRect(x + 20, y + 30, size - 40, 8,
        {tealMid[1], tealMid[2], tealMid[3]},
        {tealDark[1], tealDark[2], tealDark[3]}, false)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 0.7)
    for i = 0, 6 do
        love.graphics.rectangle("fill", x + 25 + i * 11, y + 31, 7, 6)
    end
    
    -- 8 columns with cylindrical shading
    local numColumns = 8
    local colSpacing = (size - 20) / (numColumns - 1)
    local colWidth = 7
    local colHeight = 52
    
    for i = 0, numColumns - 1 do
        local colX = x + 10 + i * colSpacing - colWidth/2
        local colY = y + 22
        
        -- Column ground shadow
        love.graphics.setColor(0, 0, 0, 0.1)
        love.graphics.ellipse("fill", colX + colWidth/2 + 2, colY + colHeight + 2, colWidth/2 + 1, 2)
        
        -- Column with cylindrical shading
        drawColumn(colX, colY + 7, colWidth, colHeight - 7, marble, marbleDark)
        
        -- Base with gradient
        gradientRect(colX - 2, colY + colHeight - 2, colWidth + 4, 4,
            {marbleDark[1] + 0.04, marbleDark[2] + 0.04, marbleDark[3] + 0.04},
            {marbleDark[1] - 0.06, marbleDark[2] - 0.06, marbleDark[3] - 0.06}, false)
        
        -- Capital with gold gradient
        gradientRect(colX - 3, colY + 3, colWidth + 6, 6,
            {goldLight[1], goldLight[2], goldLight[3]},
            {goldDark[1], goldDark[2], goldDark[3]}, false)
        love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.7)
        love.graphics.polygon("fill", colX - 2, colY + 6, colX + colWidth/2, colY - 1, colX + colWidth + 2, colY + 6)
        
        -- Abacus
        gradientRect(colX - 4, colY - 1, colWidth + 8, 5,
            {marble[1] + 0.03, marble[2] + 0.03, marble[3] + 0.03},
            {marble[1] - 0.04, marble[2] - 0.04, marble[3] - 0.04}, false)
    end
    
    -- Entablature with gradient
    gradientRect(x, y + 14, size, 9,
        {marble[1] + 0.02, marble[2] + 0.02, marble[3] + 0.02},
        {marble[1] - 0.06, marble[2] - 0.06, marble[3] - 0.06}, true)
    
    -- Frieze
    gradientRect(x + 2, y + 16, size - 4, 5,
        {tealMid[1] + 0.03, tealMid[2] + 0.03, tealMid[3] + 0.03},
        {tealDark[1], tealDark[2], tealDark[3]}, false)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    for i = 0, 10 do
        love.graphics.rectangle("fill", x + 8 + i * 9, y + 17, 5, 3)
    end
    
    -- Pediment with gradient shading (slice by slice)
    local pedHeight = 29
    for row = 0, pedHeight do
        local t = row / pedHeight
        local rowWidth = (size + 6) * (1 - t)
        local rowX = x - 3 + (size + 6 - rowWidth) / 2
        local shade = marble[1] - t * 0.06
        local noise = math.sin(row * 0.5) * 0.01
        love.graphics.setColor(shade + noise, shade - 0.02 + noise, shade - 0.04 + noise, 1)
        love.graphics.rectangle("fill", rowX, y + 14 - row, rowWidth, 1)
    end
    
    -- Pediment edge shadows
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 8, y + 12, x + size/2, y - 8)
    love.graphics.line(x + size - 8, y + 12, x + size/2, y - 8)
    
    -- Tympanum with gradient
    love.graphics.setColor(tealDark[1], tealDark[2], tealDark[3], 0.75)
    love.graphics.polygon("fill", x + 15, y + 10, x + size - 15, y + 10, x + size/2, y - 3)
    love.graphics.setColor(0, 0, 0, 0.12)
    love.graphics.polygon("fill", x + 18, y + 8, x + size - 18, y + 8, x + size/2, y - 1)
    
    -- Warrior figures with metallic shading
    for _, wx in ipairs({x + size/2, x + size/2 - 18, x + size/2 + 18}) do
        local figSize = (wx == x + size/2) and 1.3 or 1.0
        gradientRect(wx - 4*figSize, y + 6 - 4*figSize, 8*figSize, 10*figSize,
            {goldLight[1], goldLight[2], goldLight[3]},
            {goldDark[1], goldDark[2], goldDark[3]}, false)
        love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
        love.graphics.circle("fill", wx, y + 2 - 2*figSize, 3*figSize)
        love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.5)
        love.graphics.circle("fill", wx - 1, y + 1 - 2*figSize, 1.5*figSize)
    end
    
    -- Acroteria with gradient
    drawAcroterion(x + size/2, y - 13, 10, goldMid, goldLight)
    drawAcroterion(x + 2, y + 10, 6, goldMid, goldLight)
    drawAcroterion(x + size - 2, y + 10, 6, goldMid, goldLight)
    
    -- Bronze doors
    drawBronzeDoor(x + size/2 - 15, y + 45, 30, 40, bronze, bronzeLight, goldMid, goldDark)
    
    -- Torches
    drawTorchFlame(x + 14, y + 42)
    drawTorchFlame(x + size - 14, y + 42)
    
    -- Two banners
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {tealMid[1], tealMid[2], tealMid[3], 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {goldMid[1], goldMid[2], goldMid[3], 1}
    drawBanner(x + size/2 - 24, y, bannerColor, emblemColor, goldDark, goldMid)
    drawBanner(x + size/2 + 24, y, bannerColor, emblemColor, goldDark, goldMid)
    
    love.graphics.setLineWidth(1)
end

function TownHall:drawKeep(x, y, size)
    -- Desert Warrior color palette
    local tealDark = {0.10, 0.25, 0.35}
    local tealMid = {0.15, 0.40, 0.50}
    local goldDark = {0.45, 0.35, 0.15}
    local goldMid = {0.72, 0.58, 0.22}
    local goldLight = {0.92, 0.78, 0.35}
    local marble = {0.92, 0.90, 0.86}
    local marbleDark = {0.75, 0.73, 0.69}
    local marbleShadow = {0.58, 0.56, 0.52}
    local bronze = {0.58, 0.48, 0.32}
    local bronzeLight = {0.75, 0.62, 0.42}
    
    -- Grand shadow with soft gradient
    for r = 14, 1, -1 do
        local alpha = (1 - r/14) * 0.3
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.ellipse("fill", x + size/2, y + size + 6, size/2 + r/2, 9 + r/3)
    end
    
    -- Massive foundation with 5 gradient steps
    for i = 4, 0, -1 do
        local stepY = y + size - 5 + i * 4
        local stepInset = i * 2.5
        local baseShade = 0.72 - i * 0.03
        gradientRect(x + stepInset - 3, stepY, size - stepInset*2 + 6, 6,
            {baseShade + 0.05, baseShade + 0.03, baseShade + 0.01},
            {baseShade - 0.05, baseShade - 0.06, baseShade - 0.06}, true)
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("fill", x + stepInset - 3, stepY, size - stepInset*2 + 6, 1)
        love.graphics.setColor(0, 0, 0, 0.1)
        love.graphics.rectangle("fill", x + stepInset - 3, stepY + 5, size - stepInset*2 + 6, 1)
    end
    
    -- Grand platform with weathering
    weatheredRect(x - 2, y + 28, size + 4, size - 38, marbleDark, 0.08)
    
    -- Inner sanctum with gradient
    gradientRect(x + 12, y + 20, size - 24, 60,
        {marbleShadow[1] + 0.02, marbleShadow[2] + 0.02, marbleShadow[3] + 0.02},
        {marbleShadow[1] - 0.1, marbleShadow[2] - 0.1, marbleShadow[3] - 0.08}, true)
    
    -- Statue alcove with depth gradient
    gradientRect(x + size/2 - 12, y + 38, 24, 30,
        {tealDark[1] + 0.05, tealDark[2] + 0.05, tealDark[3] + 0.05},
        {tealDark[1] - 0.05, tealDark[2] - 0.05, tealDark[3] - 0.03}, false)
    love.graphics.setColor(tealDark[1], tealDark[2], tealDark[3], 0.7)
    love.graphics.arc("fill", x + size/2, y + 38, 12, math.pi, 2 * math.pi)
    
    -- Golden statue with metallic gradient
    gradientRect(x + size/2 - 5, y + 48, 10, 20,
        {goldLight[1], goldLight[2], goldLight[3]},
        {goldDark[1], goldDark[2], goldDark[3]}, false)
    -- Statue head with highlight
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.circle("fill", x + size/2, y + 45, 5)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.6)
    love.graphics.circle("fill", x + size/2 - 1.5, y + 43.5, 2)
    -- Crown with gradient
    drawAcroterion(x + size/2, y + 38, 6, goldMid, goldLight)
    -- Shield with bronze gradient
    for i = 0, 7 do
        local t = i / 7
        local shade = bronzeLight[1] - t * 0.15
        love.graphics.setColor(shade, shade * 0.85, shade * 0.6, 1)
        love.graphics.ellipse("fill", x + size/2 - 8, y + 54, 4 - t*0.5, 7 - t*0.5)
    end
    -- Spear with metallic sheen
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + size/2 + 8, y + 68, x + size/2 + 10, y + 38)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + size/2 + 8.5, y + 68, x + size/2 + 10.5, y + 40)
    
    -- 10 grand columns with cylindrical shading
    local numColumns = 10
    local colSpacing = (size + 4) / (numColumns - 1)
    local colWidth = 6
    local colHeight = 50
    
    for i = 0, numColumns - 1 do
        local colX = x - 2 + i * colSpacing - colWidth/2
        local colY = y + 20
        
        -- Column ground shadow
        love.graphics.setColor(0, 0, 0, 0.08)
        love.graphics.ellipse("fill", colX + colWidth/2 + 2, colY + colHeight + 2, colWidth/2 + 1, 2)
        
        -- Column with cylindrical shading
        drawColumn(colX, colY + 6, colWidth, colHeight - 6, marble, marbleDark)
        
        -- Base with gradient
        gradientRect(colX - 1.5, colY + colHeight - 2, colWidth + 3, 4,
            {marbleDark[1] + 0.03, marbleDark[2] + 0.03, marbleDark[3] + 0.03},
            {marbleDark[1] - 0.05, marbleDark[2] - 0.05, marbleDark[3] - 0.05}, false)
        
        -- Capital with gold gradient
        gradientRect(colX - 2, colY + 2, colWidth + 4, 5,
            {goldLight[1], goldLight[2], goldLight[3]},
            {goldDark[1], goldDark[2], goldDark[3]}, false)
        love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.8)
        love.graphics.polygon("fill", colX - 1, colY + 5, colX + colWidth/2, colY - 2, colX + colWidth + 1, colY + 5)
        
        -- Abacus
        gradientRect(colX - 3, colY - 2, colWidth + 6, 5,
            {marble[1] + 0.02, marble[2] + 0.02, marble[3] + 0.02},
            {marble[1] - 0.03, marble[2] - 0.03, marble[3] - 0.03}, false)
    end
    
    -- Grand entablature with gradient
    gradientRect(x - 5, y + 10, size + 10, 11,
        {marble[1] + 0.02, marble[2] + 0.02, marble[3] + 0.02},
        {marble[1] - 0.05, marble[2] - 0.05, marble[3] - 0.05}, true)
    
    -- Elaborate frieze
    gradientRect(x - 3, y + 12, size + 6, 6,
        {tealMid[1] + 0.03, tealMid[2] + 0.03, tealMid[3] + 0.03},
        {tealDark[1], tealDark[2], tealDark[3]}, false)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    for i = 0, 12 do
        love.graphics.rectangle("fill", x + 4 + i * 8, y + 13, 5, 4)
    end
    
    -- Grand pediment with gradient shading
    local pedHeight = 32
    for row = 0, pedHeight do
        local t = row / pedHeight
        local rowWidth = (size + 16) * (1 - t)
        local rowX = x - 8 + (size + 16 - rowWidth) / 2
        local shade = marble[1] - t * 0.05
        local noise = math.sin(row * 0.4) * 0.008
        love.graphics.setColor(shade + noise, shade - 0.015 + noise, shade - 0.03 + noise, 1)
        love.graphics.rectangle("fill", rowX, y + 10 - row, rowWidth, 1)
    end
    
    -- Pediment edge shadows
    love.graphics.setColor(0, 0, 0, 0.12)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 5, y + 8, x + size/2, y - 15)
    love.graphics.line(x + size - 5, y + 8, x + size/2, y - 15)
    
    -- Grand tympanum
    love.graphics.setColor(tealDark[1], tealDark[2], tealDark[3], 0.7)
    love.graphics.polygon("fill", x + 12, y + 6, x + size - 12, y + 6, x + size/2, y - 10)
    love.graphics.setColor(0, 0, 0, 0.1)
    love.graphics.polygon("fill", x + 16, y + 4, x + size - 16, y + 4, x + size/2, y - 8)
    
    -- Epic battle scene with metallic figures
    local figurePositions = {
        {x + size/2, 1.5},          -- Center deity
        {x + size/2 - 22, 1.0},     -- Left warrior 1
        {x + size/2 + 22, 1.0},     -- Right warrior 1
        {x + size/2 - 35, 0.8},     -- Left warrior 2
        {x + size/2 + 35, 0.8},     -- Right warrior 2
    }
    for _, fig in ipairs(figurePositions) do
        local fx, fscale = fig[1], fig[2]
        gradientRect(fx - 4*fscale, y + 4 - 3*fscale, 8*fscale, 9*fscale,
            {goldLight[1], goldLight[2], goldLight[3]},
            {goldDark[1], goldDark[2], goldDark[3]}, false)
        love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
        love.graphics.circle("fill", fx, y + 1 - 5*fscale, 2.5*fscale)
        love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.5)
        love.graphics.circle("fill", fx - 0.8*fscale, y - 5.5*fscale, 1.2*fscale)
    end
    -- Radiating light from central figure
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.3)
    for ray = 0, 5 do
        local angle = math.pi + ray * math.pi / 6
        love.graphics.line(x + size/2, y - 6, x + size/2 + math.cos(angle) * 10, y - 6 + math.sin(angle) * 8)
    end
    
    -- Grand acroteria
    drawAcroterion(x + size/2, y - 20, 14, goldMid, goldLight)
    drawAcroterion(x - 2, y + 6, 8, goldMid, goldLight)
    drawAcroterion(x + size + 2, y + 6, 8, goldMid, goldLight)
    
    -- Grand bronze doors
    drawBronzeDoor(x + size/2 - 18, y + 70, 36, 25, bronze, bronzeLight, goldMid, goldDark)
    
    -- Grand torches
    drawTorchFlame(x + 8, y + 40)
    drawTorchFlame(x + size - 8, y + 40)
    
    -- Royal banner (center, large)
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {tealMid[1], tealMid[2], tealMid[3], 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {goldMid[1], goldMid[2], goldMid[3], 1}
    
    -- Banner pole with metallic gradient
    gradientRect(x + size/2 - 1, y - 55, 3, 35,
        {goldMid[1], goldMid[2], goldMid[3]},
        {goldDark[1] - 0.1, goldDark[2] - 0.1, goldDark[3] - 0.05}, false)
    -- Pole top ornament
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.circle("fill", x + size/2, y - 58, 4)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 0.6)
    love.graphics.circle("fill", x + size/2 + 1, y - 59, 1.5)
    
    -- Large banner with fabric folds
    love.graphics.setColor(bannerColor)
    love.graphics.polygon("fill",
        x + size/2 + 2, y - 53,
        x + size/2 + 28, y - 42,
        x + size/2 + 25, y - 28,
        x + size/2 + 2, y - 22
    )
    -- Fabric highlight
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.polygon("fill",
        x + size/2 + 2, y - 53,
        x + size/2 + 12, y - 48,
        x + size/2 + 10, y - 35,
        x + size/2 + 2, y - 32
    )
    -- Fabric shadow
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.polygon("fill",
        x + size/2 + 18, y - 44,
        x + size/2 + 28, y - 42,
        x + size/2 + 25, y - 28,
        x + size/2 + 16, y - 30
    )
    
    -- Crown emblem on banner
    love.graphics.setColor(emblemColor)
    love.graphics.polygon("fill",
        x + size/2 + 8, y - 46,
        x + size/2 + 11, y - 38,
        x + size/2 + 15, y - 46,
        x + size/2 + 18, y - 38,
        x + size/2 + 22, y - 46,
        x + size/2 + 20, y - 32,
        x + size/2 + 6, y - 32
    )
    
    love.graphics.setLineWidth(1)
end

function TownHall:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

-- Combat Methods --

function TownHall:takeDamage(amount)
    self.hp = self.hp - amount
    self.flashTimer = 0.1  -- Visual feedback
end

function TownHall:isDead()
    return self.hp <= 0
end

function TownHall:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 10
    local barHeight = 6
    local barX = x + 5
    local barY = y - 12
    
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

function TownHall:startProduction()
    -- Add to queue if not full
    if #self.productionQueue < self.maxQueueSize then
        table.insert(self.productionQueue, "peon")
        
        -- Start production immediately if not already producing
        if not self.isProducing and not self.isUpgrading and #self.productionQueue > 0 then
            self.isProducing = true
            self.productionTimer = 0
        end
        return true
    end
    return false
end

function TownHall:cancelProduction()
    -- Cancel the last item in queue and refund
    if #self.productionQueue > 0 then
        table.remove(self.productionQueue)
        -- If we cancelled the one being produced, stop production
        if #self.productionQueue == 0 then
            self.isProducing = false
            self.productionTimer = 0
        end
        return self.productionCost  -- Return cost for refund
    end
    return 0
end

function TownHall:getQueueSize()
    return #self.productionQueue
end

function TownHall:canProduce()
    return self.completed and not self.isUpgrading and not self.isBuilding and #self.productionQueue < self.maxQueueSize
end

function TownHall:getProductionProgress()
    if self.isProducing then
        return math.floor((self.productionTimer / self.productionTime) * 100)
    end
    return 0
end

function TownHall:getUpgradeProgress()
    if self.isUpgrading then
        return math.floor((self.upgradeProgress / self.upgradeTime) * 100)
    end
    return 0
end

function TownHall:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function TownHall:getSpawnPos()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize + 20, wy + self.pixelSize / 2
end

function TownHall:updateUI(resources, screenW, screenH, font, currentPop, maxPop)
    currentPop = currentPop or 0
    maxPop = maxPop or 999
    self.currentPop = currentPop
    self.maxPop = maxPop
    
    -- Don't show UI for enemy buildings
    local playerTeam = Teams and Teams.PLAYER or 1
    if self.team ~= playerTeam then return end
    
    if self.selected and self.completed then
        -- New bottom panel positioning
        local panelX = screenW - 288
        local panelY = screenH - 188
        local buttonY = panelY + 55
        local buttonW = 125
        local buttonH = 36
        
        -- Train Peon button
        if not self.actionButton then
            local selfRef = self
            self.actionButton = Button.new({
                x = panelX + 12,
                y = buttonY,
                width = buttonW,
                height = buttonH,
                text = "Peon (400/0)",
                font = font,
                onClick = function()
                    if resources.gold >= selfRef.productionCost and 
                       selfRef:canProduce() and 
                       selfRef.currentPop < selfRef.maxPop then
                        if selfRef:startProduction() then
                            resources.gold = resources.gold - selfRef.productionCost
                        end
                    end
                end
            })
        else
            -- Update button position
            self.actionButton.x = panelX + 12
            self.actionButton.y = buttonY
        end
        
        local canAfford = resources.gold >= self.productionCost
        local hasCapacity = currentPop < maxPop
        self.actionButton:setEnabled(canAfford and hasCapacity and self:canProduce())
        
        -- Set disabled reason for hover tooltip
        local reason = nil
        if self.isUpgrading then
            reason = "Busy upgrading"
        elseif self.isProducing then
            reason = "Already training"
        elseif not canAfford then
            reason = "Need more gold"
        elseif not hasCapacity then
            reason = "Need more farms"
        end
        self.actionButton:setDisabledReason(reason)
        
        self.actionButton:update(0)
        
        -- Upgrade button (if applicable)
        if self.tier < 3 and not self.isUpgrading then
            local upgradeCostGold, upgradeCostLumber = self:getUpgradeCost()
            local upgradeName = self.tier == 1 and "Hold" or "Keep"
            
            if not self.upgradeButton then
                local selfRef = self
                self.upgradeButton = Button.new({
                    x = panelX + 12 + buttonW + 8,
                    y = buttonY,
                    width = buttonW,
                    height = buttonH,
                    text = upgradeName,
                    font = font,
                    colors = {
                        normal = {0.55, 0.45, 0.25, 1},
                        hover = {0.65, 0.55, 0.35, 1},
                        pressed = {0.45, 0.35, 0.15, 1},
                        text = {0.95, 0.92, 0.85, 1},
                        border = {0.7, 0.55, 0.25, 1}
                    },
                    onClick = function()
                        local costG, costL = selfRef:getUpgradeCost()
                        if resources.gold >= costG and resources.lumber >= costL and selfRef:canUpgrade() then
                            resources.gold = resources.gold - costG
                            resources.lumber = resources.lumber - costL
                            selfRef:startUpgrade()
                        end
                    end
                })
            else
                -- Update button position if panel moved
                self.upgradeButton.x = panelX + 12 + buttonW + 8
                self.upgradeButton.y = buttonY
            end
            
            local costText = string.format("%s (%d/%d)", upgradeName, upgradeCostGold, upgradeCostLumber)
            self.upgradeButton:setText(costText)
            
            local canAffordUpgrade = resources.gold >= upgradeCostGold and resources.lumber >= upgradeCostLumber
            self.upgradeButton:setEnabled(canAffordUpgrade and self:canUpgrade())
            
            -- Set disabled reason for hover tooltip
            -- Check requirements FIRST, then resources
            local reason = nil
            if self.isProducing then
                reason = "Busy training peon"
            elseif self.tier == 1 and not Requirements.hasBarracks() then
                reason = "Requires Barracks"
            elseif not canAffordUpgrade then
                if resources.gold < upgradeCostGold and resources.lumber < upgradeCostLumber then
                    reason = "Need more gold & lumber"
                elseif resources.gold < upgradeCostGold then
                    reason = "Need more gold"
                else
                    reason = "Need more lumber"
                end
            end
            self.upgradeButton:setDisabledReason(reason)
            
            self.upgradeButton:update(0)
        else
            self.upgradeButton = nil
        end
    else
        self.actionButton = nil
        self.upgradeButton = nil
    end
end

function TownHall:drawUI()
    -- Don't show UI for enemy buildings
    local playerTeam = Teams and Teams.PLAYER or 1
    if self.team ~= playerTeam then return end
    
    if self.selected and self.completed then
        if self.actionButton then
            self.actionButton:draw()
        end
        
        if self.upgradeButton and self.tier < 3 and not self.isUpgrading then
            self.upgradeButton:draw()
        end
    end
end

function TownHall:mousepressed(x, y, button)
    if self.actionButton then self.actionButton:mousepressed(x, y, button) end
    if self.upgradeButton then self.upgradeButton:mousepressed(x, y, button) end
end

function TownHall:mousereleased(x, y, button)
    if self.actionButton then self.actionButton:mousereleased(x, y, button) end
    if self.upgradeButton then self.upgradeButton:mousereleased(x, y, button) end
end

function TownHall:drawOnMinimap(mapX, mapY, scale)
    -- Use team color for minimap, with tier-based brightness
    if Teams then
        local teamColor = Teams.getColor(self.team, "minimapBuilding")
        -- Brighten based on tier
        local tierMult = 0.8 + self.tier * 0.1
        love.graphics.setColor(
            math.min(1, teamColor[1] * tierMult),
            math.min(1, teamColor[2] * tierMult),
            math.min(1, teamColor[3] * tierMult),
            1
        )
    else
        -- Fallback: Color based on tier
        if self.tier == 3 then
            love.graphics.setColor(0.8, 0.6, 0.2, 1)  -- Gold for Keep
        elseif self.tier == 2 then
            love.graphics.setColor(0.7, 0.5, 0.25, 1)  -- Bronze for Hold
        else
            love.graphics.setColor(0.6, 0.4, 0.2, 1)  -- Brown for Town Hall
        end
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return TownHall
