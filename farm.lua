--[[
    Farm
    Provides unit capacity (+4 units per farm)
    Size: 2x2 tiles, grid-aligned
]]

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

local Farm = {}
Farm.__index = Farm

Farm.GRID_SIZE = 2
Farm.COST_GOLD = 250
Farm.COST_LUMBER = 50
Farm.BUILD_TIME = 10.0
Farm.CAPACITY_BONUS = 4

function Farm.new(params)
    local self = setmetatable({}, Farm)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = Farm.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "farm"
    self.name = "Farm"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 200
    self.hp = self.maxHp
    self.sightRadius = 2
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = Farm.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function Farm:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function Farm:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function Farm:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function Farm:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function Farm:update(dt)
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

function Farm:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction site
        love.graphics.setColor(0.5, 0.45, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.35, 0.8)
        -- Lumber stacks
        love.graphics.rectangle("fill", x + 5, y + 10, 20, 8)
        love.graphics.rectangle("fill", x + size - 25, y + 15, 20, 8)
        
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
        
        -- Ground/field (crop rows)
        love.graphics.setColor(0.45, 0.38, 0.25, 1)
        love.graphics.rectangle("fill", x, y + 30, size, size - 30, 2)
        
        -- Wheat/crop rows
        love.graphics.setColor(0.75, 0.65, 0.25, 1)
        for row = 0, 2 do
            for col = 0, 5 do
                local cropX = x + 5 + col * 10
                local cropY = y + 35 + row * 12
                -- Wheat stalks
                love.graphics.line(cropX, cropY + 8, cropX, cropY)
                love.graphics.line(cropX + 2, cropY + 8, cropX + 2, cropY + 2)
                love.graphics.ellipse("fill", cropX + 1, cropY - 1, 3, 2)
            end
        end
        
        -- Farmhouse base
        love.graphics.setColor(0.55, 0.4, 0.25, 1)
        love.graphics.rectangle("fill", x + 8, y + 8, size - 16, 30, 2)
        
        -- Wooden plank texture
        love.graphics.setColor(0.5, 0.36, 0.22, 1)
        love.graphics.rectangle("fill", x + 8, y + 15, size - 16, 2)
        love.graphics.rectangle("fill", x + 8, y + 25, size - 16, 2)
        
        -- Thatched roof
        love.graphics.setColor(0.6, 0.55, 0.3, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 5,
            x + 3, y + 12,
            x + size - 3, y + 12
        )
        -- Roof thatch texture
        love.graphics.setColor(0.55, 0.5, 0.28, 1)
        love.graphics.line(x + size/2, y - 3, x + 8, y + 10)
        love.graphics.line(x + size/2, y - 3, x + 20, y + 10)
        love.graphics.line(x + size/2, y - 3, x + size - 20, y + 10)
        love.graphics.line(x + size/2, y - 3, x + size - 8, y + 10)
        
        -- Door
        love.graphics.setColor(0.4, 0.28, 0.15, 1)
        love.graphics.rectangle("fill", x + size/2 - 6, y + 22, 12, 16)
        love.graphics.setColor(0.3, 0.2, 0.1, 1)
        love.graphics.rectangle("fill", x + size/2 - 1, y + 22, 2, 16)
        -- Door handle
        love.graphics.setColor(0.5, 0.45, 0.3, 1)
        love.graphics.circle("fill", x + size/2 + 4, y + 30, 2)
        
        -- Window
        love.graphics.setColor(0.5, 0.6, 0.7, 0.8)
        love.graphics.rectangle("fill", x + 14, y + 14, 10, 10)
        love.graphics.setColor(0.4, 0.28, 0.15, 1)
        love.graphics.rectangle("fill", x + 18, y + 14, 2, 10)
        love.graphics.rectangle("fill", x + 14, y + 18, 10, 2)
        
        -- Wooden fence posts
        love.graphics.setColor(0.5, 0.38, 0.22, 1)
        love.graphics.rectangle("fill", x + 2, y + 30, 3, size - 32)
        love.graphics.rectangle("fill", x + size - 5, y + 30, 3, size - 32)
        love.graphics.rectangle("fill", x + 2, y + 40, size - 4, 2)
        love.graphics.rectangle("fill", x + 2, y + 52, size - 4, 2)
        
        -- Hay bale
        love.graphics.setColor(0.7, 0.6, 0.3, 1)
        love.graphics.ellipse("fill", x + size - 12, y + 20, 6, 5)
        love.graphics.setColor(0.65, 0.55, 0.28, 1)
        love.graphics.arc("line", x + size - 12, y + 20, 5, 0, math.pi)
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    -- Health bar
    self:drawHealthBar()
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Farm:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function Farm:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function Farm:updateUI(resources, screenW, screenH, font) end
function Farm:drawUI() end
function Farm:mousepressed(x, y, button) end
function Farm:mousereleased(x, y, button) end

-- Combat Methods --

function Farm:takeDamage(amount)
    self.hp = self.hp - amount
end

function Farm:isDead()
    return self.hp <= 0
end

function Farm:drawHealthBar()
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

function Farm:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        -- Use team color
        if Teams then
            Teams.setColor(self.team, "minimapBuilding")
        else
            love.graphics.setColor(0.5, 0.6, 0.3, 1)
        end
    else
        love.graphics.setColor(0.4, 0.4, 0.3, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return Farm
