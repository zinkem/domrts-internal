--[[
    Scout Tower
    Defensive building that can be upgraded
    Size: 2x2 tiles, grid-aligned
    Can upgrade to Archer Tower (requires Lumber Mill) or Cannon Tower (requires Blacksmith)
]]

local Button = require("button")
local Requirements = require("requirements")

local ScoutTower = {}
ScoutTower.__index = ScoutTower

ScoutTower.GRID_SIZE = 2
ScoutTower.COST_GOLD = 250
ScoutTower.COST_LUMBER = 25
ScoutTower.BUILD_TIME = 10.0
ScoutTower.UPGRADE_COST = 100  -- Gold cost to upgrade

-- Tower types
ScoutTower.TYPE_SCOUT = "scout"
ScoutTower.TYPE_ARCHER = "archer"
ScoutTower.TYPE_CANNON = "cannon"

function ScoutTower.new(params)
    local self = setmetatable({}, ScoutTower)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = ScoutTower.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "scouttower"
    self.name = "Scout Tower"
    self.towerType = ScoutTower.TYPE_SCOUT
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = ScoutTower.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    -- Upgrade state
    self.isUpgrading = false
    self.upgradeProgress = 0
    self.upgradeTime = 8.0
    self.upgradeTarget = nil
    
    -- UI buttons
    self.archerUpgradeButton = nil
    self.cannonUpgradeButton = nil
    
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
            self.towerType = self.upgradeTarget
            self.upgradeTarget = nil
            -- Update name based on type
            if self.towerType == ScoutTower.TYPE_ARCHER then
                self.name = "Archer Tower"
            elseif self.towerType == ScoutTower.TYPE_CANNON then
                self.name = "Cannon Tower"
            end
            return false, true  -- upgrade complete
        end
    end
    
    return false, false
end

function ScoutTower:startUpgrade(targetType)
    if self.completed and not self.isUpgrading and self.towerType == ScoutTower.TYPE_SCOUT then
        self.isUpgrading = true
        self.upgradeProgress = 0
        self.upgradeTarget = targetType
        return true
    end
    return false
end

function ScoutTower:canUpgrade()
    return self.completed and not self.isUpgrading and self.towerType == ScoutTower.TYPE_SCOUT
end

function ScoutTower:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction site
        love.graphics.setColor(0.45, 0.42, 0.38, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.5, 0.48, 0.44, 0.8)
        love.graphics.rectangle("fill", x + 10, y + 15, 20, 8)
        love.graphics.rectangle("fill", x + size - 30, y + 18, 20, 8)
        
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
    else
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.ellipse("fill", x + size/2, y + size + 2, size/2 - 5, 5)
        
        if self.towerType == ScoutTower.TYPE_SCOUT then
            self:drawScoutTower(x, y, size)
        elseif self.towerType == ScoutTower.TYPE_ARCHER then
            self:drawArcherTower(x, y, size)
        elseif self.towerType == ScoutTower.TYPE_CANNON then
            self:drawCannonTower(x, y, size)
        end
        
        -- Upgrading progress bar
        if self.isUpgrading then
            local barW = size - 10
            local progress = self.upgradeProgress / self.upgradeTime
            love.graphics.setColor(0.2, 0.2, 0.2, 1)
            love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
            love.graphics.setColor(0.8, 0.6, 0.2, 1)
            love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
        end
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function ScoutTower:drawScoutTower(x, y, size)
    -- Basic wooden tower
    -- Base
    love.graphics.setColor(0.45, 0.38, 0.28, 1)
    love.graphics.rectangle("fill", x + 8, y + 35, size - 16, size - 35, 2)
    
    -- Tower body (tapers up)
    love.graphics.setColor(0.5, 0.42, 0.3, 1)
    love.graphics.polygon("fill",
        x + 12, y + 35,
        x + size - 12, y + 35,
        x + size - 8, y + 10,
        x + 8, y + 10
    )
    
    -- Wood plank texture
    love.graphics.setColor(0.42, 0.36, 0.26, 1)
    love.graphics.line(x + 12, y + 20, x + size - 12, y + 20)
    love.graphics.line(x + 11, y + 28, x + size - 11, y + 28)
    
    -- Lookout platform
    love.graphics.setColor(0.48, 0.4, 0.28, 1)
    love.graphics.rectangle("fill", x + 2, y + 5, size - 4, 8, 2)
    
    -- Roof (pointed)
    love.graphics.setColor(0.4, 0.32, 0.22, 1)
    love.graphics.polygon("fill",
        x + size/2, y - 12,
        x, y + 8,
        x + size, y + 8
    )
    
    -- Window/opening
    love.graphics.setColor(0.15, 0.12, 0.1, 1)
    love.graphics.rectangle("fill", x + size/2 - 6, y + 15, 12, 15, 1)
    
    -- Door
    love.graphics.setColor(0.35, 0.28, 0.18, 1)
    love.graphics.rectangle("fill", x + size/2 - 8, y + size - 22, 16, 22)
