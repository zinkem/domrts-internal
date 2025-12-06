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
    self.sightRadius = 2  -- Tiles
    
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
            self.isProducing = false
            self.productionTimer = 0
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
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x + size/2, y + size + 5, size/2 - 5, 8)
    
    -- Main castle base (stone walls)
    love.graphics.setColor(0.45, 0.42, 0.38, 1)
    love.graphics.rectangle("fill", x + 8, y + 20, size - 16, size - 20, 2)
    
    -- Stone texture pattern
    love.graphics.setColor(0.4, 0.37, 0.33, 1)
    for row = 0, 4 do
        for col = 0, 3 do
            local offsetX = (row % 2) * 12
            love.graphics.rectangle("fill", x + 12 + col * 20 + offsetX, y + 25 + row * 14, 16, 10, 1)
        end
    end
    
    -- Left tower
    love.graphics.setColor(0.5, 0.47, 0.42, 1)
    love.graphics.rectangle("fill", x, y + 10, 24, size - 10, 2)
    love.graphics.setColor(0.45, 0.42, 0.38, 1)
    for i = 0, 2 do
        love.graphics.rectangle("fill", x + i * 9, y + 2, 6, 12)
    end
    love.graphics.setColor(0.2, 0.25, 0.35, 1)
    love.graphics.rectangle("fill", x + 8, y + 30, 8, 12, 1)
    love.graphics.setColor(0.6, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", x + 11, y + 30, 2, 12)
    
    -- Right tower  
    love.graphics.setColor(0.5, 0.47, 0.42, 1)
    love.graphics.rectangle("fill", x + size - 24, y + 10, 24, size - 10, 2)
    love.graphics.setColor(0.45, 0.42, 0.38, 1)
    for i = 0, 2 do
        love.graphics.rectangle("fill", x + size - 24 + i * 9, y + 2, 6, 12)
    end
    love.graphics.setColor(0.2, 0.25, 0.35, 1)
    love.graphics.rectangle("fill", x + size - 16, y + 30, 8, 12, 1)
    love.graphics.setColor(0.6, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", x + size - 13, y + 30, 2, 12)
    
    -- Center battlements
    love.graphics.setColor(0.48, 0.45, 0.4, 1)
    for i = 0, 4 do
        love.graphics.rectangle("fill", x + 28 + i * 9, y + 12, 6, 10)
    end
    
    -- Main entrance arch
    love.graphics.setColor(0.15, 0.12, 0.08, 1)
    love.graphics.rectangle("fill", x + size/2 - 14, y + size - 45, 28, 45)
    love.graphics.arc("fill", x + size/2, y + size - 45, 14, math.pi, 2 * math.pi)
    
    -- Wooden door
    love.graphics.setColor(0.4, 0.28, 0.15, 1)
    love.graphics.rectangle("fill", x + size/2 - 12, y + size - 40, 24, 40)
    love.graphics.setColor(0.3, 0.2, 0.1, 1)
    love.graphics.rectangle("fill", x + size/2 - 1, y + size - 40, 2, 40)
    love.graphics.setColor(0.35, 0.3, 0.25, 1)
    love.graphics.circle("fill", x + size/2 - 8, y + size - 30, 2)
    love.graphics.circle("fill", x + size/2 + 8, y + size - 30, 2)
    love.graphics.circle("fill", x + size/2 - 8, y + size - 15, 2)
    love.graphics.circle("fill", x + size/2 + 8, y + size - 15, 2)
    
    -- Banner/flag on center - TEAM COLORED
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {0.8, 0.2, 0.2, 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {0.9, 0.8, 0.2, 1}
    
    love.graphics.setColor(0.5, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", x + size/2 - 1, y - 15, 2, 25)
    love.graphics.setColor(bannerColor)
    love.graphics.polygon("fill", 
        x + size/2 + 1, y - 15,
        x + size/2 + 16, y - 8,
        x + size/2 + 1, y
    )
    love.graphics.setColor(emblemColor)
    love.graphics.circle("fill", x + size/2 + 8, y - 8, 3)
    
    -- Torch lights
    love.graphics.setColor(1, 0.7, 0.3, 0.8)
    love.graphics.circle("fill", x + 12, y + 55, 4)
    love.graphics.circle("fill", x + size - 12, y + 55, 4)
    love.graphics.setColor(1, 0.9, 0.5, 0.4)
    love.graphics.circle("fill", x + 12, y + 55, 7)
    love.graphics.circle("fill", x + size - 12, y + 55, 7)
end

function TownHall:drawHold(x, y, size)
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x + size/2, y + size + 5, size/2 - 3, 8)
    
    -- Larger stone base
    love.graphics.setColor(0.42, 0.4, 0.36, 1)
    love.graphics.rectangle("fill", x + 5, y + 18, size - 10, size - 18, 2)
    
    -- Stone texture
    love.graphics.setColor(0.38, 0.36, 0.32, 1)
    for row = 0, 5 do
        for col = 0, 4 do
            local offsetX = (row % 2) * 10
            love.graphics.rectangle("fill", x + 8 + col * 18 + offsetX, y + 22 + row * 12, 14, 9, 1)
        end
    end
    
    -- Taller towers (4 corners)
    love.graphics.setColor(0.48, 0.45, 0.4, 1)
    -- Left front tower
    love.graphics.rectangle("fill", x - 2, y + 5, 26, size - 5, 2)
    -- Right front tower
    love.graphics.rectangle("fill", x + size - 24, y + 5, 26, size - 5, 2)
    
    -- Tower tops (crenellations)
    love.graphics.setColor(0.45, 0.42, 0.38, 1)
    for i = 0, 2 do
        love.graphics.rectangle("fill", x - 2 + i * 10, y - 5, 7, 14)
        love.graphics.rectangle("fill", x + size - 24 + i * 10, y - 5, 7, 14)
    end
    
    -- Conical tower roofs
    love.graphics.setColor(0.35, 0.25, 0.2, 1)
    love.graphics.polygon("fill", x + 11, y - 18, x - 4, y - 2, x + 26, y - 2)
    love.graphics.polygon("fill", x + size - 11, y - 18, x + size - 26, y - 2, x + size + 4, y - 2)
    
    -- Center section with larger door
    love.graphics.setColor(0.12, 0.1, 0.08, 1)
    love.graphics.rectangle("fill", x + size/2 - 18, y + size - 50, 36, 50)
    love.graphics.arc("fill", x + size/2, y + size - 50, 18, math.pi, 2 * math.pi)
    
    -- Reinforced door
    love.graphics.setColor(0.38, 0.26, 0.14, 1)
    love.graphics.rectangle("fill", x + size/2 - 16, y + size - 45, 32, 45)
    love.graphics.setColor(0.45, 0.42, 0.45, 1)
    love.graphics.rectangle("fill", x + size/2 - 16, y + size - 40, 32, 3)
    love.graphics.rectangle("fill", x + size/2 - 16, y + size - 25, 32, 3)
    love.graphics.rectangle("fill", x + size/2 - 16, y + size - 10, 32, 3)
    
    -- Windows
    love.graphics.setColor(0.2, 0.25, 0.35, 1)
    love.graphics.rectangle("fill", x + 8, y + 28, 10, 14, 1)
    love.graphics.rectangle("fill", x + size - 18, y + 28, 10, 14, 1)
    
    -- Banners (two flags) - TEAM COLORED
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {0.7, 0.2, 0.2, 1}
    love.graphics.setColor(0.5, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", x + 10, y - 28, 2, 15)
    love.graphics.rectangle("fill", x + size - 12, y - 28, 2, 15)
    love.graphics.setColor(bannerColor)
    love.graphics.polygon("fill", x + 12, y - 28, x + 25, y - 23, x + 12, y - 16)
    love.graphics.polygon("fill", x + size - 10, y - 28, x + size - 23, y - 23, x + size - 10, y - 16)
    
    -- Gold trim
    love.graphics.setColor(0.8, 0.7, 0.2, 1)
    love.graphics.rectangle("fill", x + size/2 - 20, y + 10, 40, 4)
end

function TownHall:drawKeep(x, y, size)
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x + size/2, y + size + 6, size/2, 9)
    
    -- Massive stone base
    love.graphics.setColor(0.4, 0.38, 0.35, 1)
    love.graphics.rectangle("fill", x + 2, y + 15, size - 4, size - 15, 3)
    
    -- Stone texture (darker, more imposing)
    love.graphics.setColor(0.35, 0.33, 0.3, 1)
    for row = 0, 5 do
        for col = 0, 5 do
            local offsetX = (row % 2) * 8
            love.graphics.rectangle("fill", x + 5 + col * 15 + offsetX, y + 20 + row * 12, 12, 8, 1)
        end
    end
    
    -- Grand towers (taller, more ornate)
    love.graphics.setColor(0.45, 0.43, 0.4, 1)
    love.graphics.rectangle("fill", x - 5, y - 5, 30, size + 5, 2)
    love.graphics.rectangle("fill", x + size - 25, y - 5, 30, size + 5, 2)
    
    -- Tower battlements
    love.graphics.setColor(0.42, 0.4, 0.37, 1)
    for i = 0, 3 do
        love.graphics.rectangle("fill", x - 5 + i * 8, y - 15, 6, 14)
        love.graphics.rectangle("fill", x + size - 25 + i * 8, y - 15, 6, 14)
    end
    
    -- Grand tower roofs with gold tips
    love.graphics.setColor(0.3, 0.22, 0.18, 1)
    love.graphics.polygon("fill", x + 10, y - 35, x - 8, y - 10, x + 28, y - 10)
    love.graphics.polygon("fill", x + size - 10, y - 35, x + size - 28, y - 10, x + size + 8, y - 10)
    -- Gold tips
    love.graphics.setColor(0.9, 0.8, 0.2, 1)
    love.graphics.polygon("fill", x + 10, y - 40, x + 7, y - 32, x + 13, y - 32)
    love.graphics.polygon("fill", x + size - 10, y - 40, x + size - 13, y - 32, x + size - 7, y - 32)
    
    -- Center grand entrance
    love.graphics.setColor(0.1, 0.08, 0.06, 1)
    love.graphics.rectangle("fill", x + size/2 - 22, y + size - 55, 44, 55)
    love.graphics.arc("fill", x + size/2, y + size - 55, 22, math.pi, 2 * math.pi)
    
    -- Ornate door
    love.graphics.setColor(0.35, 0.24, 0.12, 1)
    love.graphics.rectangle("fill", x + size/2 - 20, y + size - 50, 40, 50)
    -- Gold door trim
    love.graphics.setColor(0.8, 0.7, 0.2, 1)
    love.graphics.rectangle("fill", x + size/2 - 20, y + size - 50, 40, 4)
    love.graphics.rectangle("fill", x + size/2 - 20, y + size - 30, 40, 3)
    love.graphics.rectangle("fill", x + size/2 - 20, y + size - 10, 40, 3)
    love.graphics.rectangle("fill", x + size/2 - 1, y + size - 50, 2, 50)
    
    -- Stained glass window above door
    love.graphics.setColor(0.3, 0.4, 0.6, 1)
    love.graphics.circle("fill", x + size/2, y + 30, 12)
    love.graphics.setColor(0.8, 0.7, 0.2, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x + size/2, y + 30, 12)
    love.graphics.line(x + size/2 - 10, y + 30, x + size/2 + 10, y + 30)
    love.graphics.line(x + size/2, y + 20, x + size/2, y + 40)
    
    -- Royal banner (center, large) - TEAM COLORED
    local bannerColor = Teams and Teams.getColor(self.team, "banner") or {0.6, 0.15, 0.15, 1}
    local emblemColor = Teams and Teams.getColor(self.team, "emblem") or {0.9, 0.8, 0.2, 1}
    
    love.graphics.setColor(0.5, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", x + size/2 - 1, y - 45, 3, 35)
    love.graphics.setColor(bannerColor)
    love.graphics.polygon("fill", 
        x + size/2 + 2, y - 45,
        x + size/2 + 25, y - 35,
        x + size/2 + 2, y - 15
    )
    -- Crown emblem
    love.graphics.setColor(emblemColor)
    love.graphics.polygon("fill", 
        x + size/2 + 8, y - 38,
        x + size/2 + 10, y - 32,
        x + size/2 + 14, y - 38,
        x + size/2 + 16, y - 32,
        x + size/2 + 20, y - 38,
        x + size/2 + 18, y - 28,
        x + size/2 + 6, y - 28
    )
    
    -- Grand torches
    love.graphics.setColor(1, 0.7, 0.3, 0.9)
    love.graphics.circle("fill", x + 15, y + 50, 5)
    love.graphics.circle("fill", x + size - 15, y + 50, 5)
    love.graphics.setColor(1, 0.9, 0.5, 0.5)
    love.graphics.circle("fill", x + 15, y + 50, 9)
    love.graphics.circle("fill", x + size - 15, y + 50, 9)
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
    if not self.isProducing and not self.isUpgrading then
        self.isProducing = true
        self.productionTimer = 0
        return true
    end
    return false
end

function TownHall:canProduce()
    return self.completed and not self.isProducing and not self.isUpgrading and not self.isBuilding
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
            local reason = nil
            if self.isProducing then
                reason = "Busy training peon"
            elseif not canAffordUpgrade then
                if resources.gold < upgradeCostGold and resources.lumber < upgradeCostLumber then
                    reason = "Need more gold & lumber"
                elseif resources.gold < upgradeCostGold then
                    reason = "Need more gold"
                else
                    reason = "Need more lumber"
                end
            elseif self.tier == 1 and not Requirements.hasBarracks() then
                reason = "Requires Barracks"
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
