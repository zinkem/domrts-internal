--[[
    Lumber Mill
    Utility building that enables tower upgrades
    Size: 2x2 tiles, grid-aligned
    No requirements to build
]]

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

local LumberMill = {}
LumberMill.__index = LumberMill

LumberMill.GRID_SIZE = 2
LumberMill.COST_GOLD = 250
LumberMill.COST_LUMBER = 0
LumberMill.BUILD_TIME = 12.0

function LumberMill.new(params)
    local self = setmetatable({}, LumberMill)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = LumberMill.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "lumbermill"
    self.name = "Lumber Mill"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 50
    self.hp = self.maxHp
    self.sightRadius = 5
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = LumberMill.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function LumberMill:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function LumberMill:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function LumberMill:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function LumberMill:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function LumberMill:update(dt)
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return true
        end
    end
    return false
end

function LumberMill:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction site
        love.graphics.setColor(0.5, 0.4, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.3, 0.8)
        -- Lumber stacks
        love.graphics.rectangle("fill", x + 5, y + 10, 25, 8)
        love.graphics.rectangle("fill", x + size - 30, y + 15, 25, 8)
        
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
        
        -- Main building base (wooden structure)
        love.graphics.setColor(0.5, 0.38, 0.22, 1)
        love.graphics.rectangle("fill", x + 4, y + 20, size - 8, size - 20, 2)
        
        -- Wood plank texture
        love.graphics.setColor(0.45, 0.34, 0.2, 1)
        for i = 0, 3 do
            love.graphics.rectangle("fill", x + 4, y + 25 + i * 10, size - 8, 2)
        end
        
        -- Roof (slanted wooden)
        love.graphics.setColor(0.4, 0.3, 0.18, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 2,
            x, y + 24,
            x + size, y + 24
        )
        -- Roof highlight
        love.graphics.setColor(0.48, 0.36, 0.22, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 2,
            x + size/2 - 20, y + 18,
            x + size/2, y + 14
        )
        
        -- Large saw blade on side
        love.graphics.setColor(0.55, 0.55, 0.6, 1)
        love.graphics.circle("fill", x + size - 12, y + 35, 10)
        love.graphics.setColor(0.4, 0.4, 0.45, 1)
        love.graphics.circle("fill", x + size - 12, y + 35, 6)
        -- Saw teeth
        love.graphics.setColor(0.6, 0.6, 0.65, 1)
        for i = 0, 7 do
            local angle = i * math.pi / 4
            local tx = x + size - 12 + math.cos(angle) * 12
            local ty = y + 35 + math.sin(angle) * 12
            love.graphics.polygon("fill",
                x + size - 12 + math.cos(angle) * 8, y + 35 + math.sin(angle) * 8,
                tx + math.cos(angle + 0.3) * 2, ty + math.sin(angle + 0.3) * 2,
                tx + math.cos(angle - 0.3) * 2, ty + math.sin(angle - 0.3) * 2
            )
        end
        
        -- Door
        love.graphics.setColor(0.35, 0.25, 0.15, 1)
        love.graphics.rectangle("fill", x + 10, y + size - 28, 18, 28)
        love.graphics.setColor(0.45, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + 18, y + size - 28, 2, 28)
        
        -- Log pile outside
        love.graphics.setColor(0.5, 0.38, 0.2, 1)
        love.graphics.ellipse("fill", x + size - 20, y + size - 8, 8, 4)
        love.graphics.ellipse("fill", x + size - 25, y + size - 12, 6, 3)
        love.graphics.ellipse("fill", x + size - 15, y + size - 14, 7, 3)
        
        -- Window
        love.graphics.setColor(0.4, 0.5, 0.6, 0.8)
        love.graphics.rectangle("fill", x + 35, y + 30, 12, 12)
        love.graphics.setColor(0.35, 0.25, 0.15, 1)
        love.graphics.rectangle("fill", x + 40, y + 30, 2, 12)
        love.graphics.rectangle("fill", x + 35, y + 35, 12, 2)
        
        -- Smoke from chimney (subtle)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
        love.graphics.circle("fill", x + size/2 + 5, y - 8, 4)
        love.graphics.circle("fill", x + size/2 + 8, y - 14, 3)
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function LumberMill:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function LumberMill:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function LumberMill:updateUI(resources, screenW, screenH, font) end
function LumberMill:drawUI() end
function LumberMill:mousepressed(x, y, button) end
function LumberMill:mousereleased(x, y, button) end

function LumberMill:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        if Teams then
            Teams.setColor(self.team, "minimapBuilding")
        else
            love.graphics.setColor(0.5, 0.4, 0.25, 1)
        end
    else
        love.graphics.setColor(0.4, 0.35, 0.2, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

-- Combat Methods --

function LumberMill:takeDamage(amount)
    self.hp = self.hp - amount
end

function LumberMill:isDead()
    return self.hp <= 0
end

function LumberMill:drawHealthBar()
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

return LumberMill
