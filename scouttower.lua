--[[
    Scout Tower
    Defensive structure with extended sight radius
    Size: 2x2 tiles, grid-aligned
    Special: Provides vision radius of 9 tiles
]]

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

local ScoutTower = {}
ScoutTower.__index = ScoutTower

ScoutTower.GRID_SIZE = 2
ScoutTower.COST_GOLD = 200
ScoutTower.COST_LUMBER = 100
ScoutTower.BUILD_TIME = 12.0

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
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 100
    self.hp = self.maxHp
    self.sightRadius = 9  -- Extended vision range!
    
    -- Building state
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = ScoutTower.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    -- Animation
    self.torchFlicker = 0
    
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
    -- Update torch animation
    self.torchFlicker = self.torchFlicker + dt * 8
    
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return true  -- Building complete
        end
    end
    return false
end

function ScoutTower:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction site
        love.graphics.setColor(0.5, 0.45, 0.4, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        
        -- Scaffolding
        love.graphics.setColor(0.6, 0.45, 0.3, 0.8)
        love.graphics.rectangle("fill", x + size/2 - 8, y + 10, 16, size - 20)
        love.graphics.setColor(0.5, 0.4, 0.25, 0.8)
        love.graphics.line(x + 10, y + 20, x + size - 10, y + 20)
        love.graphics.line(x + 10, y + 40, x + size - 10, y + 40)
        
        -- Progress bar
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
    else
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.ellipse("fill", x + size/2, y + size + 2, size/3, 6)
        
        -- Tower base (stone)
        love.graphics.setColor(0.45, 0.42, 0.38, 1)
        love.graphics.rectangle("fill", x + 10, y + size - 25, size - 20, 25, 3)
        
        -- Base details (stone texture)
        love.graphics.setColor(0.35, 0.32, 0.28, 1)
        for i = 0, 2 do
            love.graphics.rectangle("fill", x + 12 + i * 15, y + size - 22, 12, 8)
            love.graphics.rectangle("fill", x + 18 + i * 15, y + size - 12, 10, 10)
        end
        
        -- Main tower body (taller, narrower)
        love.graphics.setColor(0.5, 0.47, 0.42, 1)
        love.graphics.rectangle("fill", x + size/2 - 12, y + 15, 24, size - 40, 2)
        
        -- Tower body shading
        love.graphics.setColor(0.4, 0.37, 0.32, 1)
        love.graphics.rectangle("fill", x + size/2 - 12, y + 15, 6, size - 40, 2)
        love.graphics.setColor(0.55, 0.52, 0.47, 1)
        love.graphics.rectangle("fill", x + size/2 + 6, y + 15, 6, size - 40, 2)
        
        -- Tower top platform (crenellations)
        love.graphics.setColor(0.5, 0.47, 0.42, 1)
        love.graphics.rectangle("fill", x + size/2 - 16, y + 8, 32, 12)
        
        -- Crenellations (battlements)
        love.graphics.setColor(0.55, 0.52, 0.47, 1)
        for i = 0, 3 do
            love.graphics.rectangle("fill", x + size/2 - 14 + i * 9, y + 2, 6, 8)
        end
        
        -- Pointed roof
        love.graphics.setColor(0.4, 0.3, 0.25, 1)
        love.graphics.polygon("fill", 
            x + size/2, y - 8,
            x + size/2 - 18, y + 10,
            x + size/2 + 18, y + 10
        )
        
        -- Roof highlight
        love.graphics.setColor(0.5, 0.4, 0.35, 1)
        love.graphics.polygon("fill", 
            x + size/2, y - 8,
            x + size/2 - 8, y + 4,
            x + size/2 + 2, y + 4
        )
        
        -- Window (glowing)
        local flicker = math.sin(self.torchFlicker) * 0.1 + 0.9
        love.graphics.setColor(0.9 * flicker, 0.7 * flicker, 0.3 * flicker, 1)
        love.graphics.rectangle("fill", x + size/2 - 4, y + 28, 8, 12, 1)
        
        -- Window glow
        love.graphics.setColor(1, 0.85, 0.4, 0.3 * flicker)
        love.graphics.circle("fill", x + size/2, y + 34, 10)
        
        -- Second window (smaller)
        love.graphics.setColor(0.85 * flicker, 0.65 * flicker, 0.25 * flicker, 1)
        love.graphics.rectangle("fill", x + size/2 - 3, y + 45, 6, 8, 1)
        
        -- Door at base
        love.graphics.setColor(0.35, 0.25, 0.18, 1)
        love.graphics.rectangle("fill", x + size/2 - 5, y + size - 20, 10, 18, 2)
        
        -- Door detail
        love.graphics.setColor(0.25, 0.18, 0.12, 1)
        love.graphics.line(x + size/2, y + size - 18, x + size/2, y + size - 4)
        
        -- Team color banner
        if Teams then
            Teams.setColor(self.team, "banner")
        else
            love.graphics.setColor(0.8, 0.2, 0.2, 1)
        end
        -- Banner pole
        love.graphics.setColor(0.4, 0.3, 0.2, 1)
        love.graphics.rectangle("fill", x + size/2 + 14, y - 5, 2, 20)
        -- Banner
        if Teams then
            Teams.setColor(self.team, "banner")
        else
            love.graphics.setColor(0.8, 0.2, 0.2, 1)
        end
        love.graphics.polygon("fill",
            x + size/2 + 16, y - 3,
            x + size/2 + 28, y + 2,
            x + size/2 + 16, y + 10
        )
    end
    
    -- Selection indicator
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
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

function ScoutTower:updateUI(resources, screenW, screenH, font) end
function ScoutTower:drawUI() end
function ScoutTower:mousepressed(x, y, button) end
function ScoutTower:mousereleased(x, y, button) end

-- Combat Methods --

function ScoutTower:takeDamage(amount)
    self.hp = self.hp - amount
end

function ScoutTower:isDead()
    return self.hp <= 0
end

function ScoutTower:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 10
    local barHeight = 4
    local barX = x + 5
    local barY = y - 12  -- Slightly higher due to tower height
    
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

function ScoutTower:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        -- Use team color
        if Teams then
            Teams.setColor(self.team, "minimapBuilding")
        else
            love.graphics.setColor(0.5, 0.5, 0.6, 1)
        end
    else
        love.graphics.setColor(0.4, 0.4, 0.45, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return ScoutTower