end

function ScoutTower:drawArcherTower(x, y, size)
    -- Stone tower with archer battlements
    -- Base
    love.graphics.setColor(0.42, 0.4, 0.38, 1)
    love.graphics.rectangle("fill", x + 6, y + 30, size - 12, size - 30, 2)
    
    -- Tower body
    love.graphics.setColor(0.48, 0.45, 0.42, 1)
    love.graphics.polygon("fill",
        x + 10, y + 30,
        x + size - 10, y + 30,
        x + size - 6, y + 8,
        x + 6, y + 8
    )
    
    -- Stone texture
    love.graphics.setColor(0.4, 0.38, 0.35, 1)
    for row = 0, 2 do
        for col = 0, 1 do
            local offsetX = (row % 2) * 8
            love.graphics.rectangle("fill", x + 12 + col * 20 + offsetX, y + 12 + row * 12, 15, 8, 1)
        end
    end
    
    -- Battlements (crenellations)
    love.graphics.setColor(0.5, 0.47, 0.44, 1)
    love.graphics.rectangle("fill", x + 2, y + 2, size - 4, 10)
    love.graphics.setColor(0.48, 0.45, 0.42, 1)
    -- Gaps in battlements
    love.graphics.rectangle("fill", x + 8, y - 2, 8, 8)
    love.graphics.rectangle("fill", x + 24, y - 2, 8, 8)
    love.graphics.rectangle("fill", x + 40, y - 2, 8, 8)
    
    -- Arrow slit
    love.graphics.setColor(0.1, 0.08, 0.06, 1)
    love.graphics.rectangle("fill", x + size/2 - 2, y + 18, 4, 14)
    
    -- Bow icon
    love.graphics.setColor(0.6, 0.45, 0.25, 1)
    love.graphics.arc("line", x + size/2, y + 6, 6, math.pi * 0.7, math.pi * 1.3, 8)
    love.graphics.line(x + size/2 - 5, y + 9, x + size/2 + 5, y + 3)
    
    -- Door
    love.graphics.setColor(0.35, 0.28, 0.2, 1)
    love.graphics.rectangle("fill", x + size/2 - 8, y + size - 24, 16, 24)
    love.graphics.arc("fill", x + size/2, y + size - 24, 8, math.pi, 2 * math.pi)
end

function ScoutTower:drawCannonTower(x, y, size)
    -- Heavy stone tower with cannon
    -- Base (thicker)
    love.graphics.setColor(0.38, 0.36, 0.34, 1)
    love.graphics.rectangle("fill", x + 4, y + 25, size - 8, size - 25, 3)
    
    -- Tower body
    love.graphics.setColor(0.45, 0.42, 0.4, 1)
    love.graphics.rectangle("fill", x + 6, y + 8, size - 12, 25, 2)
    
    -- Heavy stone texture
    love.graphics.setColor(0.38, 0.35, 0.33, 1)
    for row = 0, 2 do
        for col = 0, 1 do
            local offsetX = (row % 2) * 10
            love.graphics.rectangle("fill", x + 10 + col * 22 + offsetX, y + 28 + row * 12, 18, 8, 1)
        end
    end
    
    -- Platform top
    love.graphics.setColor(0.5, 0.47, 0.45, 1)
    love.graphics.rectangle("fill", x, y + 2, size, 10, 2)
    
    -- Cannon barrel
    love.graphics.setColor(0.3, 0.28, 0.26, 1)
    love.graphics.rectangle("fill", x + size/2 - 5, y - 8, 10, 20, 2)
    -- Cannon muzzle
    love.graphics.setColor(0.25, 0.23, 0.2, 1)
    love.graphics.ellipse("fill", x + size/2, y - 8, 6, 4)
    -- Cannon base
    love.graphics.setColor(0.35, 0.32, 0.3, 1)
    love.graphics.rectangle("fill", x + size/2 - 8, y + 8, 16, 6, 1)
    
    -- Metal reinforcement bands
    love.graphics.setColor(0.4, 0.38, 0.4, 1)
    love.graphics.rectangle("fill", x + 4, y + 20, size - 8, 3)
    love.graphics.rectangle("fill", x + 4, y + 38, size - 8, 3)
    
    -- Door (reinforced)
    love.graphics.setColor(0.3, 0.25, 0.18, 1)
    love.graphics.rectangle("fill", x + size/2 - 8, y + size - 22, 16, 22)
    -- Metal bands on door
    love.graphics.setColor(0.35, 0.33, 0.35, 1)
    love.graphics.rectangle("fill", x + size/2 - 8, y + size - 18, 16, 2)
    love.graphics.rectangle("fill", x + size/2 - 8, y + size - 10, 16, 2)
