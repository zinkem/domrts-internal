--[[
    Stable
    Enables Knight production at Barracks
    Has Paladin upgrade (requires Siege Workshop)
    Size: 2x2 tiles, grid-aligned
    Requires: Hold (Town Hall tier 2)
]]

local Button = require("button")
local Requirements = require("requirements")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

local Stable = {}
Stable.__index = Stable

Stable.GRID_SIZE = 3
Stable.COST_GOLD = 500
Stable.COST_LUMBER = 200
Stable.BUILD_TIME = 20.0
Stable.PALADIN_UPGRADE_COST = 100

function Stable.new(params)
    local self = setmetatable({}, Stable)
    
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
    
    -- UI
    self.paladinUpgradeButton = nil
    
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
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return true, false  -- build complete, no upgrade
        end
        return false, false
    end
    
    if self.isUpgrading then
        self.upgradeProgress = self.upgradeProgress + dt
        if self.upgradeProgress >= self.upgradeTime then
            self.isUpgrading = false
            self.upgradeProgress = 0
            self.hasPaladinUpgrade = true
            -- Trigger callback to convert existing knights
            if self.onPaladinUpgrade then
                self.onPaladinUpgrade()
            end
            return false, true  -- upgrade complete
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
        -- Lumber and straw
        love.graphics.rectangle("fill", x + 8, y + 12, 20, 8)
        love.graphics.setColor(0.7, 0.65, 0.4, 0.8)
        love.graphics.rectangle("fill", x + size - 28, y + 18, 22, 6)
        
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
    else
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.ellipse("fill", x + size/2, y + size + 2, size/2 - 3, 5)
        
        -- Ground (hay/straw covered)
        love.graphics.setColor(0.6, 0.55, 0.35, 1)
        love.graphics.rectangle("fill", x, y + 35, size, size - 35, 2)
        
        -- Main building (wooden barn style)
        love.graphics.setColor(0.55, 0.38, 0.22, 1)
        love.graphics.rectangle("fill", x + 3, y + 12, size - 6, size - 15, 2)
        
        -- Wood plank texture
        love.graphics.setColor(0.48, 0.32, 0.18, 1)
        for i = 0, 3 do
            love.graphics.rectangle("fill", x + 3, y + 18 + i * 12, size - 6, 2)
        end
        
        -- Barn roof
        love.graphics.setColor(0.5, 0.32, 0.18, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 8,
            x - 3, y + 15,
            x + size + 3, y + 15
        )
        -- Roof highlight
        love.graphics.setColor(0.58, 0.4, 0.25, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 8,
            x + size/2 - 22, y + 12,
            x + size/2, y + 8
        )
        
        -- Stable doors (large opening)
        love.graphics.setColor(0.15, 0.12, 0.08, 1)
        love.graphics.rectangle("fill", x + 8, y + 28, size - 16, size - 30, 2)
        
        -- Wooden door frame
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + 6, y + 26, 4, size - 28)
        love.graphics.rectangle("fill", x + size - 10, y + 26, 4, size - 28)
        love.graphics.rectangle("fill", x + 6, y + 26, size - 12, 4)
        
        -- Door hinge/X pattern
        love.graphics.setColor(0.4, 0.28, 0.15, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 12, y + 32, x + size/2 - 2, y + size - 8)
        love.graphics.line(x + size/2 - 2, y + 32, x + 12, y + size - 8)
        love.graphics.line(x + size/2 + 2, y + 32, x + size - 12, y + size - 8)
        love.graphics.line(x + size - 12, y + 32, x + size/2 + 2, y + size - 8)
        
        -- Horse head silhouette in doorway
        love.graphics.setColor(0.3, 0.25, 0.2, 1)
        love.graphics.ellipse("fill", x + size/2, y + 42, 10, 8)
        love.graphics.polygon("fill",
            x + size/2 + 5, y + 38,
            x + size/2 + 15, y + 32,
            x + size/2 + 12, y + 42,
            x + size/2 + 8, y + 45
        )
        -- Horse ear
        love.graphics.polygon("fill",
            x + size/2 + 8, y + 35,
            x + size/2 + 12, y + 28,
            x + size/2 + 14, y + 34
        )
        
        -- Horseshoe above door
        love.graphics.setColor(0.4, 0.38, 0.4, 1)
        love.graphics.setLineWidth(3)
        love.graphics.arc("line", x + size/2, y + 20, 8, math.pi * 0.2, math.pi * 0.8, 8)
        
        -- Hay bale on side
        love.graphics.setColor(0.7, 0.62, 0.38, 1)
        love.graphics.ellipse("fill", x + size - 10, y + size - 10, 8, 5)
        love.graphics.setColor(0.65, 0.58, 0.35, 1)
        love.graphics.arc("line", x + size - 10, y + size - 10, 6, 0, math.pi)
        
        -- Paladin banner (if upgraded)
        if self.hasPaladinUpgrade then
            love.graphics.setColor(0.5, 0.35, 0.2, 1)
            love.graphics.rectangle("fill", x + 5, y - 15, 2, 20)
            love.graphics.setColor(0.8, 0.7, 0.2, 1)  -- Gold banner
            love.graphics.polygon("fill",
                x + 7, y - 15,
                x + 20, y - 12,
                x + 17, y - 2,
                x + 7, y - 5
            )
            -- Cross on banner
            love.graphics.setColor(0.9, 0.85, 0.3, 1)
            love.graphics.rectangle("fill", x + 11, y - 14, 3, 10)
            love.graphics.rectangle("fill", x + 8, y - 11, 9, 3)
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
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
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

function Stable:updateUI(resources, screenW, screenH, font)
    -- UI now handled by command buttons in gameplay.lua
end

function Stable:drawUI()
    -- UI now handled by command buttons in gameplay.lua
end

function Stable:mousepressed(x, y, button)
    -- UI now handled by command buttons in gameplay.lua
end

function Stable:mousereleased(x, y, button)
    -- UI now handled by command buttons in gameplay.lua
end

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

function Stable:drawOnMinimap(mapX, mapY, scale)
    local Teams = require("teams")
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