end

function ScoutTower:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
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

function ScoutTower:updateUI(resources, screenW, screenH, font)
    if self.selected and self.completed and self.towerType == ScoutTower.TYPE_SCOUT and not self.isUpgrading then
        local panelX = screenW - 180
        local buttonY = 70 + 145
        
        local selfRef = self
        local canArcher = Requirements.canUpgradeToArcherTower()
        local canCannon = Requirements.canUpgradeToCannonTower()
        
        -- Archer Tower upgrade button
        if not self.archerUpgradeButton then
            self.archerUpgradeButton = Button.new({
                x = panelX + 10, y = buttonY, width = 150, height = 35,
                text = "Archer Tower (100g)", font = font,
                colors = {
                    normal = {0.4, 0.5, 0.35, 1}, hover = {0.5, 0.6, 0.45, 1},
                    pressed = {0.3, 0.4, 0.25, 1}, text = {1, 1, 1, 1}, border = {0.3, 0.4, 0.25, 1}
                },
                onClick = function()
                    if canArcher and resources.gold >= ScoutTower.UPGRADE_COST then
                        resources.gold = resources.gold - ScoutTower.UPGRADE_COST
                        selfRef:startUpgrade(ScoutTower.TYPE_ARCHER)
                    end
                end
            })
        end
        
        -- Cannon Tower upgrade button
        if not self.cannonUpgradeButton then
            self.cannonUpgradeButton = Button.new({
                x = panelX + 10, y = buttonY + 40, width = 150, height = 35,
                text = "Cannon Tower (100g)", font = font,
                colors = {
                    normal = {0.5, 0.4, 0.35, 1}, hover = {0.6, 0.5, 0.45, 1},
                    pressed = {0.4, 0.3, 0.25, 1}, text = {1, 1, 1, 1}, border = {0.4, 0.3, 0.25, 1}
                },
                onClick = function()
                    if canCannon and resources.gold >= ScoutTower.UPGRADE_COST then
                        resources.gold = resources.gold - ScoutTower.UPGRADE_COST
                        selfRef:startUpgrade(ScoutTower.TYPE_CANNON)
                    end
                end
            })
        end
        
        self.archerUpgradeButton:setEnabled(canArcher and resources.gold >= ScoutTower.UPGRADE_COST)
        self.cannonUpgradeButton:setEnabled(canCannon and resources.gold >= ScoutTower.UPGRADE_COST)
        self.archerUpgradeButton:update(0)
        self.cannonUpgradeButton:update(0)
    else
        self.archerUpgradeButton = nil
        self.cannonUpgradeButton = nil
    end
end

function ScoutTower:drawUI()
    if self.selected and self.completed and self.towerType == ScoutTower.TYPE_SCOUT and not self.isUpgrading then
        if self.archerUpgradeButton then self.archerUpgradeButton:draw() end
        if self.cannonUpgradeButton then self.cannonUpgradeButton:draw() end
        
        local screenW = love.graphics.getWidth()
        
        -- Show requirements
        if not Requirements.canUpgradeToArcherTower() then
            love.graphics.setColor(1, 0.6, 0.4, 1)
            love.graphics.setFont(Game.fonts.small)
            love.graphics.print("Needs Lumber Mill", screenW - 170, 70 + 183)
        end
        if not Requirements.canUpgradeToCannonTower() then
            love.graphics.setColor(1, 0.6, 0.4, 1)
            love.graphics.setFont(Game.fonts.small)
            love.graphics.print("Needs Blacksmith", screenW - 170, 70 + 223)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function ScoutTower:mousepressed(x, y, button)
    if self.archerUpgradeButton then self.archerUpgradeButton:mousepressed(x, y, button) end
    if self.cannonUpgradeButton then self.cannonUpgradeButton:mousepressed(x, y, button) end
end

function ScoutTower:mousereleased(x, y, button)
    if self.archerUpgradeButton then self.archerUpgradeButton:mousereleased(x, y, button) end
    if self.cannonUpgradeButton then self.cannonUpgradeButton:mousereleased(x, y, button) end
end

function ScoutTower:drawOnMinimap(mapX, mapY, scale)
    if self.towerType == ScoutTower.TYPE_ARCHER then
        love.graphics.setColor(0.4, 0.6, 0.4, 1)
    elseif self.towerType == ScoutTower.TYPE_CANNON then
        love.graphics.setColor(0.5, 0.4, 0.35, 1)
    elseif self.completed then
        love.graphics.setColor(0.5, 0.5, 0.45, 1)
    else
        love.graphics.setColor(0.4, 0.4, 0.38, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return ScoutTower
